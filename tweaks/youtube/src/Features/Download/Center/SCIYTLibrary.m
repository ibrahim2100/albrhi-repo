#import "SCIYTLibrary.h"
#import "SCIYTNotice.h"
#import "SCIYTThumbnails.h"
#import "../../../SCILog.h"
#import "../../../Prefs.h"
#import "../../../Localization/SCILocalize.h"
#import "../../../Diagnostics/SCIYTDiagnostics.h"
#import <UIKit/UIKit.h>
#import <Photos/Photos.h>

NSNotificationName const SCIYTLibraryDidChangeNotification = @"SCIYTLibraryDidChange";

@interface SCIYTLibrary ()
@property (nonatomic, strong) NSMutableArray<SCIYTJob *> *store;
@end

@implementation SCIYTLibrary

+ (instancetype)shared {
    static SCIYTLibrary *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[SCIYTLibrary alloc] init]; });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (!self) return nil;

    _store = [NSMutableArray array];
    [self load];
    return self;
}

+ (NSURL *)folder {
    static NSURL *folder = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSURL *documents = [[[NSFileManager defaultManager]
            URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
        folder = [documents URLByAppendingPathComponent:@"Albrhi Downloads" isDirectory:YES];

        [[NSFileManager defaultManager] createDirectoryAtURL:folder
                                withIntermediateDirectories:YES
                                                 attributes:nil
                                                      error:nil];
    });
    return folder;
}

+ (NSURL *)indexFile {
    return [[self folder] URLByAppendingPathComponent:@"library.index"];
}

- (NSArray<SCIYTJob *> *)jobs { return [self.store copy]; }

// MARK: - Persistence

/// Clears scratch files an interrupted download left behind.
///
/// Every download writes its joined parts into the temporary directory before the finished
/// file is moved into place. A download the app did not survive leaves that behind, and iOS
/// empties the temporary directory on its own schedule rather than promptly -- which on a
/// phone that has saved a few long videos is hundreds of megabytes sitting where nobody
/// will look for it.
///
/// Only our own scratch names, and only ones older than an hour, so a download running
/// right now is never touched.
- (void)clearScratch {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSURL *temp = [NSURL fileURLWithPath:NSTemporaryDirectory()];

    NSArray<NSURL *> *entries =
        [manager contentsOfDirectoryAtURL:temp
               includingPropertiesForKeys:@[NSURLContentModificationDateKey]
                                  options:NSDirectoryEnumerationSkipsHiddenFiles
                                    error:nil];

    NSDate *cutoff = [NSDate dateWithTimeIntervalSinceNow:-3600];
    unsigned long long freed = 0;

    for (NSURL *entry in entries) {
        NSString *extension = entry.pathExtension.lowercaseString;
        if (![@[@"ts", @"aac", @"m4a", @"mp4", @"raw"] containsObject:extension]) continue;

        NSDate *modified = nil;
        [entry getResourceValue:&modified forKey:NSURLContentModificationDateKey error:nil];
        if (modified && [modified compare:cutoff] == NSOrderedDescending) continue;

        NSNumber *size = nil;
        [entry getResourceValue:&size forKey:NSURLFileSizeKey error:nil];
        if ([manager removeItemAtURL:entry error:nil]) freed += size.unsignedLongLongValue;
    }

    if (freed) SCILogV(@"library: cleared %llu bytes of scratch", freed);
}

- (void)load {
    [self clearScratch];

    NSData *data = [NSData dataWithContentsOfURL:[SCIYTLibrary indexFile]];
    if (!data.length) return;

    NSError *error = nil;
    NSSet *classes = [NSSet setWithObjects:[NSArray class], [SCIYTJob class],
                                            [NSString class], [NSDate class], nil];
    NSArray *saved = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes
                                                          fromData:data
                                                             error:&error];
    if (![saved isKindOfClass:[NSArray class]]) {
        SCILogV(@"library: index unreadable — %@", error.localizedDescription);
        return;
    }

    // A row whose file is gone is dropped rather than shown greyed out. The folder is
    // reachable from the Files app, and someone who deleted a video there has already
    // said what they wanted to happen to it.
    for (SCIYTJob *job in saved) {
        if ([job isKindOfClass:[SCIYTJob class]] && [job fileURL]) [self.store addObject:job];
    }

    SCILogV(@"library: %lu downloads", (unsigned long)self.store.count);
}

