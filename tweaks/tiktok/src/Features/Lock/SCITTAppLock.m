//
//  SCITTAppLock.m
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import "SCITTAppLock.h"
#import "../../Prefs.h"
#import "../../SCILog.h"
#import "../../Localization/SCILocalize.h"

///
/// **A question asked when TikTok comes back to the screen.** Face ID, Touch ID or the passcode.
///
/// No TikTok class is involved: the app leaving and returning is announced by the system, so a build of TikTok that
/// renames everything still has the lock. The cover is raised while the app is resigning -- the app switcher's card is
/// photographed then, so a cover added afterwards would show in the app and not in the card.
///
/// Passcode is accepted, not only biometry: a phone whose owner has Face ID switched off must not be locked out of an
/// app on their own device by this. A device that can evaluate neither is let through, and the report says so. A
/// refusal keeps the cover and nothing else: closing TikTok because a check failed would be deciding something
/// nobody asked for.
///

static BOOL sciUnlocked = NO, sciAsking = NO, sciInstalled = NO;
static NSUInteger sciAsked = 0, sciPassed = 0, sciRefused = 0, sciLetThrough = 0;
static UIView *sciCover = nil;

static UIWindow *SCITTLockWindow(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isKeyWindow) return window;
        }
    }
    return UIApplication.sharedApplication.windows.firstObject;
}

static void SCITTRemoveCover(void) {
    [sciCover removeFromSuperview];
    sciCover = nil;
}

static void SCITTShowCover(void) {
    UIWindow *window = SCITTLockWindow();
    if (!window || sciCover) return;

    // A solid view, not a blur: a blurred feed is still a picture of the feed.
    sciCover = [[UIView alloc] initWithFrame:window.bounds];
    sciCover.backgroundColor = UIColor.blackColor;
    sciCover.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    UILabel *label = [[UILabel alloc] init];
    label.text = SCILocalized(@"lock_title");
    label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    label.textColor = UIColor.whiteColor;
    label.textAlignment = NSTextAlignmentCenter;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [sciCover addSubview:label];
    [window addSubview:sciCover];
    [NSLayoutConstraint activateConstraints:@[
        [label.centerXAnchor constraintEqualToAnchor:sciCover.centerXAnchor],
        [label.centerYAnchor constraintEqualToAnchor:sciCover.centerYAnchor],
    ]];
}

static void SCITTAsk(void) {
    if (sciAsking) return;
    sciAsking = YES;
    sciAsked++;

    LAContext *context = [[LAContext alloc] init];
    NSError *error = nil;
    if (![context canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication error:&error]) {
        SCILogV(@"app lock: this device cannot authenticate (%@) — letting it through", error.localizedDescription ?: @"?");
        sciLetThrough++;
        sciUnlocked = YES;
        sciAsking = NO;
        SCITTRemoveCover();
        return;
    }

    [context evaluatePolicy:LAPolicyDeviceOwnerAuthentication localizedReason:SCILocalized(@"lock_reason") reply:^(BOOL success, NSError *failure) {
        dispatch_async(dispatch_get_main_queue(), ^{
            sciAsking = NO;
            if (success) {
                sciUnlocked = YES;
                sciPassed++;
                SCITTRemoveCover();
            } else {
                sciRefused++;      // the cover stays; the next activation asks again
            }
        });
    }];
}

static BOOL SCITTLockOn(void) { return SCIPrefEnabled(SCIPrefAppLock); }

NSString *SCITTAppLockReport(void) {
    if (!sciInstalled) return @"not installed";
    if (!SCITTLockOn()) return @"off";
    return [NSString stringWithFormat:@"on; asked %lu, passed %lu, refused %lu, device could not authenticate %lu",
            (unsigned long)sciAsked, (unsigned long)sciPassed, (unsigned long)sciRefused, (unsigned long)sciLetThrough];
}

void SCITTInstallAppLock(void) {
    if (sciInstalled) return;
    sciInstalled = YES;
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;

    [center addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
        if (!SCITTLockOn()) return;
        if (sciAsking) return;                  // the system's own sheet resigns the app too: do not lock under a question
        sciUnlocked = NO;
        SCITTShowCover();
    }];

    [center addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
        if (!SCITTLockOn()) {
            sciUnlocked = YES;
            SCITTRemoveCover();
            return;
        }
        if (sciUnlocked) {
            SCITTRemoveCover();
            return;
        }
        SCITTShowCover();
        SCITTAsk();
    }];
    SCILogV(@"app lock attached");
}
