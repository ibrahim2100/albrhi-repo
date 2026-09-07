#import "SCILicenseUI.h"
#import "SCILicense.h"
#import "SCIPanelGate.h"

///
/// The screen itself.
///
/// A plain `UIViewController` with a stack view in a scroll view, because that is the one shape
/// that works in every app this ships into: a `UITableViewController` brings its own scrolling
/// and its own idea of what a cell is, and four host apps have four different ideas about both.
///
/// **The scroll view's content is pinned to it *and* given a width**, which is the mistake the
/// panel's plans card made and reported as "a small empty box": pinning content to a scroll view
/// sets `contentSize`, and without the width constraint the content is free to be zero wide.
///
@interface SCILicenseUIController : UIViewController
@property (nonatomic, strong) UIView *badge;          ///< the mark that answers "is it on"
@property (nonatomic, strong) UILabel *badgeGlyph;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *termLabel;     ///< when it ends, in words
@property (nonatomic, strong) UILabel *deviceLabel;
@property (nonatomic, strong) UITextField *entry;
@property (nonatomic, strong) UIButton *applyButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation SCILicenseUIController

/// Localised without a table.
///
/// This file is compiled into four tweaks that each carry their own `SCILocalize.m`, and importing
/// one of them here would mean this shared file reading whichever table happened to resolve first
/// — the exact ambiguity `SCILocalizeAPI.h` was written to end for the preference-bundle kit. Two
/// languages, inline, is the smaller price: there are fourteen strings and they are all about one
/// subject.
static BOOL SCIArabic(void) {
    NSString *language = [[NSLocale preferredLanguages] firstObject] ?: @"en";
    return [language hasPrefix:@"ar"];
}

static NSString *SCIText(NSString *english, NSString *arabic) {
    return SCIArabic() ? arabic : english;
}

/// A date in the language this screen is speaking.
///
/// **`NSDateFormatter` follows the system locale and this screen follows `preferredLanguages`**,
/// which are not the same setting — so an English sentence took an Arabic month name and read
/// «Until 16 9 — 2026 سبتمبر days left». One of the two has to give, and it is the formatter:
/// the sentence around it is already chosen.
static NSString *SCIDate(NSTimeInterval when) {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:SCIArabic() ? @"ar" : @"en_GB"];
    formatter.dateStyle = NSDateFormatterLongStyle;
    formatter.timeStyle = NSDateFormatterNoStyle;
    return [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:when]];
}

