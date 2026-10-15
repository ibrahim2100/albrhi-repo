#import <objc/runtime.h>
#import <objc/message.h>
#import "shared/src/SCIResponder.h"
#import "shared/src/SCIKVC.h"
#import "../../YouTubeHeaders.h"
#import "../../SCILog.h"
#import "../../Prefs.h"
#import "../../SCIYTLaunchGuard.h"
#import "../../Localization/SCILocalize.h"
#import "../../Diagnostics/SCIYTDiagnostics.h"
#import "../Download/SCIYTDownload.h"

///
/// A save button inside YouTube's own player, and the clock time the video ends at.
///
/// Until now the tweak had no presence on the layer over the video at all: a tab at the
/// bottom of the app and buttons in Shorts, and nothing where a video is actually being
/// watched. Saving meant leaving the player, which is the one moment nobody wants to.
///
/// **The technique is read from YTVideoOverlay by PoomSmart (MIT), not copied from it.**
/// That tweak is a framework other tweaks register buttons with; this is one button for one
/// tweak, so the registry, the settings integration and the per-tweak metadata table it
/// carries are all left out. What is taken is the answer to the only question that mattered:
/// *which two classes own the two places a button can go*, which is exactly the kind of
/// thing this project reads open source for rather than guessing at.
///
/// **Both classes are leads.** Neither appears in a class dump this project has taken of
/// this build, so nothing here assumes either exists:
///
///   - a `%hook` on an absent class never attaches, which is the cheap half;
///   - every selector is behind `-respondsToSelector:`, because a class that exists with a
///     renamed accessor is the case that crashes rather than no-ops;
///   - the diagnostics report names which of the two attached, so "no button" is never two
///     silent reasons at once. That loop is what this project uses instead of guessing, and
///     it is the whole reason the X tweak's three button surfaces are all still in place.
///
/// The end time is a label rather than a fourth thing drawn on the progress bar. The bar is
/// two points of usable height -- the SponsorBlock markers sit *on* it at that thickness --
/// and a time needs a line of text, so it goes in the container beside the icons where
/// there is room for one.
///

///
/// What this surface is actually doing, in numbers rather than in one overwritten sentence.
///
/// **This button shipped with no report at all for eight releases.** Its only record went into
/// `-recordMarkerBar:`, which is the SponsorBlock progress-bar line — so a feature that was off
/// by default and unconfirmed had its one piece of evidence filed under an unrelated heading,
/// and no report has ever mentioned it. A diagnostic written into the wrong slot is worse than
/// none: it reads as covered.
static NSUInteger sciOverlaysSeen = 0;
static NSUInteger sciOverlayButtonsMade = 0;
static NSUInteger sciOverlayTaps = 0;

/// How many times YouTube told us the controls were appearing or disappearing.
///
/// Counted because the whole fade rides on those two calls arriving: a zero here and a button
/// that never moves is "this build does not call these setters", while a rising count and a
/// button that never moves is a placement or alpha problem. Those need different work, and one
/// symptom cannot say which -- the same reason the button's own construction is counted
/// separately from its taps.
static NSUInteger sciOverlayFadeSignals = 0;

/// Where the button ended up vertically, so "it overlaps the title" has a number next to it.
static CGFloat sciOverlayTopInset = 8;

static char kSCIOverlaySaveButton;
static char kSCIOverlayJoined;

/// The buttons that sit beside the save button, nearest first: the quality label and the picture-in-picture button. An overlay gets this
/// array once, when it is first built; a switch changed afterwards takes effect on the next video's overlay.
static char kSCIOverlayExtras;
static const NSInteger SCIOverlayQualityTag = 0x5C10B9;
static const NSInteger SCIOverlayPiPTag     = 0x5C10BA;

/// Every quality button that exists, held weakly, so a choice made in the quality sheet can retitle all of them without an observer
/// per overlay that would have to be removed again.
static NSHashTable<UIButton *> *sciQualityButtons = nil;
static NSString *sciQualityLabel = @"Auto";
static NSUInteger sciQualityMade = 0, sciQualityTaps = 0, sciQualityChosen = 0;
static NSUInteger sciPiPMade = 0, sciPiPTaps = 0, sciPiPRefused = 0;

/// The button's own frame, and whether it is in a window.
///
/// **1.27.0's report said the button was made and handed to YouTube's layout, and nothing was on
/// screen — because a button appended to an array had never been added to any view.** The report
/// was accurate about everything it measured and measured the wrong thing: it counted the making
/// and not the placing. Both are here now, and a frame of zero says which half failed without
/// another release to find out.
static NSString *sciOverlayPlacement = nil;

static void SCIReportOverlayState(BOOL joined) {
    NSString *extras = [NSString stringWithFormat:SCILocalized(@"diag_overlay_extras"),
        (unsigned long)sciQualityMade, (unsigned long)sciQualityTaps, (unsigned long)sciQualityChosen,
        (unsigned long)sciPiPMade, (unsigned long)sciPiPTaps, (unsigned long)sciPiPRefused];
    [SCIYTDiagnostics recordOverlayButton:
        [[NSString stringWithFormat:SCILocalized(@"diag_overlay_counts"),
            (unsigned long)sciOverlaysSeen,
            (unsigned long)sciOverlayButtonsMade,
            joined ? SCILocalized(@"diag_overlay_native") : SCILocalized(@"diag_overlay_placed"),
            (unsigned long)sciOverlayTaps,
            (unsigned long)sciOverlayFadeSignals,
            sciOverlayPlacement ?: SCILocalized(@"diag_overlay_unplaced")] stringByAppendingFormat:@" · %@", extras]];
}

