// The file sink for NULog, written only while the log switch is on (see NUShared.h).
//
// Why this exists: on the iOS 18 and iOS 26 test targets
// `oslog` on-device cannot decode our os_log format strings — every
// NULog comes out as `<compose failure [corrupt log]>`, which makes the display
// side effectively un-debuggable. The tweak spans six processes, so "attach a
// debugger" is not a practical substitute either.
//
// So every NULog also appends a plain line to a per-process file. The sink is
// chosen at first use from a candidate list, because the six injected processes
// do NOT share a writable directory: SpringBoard / MediaRemoteUI can write under
// /var/mobile, the App Store apps (Spotify, YouTube Music, …) are container-
// redirected and can only write inside their own sandbox. NSTemporaryDirectory()
// is the always-works fallback.
//
// Release (FINALPACKAGE) builds compile this to nothing.
#import "NUShared.h"
#import "NUPrefs.h"

/// Shared by every translation unit -- see NUApplySandbox() in NUShared.h for what having one
/// copy per unit actually cost.
BOOL gNUSandboxApplied = NO;
BOOL gNUSandboxAnnounced = NO;

///
/// Whether anything is written, read once per process from the tweak's own preferences.
///
/// **Once, deliberately.** A log switch is used by turning it on, reproducing the problem and
/// reading the file — reopening the app is already part of that, so re-reading the preference on
/// every line would buy nothing and put a preference read on a path that runs inside media
/// callbacks. And when the switch is off this is one already-decided BOOL, which is what makes
/// leaving the sinks compiled in cost nothing.
///
BOOL NULogEnabled(void) {
    static BOOL enabled = NO;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        enabled = NUPrefBool(@"verboseLogging", NO);
    });
    return enabled;
}

#ifdef NU_LOGGING

#import <pthread.h>

static NSString *gNULogPath = nil;
static pthread_mutex_t gNULogLock = PTHREAD_MUTEX_INITIALIZER;

///
/// **The file was append-only with no ceiling, and that is only harmless while the switch is off.**
///
/// `seekToEndOfFile` on every line, forever: turn the log on to chase something, forget it, and
/// SpringBoard -- which runs for days -- keeps appending a line per track change until the disk
/// notices. A diagnostic that can fill a phone is a bug of its own, and "the user will remember to
/// turn it off" is not a design.
///
/// 128 KB *per process*, because seven processes write one file each and the ceiling that matters is
/// the total: seven of them at half a megabyte was three and a half megabytes on a phone whose owner
/// asked for a megabyte at most. A session anybody reads is a few hundred lines. The check is a
/// `stat` every 64 lines rather than every line: the cost is then nothing while the log is on and
/// nothing at all while it is off.
///
/// Truncated rather than rotated. A second file is a second thing to find, ask for and delete, and
/// the interesting part of a log that has run this long is what it is doing *now* -- the truncation
/// says so in the file itself, so a short log is never mistaken for a quiet process.
///
static const unsigned long long kNULogMaxBytes = 128 * 1024;
static const int kNULogCheckEvery = 64;

// First writable candidate wins, and we remember it for the process lifetime.
// The shared /var/mobile/nu directory is preferred so the display-side logs
// (SpringBoard + MediaRemoteUI, the two that matter most for the UI work) land
// together in one place.
static NSString *NULogResolvePath(void) {
    NSString *proc = NSProcessInfo.processInfo.processName ?: @"unknown";
    proc = [proc stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    NSFileManager *fm = NSFileManager.defaultManager;

    NSString *shared = @"/var/mobile/nu";
    [fm createDirectoryAtPath:shared withIntermediateDirectories:YES attributes:nil error:NULL];
    for (NSString *dir in @[ shared, NSTemporaryDirectory() ?: @"/tmp" ]) {
        if (![fm isWritableFileAtPath:dir]) continue;
        NSString *p = [dir stringByAppendingPathComponent:
                       [NSString stringWithFormat:@"nextup3-%@.log", proc]];
        // isWritableFileAtPath on a directory is necessary but not sufficient
        // under the app sandboxes — prove it by actually creating the file.
        if ([fm fileExistsAtPath:p] || [fm createFileAtPath:p contents:nil attributes:nil]) return p;
    }
    return nil;
}

void NULogWritev(const char *cfmt, va_list ap) {
    if (!cfmt) return;
    @autoreleasepool {
        // os_log's annotations have no NSString equivalent; strip them so the
        // same literal format string works for both sinks.
        NSMutableString *fmt = [NSMutableString stringWithUTF8String:cfmt];
        for (NSString *ann in @[ @"%{public}", @"%{private}" ])
            [fmt replaceOccurrencesOfString:ann withString:@"%"
                                    options:0 range:NSMakeRange(0, fmt.length)];

        NSString *line = [[NSString alloc] initWithFormat:fmt arguments:ap];

        pthread_mutex_lock(&gNULogLock);
        if (!gNULogPath) gNULogPath = NULogResolvePath();
        NSString *path = gNULogPath;
        pthread_mutex_unlock(&gNULogLock);
        if (!path) return;

        static NSDateFormatter *df = nil;
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            df = [NSDateFormatter new];
            df.dateFormat = @"HH:mm:ss.SSS";
        });

        NSString *stamped = [NSString stringWithFormat:@"%@ [%d] %@\n",
                             [df stringFromDate:NSDate.date], getpid(), line];

        // Recreate the file if it vanished. The resolved path is cached for the
        // process lifetime, and a deploy cycle that clears /var/mobile/nu would
        // otherwise silence this process's logging until it restarts — which is
        // exactly when the log matters most (SpringBoard survives many deploys).
        NSFileManager *fm = NSFileManager.defaultManager;
        if (![fm fileExistsAtPath:path]) [fm createFileAtPath:path contents:nil attributes:nil];

        static int sinceCheck = 0;
        if (sinceCheck++ % kNULogCheckEvery == 0) {
            NSDictionary *attributes = [fm attributesOfItemAtPath:path error:NULL];
            if ([attributes fileSize] > kNULogMaxBytes) {
                NSString *note = [NSString stringWithFormat:
                    @"%@ [%d] --- log passed %lluKB, truncated ---\n",
                    [df stringFromDate:NSDate.date], getpid(), kNULogMaxBytes / 1024];
                [[note dataUsingEncoding:NSUTF8StringEncoding] writeToFile:path atomically:NO];
            }
        }

        NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
        if (!fh) return;
        @try {
            [fh seekToEndOfFile];
            [fh writeData:[stamped dataUsingEncoding:NSUTF8StringEncoding]];
        } @catch (__unused NSException *e) {
        } @finally {
            [fh closeFile];
        }
    }
}

#endif  // NU_LOGGING
