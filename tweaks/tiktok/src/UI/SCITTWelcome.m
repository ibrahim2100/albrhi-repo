#import "SCITTMark.h"
#import "SCITTWelcome.h"
#import "../Tweak.h"
#import "../Prefs.h"
#import "../Localization/SCILocalize.h"

///
/// Built from the same material as everything else this tweak draws: a dark blurred card with a hairline edge, the accent
/// mark, the same corner curve. The saving banner, the feed button, the confirmation sheet and this screen are one family,
/// which is the whole reason the tweak looks deliberate rather than assembled.
///
/// **A view in the key window rather than a presented view controller**, for the reason `SCITTSheet` documents: TikTok often
/// has something presented already, and presenting onto a controller mid-transition either fails silently or throws. Here it
/// matters more than usual -- this runs seconds after launch, which is exactly when TikTok is putting its own things up.
///
/// **The edition.** Raise this when a release has something worth telling people; leave it alone when it only mends things.
/// Everyone whose stored edition is lower sees the screen once on their next launch.
///
static const NSInteger kSCIWelcomeEdition = 2;

/// The one welcome on screen, if any.
static UIView *sciWelcomeOverlay = nil;

/// A retry loop is running. One at a time: every window the tweak attaches to asks.
static BOOL sciWelcomeWaiting = NO;

@implementation SCITTWelcome

+ (UIWindow *)window {
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        if (scene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
            if (candidate.isKeyWindow) return candidate;
        }
    }
    return nil;
}

+ (void)showIfNeeded {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self showIfNeeded]; });
        return;
    }

    if ([[NSUserDefaults standardUserDefaults] integerForKey:SCIPrefWelcomeEdition] >= kSCIWelcomeEdition) return;
    if (sciWelcomeWaiting) return;
    sciWelcomeWaiting = YES;
    [self attempt:0];
}

/// Up to twelve tries, two and a half seconds apart. It gives up silently after that and tries again at the next launch,
/// because the edition is only recorded when the card is really drawn.
+ (void)attempt:(NSInteger)count {
    UIWindow *window = [self window];
    BOOL ready = window && [UIApplication sharedApplication].applicationState == UIApplicationStateActive;

    if (ready) {
        sciWelcomeWaiting = NO;
        // Recorded at the moment it is drawn: a launch that is killed a second later would otherwise show it again forever
        // on a device that keeps doing that, and a launch with no window would have used it up for nothing.
        [[NSUserDefaults standardUserDefaults] setInteger:kSCIWelcomeEdition forKey:SCIPrefWelcomeEdition];
        // Pushed to disk now: a launch that is killed within seconds of the card appearing must not lose the record (seen in the
        // simulator, where a relaunch two seconds later showed the card again).
        [[NSUserDefaults standardUserDefaults] synchronize];
        [self show];
        return;
    }

    if (count >= 12) { sciWelcomeWaiting = NO; return; }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self attempt:count + 1];
    });
}

+ (void)dismiss {
    UIView *overlay = sciWelcomeOverlay;
    if (!overlay) return;
    sciWelcomeOverlay = nil;

    UIView *card = [overlay viewWithTag:1];
    [UIView animateWithDuration:0.24 animations:^{
        overlay.alpha = 0;
        card.transform = CGAffineTransformMakeScale(0.96, 0.96);
    } completion:^(BOOL finished) {
        [overlay removeFromSuperview];
    }];
}

+ (void)startTapped {
    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [haptic impactOccurred];
    [self dismiss];
}

