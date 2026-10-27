//
//  main.m  --  the Albrhi Mirror app
//
//  The one place on the phone where mirroring is switched on and off and where a Mac is paired. It talks to the daemon over
//  a Unix socket (`/var/mobile/Library/AlbrhiMirror/control.sock`, owned by mobile, mode 0600): status, enable, disable,
//  pair-start (the daemon answers with a six-digit code, which this screen shows), pair-cancel, unpair.
//
//  Pairing can only be started here, with the person holding the phone. That is the point of having an app: a Mac that
//  merely asks is refused, and so is any other app on the phone.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

// ---- strings (English and Arabic) ---------------------------------------------------------------------------------
static BOOL Arabic(void) { return [[NSLocale preferredLanguages].firstObject hasPrefix:@"ar"]; }
static NSString *T(NSString *en, NSString *ar) { return Arabic() ? ar : en; }

// ---- the control socket -------------------------------------------------------------------------------------------
static NSString *SocketPath(void) {
#if TARGET_OS_SIMULATOR
    // A simulated phone shares the Mac's filesystem; tests point the app at a host build of the daemon.
    const char *override = getenv("ALBRHI_CONTROL_SOCKET");
    if (override) return @(override);
#endif
    return @"/var/mobile/Library/AlbrhiMirror/control.sock";
}

/// One request, one answer. nil when the daemon is not there.
static NSDictionary *Ask(NSString *command) {
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    struct sockaddr_un address = { .sun_family = AF_UNIX };
    NSString *path = SocketPath();
    if (path.length >= sizeof(address.sun_path)) { close(fd); return nil; }
    strlcpy(address.sun_path, path.fileSystemRepresentation, sizeof(address.sun_path));
    address.sun_len = (uint8_t)SUN_LEN(&address);
    struct timeval limit = { 2, 0 };
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &limit, sizeof(limit));
    if (connect(fd, (struct sockaddr *)&address, sizeof(address)) != 0) { close(fd); return nil; }
    NSData *request = [NSJSONSerialization dataWithJSONObject:@{ @"cmd": command } options:0 error:nil];
    send(fd, request.bytes, request.length, 0);
    NSMutableData *answer = [NSMutableData data];
    char buffer[2048]; ssize_t n;
    while ((n = recv(fd, buffer, sizeof(buffer), 0)) > 0) [answer appendBytes:buffer length:(NSUInteger)n];
    close(fd);
    id object = answer.length ? [NSJSONSerialization JSONObjectWithData:answer options:0 error:nil] : nil;
    return [object isKindOfClass:[NSDictionary class]] ? object : nil;
}

// ---- the screen ---------------------------------------------------------------------------------------------------
@interface MirrorViewController : UIViewController
@property (nonatomic) UILabel *state, *codeLabel, *codeNote, *note;
@property (nonatomic) UISwitch *toggle;
@property (nonatomic) UIButton *pairButton, *forgetButton;
@property (nonatomic) NSTimer *timer;
@property (nonatomic) BOOL updating;
@end

@implementation MirrorViewController

- (UILabel *)label:(UIFont *)font color:(UIColor *)color {
    UILabel *label = [[UILabel alloc] init];
    label.font = font; label.textColor = color; label.numberOfLines = 0; label.textAlignment = NSTextAlignmentNatural;
    return label;
}

- (UIButton *)button:(NSString *)title filled:(BOOL)filled destructive:(BOOL)destructive action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    button.layer.cornerRadius = 12;
    button.contentEdgeInsets = UIEdgeInsetsMake(14, 20, 14, 20);
    if (filled) { button.backgroundColor = [UIColor systemBlueColor]; [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal]; }
    else if (destructive) { [button setTitleColor:UIColor.systemRedColor forState:UIControlStateNormal]; }
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

