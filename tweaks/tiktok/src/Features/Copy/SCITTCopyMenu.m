//
//  SCITTCopyMenu.m
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCITTCopyMenu.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import "../../UI/SCITTToast.h"
#import "../../Localization/SCILocalize.h"

///
/// **A dropdown from the download button, rows that each copy one thing.**
///
/// The first version was a bottom sheet of four rows, one of which glued the account, the caption and the link into a single block. It
/// is replaced by six independent rows, drawn as a small menu that hangs from the button the hold began on (to its left when the button
/// is on the right half of the screen, as TikTok's rail is). Each row shows what it will copy, truncated to a line, so the person checks it
/// by reading rather than by trusting a label.
///
/// Where each value comes from (47.1.0 class metadata, every accessor returns an object):
///
///   video link   AWEAwemeModel -shareURL, else -shareInfo.shareUrl, else built from the account and the post id
///                (`https://www.tiktok.com/@<name>/video/<id>`, the form TikTok itself resolves)
///   caption      AWEAwemeModel -descriptionString
///   sound link   AWEAwemeModel -music -> AWEMusicModel -shareInfo -> AWEShareInfoModel -shareUrl   (no built fallback: a guessed
///                address for a sound would be a guess)
///   username     AWEAwemeModel -author -> AWEUserModel -uniqueIDForShow, copied with its `@`
///   bio          AWEUserModel -signature
///   profile      built from the username: `https://www.tiktok.com/@<name>`
///
/// **Not run on a device.** The report names the source of the last video link, so a wrong one is traceable.
///

static NSUInteger sciCopyAsked = 0, sciCopyOffered = 0, sciCopyEmpty = 0, sciCopyCopied = 0;
static NSString *sciCopyVideoSource = nil, *sciCopyLastRow = nil;

/// An object-returning accessor, asked only when the object has it and declares it as returning an object.
static id SCITTObjectFor(id object, NSString *name) {
    if (!object) return nil;
    SEL selector = NSSelectorFromString(name);
    Method method = class_getInstanceMethod(object_getClass(object), selector);
    const char *types = method ? method_getTypeEncoding(method) : NULL;
    if (!types || types[0] != '@') return nil;
    return ((id (*)(id, SEL))objc_msgSend)(object, selector);
}

static NSString *SCITTTextOf(id value) {
    NSString *text = nil;
    if ([value isKindOfClass:[NSString class]]) text = value;
    else if ([value isKindOfClass:[NSURL class]]) text = [(NSURL *)value absoluteString];
    text = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return text.length ? text : nil;
}

static NSUInteger sciCopyLinksCleaned = 0;

/// TikTok's share address with what the share added taken off: on a TikTok host the path alone names the post or the sound, and
/// everything after the `?` is the sharer's (`_r`, `u_code`, `sharer_language`, `_d`, `share_item_id`, `source`, ...). Copying it
/// would hand that to whoever receives the link. Any other host is left exactly as it came.
static NSString *SCITTCleanedLink(NSString *link) {
    NSURLComponents *parts = [NSURLComponents componentsWithString:link];
    NSString *host = parts.host.lowercaseString;
    if (!host.length || !([host isEqualToString:@"tiktok.com"] || [host hasSuffix:@".tiktok.com"])) return link;
    if (!parts.query.length && !parts.fragment.length) return link;
    parts.query = nil;
    parts.fragment = nil;
    NSString *clean = parts.string;
    if (!clean.length) return link;
    sciCopyLinksCleaned++;
    return clean;
}

/// A web address, or nil. A link row must copy a link and nothing that merely sits in a "URL" field.
static NSString *SCITTLinkOf(id value) {
    NSString *text = SCITTTextOf(value);
    NSString *lower = text.lowercaseString;
    return ([lower hasPrefix:@"https://"] || [lower hasPrefix:@"http://"]) ? SCITTCleanedLink(text) : nil;
}

