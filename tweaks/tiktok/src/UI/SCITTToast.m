//
//  SCITTToast.m
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCITTToast.h"
#import "../Localization/SCILocalize.h"

static UIVisualEffectView *sciBanner = nil;
static UIImageView *sciIcon = nil;
static UILabel *sciLabel = nil;
static UIView *sciTrack = nil;
static UIView *sciFill = nil;
static UIButton *sciCancel = nil;
static void (^sciCancelHandler)(void) = nil;
static BOOL sciCancellable = NO;   // whether the banner on screen is showing its cancel button

/// The size of the cancel button's circle, and how much further out than the circle a finger may land and still count.
static const CGFloat kSCITTCancelDiameter = 30;
static const CGFloat kSCITTCancelSlop = 8;

/// **The banner takes a touch in one place only.** Everything else on it answers "not me" so the feed's scroll and taps go through to
/// where they were aimed; the cancel button answers inside its circle plus a thumb's worth of slop, because a 30-point target is
/// precise to hit and a download started by mistake is a moment to be forgiving about.
@interface SCITTBannerView : UIVisualEffectView
@end

@implementation SCITTBannerView
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (!sciCancellable || sciCancel.hidden || self.alpha < 0.5) return nil;
    CGRect target = CGRectInset(sciCancel.frame, -kSCITTCancelSlop, -kSCITTCancelSlop);
    return CGRectContainsPoint(target, point) ? sciCancel : nil;
}
@end

@implementation SCITTToast

///
/// The window to hang it on.
///
/// Taken from the foreground scene rather than from `-keyWindow`, which is deprecated and, in an
/// app with more than one window, answers whichever one asked last.
+ (UIWindow *)window {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive) continue;
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;

        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isKeyWindow) return window;
        }
        return ((UIWindowScene *)scene).windows.firstObject;
    }
    return nil;
}

+ (void)build:(UIWindow *)window {
    // Dark blur rather than a flat colour: the thing behind it is an arbitrary video frame, and
    // a material keeps the text legible over a white one without painting a black slab over the
    // picture.
    UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark];
    sciBanner = [[SCITTBannerView alloc] initWithEffect:effect];

    sciBanner.layer.cornerRadius = 22;
    sciBanner.layer.cornerCurve = kCACornerCurveContinuous;
    sciBanner.clipsToBounds = YES;
    sciBanner.alpha = 0;

    // **The whole point.** Nothing on the banner takes a touch except the cancel button, and the
    // banner's hit test makes sure of that (see SCITTBannerView), so the feed keeps scrolling under
    // it while a download runs.
    sciBanner.userInteractionEnabled = YES;

    UIView *content = sciBanner.contentView;

    sciIcon = [[UIImageView alloc] init];
    sciIcon.tintColor = [UIColor whiteColor];
    sciIcon.contentMode = UIViewContentModeScaleAspectFit;
    sciIcon.userInteractionEnabled = NO;
    [content addSubview:sciIcon];

    sciLabel = [[UILabel alloc] init];
    sciLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    sciLabel.textColor = [UIColor whiteColor];
    sciLabel.userInteractionEnabled = NO;
    sciLabel.adjustsFontSizeToFitWidth = YES;
    sciLabel.minimumScaleFactor = 0.8;

    // Follows the phone's own language direction rather than assuming a side, since every string
    // in this tweak exists in Arabic and English.
    sciLabel.textAlignment = NSTextAlignmentNatural;
    [content addSubview:sciLabel];

    sciTrack = [[UIView alloc] init];
    sciTrack.backgroundColor = [UIColor colorWithWhite:1 alpha:0.22];
    sciTrack.layer.cornerRadius = 1.5;
    sciTrack.clipsToBounds = YES;
    sciTrack.userInteractionEnabled = NO;
    [content addSubview:sciTrack];

    sciFill = [[UIView alloc] init];
    sciFill.backgroundColor = [UIColor whiteColor];
    sciFill.userInteractionEnabled = NO;
    [sciTrack addSubview:sciFill];

    // The cancel button: a small glass disc with an x, the same material as the banner one step lighter, so it reads as part of it and
    // as the one thing on it that answers a finger.
    sciCancel = [UIButton buttonWithType:UIButtonTypeCustom];
    sciCancel.frame = CGRectMake(0, 0, kSCITTCancelDiameter, kSCITTCancelDiameter);
    sciCancel.backgroundColor = [UIColor colorWithWhite:1 alpha:0.18];
    sciCancel.layer.cornerRadius = kSCITTCancelDiameter / 2;
    sciCancel.layer.cornerCurve = kCACornerCurveContinuous;
    UIImageSymbolConfiguration *xConfig = [UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightHeavy];
    [sciCancel setImage:[UIImage systemImageNamed:@"xmark" withConfiguration:xConfig] forState:UIControlStateNormal];
    sciCancel.tintColor = [UIColor whiteColor];
    sciCancel.accessibilityLabel = SCILocalized(@"save_cancel");
    [sciCancel addTarget:(id)self action:@selector(cancelPressedDown:) forControlEvents:UIControlEventTouchDown];
    [sciCancel addTarget:(id)self action:@selector(cancelReleased:)
        forControlEvents:UIControlEventTouchUpOutside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
    [sciCancel addTarget:(id)self action:@selector(cancelTapped:) forControlEvents:UIControlEventTouchUpInside];
    sciCancel.hidden = YES;
    [content addSubview:sciCancel];

    [window addSubview:sciBanner];
}

