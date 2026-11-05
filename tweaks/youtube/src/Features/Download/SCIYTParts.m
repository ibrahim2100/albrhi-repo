#import "SCIYTParts.h"
#import "../../Prefs.h"
#import "../../SCILog.h"
#import "../../Localization/SCILocalize.h"
#import "../../Diagnostics/SCIYTDiagnostics.h"
#import "SCIYTConcurrency.h"
#import "SCIYTFailure.h"

/// How many parts the system is asked to run at once.
///
/// Four, and the number is a compromise rather than a maximum. Google serves these happily
/// enough in parallel, but a phone on a weak connection sharing its bandwidth four ways makes
/// each individual part slower and likelier to time out -- and a timeout costs a retry, which
/// costs more than the parallelism saved.
//
// **Four was a tested constant, and it is now a floor rather than the answer.**
//
// An HLS playlist is a few hundred segments, so this number is the largest single lever on how
// long a download takes -- and the right value is a property of somebody's network, not of this
// source. Google's servers may throttle a client that opens too many connections, which is not
// measurable from a build machine, so it is asked rather than decided: the settings row offers
// 4, 6 and 8, and an unset preference keeps exactly the behaviour that has been shipping.
//
// Now learned across downloads (SCIYTConcurrency): the person's own choice in Settings stands when
// they made one, else it is what the last runs measured, four before any.
static NSUInteger sciSessionParallel = 4;     // what the session in use was made with
static NSUInteger SCIParallel(void) { return [SCIYTConcurrency parallelism]; }

/// How many times one part is asked for before the run gives up.
static const NSUInteger kSCIAttempts = 3;


///
/// One run's state.
///
/// A class rather than captured variables, because several callbacks touch this at once and
/// they must be looking at the same thing. Every field is read and written on one serial
/// queue, which is what makes "several at a time" safe to reason about.
///
@interface SCIYTPartsRun : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, strong) NSArray<NSString *> *addresses;
@property (nonatomic, strong) NSURL *folder;
@property (nonatomic, strong) NSMutableArray *files;        ///< indexed like addresses
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *attempts;

@property (nonatomic) NSUInteger completed;
@property (nonatomic) NSTimeInterval startedAt;       ///< when the first part of this attempt was asked for
@property (nonatomic) long long fetchedBytes;         ///< what this attempt fetched (not what was already on disk)
@property (nonatomic) BOOL finished;

/// Which attempt at this run these tasks belong to. A run restarted under the same identifier
/// (a download resumed after the app was closed) must not hear from the tasks of the attempt
/// it replaced: they are cancelled, and their cancellation would otherwise look like a failure.
@property (nonatomic, copy) NSString *generation;

/// Whether the parts are kept on failure, for a later resume. A persistent run's folder is the
/// only record of what has already arrived, so a failure leaves it alone; the owner of the run
/// removes it when the job is finished or abandoned.
@property (nonatomic) BOOL persistent;
@property (nonatomic, strong) NSArray<NSNumber *> *sizes;

@property (nonatomic, copy) void (^progress)(double);
@property (nonatomic, copy) void (^completion)(NSArray<NSURL *> *, NSURL *, NSString *);
@end

@implementation SCIYTPartsRun
@end


@interface SCIYTParts () <NSURLSessionDownloadDelegate>
@end


@implementation SCIYTParts

/// The runs in flight, by identifier, and the queue that owns them.
static NSMutableDictionary<NSString *, SCIYTPartsRun *> *sciRuns = nil;
static dispatch_queue_t sciLock = nil;

+ (void)initialize {
    if (self != [SCIYTParts class]) return;
    sciRuns = [NSMutableDictionary dictionary];
    sciLock = dispatch_queue_create("com.albrhi.youtube.parts", DISPATCH_QUEUE_SERIAL);
}

+ (instancetype)shared {
    static SCIYTParts *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[SCIYTParts alloc] init]; });
    return shared;
}