#pragma mark - The rows

@interface SCITTCopyRow : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *symbol;
@property (nonatomic, copy) NSString *text;     // exactly what is copied, and exactly what is shown beneath the title
@property (nonatomic, assign) BOOL link;        // shown truncated in the middle
@property (nonatomic, assign) BOOL groupStart;  // a separator above
@end
@implementation SCITTCopyRow
@end

static SCITTCopyRow *SCITTMakeRow(NSString *titleKey, NSString *symbol, NSString *text, BOOL link) {
    if (!text.length) return nil;
    SCITTCopyRow *row = [[SCITTCopyRow alloc] init];
    row.title = SCILocalized(titleKey);
    row.symbol = symbol;
    row.text = text;
    row.link = link;
    return row;
}

static NSArray<SCITTCopyRow *> *SCITTRowsForModel(id model) {
    id user = SCITTObjectFor(model, @"author") ?: SCITTObjectFor(model, @"getAuthorModel");
    NSString *name = SCITTTextOf(SCITTObjectFor(user, @"uniqueIDForShow"));
    NSString *handle = name ? [name hasPrefix:@"@"] ? name : [@"@" stringByAppendingString:name] : nil;
    NSString *bare = [handle substringFromIndex:MIN((NSUInteger)1, handle.length)];

    // The video's link: TikTok's own share address first, the built one only when TikTok gave none.
    NSString *video = SCITTLinkOf(SCITTObjectFor(model, @"shareURL"));
    sciCopyVideoSource = video ? @"shareURL" : nil;
    if (!video) {
        video = SCITTLinkOf(SCITTObjectFor(SCITTObjectFor(model, @"shareInfo"), @"shareUrl"));
        if (video) sciCopyVideoSource = @"shareInfo.shareUrl";
    }
    if (!video) {
        NSString *itemID = SCITTTextOf(SCITTObjectFor(model, @"itemID"));
        if (bare.length && itemID.length) {
            video = [NSString stringWithFormat:@"https://www.tiktok.com/@%@/video/%@", bare, itemID];
            sciCopyVideoSource = @"built from the account and the post id";
        }
    }
    if (!video) sciCopyVideoSource = @"none";

    id music = SCITTObjectFor(model, @"music") ?: SCITTObjectFor(model, @"getMusicModel");
    NSString *sound = SCITTLinkOf(SCITTObjectFor(SCITTObjectFor(music, @"shareInfo"), @"shareUrl"));

    NSString *caption = SCITTTextOf(SCITTObjectFor(model, @"descriptionString"));
    NSString *bio = SCITTTextOf(SCITTObjectFor(user, @"signature"));
    NSString *profile = bare.length ? [@"https://www.tiktok.com/@" stringByAppendingString:bare] : nil;

    NSMutableArray<SCITTCopyRow *> *rows = [NSMutableArray array];
    void (^add)(SCITTCopyRow *, BOOL) = ^(SCITTCopyRow *row, BOOL groupStart) {
        if (!row) return;
        row.groupStart = groupStart && rows.count > 0;
        [rows addObject:row];
    };

    add(SCITTMakeRow(@"copy_video_link", @"link", video, YES), NO);
    add(SCITTMakeRow(@"copy_caption", @"text.quote", caption, NO), NO);
    add(SCITTMakeRow(@"copy_sound_link", @"music.note", sound, YES), YES);
    add(SCITTMakeRow(@"copy_username", @"at", handle, NO), YES);
    add(SCITTMakeRow(@"copy_bio", @"text.alignleft", bio, NO), NO);
    add(SCITTMakeRow(@"copy_profile_link", @"person.crop.circle", profile, YES), NO);
    return rows;
}

#pragma mark - The dropdown

@class SCITTCopyDropdown;
static __weak SCITTCopyDropdown *sciCopyShowing = nil;