static const NSInteger SCIOverlayButtonTag = 0x5C10B7;
static const NSInteger SCIEndTimeTag       = 0x5C10B8;

/// Whether a view is one of the buttons this file added. The neighbour search below must never measure them: it would take its own
/// button for the control it is meant to sit beside, and the button would walk.
static BOOL SCIIsOurs(UIView *view) {
    return view.tag == SCIOverlayButtonTag || view.tag == SCIOverlayQualityTag || view.tag == SCIOverlayPiPTag;
}

/// The clock time a video ends at, from now plus what is left of it.
///
/// Formatted with the user's own locale and 24-hour preference rather than a hand-built
/// string: "ends 23:40" and "ends 11:40 PM" are the same fact, and which one is right is a
/// setting the phone already holds.
static NSString *SCIEndTimeText(double totalTime, double elapsed) {
    double remaining = totalTime - elapsed;
    if (!isfinite(remaining) || remaining <= 0) return nil;

    static NSDateFormatter *clock = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        clock = [[NSDateFormatter alloc] init];
        clock.dateStyle = NSDateFormatterNoStyle;
        clock.timeStyle = NSDateFormatterShortStyle;
    });

    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:remaining];
    return [NSString stringWithFormat:SCILocalized(@"overlay_ends_at"), [clock stringFromDate:end]];
}

/// Walks up to the view controller a view belongs to.
///
/// The sheet has to be presented from something, and a button knows only its own view. The
/// responder chain is the one route that needs no class name at all -- which is the point,
/// on a surface where every class name is already a lead.


///
/// Fading with YouTube's own controls, on YouTube's own signal.
///
/// The button used to sit there permanently, over the picture, whether or not the controls were
/// showing — which is wrong in the ordinary way a guest is wrong: everything else on that layer
/// comes and goes with a tap, and one thing that does not reads as stuck rather than as ours.
///
/// **Two flags rather than one, because the app has two.** `-setOverlayVisible:` governs the
/// whole control layer and `-setTopOverlayVisible:isAutonavCanceledState:` governs the top row
/// alone, which is the row this button is in — so it shows only when both say so. The top flag
/// starts YES and is only ever changed by its own setter: a build that never calls it would
/// otherwise leave the button invisible forever, which is the failure direction that looks like
/// the feature was never installed.
///
/// **Nothing is polled.** `-layoutSubviews` runs at times unrelated to a fade and does not run
/// during one; these are the two moments YouTube itself decides.
static char kSCIOverlayShown;
static char kSCIOverlayTopShown;

// SCITopInsetFor is gone with the constraint it fed. It measured `-topControlsHeight` to put the
// button *under* the top row; the button is now *in* that row, sized and lined up from the
// buttons beside it, so a measurement of the row's height has nothing left to decide.


/// **Placement happens once per overlay, and never from inside a layout pass.**
///
/// `-topControls` is a getter YouTube calls *while it is laying out*, and 1.27.1 put
/// `-bringSubviewToFront:` in it, plus two localized format strings and a diagnostics write, on
/// every single call. Bringing a subview to the front marks the hierarchy as needing layout;
/// laying out asks for `-topControls` again; and that is a loop with nothing to stop it. On top
/// of it 1.28.2 set a constraint constant from `-layoutSubviews`, measured with
/// `-topControlsHeight` — the height of the row this button is inside — so the measurement moved
/// every time the button did. Two feedback loops on the main thread, in the player, which is why
/// YouTube sat on its own logo and never finished launching.
///
/// The rule this leaves behind is worth more than the fix: **a hook on a getter that layout calls
/// must be free the second time.** Do the work when there is work — build the button once, place
/// it once — and hand back `%orig` untouched ever after.
// The write cap is gone with the constraint it protected. It bounded how many times a constraint
// constant could be written, because a measurement that would not settle was a loop; a frame
// written onto a child cannot loop, and this frame legitimately changes on every rotation,
// fullscreen toggle and reflow. What stops needless writes is the half-point comparison below.

/// Writes the top constraint, bounded twice: only for a real change, and only so many times for
/// one overlay. A measurement that will not settle then costs a button six points out of place
/// rather than an app that will not start.
/// The frame our button wants: one gap to the left of the top row's right-hand group.
///
/// Measured from the overlay's own buttons rather than chosen. The right of that row carries
/// cast, subtitles and the gear on a build that has all three and fewer on one that does not, so
/// a number written here would be right on one phone and wrong on the next.
/// The autoplay switch, wherever it is in the overlay's own tree.
///
/// **It is the anchor because it is the one that moves.** It starts hidden and appears when
/// playback begins, so "the leftmost control on the right" is a different button before and after
/// a video starts — which is exactly what was seen: the save button sat correctly, the switch
/// arrived, and the button jumped away. Anchoring to the thing that changes is what stops the
/// measurement changing under it.
static UIView *SCIAutonavSwitch(UIView *root, NSUInteger depth) {
    if (depth > 3) return nil;

    for (UIView *child in root.subviews) {
        if ([NSStringFromClass([child class]) isEqualToString:@"YTAutonavSwitch"]) return child;
        UIView *deeper = SCIAutonavSwitch(child, depth + 1);
        if (deeper) return deeper;
    }
    return nil;
}