///
/// A background session, which is the whole point of this file's second draft.
///
/// The first used an ordinary session and completion blocks, and an ordinary session belongs
/// to the app: leave YouTube, lock the phone, or take a call, and iOS suspends the process
/// and every transfer with it. A ninety-part video therefore required standing in the app
/// watching a progress bar, which is not what having a download manager is for.
///
/// A background session is run by the system instead. The transfers continue while YouTube is
/// suspended, and the app is woken to be told about them. That is the entire difference, and
/// it costs three things:
///
///   * download tasks rather than data tasks, since a background session supports no others;
///   * a delegate rather than completion blocks, for the same reason;
///   * every task enqueued at once, because the system schedules them and knows better than
///     a hand-rolled loop does what the radio and the battery can afford.
///
/// **What it does not do is survive the app being killed.** iOS would relaunch YouTube to
/// deliver the events, and the run this object is holding would be gone -- so a part arriving
/// for a run nobody remembers is discarded and the scratch sweep clears up after it. Carrying
/// the state on disk to survive that is a real piece of work with a real chance of leaving a
/// half-written video looking finished, and the case it buys -- force-quitting the app you
/// are downloading in -- is not the one anybody complained about.
///
static BOOL sciForegroundForHarness = NO;

/// For the simulator harness only: the simulator has no `nsurlsessiond`, so a background session
/// cannot be made there at all. An ordinary session answers through the same delegate, which is
/// enough to test what the parts fetcher itself decides -- what is kept, what is fetched again.
/// It does not test the system delivering parts while the app is dead; that needs a device.
+ (void)useForegroundSessionForHarness { sciForegroundForHarness = YES; }

+ (NSURLSession *)session {
    static NSURLSession *session = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSURLSessionConfiguration *configuration = sciForegroundForHarness
            ? [NSURLSessionConfiguration defaultSessionConfiguration]
            : [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:
                @"com.albrhi.youtube.downloads"];

        // Enough for the parts in flight and no more.
        sciSessionParallel = SCIParallel();
        configuration.HTTPMaximumConnectionsPerHost = sciSessionParallel;
        configuration.timeoutIntervalForRequest = 60;

        // Not discretionary: this was asked for by a person who is watching a progress bar,
        // not a sync that can wait for a charger and Wi-Fi. Left at the default, iOS would
        // feel free to hold the whole thing until it judged the moment convenient.
        configuration.discretionary = NO;
        configuration.sessionSendsLaunchEvents = YES;

        session = [NSURLSession sessionWithConfiguration:configuration
                                                delegate:[self shared]
                                           delegateQueue:nil];
    });
    return session;
}

+ (NSURL *)resumableRoot {
    static NSURL *root = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSURL *support = [[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                                                  inDomains:NSUserDomainMask] firstObject];
        root = [support URLByAppendingPathComponent:@"AlbrhiPartial" isDirectory:YES];
        [[NSFileManager defaultManager] createDirectoryAtURL:root withIntermediateDirectories:YES attributes:nil error:nil];

        // Not part of a backup: it is a cache of bytes that can be fetched again, and a phone
        // backing up half a video helps nobody.
        [root setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
    });
    return root;
}

+ (NSURL *)folderForRun:(NSString *)identifier {
    return [[self resumableRoot] URLByAppendingPathComponent:identifier isDirectory:YES];
}

+ (void)fetch:(NSArray<NSString *> *)addresses
     progress:(void (^)(double))progress
   completion:(void (^)(NSArray<NSURL *> *, NSURL *, NSString *))completion {
    [self fetch:addresses sizes:nil runIdentifier:nil progress:progress completion:completion];
}

+ (void)fetch:(NSArray<NSString *> *)addresses
        sizes:(NSArray<NSNumber *> *)sizes
