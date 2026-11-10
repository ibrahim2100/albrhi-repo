//
//  SCISafeLaunch.m
//  Albrhi -- shared
//
//  **Why this exists.** The worst thing a tweak can do is stop an app from starting, and the person who hits it cannot fix it from inside the app.
//  Five of this project's bugs were exactly that (YouTube's launch hang, a TikTok probe typed wrongly, a startup hook asking layout of itself...).
//  The launch guard in YouTube stands expensive hooks down after eight seconds of a launch that is *alive*; it cannot help when the process is
//  *dead* before the next launch. This is the other half: it remembers that the last launch did not finish, and after two such launches in a row it
//  installs nothing and offers the way back.
//
//  **What counts as "finished".** The app became active and stayed so for three seconds, or it went to the background / was ended on purpose.
//  A process that was started in the background (a push, a fetch) does not count either way. A crash, a watchdog kill or a jetsam during start-up
//  leaves the mark standing -- which is the signal.
//
//  **What it deliberately does not do.** It does not guess *which* feature was at fault (it cannot), it does not touch the person's settings, and a
//  crash later in a session that started fine is not its business.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCISafeLaunch.h"
#import <UIKit/UIKit.h>
#import "SCICard.h"

#pragma mark - The state on disk

static NSString *sciSLPath = nil;
static SCISafeLaunchState sciSLState;
static BOOL sciSLBegun = NO, sciSLReady = NO, sciSLActive = NO, sciSLShown = NO;
static NSString *sciSLNote = @"not started";

static NSString *SCISafeLaunchPath(void) {
    NSString *support = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
    if (!support.length) return nil;
    NSString *folder = [support stringByAppendingPathComponent:@"Albrhi"];
    [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
    return [folder stringByAppendingPathComponent:@"safe-launch.json"];
}

static SCISafeLaunchState SCISafeLaunchRead(void) {
    SCISafeLaunchState s = {NO, 0, NO};
    NSData *data = sciSLPath ? [NSData dataWithContentsOfFile:sciSLPath] : nil;
    NSDictionary *d = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
    if ([d isKindOfClass:[NSDictionary class]]) {
        s.pending = [d[@"pending"] boolValue];
        s.failures = MAX(0, MIN(99, [d[@"failures"] integerValue]));
        s.paused = [d[@"paused"] boolValue];
    }
    return s;
}

static void SCISafeLaunchWrite(SCISafeLaunchState s) {
    if (!sciSLPath) return;
    NSDictionary *d = @{@"pending": @(s.pending), @"failures": @(s.failures), @"paused": @(s.paused), @"at": @((long long)[[NSDate date] timeIntervalSince1970])};
    NSData *data = [NSJSONSerialization dataWithJSONObject:d options:0 error:NULL];
    [data writeToFile:sciSLPath options:NSDataWritingAtomic error:NULL];
}

static NSObject *SCISafeLaunchLock(void) {
    static NSObject *lock;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ lock = [NSObject new]; });
    return lock;
}

static void SCISafeLaunchApply(SCISafeLaunchEvent event) {
    @synchronized (SCISafeLaunchLock()) {
        sciSLState = SCISafeLaunchStep(sciSLState, event);
        SCISafeLaunchWrite(sciSLState);
    }
}

#pragma mark - The way back