static CGRect SCIFrameBesideTopControls(YTMainAppControlsOverlayView *overlay, UIView *ours) {
    //
    // **Leading and trailing, not left and right — reported from an Arabic phone.**
    //
    // The placement was written as "the leftmost control on the right half, and our button one gap
    // to its left". Every word of that is correct in English and wrong in Arabic: UIKit mirrors
    // the row, so the cast, subtitles and gear group moves to the *left* and the collapse chevron
    // to the right. The old rule then measured the chevron, or nothing, and put the button
    // wherever that arithmetic landed.
    //
    // Nothing about the layout is detected here: `effectiveUserInterfaceLayoutDirection` is the
    // answer UIKit itself uses to mirror, asked of the same view being measured.
    //
    BOOL mirrored = (overlay.effectiveUserInterfaceLayoutDirection ==
                     UIUserInterfaceLayoutDirectionRightToLeft);
    CGFloat middle = overlay.bounds.size.width / 2.0;

    //
    // **Buttons only, and only button-sized ones.**
    //
    // An earlier version measured "the leftmost control", which caught a *container* 96 points
    // wide and gave our button that width -- and the button is placed its own width from the
    // anchor, so it landed a container's width away. It looked like flight; it was arithmetic on
    // the wrong number.
    //
    CGRect reference = CGRectNull;
    CGFloat best = mirrored ? -CGFLOAT_MAX : CGFLOAT_MAX;
    CGFloat topBand = MAX(44.0, overlay.bounds.size.height * 0.35);

    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithArray:overlay.subviews];
    NSUInteger walked = 0;

    while (queue.count && walked < 200) {
        UIView *child = queue.firstObject;
        [queue removeObjectAtIndex:0];
        walked++;

        if (child != ours && !SCIIsOurs(child) && !child.hidden) [queue addObjectsFromArray:child.subviews];

        if (child == ours || SCIIsOurs(child) || child.hidden) continue;
        if (![child isKindOfClass:[UIButton class]]) continue;

        CGRect frame = [child convertRect:child.bounds toView:overlay];
        if (frame.size.width < 16 || frame.size.width > 56) continue;
        if (frame.size.height < 16) continue;
        if (CGRectGetMaxY(frame) > topBand) continue;          // the top row only

        // The trailing side, whichever side that is: the right in English, the left in Arabic.
        // The chevron lives on the leading side and is what this must never measure.
        BOOL trailingSide = mirrored ? (CGRectGetMidX(frame) < middle)
                                     : (CGRectGetMidX(frame) > middle);
        if (!trailingSide) continue;

        // The one nearest the middle of the row, which is where our button goes next to.
        CGFloat edge = mirrored ? CGRectGetMaxX(frame) : CGRectGetMinX(frame);
        BOOL nearer = mirrored ? (edge > best) : (edge < best);
        if (nearer) { best = edge; reference = frame; }
    }

    if (CGRectIsNull(reference)) return CGRectNull;

    // The anchor: the autoplay switch when it has been laid out, the innermost button otherwise.
    // The switch is what appears when playback starts, so measuring from anything else gives one
    // answer before that and another after it -- which was reported as the button jumping.
    UIView *autonav = SCIAutonavSwitch(overlay, 0);
    CGRect anchor = reference;
    if (autonav && autonav.bounds.size.width > 0) {
        CGRect converted = [autonav convertRect:autonav.bounds toView:overlay];
        if (CGRectGetMinX(converted) > 0) anchor = converted;
    }

    CGFloat gap = 8;
    CGFloat x = mirrored ? (CGRectGetMaxX(anchor) + gap)
                         : (CGRectGetMinX(anchor) - reference.size.width - gap);

    return CGRectMake(x, CGRectGetMidY(anchor) - reference.size.height / 2.0,
                      reference.size.width, reference.size.height);
}

/// Our buttons that are in this overlay, in the order they sit: save first, then the extras, each further from the anchor.
static NSArray<UIButton *> *SCIOurTopButtons(YTMainAppControlsOverlayView *overlay) {
    NSMutableArray<UIButton *> *buttons = [NSMutableArray array];
    UIButton *save = objc_getAssociatedObject(overlay, &kSCIOverlaySaveButton);
    if (save && save.superview == overlay) [buttons addObject:save];
    for (UIButton *extra in (NSArray *)objc_getAssociatedObject(overlay, &kSCIOverlayExtras)) {
        if (extra.superview == overlay) [buttons addObject:extra];
    }
    return buttons;
}