runIdentifier:(NSString *)persistentIdentifier
     progress:(void (^)(double))progress
   completion:(void (^)(NSArray<NSURL *> *, NSURL *, NSString *))completion {

    if (!addresses.count) {
        completion(nil, nil, SCILocalized(@"dl_hls_no_segments"));
        return;
    }

    BOOL persistent = persistentIdentifier.length > 0;
    NSString *identifier = persistent ? persistentIdentifier : [[NSUUID UUID] UUIDString];
    NSURL *folder = persistent ? [self folderForRun:identifier]
                               : [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:identifier]];

    NSError *error = nil;
    [[NSFileManager defaultManager] createDirectoryAtURL:folder
                             withIntermediateDirectories:YES
                                              attributes:nil
                                                   error:&error];
    if (error) {
        completion(nil, nil, SCILocalized(@"dl_failed"));
        return;
    }

    SCIYTPartsRun *run = [[SCIYTPartsRun alloc] init];
    run.identifier = identifier;
    run.addresses = addresses;
    run.folder = folder;
    run.files = [NSMutableArray arrayWithCapacity:addresses.count];
    run.attempts = [NSMutableDictionary dictionary];
    run.progress = progress;
    run.completion = completion;
    run.persistent = persistent;
    run.sizes = (sizes.count == addresses.count) ? sizes : nil;
    run.generation = [[[NSUUID UUID] UUIDString] substringToIndex:8];

    // Filled with placeholders so a part can be written at its own index whenever it lands.
    // This is the ordering guarantee in one line: the slot is decided before the request is
    // made, so arrival order cannot reach it.
    for (NSUInteger i = 0; i < addresses.count; i++) [run.files addObject:[NSNull null]];

    dispatch_async(sciLock, ^{
        // What already arrived, on an earlier attempt or while the app was closed. A part counts
        // only when it is there *and* the right size: a rename into place is atomic, but a size
        // that disagrees with the plan means the plan changed under it, and bytes of the wrong
        // plan are worse than bytes not yet fetched.
        if (persistent) {
            for (NSUInteger i = 0; i < addresses.count; i++) {
                NSURL *file = [SCIYTParts partFile:i inFolder:folder];
                NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:file.path error:nil];
                if (!attributes) continue;

                BOOL right = !run.sizes || [attributes fileSize] == (unsigned long long)[run.sizes[i] longLongValue];
                if (right) { run.files[i] = file; run.completed += 1; }
                else [[NSFileManager defaultManager] removeItemAtURL:file error:nil];
            }
        }

        // A run restarted under the same name replaces the tasks of the one before it.
        if (persistent) [SCIYTParts cancelSystemTasksOfRun:identifier];

        sciRuns[identifier] = run;

        if (run.completed >= addresses.count) { [SCIYTParts finishRun:run]; return; }

        if (run.progress && run.completed) {
            double fraction = (double)run.completed / (double)addresses.count;
            dispatch_async(dispatch_get_main_queue(), ^{ run.progress(fraction); });
        }

        run.startedAt = [NSDate date].timeIntervalSince1970;
        for (NSUInteger i = 0; i < addresses.count; i++) {
            if (![run.files[i] isKindOfClass:[NSNull class]]) continue;
            [self startPart:i of:run];
        }
    });

    SCILogV(@"parts: %lu queued in the background session", (unsigned long)addresses.count);
}

/// Queues one part. Called on the run's queue.
+ (void)startPart:(NSUInteger)index of:(SCIYTPartsRun *)run {
    NSURL *url = [NSURL URLWithString:run.addresses[index]];
    if (!url) { [self failRun:run with:SCILocalized(@"dl_failed")]; return; }

    NSURLSessionDownloadTask *task = [[self session] downloadTaskWithURL:url];

    // The run and the slot, on the task itself. A background session hands its tasks back
    // through a delegate with no context of ours attached, so the only way to know what a
    // finished file is *for* is to have written it on the task when it was made.
    task.taskDescription = [NSString stringWithFormat:@"%@|%lu|%@",
                            run.identifier, (unsigned long)index, run.generation];
    [task resume];
}