@interface SCITTCopyRowControl : UIControl
@property (nonatomic, strong) SCITTCopyRow *row;
@end
@implementation SCITTCopyRowControl
- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.backgroundColor = highlighted ? [UIColor colorWithWhite:1 alpha:0.14] : [UIColor clearColor];
}
@end

@interface SCITTCopyDropdown : UIControl
- (instancetype)initWithRows:(NSArray<SCITTCopyRow *> *)rows anchor:(CGRect)anchor inWindow:(UIWindow *)window;
- (void)dismiss;
@end

@implementation SCITTCopyDropdown {
    UIVisualEffectView *_panel;
    CGPoint _anchorPoint;
}

- (instancetype)initWithRows:(NSArray<SCITTCopyRow *> *)rows anchor:(CGRect)anchor inWindow:(UIWindow *)window {
    if (!(self = [super initWithFrame:window.bounds])) return nil;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.18];
    [self addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchDown];

    UIEdgeInsets safe = window.safeAreaInsets;
    CGFloat width = MIN(280, window.bounds.size.width - 32);
    const CGFloat rowHeight = 56;

    UIVisualEffectView *panel = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialDark]];
    panel.layer.cornerRadius = 18;
    panel.layer.cornerCurve = kCACornerCurveContinuous;
    panel.clipsToBounds = YES;
    panel.layer.borderWidth = 0.5;
    panel.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.22].CGColor;
    _panel = panel;

    CGFloat y = 0;
    for (SCITTCopyRow *row in rows) {
        if (row.groupStart) {
            UIView *separator = [[UIView alloc] initWithFrame:CGRectMake(0, y, width, 6)];
            separator.backgroundColor = [UIColor colorWithWhite:0 alpha:0.28];
            [panel.contentView addSubview:separator];
            y += 6;
        }

        SCITTCopyRowControl *control = [[SCITTCopyRowControl alloc] initWithFrame:CGRectMake(0, y, width, rowHeight)];
        control.row = row;
        [control addTarget:self action:@selector(chosen:) forControlEvents:UIControlEventTouchUpInside];

        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
        UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:row.symbol withConfiguration:config]];
        icon.tintColor = [UIColor whiteColor];
        icon.contentMode = UIViewContentModeCenter;
        icon.translatesAutoresizingMaskIntoConstraints = NO;

        UILabel *title = [[UILabel alloc] init];
        title.text = row.title;
        title.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        title.textColor = [UIColor whiteColor];

        UILabel *preview = [[UILabel alloc] init];
        preview.text = [row.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
        preview.font = [UIFont systemFontOfSize:12];
        preview.textColor = [UIColor colorWithWhite:1 alpha:0.6];
        preview.lineBreakMode = row.link ? NSLineBreakByTruncatingMiddle : NSLineBreakByTruncatingTail;

        UIStackView *text = [[UIStackView alloc] initWithArrangedSubviews:@[title, preview]];
        text.axis = UILayoutConstraintAxisVertical;
        text.spacing = 2;
        text.userInteractionEnabled = NO;
        text.translatesAutoresizingMaskIntoConstraints = NO;

        icon.userInteractionEnabled = NO;
        [control addSubview:icon];
        [control addSubview:text];
        [NSLayoutConstraint activateConstraints:@[
            [icon.leadingAnchor constraintEqualToAnchor:control.leadingAnchor constant:14],
            [icon.centerYAnchor constraintEqualToAnchor:control.centerYAnchor],
            [icon.widthAnchor constraintEqualToConstant:24],
            [text.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:10],
            [text.trailingAnchor constraintEqualToAnchor:control.trailingAnchor constant:-14],
            [text.centerYAnchor constraintEqualToAnchor:control.centerYAnchor],
        ]];
        [panel.contentView addSubview:control];
        y += rowHeight;
    }

    // To the left of the button when it is on the right half of the screen (TikTok's rail), to the right otherwise; centred on the button
    // and clamped inside the safe area so it never runs under the status bar or the home indicator.
    CGFloat height = y;
    BOOL buttonOnRight = CGRectGetMidX(anchor) > window.bounds.size.width / 2;
    CGFloat x = buttonOnRight ? CGRectGetMinX(anchor) - 10 - width : CGRectGetMaxX(anchor) + 10;
    x = MAX(12, MIN(x, window.bounds.size.width - width - 12));
    CGFloat top = safe.top + 8, bottom = window.bounds.size.height - safe.bottom - 8;
    CGFloat originY = MAX(top, MIN(CGRectGetMidY(anchor) - height / 2, bottom - height));
    panel.frame = CGRectMake(x, originY, width, height);
    [self addSubview:panel];

    // Grows out of the button: the anchor point is the edge of the menu nearest to it.
    CGPoint towards = CGPointMake(buttonOnRight ? 1 : 0, MAX(0, MIN(1, (CGRectGetMidY(anchor) - originY) / height)));
    CGRect frame = panel.frame;
    panel.layer.anchorPoint = towards;
    panel.frame = frame;
    _anchorPoint = towards;
    return self;
}