/// One thing that changed: a disc with a glyph, a title, and a line saying what it means.
+ (UIView *)rowWithSymbol:(NSString *)symbol
                    color:(UIColor *)color
                    title:(NSString *)title
                     note:(NSString *)note {
    UIView *disc = [[UIView alloc] init];
    disc.backgroundColor = [color colorWithAlphaComponent:0.22];
    disc.layer.cornerRadius = 11;
    disc.layer.cornerCurve = kCACornerCurveContinuous;
    disc.translatesAutoresizingMaskIntoConstraints = NO;
    [disc.widthAnchor constraintEqualToConstant:36].active = YES;
    [disc.heightAnchor constraintEqualToConstant:36].active = YES;

    UIImageView *glyph = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:symbol
                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:16
                                                                                 weight:UIImageSymbolWeightSemibold]]];
    glyph.tintColor = color;
    glyph.translatesAutoresizingMaskIntoConstraints = NO;
    [disc addSubview:glyph];
    [glyph.centerXAnchor constraintEqualToAnchor:disc.centerXAnchor].active = YES;
    [glyph.centerYAnchor constraintEqualToAnchor:disc.centerYAnchor].active = YES;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.numberOfLines = 0;

    UILabel *noteLabel = [[UILabel alloc] init];
    noteLabel.text = note;
    noteLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightRegular];
    noteLabel.textColor = [UIColor colorWithWhite:1 alpha:0.6];
    noteLabel.numberOfLines = 0;

    UIStackView *text = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, noteLabel]];
    text.axis = UILayoutConstraintAxisVertical;
    text.spacing = 2;

    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[disc, text]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 12;
    // Top, not centre: a two-line note would otherwise pull the disc down beside the second line.
    row.alignment = UIStackViewAlignmentTop;
    return row;
}

/// A short burst of confetti behind the card, once. Small rounded pieces in the tweak's own colours; it ends by itself, and
/// it is skipped entirely when the phone asks for reduced motion.
+ (void)burstConfettiOver:(UIView *)overlay {
    if (UIAccessibilityIsReduceMotionEnabled()) return;

    NSArray<UIColor *> *colors = @[SCIAccent(), [UIColor systemTealColor], [UIColor systemYellowColor],
                                   [UIColor systemPinkColor], [UIColor whiteColor]];
    NSMutableArray<CAEmitterCell *> *cells = [NSMutableArray array];
    for (UIColor *color in colors) {
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(10, 6)];
        UIImage *piece = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
            [color setFill];
            [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 10, 6) cornerRadius:2] fill];
        }];

        CAEmitterCell *cell = [CAEmitterCell emitterCell];
        cell.contents = (__bridge id)piece.CGImage;
        cell.birthRate = 14;
        cell.lifetime = 4.2;
        cell.velocity = 260;
        cell.velocityRange = 120;
        cell.yAcceleration = 330;
        cell.emissionLongitude = M_PI;          // up, then gravity brings it back
        cell.emissionRange = M_PI / 2.6;
        cell.spin = 3.2;
        cell.spinRange = 5;
        cell.scale = 0.9;
        cell.scaleRange = 0.5;
        cell.alphaSpeed = -0.28;
        [cells addObject:cell];
    }

    CAEmitterLayer *emitter = [CAEmitterLayer layer];
    emitter.frame = overlay.bounds;
    emitter.emitterPosition = CGPointMake(CGRectGetMidX(overlay.bounds), CGRectGetMaxY(overlay.bounds) * 0.9);
    emitter.emitterShape = kCAEmitterLayerLine;
    emitter.emitterSize = CGSizeMake(overlay.bounds.size.width * 0.9, 1);
    emitter.emitterCells = cells;
    // Above the card: confetti that falls behind a blurred card is confetti nobody sees.
    [overlay.layer addSublayer:emitter];

    // Stop making new ones after a moment; the ones in the air finish falling and the layer is removed after that.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.55 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        emitter.birthRate = 0;
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [emitter removeFromSuperlayer];
    });
}