/// Wraps a run so bidi cannot rearrange it against the sentence holding it — the same fix, and the
/// same reason, as the licence app's own `SCIRun`: a date's digits and the words either side of
/// them are one left-to-right run as far as the algorithm is concerned.
static NSString *SCIRunText(NSString *text) {
    return text.length ? [NSString stringWithFormat:@"\u2068%@\u2069", text] : @"";
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // **Grouped, not plain** — `secondarySystemGroupedBackground` (what the cards are drawn in) is
    // white in light mode, and so is `systemBackground`. Built on the plain colour the cards were
    // perfectly present and completely invisible, which is what the simulator showed in one look.
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.title = SCIText(@"Licence", @"الترخيص");

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:self
                                                      action:@selector(close)];

    UIScrollView *scroller = [[UIScrollView alloc] init];
    scroller.translatesAutoresizingMaskIntoConstraints = NO;
    scroller.alwaysBounceVertical = YES;
    [self.view addSubview:scroller];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14;
    [scroller addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [scroller.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scroller.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroller.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroller.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [stack.topAnchor constraintEqualToAnchor:scroller.topAnchor constant:20],
        [stack.bottomAnchor constraintEqualToAnchor:scroller.bottomAnchor constant:-20],
        [stack.leadingAnchor constraintEqualToAnchor:scroller.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:scroller.trailingAnchor constant:-20],

        // The width, without which the content is free to be zero wide and the screen reads as
        // empty. `contentSize` is what pinning to the edges above sets; it is not a size.
        [stack.widthAnchor constraintEqualToAnchor:scroller.widthAnchor constant:-40],
    ]];

    self.statusLabel = [self label:@"" bold:YES];
    self.termLabel = [self note:@""];
    self.deviceLabel = [self label:@"" bold:NO];
    self.deviceLabel.font = [UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightRegular];

    // **The answer before the reading.** "Is this on?" is the question every visit to this screen
    // starts with, and a sentence in body text is a slower way to answer it than a coloured mark
    // — which is also the half somebody can read across a room while somebody else holds the
    // phone. The words stay underneath it, because a colour alone says "something" and never
    // "expired on the fourth".
    [stack addArrangedSubview:[self header]];
    [stack addArrangedSubview:[self card:@[self.statusLabel, self.termLabel]]];

    // **A store copy says so, at the top, before anything about keys.**
    //
    // Somebody who bought this in a shop did not buy a licence to a device and should not be
    // asked to think about one. The screen names the shop, gives the one code, and says when the
    // copy stops -- which is the only part of it that will ever surprise anybody.
    if (SCILicenseStoreID().length) {
        NSString *until = SCIRunText(SCIDate(SCILicenseStoreExpiry()));

        [stack addArrangedSubview:[self heading:SCIText(@"This copy", @"هذه النسخة")]];

        UILabel *store = [self label:[NSString stringWithFormat:
            SCIText(@"A copy for %@ — %@", @"نسخة خاصة بـ%@ — %@"),
            SCILicenseStoreName() ?: SCILicenseStoreID(),
            SCILicenseStoreSite() ?: @""] bold:NO];
        store.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        [stack addArrangedSubview:store];

        [stack addArrangedSubview:[self note:[NSString stringWithFormat:
            SCIText(@"One code for every device: type %@ below. This copy works until %@, after "
                    @"which the store has a new one.",
                    @"كودٌ واحد لكل الأجهزة: اكتب %@ في الأسفل. هذه النسخة تعمل حتى %@، وبعدها "
                    @"يوفّر المتجر نسخةً جديدة."),
            SCILicenseStoreID().uppercaseString, until]]];
    }

    // **Said only where it is true.** On a jailbreak with the panel installed, one activation
    // there licenses every tweak on the phone -- entering a key here writes to the same place, so
    // both routes work, but pointing at the one screen that covers everything is the better
    // answer. On a sideloaded install there is no panel and this screen is the only route.
    if (SCIPanelIsInstalled()) {
        [stack addArrangedSubview:[self note:SCIText(
            @"Albrhi Panel is installed on this device: activating there licenses every Albrhi tweak at once, and a key entered here does the same thing.",
            @"بانل البرهي مثبَّت على هذا الجهاز: التفعيل منه يرخّص كل أدوات البرهي دفعةً واحدة، ومفتاحٌ يُدخَل هنا يفعل الشيء نفسه.")]];
    }

    [stack addArrangedSubview:[self heading:SCIText(@"This device", @"هذا الجهاز")]];
    [stack addArrangedSubview:[self card:@[
        self.deviceLabel,
        [self button:SCIText(@"Copy device code", @"نسخ رمز الجهاز")
              action:@selector(copyDevice) primary:NO],
        [self note:SCIText(
            @"Send this to get a key. It is a one-way value provisioned on this device — it is not a serial number and cannot be turned back into one.",
            @"أرسله للحصول على مفتاح. قيمة تُنشأ على هذا الجهاز باتجاهٍ واحد — ليست رقماً تسلسلياً ولا يمكن إرجاعها إليه.")],
    ]]];

    [stack addArrangedSubview:[self heading:SCIText(@"Enter a licence", @"إدخال ترخيص")]];

    self.entry = [[UITextField alloc] init];
    self.entry.borderStyle = UITextBorderStyleRoundedRect;
    self.entry.autocorrectionType = UITextAutocorrectionTypeNo;
    self.entry.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.entry.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.entry.placeholder = SCIText(@"ALB1.… or ALB-XXXX-XXXX-XXXX",
                                     @"ALB1.… أو ALB-XXXX-XXXX-XXXX");
    [self.entry.heightAnchor constraintEqualToConstant:44].active = YES;
    [stack addArrangedSubview:self.entry];

    self.applyButton = [self button:SCIText(@"Activate", @"تفعيل")
                             action:@selector(apply) primary:YES];

    self.spinner = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.hidesWhenStopped = YES;
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [self.applyButton addSubview:self.spinner];
    [NSLayoutConstraint activateConstraints:@[
        [self.spinner.trailingAnchor constraintEqualToAnchor:self.applyButton.trailingAnchor],
        [self.spinner.centerYAnchor constraintEqualToAnchor:self.applyButton.centerYAnchor],
    ]];

    [stack addArrangedSubview:self.applyButton];
    [stack addArrangedSubview:[self note:SCIText(
        @"Paste whatever you were sent — a short code or a long key. Albrhi works out which, checks it on the spot, and turns itself on.",
        @"الصق ما وصلك — كوداً قصيراً أو مفتاحاً طويلاً. البرهي يعرف أيّهما، ويتحقّق منه في حينه، ويشتغل.")]];

    [stack addArrangedSubview:[self heading:SCIText(@"Other", @"أخرى")]];
    [stack addArrangedSubview:[self card:@[
        [self button:SCIText(@"Ask the server now", @"اسأل الخادم الآن")
              action:@selector(sync) primary:NO],
        [self button:SCIText(@"Remove the key", @"إزالة المفتاح")
              action:@selector(remove) primary:NO],
    ]]];

    [self refresh];
}