static void SCIApplyTopInset(YTMainAppControlsOverlayView *overlay) {
    NSArray<UIButton *> *buttons = SCIOurTopButtons(overlay);
    if (!buttons.count) return;

    CGRect wanted = SCIFrameBesideTopControls(overlay, buttons.firstObject);
    if (CGRectIsNull(wanted)) return;

    // Each further button one gap beyond the one before it, away from the anchor: to the left in English, to the right in Arabic.
    BOOL mirrored = (overlay.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft);
    CGFloat step = wanted.size.width + 8;

    for (NSUInteger i = 0; i < buttons.count; i++) {
        UIButton *button = buttons[i];
        CGRect frame = wanted;
        frame.origin.x += (mirrored ? 1 : -1) * step * (CGFloat)i;

        // Half a point, because a difference smaller than that is rounding, and writing rounding back
        // into a frame from a layout-adjacent path is how a settled layout is made to move again.
        if (ABS(button.frame.origin.x - frame.origin.x) < 0.5 &&
            ABS(button.frame.origin.y - frame.origin.y) < 0.5 &&
            ABS(button.frame.size.width - frame.size.width) < 0.5) continue;

        button.frame = frame;
    }
    sciOverlayTopInset = wanted.origin.y;
}


/// Where the button actually ended up, read on a visibility signal rather than during layout.
///
/// It used to be built on every `-topControls` call — two localized format strings per call, on a
/// getter layout asks for constantly. Here it costs two strings each time the controls appear or
/// disappear, which is a handful a minute, and the numbers in it are real: the button has been
/// laid out by the time these fire, so a frame of zero means something rather than "too early".
static void SCIRecordOverlayPlacement(YTMainAppControlsOverlayView *overlay) {
    UIButton *save = SCIOurTopButtons(overlay).firstObject;
    if (!save) return;

    sciOverlayPlacement =
        [NSString stringWithFormat:SCILocalized(@"diag_overlay_frame_inset"),
            (double)sciOverlayTopInset,
            [overlay respondsToSelector:@selector(topControlsHeight)]
                ? (double)[overlay topControlsHeight] : -1.0];
    sciOverlayPlacement = [sciOverlayPlacement stringByAppendingFormat:@" · %@",
        [NSString stringWithFormat:SCILocalized(@"diag_overlay_frame"),
            (double)save.frame.origin.x, (double)save.frame.origin.y,
            (double)save.frame.size.width, (double)save.frame.size.height,
            save.window ? SCILocalized(@"diag_overlay_in_window")
                        : SCILocalized(@"diag_overlay_no_window")]];

    SCIReportOverlayState([objc_getAssociatedObject(overlay, &kSCIOverlayJoined) boolValue]);
}


static void SCISyncSaveButton(YTMainAppControlsOverlayView *overlay, BOOL animated) {
    NSArray<UIButton *> *buttons = SCIOurTopButtons(overlay);
    if (!buttons.count) return;

    NSNumber *shown = objc_getAssociatedObject(overlay, &kSCIOverlayShown);
    NSNumber *topShown = objc_getAssociatedObject(overlay, &kSCIOverlayTopShown);

    // Absent reads as visible for the top flag and as "ask the view" for the whole layer, so a
    // button built before either setter has fired matches whatever is on screen right now.
    BOOL wanted = (topShown ? topShown.boolValue : YES) &&
                  (shown ? shown.boolValue
                         : ([overlay respondsToSelector:@selector(isOverlayVisible)]
                            ? [overlay isOverlayVisible] : YES));

    CGFloat target = wanted ? 1.0 : 0.0;

    for (UIButton *button in buttons) {
        if (button.alpha == target) continue;

        // The duration is YouTube's own fade to within a frame, and a reduced-motion setting is
        // honoured by skipping it rather than by leaving the button behind.
        if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
            button.alpha = target;
            continue;
        }

        [UIView animateWithDuration:0.2
                              delay:0
                            options:UIViewAnimationOptionBeginFromCurrentState |
                                    UIViewAnimationOptionCurveEaseInOut
                         animations:^{ button.alpha = target; }
                         completion:nil];
    }
}


/// The quality button's text, from the format the person just picked: 2160p becomes 4K, 1440p 2K, 1080p HD, and a frame rate above 30 goes on
/// a second line. Written for this tweak; the idea (a label that says what is playing) is YouQuality's, by PoomSmart (MIT).
static NSString *SCICompactQuality(id format) {
    if (!format || ![format respondsToSelector:@selector(qualityLabel)]) return nil;
    NSString *label = ((id (*)(id, SEL))objc_msgSend)(format, @selector(qualityLabel));
    if (![label isKindOfClass:[NSString class]] || !label.length) return nil;

    double fps = [format respondsToSelector:@selector(FPS)] ? ((double (*)(id, SEL))objc_msgSend)(format, @selector(FPS)) : 0;
    BOOL high = fps > 30;
    NSString *separator = high ? @"\n" : @"";

    if ([label hasPrefix:@"2160p"]) label = [label stringByReplacingOccurrencesOfString:@"2160p" withString:[@"4K" stringByAppendingString:separator]];
    else if ([label hasPrefix:@"1440p"]) label = [label stringByReplacingOccurrencesOfString:@"1440p" withString:[@"2K" stringByAppendingString:separator]];
    else if ([label hasPrefix:@"1080p"]) label = [label stringByReplacingOccurrencesOfString:@"1080p" withString:[@"HD" stringByAppendingString:separator]];
    else if (high) label = [label stringByReplacingOccurrencesOfString:@"p" withString:@"p\n" options:0 range:NSMakeRange(0, MIN((NSUInteger)label.length, (NSUInteger)6))];
    if ([label hasSuffix:@" HDR"]) label = [label stringByReplacingOccurrencesOfString:@" HDR" withString:@"\nHDR"];
    return label;
}

