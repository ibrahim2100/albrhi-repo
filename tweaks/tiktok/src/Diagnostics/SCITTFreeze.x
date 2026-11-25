//
//  SCITTFreeze.x
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach/mach.h>
#import <pthread.h>
#import <dlfcn.h>
#import <stdatomic.h>
#import "SCITTFreeze.h"
#import "../Tweak.h"
#import "../SCILog.h"

///
/// **A freeze with no crash has two possible shapes and they need different cures, so the first job is to tell them apart.**
///
/// The report was: the picture and the sound go on, no button answers, and nothing is logged. That is either
///
///   * the **main thread is stuck** (a lock, a loop, a wait): the media threads carry on without it, the UI cannot. The stack of the main thread
///     says what it is standing in; or
///   * the **main thread is alive and the touches go nowhere**: a view or a window that swallows them, or a recogniser left switched off. Then the
///     main thread answers the ping at once and the answer is in *which view each touch landed on*.
///
/// So two things are kept. A timer on a background queue sends the main queue a one-line block every second; if the answer is three seconds late
/// while the app is active, the main thread is suspended for a few microseconds, its registers are read, the frame-pointer chain is followed
/// through its own stack (addresses only: **nothing is allocated and nothing is looked up while it is suspended**, because the thread may be
/// holding the allocator's lock), and it is resumed; the addresses are turned into `image+offset` afterwards. And every touch that begins
/// is noted on the main thread: the chain of views under the finger and the windows that exist, sixteen of them, in memory.
///
/// **Cost and what is written.** A one-second timer that posts a block that stores a number; the touch note is one hit test per touch. A file
/// (`Application Support/albrhi-freeze.txt`, one file, overwritten, at most 6 KB) is written only when a stall reaches five seconds, or when the app
/// is sent to the background right after several touches in a row landed on the very same view (the shape of taps that go nowhere). A report that
/// writes itself is a cost paid by everyone for a fault few have (CLAUDE.md §4.4); this one writes in the one situation it exists for.
///

static const double kSCITTStallSample1 = 3.0, kSCITTStallSample2 = 5.0, kSCITTStallSample3 = 8.0;
#define kSCITTRingSize 16
#define kSCITTMaxFrames 40
static NSObject *sciLock;   // guards sciSamples between the watchdog's queue and the main thread

static _Atomic(uint64_t) sciPingSentMs;        // when the outstanding ping was posted
static _Atomic(bool) sciPingOutstanding;
static _Atomic(bool) sciActive;
static _Atomic(uint64_t) sciActiveSinceMs;
static _Atomic(NSUInteger) sciPings;
static _Atomic(NSUInteger) sciStalls;          // answers that came 2 s or more late
static _Atomic(uint64_t) sciLongestStallMs;

static mach_port_t sciMainThread = MACH_PORT_NULL;
static pthread_t sciMainPThread = NULL;
static NSString *sciState = nil;
static NSString *sciSamples = nil;             // the last stall's samples, formatted
static NSString *sciPreviousFile = nil;        // what the previous launch left
static NSString *sciWrittenAs = nil;
static NSMutableArray<NSString *> *sciStallLog = nil;      // main thread only
static NSString *sciRing[kSCITTRingSize];                  // main thread only
static NSUInteger sciRingCount = 0;
static CFTimeInterval sciRingTimes[kSCITTRingSize];
static NSString *sciRingChains[kSCITTRingSize];
static NSUInteger sciDeadTapFiles = 0;

static uint64_t SCITTNowMs(void) {
    return clock_gettime_nsec_np(CLOCK_UPTIME_RAW) / 1000000ULL;
}

static NSString *SCITTFreezePath(void) {
    NSString *dir = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
    return [dir stringByAppendingPathComponent:@"albrhi-freeze.txt"];
}

#pragma mark - The main thread's stack, read from outside

typedef struct { uintptr_t frames[kSCITTMaxFrames + 2]; int count; BOOL ok; } SCITTStack;

