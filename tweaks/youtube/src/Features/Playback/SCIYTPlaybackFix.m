/*
 * Playback error recovery, after YTPlaybackFix by Mark02.
 * https://github.com/Mark02-2012/YTPlaybackFix
 *
 * The method is his: intercept the player overlay's -handleError: for playback error codes 14 and
 * 0, wait to see whether playback really stalled, reload the player, seek back to the last known
 * position and check again. This file is written for Albrhi -- it reads and writes nothing that is
 * not confirmed by the runtime first, caps its own retries, and hands the original error back to the
 * app when it gives up -- but the idea and the control flow come from that project, which is
 * reproduced under its licence below. It reached this project through YTKACE
 * (github.com/itzzace/ytkace, MIT), which adapted it first.
 *
 * Copyright (c) 2026 Mark02
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#import "../../SCILog.h"
#import "../../Prefs.h"
#import "../../SCIYTLaunchGuard.h"
#import "../../Diagnostics/SCIYTDiagnostics.h"

///
/// "An error occurred, tap to retry" -- YouTube's own playback error, which the owner reported as
/// something that happens often and that a reload cures.
///
/// **What is different from a plain retry, and why each part is here:**
///
///   * Every error the overlay reports is counted by domain and code, whether or not it is one this
///     recovers. The report then says which errors actually happen on this phone, instead of the
///     two numbers a reference tweak happened to know.
///   * It waits before acting. An error can arrive while the video is in fact still playing, and a
///     reload of a healthy player is a visible stutter for nothing.
///   * It stops. Each video gets three reloads inside two minutes, however they are spread across
///     errors; after that the app's own error is shown, so a video that genuinely cannot play is
///     never reloaded forever.
///   * When it gives up, the original error is handed back to the app, so the failure looks the
///     way it always did rather than as a spinner that never resolves.
///   * Every selector it sends is checked against the runtime first, argument types included --
///     this project has crashed TikTok twice by declaring a signature from a name.
///
/// After the launch, not during it, for the reason the ad gates are: hooks on the player go in a
/// moment after the app is active.
///

static NSString * const kSCIPlaybackDomain = @"com.google.ios.youtube.ErrorDomain.playback";

static const NSTimeInterval kSCIStallGrace   = 0.8;
static const NSTimeInterval kSCIVerifyAfter  = 3.0;
static const double kSCIProgressEpsilon      = 0.15;
static const NSInteger kSCIReloadsPerVideo   = 3;
static const NSTimeInterval kSCIReloadWindow  = 120.0;

static _Atomic double sLatestTime = 0.0;
static BOOL sInFlight = NO;                       // main thread only
static NSMutableDictionary<NSString *, NSMutableArray<NSDate *> *> *sReloads = nil;

// MARK: - Asking the runtime before sending

/// True when `object` answers `selector` with exactly these argument type characters (after the
/// two hidden ones) and, if `returnType` is given, that return type character.
static BOOL SCIYTAnswers(id object, SEL selector, const char *returnType, const char *args) {
    if (!object) return NO;
    Method method = class_getInstanceMethod(object_getClass(object), selector);
    if (!method) return NO;

    if (returnType) {
        char *actual = method_copyReturnType(method);
        BOOL same = actual && actual[0] == returnType[0];
        free(actual);
        if (!same) return NO;
    }

    size_t wanted = strlen(args);
    if (method_getNumberOfArguments(method) != wanted + 2) return NO;

    for (size_t i = 0; i < wanted; i++) {
        char *actual = method_copyArgumentType(method, (unsigned int)(i + 2));
        BOOL same = actual && actual[0] == args[i];
        free(actual);
        if (!same) return NO;
    }
    return YES;
}

static id SCIYTObjectGetter(id object, NSString *name) {
    SEL selector = NSSelectorFromString(name);
    if (!SCIYTAnswers(object, selector, "@", "")) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(object, selector);
}

static double SCIYTPosition(id player) {
    SEL selector = NSSelectorFromString(@"currentVideoMediaTime");
    if (!SCIYTAnswers(player, selector, "d", "")) return -1.0;
    return ((double (*)(id, SEL))objc_msgSend)(player, selector);
}

static void SCIYTSeek(id player, double position) {
    SEL selector = NSSelectorFromString(@"seekToTime:");
    if (!SCIYTAnswers(player, selector, "v", "d")) {
        [SCIYTDiagnostics countPlaybackFix:@"seek unavailable on this build"];
        return;
    }
    ((void (*)(id, SEL, double))objc_msgSend)(player, selector, position);
}

/// Reloads just the player: the video's own -player:reloadWithContext:, with a context built by
/// the class that exists for exactly this. Returns NO -- and sends nothing -- if any piece of that
/// is not what it is expected to be.
static BOOL SCIYTReloadPlayer(id pvc) {
    id video = SCIYTObjectGetter(pvc, @"activeVideo");
    Class contextClass = NSClassFromString(@"MLPlayerReloadContext");
    SEL contextInit = NSSelectorFromString(@"initWithStartPlayback:refreshStreamingData:");
    SEL reload = NSSelectorFromString(@"player:reloadWithContext:");

    if (!video || !contextClass) return NO;
    if (!SCIYTAnswers(video, reload, "v", "@@")) return NO;

    id allocated = [contextClass alloc];
    if (!SCIYTAnswers(allocated, contextInit, "@", "BB")) return NO;

    id media = SCIYTObjectGetter(video, @"mediaPlayer");
    id context = ((id (*)(id, SEL, BOOL, BOOL))objc_msgSend)(allocated, contextInit, YES, YES);
    if (!context) return NO;

    ((void (*)(id, SEL, id, id))objc_msgSend)(video, reload, media, context);
    return YES;
}

/// The reference's fallback: the same "tap to retry" event YouTube's own error screen sends. It
/// reloads the whole watch page, which is why it is second.
static BOOL SCIYTSendRetryEvent(id overlay) {
    id responder = SCIYTObjectGetter(overlay, @"parentResponder");
    Class eventClass = NSClassFromString(@"YTPlayerTapToRetryResponderEvent");
    SEL factory = NSSelectorFromString(@"eventWithFirstResponder:");
    if (!responder || !eventClass) return NO;

    Method classMethod = class_getClassMethod(eventClass, factory);
    if (!classMethod) return NO;
    char *returnType = method_copyReturnType(classMethod);
    BOOL objectReturn = returnType && returnType[0] == '@';
    free(returnType);
    if (!objectReturn || method_getNumberOfArguments(classMethod) != 3) return NO;

    id event = ((id (*)(Class, SEL, id))objc_msgSend)(eventClass, factory, responder);
    SEL send = NSSelectorFromString(@"send");
    if (!SCIYTAnswers(event, send, "v", "")) return NO;

    ((void (*)(id, SEL))objc_msgSend)(event, send);
    return YES;
}

// MARK: - The reload budget

/// Reloads spent on this video in the last two minutes, after dropping the stale ones. The budget
/// is counted in reloads and not in errors, because one error can take two reloads and three
/// errors in a row can each take one -- and it is the reloads that a video which cannot play must
/// not be given without end.
static NSMutableArray<NSDate *> *SCIYTRecentReloads(NSString *videoID) {
    NSString *key = videoID.length ? videoID : @"-";
    if (!sReloads) sReloads = [NSMutableDictionary dictionary];

    NSMutableArray<NSDate *> *stamps = sReloads[key] ?: [NSMutableArray array];
    NSDate *cutoff = [NSDate dateWithTimeIntervalSinceNow:-kSCIReloadWindow];
    NSIndexSet *stale = [stamps indexesOfObjectsPassingTest:^BOOL(NSDate *stamp, NSUInteger i, BOOL *stop) {
        return [stamp compare:cutoff] == NSOrderedAscending;
    }];
    [stamps removeObjectsAtIndexes:stale];
    sReloads[key] = stamps;

    // Bounded: a cache of recent trouble, not a history.
    if (sReloads.count > 40) { [sReloads removeAllObjects]; sReloads[key] = stamps; }
    return stamps;
}

static BOOL SCIYTHasReloadBudget(NSString *videoID) {
    return (NSInteger)SCIYTRecentReloads(videoID).count < kSCIReloadsPerVideo;
}

/// Spends one reload, or answers NO without spending when the video has none left.
static BOOL SCIYTSpendReload(NSString *videoID) {
    NSMutableArray<NSDate *> *stamps = SCIYTRecentReloads(videoID);
    if ((NSInteger)stamps.count >= kSCIReloadsPerVideo) return NO;
    [stamps addObject:[NSDate date]];
    return YES;
}

// MARK: - Recovery

typedef void (*SCIYTOriginalHandleError)(id, SEL, id);

static void SCIYTRecover(id overlay, id pvc, NSString *videoID, double saved, id error, SEL selector, SCIYTOriginalHandleError original) {
    __weak id weakOverlay = overlay;
    __weak id weakPlayer = pvc;

    // The error can arrive while the picture is still moving. Wait and look.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kSCIStallGrace * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        id player = weakPlayer;
        if (!player) { sInFlight = NO; return; }

        if (SCIYTPosition(player) > saved + kSCIProgressEpsilon) {
            sInFlight = NO;
            [SCIYTDiagnostics countPlaybackFix:@"still playing — left alone"];
            return;
        }

        // NO when this video has no reloads left, and nothing is sent in that case.
        BOOL (^attempt)(NSString *) = ^BOOL(NSString *stage) {
            if (!SCIYTSpendReload(videoID)) {
                [SCIYTDiagnostics countPlaybackFix:@"reload budget spent for this video"];
                return NO;
            }
            BOOL reloaded = SCIYTReloadPlayer(player);
            if (!reloaded) {
                id strongOverlay = weakOverlay;
                reloaded = strongOverlay && SCIYTSendRetryEvent(strongOverlay);
                [SCIYTDiagnostics countPlaybackFix:reloaded ? @"reload: retry event (player reload unavailable)"
                                                            : @"reload: nothing available"];
            } else {
                [SCIYTDiagnostics countPlaybackFix:[NSString stringWithFormat:@"reload: player (%@)", stage]];
            }
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                id p = weakPlayer;
                if (p) SCIYTSeek(p, saved);
            });
            return YES;
        };

        attempt(@"first");

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kSCIVerifyAfter * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            id p = weakPlayer;
            if (!p) { sInFlight = NO; return; }

            if (SCIYTPosition(p) > saved + 0.05) {
                sInFlight = NO;
                [SCIYTDiagnostics countPlaybackFix:@"recovered"];
                return;
            }

            [SCIYTDiagnostics countPlaybackFix:@"still stalled — second attempt"];
            BOOL again = attempt(@"second");

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((again ? kSCIVerifyAfter : 0.0) * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                id last = weakPlayer;
                BOOL playing = last && SCIYTPosition(last) > saved + 0.05;
                sInFlight = NO;

                if (playing) {
                    [SCIYTDiagnostics countPlaybackFix:@"recovered"];
                    return;
                }

                // Gave up. The app's own error is shown, so the failure looks the way it always
                // did instead of a spinner that never resolves.
                [SCIYTDiagnostics countPlaybackFix:@"gave up — the app's own error shown"];
                id strongOverlay = weakOverlay;
                if (strongOverlay && original) original(strongOverlay, selector, error);
            });
        });
    });
}

static BOOL SCIYTFixEnabled(void) {
    return SCIPrefEnabled(SCIPrefFixPlaybackErrors) && !SCIYTStoodDown();
}

// MARK: - Installation

static IMP sOriginalHandleError = NULL;
static IMP sOriginalMediaTime = NULL;
static IMP sOriginalSeek = NULL;

static BOOL SCIYTHookIfDeclared(NSString *className, NSString *selectorName, const char *encoding,
                                IMP replacement, IMP *original) {
    Class cls = objc_getClass(className.UTF8String);
    NSString *label = [NSString stringWithFormat:@"%@ %@", className, selectorName];
    if (!cls) {
        [SCIYTDiagnostics countPlaybackFix:[NSString stringWithFormat:@"hook: %@ — class not in this build", label]];
        return NO;
    }

    SEL selector = NSSelectorFromString(selectorName);
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) {
        [SCIYTDiagnostics countPlaybackFix:[NSString stringWithFormat:@"hook: %@ — method not on this build", label]];
        return NO;
    }

    const char *actual = method_getTypeEncoding(method);
    if (!actual || strcmp(actual, encoding) != 0) {
        [SCIYTDiagnostics countPlaybackFix:[NSString stringWithFormat:@"hook: %@ — encoding %s, expected %s",
                                            label, actual ?: "?", encoding]];
        return NO;
    }

    MSHookMessageEx(cls, selector, replacement, original);
    [SCIYTDiagnostics countPlaybackFix:[NSString stringWithFormat:@"hook: %@ — installed", label]];
    return YES;
}

static void SCIYTInstallPlaybackFix(void) {
    static BOOL installed = NO;
    if (installed) return;
    installed = YES;

    // The position the player last reported, kept because at the moment an error arrives it may
    // already read zero. A plain store: this getter is called for every progress update.
    IMP mediaTime = imp_implementationWithBlock(^double(id me) {
        double value = sOriginalMediaTime ? ((double (*)(id, SEL))sOriginalMediaTime)(me, @selector(currentVideoMediaTime)) : 0.0;
        sLatestTime = value;
        return value;
    });
    SCIYTHookIfDeclared(@"YTPlayerViewController", @"currentVideoMediaTime", "d16@0:8", mediaTime, &sOriginalMediaTime);

    IMP seek = imp_implementationWithBlock(^(id me, double time) {
        sLatestTime = time;
        if (sOriginalSeek) ((void (*)(id, SEL, double))sOriginalSeek)(me, @selector(seekToTime:), time);
    });
    SCIYTHookIfDeclared(@"YTPlayerViewController", @"seekToTime:", "v24@0:8d16", seek, &sOriginalSeek);

    IMP handle = imp_implementationWithBlock(^(id me, id error) {
        SEL selector = NSSelectorFromString(@"handleError:");
        SCIYTOriginalHandleError original = (SCIYTOriginalHandleError)sOriginalHandleError;

        NSError *failure = [error isKindOfClass:[NSError class]] ? error : nil;
        [SCIYTDiagnostics countPlaybackFix:failure
            ? [NSString stringWithFormat:@"error seen: %@ %ld", failure.domain, (long)failure.code]
            : @"error seen: not an NSError"];

        BOOL ours = failure && [failure.domain isEqualToString:kSCIPlaybackDomain]
                    && (failure.code == 14 || failure.code == 0);

        if (!ours || !SCIYTFixEnabled() || sInFlight) {
            if (original) original(me, selector, error);
            return;
        }

        id pvc = SCIYTObjectGetter(me, @"parentViewController");
        NSString *videoID = SCIYTObjectGetter(pvc, @"currentVideoID");
        if (![videoID isKindOfClass:[NSString class]]) videoID = nil;

        if (!pvc) {
            [SCIYTDiagnostics countPlaybackFix:@"no player to recover — the app's own error shown"];
            if (original) original(me, selector, error);
            return;
        }

        if (!SCIYTHasReloadBudget(videoID)) {
            [SCIYTDiagnostics countPlaybackFix:@"reload budget spent — the app's own error shown"];
            if (original) original(me, selector, error);
            return;
        }

        sInFlight = YES;
        [SCIYTDiagnostics countPlaybackFix:@"intercepted"];
        SCIYTRecover(me, pvc, videoID, sLatestTime, error, selector, original);
    });
    SCIYTHookIfDeclared(@"YTMainAppVideoPlayerOverlayViewController", @"handleError:", "v24@0:8@16",
                        handle, &sOriginalHandleError);
}

__attribute__((constructor)) static void SCIYTPlaybackFixRegister(void) {
    SCIYTWhenActive(^{ SCIYTInstallPlaybackFix(); });
}
