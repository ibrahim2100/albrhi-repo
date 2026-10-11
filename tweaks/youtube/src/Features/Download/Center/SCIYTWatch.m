#import "SCIYTWatch.h"
#import "SCIYTLibrary.h"
#import "SCIYTPlayer.h"
#import "../SCIYTDirect.h"
#import "../../../Prefs.h"
#import "../../../SCILog.h"
#import "../../../SCIYTLaunchGuard.h"
#import "../../../Localization/SCILocalize.h"
#import "../../../Diagnostics/SCIYTDiagnostics.h"

static NSUInteger sciOffered = 0, sciAccepted = 0, sciStarted = 0, sciPlayed = 0, sciFailed = 0, sciReused = 0;
static NSUInteger sciAsked = 0, sciNoPresenter = 0, sciSwitchOff = 0, sciRateLimited = 0, sciNoWindow = 0, sciAlertUp = 0;

/// The app's key window's root, found without the overlay that reported the error: that overlay
/// is a child of the player, and `-view.window` on it can be nil at the moment an error is drawn.
static UIViewController *SCIYTAppRoot(void) {
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *window in [(UIWindowScene *)scene windows]) {
            if (window.isKeyWindow && window.rootViewController) return window.rootViewController;
        }
    }
    return nil;
}
static NSString *sciLastFailure = nil;

static UIViewController *SCIYTTop(UIViewController *controller) {
    UIViewController *top = controller;
    while (top.presentedViewController && !top.presentedViewController.isBeingDismissed) {
        top = top.presentedViewController;
    }
    return top;
}

@interface SCIYTWatch (Private)
+ (void)presentPlayerForJob:(SCIYTJob *)job from:(UIViewController *)presenter afterDismissing:(UIAlertController *)alert;
+ (void)showMessage:(NSString *)message from:(UIViewController *)presenter afterDismissing:(UIAlertController *)alert;
@end


/// One watch in progress: the waiting dialog, the job it follows, and the notification that
/// tells it the job moved. Held by a static set for exactly as long as it is needed -- a
/// download outlives the call that started it, and an observer with no owner is one that is
/// never removed.
@interface SCIYTWatchSession : NSObject
@property (nonatomic, strong) SCIYTJob *job;
@property (nonatomic, weak) UIViewController *presenter;
@property (nonatomic, strong) UIAlertController *alert;
@property (nonatomic, strong) id observer;
@property (nonatomic) BOOL stopped;
@end

static NSMutableSet<SCIYTWatchSession *> *sSessions = nil;

@implementation SCIYTWatchSession

- (void)begin {
    if (!sSessions) sSessions = [NSMutableSet set];
    [sSessions addObject:self];

    self.alert = [UIAlertController alertControllerWithTitle:SCILocalized(@"watch_preparing")
                                                     message:[self progressLine]
                                              preferredStyle:UIAlertControllerStyleAlert];
    __weak __typeof(self) weakSelf = self;
    [self.alert addAction:[UIAlertAction actionWithTitle:SCILocalized(@"watch_stop")
                                                   style:UIAlertActionStyleCancel
                                                 handler:^(__unused UIAlertAction *action) {
        // Stops *waiting*. The download is a row in the Centre and carries on; ending it is
        // a swipe there, and a "stop" that also threw away a nearly finished file would be
        // the surprising half of this button.
        [weakSelf end];
    }]];

    UIViewController *presenter = self.presenter;
    if (presenter) [SCIYTTop(presenter) presentViewController:self.alert animated:YES completion:nil];

    self.observer = [[NSNotificationCenter defaultCenter]
        addObserverForName:SCIYTLibraryDidChangeNotification object:nil
                     queue:[NSOperationQueue mainQueue]
                usingBlock:^(__unused NSNotification *note) { [weakSelf moved]; }];

    // A job can be whole before the observer exists (a tiny video, a very fast line).
    [self moved];
}

- (NSString *)progressLine {
    int percent = (int)(self.job.progress * 100);
    return [NSString stringWithFormat:SCILocalized(@"watch_progress"), percent];
}