/// Reads the run and slot back off a task.
+ (SCIYTPartsRun *)runForTask:(NSURLSessionTask *)task index:(NSUInteger *)indexOut {
    NSArray<NSString *> *parts = [task.taskDescription componentsSeparatedByString:@"|"];
    if (parts.count != 3) return nil;

    *indexOut = (NSUInteger)[parts[1] integerValue];
    SCIYTPartsRun *run = sciRuns[parts[0]];

    // A task of an attempt that has been replaced is not this run's to count.
    return (run && [run.generation isEqualToString:parts[2]]) ? run : nil;
}

+ (NSURL *)partFile:(NSUInteger)index inFolder:(NSURL *)folder {
    // Zero padded, because part 10 sorts before part 9 as text and the join reads names.
    return [folder URLByAppendingPathComponent:[NSString stringWithFormat:@"%06lu.part", (unsigned long)index]];
}

/// Cancels whatever the system is still doing for a run, before it is started again. Their
/// cancellations arrive carrying the old generation and are ignored.
+ (void)cancelSystemTasksOfRun:(NSString *)identifier {
    NSString *prefix = [identifier stringByAppendingString:@"|"];
    [[self session] getTasksWithCompletionHandler:^(NSArray *data, NSArray *uploads, NSArray<NSURLSessionDownloadTask *> *downloads) {
        for (NSURLSessionDownloadTask *task in downloads) {
            if ([task.taskDescription hasPrefix:prefix]) [task cancel];
        }
    }];
}

/// Stops a persistent run for good: its tasks, its folder, and its place in memory.
+ (void)abandonRun:(NSString *)identifier {
    if (!identifier.length) return;
    dispatch_async(sciLock, ^{
        SCIYTPartsRun *run = sciRuns[identifier];
        if (run) { run.finished = YES; [sciRuns removeObjectForKey:identifier]; }
        [SCIYTParts cancelSystemTasksOfRun:identifier];
        [[NSFileManager defaultManager] removeItemAtURL:[SCIYTParts folderForRun:identifier] error:nil];
    });
}

/// What of a run is on disk, in parts and bytes -- for a row that says "resuming".
+ (NSUInteger)partsOnDiskForRun:(NSString *)identifier {
    NSArray *names = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self folderForRun:identifier].path error:nil];
    NSUInteger n = 0;
    for (NSString *name in names) if ([name hasSuffix:@".part"]) n++;
    return n;
}

/// Ends a run whose parts are all present. Called on the run's queue.
+ (void)finishRun:(SCIYTPartsRun *)run {
    if (run.finished) return;
    run.finished = YES;
    [sciRuns removeObjectForKey:run.identifier];

    // How fast this run went, at the parallelism it had, so the next session can start better.
    if (run.startedAt > 0 && run.fetchedBytes > 0) {
        [SCIYTConcurrency recordRunBytes:run.fetchedBytes seconds:[NSDate date].timeIntervalSince1970 - run.startedAt used:sciSessionParallel];
    }

    NSArray<NSURL *> *ordered = [run.files copy];
    NSURL *folder = run.folder;
    void (^done)(NSArray<NSURL *> *, NSURL *, NSString *) = run.completion;
    if (done) dispatch_async(dispatch_get_main_queue(), ^{ done(ordered, folder, nil); });
}

/// Ends a run once, and clears up. Called on the run's queue.
+ (void)failRun:(SCIYTPartsRun *)run with:(NSString *)message {
    if (!run || run.finished) return;
    run.finished = YES;

    [sciRuns removeObjectForKey:run.identifier];

    // A persistent run's parts are what a retry resumes from, so they stay.
    if (!run.persistent) [[NSFileManager defaultManager] removeItemAtURL:run.folder error:nil];
    else [SCIYTParts cancelSystemTasksOfRun:run.identifier];

    void (^done)(NSArray<NSURL *> *, NSURL *, NSString *) = run.completion;
    if (done) dispatch_async(dispatch_get_main_queue(), ^{ done(nil, nil, message); });
}