/// `semanticContentAttribute` is not inherited by a view's children: every one has to be told, or the labels stay left-aligned and
/// the switch stays on the right in an Arabic layout. The code is digits and stays left to right.
- (void)applyDirection:(UIView *)view {
    if (view == self.codeLabel) { view.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight; return; }
    view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    for (UIView *child in view.subviews) [self applyDirection:child];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;

    UILabel *title = [self label:[UIFont systemFontOfSize:30 weight:UIFontWeightBold] color:UIColor.labelColor];
    title.text = T(@"Albrhi Mirror", @"البرهي ميرور");

    self.state = [self label:[UIFont systemFontOfSize:15] color:UIColor.secondaryLabelColor];

    UILabel *toggleLabel = [self label:[UIFont systemFontOfSize:17 weight:UIFontWeightMedium] color:UIColor.labelColor];
    toggleLabel.text = T(@"Allow mirroring", @"السماح بالعرض على الماك");
    self.toggle = [[UISwitch alloc] init];
    [self.toggle addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged];
    UIStackView *toggleRow = [[UIStackView alloc] initWithArrangedSubviews:@[ toggleLabel, self.toggle ]];
    toggleRow.alignment = UIStackViewAlignmentCenter; toggleRow.spacing = 12;
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor; card.layer.cornerRadius = 14;
    toggleRow.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:toggleRow];
    [NSLayoutConstraint activateConstraints:@[
        [toggleRow.topAnchor constraintEqualToAnchor:card.topAnchor constant:14], [toggleRow.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14],
        [toggleRow.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16], [toggleRow.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
    ]];

    self.pairButton = [self button:T(@"Pair a Mac", @"اقتران بماك") filled:YES destructive:NO action:@selector(pair)];
    self.codeLabel = [self label:[UIFont monospacedDigitSystemFontOfSize:56 weight:UIFontWeightBold] color:UIColor.labelColor];
    self.codeLabel.textAlignment = NSTextAlignmentCenter; self.codeLabel.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    self.codeNote = [self label:[UIFont systemFontOfSize:15] color:UIColor.secondaryLabelColor];
    self.codeNote.textAlignment = NSTextAlignmentCenter;
    self.forgetButton = [self button:T(@"Forget the pairing", @"إلغاء الاقتران") filled:NO destructive:YES action:@selector(forget)];
    self.note = [self label:[UIFont systemFontOfSize:13] color:UIColor.tertiaryLabelColor];
    self.note.text = T(@"The Mac app shows the screen of this iPhone. Nothing is shared unless the switch is on and a paired Mac connects over USB.",
                       @"تطبيق الماك يعرض شاشة هذا الآيفون. لا يُشارك شيء إلا إذا كان المفتاح مفعّلاً واتصل ماك مقترن عبر USB.");

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[ title, self.state, card, self.pairButton, self.codeLabel, self.codeNote, self.forgetButton, self.note ]];
    stack.axis = UILayoutConstraintAxisVertical; stack.spacing = 14; stack.translatesAutoresizingMaskIntoConstraints = NO;
    [stack setCustomSpacing:22 afterView:self.state];
    [self.view addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:28],
        [stack.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-20],
    ]];
    if (Arabic()) [self applyDirection:self.view];
    [self refresh];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(refresh) userInfo:nil repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated]; [self.timer invalidate]; }

/// Asks the daemon in the background and updates the screen from what it said.
- (void)refresh { [self send:@"status"]; }

- (void)send:(NSString *)command {
    if (self.updating && [command isEqual:@"status"]) return;
    self.updating = YES;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSDictionary *status = Ask(command);
        dispatch_async(dispatch_get_main_queue(), ^{ self.updating = NO; [self show:status]; });
    });
}

- (void)show:(NSDictionary *)status {
    BOOL running = status != nil && !status[@"error"];
    BOOL enabled = [status[@"enabled"] boolValue], paired = [status[@"paired"] boolValue], session = [status[@"session"] boolValue];
    NSDictionary *pairing = [status[@"pairing"] isKindOfClass:[NSDictionary class]] ? status[@"pairing"] : nil;

    if (!running) {
        self.state.text = status[@"error"] ?: T(@"The service is not running. Restart the iPhone or reinstall the package.", @"الخدمة غير شغّالة. أعد تشغيل الآيفون أو أعد تثبيت الحزمة.");
        self.state.textColor = UIColor.systemRedColor;
    } else if (!enabled) {
        self.state.text = T(@"Off. Nothing is shared.", @"مطفأ. لا يُشارك شيء.");
        self.state.textColor = UIColor.secondaryLabelColor;
    } else if (session) {
        self.state.text = T(@"A Mac is connected.", @"ماك متصل الآن.");
        self.state.textColor = UIColor.systemGreenColor;
    } else {
        self.state.text = paired ? T(@"On. Waiting for the paired Mac.", @"مفعّل. بانتظار الماك المقترن.") : T(@"On. No Mac is paired yet.", @"مفعّل. لا يوجد ماك مقترن بعد.");
        self.state.textColor = UIColor.systemOrangeColor;
    }

    self.toggle.enabled = running;
    if (self.toggle.on != enabled && !self.toggle.isTracking) [self.toggle setOn:enabled animated:YES];

    self.pairButton.hidden = !(running && enabled) || pairing != nil;
    self.pairButton.alpha = 1;
    [self.pairButton setTitle:paired ? T(@"Pair another Mac", @"اقتران بماك آخر") : T(@"Pair a Mac", @"اقتران بماك") forState:UIControlStateNormal];

    self.codeLabel.hidden = self.codeNote.hidden = pairing == nil;
    if (pairing) {
        NSString *code = pairing[@"code"];
        self.codeLabel.text = code.length == 6 ? [NSString stringWithFormat:@"%@ %@", [code substringToIndex:3], [code substringFromIndex:3]] : code;
        self.codeNote.text = [NSString stringWithFormat:T(@"Type this code in the Albrhi Mirror app on the Mac.\n%@ s left · %@ tries left", @"اكتب هذا الرمز في تطبيق البرهي ميرور على الماك.\nباقي %@ ثانية · %@ محاولات"),
                              pairing[@"secondsLeft"], pairing[@"attemptsLeft"]];
    }
    self.forgetButton.hidden = !(running && paired);
}

- (void)toggled:(UISwitch *)sender { [self send:sender.on ? @"enable" : @"disable"]; }
- (void)pair { [self send:@"pair-start"]; }

- (void)forget {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:T(@"Forget the pairing?", @"إلغاء الاقتران؟")
                                                                   message:T(@"The Mac will have to be paired again.", @"سيحتاج الماك إلى اقتران جديد.")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:T(@"Cancel", @"إلغاء") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:T(@"Forget", @"إلغاء الاقتران") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) { [self send:@"unpair"]; }]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic) UIWindow *window;
@end

@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[MirrorViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class])); }
}