+ (void)layout:(UIWindow *)window {
    CGFloat width = MIN(320, window.bounds.size.width - 32);
    CGFloat height = 44;

    // Under the safe area at the top, which is where a notification belongs and where it covers
    // none of the video's subject.
    CGFloat top = window.safeAreaInsets.top + 8;

    sciBanner.frame = CGRectMake((window.bounds.size.width - width) / 2, top, width, height);

    // The text and the bar stop short of the cancel button when it is there, and run to the edge when it is not.
    CGFloat right = sciCancellable ? 14 + kSCITTCancelDiameter + 10 : 14;

    sciIcon.frame = CGRectMake(14, (height - 20) / 2, 20, 20);
    sciLabel.frame = CGRectMake(44, 8, width - 44 - right, 18);
    sciTrack.frame = CGRectMake(44, height - 15, width - 44 - right, 3);
    sciCancel.frame = CGRectMake(width - 14 - kSCITTCancelDiameter, (height - kSCITTCancelDiameter) / 2,
                                 kSCITTCancelDiameter, kSCITTCancelDiameter);
}

+ (void)setCancelHandler:(void (^)(void))handler {
    sciCancelHandler = [handler copy];
}

+ (void)showText:(NSString *)text symbol:(NSString *)symbol progress:(CGFloat)progress {
    [self present:text symbol:symbol progress:progress cancellable:YES];
}

+ (void)present:(NSString *)text symbol:(NSString *)symbol progress:(CGFloat)progress cancellable:(BOOL)cancellable {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [self window];
        if (!window) return;

        if (!sciBanner || sciBanner.window != window) {
            [sciBanner removeFromSuperview];
            [self build:window];
        }

        // The button belongs to a banner that is working and that has something to cancel.
        sciCancellable = cancellable && sciCancelHandler != nil;
        sciCancel.hidden = !sciCancellable;
        sciCancel.alpha = 1;
        sciCancel.enabled = YES;
        sciCancel.transform = CGAffineTransformIdentity;

        [self layout:window];

        // A banner that was last a notice had its bar hidden; every other state shows it.
        sciTrack.hidden = NO;
        sciIcon.tintColor = [UIColor whiteColor];
        sciFill.backgroundColor = [UIColor whiteColor];

        sciLabel.text = text;
        sciIcon.image = [UIImage systemImageNamed:symbol];

        CGFloat clamped = MAX(0, MIN(1, progress));
        CGFloat full = sciTrack.bounds.size.width;

        if (progress < 0) {
            // Nothing measurable yet — a quarter-width bar sliding across says "working" without
            // claiming a fraction it does not have. A bar frozen at 0% reads as stuck.
            sciFill.frame = CGRectMake(0, 0, full * 0.25, 3);

            [UIView animateWithDuration:0.9
                                  delay:0
                                options:UIViewAnimationOptionRepeat |
                                        UIViewAnimationOptionAutoreverse |
                                        UIViewAnimationOptionCurveEaseInOut
                             animations:^{
                sciFill.frame = CGRectMake(full * 0.75, 0, full * 0.25, 3);
            } completion:nil];
        } else {
            [sciFill.layer removeAllAnimations];
            [UIView animateWithDuration:0.2 animations:^{
                sciFill.frame = CGRectMake(0, 0, full * clamped, 3);
            }];
        }

        if (sciBanner.alpha < 1) {
            sciBanner.transform = CGAffineTransformMakeTranslation(0, -12);
            [UIView animateWithDuration:0.28
                                  delay:0
                 usingSpringWithDamping:0.85
                  initialSpringVelocity:0
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                sciBanner.alpha = 1;
                sciBanner.transform = CGAffineTransformIdentity;
            } completion:nil];
        }
    });
}