- (void)save {
    NSMutableArray<SCIYTJob *> *finished = [NSMutableArray array];
    for (SCIYTJob *job in self.store) {
        if (job.state == SCIYTJobStateDone && job.fileName.length) [finished addObject:job];
    }

    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:finished
                                        requiringSecureCoding:YES
                                                        error:&error];
    if (!data) {
        SCILogV(@"library: could not write the index — %@", error.localizedDescription);
        return;
    }
    [data writeToURL:[SCIYTLibrary indexFile] atomically:YES];
}

- (void)changed {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:SCIYTLibraryDidChangeNotification
                                                            object:self];
    });
}

// MARK: - Running one

- (SCIYTJob *)startVariant:(SCIHLSVariant *)variant
                      kind:(SCIYTJobKind)kind
                     title:(NSString *)title
                   videoID:(NSString *)videoID
                   isShort:(BOOL)isShort {

    NSString *quality = (kind == SCIYTJobKindAudio) ? SCILocalized(@"dl_kind_audio")
                                                     : [variant label];

    SCIYTJob *job = [SCIYTJob jobWithTitle:title quality:quality kind:kind videoID:videoID];
    job.isShort = isShort;
    [self.store insertObject:job atIndex:0];
    [self changed];

    // Progress is throttled to whole percents. A playlist of two hundred parts posts two
    // hundred notifications otherwise, each one reloading a table that has not changed
    // by anything a person can see.
    __block int lastShown = -1;

    void (^onProgress)(double) = ^(double fraction) {
        int percent = (int)(fraction * 100);
        job.progress = fraction;
        if (percent == lastShown) return;
        lastShown = percent;
        [self changed];
    };

    void (^onDone)(NSURL *, NSString *) = ^(NSURL *file, NSString *failure) {
        if (!file) {
            dispatch_async(dispatch_get_main_queue(), ^{
                job.state = SCIYTJobStateFailed;
                job.failure = failure ?: SCILocalized(@"dl_failed");
                [self changed];
                [SCIYTNotice announceFailed:job reason:failure];
            });
            return;
        }

        // The app is asked to stay awake for the joining and unwrapping.
        //
        // The parts arrive through a background session, so they land whether YouTube is in
        // front or not -- and the work that turns ninety parts into one video is ours, in
        // this process, and would be suspended halfway through with the app in the
        // background. That is a video left as a folder of fragments and a row stuck at
        // ninety-nine per cent.
        //
        // Thirty seconds is roughly what iOS grants, which is ample: the joining is a file
        // copy, not a re-encode. The task is ended on both paths, because leaking one is how
        // an app gets killed for holding a background assertion it forgot about.
        UIApplication *app = [UIApplication sharedApplication];
        __block UIBackgroundTaskIdentifier hold =
            [app beginBackgroundTaskWithExpirationHandler:^{
                [app endBackgroundTask:hold];
                hold = UIBackgroundTaskInvalid;
            }];

        [self adopt:file for:job];
        [SCIYTNotice announceFinished:job];

        if (hold != UIBackgroundTaskInvalid) {
            [app endBackgroundTask:hold];
            hold = UIBackgroundTaskInvalid;
        }
    };

    if (kind == SCIYTJobKindAudio) {
        [SCIYTHLS downloadAudioFor:variant progress:onProgress completion:onDone];
    } else {
        [SCIYTHLS downloadVariant:variant progress:onProgress completion:onDone];
    }

    return job;
}

