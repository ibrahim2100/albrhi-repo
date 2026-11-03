#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#import "SCIYTArbiter.h"
#import "SCIYTPlayer.h"
#import "SCIYTHostPlayer.h"
#import "../../../SCILog.h"
#import "../../../Prefs.h"
#import "../../../SCIYTLaunchGuard.h"

///
/// One player at a time.
///
/// Two players live in this process -- YouTube's and the Download Centre's -- and the audio
/// session separates apps, not players, so nothing stopped both playing: the picture of one over
/// the sound of the other, and a lock-screen Play that started both, because **the lock screen's
/// buttons are delivered to every handler on the shared MPRemoteCommandCenter** and each of the
/// two had registered its own.
///
/// The rule is in SCIYTArbiterCore.h (an owner, decided by who started audibly and when). This
/// file is the enforcement, and every place it reaches into YouTube was read from the 21.41.5
/// binary rather than guessed:
///
///   YTSingleVideoController -play            the one door every YouTube player starts through
///                                            (watch page, Shorts, inline). It answers -isMuted and
///                                            -volume, so a muted feed preview is not a takeover.
///   YTRemoteCommandHandler / YTReelRemote…   the lock screen's buttons on YouTube's side.
///   YTNowPlayingInfoCenterPlaybackObserverImpl  what writes "now playing" over whatever is there.
///   MLAudioSession -appDidEnterBackground    where YouTube lets go of the audio session when it
///                                            thinks nothing of its own is playing.
///
/// Installed at runtime, behind the class and the exact type encoding, after the app is active --
/// a %hook on a method a class does not declare would *add* it (CLAUDE.md 4.2). Each hook is
/// counted, and a hook that attached with a count of zero is a finding, not a contradiction.
///

static SCIArbiterState sState = { SCIOwnerNone, 0 };
static NSMutableArray<NSString *> *sLabels = nil;
static NSMutableDictionary<NSString *, NSString *> *sStatus = nil;
static NSMutableDictionary<NSString *, NSNumber *> *sCounts = nil;

static double SCINow(void) { return CACurrentMediaTime(); }

static void SCIRegister(NSString *label, NSString *status) {
    @synchronized ([SCIYTArbiter class]) {
        if (!sLabels) { sLabels = [NSMutableArray array]; sStatus = [NSMutableDictionary dictionary]; sCounts = [NSMutableDictionary dictionary]; }
        if (![sLabels containsObject:label]) [sLabels addObject:label];
        sStatus[label] = status;
    }
}

static void SCICount(NSString *label) {
    @synchronized ([SCIYTArbiter class]) { sCounts[label] = @([sCounts[label] integerValue] + 1); }
}

/// Shorts is a different controller from the watch page's, so it is remembered the same way:
/// weakly, and only once it has actually played.
static __weak id sReelPlayer = nil;

static void SCIPauseReel(void) {
    id reel = sReelPlayer;
    SEL pause = NSSelectorFromString(@"pause");
    if (reel && [reel respondsToSelector:pause]) ((void (*)(id, SEL))objc_msgSend)(reel, pause);
}

static BOOL SCIEnabled(void) { return SCIPrefEnabled(SCIPrefOnePlayer) && !SCIYTStoodDown(); }

@implementation SCIYTArbiter

+ (SCIOwner)owner {
    @synchronized (self) { return (SCIOwner)sState.owner; }
}

+ (void)oursStarted {
    @synchronized (self) { SCIArbiterOursStarted(&sState, SCINow()); }
}

+ (void)oursCommanded {
    @synchronized (self) { SCIArbiterOursCommanded(&sState, SCINow()); }
}

+ (void)oursEnded {
    @synchronized (self) { SCIArbiterOursEnded(&sState); }
}

+ (BOOL)oursMayAct {
    // Off means the old behaviour: ours answers whatever it is sent.
    if (!SCIEnabled()) return YES;
    @synchronized (self) { return SCIArbiterOursMayAct(&sState); }
}