static void SCIQualityWasChosen(id format) {
    NSString *label = SCICompactQuality(format);
    if (!label) return;
    sciQualityChosen++;
    sciQualityLabel = label;
    for (UIButton *button in sciQualityButtons.allObjects) [button setTitle:label forState:UIControlStateNormal];
}

/// One extra button for the top row: a text one (quality) or an icon one (picture in picture), made by YouTube's own factory where it
/// answers and by UIKit where it does not. Same construction as the save button's, and added to the overlay the same way.
static UIButton *SCIMakeTopButton(YTMainAppControlsOverlayView *overlay, UIImage *icon, NSString *title, NSString *accessibility,
                                  NSInteger tag, SEL action) {
    UIButton *button = nil;
    if (icon && [overlay respondsToSelector:@selector(playerButtonWithImage:selectedImage:accessibilityLabel:verticalContentPadding:minHitTargetSize:)]) {
        id built = [overlay playerButtonWithImage:icon selectedImage:icon accessibilityLabel:accessibility verticalContentPadding:0 minHitTargetSize:48];
        if ([built isKindOfClass:[UIControl class]]) button = (UIButton *)built;
    }
    if (!button) {
        button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.accessibilityLabel = accessibility;
        if (icon) [button setImage:icon forState:UIControlStateNormal];
    }
    if (title) {
        [button setTitle:title forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
        button.titleLabel.numberOfLines = 2;
        button.titleLabel.textAlignment = NSTextAlignmentCenter;
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
    button.tintColor = [UIColor whiteColor];
    button.tag = tag;
    button.translatesAutoresizingMaskIntoConstraints = YES;
    [button addTarget:overlay action:action forControlEvents:UIControlEventTouchUpInside];
    [overlay addSubview:button];
    return button;
}

/// Builds the extras once for this overlay, for whichever of the two switches was on at that moment.
static void SCIBuildExtraButtons(YTMainAppControlsOverlayView *overlay, BOOL quality, BOOL pip) {
    NSMutableArray<UIButton *> *extras = [NSMutableArray array];

    if (quality) {
        UIButton *button = SCIMakeTopButton(overlay, nil, sciQualityLabel, SCILocalized(@"overlay_quality"), SCIOverlayQualityTag, @selector(sciQualityTapped:));
        static dispatch_once_t once;
        dispatch_once(&once, ^{ sciQualityButtons = [NSHashTable weakObjectsHashTable]; });
        [sciQualityButtons addObject:button];
        [extras addObject:button];
        sciQualityMade++;
    }

    if (pip) {
        UIImage *icon = [UIImage systemImageNamed:@"pip.enter"] ?: [UIImage systemImageNamed:@"rectangle.on.rectangle"];
        [extras addObject:SCIMakeTopButton(overlay, icon, nil, SCILocalized(@"overlay_pip"), SCIOverlayPiPTag, @selector(sciPiPTapped:))];
        sciPiPMade++;
    }

    objc_setAssociatedObject(overlay, &kSCIOverlayExtras, extras, OBJC_ASSOCIATION_RETAIN);
}


%group SCIOverlayTop

%hook YTMainAppControlsOverlayView

///
/// The row of buttons across the top of the player, and where ours is made.
///
/// `-topControls` is not modified — 1.27.0 appended the button to the array this returns on the
/// reasoning that the player would then place it, and a view in an array is not a view in a
/// hierarchy: it had no superview and nothing drew it. This hook is simply a moment that fires
/// once the overlay exists, which is when the button can be built and added.
///
/// **The button is built by YouTube's own factory where there is one.**
/// `-playerButtonWithImage:selectedImage:accessibilityLabel:verticalContentPadding:minHitTargetSize:`
/// hands back a YTQTMButton measured the way the app measures its own, so it looks like the
/// controls beside it rather than like a guest. A build without that factory is not guessed at:
/// a plain button is used instead and the report says which of the two happened.
///
- (NSArray *)topControls {
    NSArray *controls = %orig;

    if (SCIYTStoodDown()) return controls;

    BOOL wantSave = SCIPrefEnabled(SCIPrefOverlayButton);
    BOOL wantQuality = SCIPrefEnabled(SCIPrefOverlayQuality);
    BOOL wantPiP = SCIPrefEnabled(SCIPrefOverlayPiP);
    if (!wantSave && !wantQuality && !wantPiP) return controls;

    @try {
        UIButton *save = objc_getAssociatedObject(self, &kSCIOverlaySaveButton);
        BOOL joined = [objc_getAssociatedObject(self, &kSCIOverlayJoined) boolValue];

        // **Nothing at all once the buttons are placed.** Everything below belongs to building them,
        // and this method is called during layout: anything it does on every call is something
        // layout does on every call, and two of those together stopped the app from starting.
        BOOL saveSettled = !wantSave || (save && save.superview == self);
        BOOL extrasBuilt = objc_getAssociatedObject(self, &kSCIOverlayExtras) != nil;
        if (saveSettled && extrasBuilt) return controls;

        sciOverlaysSeen++;

        if (wantSave && !save) {
            // **The app's own glyph, not ours.** YouTube draws downloading as an arrow into a
            // tray, and a circled arrow beside it reads as a guest even when everything else
            // about the button is the app's. `arrow.down.to.line` is that shape in SF Symbols.
            UIImage *icon = [UIImage systemImageNamed:@"arrow.down.to.line"]
                          ?: [UIImage systemImageNamed:@"arrow.down.circle"];

            if ([self respondsToSelector:@selector(playerButtonWithImage:selectedImage:accessibilityLabel:verticalContentPadding:minHitTargetSize:)]) {
                // 0 padding and a 48pt target: the padding is the app's to decide from its own
                // metrics and 0 asks for that default, while 48 is the size a finger needs and
                // the one number here that is about people rather than about YouTube.
                id built = [self playerButtonWithImage:icon
                                         selectedImage:icon
                                    accessibilityLabel:SCILocalized(@"overlay_save")
                                verticalContentPadding:0
                                      minHitTargetSize:48];

                // Checked rather than cast. A factory that answers with something that is not a
                // control would otherwise be found out by -addTarget:, in the player, at the
                // worst moment.
                if ([built isKindOfClass:[UIControl class]]) {
                    save = (UIButton *)built;
                    joined = YES;
                }
            }

            if (!save) {
                save = [UIButton buttonWithType:UIButtonTypeSystem];
                save.accessibilityLabel = SCILocalized(@"overlay_save");
                [save setImage:icon forState:UIControlStateNormal];
            }

            // White, like every other control on that row. The factory hands back a button
            // tinted for wherever it was going to be used, which is not necessarily over video.
            save.tintColor = [UIColor whiteColor];

            save.tag = SCIOverlayButtonTag;
            [save addTarget:self action:@selector(sciSaveTapped:)
           forControlEvents:UIControlEventTouchUpInside];

            objc_setAssociatedObject(self, &kSCIOverlaySaveButton, save, OBJC_ASSOCIATION_RETAIN);
            objc_setAssociatedObject(self, &kSCIOverlayJoined, @(joined), OBJC_ASSOCIATION_RETAIN);

            //
            // **Added to the view, always — this is the whole of 1.27.1.**
            //
            // 1.27.0 built the button with YouTube's own factory and returned it inside the
            // array `-topControls` answers with, on the reasoning that the player would then
            // position it. A view that is in an array is not a view that is in a hierarchy:
            // it had no superview, so there was nothing to lay out and nothing to draw, and
            // the report said "made and handed to its layout" while the screen was empty.
            //
            // The array append is gone rather than kept alongside this. It placed nothing,
            // and a mechanism that decides nothing is worse than a missing one -- it reads as
            // a thing that works.
            //
            // Top-left, past the collapse chevron. The right of that bar carries cast,
            // subtitles and the overflow menu on a build that has them all, and this project
            // has no way to measure their widths from here; the left of it carries one button
            // and then nothing.
            //
            //
            // **In the top row, beside subtitles and the gear — placed by frame, not by anchors.**
            //
            // Anchors need something to be anchored *to*, and the buttons in that row are laid
            // out by the overlay itself: there is no guide for "left of the leftmost of the right
            // group" and pinning to the safe area is what put this button under the title in the
            // first place. So the frame is taken from the neighbours themselves, on the two
            // visibility signals -- their size, their centre line, one gap to the left of them.
            //
            // Which makes the button the same height as the row's own controls, moving with them
            // in fullscreen and inline alike, without a number in this file deciding any of it.
            //
            save.translatesAutoresizingMaskIntoConstraints = YES;
            [self addSubview:save];

            sciOverlayButtonsMade++;

            // Matched to what is on screen the instant it exists, without animating: a button
            // that fades in the moment it is built would read as something appearing on its own.
            SCISyncSaveButton(self, NO);
        }

        // The two extras, once, next to the save button. They are built from the same hook, on the same moment and in the same way,
        // so a build where the save button attaches is a build where these attach.
        if (!extrasBuilt) {
            SCIBuildExtraButtons(self, wantQuality, wantPiP);
            SCISyncSaveButton(self, NO);
        }

        // Kept in front of whatever the player draws over the picture. Ours is the last thing
        // added and the first thing a redraw of YouTube's own controls would bury.
        for (UIButton *button in SCIOurTopButtons(self)) [self bringSubviewToFront:button];

        // The frame is not read here: at build time it is zero, because nothing has been laid
        // out yet, and a report of 0×0 would say the placement failed when it has not happened
        // yet. It is recorded on the visibility signals below, where the button has a frame and
        // where the work is not on a layout path.
        SCIReportOverlayState(joined);
    } @catch (NSException *exception) {
        // A button is a convenience and the player is not. Anything thrown here costs the
        // button and nothing else -- the same trade every drawing hook in this tweak makes.
        SCILogV(@"overlay: top button — %@", exception.reason);
        [SCIYTDiagnostics recordOverlayButton:
            [NSString stringWithFormat:SCILocalized(@"diag_overlay_threw"), exception.reason]];
    }

    return controls;
}

// The parameter carries no __unused, and must not.
//
// %new builds the method's type encoding by pasting the parameter's written type straight
// into @encode(...), so `__unused UIButton *` became `@encode(__unused UIButton *)` -- an
// attribute inside @encode, which clang reports as ignored-while-parsing-a-type and
// -Werror turns into three fatal errors in one generated line. Every other %new in this
// project writes a plain typed parameter for the same reason; an unused one is not warned
// about in an Objective-C method the way it would be in a C function.
//
// **The frame is written from -layoutSubviews, and the difference from what broke the app is
// exactly what is written.**
//
// Applying it only on the two visibility signals left the button drifting: the overlay lays its
// own controls out whenever the player resizes, rotates, enters fullscreen or simply reflows, and
// a frame measured from where the neighbours *were* is wrong the moment they move. The button
// looked placed and then wandered.
//
// What made 1.28.2 unlaunchable was not writing from layout — it was writing a **constraint
// constant** measured from the row this button is inside: that invalidates the constraint system
// upward, the parent lays out again, and the measurement moves again. Setting a *child's frame*
// marks the child as needing layout and does not ask the parent for anything, so it settles in
// one pass. With the half-point guard below, an unchanged frame is not written at all.
- (void)layoutSubviews {
    %orig;

    // After %orig: the neighbours have to be where they are going to be before anything is
    // measured from them.
    SCIApplyTopInset(self);
}

- (void)setOverlayVisible:(BOOL)visible {
    %orig;
    sciOverlayFadeSignals++;

    // **No scan is taken here any more, and the reason is worth keeping.**
    //
    // This looked like the right moment -- the player is on screen when the controls fade in --
    // and it was the wrong *object*. These overlays exist off-screen too: the one that answered
    // had a nil window and a frame of 0×0, so the walk started at the overlay itself and
    // described 48 playback controls, three reports running. Worse, answering here consumed the
    // request, so the timer that would have scanned the whole window never ran.
    //
    // A trigger that can fire on a detached instance is a trigger that reports the wrong tree
    // and hides the one that would have been right.
    objc_setAssociatedObject(self, &kSCIOverlayShown, @(visible), OBJC_ASSOCIATION_RETAIN);
    SCIApplyTopInset(self);
    SCISyncSaveButton(self, YES);
    SCIRecordOverlayPlacement(self);
}

- (void)setTopOverlayVisible:(BOOL)visible isAutonavCanceledState:(BOOL)cancelled {
    %orig;
    sciOverlayFadeSignals++;
    objc_setAssociatedObject(self, &kSCIOverlayTopShown, @(visible), OBJC_ASSOCIATION_RETAIN);
    SCIApplyTopInset(self);
    SCISyncSaveButton(self, YES);
    SCIRecordOverlayPlacement(self);
}

%new
- (void)sciSaveTapped:(UIButton *)sender {
    sciOverlayTaps++;
    SCIReportOverlayState([objc_getAssociatedObject(self, &kSCIOverlayJoined) boolValue]);

    UIViewController *host = SCIControllerForView(self);
    if (!host) {
        [SCIYTDiagnostics recordOverlayButton:SCILocalized(@"diag_overlay_no_host")];
        return;
    }
    [SCIYTDownload presentFrom:host];
}

%new
- (void)sciQualityTapped:(UIButton *)sender {
    sciQualityTaps++;
    SCIReportOverlayState([objc_getAssociatedObject(self, &kSCIOverlayJoined) boolValue]);

    // YouTube's own quality sheet, asked for the way its own button asks: the overlay's events delegate is the controller that owns it.
    id delegate = SCISafeValueForKey(self, @"eventsDelegate");
    if ([delegate respondsToSelector:@selector(didPressVideoQuality:)]) {
        ((void (*)(id, SEL, id))objc_msgSend)(delegate, @selector(didPressVideoQuality:), sender);
    }
}

%new
- (void)sciPiPTapped:(UIButton *)sender {
    sciPiPTaps++;

    // overlay -> its events delegate (the overlay controller) -> the player controller it is a child of -> the playback controller -> the
    // PiP controller. Every hop is an object getter or an object ivar, read without running anything of YouTube's.
    id delegate = SCISafeValueForKey(self, @"eventsDelegate");
    UIViewController *player = [delegate isKindOfClass:[UIViewController class]] ? [(UIViewController *)delegate parentViewController] : nil;
    id playback = SCISafeValueForKey(player, @"playbackController");
    id pip = SCISafeValueForKey(playback, @"playerPIPController");

    BOOL canEnable = [pip respondsToSelector:@selector(canEnablePictureInPicture)]
        && ((BOOL (*)(id, SEL))objc_msgSend)(pip, @selector(canEnablePictureInPicture));

    if (canEnable && [pip respondsToSelector:@selector(maybeTogglePictureInPicture)]) {
        ((void (*)(id, SEL))objc_msgSend)(pip, @selector(maybeTogglePictureInPicture));
    } else {
        sciPiPRefused++;
    }
    SCIReportOverlayState([objc_getAssociatedObject(self, &kSCIOverlayJoined) boolValue]);
}

%end

%end


%group SCIQualityOriginal
%hook YTVideoQualitySwitchOriginalController
- (void)singleVideo:(id)singleVideo didSelectVideoFormat:(id)format {
    SCIQualityWasChosen(format);
    %orig;
}
%end
%end

%group SCIQualityRedesigned
%hook YTVideoQualitySwitchRedesignedController
- (void)singleVideo:(id)singleVideo didSelectVideoFormat:(id)format {
    SCIQualityWasChosen(format);
    %orig;
}
%end
%end


%group SCIOverlayBottom

%hook YTInlinePlayerBarContainerView

- (void)layoutSubviews {
    %orig;

    if (!SCIPrefEnabled(SCIPrefOverlayEndTime)) {
        UIView *stale = [self viewWithTag:SCIEndTimeTag];
        if (stale) [stale removeFromSuperview];
        return;
    }

    @try {
        double total = [self respondsToSelector:@selector(totalTime)] ? self.totalTime : 0;
        if (!isfinite(total) || total <= 0) return;

        // The elapsed side is not asked for. This container does not advertise one, and
        // guessing an accessor on a lead class is how 0.1.1 died -- so the label says when
        // the video ends if it runs from *here*, which is the question anyone reading it is
        // actually asking, and it needs only the duration this class does answer.
        NSString *text = SCIEndTimeText(total, 0);
        if (!text) return;

        UILabel *label = (UILabel *)[self viewWithTag:SCIEndTimeTag];
        if (!label) {
            label = [[UILabel alloc] init];
            label.tag = SCIEndTimeTag;
            label.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
            label.textColor = [UIColor colorWithWhite:1 alpha:0.75];
            label.userInteractionEnabled = NO;
            label.translatesAutoresizingMaskIntoConstraints = NO;
            [self addSubview:label];

            [NSLayoutConstraint activateConstraints:@[
                [label.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
                [label.bottomAnchor constraintEqualToAnchor:self.topAnchor constant:-2]
            ]];

            [SCIYTDiagnostics recordMarkerBar:@"YTInlinePlayerBarContainerView(endtime)" count:1];
        }

        // **Only when it changed, and the reorder only when it is not already on top.**
        //
        // This ran on every layout pass: `-setText:` invalidates the label's layout and
        // `-bringSubviewToFront:` reorders this view's subviews, and each of those asks for
        // another layout pass, which arrives here and does both again. A loop on the main
        // thread inside the player — the second of the two in this file that kept YouTube
        // sitting on its own logo.
        //
        // A clock time changes once a minute, so the comparison is nearly always the answer,
        // and the button below is added last anyway.
        if (![label.text isEqualToString:text]) label.text = text;
        if (self.subviews.lastObject != label) [self bringSubviewToFront:label];
    } @catch (NSException *exception) {
        SCILogV(@"overlay: end time — %@", exception.reason);
    }
}

%end

%end


%ctor {
    // Bound by name rather than by scanning. The reels button broke for a whole release
    // because a search over objc_copyClassList replaced a name that objc_getClass still
    // answered to -- a search is a fallback for an unknown name, never a replacement for a
    // known one.
    if (NSClassFromString(@"YTMainAppControlsOverlayView")) {
        %init(SCIOverlayTop);
    } else {
        SCILogV(@"overlay: YTMainAppControlsOverlayView is not in this build");
    }

    // The quality label follows what the person picks. Each controller is bound only where it declares the call with the encoding
    // this was written against (`v32@0:8@16@24`, read from 21.41.5): a build that renames it costs the label its updates, not the app.
    struct { const char *name; BOOL redesigned; } sheets[] = { { "YTVideoQualitySwitchOriginalController", NO }, { "YTVideoQualitySwitchRedesignedController", YES } };
    for (size_t i = 0; i < sizeof(sheets) / sizeof(sheets[0]); i++) {
        Class cls = NSClassFromString(@(sheets[i].name));
        Method method = cls ? class_getInstanceMethod(cls, @selector(singleVideo:didSelectVideoFormat:)) : NULL;
        const char *types = method ? method_getTypeEncoding(method) : NULL;
        if (!types || strcmp(types, "v32@0:8@16@24") != 0) {
            SCILogV(@"overlay: %s -singleVideo:didSelectVideoFormat: is not in this build as expected", sheets[i].name);
            continue;
        }
        if (sheets[i].redesigned) { %init(SCIQualityRedesigned); } else { %init(SCIQualityOriginal); }
    }

    if (NSClassFromString(@"YTInlinePlayerBarContainerView")) {
        %init(SCIOverlayBottom);
    } else {
        SCILogV(@"overlay: YTInlinePlayerBarContainerView is not in this build");
    }
}