#pragma mark - Small pieces

/// The identity, and the one mark that answers the question.
- (UIView *)header {
    UIView *row = [[UIView alloc] init];

    self.badge = [[UIView alloc] init];
    self.badge.translatesAutoresizingMaskIntoConstraints = NO;
    self.badge.layer.cornerRadius = 27;
    [row addSubview:self.badge];

    self.badgeGlyph = [[UILabel alloc] init];
    self.badgeGlyph.translatesAutoresizingMaskIntoConstraints = NO;
    self.badgeGlyph.textAlignment = NSTextAlignmentCenter;
    self.badgeGlyph.font = [UIFont systemFontOfSize:30 weight:UIFontWeightBold];
    self.badgeGlyph.textColor = [UIColor whiteColor];
    [self.badge addSubview:self.badgeGlyph];

    UILabel *name = [[UILabel alloc] init];
    name.translatesAutoresizingMaskIntoConstraints = NO;
    name.text = SCIText(@"Albrhi", @"البرهي");
    name.font = [UIFont systemFontOfSize:26 weight:UIFontWeightBold];

    UILabel *what = [[UILabel alloc] init];
    what.translatesAutoresizingMaskIntoConstraints = NO;
    what.text = SCIText(@"Licence", @"الترخيص");
    what.font = [UIFont systemFontOfSize:15];
    what.textColor = [UIColor secondaryLabelColor];

    [row addSubview:name];
    [row addSubview:what];

    [NSLayoutConstraint activateConstraints:@[
        [self.badge.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [self.badge.topAnchor constraintEqualToAnchor:row.topAnchor],
        [self.badge.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
        [self.badge.widthAnchor constraintEqualToConstant:54],
        [self.badge.heightAnchor constraintEqualToConstant:54],

        [self.badgeGlyph.centerXAnchor constraintEqualToAnchor:self.badge.centerXAnchor],
        [self.badgeGlyph.centerYAnchor constraintEqualToAnchor:self.badge.centerYAnchor],

        [name.leadingAnchor constraintEqualToAnchor:self.badge.trailingAnchor constant:14],
        [name.topAnchor constraintEqualToAnchor:self.badge.topAnchor constant:4],
        [name.trailingAnchor constraintLessThanOrEqualToAnchor:row.trailingAnchor],

        [what.leadingAnchor constraintEqualToAnchor:name.leadingAnchor],
        [what.topAnchor constraintEqualToAnchor:name.bottomAnchor constant:2],
    ]];

    return row;
}

/// A grouped card, the shape iOS uses for a set of related rows. Everything on this screen that
/// belongs together is inside one, so the eye has three things to read rather than fifteen.
- (UIView *)card:(NSArray<UIView *> *)rows {
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    card.layer.cornerRadius = 14;

    UIStackView *inner = [[UIStackView alloc] initWithArrangedSubviews:rows];
    inner.translatesAutoresizingMaskIntoConstraints = NO;
    inner.axis = UILayoutConstraintAxisVertical;
    inner.spacing = 10;
    [card addSubview:inner];

    [NSLayoutConstraint activateConstraints:@[
        [inner.topAnchor constraintEqualToAnchor:card.topAnchor constant:14],
        [inner.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14],
        [inner.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14],
        [inner.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14],
    ]];

    return card;
}

/// The licence's own end date, in words rather than a number.
///
/// **Three different facts share one field** and only one of them is a date: `until` of zero is a
/// lifetime licence, a date in the past is a licence that ended, and no licence at all is neither.
/// The panel already paid for reading those as one thing — "0 valid of 3" on a screen holding two
/// lifetime licences — so they are asked apart here.
- (NSString *)termSentence {
    if (SCILicenseCurrentState() != SCILicenseStateValid && !SCILicenseStoreActive()) {
        return SCIText(@"No licence on this device yet.", @"لا ترخيص على هذا الجهاز بعد.");
    }

    if (SCILicenseIsLifetime()) return SCIText(@"Lifetime — it does not end.", @"مدى الحياة — لا تنتهي.");

    NSTimeInterval ends = SCILicenseStoreActive() ? SCILicenseStoreExpiry() : SCILicenseTermEnds();
    if (ends <= 0) return @"";

    NSString *date = SCIRunText(SCIDate(ends));

    double left = ends - [NSDate date].timeIntervalSince1970;
    if (left <= 0) {
        return [NSString stringWithFormat:SCIText(@"Ended on %@", @"انتهت في %@"), date];
    }

    // The number of days beside the date, because "the fourth of October" answers a different
    // question from "eight days" and somebody deciding whether to renew wants the second.
    NSInteger days = (NSInteger)ceil(left / 86400.0);
    if (days == 1) {
        return [NSString stringWithFormat:SCIText(@"Until %@ — one day left", @"حتى %@ — يوم واحد"),
                date];
    }

    // The count through the same locale as the date beside it. Left as `%ld` it came out «١٦
    // سبتمبر ٢٠٢٦ — 9 يوماً»: two numbering systems in one line, which reads as a half-translated
    // screen and is the sort of detail that decides whether something looks finished.
    NSNumberFormatter *counter = [[NSNumberFormatter alloc] init];
    counter.locale = [NSLocale localeWithLocaleIdentifier:SCIArabic() ? @"ar" : @"en_GB"];

    return [NSString stringWithFormat:SCIText(@"Until %@ — %@ days left", @"حتى %@ — %@ يوماً"),
            date, SCIRunText([counter stringFromNumber:@(days)])];
}

- (UILabel *)label:(NSString *)text bold:(BOOL)bold {
    UILabel *label = [[UILabel alloc] init];
    label.numberOfLines = 0;
    label.text = text;
    label.font = bold ? [UIFont boldSystemFontOfSize:17] : [UIFont systemFontOfSize:15];
    return label;
}

- (UILabel *)heading:(NSString *)text {
    UILabel *label = [self label:[text uppercaseString] bold:NO];
    label.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    label.textColor = [UIColor secondaryLabelColor];
    return label;
}

- (UILabel *)note:(NSString *)text {
    UILabel *label = [self label:text bold:NO];
    label.font = [UIFont systemFontOfSize:13];
    label.textColor = [UIColor secondaryLabelColor];
    return label;
}

- (UIButton *)button:(NSString *)title action:(SEL)action primary:(BOOL)primary {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:17 weight:primary ? UIFontWeightSemibold
                                                                        : UIFontWeightRegular];
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintEqualToConstant:34].active = YES;
    return button;
}