/// Fills `out` with the program counter, the link register and the return addresses up the frame-pointer chain. **No Objective-C, no allocation, no
/// logging between the suspend and the resume.**
static void SCITTSampleMainThread(SCITTStack *out) {
    out->count = 0;
    out->ok = NO;
#if defined(__arm64__)
    if (sciMainThread == MACH_PORT_NULL || !sciMainPThread) return;
    uintptr_t stackTop = (uintptr_t)pthread_get_stackaddr_np(sciMainPThread);
    const uintptr_t mask = 0x0000007FFFFFFFFFULL;   // strips pointer authentication bits from a return address

    if (thread_suspend(sciMainThread) != KERN_SUCCESS) return;
    arm_thread_state64_t state;
    mach_msg_type_number_t count = ARM_THREAD_STATE64_COUNT;
    kern_return_t kr = thread_get_state(sciMainThread, ARM_THREAD_STATE64, (thread_state_t)&state, &count);
    if (kr == KERN_SUCCESS) {
        uintptr_t pc = (uintptr_t)arm_thread_state64_get_pc(state) & mask;
        uintptr_t lr = (uintptr_t)arm_thread_state64_get_lr(state) & mask;
        uintptr_t fp = (uintptr_t)arm_thread_state64_get_fp(state);
        uintptr_t sp = (uintptr_t)arm_thread_state64_get_sp(state);
        out->frames[out->count++] = pc;
        out->frames[out->count++] = lr;
        uintptr_t frame = fp;
        while (out->count < kSCITTMaxFrames && frame >= sp && (frame & 0xF) == 0 && frame + 16 <= stackTop) {
            uintptr_t next = *(uintptr_t *)frame;
            uintptr_t ret = *(uintptr_t *)(frame + 8) & mask;
            if (ret) out->frames[out->count++] = ret;
            if (next <= frame) break;
            frame = next;
        }
        out->ok = YES;
    }
    thread_resume(sciMainThread);
#endif
}

static NSString *SCITTFormatStack(const SCITTStack *stack) {
    if (!stack->ok) return @"(the main thread's registers could not be read)";
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    for (int i = 0; i < stack->count; i++) {
        Dl_info info;
        if (dladdr((void *)stack->frames[i], &info) && info.dli_fname) {
            const char *base = strrchr(info.dli_fname, '/');
            base = base ? base + 1 : info.dli_fname;
            uintptr_t offset = stack->frames[i] - (uintptr_t)info.dli_fbase;
            if (info.dli_sname) {
                [lines addObject:[NSString stringWithFormat:@"%d %s+0x%lx %s", i, base, (unsigned long)offset, info.dli_sname]];
            } else {
                [lines addObject:[NSString stringWithFormat:@"%d %s+0x%lx", i, base, (unsigned long)offset]];
            }
        } else {
            [lines addObject:[NSString stringWithFormat:@"%d 0x%lx", i, (unsigned long)stack->frames[i]]];
        }
    }
    return [lines componentsJoinedByString:@"\n"];
}

#pragma mark - The touches

static NSString *SCITTChainOfView(UIView *view) {
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (NSInteger i = 0; view && i < 5; i++, view = view.superview) [names addObject:NSStringFromClass([view class])];
    return [names componentsJoinedByString:@" < "];
}

static NSString *SCITTWindowsLine(void) {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            [parts addObject:[NSString stringWithFormat:@"%@(l%.0f%@%@)", NSStringFromClass([window class]), window.windowLevel,
                              window.hidden ? @",hidden" : @"", window.isKeyWindow ? @",key" : @""]];
        }
    }
    return [parts componentsJoinedByString:@" "];
}

static void SCITTNoteTouch(UIWindow *window, UIEvent *event) {
    if (event.type != UIEventTypeTouches) return;
    NSSet<UITouch *> *all = event.allTouches;
    UITouch *touch = all.anyObject;
    if (!touch || touch.phase != UITouchPhaseBegan) return;
    UIView *hit = [window hitTest:[touch locationInView:window] withEvent:nil];
    NSString *chain = SCITTChainOfView(hit);
    NSString *entry = [NSString stringWithFormat:@"%@ | %@ | windows: %@", NSStringFromClass([window class]), chain, SCITTWindowsLine()];
    NSUInteger slot = sciRingCount % kSCITTRingSize;
    sciRing[slot] = entry;
    sciRingChains[slot] = chain;
    sciRingTimes[slot] = CACurrentMediaTime();
    sciRingCount++;
}

static NSString *SCITTRingText(void) {
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    NSUInteger n = MIN(sciRingCount, kSCITTRingSize);
    CFTimeInterval now = CACurrentMediaTime();
    for (NSUInteger i = 0; i < n; i++) {
        NSUInteger slot = (sciRingCount - n + i) % kSCITTRingSize;
        [lines addObject:[NSString stringWithFormat:@"-%.1fs  %@", now - sciRingTimes[slot], sciRing[slot]]];
    }
    return lines.count ? [lines componentsJoinedByString:@"\n"] : @"(no touch has begun yet)";
}