- (void)moved {
    if (self.stopped) return;

    switch (self.job.state) {
        case SCIYTJobStateWorking:
            self.alert.message = [self progressLine];
            break;

        case SCIYTJobStateDone: {
            [self end];
            sciPlayed++;
            [SCIYTWatch presentPlayerForJob:self.job from:self.presenter afterDismissing:self.alert];
            break;
        }

        case SCIYTJobStateFailed: {
            [self end];
            sciFailed++;
            sciLastFailure = self.job.failure;
            NSString *message = [NSString stringWithFormat:SCILocalized(@"watch_failed"),
                                 self.job.failure ?: SCILocalized(@"dl_failed")];
            [SCIYTWatch showMessage:message from:self.presenter afterDismissing:self.alert];
            break;
        }
    }
}

- (void)end {
    self.stopped = YES;
    if (self.observer) [[NSNotificationCenter defaultCenter] removeObserver:self.observer];
    self.observer = nil;
    [sSessions removeObject:self];
}

@end


@implementation SCIYTWatch

+ (SCIHLSVariant *)bestVariantToWatch:(NSArray<SCIHLSVariant *> *)variants {
    SCIHLSVariant *best = nil;      // tallest within the limit
    SCIHLSVariant *smallest = nil;  // the fallback when everything is taller

    for (SCIHLSVariant *variant in variants) {
        if ([variant.codecs.lowercaseString containsString:@"av01"]) continue;

        if (!smallest || (variant.height > 0 && variant.height < smallest.height)) smallest = variant;
        if (variant.height <= 720 && (!best || variant.height > best.height)) best = variant;
    }
    return best ?: smallest;
}

+ (void)watchVariant:(SCIHLSVariant *)variant
               title:(NSString *)title
             videoID:(NSString *)videoID
                from:(UIViewController *)presenter {
    if (!variant || !presenter) return;

    // Already here: play it, do not fetch it twice.
    SCIYTJob *existing = [[SCIYTLibrary shared] existingJobForVideo:videoID kind:SCIYTJobKindVideo];
    if (existing) {
        sciReused++;
        [self presentPlayerForJob:existing from:presenter afterDismissing:nil];
        return;
    }

    sciStarted++;
    SCIYTJob *job = [[SCIYTLibrary shared] startVariant:variant
                                                    kind:SCIYTJobKindVideo
                                                   title:title
                                                 videoID:videoID
                                                 isShort:NO];
    SCIYTWatchSession *session = [[SCIYTWatchSession alloc] init];
    session.job = job;
    session.presenter = presenter;
    [session begin];
}

+ (void)watchVideoID:(NSString *)videoID title:(NSString *)title from:(UIViewController *)presenter {
    if (!videoID.length || !presenter) return;
    sciAccepted++;

    UIAlertController *asking = [UIAlertController alertControllerWithTitle:SCILocalized(@"watch_preparing")
                                                                    message:SCILocalized(@"dl_asking")
                                                             preferredStyle:UIAlertControllerStyleAlert];
    [SCIYTTop(presenter) presentViewController:asking animated:YES completion:nil];

    __weak UIViewController *weakPresenter = presenter;
    [SCIYTDirect variantsForVideo:videoID completion:^(NSArray<SCIHLSVariant *> *variants, NSString *failure) {
        dispatch_async(dispatch_get_main_queue(), ^{
            void (^proceed)(void) = ^{
                UIViewController *host = weakPresenter;
                if (!host) return;

                SCIHLSVariant *pick = [self bestVariantToWatch:variants];
                if (!pick) {
                    sciFailed++;
                    sciLastFailure = failure;
                    [self showMessage:[NSString stringWithFormat:SCILocalized(@"watch_failed"),
                                       failure ?: SCILocalized(@"dl_failed")]
                                 from:host afterDismissing:nil];
                    return;
                }
                [self watchVariant:pick
                             title:title ?: [SCIYTDiagnostics titleForVideoID:videoID]
                           videoID:videoID
                              from:host];
            };

            if (asking.presentingViewController) {
                [asking dismissViewControllerAnimated:YES completion:proceed];
            } else {
                proceed();
            }
        });
    }];
}

+ (void)presentPlayerForJob:(SCIYTJob *)job from:(UIViewController *)presenter afterDismissing:(UIAlertController *)alert {
    void (^open)(void) = ^{
        if (!presenter) return;
        [SCIYTPlayer presentFrom:SCIYTTop(presenter) jobs:@[job] start:0];
    };
    if (alert.presentingViewController) {
        [alert dismissViewControllerAnimated:YES completion:open];
    } else {
        open();
    }
}

