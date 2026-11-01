#import <substrate.h>
#import "shared/src/SCIKVC.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../../Downloader/SCIMediaDownloader.h"
#import "../../Localization/SCILocalize.h"
#import "../../Settings/SCIDiagnosticsViewController.h"
#import "../../Features/General/SCIDateFormat.h"
#import "../../Compat/SCIResolve.h"

///
/// Inline download button
///
/// Injects a native-looking download glyph into the post action row
/// (like · comment · send · … · save), so media can be saved with a single tap
/// instead of a long press.
///
/// Placement and sizing are derived from the row's own controls at layout time,
/// so the button inherits Instagram's spacing and metrics rather than hard-coding
/// them. Downloading itself is delegated to SCIMediaDownloader, which means the
/// button honours the quality picker and queue exactly as a long press does.
///

static const NSInteger SCIInlineDownloadButtonTag = 0x5CD10;
static const NSInteger SCIReelDateLabelTag = 0x5CDA7;

// Declared ahead of use: the date helpers sit beside the code they belong with
// rather than being ordered by what C needs to see first.
static id SCIMediaForButtonBar(UIView *bar);
static void SCILayoutReelDate(UIView *bar, UIButton *button, CGFloat side);

/// When a reel was posted, written in whichever format the user chose.
///
/// Instagram shows a date on a feed post and none at all on a reel, so there is no
/// way to tell whether the thing on screen went up this morning or three years ago.
/// The media carries the timestamp — -takenAt on both tested builds — it is simply
/// never drawn.
static NSString *SCIReelDateTextForBar(UIView *bar) {
    id media = SCIMediaForButtonBar(bar);
    if (!media) return nil;

    NSDate *date = nil;
    for (NSString *key in @[@"takenAtDate", @"takenAt", @"creationDate"]) {
        id value = nil;
        @try { value = SCISafeValueForKey(media, key); } @catch (__unused id e) {}

        if ([value isKindOfClass:[NSDate class]]) { date = value; break; }

        // -takenAt is a unix timestamp on some builds and an NSDate on others.
        if ([value isKindOfClass:[NSNumber class]] && [value doubleValue] > 1000000000.0) {
            date = [NSDate dateWithTimeIntervalSince1970:[value doubleValue]];
            break;
        }
    }
    if (!date) return nil;

    // The chosen format when the date feature is on, so this matches every other
    // timestamp in the app; a plain short date when it is off, since someone who has
    // not set a format still needs this one to be readable.
    NSString *formatted = [SCIDateFormat enabled] ? [SCIDateFormat stringForDate:date] : nil;
    if (formatted.length) return formatted;

    static NSDateFormatter *fallback = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        fallback = [[NSDateFormatter alloc] init];
        fallback.dateStyle = NSDateFormatterShortStyle;
        fallback.timeStyle = NSDateFormatterNoStyle;
    });
    return [fallback stringFromDate:date];
}

// Does this object actually carry a downloadable payload?
static BOOL SCIHasMediaPayload(id candidate) {
    if (!candidate) return NO;

    for (NSString *key in @[@"video", @"photo"]) {
        @try {
            if (SCISafeValueForKey(candidate, key) != nil) return YES;
        } @catch (__unused id e) {}
    }

    return NO;
}

// Pulls an IGMedia-like object off an arbitrary owner, trying every accessor name
// Instagram uses across its cell, delegate, view-model and section-controller
// layers. The owner itself counts — a cell may *be* the media holder.
static id SCIMediaFromOwner(id owner) {
    if (!owner) return nil;

    if (SCIHasMediaPayload(owner)) return owner;

    static NSArray *keys = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keys = @[@"media", @"post", @"feedItem", @"mediaCellFeedItem", @"currentMediaItem",
                 @"pagePhotoPost", @"item", @"viewModel", @"configuration",
                 @"_media", @"_post", @"_configuration"];
    });

    for (NSString *key in keys) {
        id candidate = nil;
        @try { candidate = SCISafeValueForKey(owner, key); } @catch (__unused id e) {}

        if (SCIHasMediaPayload(candidate)) return candidate;

        // One level deeper: configurations and view models wrap the media.
        if (candidate) {
            for (NSString *inner in @[@"media", @"post", @"feedItem"]) {
                id nested = nil;
                @try { nested = SCISafeValueForKey(candidate, inner); } @catch (__unused id e) {}

                if (SCIHasMediaPayload(nested)) return nested;
            }
        }
    }

    return nil;
}