- (void)present {
    _panel.transform = CGAffineTransformMakeScale(0.82, 0.82);
    _panel.alpha = 0;
    self.alpha = 0;
    [UIView animateWithDuration:0.26 delay:0 usingSpringWithDamping:0.78 initialSpringVelocity:0.4 options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self->_panel.transform = CGAffineTransformIdentity;
        self->_panel.alpha = 1;
        self.alpha = 1;
    } completion:nil];
}

- (void)dismiss {
    if (sciCopyShowing == self) sciCopyShowing = nil;
    [UIView animateWithDuration:0.16 animations:^{
        self->_panel.transform = CGAffineTransformMakeScale(0.9, 0.9);
        self.alpha = 0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

- (void)chosen:(SCITTCopyRowControl *)control {
    [UIPasteboard generalPasteboard].string = control.row.text;
    sciCopyCopied++;
    sciCopyLastRow = control.row.title;
    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [haptic impactOccurred];
    [self dismiss];
    [SCITTToast noticeWithText:SCILocalized(@"copy_done") symbol:@"doc.on.doc.fill"];
}

@end

void SCITTShowCopyMenu(id awemeModel, UIView *anchor) {
    sciCopyAsked++;
    UIWindow *window = anchor.window;
    if (!awemeModel || !window) {
        sciCopyEmpty++;
        return;
    }
    if (sciCopyShowing) return;   // already open: the same hold, seen twice

    NSArray<SCITTCopyRow *> *rows = SCITTRowsForModel(awemeModel);
    if (!rows.count) {
        sciCopyEmpty++;
        [SCITTToast noticeWithText:SCILocalized(@"copy_nothing") symbol:@"questionmark.circle"];
        return;
    }

    CGRect anchorFrame = [anchor.superview convertRect:anchor.frame toView:window];
    SCITTCopyDropdown *menu = [[SCITTCopyDropdown alloc] initWithRows:rows anchor:anchorFrame inWindow:window];
    if (!menu) return;
    sciCopyOffered++;
    sciCopyShowing = menu;
    [window addSubview:menu];
    [menu present];
}

BOOL SCITTCopyMenuIsOpen(void) {
    return sciCopyShowing != nil;
}

NSString *SCITTCopyReport(void) {
    return [NSString stringWithFormat:@"menus asked %lu, offered %lu, nothing to offer %lu, rows copied %lu (last: %@); video link source: %@; "
            @"links with the share's tracking removed: %lu",
            (unsigned long)sciCopyAsked, (unsigned long)sciCopyOffered, (unsigned long)sciCopyEmpty, (unsigned long)sciCopyCopied,
            sciCopyLastRow ?: @"—", sciCopyVideoSource ?: @"—", (unsigned long)sciCopyLinksCleaned];
}
