#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <string.h>
#import <math.h>
#import "SCITTSettingsEntry.h"
#import "SCITTStatus.h"
#import "../Prefs.h"
#import "../SCILog.h"
#import "../Localization/SCILocalize.h"

///
/// **Albrhi's settings, as a row on TikTok's own Settings screen.**
///
/// TikTok builds that screen from plugins: one `TTKSettings…CellPlugin` per row, found by an identifier
/// string that a `TTKSettingsSectionRegister` lists under its section, resolved through
/// `AWEPluginManagerCenter` with a protocol name and a scene name. Joining that means registering a
/// plugin class under an identifier with two strings nobody here has seen used, in a screen every user
/// of the app opens; a wrong guess is a Settings screen that comes up empty. So the row is **not** a
/// plugin. It is a view in the screen's own collection view, in the space a top inset makes for it, so
/// it scrolls with the list and TikTok's data model is never touched.
///
/// Asked of the class, not assumed: `TTKSettingsViewController` is installed only if it answers
/// `-viewDidAppear:` with the encoding recorded for 46.4.0 and 47.1.0 and its `-collectionView` is
/// there. The report says which.
///

static const NSInteger kSCIEntryTag = 0x5C57;
static const CGFloat kSCIEntryHeight = 60;
static const CGFloat kSCIEntryGap = 14;
static const CGFloat kSCIEntrySide = 16;

static NSString *sciEntryState = nil;
static NSUInteger sciEntryAttached = 0;
static NSUInteger sciEntryTaps = 0;
static NSUInteger sciEntryInsetRestored = 0;

/// The top inset this code left on the collection view, kept on the view itself so a second
/// appearance of the screen adds nothing and a TikTok rewrite of the inset can be told from our own.
static const void *kSCIEntryExpectedKey = &kSCIEntryExpectedKey;

@interface SCITTEntryRow : UIControl
@end

@implementation SCITTEntryRow

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;

    self.tag = kSCIEntryTag;
    self.layer.cornerRadius = 12;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1 alpha:0.09]
            : [UIColor colorWithWhite:0 alpha:0.05];
    }];

    UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightSemibold];
    UIImageView *glyph = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:@"slider.horizontal.3" withConfiguration:config]];
    glyph.tintColor = [UIColor whiteColor];
    glyph.contentMode = UIViewContentModeCenter;
    glyph.backgroundColor = [UIColor colorWithRed:0.99 green:0.17 blue:0.33 alpha:1];
    glyph.layer.cornerRadius = 8;
    glyph.layer.cornerCurve = kCACornerCurveContinuous;
    glyph.clipsToBounds = YES;
    [glyph.widthAnchor constraintEqualToConstant:34].active = YES;
    [glyph.heightAnchor constraintEqualToConstant:34].active = YES;

    UILabel *title = [[UILabel alloc] init];
    title.text = SCILocalized(@"title");
    title.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    title.textColor = [UIColor labelColor];

    UILabel *note = [[UILabel alloc] init];
    note.text = SCILocalized(@"entry_note");
    note.font = [UIFont systemFontOfSize:12.5];
    note.textColor = [UIColor secondaryLabelColor];

    UIStackView *text = [[UIStackView alloc] initWithArrangedSubviews:@[title, note]];
    text.axis = UILayoutConstraintAxisVertical;
    text.spacing = 2;

    UIImageSymbolConfiguration *small =
        [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightSemibold];
    UIImageView *chevron = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:@"chevron.forward" withConfiguration:small]];
    chevron.tintColor = [UIColor tertiaryLabelColor];
    [chevron setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[glyph, text, chevron]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;
    row.spacing = 12;
    row.userInteractionEnabled = NO;
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:row];
    [NSLayoutConstraint activateConstraints:@[
        [row.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14],
        [row.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-14],
        [row.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
    ]];

    [self addTarget:self action:@selector(opened) forControlEvents:UIControlEventTouchUpInside];
    return self;
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.alpha = highlighted ? 0.6 : 1;
}

- (void)opened {
    sciEntryTaps++;
    [SCITTStatus present];
}

@end