+ (BOOL)oursMayDescribe {
    if (!SCIEnabled()) return YES;
    @synchronized (self) { return SCIArbiterOursMayDescribe(&sState); }
}

+ (BOOL)hostMustStandBack {
    if (!SCIEnabled()) return NO;
    @synchronized (self) { return SCIArbiterHostMustStandBack(&sState); }
}

+ (void)pauseHostPlayers {
    [SCIYTHostPlayer pauseHost];
    SCIPauseReel();
}

+ (NSString *)report {
    static NSArray *names = nil;
    if (!names) names = @[@"none", @"Centre player", @"YouTube's player"];
    @synchronized (self) {
        NSMutableArray<NSString *> *lines = [NSMutableArray arrayWithObject:
            [NSString stringWithFormat:@"owner: %@", names[sState.owner]]];
        if (!sLabels.count) [lines addObject:@"hooks: not installed yet — they attach a moment after the app becomes active"];
        for (NSString *label in sLabels) {
            [lines addObject:[NSString stringWithFormat:@"%@ — %@ · ×%@", label, sStatus[label], sCounts[label] ?: @0]];
        }
        return [lines componentsJoinedByString:@"\n  "];
    }
}

@end

// MARK: - Installing

/// The class, the selector and the exact encoding -- or a recorded reason for stepping over it.
static Method SCIFind(NSString *className, NSString *selectorName, const char *encoding, Class *outClass, SEL *outSel) {
    NSString *label = [NSString stringWithFormat:@"%@ %@", className, selectorName];
    Class cls = objc_getClass(className.UTF8String);
    if (!cls) { SCIRegister(label, @"class not in this build"); return NULL; }

    SEL selector = NSSelectorFromString(selectorName);
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) { SCIRegister(label, @"method not on this build"); return NULL; }

    const char *actual = method_getTypeEncoding(method);
    if (!actual || strcmp(actual, encoding) != 0) {
        SCIRegister(label, [NSString stringWithFormat:@"not hooked: encoding is %s, expected %s", actual ?: "?", encoding]);
        return NULL;
    }
    *outClass = cls; *outSel = selector;
    return method;
}

/// `-(NSInteger)handle…:(id)event` on a lock-screen handler: refused with "no actionable item"
/// while our player owns playback, so exactly one side answers a button.
static void SCIHookRemote(NSString *className, NSString *selectorName) {
    Class cls; SEL selector;
    if (!SCIFind(className, selectorName, "q24@0:8@16", &cls, &selector)) return;

    NSString *label = [NSString stringWithFormat:@"%@ %@", className, selectorName];
    IMP *orig = calloc(1, sizeof(IMP));
    IMP replacement = imp_implementationWithBlock(^NSInteger(id me, id event) {
        if ([SCIYTArbiter hostMustStandBack]) {
            SCICount(label);
            return MPRemoteCommandHandlerStatusNoActionableNowPlayingItem;
        }
        return *orig ? ((NSInteger (*)(id, SEL, id))*orig)(me, selector, event) : MPRemoteCommandHandlerStatusCommandFailed;
    });
    MSHookMessageEx(cls, selector, replacement, orig);
    SCIRegister(label, @"hooked");
}