///
/// The first candidate is not always the right one, and a repost is where that showed.
///
/// Every owner in the chain below can hold *a* media, and `SCIHasMediaPayload` accepts
/// any of them the moment a `photo` is non-nil — which a repost's unfetched stub always
/// has, because Instagram loads the cover first (`-coverPhotoDidPartiallyLoad` is its
/// own declared accessor). So the search stopped at the stub, its video had no
/// renditions, and a video was saved as its cover image.
///
/// Taking the first match is still right for every ordinary post, so the walk is
/// unchanged. What is added is a second pass: if the first match declares itself a
/// video but cannot resolve one, keep looking, and prefer any later candidate that
/// can. Only when nothing better turns up is the first match returned — so this can
/// never do worse than before, it can only find something the old walk skipped past.
///
static void SCIConsiderMedia(id candidate, id *best, id *firstSeen) {
    if (!candidate) return;
    if (!*firstSeen) *firstSeen = candidate;
    if (*best) return;

    IGVideo *video = nil;
    @try { video = SCISafeValueForKey(candidate, @"video"); } @catch (__unused id e) {}

    if ([SCIMediaDownloader hasPlayableVideo:video]) *best = candidate;
}

/// Walks the delegate chain first, then the view hierarchy, looking for the media
/// backing this action row.
static id SCIMediaForButtonBar(UIView *bar) {
    // The best candidate found so far (a resolvable video) and the first one found at
    // all — which is exactly what this function used to return, and still does when
    // nothing better exists.
    id best = nil;
    id firstSeen = nil;

    for (NSString *key in @[@"delegate", @"dataSource"]) {
        id owner = nil;
        @try { owner = SCISafeValueForKey(bar, key); } @catch (__unused id e) {}

        SCIConsiderMedia(SCIMediaFromOwner(owner), &best, &firstSeen);
        if (best) return best;

        // Delegates commonly forward to another object holding the media.
        id nested = nil;
        @try { nested = SCISafeValueForKey(owner, @"delegate"); } @catch (__unused id e) {}

        SCIConsiderMedia(SCIMediaFromOwner(nested), &best, &firstSeen);
        if (best) return best;
    }

    // Then the enclosing cell, which is where the long-press path finds it.
    UIView *ancestor = bar.superview;
    while (ancestor) {
        SCIConsiderMedia(SCIMediaFromOwner(ancestor), &best, &firstSeen);
        if (best) return best;

        // The cell's own view controller can hold it instead.
        id nextResponder = [ancestor nextResponder];
        if ([nextResponder isKindOfClass:[UIViewController class]]) {
            SCIConsiderMedia(SCIMediaFromOwner(nextResponder), &best, &firstSeen);
            if (best) return best;
        }

        ancestor = ancestor.superview;
    }

    // Nothing in the chain could resolve a video. The first match is what the old walk
    // would have returned, and the downloader now refuses to call a declared video a
    // photo, so this reports honestly instead of saving the wrong file.
    if (firstSeen) return firstSeen;

    return nil;
}

// "@username" for the post's author, used as the queue row subtitle. Best-effort:
// an unknown media shape just yields nil and the row shows no source.
static NSString *SCIUsernameForMedia(id media) {
    id user = nil;
    @try { user = SCISafeValueForKey(media, @"user"); } @catch (__unused id e) {}

    NSString *username = nil;
    @try { username = SCISafeValueForKey(user, @"username"); } @catch (__unused id e) {}

    return [username length] ? [NSString stringWithFormat:@"@%@", username] : nil;
}

static void SCIDownloadMedia(id media, UIView *anchorView) {
    [SCIDiagnostics recordButtonMediaClass:media ? NSStringFromClass([media class]) : nil];

    // Everything — quality picker, queue routing, delegate choice — lives in the
    // coordinator, so the button behaves identically to a long press.
    [SCIMediaDownloader downloadMedia:media
                          sourceLabel:SCIUsernameForMedia(media)
                               anchor:anchorView];
}

// MARK: - Carousels

// IGMedia answers whether it is a multi-item post and hands back the child media —
// far more reliable than hunting the view hierarchy for the (Swift, non-view)
// IGPageMediaView, whose accessors also changed on IG 410.
static BOOL SCIMediaIsCarousel(id media) {
    if (!media) return NO;
    @try {
        if ([media respondsToSelector:@selector(isCarousel)]) return SCISafeBoolForKey(media, @"isCarousel");
    } @catch (__unused id e) {}
    return NO;
}