/// Puts the row above the list, once, and keeps it there.
///
/// The room is made with `contentInset.top`. If TikTok rewrites the inset (it may, when the screen is
/// rebuilt after a login), the next appearance finds a number that is not the one left behind and adds
/// the room to TikTok's value, rather than adding the row's height a second time to its own. A scroll position at the very top moves with the new inset so the row is seen
/// on arrival; a list somebody has scrolled is left where it is.
static void SCITTAttachEntry(UIViewController *controller) {
    @try {
        UICollectionView *list = [controller respondsToSelector:@selector(collectionView)]
            ? ((UICollectionView *(*)(id, SEL))objc_msgSend)(controller, @selector(collectionView)) : nil;
        if (![list isKindOfClass:[UICollectionView class]] || list.bounds.size.width < 100) return;

        CGFloat room = kSCIEntryHeight + kSCIEntryGap;

        SCITTEntryRow *row = (SCITTEntryRow *)[list viewWithTag:kSCIEntryTag];
        if (!row) {
            row = [[SCITTEntryRow alloc] initWithFrame:CGRectZero];
            [list addSubview:row];
            sciEntryAttached++;
        }

        // The inset this code left behind, or nothing. Whatever is there now that is not that
        // number is TikTok's own, and the room is added to it -- once.
        NSNumber *expected = objc_getAssociatedObject(list, kSCIEntryExpectedKey);
        UIEdgeInsets inset = list.contentInset;

        if (!expected || fabs(inset.top - expected.doubleValue) > 0.5) {
            BOOL atTop = list.contentOffset.y <= -list.adjustedContentInset.top + 1;
            if (expected) sciEntryInsetRestored++;
            inset.top += room;
            list.contentInset = inset;
            objc_setAssociatedObject(list, kSCIEntryExpectedKey, @(inset.top), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            if (atTop) list.contentOffset = CGPointMake(list.contentOffset.x, -list.adjustedContentInset.top);
        }

        CGRect frame = CGRectMake(kSCIEntrySide, -room, list.bounds.size.width - 2 * kSCIEntrySide, kSCIEntryHeight);
        if (!CGRectEqualToRect(row.frame, frame)) row.frame = frame;
    } @catch (NSException *exception) {
        sciEntryState = [NSString stringWithFormat:@"threw: %@", exception.reason];
    }
}

%group SettingsEntry

%hook TTKSettingsViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!SCIPanelAllowsThisApp()) return;
    SCITTAttachEntry(self);

    // Once more shortly after: the screen fills its list asynchronously and may reset the inset as
    // the first sections arrive. The attach is idempotent, so a second pass costs nothing.
    __weak UIViewController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        UIViewController *strong = weakSelf;
        if (strong.viewIfLoaded.window) SCITTAttachEntry(strong);
    });
}

%end

%end


NSString *SCITTSettingsEntryReport(void) {
    return [NSString stringWithFormat:@"%@; rows made: %lu, inset restored: %lu, opened from it: %lu",
            sciEntryState ?: @"not installed", (unsigned long)sciEntryAttached,
            (unsigned long)sciEntryInsetRestored, (unsigned long)sciEntryTaps];
}

static BOOL sciEntryInstalled = NO;

BOOL SCITTSettingsEntryInstalled(void) { return sciEntryInstalled; }

void SCITTInstallSettingsEntry(void) {
    Class screen = NSClassFromString(@"TTKSettingsViewController");
    Method appear = screen ? class_getInstanceMethod(screen, @selector(viewDidAppear:)) : NULL;
    const char *types = appear ? method_getTypeEncoding(appear) : NULL;
    BOOL hasList = screen && class_getInstanceMethod(screen, @selector(collectionView)) != NULL;

    if (!types || strcmp(types, "v20@0:8B16") != 0 || !hasList) {
        sciEntryState = [NSString stringWithFormat:@"stood down: %@",
            !screen ? @"TTKSettingsViewController absent"
                    : (!types ? @"-viewDidAppear: not declared there"
                              : (!hasList ? @"-collectionView absent" : @"encoding differs"))];
        SCILogV(@"[SettingsEntry] %@", sciEntryState);
        return;
    }

    %init(SettingsEntry);
    sciEntryInstalled = YES;
    sciEntryState = @"installed: TTKSettingsViewController -viewDidAppear:";
    SCILogV(@"[SettingsEntry] %@", sciEntryState);
}