/// Four touches in the last fifteen seconds that all landed on the same chain of views: a person tapping and nothing happening looks like this,
/// and so does tapping a video to pause it. The file is a small cost for the second reading.
static BOOL SCITTLooksLikeDeadTaps(void) {
    if (sciRingCount < 4) return NO;
    CFTimeInterval now = CACurrentMediaTime();
    NSString *first = nil;
    for (NSUInteger i = 0; i < 4; i++) {
        NSUInteger slot = (sciRingCount - 1 - i) % kSCITTRingSize;
        if (now - sciRingTimes[slot] > 15) return NO;
        if (!first) first = sciRingChains[slot];
        else if (![first isEqualToString:sciRingChains[slot]]) return NO;
    }
    return YES;
}

#pragma mark - Writing the evidence

static void SCITTWriteEvidence(NSString *headline, NSString *body) {
    NSMutableString *text = [NSMutableString stringWithFormat:@"%@ on %@ %@ (%@)\n%@\n\n%@\n", headline,
                             [[NSBundle mainBundle] bundleIdentifier], SCIVersionString,
                             [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"?",
                             [NSDate date], body];
    if (text.length > 6000) [text deleteCharactersInRange:NSMakeRange(6000, text.length - 6000)];
    NSString *path = SCITTFreezePath();
    [[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
    [text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    sciWrittenAs = headline;
}

#pragma mark - The watchdog

/// Is the app in front right now? Asked of UIKit on the main thread, because **the notification alone is not enough**: 0.31.2 waited for
/// `UIApplicationDidBecomeActiveNotification`, and on the owner's phone it had already been posted by the time this library started watching
/// (the report said `pings 0` beside a launch with a dozen touches in it: the watchdog had been blind for the whole launch). So the state is read,
/// once at install and then once a second for as long as the answer is no.
static void SCITTReconcileActive(void) {
    BOOL front = UIApplication.sharedApplication.applicationState == UIApplicationStateActive;
    if (front && !atomic_load(&sciActive)) {
        atomic_store(&sciActiveSinceMs, SCITTNowMs());
        atomic_store(&sciPingSentMs, SCITTNowMs());
        atomic_store(&sciActive, true);
    } else if (!front) {
        atomic_store(&sciActive, false);
    }
}

static void SCITTWatchdogTick(void) {
    uint64_t now = SCITTNowMs();
    if (!atomic_load(&sciActive)) {
        atomic_store(&sciPingSentMs, now);
        dispatch_async(dispatch_get_main_queue(), ^{ SCITTReconcileActive(); });
        return;
    }
    if (!atomic_load(&sciPingOutstanding)) {
        atomic_store(&sciPingOutstanding, true);
        atomic_store(&sciPingSentMs, now);
        atomic_fetch_add(&sciPings, 1);
        dispatch_async(dispatch_get_main_queue(), ^{
            uint64_t answered = SCITTNowMs();
            uint64_t sent = atomic_load(&sciPingSentMs);
            atomic_store(&sciPingOutstanding, false);
            uint64_t late = answered > sent ? answered - sent : 0;
            if (late >= 2000) {
                atomic_fetch_add(&sciStalls, 1);
                if (late > atomic_load(&sciLongestStallMs)) atomic_store(&sciLongestStallMs, late);
                if (!sciStallLog) sciStallLog = [NSMutableArray array];
                [sciStallLog addObject:[NSString stringWithFormat:@"%.1f s", late / 1000.0]];
                if (sciStallLog.count > 8) [sciStallLog removeObjectAtIndex:0];
            }
        });
        return;
    }

    uint64_t since = MAX(atomic_load(&sciPingSentMs), atomic_load(&sciActiveSinceMs));
    double waited = (now - since) / 1000.0;
    static int stage = 0;
    static uint64_t stageFor = 0;
    uint64_t sent = atomic_load(&sciPingSentMs);
    if (stageFor != sent) { stageFor = sent; stage = 0; }   // a new stall, not the old one going on

    double marks[3] = {kSCITTStallSample1, kSCITTStallSample2, kSCITTStallSample3};
    if (stage >= 3 || waited < marks[stage]) return;
    stage++;

    SCITTStack stack;
    SCITTSampleMainThread(&stack);
    NSString *formatted = SCITTFormatStack(&stack);
    NSString *sample = [NSString stringWithFormat:@"sample %d at %.1f s of waiting:\n%@", stage, waited, formatted];
    @synchronized (sciLock) {
        sciSamples = (stage == 1 || !sciSamples) ? sample : [sciSamples stringByAppendingFormat:@"\n\n%@", sample];
    }
    if (stage >= 2) {
        // The touches are in main-thread-only memory. Reading them from here while the main thread is stuck is safe (it is not writing); if it is
        // not stuck it is the other shape of freeze and the ring is exactly what is wanted.
        NSString *ring = SCITTRingText();
        NSString *body;
        @synchronized (sciLock) { body = sciSamples; }
        SCITTWriteEvidence([NSString stringWithFormat:@"MAIN THREAD STALLED %.1f s", waited],
                           [NSString stringWithFormat:@"%@\n\nlast touches (newest last):\n%@", body, ring]);
    }
}

#pragma mark - Install

%group SCITTFreezeGroup
%hook UIWindow
- (void)sendEvent:(UIEvent *)event {
    SCITTNoteTouch(self, event);
    %orig;
}
%end
%end

void SCITTInstallFreeze(void) {
    if (sciState) return;
    sciLock = [[NSObject alloc] init];

    @try {
        sciPreviousFile = [NSString stringWithContentsOfFile:SCITTFreezePath() encoding:NSUTF8StringEncoding error:nil];
    } @catch (__unused NSException *e) {}

    void (^capture)(void) = ^{
        sciMainThread = pthread_mach_thread_np(pthread_self());
        sciMainPThread = pthread_self();
    };
    if (pthread_main_np()) capture();
    else dispatch_async(dispatch_get_main_queue(), capture);

    atomic_store(&sciActive, false);
    if (pthread_main_np()) SCITTReconcileActive();
    else dispatch_async(dispatch_get_main_queue(), ^{ SCITTReconcileActive(); });
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
        atomic_store(&sciActiveSinceMs, SCITTNowMs());
        atomic_store(&sciPingSentMs, SCITTNowMs());
        atomic_store(&sciActive, true);
    }];
    [center addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
        atomic_store(&sciActive, false);
    }];
    [center addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
        if (SCITTLooksLikeDeadTaps()) {
            sciDeadTapFiles++;
            SCITTWriteEvidence(@"APP LEFT AFTER TAPS ON ONE VIEW", [NSString stringWithFormat:@"last touches (newest last):\n%@", SCITTRingText()]);
        }
    }];

    dispatch_queue_t queue = dispatch_queue_create("com.albrhi.tiktok.freeze", dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0));
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), NSEC_PER_SEC, NSEC_PER_SEC / 4);
    dispatch_source_set_event_handler(timer, ^{ SCITTWatchdogTick(); });
    dispatch_resume(timer);

    %init(SCITTFreezeGroup);
    sciState = @"watching: a one-second ping to the main thread, stack samples after 3 s of silence, a file after 5 s";
    SCILogV(@"[Freeze] %@", sciState);
}