static NSArray *SCICarouselChildren(id media) {
    if (!SCIMediaIsCarousel(media)) return nil;

    for (NSString *key in @[@"carouselMedia", @"items"]) {
        id children = nil;
        @try { children = SCISafeValueForKey(media, key); } @catch (__unused id e) {}
        if ([children isKindOfClass:[NSArray class]] && [(NSArray *)children count] > 1) {
            // Note which post each slide belongs to while both are in hand. Music
            // hangs off the post, so without this a slide asked about its audio has
            // none and the save-as-video choice never appears on a multi-photo post.
            for (id slide in (NSArray *)children) [SCIUtils rememberParentPost:media forSlide:slide];

            return children;
        }
    }
    return nil;
}

// The child media of the carousel backing this action row. The resolved media may be
// the current slide (not itself a carousel), so the owner chain is walked for the
// parent post that is.
static NSArray *SCICarouselChildrenForBar(UIView *bar) {
    NSArray *children = SCICarouselChildren(SCIMediaForButtonBar(bar));
    if (children) return children;

    UIView *ancestor = bar;
    NSInteger depth = 0;
    while (ancestor && depth++ < 14) {
        for (NSString *key in @[@"media", @"post", @"feedItem", @"mediaCellFeedItem"]) {
            id media = nil;
            @try { media = SCISafeValueForKey(ancestor, key); } @catch (__unused id e) {}

            children = SCICarouselChildren(media);
            if (children) return children;

            @try {
                id nested = media ? SCISafeValueForKey(media, @"media") : nil;
                children = SCICarouselChildren(nested);
                if (children) return children;
            } @catch (__unused id e) {}
        }

        id responder = [ancestor nextResponder];
        if ([responder isKindOfClass:[UIViewController class]]) {
            for (NSString *key in @[@"media", @"post", @"feedItem"]) {
                id media = nil;
                @try { media = SCISafeValueForKey(responder, key); } @catch (__unused id e) {}
                children = SCICarouselChildren(media);
                if (children) return children;
            }
        }

        ancestor = ancestor.superview;
    }
    return nil;
}

///
/// Which slide of a carousel is actually on screen.
///
/// **"Save this one" saved the first photo whatever you were looking at**, and the reason
/// was an assumption written into the line below this: that if the resolved media is not
/// itself the carousel then it must be the visible slide. On this build the action row
/// resolves to the *post*, so that test failed and the code fell back to
/// `children.firstObject` — the first photo, every time, by design rather than by accident.
///
/// The dots under a carousel are `IGFeedItemPageControlMediaOverlay`, and it answers
/// `-pageControlCurrentPage`. Both are confirmed in a class dump of this build; neither is
/// guessed. Searching the post's own view tree for that overlay is what turns "a carousel is
/// open" into "slide 3 is open".
///
/// Returns NSNotFound when there is no overlay to ask, and the caller keeps its old
/// behaviour rather than inventing an index — a post whose dots are hidden should still save
/// something.
///
static NSInteger SCIVisibleCarouselIndex(UIView *bar) {
    Class overlayClass = NSClassFromString(@"IGFeedItemPageControlMediaOverlay");
    if (!overlayClass) return NSNotFound;

    SEL currentPage = NSSelectorFromString(@"pageControlCurrentPage");

    // Up to the post's own cell, then down through it. The overlay is a sibling of the
    // media, not an ancestor of the action row, so neither direction alone finds it.
    UIView *ancestor = bar;
    for (NSInteger depth = 0; ancestor && depth < 14; depth++, ancestor = ancestor.superview) {
        NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:ancestor];

        while (queue.count) {
            UIView *view = queue.firstObject;
            [queue removeObjectAtIndex:0];

            if ([view isKindOfClass:overlayClass] && [view respondsToSelector:currentPage]) {
                NSInteger page = ((NSInteger (*)(id, SEL))objc_msgSend)(view, currentPage);
                if (page >= 0) return page;
            }

            [queue addObjectsFromArray:view.subviews];
        }
    }

    return NSNotFound;
}