+ (void)show {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self show]; });
        return;
    }

    UIWindow *window = [self window];
    if (!window) return;

    [self dismiss];

    UIView *overlay = [[UIView alloc] initWithFrame:window.bounds];
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
    overlay.alpha = 0;
    [window addSubview:overlay];

    UIVisualEffectView *card = [[UIVisualEffectView alloc] initWithEffect:
        [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterialDark]];
    card.tag = 1;
    card.layer.cornerRadius = 30;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.clipsToBounds = YES;
    card.layer.borderWidth = 0.5;
    card.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.14].CGColor;
    card.translatesAutoresizingMaskIntoConstraints = NO;
    [overlay addSubview:card];

    // The mark: the thin ring and arrow (`SCITTMark.h`), in the accent, straight on the card: no tile under it.
    UIImageView *mark = [[UIImageView alloc] initWithImage:SCITTMarkImage(72, SCIAccent())];
    mark.contentMode = UIViewContentModeScaleAspectFit;
    mark.translatesAutoresizingMaskIntoConstraints = NO;
    [mark.widthAnchor constraintEqualToConstant:72].active = YES;
    [mark.heightAnchor constraintEqualToConstant:72].active = YES;

    UIStackView *markRow = [[UIStackView alloc] initWithArrangedSubviews:@[mark]];
    markRow.axis = UILayoutConstraintAxisVertical;
    markRow.alignment = UIStackViewAlignmentCenter;

    UILabel *title = [[UILabel alloc] init];
    title.text = SCILocalized(@"welcome_title");
    title.font = [UIFont systemFontOfSize:24 weight:UIFontWeightHeavy];
    title.textColor = [UIColor whiteColor];
    title.textAlignment = NSTextAlignmentCenter;
    title.numberOfLines = 0;

    UILabel *subtitle = [[UILabel alloc] init];
    // The version number is isolated left-to-right (U+2066 ... U+2069): inside an Arabic sentence the bidi algorithm would
    // otherwise move the "v" and the dots around the line.
    subtitle.text = [NSString stringWithFormat:SCILocalized(@"welcome_subtitle"),
                     [NSString stringWithFormat:@"\u2066%@\u2069", SCIVersionString]];
    subtitle.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightMedium];
    subtitle.textColor = [UIColor colorWithWhite:1 alpha:0.62];
    subtitle.textAlignment = NSTextAlignmentCenter;
    subtitle.numberOfLines = 0;

    UIStackView *rows = [[UIStackView alloc] init];
    rows.axis = UILayoutConstraintAxisVertical;
    rows.spacing = 15;
    NSArray<UIView *> *entries = @[
        [self rowWithSymbol:@"gearshape.fill" color:SCIAccent()
                      title:SCILocalized(@"welcome_r1") note:SCILocalized(@"welcome_r1_note")],
        [self rowWithSymbol:@"list.bullet.rectangle.fill" color:[UIColor systemTealColor]
                      title:SCILocalized(@"welcome_r2") note:SCILocalized(@"welcome_r2_note")],
        [self rowWithSymbol:@"photo.stack.fill" color:[UIColor systemPinkColor]
                      title:SCILocalized(@"welcome_r3") note:SCILocalized(@"welcome_r3_note")],
        [self rowWithSymbol:@"eye.slash.fill" color:[UIColor systemYellowColor]
                      title:SCILocalized(@"welcome_r4") note:SCILocalized(@"welcome_r4_note")],
    ];
    for (UIView *entry in entries) [rows addArrangedSubview:entry];

    UILabel *joke = [[UILabel alloc] init];
    joke.text = SCILocalized(@"welcome_joke");
    joke.font = [UIFont italicSystemFontOfSize:12.5];
    joke.textColor = [UIColor colorWithWhite:1 alpha:0.5];
    joke.textAlignment = NSTextAlignmentCenter;
    joke.numberOfLines = 0;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[markRow, title, subtitle]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 8;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [stack setCustomSpacing:14 afterView:markRow];
    [stack setCustomSpacing:22 afterView:subtitle];
    [stack addArrangedSubview:rows];
    [card.contentView addSubview:stack];

    // **The panel gate, said here or nowhere.** A fresh install of the suite patches nothing until the app is switched on in
    // Settings › Albrhi -- that is deliberate, since one install carries four tweaks -- and somebody meeting this screen for
    // the first time is exactly the person who would otherwise conclude the tweak is broken. Shown only when it is off.
    UIView *last = rows;
    if (!SCIPanelAllowsThisApp()) {
        UILabel *gate = [[UILabel alloc] init];
        gate.text = SCILocalized(@"gate_off");
        gate.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightSemibold];
        gate.textColor = [UIColor systemOrangeColor];
        gate.textAlignment = NSTextAlignmentCenter;
        gate.numberOfLines = 0;

        UIView *banner = [[UIView alloc] init];
        banner.backgroundColor = [[UIColor systemOrangeColor] colorWithAlphaComponent:0.14];
        banner.layer.cornerRadius = 12;
        banner.layer.cornerCurve = kCACornerCurveContinuous;
        gate.translatesAutoresizingMaskIntoConstraints = NO;
        [banner addSubview:gate];
        [NSLayoutConstraint activateConstraints:@[
            [gate.topAnchor constraintEqualToAnchor:banner.topAnchor constant:10],
            [gate.bottomAnchor constraintEqualToAnchor:banner.bottomAnchor constant:-10],
            [gate.leadingAnchor constraintEqualToAnchor:banner.leadingAnchor constant:12],
            [gate.trailingAnchor constraintEqualToAnchor:banner.trailingAnchor constant:-12],
        ]];
        [stack setCustomSpacing:18 afterView:last];
        [stack addArrangedSubview:banner];
        last = banner;
    }

    [stack setCustomSpacing:18 afterView:last];
    [stack addArrangedSubview:joke];

    UIButton *start = [UIButton buttonWithType:UIButtonTypeSystem];
    start.backgroundColor = SCIAccent();
    start.layer.cornerRadius = 15;
    start.layer.cornerCurve = kCACornerCurveContinuous;
    start.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    [start setTitle:SCILocalized(@"welcome_start") forState:UIControlStateNormal];
    [start setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [start addTarget:self action:@selector(startTapped) forControlEvents:UIControlEventTouchUpInside];
    [start.heightAnchor constraintEqualToConstant:54].active = YES;

    [stack setCustomSpacing:18 afterView:joke];
    [stack addArrangedSubview:start];

    [NSLayoutConstraint activateConstraints:@[
        [card.centerXAnchor constraintEqualToAnchor:overlay.centerXAnchor],
        [card.centerYAnchor constraintEqualToAnchor:overlay.centerYAnchor],
        [card.widthAnchor constraintLessThanOrEqualToConstant:360],
        [card.leadingAnchor constraintGreaterThanOrEqualToAnchor:overlay.leadingAnchor constant:20],
        [card.trailingAnchor constraintLessThanOrEqualToAnchor:overlay.trailingAnchor constant:-20],
        // Never taller than the screen it is drawn on: the card grows with its text, and a long translation on a small phone
        // would otherwise run off both ends with no way to reach the button.
        [card.topAnchor constraintGreaterThanOrEqualToAnchor:overlay.safeAreaLayoutGuide.topAnchor constant:12],
        [card.bottomAnchor constraintLessThanOrEqualToAnchor:overlay.safeAreaLayoutGuide.bottomAnchor constant:-12],

        [stack.topAnchor constraintEqualToAnchor:card.contentView.topAnchor constant:26],
        [stack.leadingAnchor constraintEqualToAnchor:card.contentView.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:card.contentView.trailingAnchor constant:-20],
        [stack.bottomAnchor constraintEqualToAnchor:card.contentView.bottomAnchor constant:-20],
    ]];

    NSLayoutConstraint *wide = [card.widthAnchor constraintEqualToConstant:360];
    wide.priority = UILayoutPriorityDefaultHigh;
    wide.active = YES;

    sciWelcomeOverlay = overlay;

    BOOL still = UIAccessibilityIsReduceMotionEnabled();

    card.transform = CGAffineTransformMakeScale(0.94, 0.94);
    if (!still) {
        // The rows come in one after another, and the mark pops: the screen is read top to bottom and it should feel like it.
        mark.transform = CGAffineTransformMakeScale(0.4, 0.4);
        mark.alpha = 0;
        [entries enumerateObjectsUsingBlock:^(UIView *entry, NSUInteger i, BOOL *stop) {
            entry.alpha = 0;
            entry.transform = CGAffineTransformMakeTranslation(0, 14);
        }];
        joke.alpha = 0;
    }

    [UIView animateWithDuration:0.42
                          delay:0
         usingSpringWithDamping:0.82
          initialSpringVelocity:0
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        overlay.alpha = 1;
        card.transform = CGAffineTransformIdentity;
    } completion:nil];

    if (still) return;

    [UIView animateWithDuration:0.55 delay:0.12 usingSpringWithDamping:0.5 initialSpringVelocity:0.8
                        options:UIViewAnimationOptionAllowUserInteraction animations:^{
        mark.transform = CGAffineTransformIdentity;
        mark.alpha = 1;
    } completion:nil];

    [entries enumerateObjectsUsingBlock:^(UIView *entry, NSUInteger i, BOOL *stop) {
        [UIView animateWithDuration:0.45 delay:0.35 + 0.13 * (double)i usingSpringWithDamping:0.86 initialSpringVelocity:0
                            options:UIViewAnimationOptionAllowUserInteraction animations:^{
            entry.alpha = 1;
            entry.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
    [UIView animateWithDuration:0.5 delay:0.35 + 0.13 * (double)entries.count + 0.1 options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{ joke.alpha = 1; } completion:nil];

    [self burstConfettiOver:overlay];
}

@end
