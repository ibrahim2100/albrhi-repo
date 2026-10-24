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
/// **Albrhi's settings, as a row on TikTok's own Settings screen -- two ways, one chosen at install.**
///
/// *Native (preferred).* TikTok's Settings is an IGListKit-style list: `-[TTKSettingsViewController sectionViewModels]`
/// (declared by `AWEBaseListViewController`) returns the section view models, each wrapping cell plugins whose
/// `itemModel` is an `AWESettingItemModel`. A reference tweak (NA9, read by disassembly, nothing copied) adds a section
/// to that array and catches the tap in `-collectionView:didSelectItemAtIndexPath:` by the item's identifier; the
/// messages it sends are `AWESettingItemModel` `setTitle:` `setIdentifier:` `setType:` `setCellType:` `setIconImage:`,
/// a `TTKSettingsBaseCellPlugin` given the item with `setItemModel:`, and an `AWESettingsNormalSectionViewModel` built
/// with `initWithModelsArray:` and given `setSectionIdentifier:` `setSectionHeaderTitle:` `setSectionHeaderHeight:`.
/// Every one of those exists with the same encoding in 46.4.0 and 47.1.0 (checked against both dumps, and again at
/// install). The row is TikTok's own cell, with its own metrics, dark mode and right-to-left layout.
///
/// *Inset (fallback, only when the native path cannot be installed).* A view in the screen's collection view, in the
/// space a top inset makes for it. It scrolls with the list and touches no TikTok data model.
///
/// The report says which one is in use.
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


static NSString *const kSCIEntryIdentifier = @"albrhi_settings_entry";
static NSString *const kSCIEntrySectionIdentifier = @"albrhi_settings_section";
static const void *kSCIEntrySectionKey = &kSCIEntrySectionKey;
static NSUInteger sciNativeBuilt = 0, sciNativeInserted = 0, sciNativeFailed = 0;
static BOOL sciEntryNative = NO;