// The button's action: on a multi-item post, offer "this one" or "all N"; otherwise
// download the single media directly.
static void SCIHandleDownloadForBar(UIView *bar, UIView *anchor) {
    id current = SCIMediaForButtonBar(bar);
    NSArray *children = [SCIUtils getBoolPref:@"carousel_download_choice"] ? SCICarouselChildrenForBar(bar) : nil;

    if (children.count > 1) {
        // The visible slide, asked for rather than assumed. The old reasoning is kept as the
        // fallback for a post with no page control to ask, and is documented above.
        id currentSlide = nil;

        NSInteger index = SCIVisibleCarouselIndex(bar);
        if (index != NSNotFound && index < (NSInteger)children.count) {
            currentSlide = children[(NSUInteger)index];
        }

        if (!currentSlide) {
            currentSlide = SCIMediaIsCarousel(current) ? children.firstObject : (current ?: children.firstObject);
        }

        UIAlertController *sheet = [UIAlertController alertControllerWithTitle:nil
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];

        [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"p_carousel_current")
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *a) {
            [SCIMediaDownloader downloadMedia:currentSlide sourceLabel:nil anchor:anchor];
        }]];

        [sheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:SCILocalized(@"p_carousel_all"), (long)children.count]
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *a) {
            for (id child in children) [SCIMediaDownloader downloadMedia:child sourceLabel:nil anchor:anchor];
        }]];

        [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel") style:UIAlertActionStyleCancel handler:nil]];

        sheet.popoverPresentationController.sourceView = anchor;
        sheet.popoverPresentationController.sourceRect = anchor.bounds;
        [topMostController() presentViewController:sheet animated:YES completion:nil];
        return;
    }

    SCIDownloadMedia(current, anchor);
}

///
/// Injection
///
/// Instagram ships two action-row implementations: the older Objective-C
/// `IGUFIButtonBarView` and the Swift `IGSocialUFIView`, and which one renders a
/// given post varies by build and surface. Both are hooked, and the layout below
/// deliberately avoids per-class accessors (`saveButton` exists on one and not
/// the other) — it measures the row's own controls instead, so it survives
/// whichever implementation is live.
///

// The action row's tappable elements, left to right.
//
// Counting only direct UIControl children finds one button: Instagram wraps like
// and comment in IGUFIButtonWithCountsView containers, which are plain views. A
// subview therefore counts as a control if it *is* one or *contains* one.
static BOOL SCIContainsControl(UIView *view, NSInteger depth) {
    if ([view isKindOfClass:[UIControl class]]) return YES;
    if (depth > 3) return NO;

    for (UIView *subview in view.subviews) {
        if (SCIContainsControl(subview, depth + 1)) return YES;
    }

    return NO;
}

static NSArray<UIView *> *SCIRowControls(UIView *bar) {
    NSMutableArray<UIView *> *controls = [NSMutableArray array];

    for (UIView *subview in bar.subviews) {
        if (subview.tag == SCIInlineDownloadButtonTag) continue;
        if (subview.hidden || subview.alpha < 0.01) continue;
        if (CGRectIsEmpty(subview.frame)) continue;
        if (!SCIContainsControl(subview, 0)) continue;

        [controls addObject:subview];
    }

    [controls sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        if (CGRectGetMinX(a.frame) == CGRectGetMinX(b.frame)) return NSOrderedSame;
        return (CGRectGetMinX(a.frame) < CGRectGetMinX(b.frame)) ? NSOrderedAscending : NSOrderedDescending;
    }];

    return controls;
}