/// A writer of "now playing" that stands aside while our player owns playback.
static void SCIHookNowPlaying(NSString *selectorName, const char *encoding) {
    NSString *className = @"YTNowPlayingInfoCenterPlaybackObserverImpl";
    Class cls; SEL selector;
    if (!SCIFind(className, selectorName, encoding, &cls, &selector)) return;

    NSString *label = [NSString stringWithFormat:@"%@ %@", className, selectorName];
    IMP *orig = calloc(1, sizeof(IMP));
    IMP replacement = NULL;

    if (!strcmp(encoding, "v16@0:8")) {
        replacement = imp_implementationWithBlock(^(id me) {
            if ([SCIYTArbiter hostMustStandBack]) { SCICount(label); return; }
            if (*orig) ((void (*)(id, SEL))*orig)(me, selector);
        });
    } else if (!strcmp(encoding, "v24@0:8@16")) {
        replacement = imp_implementationWithBlock(^(id me, id model) {
            if ([SCIYTArbiter hostMustStandBack]) { SCICount(label); return; }
            if (*orig) ((void (*)(id, SEL, id))*orig)(me, selector, model);
        });
    } else if (!strcmp(encoding, "v28@0:8@16B24")) {
        replacement = imp_implementationWithBlock(^(id me, id model, BOOL flag) {
            if ([SCIYTArbiter hostMustStandBack]) { SCICount(label); return; }
            if (*orig) ((void (*)(id, SEL, id, BOOL))*orig)(me, selector, model, flag);
        });
    } else if (!strcmp(encoding, "v24@0:8f16B20")) {
        replacement = imp_implementationWithBlock(^(id me, float rate, BOOL flag) {
            if ([SCIYTArbiter hostMustStandBack]) { SCICount(label); return; }
            if (*orig) ((void (*)(id, SEL, float, BOOL))*orig)(me, selector, rate, flag);
        });
    }
    if (!replacement) return;
    MSHookMessageEx(cls, selector, replacement, orig);
    SCIRegister(label, @"hooked");
}

/// After YouTube lets go of the audio session, take it back if our player is the one playing.
/// Nothing is skipped: YouTube's own activation paths run untouched, so its player is never
/// starved of a session -- ours is only put back when it is the one that needs it.
static void SCIHookSessionRelease(NSString *selectorName, const char *encoding) {
    Class cls; SEL selector;
    if (!SCIFind(@"MLAudioSession", selectorName, encoding, &cls, &selector)) return;

    NSString *label = [NSString stringWithFormat:@"MLAudioSession %@", selectorName];
    IMP *orig = calloc(1, sizeof(IMP));
    IMP replacement = NULL;

    if (!strcmp(encoding, "v16@0:8")) {
        replacement = imp_implementationWithBlock(^(id me) {
            if (*orig) ((void (*)(id, SEL))*orig)(me, selector);
            if (SCIEnabled() && [SCIYTPlayer reclaimAudioIfPlaying]) SCICount(label);
        });
    } else {
        replacement = imp_implementationWithBlock(^(id me, uint32_t task) {
            if (*orig) ((void (*)(id, SEL, uint32_t))*orig)(me, selector, task);
            if (SCIEnabled() && [SCIYTPlayer reclaimAudioIfPlaying]) SCICount(label);
        });
    }
    MSHookMessageEx(cls, selector, replacement, orig);
    SCIRegister(label, @"hooked");
}

/// The door YouTube's players start through.
static void SCIHookHostPlay(void) {
    Class cls; SEL selector;
    if (!SCIFind(@"YTSingleVideoController", @"play", "v16@0:8", &cls, &selector)) return;

    // The two getters the decision reads -- asked about, never assumed.
    SEL mutedSel = NSSelectorFromString(@"isMuted"), volumeSel = NSSelectorFromString(@"volume");
    Method mutedM = class_getInstanceMethod(cls, mutedSel), volumeM = class_getInstanceMethod(cls, volumeSel);
    BOOL canJudge = mutedM && volumeM &&
        !strcmp(method_getTypeEncoding(mutedM), "B16@0:8") && !strcmp(method_getTypeEncoding(volumeM), "f16@0:8");

    NSString *label = @"YTSingleVideoController play";
    if (!canJudge) { SCIRegister(label, @"not hooked: -isMuted / -volume missing, cannot tell a preview from a video"); return; }

    IMP *orig = calloc(1, sizeof(IMP));
    IMP replacement = imp_implementationWithBlock(^(id me) {
        BOOL audible = !((BOOL (*)(id, SEL))objc_msgSend)(me, mutedSel) &&
                       ((float (*)(id, SEL))objc_msgSend)(me, volumeSel) > 0.01f;

        if (SCIEnabled() && audible) {
            SCICount(label);
            BOOL oursPlaying = [SCIYTPlayer isPlaying];
            int veto;
            @synchronized ([SCIYTArbiter class]) { veto = SCIArbiterHostStarted(&sState, SCINow(), oursPlaying); }

            if (veto) {
                // The echo of one of our own commands (the lock screen's Play reaches both).
                SCICount(@"play vetoed (echo of our command)");
                return;
            }
            if (oursPlaying) {
                SCICount(@"play: YouTube took over, Centre player paused");
                dispatch_async(dispatch_get_main_queue(), ^{ [SCIYTPlayer pauseForHost]; });
            }
        }
        if (*orig) ((void (*)(id, SEL))*orig)(me, selector);
    });
    MSHookMessageEx(cls, selector, replacement, orig);
    SCIRegister(label, @"hooked (counts audible starts only; muted previews are not takeovers)");
    SCIRegister(@"play vetoed (echo of our command)", @"counter");
    SCIRegister(@"play: YouTube took over, Centre player paused", @"counter");
}