static NSString *SCITTSectionIdentifierOf(id section) {
    SEL sel = NSSelectorFromString(@"sectionIdentifier");
    if (![section respondsToSelector:sel]) return nil;
    id value = ((id (*)(id, SEL))objc_msgSend)(section, sel);
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

/// One section of one row, made the way TikTok makes its own. Nothing is retained globally: the section belongs to the
/// controller that asked, and is built again for the next one.
static id SCITTMakeSettingsSection(void) {
    Class itemClass = NSClassFromString(@"AWESettingItemModel");
    Class pluginClass = NSClassFromString(@"TTKSettingsBaseCellPlugin");
    Class sectionClass = NSClassFromString(@"AWESettingsNormalSectionViewModel");
    if (!itemClass || !pluginClass || !sectionClass) return nil;

    id item = [[itemClass alloc] init];
    ((void (*)(id, SEL, id))objc_msgSend)(item, NSSelectorFromString(@"setTitle:"), SCILocalized(@"title"));
    ((void (*)(id, SEL, id))objc_msgSend)(item, NSSelectorFromString(@"setIdentifier:"), kSCIEntryIdentifier);
    ((void (*)(id, SEL, long long))objc_msgSend)(item, NSSelectorFromString(@"setType:"), 1);
    ((void (*)(id, SEL, long long))objc_msgSend)(item, NSSelectorFromString(@"setCellType:"), 4);

    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightMedium];
    UIImage *icon = [[UIImage systemImageNamed:@"slider.horizontal.3" withConfiguration:config]
                     imageWithTintColor:[UIColor labelColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
    if (icon) ((void (*)(id, SEL, id))objc_msgSend)(item, NSSelectorFromString(@"setIconImage:"), icon);

    id plugin = [[pluginClass alloc] init];
    ((void (*)(id, SEL, id))objc_msgSend)(plugin, NSSelectorFromString(@"setItemModel:"), item);

    id section = ((id (*)(id, SEL, id))objc_msgSend)([sectionClass alloc], NSSelectorFromString(@"initWithModelsArray:"), @[plugin]);
    if (!section) return nil;
    ((void (*)(id, SEL, id))objc_msgSend)(section, NSSelectorFromString(@"setSectionIdentifier:"), kSCIEntrySectionIdentifier);
    ((void (*)(id, SEL, id))objc_msgSend)(section, NSSelectorFromString(@"setSectionHeaderTitle:"), SCILocalized(@"entry_header"));
    ((void (*)(id, SEL, double))objc_msgSend)(section, NSSelectorFromString(@"setSectionHeaderHeight:"), 38.0);
    sciNativeBuilt++;
    return section;
}

%group SettingsNative

%hook TTKSettingsViewController

- (NSArray *)sectionViewModels {
    NSArray *original = %orig;
    if (![original isKindOfClass:[NSArray class]] || !original.count || !SCIPanelAllowsThisApp()) return original;

    @try {
        for (id section in original) {
            if ([SCITTSectionIdentifierOf(section) isEqualToString:kSCIEntrySectionIdentifier]) return original;
        }

        id mine = objc_getAssociatedObject(self, kSCIEntrySectionKey);
        if (!mine) {
            mine = SCITTMakeSettingsSection();
            if (!mine) { sciNativeFailed++; return original; }
            objc_setAssociatedObject(self, kSCIEntrySectionKey, mine, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }

        // Below the banner at the top (a sign-in or profile card, which is not a settings group), above the first real
        // group. The banner is recognised by its class name, and if none is recognised the row goes first.
        NSUInteger at = 0;
        while (at < original.count) {
            NSString *name = NSStringFromClass([original[at] class]);
            if (![name containsString:@"HeaderBanner"] && ![name containsString:@"HeaderTitle"]) break;
            at++;
        }

        NSMutableArray *sections = [original mutableCopy];
        [sections insertObject:mine atIndex:MIN(at, sections.count)];
        sciNativeInserted++;
        return [sections copy];
    } @catch (NSException *exception) {
        sciNativeFailed++;
        return original;
    }
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    id item = [cell respondsToSelector:@selector(itemModel)] ? ((id (*)(id, SEL))objc_msgSend)(cell, @selector(itemModel)) : nil;
    id identifier = [item respondsToSelector:@selector(identifier)] ? ((id (*)(id, SEL))objc_msgSend)(item, @selector(identifier)) : nil;
    if ([identifier isKindOfClass:[NSString class]] && [identifier isEqualToString:kSCIEntryIdentifier]) {
        sciEntryTaps++;
        [SCITTStatus present];
        return;
    }
    %orig;
}

%end

%end

NSString *SCITTSettingsEntryReport(void) {
    return [NSString stringWithFormat:@"%@; native sections built: %lu, inserted: %lu, failed: %lu; inset rows made: %lu, inset restored: %lu; opened from the row: %lu",
            sciEntryState ?: @"not installed", (unsigned long)sciNativeBuilt, (unsigned long)sciNativeInserted,
            (unsigned long)sciNativeFailed, (unsigned long)sciEntryAttached,
            (unsigned long)sciEntryInsetRestored, (unsigned long)sciEntryTaps];
}

static BOOL sciEntryInstalled = NO;

BOOL SCITTSettingsEntryInstalled(void) { return sciEntryInstalled; }

static BOOL SCITTEntryHas(Class cls, const char *selector, const char *encoding) {
    Method method = cls ? class_getInstanceMethod(cls, sel_registerName(selector)) : NULL;
    const char *types = method ? method_getTypeEncoding(method) : NULL;
    return types && strcmp(types, encoding) == 0;
}

void SCITTInstallSettingsEntry(void) {
    Class screen = NSClassFromString(@"TTKSettingsViewController");

    // Native first: every class and selector the section is made of, with the encoding it is sent with.
    Class item = NSClassFromString(@"AWESettingItemModel");
    Class plugin = NSClassFromString(@"TTKSettingsBaseCellPlugin");
    Class section = NSClassFromString(@"AWESettingsNormalSectionViewModel");
    Class cell = NSClassFromString(@"TTKSettingsCollectionViewCell");
    BOOL native = SCITTEntryHas(screen, "sectionViewModels", "@16@0:8")
        && SCITTEntryHas(screen, "collectionView:didSelectItemAtIndexPath:", "v32@0:8@16@24")
        && SCITTEntryHas(item, "setTitle:", "v24@0:8@16") && SCITTEntryHas(item, "setIdentifier:", "v24@0:8@16")
        && SCITTEntryHas(item, "setType:", "v24@0:8q16") && SCITTEntryHas(item, "setCellType:", "v24@0:8q16")
        && SCITTEntryHas(item, "setIconImage:", "v24@0:8@16") && SCITTEntryHas(item, "identifier", "@16@0:8")
        && SCITTEntryHas(plugin, "setItemModel:", "v24@0:8@16")
        && SCITTEntryHas(section, "initWithModelsArray:", "@24@0:8@16")
        && SCITTEntryHas(section, "setSectionIdentifier:", "v24@0:8@16")
        && SCITTEntryHas(section, "setSectionHeaderTitle:", "v24@0:8@16")
        && SCITTEntryHas(section, "setSectionHeaderHeight:", "v24@0:8d16")
        && SCITTEntryHas(section, "sectionIdentifier", "@16@0:8")
        && SCITTEntryHas(cell, "itemModel", "@16@0:8");
    if (native) {
        %init(SettingsNative);
        sciEntryInstalled = YES;
        sciEntryNative = YES;
        sciEntryState = @"installed (native section): TTKSettingsViewController -sectionViewModels";
        SCILogV(@"[SettingsEntry] %@", sciEntryState);
        return;
    }

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
    sciEntryState = @"installed (inset row, native path unavailable): TTKSettingsViewController -viewDidAppear:";
    SCILogV(@"[SettingsEntry] %@", sciEntryState);
}
