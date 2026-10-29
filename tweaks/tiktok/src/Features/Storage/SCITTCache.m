//
//  SCITTCache.m
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCITTCache.h"
#import "../../Prefs.h"
#import "../../SCILog.h"

///
/// **What a cache clean should and should not do, written from what NA9 for TikTok does and from where it goes wrong.**
///
/// NA9 (closed, unlicensed; its binary was read with REA on 2026-10-29, nothing copied) has a switch "Clear cache at startup" and a button
/// "Clear cache". The read, in what it actually does:
///
///   * The switch's constructor runs when the dylib loads -- before TikTok's own code -- and, when `na9_autoclear_cache` is on, dispatches
///     `+[TTKHelperTools clearCache:NO]` to a global queue. **On a background thread, concurrently with TikTok starting up.**
///   * `+cachePaths` is three folders: `Library/Caches`, `Library/Application Support/gurd_cache` and `tmp`.
///   * `clearCache:` lists each folder and removes every entry in it (`contentsOfDirectoryAtPath:`, `removeItemAtPath:`). With the flag NO
///     (the launch pass) it skips the folder named `gurd_cache`; with YES (the button) it does not.
///
/// Three things this file does differently, each for a reason:
///
///   1. **It does not delete in place.** Removing a gigabyte of small files takes seconds, and every file TikTok reaches for in that time is
///      a race. Each top-level entry is *renamed* into one trash folder inside `tmp` (instant, on the same volume) and the trash is emptied
///      afterwards, on a utility queue. A rename is also what makes a pass that dies half-way harmless: the next one empties what is left.
///   2. **It leaves alone what was written after it began.** The launch pass skips an entry modified since the process started; the button
///      skips one written in the last twenty seconds. Whatever TikTok is writing *now* is not "cache that has been sitting there".
///   3. **It can wait until the cache is worth cleaning.** A cleaning at every launch also throws away the videos TikTok has just preloaded
///      for the first swipes, so the first scrolls of every session are slower and use the mobile network again. "Only when over N MB" keeps
///      what the cache is for and still ends the growth that fills a phone.
///
/// `gurd_cache` is not touched at all: what it holds is not known from here, and a folder somebody else owns is not cleaned on a guess.
/// Its size is in the report so that the next decision is made on a number.
///
/// **Not run on a device.**
///

NSNotificationName const SCITTCacheDidChange = @"AlbrhiTTCacheDidChange";

static NSString *const kSCITTTrashName = @"albrhi-trash";

static NSDate *sciLaunchAt = nil;
static unsigned long long sciCachesBytes = 0, sciTempBytes = 0, sciGurdBytes = 0;
static BOOL sciSizeKnown = NO;
static CFAbsoluteTime sciSizeAt = 0;
static NSString *sciLastPass = nil;
static NSUInteger sciPasses = 0, sciSkippedBelow = 0;

static dispatch_queue_t SCITTCacheQueue(void) {
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, 0);
        queue = dispatch_queue_create("albrhi.tt.cache", attr);
    });
    return queue;
}

static NSString *SCITTCachesPath(void) {
    return NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
}

static NSString *SCITTTempPath(void) {
    NSString *path = NSTemporaryDirectory();
    return path.length > 1 && [path hasSuffix:@"/"] ? [path substringToIndex:path.length - 1] : path;
}

static NSString *SCITTGurdPath(void) {
    NSString *support = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
    return [support stringByAppendingPathComponent:@"gurd_cache"];
}

static NSString *SCITTTrashPath(void) {
    return [SCITTTempPath() stringByAppendingPathComponent:kSCITTTrashName];
}

static unsigned long long SCITTSizeOf(NSString *path) {
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL directory = NO;
    if (![fm fileExistsAtPath:path isDirectory:&directory]) return 0;

    if (!directory) {
        NSDictionary *attributes = [fm attributesOfItemAtPath:path error:NULL];
        return [attributes fileSize];
    }

    unsigned long long total = 0;
    NSDirectoryEnumerator *walk = [fm enumeratorAtURL:[NSURL fileURLWithPath:path]
                           includingPropertiesForKeys:@[NSURLTotalFileAllocatedSizeKey, NSURLIsRegularFileKey]
                                              options:0
                                         errorHandler:^BOOL(NSURL *url, NSError *error) { return YES; }];
    for (NSURL *url in walk) {
        NSNumber *regular = nil, *size = nil;
        [url getResourceValue:&regular forKey:NSURLIsRegularFileKey error:NULL];
        if (!regular.boolValue) continue;
        [url getResourceValue:&size forKey:NSURLTotalFileAllocatedSizeKey error:NULL];
        total += size.unsignedLongLongValue;
    }
    return total;
}