- (void)say:(NSString *)message {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:nil
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:SCIText(@"OK", @"حسنًا")
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - State

/// What happens the moment a licence is accepted, wherever it came from.
///
/// **The gate is asked once and remembered** — right on a jailbreak, where the switch and the
/// licence are set in the panel before the app is opened, and wrong here: a standalone app is
/// opened *first*, unlicensed, so the answer it froze was "no". Dropping it is what makes this
/// tweak's own switches start deciding something.
///
/// The hooks a `%ctor` did not install cannot appear retroactively, so this says to reopen the app
/// rather than pretending everything is live: a screen that says "activated" while half the
/// features are missing tells the same lie as a switch that decides nothing.
- (void)accepted {
    SCIPanelGateInvalidate();
    [self refresh];

    // **The relaunch sentence is said only to those who need it.** A process that was allowed when
    // it started has its hooks in place and comes to life on the invalidate above; one that was
    // refused installed nothing at `%ctor`, and no licence can put a hook in retroactively. Saying
    // it to everybody is a small untruth that teaches people to ignore the true version.
    if (SCIPanelGateWasAllowedAtLaunch()) {
        [self say:SCIText(@"Activated. Everything is on.", @"فُعِّلت. كل شيء يعمل الآن.")];
        return;
    }

    [self say:SCIText(@"Activated. Close the app fully and open it again so every part of the "
                      @"tweak starts.",
                      @"فُعِّلت. أغلق التطبيق تماماً وافتحه من جديد ليبدأ كل جزء من الأداة.")];
}

/// The button says what it is doing, because a network call with no sign of life is a button that
/// did nothing as far as anybody watching can tell — the same complaint TikTok's silent save
/// earned before it grew an indicator.
- (void)working:(BOOL)busy {
    self.applyButton.enabled = !busy;
    self.applyButton.alpha = busy ? 0.5 : 1.0;
    busy ? [self.spinner startAnimating] : [self.spinner stopAnimating];
}

- (void)refresh {
    self.statusLabel.text = SCILicenseStatusLine();

    // Live means: a valid key, or a store copy the server has accepted. Both are "it works", and
    // the mark is about that and nothing finer.
    BOOL live = SCILicenseStoreID().length ? SCILicenseStoreActive()
                                           : (SCILicenseCurrentState() == SCILicenseStateValid);

    self.badge.backgroundColor = live ? [UIColor systemGreenColor] : [UIColor systemRedColor];
    self.badgeGlyph.text = live ? @"✓" : @"!";
    self.termLabel.text = [self termSentence];

    // A store copy is licensed or it is not, and the ordinary status line -- written for keys,
    // servers and grace periods -- describes none of that.
    if (SCILicenseStoreID().length) {
        self.statusLabel.text = SCILicenseStoreActive()
            ? SCIText(@"Active", @"مفعَّلة")
            : SCIText(@"Not activated — enter the code below", @"غير مفعَّلة — اكتب الكود في الأسفل");
    }

    NSString *device = SCILicenseFingerprint();
    self.deviceLabel.text = device.length ? device : SCIText(@"not created yet", @"لم يُنشأ بعد");

    // What the licence covers, said only when it is narrower than everything: "this key is for
    // YouTube" is worth knowing, and "this key is for everything" is noise on a screen inside one
    // app.
    NSString *scope = SCILicenseScope();
    if ([scope hasPrefix:@"app:"]) {
        self.statusLabel.text = [NSString stringWithFormat:@"%@ · %@",
            self.statusLabel.text,
            [NSString stringWithFormat:SCIText(@"for %@ only", @"لـ%@ وحدها"),
                SCIRunText([scope substringFromIndex:4])]];
    }
}

#pragma mark - Actions

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)copyDevice {
    NSString *device = SCILicenseFingerprint();
    if (!device.length || SCILicenseFingerprintIsWeak()) {
        [self say:SCIText(@"This device has no id yet. Leave this screen and open it again, then try.",
                          @"لا يوجد رمز لهذا الجهاز بعد. أغلق هذه الشاشة وافتحها ثانيةً ثم أعد المحاولة.")];
        return;
    }

    [UIPasteboard generalPasteboard].string = device;
    [self say:SCIText(@"Copied.", @"نُسخ.")];
}