NSString *SCITTFreezeReport(void) {
    NSMutableString *out = [NSMutableString stringWithFormat:
        @"%@; app in front: %@; pings %lu, answers 2 s or more late %lu (longest %.1f s%@)",
        sciState ?: @"not installed", atomic_load(&sciActive) ? @"yes" : @"no",
        (unsigned long)atomic_load(&sciPings), (unsigned long)atomic_load(&sciStalls),
        atomic_load(&sciLongestStallMs) / 1000.0,
        sciStallLog.count ? [@"; this launch: " stringByAppendingString:[sciStallLog componentsJoinedByString:@", "]] : @""];
    if (sciWrittenAs) [out appendFormat:@"; file written this launch: %@", sciWrittenAs];
    if (sciDeadTapFiles) [out appendFormat:@" (taps on one view: %lu)", (unsigned long)sciDeadTapFiles];
    NSString *samples;
    @synchronized (sciLock) { samples = sciSamples; }
    if (samples.length) [out appendFormat:@"\n\nthis launch's stall:\n%@", samples];
    [out appendFormat:@"\n\nlast touches this launch (newest last):\n%@", SCITTRingText()];
    if (sciPreviousFile.length) [out appendFormat:@"\n\nleft by the previous launch:\n%@", sciPreviousFile];
    return out;
}