/// What a folder holds except the trash and what this tweak keeps for itself.
static BOOL SCITTKeepsEntry(NSString *name) {
    return [name isEqualToString:kSCITTTrashName] || [name hasPrefix:@"albrhi"];
}

static unsigned long long SCITTSizeOfFolder(NSString *root) {
    NSArray<NSString *> *names = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:root error:NULL];
    unsigned long long total = 0;
    for (NSString *name in names) {
        if (SCITTKeepsEntry(name)) continue;
        total += SCITTSizeOf([root stringByAppendingPathComponent:name]);
    }
    return total;
}

static NSString *SCITTBytes(unsigned long long bytes) {
    return [NSByteCountFormatter stringFromByteCount:(long long)bytes countStyle:NSByteCountFormatterCountStyleFile];
}

static void SCITTCacheChanged(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:SCITTCacheDidChange object:nil];
    });
}

/// Empties the trash. Whatever is in it was renamed out of the cache already; nothing here is reachable by TikTok.
static void SCITTEmptyTrash(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *trash = SCITTTrashPath();
    for (NSString *name in [fm contentsOfDirectoryAtPath:trash error:NULL]) {
        [fm removeItemAtPath:[trash stringByAppendingPathComponent:name] error:NULL];
    }
}

/// One pass: renames every top-level entry of `Library/Caches` and `tmp` that was not modified after `cutoff` into the trash, then empties it.
/// Returns the bytes moved. Runs on the cache queue.
static unsigned long long SCITTSweep(NSDate *cutoff, NSUInteger *outEntries) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *trash = SCITTTrashPath();

    SCITTEmptyTrash();   // what an earlier pass that did not finish left behind
    [fm createDirectoryAtPath:trash withIntermediateDirectories:YES attributes:nil error:NULL];

    unsigned long long freed = 0;
    NSUInteger entries = 0;
    for (NSString *root in @[SCITTCachesPath(), SCITTTempPath()]) {
        for (NSString *name in [fm contentsOfDirectoryAtPath:root error:NULL]) {
            if (SCITTKeepsEntry(name)) continue;

            NSString *path = [root stringByAppendingPathComponent:name];
            NSDate *modified = [[fm attributesOfItemAtPath:path error:NULL] fileModificationDate];
            if (modified && [modified compare:cutoff] == NSOrderedDescending) continue;   // written since: it is in use, not cache

            unsigned long long bytes = SCITTSizeOf(path);
            NSString *target = [trash stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@", [[NSUUID UUID] UUIDString], name]];
            if ([fm moveItemAtPath:path toPath:target error:NULL] || [fm removeItemAtPath:path error:NULL]) {
                freed += bytes;
                entries++;
            }
        }
    }

    SCITTEmptyTrash();
    if (outEntries) *outEntries = entries;
    return freed;
}

void SCITTCacheRefreshSize(void) {
    // Called on the main thread (the settings page and the constructor), which is also where the sizes are written.
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (sciSizeKnown && now - sciSizeAt < 10) return;
    sciSizeAt = now;
    dispatch_async(SCITTCacheQueue(), ^{
        unsigned long long caches = SCITTSizeOfFolder(SCITTCachesPath());
        unsigned long long temp = SCITTSizeOfFolder(SCITTTempPath());
        unsigned long long gurd = SCITTSizeOf(SCITTGurdPath());
        dispatch_async(dispatch_get_main_queue(), ^{
            sciCachesBytes = caches; sciTempBytes = temp; sciGurdBytes = gurd; sciSizeKnown = YES;
            SCITTCacheChanged();
        });
    });
}

NSString *SCITTCacheSummary(void) {
    if (!sciSizeKnown) return @"…";
    return [NSString stringWithFormat:@"%@ · %@", SCITTBytes(sciCachesBytes), SCITTBytes(sciTempBytes)];
}