/// One row for two instruments, deciding by shape.
///
/// Which of the two somebody holds is a fact about how their licence was issued, not something
/// they should have to classify — the panel learned that when «enter a key» and «enter a code»
/// sat side by side and were reported as the same button twice.
- (void)apply {
    NSString *text = [self.entry.text stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!text.length) { [self working:NO]; return; }

    [self.view endEditing:YES];
    [self working:YES];

    // The store's own code, tried first and only where such a build exists. It is not a key and
    // not a short code: it goes to neither the verifier nor the server.
    if (SCILicenseStoreAccepts(text)) {
        SCILicenseActivateStore(text, ^(SCILicenseServerResult result) {
            [self working:NO];
            [self refresh];

            switch (result) {
                case SCILicenseServerOK:
                    self.entry.text = @"";
                    [self accepted];
                    break;

                // A shop's window can be extended or withdrawn from the panel now, so these are
                // real answers rather than "wrong code" -- and each needs the person to do
                // something different about it.
                case SCILicenseServerExpired:
                    [self say:SCIText(@"This copy's period has ended. The store has a new one.",
                                      @"انتهت مدّة هذه النسخة. المتجر لديه نسخة جديدة.")];
                    break;
                case SCILicenseServerRevoked:
                    [self say:SCIText(@"This copy has been withdrawn by the store.",
                                      @"سُحبت هذه النسخة من قِبل المتجر.")];
                    break;
                case SCILicenseServerUnreachable:
                case SCILicenseServerNotConfigured:
                    [self say:SCIText(@"The server could not be reached. Try again on a connection.",
                                      @"تعذّر الوصول إلى الخادم. أعد المحاولة على اتصال.")];
                    break;
                default:
                    [self say:SCIText(@"That code was not accepted.", @"لم يُقبل هذا الكود.")];
                    break;
            }
        });
        return;
    }

    if ([text hasPrefix:@"ALB1."]) {
        // An offline key needs no network at all: it is verified against the public half compiled
        // into this binary, so the answer is immediate and the spinner would be a flicker.
        [self working:NO];

        SCILicenseState state = SCILicenseStateNone;
        if (SCILicenseStoreKey(text, &state)) {
            self.entry.text = @"";
            [self accepted];
        } else {
            [self say:SCILicenseDescribeState(state)];
        }
        return;
    }

    // Anything else goes down the path that can ask the server, so an unrecognised string still
    // gets a real answer rather than "that is not a key".
    SCILicenseRedeemCode(text, ^(SCILicenseRedeemResult result) {
        [self working:NO];
        [self refresh];

        switch (result) {
            case SCILicenseRedeemedOK:
                self.entry.text = @"";
                [self accepted];
                break;

            // Four refusals and four sentences, because they need four different things done
            // about them and one message covering all of them sends people to ask the wrong
            // question.
            case SCILicenseRedeemMalformed:
                [self say:SCIText(@"That is not a key or a code. Check what you pasted.",
                                  @"هذا ليس مفتاحاً ولا كوداً. تحقّق مما لصقته.")];
                break;
            case SCILicenseRedeemUnknown:
                [self say:SCIText(@"That code is not known. Check it, or ask for a new one.",
                                  @"هذا الكود غير معروف. تحقّق منه أو اطلب واحداً جديداً.")];
                break;
            case SCILicenseRedeemWindowClosed:
                [self say:SCIText(@"That code's redemption window has passed.",
                                  @"انتهت مهلة تفعيل هذا الكود.")];
                break;
            case SCILicenseRedeemTaken:
                [self say:SCIText(@"That code is already in use on another device.",
                                  @"هذا الكود مُستعمل على جهاز آخر.")];
                break;
            case SCILicenseRedeemOffline:
                [self say:SCIText(@"Nothing could be checked — the server was not reachable.",
                                  @"تعذّر التحقّق — لم يُوصل إلى الخادم.")];
                break;
        }
    });
}