// MARK: - What the session tells us

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)task
didFinishDownloadingToURL:(NSURL *)location {

    // Moved here and not later. The file at this URL is deleted the moment this method
    // returns, which is the one rule of this delegate and the one that is easy to miss.
    NSError *error = nil;
    NSURL *staged = [location URLByAppendingPathExtension:@"staged"];
    [[NSFileManager defaultManager] moveItemAtURL:location toURL:staged error:&error];
    if (error) return;

    dispatch_async(sciLock, ^{
        NSUInteger index = 0;
        SCIYTPartsRun *run = [SCIYTParts runForTask:task index:&index];

        // A part for a run nobody is running -- the app was closed and relaunched to be told
        // about it, or the attempt it belonged to was replaced. If it belongs to a download that
        // can be resumed its folder exists, and the part is filed there: the next attempt then
        // finds it already fetched. Anything else has nowhere to go.
        if (!run || run.finished || index >= run.addresses.count) {
            NSArray<NSString *> *fields = [task.taskDescription componentsSeparatedByString:@"|"];
            NSURL *folder = (fields.count == 3 && [fields[0] length]) ? [SCIYTParts folderForRun:fields[0]] : nil;
            BOOL isDirectory = NO;
            if (folder && [[NSFileManager defaultManager] fileExistsAtPath:folder.path isDirectory:&isDirectory] && isDirectory) {
                NSURL *target = [SCIYTParts partFile:(NSUInteger)[fields[1] integerValue] inFolder:folder];
                if (![[NSFileManager defaultManager] fileExistsAtPath:target.path]) {
                    [[NSFileManager defaultManager] moveItemAtURL:staged toURL:target error:nil];
                    return;
                }
            }
            [[NSFileManager defaultManager] removeItemAtURL:staged error:nil];
            return;
        }

        // A download task also "finishes" when the server answered with an error: the body of a 403 or
        // a 429 lands here as an ordinary file. Taking it for a part corrupts the join and surfaces
        // much later as a size mismatch with no reason; it is a failed attempt and is treated as one.
        NSInteger status = [task.response isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)task.response).statusCode : 0;
        unsigned long long arrived = [[[NSFileManager defaultManager] attributesOfItemAtPath:staged.path error:nil] fileSize];
        BOOL wrongSize = run.sizes && arrived != (unsigned long long)[run.sizes[index] longLongValue];
        if (status >= 400 || wrongSize) {
            [[NSFileManager defaultManager] removeItemAtURL:staged error:nil];
            [SCIYTParts retryOrFailPart:index of:run status:status note:wrongSize
                ? [NSString stringWithFormat:@"part %lu arrived as %llu bytes, expected %lld", (unsigned long)index + 1, arrived, [run.sizes[index] longLongValue]]
                : nil];
            return;
        }
        run.fetchedBytes += (long long)arrived;

        NSURL *file = [SCIYTParts partFile:index inFolder:run.folder];

        [[NSFileManager defaultManager] removeItemAtURL:file error:nil];

        NSError *moveError = nil;
        [[NSFileManager defaultManager] moveItemAtURL:staged toURL:file error:&moveError];
        if (moveError) {
            [SCIYTParts failRun:run with:SCILocalized(@"dl_ts_write_failed")];
            return;
        }

        if ([run.files[index] isKindOfClass:[NSNull class]]) {
            run.files[index] = file;
            run.completed += 1;
        }

        if (run.progress) {
            double fraction = (double)run.completed / (double)run.addresses.count;
            dispatch_async(dispatch_get_main_queue(), ^{ run.progress(fraction); });
        }

        if (run.completed < run.addresses.count) return;
        [SCIYTParts finishRun:run];
    });
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {

    if (!error) return;   // the success path is handled above

    NSInteger status = [task.response isKindOfClass:[NSHTTPURLResponse class]]
        ? ((NSHTTPURLResponse *)task.response).statusCode : 0;

    dispatch_async(sciLock, ^{
        NSUInteger index = 0;
        SCIYTPartsRun *run = [SCIYTParts runForTask:task index:&index];
        if (!run || run.finished || index >= run.addresses.count) return;
        [SCIYTParts retryOrFailPart:index of:run status:status note:error.localizedDescription];
    });
}