void SCITTCacheClearNow(void (^done)(unsigned long long)) {
    dispatch_async(SCITTCacheQueue(), ^{
        CFAbsoluteTime started = CFAbsoluteTimeGetCurrent();
        NSUInteger entries = 0;
        unsigned long long freed = SCITTSweep([NSDate dateWithTimeIntervalSinceNow:-20], &entries);

        unsigned long long caches = SCITTSizeOfFolder(SCITTCachesPath());
        unsigned long long temp = SCITTSizeOfFolder(SCITTTempPath());
        dispatch_async(dispatch_get_main_queue(), ^{
            sciPasses++;
            sciCachesBytes = caches; sciTempBytes = temp; sciSizeKnown = YES; sciSizeAt = CFAbsoluteTimeGetCurrent();
            sciLastPass = [NSString stringWithFormat:@"button — freed %@ (%lu entries) in %.2f s", SCITTBytes(freed),
                           (unsigned long)entries, CFAbsoluteTimeGetCurrent() - started];
            SCITTCacheChanged();
            if (done) done(freed);
        });
    });
}

void SCITTInstallCache(void) {
    sciLaunchAt = [NSDate date];

    // The choice is a threshold in megabytes: absent is off, the smallest value means every launch.
    double threshold = [[NSUserDefaults standardUserDefaults] doubleForKey:SCIPrefCacheAuto];
    if (threshold <= 0) {
        SCITTCacheRefreshSize();   // off: still measured, so the settings page and the report have a number
        return;
    }

    dispatch_async(SCITTCacheQueue(), ^{
        CFAbsoluteTime started = CFAbsoluteTimeGetCurrent();
        unsigned long long caches = SCITTSizeOfFolder(SCITTCachesPath());
        unsigned long long temp = SCITTSizeOfFolder(SCITTTempPath());
        unsigned long long gurd = SCITTSizeOf(SCITTGurdPath());

        if ((double)(caches + temp) < threshold * 1024.0 * 1024.0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                sciSkippedBelow++;
                sciCachesBytes = caches; sciTempBytes = temp; sciGurdBytes = gurd; sciSizeKnown = YES; sciSizeAt = CFAbsoluteTimeGetCurrent();
                sciLastPass = [NSString stringWithFormat:@"launch — left alone: %@ is under %.0f MB", SCITTBytes(caches + temp), threshold];
                SCITTCacheChanged();
            });
            return;
        }

        NSUInteger entries = 0;
        unsigned long long freed = SCITTSweep(sciLaunchAt, &entries);
        unsigned long long cachesAfter = SCITTSizeOfFolder(SCITTCachesPath());
        unsigned long long tempAfter = SCITTSizeOfFolder(SCITTTempPath());
        dispatch_async(dispatch_get_main_queue(), ^{
            sciPasses++;
            sciCachesBytes = cachesAfter; sciTempBytes = tempAfter; sciGurdBytes = gurd; sciSizeKnown = YES; sciSizeAt = CFAbsoluteTimeGetCurrent();
            sciLastPass = [NSString stringWithFormat:@"launch — freed %@ of %@ (%lu entries) in %.2f s", SCITTBytes(freed),
                           SCITTBytes(caches + temp), (unsigned long)entries, CFAbsoluteTimeGetCurrent() - started];
            SCITTCacheChanged();
        });
    });
}

NSString *SCITTCacheReport(void) {
    double threshold = [[NSUserDefaults standardUserDefaults] doubleForKey:SCIPrefCacheAuto];
    NSString *mode = threshold <= 0 ? @"off" : (threshold <= 1 ? @"every launch" : [NSString stringWithFormat:@"when over %.0f MB", threshold]);
    return [NSString stringWithFormat:@"choice: %@; now: Caches %@, temporary %@, gurd_cache %@ (never touched); passes %lu, left alone %lu; last: %@",
            mode,
            sciSizeKnown ? SCITTBytes(sciCachesBytes) : @"not measured", sciSizeKnown ? SCITTBytes(sciTempBytes) : @"not measured",
            sciSizeKnown ? SCITTBytes(sciGurdBytes) : @"not measured",
            (unsigned long)sciPasses, (unsigned long)sciSkippedBelow, sciLastPass ?: @"nothing yet this launch"];
}