+ (void)showMessage:(NSString *)message from:(UIViewController *)presenter afterDismissing:(UIAlertController *)alert {
    void (^show)(void) = ^{
        if (!presenter) return;
        UIAlertController *note = [UIAlertController alertControllerWithTitle:nil message:message
                                                               preferredStyle:UIAlertControllerStyleAlert];
        [note addAction:[UIAlertAction actionWithTitle:SCILocalized(@"ok") style:UIAlertActionStyleDefault handler:nil]];
        [SCIYTTop(presenter) presentViewController:note animated:YES completion:nil];
    };
    if (alert.presentingViewController) {
        [alert dismissViewControllerAnimated:YES completion:show];
    } else {
        show();
    }
}

// MARK: - After a failure

+ (void)offerAfterFailureFrom:(UIViewController *)presenter videoID:(NSString *)videoID {
    // Every way out is counted, because "0 offered" says nothing about *which* check stopped it
    // -- and the first report from a phone that failed said exactly that.
    sciAsked++;
    if (!presenter || !videoID.length) { sciNoPresenter++; return; }
    if (!SCIPrefEnabled(SCIPrefOfferWatch) || SCIYTStoodDown()) { sciSwitchOff++; return; }

    // Once per video a minute: the error screen is reached more than once for one failure
    // (a reload, a retry, the app's own second attempt), and a dialog that reappears on top of
    // a "Not now" is a dialog people stop reading.
    static NSMutableDictionary<NSString *, NSDate *> *asked = nil;
    if (!asked) asked = [NSMutableDictionary dictionary];
    NSDate *last = asked[videoID];
    if (last && [[NSDate date] timeIntervalSinceDate:last] < 60) { sciRateLimited++; return; }
    asked[videoID] = [NSDate date];

    // The window's own root, not the overlay that reported the error: the overlay is a child of
    // the player and a dialog is presented from whatever is on top of the whole app.
    __weak UIViewController *weakPresenter = SCIYTAppRoot() ?: presenter.view.window.rootViewController ?: presenter;
    NSString *title = [SCIYTDiagnostics titleForVideoID:videoID];

    // The next turn, not this one: the app's own error is being drawn right now, and a dialog
    // presented from inside that call is presented over a screen that is still being built.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIViewController *host = weakPresenter;
        if (!host || !host.view.window) { sciNoWindow++; return; }
        if (host.presentedViewController && [host.presentedViewController isKindOfClass:[UIAlertController class]]) { sciAlertUp++; return; }

        sciOffered++;
        UIAlertController *offer = [UIAlertController alertControllerWithTitle:SCILocalized(@"watch_offer_title")
                                                                       message:SCILocalized(@"watch_offer_message")
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [offer addAction:[UIAlertAction actionWithTitle:SCILocalized(@"watch_offer_no")
                                                   style:UIAlertActionStyleCancel handler:nil]];
        [offer addAction:[UIAlertAction actionWithTitle:SCILocalized(@"watch_offer_yes")
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(__unused UIAlertAction *action) {
            UIViewController *again = weakPresenter;
            if (again) [self watchVideoID:videoID title:title from:again];
        }]];
        [SCIYTTop(host) presentViewController:offer animated:YES completion:nil];
    });
}

+ (NSString *)report {
    NSString *line = [NSString stringWithFormat:
        @"watch here: %lu asked (%lu no player/video id · %lu switch off · %lu rate-limited · %lu no window · %lu dialog already up) · %lu offered · %lu accepted · %lu fetched · %lu already saved · %lu played · %lu failed",
        (unsigned long)sciAsked, (unsigned long)sciNoPresenter, (unsigned long)sciSwitchOff,
        (unsigned long)sciRateLimited, (unsigned long)sciNoWindow, (unsigned long)sciAlertUp,
        (unsigned long)sciOffered, (unsigned long)sciAccepted, (unsigned long)sciStarted,
        (unsigned long)sciReused, (unsigned long)sciPlayed, (unsigned long)sciFailed];
    return sciLastFailure.length ? [line stringByAppendingFormat:@" · last failure: %@", sciLastFailure] : line;
}

@end