/// One part did not arrive: ask again after a pause, or end the run. Called on the run's queue.
///
/// A refusal that means "slow down" (429, 503) is worth asking again, later, and tells the parallelism
/// learner to ask for fewer connections next time. A refusal that means "this address is no good" (403,
/// 410: it has expired) is not -- asking three times makes the same mistake more slowly.
+ (void)retryOrFailPart:(NSUInteger)index of:(SCIYTPartsRun *)run status:(NSInteger)status note:(NSString *)note {
    if (run.finished) return;

    NSUInteger tried = [run.attempts[@(index)] unsignedIntegerValue] + 1;
    run.attempts[@(index)] = @(tried);

    BOOL throttled = (status == 429 || status == 503);
    if (throttled) [SCIYTConcurrency recordThrottle];

    BOOL worthRetrying = throttled || status < 400 || status >= 500;
    if (worthRetrying && tried < kSCIAttempts + (throttled ? 2 : 0)) {
        double pause = throttled ? 3.0 * (double)tried : 0.5 * (double)tried;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(pause * NSEC_PER_SEC)), sciLock, ^{
            if (!run.finished) [SCIYTParts startPart:index of:run];
        });
        return;
    }

    [SCIYTDiagnostics recordStreamAttempt:
        [NSString stringWithFormat:@"parts: %lu of %lu failed after %lu tries — %@",
            (unsigned long)(index + 1), (unsigned long)run.addresses.count, (unsigned long)tried,
            note.length ? note : [NSString stringWithFormat:@"HTTP %ld", (long)status]]];

    NSString *sentence = [SCIYTFailure causeForText:note status:status] != SCIYTFailureUnknown
        ? [SCIYTFailure messageForCause:[SCIYTFailure causeForText:note status:status]]
        : (note.length ? note : SCILocalized(@"dl_failed"));
    [SCIYTParts failRun:run with:sentence];
}

// MARK: - Joining

+ (NSURL *)join:(NSArray<NSURL *> *)ordered
      extension:(NSString *)extension
         folder:(NSURL *)folder {

    NSURL *joined = [NSURL fileURLWithPath:
        [NSTemporaryDirectory() stringByAppendingPathComponent:
            [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:extension]]];

    [[NSFileManager defaultManager] createFileAtPath:joined.path contents:nil attributes:nil];
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingToURL:joined error:nil];

    if (!handle) {
        if (folder) [[NSFileManager defaultManager] removeItemAtURL:folder error:nil];
        return nil;
    }

    BOOL ok = YES;
    for (NSURL *file in ordered) {
        if (![file isKindOfClass:[NSURL class]]) { ok = NO; break; }

        // Mapped rather than read: one part is a few megabytes, and mapping lets the system
        // page it rather than the process holding it.
        NSData *part = [NSData dataWithContentsOfURL:file
                                             options:NSDataReadingMappedIfSafe
                                               error:nil];
        if (!part.length) { ok = NO; break; }

        @try {
            [handle writeData:part];
        } @catch (NSException *exception) {
            SCILogV(@"parts: could not write — %@", exception.reason);
            ok = NO;
            break;
        }
    }

    [handle closeFile];

    // A nil folder is "do not touch it": several joins read one run's parts in turn, and the
    // first of them removing the folder took the others' parts with it.
    if (folder) [[NSFileManager defaultManager] removeItemAtURL:folder error:nil];

    if (!ok) {
        [[NSFileManager defaultManager] removeItemAtURL:joined error:nil];
        return nil;
    }

    return joined;
}

@end