/// Moves a finished file into the library folder under a name a person can read.
- (void)adopt:(NSURL *)file for:(SCIYTJob *)job {
    // Brought onto the main thread first, because the list is edited there.
    //
    // A download does not finish on any one queue -- some paths end on a URLSession queue
    // and some on an export handler -- and -save walks the whole store. A swipe to delete
    // removes from that same store on the main thread, so a download landing at the moment
    // someone deletes a row is a mutation during enumeration, from two threads, which is a
    // crash and not a glitch. Everything that touches the store now happens in one place.
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self adopt:file for:job]; });
        return;
    }

    NSString *extension = file.pathExtension.length ? file.pathExtension : @"mp4";

    // The characters a file name cannot hold, taken out rather than escaped. A title is
    // whatever the uploader typed, and on this project that has included newlines.
    NSMutableCharacterSet *illegal =
        [NSMutableCharacterSet characterSetWithCharactersInString:@"/\\?%*|\"<>:"];
    [illegal formUnionWithCharacterSet:[NSCharacterSet controlCharacterSet]];
    [illegal formUnionWithCharacterSet:[NSCharacterSet newlineCharacterSet]];

    NSString *safe = [[job.title componentsSeparatedByCharactersInSet:illegal]
                      componentsJoinedByString:@" "];
    safe = [safe stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (safe.length > 80) safe = [safe substringToIndex:80];
    if (!safe.length) safe = SCILocalized(@"dl_untitled");

    NSString *name = [safe stringByAppendingPathExtension:extension];
    NSURL *destination = [[SCIYTLibrary folder] URLByAppendingPathComponent:name];

    NSUInteger attempt = 2;
    while ([[NSFileManager defaultManager] fileExistsAtPath:destination.path]) {
        name = [[NSString stringWithFormat:@"%@ (%lu)", safe, (unsigned long)attempt++]
                stringByAppendingPathExtension:extension];
        destination = [[SCIYTLibrary folder] URLByAppendingPathComponent:name];
    }

    NSError *error = nil;
    if (![[NSFileManager defaultManager] moveItemAtURL:file toURL:destination error:&error]) {
        SCILogV(@"library: could not keep it — %@", error.localizedDescription);
        job.state = SCIYTJobStateFailed;
        job.failure = SCILocalized(@"dl_failed");
        [self changed];
        return;
    }

    job.fileName = name;
    job.bytes = (long long)[[[NSFileManager defaultManager]
        attributesOfItemAtPath:destination.path error:nil][NSFileSize] longLongValue];
    job.progress = 1;
    job.state = SCIYTJobStateDone;

    [self save];
    [self changed];

    // Only if it was asked for. Saving to Photos used to be the one ending a download
    // could have, and that is what this whole screen exists to undo.
    if (SCIPrefEnabled(SCIPrefAutoPhotos)) {
        [self export:job completion:^(BOOL ok, NSString *detail) {
            //
            // **"Remove after saving to Photos" was honoured by one door of two.** The swipe
            // action read the switch; this automatic copy never did -- so somebody with both
            // switches on got Photos and a Centre that kept everything, which is exactly the
            // two copies the switch exists to prevent. One question, and the answer now comes
            // from the same place whichever way the copy was made.
            //
            // The switch's own default stays off, deliberately: a removal cannot be undone.
            // What changed is only that turning it on means the same thing everywhere.
            //
            if (ok) {
                if (SCIPrefEnabled(SCIPrefTidyAfterPhotos)) {
                    [SCIYTThumbnails forget:job];
                    [self remove:job];
                }
                return;
            }

            // Written where somebody is looking, not only to the log. This is the whole
            // of "it does not save to Photos": the copy was asked for, it was refused,
            // and the only record of that was a log line no report carries.
            SCILogV(@"library: automatic export refused — %@", detail);
            job.exportFailure = detail.length ? detail : SCILocalized(@"dl_failed");
            [self save];
            [self changed];
        }];
    }
}

// MARK: - Afterwards