/// Tells the person, once per launch, and gives the way back. **Not a hook and not a TikTok/Instagram class**: this runs exactly when everything
/// else has stood down, so it can only use UIKit -- on a card of our own (SCICard: system alerts come out mirrored in TikTok in Arabic).
static void SCISafeLaunchOffer(void) {
    if (sciSLShown || SCICardIsShowing()) return;
    BOOL ar = SCICardArabic();
    NSString *title = ar ? @"البرهي موقوفة مؤقتاً" : @"Albrhi is paused";
    NSString *message = ar ? @"التطبيق ما اشتغل مرتين ورا بعض، فوقفت الأداة عشان ما يتعطل. تبي ترجعها؟"
                           : @"The app did not start twice in a row, so Albrhi stepped aside to keep it working. Bring it back?";
    sciSLShown = SCICardShow(title, message, @[ar ? @"رجّعها" : @"Bring it back", ar ? @"خلها موقوفة" : @"Keep it paused"], 0, ^(NSInteger index) {
        if (index != 0) return;
        SCISafeLaunchApply(SCISafeLaunchEventResume);
        SCICardShow(ar ? @"تمام" : @"Done", ar ? @"سكّر التطبيق وافتحه من جديد." : @"Close the app and open it again.", @[@"OK"], 0, nil);
    });
}

static BOOL SCISafeLaunchIsApp(void) {
    NSString *bundle = [NSBundle mainBundle].bundlePath;
    NSString *ident = [NSBundle mainBundle].bundleIdentifier ?: @"";
    // Apple's own apps are not ours to watch (NextUp and the Watch tweak load into some of them). Instagram is left out on purpose: its behaviour is not
    // to change until the owner has seen this working in the apps that have it.
    if ([ident isEqualToString:@"com.burbn.instagram"]) return NO;
    return [bundle.pathExtension isEqualToString:@"app"] && ![ident hasPrefix:@"com.apple."];
}

static void SCISafeLaunchWatch(void) {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    NSOperationQueue *main = [NSOperationQueue mainQueue];

    [center addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:main usingBlock:^(NSNotification *n) {
        // Started for a push or a fetch: nobody waited for it, so it is not evidence about anything.
        if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) SCISafeLaunchApply(SCISafeLaunchEventBackground);
    }];
    [center addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:main usingBlock:^(NSNotification *n) {
        sciSLActive = YES;
        if (sciSLState.paused) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ SCISafeLaunchOffer(); });
            return;
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (sciSLActive) SCISafeLaunchApply(SCISafeLaunchEventStable);   // still here three seconds later
        });
    }];
    void (^left)(NSNotification *) = ^(NSNotification *n) {
        sciSLActive = NO;
        SCISafeLaunchApply(SCISafeLaunchEventLeft);
    };
    [center addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:main usingBlock:^(NSNotification *n) { sciSLActive = NO; }];
    [center addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:main usingBlock:left];
    [center addObserverForName:UIApplicationWillTerminateNotification object:nil queue:main usingBlock:left];
}

BOOL SCISafeLaunchPaused(void) {
    if (sciSLReady) return sciSLState.paused;   // the usual call: no lock
    @synchronized (SCISafeLaunchLock()) {
        if (!sciSLBegun) {
            sciSLBegun = YES;
            if (!SCISafeLaunchIsApp()) {
                sciSLNote = @"not an app process -- not watched";
            } else {
                sciSLPath = SCISafeLaunchPath();
                if (!sciSLPath) {
                    sciSLNote = @"no place to keep the mark -- not watched";
                } else {
                    sciSLActive = NO;
                    sciSLState = SCISafeLaunchRead();
                    sciSLState = SCISafeLaunchStep(sciSLState, SCISafeLaunchEventBegin);
                    SCISafeLaunchWrite(sciSLState);
                    sciSLNote = @"watching";
                    dispatch_async(dispatch_get_main_queue(), ^{ SCISafeLaunchWatch(); });
                }
            }
        }
        sciSLReady = YES;
        return sciSLState.paused;
    }
}

NSString *SCISafeLaunchReport(void) {
    SCISafeLaunchPaused();
    @synchronized (SCISafeLaunchLock()) {
        return [NSString stringWithFormat:@"%@; launches in a row that did not finish starting: %ld of %ld; %@",
                sciSLNote, (long)sciSLState.failures, (long)SCISafeLaunchLimit, sciSLState.paused ? @"PAUSED (Albrhi is standing down)" : @"running"];
    }
}
