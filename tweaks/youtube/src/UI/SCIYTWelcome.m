#import "SCIYTWelcome.h"
#import "../Tweak.h"
#import "../Prefs.h"
#import "../SCILog.h"
#import "../Localization/SCILocalize.h"
#import "../Features/Download/Center/SCIYTIcon.h"
#import "SCIYTWindow.h"

/// Which version last said hello. A string rather than a flag, so a later release can show
/// this again for something worth mentioning without anyone having to invent a second key.
static NSString *const kSCIWelcomeShown = @"welcome_shown_version";


@implementation SCIYTWelcome

+ (void)showIfFirstRun {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([[defaults stringForKey:kSCIWelcomeShown] length]) return;

    // Marked before showing, not after. If building the screen throws, the tweak has one
    // bad launch rather than one bad launch on every launch forever.
    [defaults setObject:SCIVersionString forKey:kSCIWelcomeShown];

    // Late, and only once the app has a window worth presenting on. Run at load time this
    // finds no root view controller and does nothing at all, which is the quietest way for
    // a welcome screen to never appear.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        @try {
            [self present];
        } @catch (NSException *exception) {
            SCILogV(@"welcome: could not show — %@", exception.reason);
        }
    });
}

+ (void)present {
    UIWindow *window = SCIYTKeyWindow();
    if (!window) return;

    UIViewController *top = window.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;

    // Not over another sheet. Someone who opened something in the first seconds is doing
    // something; a greeting can wait for the next launch.
    if (!top || top != window.rootViewController) return;

    [top presentViewController:[[SCIYTWelcome alloc] init] animated:YES completion:nil];
}

- (instancetype)init {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        self.modalPresentationStyle = UIModalPresentationPageSheet;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.06 alpha:1.0];

    UIImageView *mark = [[UIImageView alloc] initWithImage:
        [SCIYTIcon downloadMarkOfSize:64 filled:YES]];
    mark.tintColor = SCIAccent();
    mark.contentMode = UIViewContentModeScaleAspectFit;

    UILabel *title = [[UILabel alloc] init];
    title.text = SCILocalized(@"welcome_title");
    title.font = [UIFont systemFontOfSize:26 weight:UIFontWeightBold];
    title.textColor = [UIColor whiteColor];
    title.textAlignment = NSTextAlignmentCenter;
    title.numberOfLines = 2;

    UILabel *version = [[UILabel alloc] init];
    version.text = SCIVersionString;
    version.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightMedium];
    version.textColor = SCIAccent();
    version.textAlignment = NSTextAlignmentCenter;

    UILabel *body = [[UILabel alloc] init];
    body.text = SCILocalized(@"welcome_body");
    body.font = [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
    body.textColor = [UIColor colorWithWhite:1 alpha:0.72];
    body.textAlignment = NSTextAlignmentCenter;
    body.numberOfLines = 0;

    UIButton *go = [UIButton buttonWithType:UIButtonTypeSystem];
    [go setTitle:SCILocalized(@"welcome_go") forState:UIControlStateNormal];
    [go setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    go.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    go.backgroundColor = SCIAccent();
    go.layer.cornerRadius = 14;
    go.layer.cornerCurve = kCACornerCurveContinuous;
    [go addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    [go.heightAnchor constraintEqualToConstant:52].active = YES;

    // One stack, pinned to its own margins and to nothing else. The settings panel this
    // project rebuilt three times died in CoreAutoLayout both times it was written as
    // siblings pinned to each other.
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:
        @[mark, title, version, body]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 12;
    [stack setCustomSpacing:20 afterView:mark];
    [stack setCustomSpacing:24 afterView:version];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];

    go.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:go];

    [NSLayoutConstraint activateConstraints:@[
        [stack.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-40],
        [stack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:32],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-32],

        [mark.heightAnchor constraintEqualToConstant:64],
        [mark.widthAnchor constraintEqualToConstant:64],

        [go.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:32],
        [go.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-32],
        [go.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor
                                        constant:-24]
    ]];
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