static void SCIHookReelPlay(void) {
    Class cls; SEL selector;
    if (!SCIFind(@"YTReelPlayerViewController", @"play", "v16@0:8", &cls, &selector)) return;
    // -pause is called by name later, so it has to be the one this build declares.
    Method pause = class_getInstanceMethod(cls, NSSelectorFromString(@"pause"));
    if (!pause || strcmp(method_getTypeEncoding(pause), "v16@0:8")) {
        SCIRegister(@"YTReelPlayerViewController play", @"not hooked: no -pause to stop it with");
        return;
    }
    IMP *orig = calloc(1, sizeof(IMP));
    IMP replacement = imp_implementationWithBlock(^(id me) {
        if (*orig) ((void (*)(id, SEL))*orig)(me, selector);
        sReelPlayer = me;
    });
    MSHookMessageEx(cls, selector, replacement, orig);
    SCIRegister(@"YTReelPlayerViewController play", @"hooked (remembers the Shorts player so ours can stop it)");
}

static void SCIInstallArbiter(void) {
    static BOOL installed = NO;
    if (installed) return;
    installed = YES;

    SCIHookHostPlay();
    SCIHookReelPlay();

    for (NSString *name in @[@"handlePlayCommand:", @"handlePauseCommand:", @"handleTogglePlayPauseCommand:",
                             @"handleNextTrackCommand:", @"handlePreviousTrackCommand:",
                             @"handleSkipForwardCommand:", @"handleSkipBackwardCommand:",
                             @"handleChangePlaybackPositionCommand:"]) {
        SCIHookRemote(@"YTRemoteCommandHandler", name);
    }
    for (NSString *name in @[@"didReceivePlayCommand:", @"didReceivePauseCommand:", @"didReceiveTogglePlayPauseCommand:"]) {
        SCIHookRemote(@"YTReelRemoteCommandHandler", name);
    }

    SCIHookNowPlaying(@"updateNowPlayingInfoCenterWithModel:", "v24@0:8@16");
    SCIHookNowPlaying(@"updateNowPlayingInfoCenterWithModel:ignoreElapsedPlaybackTimeForModelEquality:", "v28@0:8@16B24");
    SCIHookNowPlaying(@"updateNowPlayingInfoWithPlaybackRate:requireElapsedTimeUpdate:", "v24@0:8f16B20");
    SCIHookNowPlaying(@"updateNowPlayingInfoWithActiveVideoIfNeeded", "v16@0:8");
    SCIHookNowPlaying(@"updateNowPlayingInfoWithLockScreenRenderer", "v16@0:8");
    SCIHookNowPlaying(@"updateNowPlayingInfoWithUpcomingPlaybackLockScreenRenderer", "v16@0:8");
    SCIHookNowPlaying(@"clearNowPlayingInfo", "v16@0:8");

    SCIHookSessionRelease(@"appDidEnterBackground", "v16@0:8");
    SCIHookSessionRelease(@"doneWithPlaybackForTaskID:", "v20@0:8I16");
}

__attribute__((constructor)) static void SCIYTArbiterRegister(void) {
    SCIYTWhenActive(^{ SCIInstallArbiter(); });
}