+ (void)finishWithText:(NSString *)text ok:(BOOL)ok {
    [self present:text
           symbol:ok ? @"checkmark.circle.fill" : @"exclamationmark.triangle.fill"
         progress:1
      cancellable:NO];

    dispatch_async(dispatch_get_main_queue(), ^{
        sciIcon.tintColor = ok ? [UIColor systemGreenColor] : [UIColor systemOrangeColor];
        sciFill.backgroundColor = sciIcon.tintColor;
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.2 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self dismiss];
    });
}

+ (void)noticeWithText:(NSString *)text symbol:(NSString *)symbol {
    [self present:text symbol:symbol progress:0 cancellable:NO];

    // Queued after the update above, on the same queue, so it applies to the banner that update built.
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!sciBanner) return;
        sciTrack.hidden = YES;
        sciLabel.frame = CGRectMake(44, (sciBanner.bounds.size.height - 18) / 2, sciLabel.frame.size.width, 18);
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.2 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self dismiss];
    });
}

+ (void)finishCancelledWithText:(NSString *)text {
    [self present:text symbol:@"xmark.circle.fill" progress:0 cancellable:NO];

    dispatch_async(dispatch_get_main_queue(), ^{
        // Neutral: the person asked for this, so it is neither the green of a save nor the orange of a failure, and there is no bar to
        // fill because nothing is left running.
        sciIcon.tintColor = [UIColor colorWithWhite:1 alpha:0.7];
        sciTrack.hidden = YES;
        if (sciBanner) {
            sciLabel.frame = CGRectMake(44, (sciBanner.bounds.size.height - 18) / 2, sciLabel.frame.size.width, 18);
        }
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.8 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self dismiss];
    });
}

+ (void)cancelPressedDown:(UIButton *)button {
    [UIView animateWithDuration:0.12 animations:^{
        button.transform = CGAffineTransformMakeScale(0.86, 0.86);
        button.backgroundColor = [UIColor colorWithWhite:1 alpha:0.32];
    }];
}

+ (void)cancelReleased:(UIButton *)button {
    [UIView animateWithDuration:0.18 animations:^{
        button.transform = CGAffineTransformIdentity;
        button.backgroundColor = [UIColor colorWithWhite:1 alpha:0.18];
    }];
}

+ (void)cancelTapped:(UIButton *)button {
    button.enabled = NO;   // one cancel per banner: a second tap on a half-faded button must not cancel the next download too
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium] impactOccurred];
    void (^handler)(void) = sciCancelHandler;
    if (handler) handler();
}

+ (void)dismiss {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!sciBanner) return;

        UIVisualEffectView *going = sciBanner;
        sciBanner = nil;

        [UIView animateWithDuration:0.22 animations:^{
            going.alpha = 0;
            going.transform = CGAffineTransformMakeTranslation(0, -12);
        } completion:^(BOOL finished) {
            [going removeFromSuperview];
        }];

        sciIcon.tintColor = [UIColor whiteColor];
        sciFill.backgroundColor = [UIColor whiteColor];
    });
}

@end