- (BOOL)rename:(SCIYTJob *)job to:(NSString *)title {
    NSURL *from = [job fileURL];
    if (!from || !title.length) return NO;

    // Cleaned the same way -adopt:for: cleans a title, because it is the same problem: this
    // becomes a file name, and a file name cannot hold a slash whoever typed it.
    NSMutableCharacterSet *illegal =
        [NSMutableCharacterSet characterSetWithCharactersInString:@"/\?%*|\"<>:"];
    [illegal formUnionWithCharacterSet:[NSCharacterSet controlCharacterSet]];
    [illegal formUnionWithCharacterSet:[NSCharacterSet newlineCharacterSet]];

    NSString *safe = [[title componentsSeparatedByCharactersInSet:illegal]
                      componentsJoinedByString:@" "];
    safe = [safe stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (!safe.length) return NO;
    if (safe.length > 80) safe = [safe substringToIndex:80];

    NSString *extension = from.pathExtension.length ? from.pathExtension : @"mp4";
    NSString *name = [safe stringByAppendingPathExtension:extension];
    NSURL *to = [[SCIYTLibrary folder] URLByAppendingPathComponent:name];

    if ([name isEqualToString:job.fileName]) {
        // The name on disk is unchanged, but the title shown may not be -- someone can edit
        // punctuation this strips. Recorded rather than refused.
        job.title = safe;
        [self save];
        [self changed];
        return YES;
    }

    if ([[NSFileManager defaultManager] fileExistsAtPath:to.path]) return NO;

    NSError *error = nil;
    if (![[NSFileManager defaultManager] moveItemAtURL:from toURL:to error:&error]) {
        SCILogV(@"library: could not rename — %@", error.localizedDescription);
        return NO;
    }

    job.fileName = name;
    job.title = safe;
    [self save];
    [self changed];
    return YES;
}

- (SCIYTJob *)existingJobForVideo:(NSString *)videoID kind:(SCIYTJobKind)kind {
    if (!videoID.length) return nil;

    for (SCIYTJob *job in self.store) {
        // Finished only. A failed attempt is not a copy, and one still running is handled
        // by the caller as a different question -- "it is already downloading" and "you
        // already have it" want different sentences.
        if (job.state != SCIYTJobStateDone) continue;
        if (job.kind != kind) continue;
        if (![job.videoID isEqualToString:videoID]) continue;
        if (![job fileURL]) continue;

        return job;
    }
    return nil;
}

- (void)remove:(SCIYTJob *)job {
    NSURL *file = [job fileURL];
    if (file) [[NSFileManager defaultManager] removeItemAtURL:file error:nil];

    [self.store removeObject:job];
    [self save];
    [self changed];
}

/// Names *which* refusal came back, because three of them need three different answers
/// and one sentence covered all of them.
///
/// **YouTube declares no reason to add to Photos**, measured from a real 21.34.3
/// Info.plist: `NSPhotoLibraryUsageDescription` is there for uploading and
/// `NSPhotoLibraryAddUsageDescription` is absent. iOS falls back to the reading key for
/// an add-only request, so the prompt somebody sees says "upload media you've already
/// created" -- which reads as nothing to do with saving a download, and a Don't Allow
/// tapped once is remembered for good. That makes `denied` the likely one here, and it
/// is fixed in iOS Settings; `restricted` cannot be fixed by the user at all; and
/// `notDetermined` coming back means the prompt never appeared, which is a different
/// investigation again.
static NSString *SCIYTPhotosRefusal(PHAuthorizationStatus status) {
    NSString *name;
    switch (status) {
        case PHAuthorizationStatusDenied:       name = @"denied"; break;
        case PHAuthorizationStatusRestricted:   name = @"restricted"; break;
        case PHAuthorizationStatusNotDetermined: name = @"not determined"; break;
        default:                                name = @"unavailable"; break;
    }
    return [NSString stringWithFormat:@"%@ (%@)", SCILocalized(@"dl_no_permission"), name];
}

- (void)export:(SCIYTJob *)job completion:(void (^)(BOOL, NSString *))completion {
    void (^done)(BOOL, NSString *) = ^(BOOL ok, NSString *detail) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(ok, detail); });
    };

    NSURL *file = [job fileURL];
    if (!file) { done(NO, SCILocalized(@"dl_failed")); return; }

    // Sound has no place in Photos: the library holds pictures and videos, and an
    // audio-only file is refused with an error that says nothing useful. Said here
    // instead, before the refusal.
    if (job.kind == SCIYTJobKindAudio) { done(NO, SCILocalized(@"dl_audio_not_photos")); return; }

    // The host app has to have declared a reason, and YouTube need not have. Asking
    // without one does not fail -- iOS ends the process. Established in 0.12.1.
    NSBundle *host = [NSBundle mainBundle];
    if (![host objectForInfoDictionaryKey:@"NSPhotoLibraryAddUsageDescription"] &&
        ![host objectForInfoDictionaryKey:@"NSPhotoLibraryUsageDescription"]) {
        done(NO, SCILocalized(@"dl_no_photos_access"));
        return;
    }

    [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly
                                               handler:^(PHAuthorizationStatus status) {
        if (status != PHAuthorizationStatusAuthorized && status != PHAuthorizationStatusLimited) {
            done(NO, SCIYTPhotosRefusal(status));
            return;
        }

        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:file];
        } completionHandler:^(BOOL success, NSError *error) {
            // Ours is not deleted. That is the difference: Photos gets a copy, and the
            // original stays where the user can still reach it.
            if (success) {
                // Photos answers on its own queue, and -save walks the store. Same reason
                // as -adopt:for: -- the store has one thread.
                dispatch_async(dispatch_get_main_queue(), ^{
                    job.exported = YES;
                    job.exportFailure = nil;
                    [self save];
                    [self changed];
                });
            } else {
                SCILogV(@"library: Photos refused it — %@", error.localizedDescription);
            }
            done(success, success ? nil : SCILocalized(@"dl_failed"));
        }];
    }];
}

- (long long)totalBytes {
    long long total = 0;
    for (SCIYTJob *job in self.store) total += job.bytes;
    return total;
}

@end