static void SCILayoutInlineButton(UIView *bar, id target) {
    UIButton *button = (UIButton *)[bar viewWithTag:SCIInlineDownloadButtonTag];

    if (!button) {
        button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.tag = SCIInlineDownloadButtonTag;
        button.accessibilityIdentifier = @"albrhi-download-button";
        button.accessibilityLabel = SCILocalized(@"inline_download_title");

        UIImageSymbolConfiguration *config =
            [UIImageSymbolConfiguration configurationWithPointSize:20.0
                                                            weight:UIImageSymbolWeightRegular];

        [button setImage:[UIImage systemImageNamed:@"arrow.down.circle" withConfiguration:config]
                forState:UIControlStateNormal];

        [button addTarget:target
                   action:@selector(sciInlineDownloadPressed:)
         forControlEvents:UIControlEventTouchUpInside];

        // The reels UFI is sized exactly to its buttons, so anything appended below
        // lands outside its bounds and gets clipped away — attached but invisible.
        bar.clipsToBounds = NO;

        [bar addSubview:button];
    }

    NSArray<UIView *> *controls = SCIRowControls(bar);

    if (!controls.count || CGRectIsEmpty(bar.bounds)) {
        button.hidden = YES;
        return;
    }

    // Feed posts lay the row out horizontally; the reels UFI stacks vertically down
    // the right edge. Measure the spread on each axis and follow whichever the row
    // is actually using, instead of assuming.
    CGFloat minX = CGFLOAT_MAX, maxX = -CGFLOAT_MAX, minY = CGFLOAT_MAX, maxY = -CGFLOAT_MAX;

    for (UIView *control in controls) {
        minX = MIN(minX, CGRectGetMinX(control.frame));
        maxX = MAX(maxX, CGRectGetMaxX(control.frame));
        minY = MIN(minY, CGRectGetMinY(control.frame));
        maxY = MAX(maxY, CGRectGetMaxY(control.frame));
    }

    BOOL vertical = (maxY - minY) > (maxX - minX);

    UIView *reference = controls.lastObject;
    CGFloat side = MAX(MIN(CGRectGetHeight(reference.frame), CGRectGetWidth(reference.frame)), 22.0);
    CGFloat gap = 14.0;
    CGRect frame;

    if (vertical) {
        // Sort by vertical position and sit below the bottom-most control.
        NSArray<UIView *> *byY = [controls sortedArrayUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
            if (CGRectGetMinY(a.frame) == CGRectGetMinY(b.frame)) return NSOrderedSame;
            return (CGRectGetMinY(a.frame) < CGRectGetMinY(b.frame)) ? NSOrderedAscending : NSOrderedDescending;
        }];

        // Sits above the top-most control — above the like button on reels, where
        // it is immediately visible instead of buried under the action stack.
        // Overflowing the bar's bounds is fine: clipping is off.
        UIView *top = byY.firstObject;
        CGFloat y = CGRectGetMinY(top.frame) - side - gap;

        frame = CGRectMake(CGRectGetMidX(top.frame) - side / 2.0, y, side, side);
        button.hidden = NO;
    }
    else {
        // The save button sits at the trailing edge; slot in just inside it.
        UIView *rightmost = controls.lastObject;
        CGFloat x = CGRectGetMinX(rightmost.frame) - side - gap;

        if (controls.count > 1) {
            UIView *neighbour = controls[controls.count - 2];

            if (x < CGRectGetMaxX(neighbour.frame) + 6.0) {
                x = CGRectGetMaxX(rightmost.frame) + gap;
            }
        }

        if (x < 0 || x + side > CGRectGetWidth(bar.bounds)) {
            x = CGRectGetWidth(bar.bounds) - side - gap;
        }

        frame = CGRectMake(x, CGRectGetMidY(rightmost.frame) - side / 2.0, side, side);
        button.hidden = (x < 0);
    }

    button.tintColor = [UIColor labelColor];
    button.frame = frame;

    [bar bringSubviewToFront:button];

    if (vertical) SCILayoutReelDate(bar, button, side);
}

/// Draws the date under the download button on the reels sidebar. Only there: a feed
/// post already shows its own timestamp, and a second one would be noise.
static void SCILayoutReelDate(UIView *bar, UIButton *button, CGFloat side) {
    UILabel *label = (UILabel *)[bar viewWithTag:SCIReelDateLabelTag];

    if (![SCIUtils getBoolPref:@"reels_show_date"]) {
        [label removeFromSuperview];
        return;
    }

    NSString *text = SCIReelDateTextForBar(bar);
    if (!text.length) {
        label.hidden = YES;
        return;
    }

    if (!label) {
        label = [[UILabel alloc] init];
        label.tag = SCIReelDateLabelTag;
        label.textAlignment = NSTextAlignmentCenter;
        label.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
        label.textColor = [UIColor whiteColor];
        label.numberOfLines = 1;
        label.adjustsFontSizeToFitWidth = YES;
        label.minimumScaleFactor = 0.7;

        // A dark plate, because a reel behind it can be any colour.
        label.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.45];
        label.layer.cornerRadius = 6.0;
        label.layer.masksToBounds = YES;

        [bar addSubview:label];
    }

    label.hidden = NO;
    label.text = text;

    // Sized to the text rather than to the sidebar. Pinned to the bar's width it came
    // out cropped, because a full date is far wider than a column of round buttons.
    CGSize needed = [label sizeThatFits:CGSizeMake(CGFLOAT_MAX, 18.0)];
    CGFloat width = needed.width + 12.0;

    // Laid out to the left of the sidebar and low down, which puts it by the account
    // name rather than in the middle of the action stack. The bar does not clip, so
    // reaching outside it is fine.
    label.frame = CGRectMake(-width - 6.0,
                             CGRectGetHeight(bar.bounds) - 18.0,
                             width, 18.0);

    [bar bringSubviewToFront:label];
}