- (void)sync {
    SCILicenseSyncWithServer(^(SCILicenseServerResult result) {
        [self refresh];

        // A failure to reach the server is reported as exactly that. It is never a licence
        // problem: a timeout or a captive portal must not read as "you are not licensed".
        if (result == SCILicenseServerOK) {
            [self say:SCIText(@"Up to date.", @"محدَّث.")];
        } else if (result == SCILicenseServerPending) {
            [self say:SCIText(@"Your request is waiting to be answered.",
                              @"طلبك بانتظار الردّ.")];
        } else if (result == SCILicenseServerUnreachable ||
                   result == SCILicenseServerNotConfigured) {
            [self say:SCIText(@"The server could not be reached. Nothing was decided.",
                              @"تعذّر الوصول إلى الخادم. لم يتقرّر شيء.")];
        } else {
            [self say:SCILicenseStatusLine()];
        }
    });
}

- (void)remove {
    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:SCIText(@"Remove the key?", @"إزالة المفتاح؟")
                                            message:SCIText(@"The tweak stops working until another licence is entered.",
                                                            @"تتوقّف الأداة حتى يُدخَل ترخيص آخر.")
                                     preferredStyle:UIAlertControllerStyleAlert];

    [sheet addAction:[UIAlertAction actionWithTitle:SCIText(@"Cancel", @"إلغاء")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [sheet addAction:[UIAlertAction actionWithTitle:SCIText(@"Remove", @"إزالة")
                                              style:UIAlertActionStyleDestructive
                                            handler:^(__unused UIAlertAction *action) {
        SCILicenseForgetKey();
        SCILicenseForgetCode();

        // The gate remembers its answer, so removing a key has to say so too -- otherwise the
        // tweak goes on working for the rest of the session, and "I removed it and it still
        // works" would be a report about this line.
        SCIPanelGateInvalidate();
        [self refresh];
    }]];

    [self presentViewController:sheet animated:YES completion:nil];
}

@end


@implementation SCILicenseUI

+ (void)presentFrom:(UIViewController *)host {
    if (!host) return;

    // Provisioned here as well as in the panel: on a device with no panel this is the first and
    // only moment anything asks for an identity, and a screen that shows "not created yet" and
    // then cannot copy anything is a screen that reads as broken.
    SCILicenseProvisionDevice();

    SCILicenseUIController *screen = [[SCILicenseUIController alloc] init];
    UINavigationController *wrapper =
        [[UINavigationController alloc] initWithRootViewController:screen];
    wrapper.modalPresentationStyle = UIModalPresentationFormSheet;

    // From whatever is actually on top. Presenting from underneath something already presented is
    // the single most common way a sheet silently never appears.
    UIViewController *top = host;
    while (top.presentedViewController) top = top.presentedViewController;

    [top presentViewController:wrapper animated:YES completion:nil];
}

+ (NSString *)summary {
    return SCILicenseStatusLine();
}

@end