static void SCILogRowOnce(UIView *bar) {
    static NSMutableSet<NSString *> *seen = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ seen = [NSMutableSet set]; });

    NSString *className = NSStringFromClass([bar class]);
    if ([seen containsObject:className]) return;

    [seen addObject:className];

    NSInteger controlCount = (NSInteger)SCIRowControls(bar).count;

    [SCIDiagnostics recordActionRowClass:className controlCount:controlCount];

    SCILogV(@"[Albrhi] Inline download: attached to %@ (%ld controls, bounds %@)",
          className, (long)controlCount, NSStringFromCGRect(bar.bounds));
}

static void SCIRefreshInlineButton(UIView *bar, id target) {
    if (![SCIUtils getBoolPref:@"inline_download_button"]) {
        [[bar viewWithTag:SCIInlineDownloadButtonTag] removeFromSuperview];
        return;
    }

    SCILogRowOnce(bar);
    SCILayoutInlineButton(bar, target);
}

// The row Instagram 410 renders, confirmed by scanning the live hierarchy rather
// than by reading class names out of a dump.
%hook IGUFIInteractionCountsView

- (void)layoutSubviews {
    %orig;

    SCIRefreshInlineButton((UIView *)self, self);
}

%new(v@:@) - (void)sciInlineDownloadPressed:(UIButton *)sender {
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];

    SCIHandleDownloadForBar((UIView *)self, sender);
}

%end

// The reels action bar — vertical, on the right edge. Confirmed by hierarchy scan.
%hook IGSundialViewerVerticalUFI

- (void)layoutSubviews {
    %orig;

    SCIRefreshInlineButton((UIView *)self, self);
}

%new(v@:@) - (void)sciInlineDownloadPressed:(UIButton *)sender {
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];

    SCIHandleDownloadForBar((UIView *)self, sender);
}

%end

// Older Objective-C action row, kept for builds that still use it.
%hook IGUFIButtonBarView

- (void)layoutSubviews {
    %orig;

    SCIRefreshInlineButton((UIView *)self, self);
}

%new(v@:@) - (void)sciInlineDownloadPressed:(UIButton *)sender {
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];

    SCIHandleDownloadForBar((UIView *)self, sender);
}

%end

// MARK: - The newer build's reels bar

// On the older Instagram the reels sidebar is IGSundialViewerVerticalUFI, an
// Objective-C class the %hook above reaches. On the newer one the same view became a
// Swift class, and its runtime name is mangled — Logos cannot name it, so the hook
// found nothing and the download button simply never appeared on reels there.
//
// Bound by mangled name instead. The class exists on exactly one of the two builds,
// so the other skips this entirely and behaves as it always has.

static void (*orig_swiftReelsLayout)(id, SEL);

static void sci_swiftReelsLayout(id self, SEL _cmd) {
    if (orig_swiftReelsLayout) orig_swiftReelsLayout(self, _cmd);

    SCIRefreshInlineButton((UIView *)self, self);
}

// The button targets its bar, so the Swift class needs this method too — the %new
// above only adds it to the classes Logos hooked.
static void sci_swiftReelsPressed(id self, __unused SEL _cmd, UIButton *sender) {
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];

    SCIHandleDownloadForBar((UIView *)self, sender);
}

%ctor {
    @autoreleasepool {
        // Resolved rather than spelled out: the numbers in a Swift runtime name are the
        // lengths of its module and class, so a literal is right only for the build it was
        // copied from. Moving the class to another module breaks it with no error at all.
        Class bar = SCIResolveClassWithHint(@"IGSundialViewerVerticalUFI",
            @"_TtC26IGSundialViewerVerticalUFI26IGSundialViewerVerticalUFI");
        if (!bar) return;

        class_addMethod(bar, @selector(sciInlineDownloadPressed:), (IMP)sci_swiftReelsPressed, "v@:@");

        SEL layout = @selector(layoutSubviews);
        if (!class_getInstanceMethod(bar, layout)) return;

        MSHookMessageEx(bar, layout, (IMP)sci_swiftReelsLayout, (IMP *)&orig_swiftReelsLayout);

        SCILogV(@"[Albrhi] Inline download: bound the Swift reels bar");
    }
}
