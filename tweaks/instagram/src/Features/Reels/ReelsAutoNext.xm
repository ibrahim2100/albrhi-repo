#import <substrate.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../../SCILog.h"
#import "../../Localization/SCILocalize.h"
#import "../../Settings/SCIDiagnosticsViewController.h"
#import "../../Compat/SCIResolve.h"

///
/// Auto-advance to the next reel — across Instagram versions.
///
/// Walking the class metadata of the real 410 and 439 binaries showed the whole
/// picture. IGSundialFeedViewController carries its own auto-scroll machinery, and
/// which gate actually decides it differs by build:
///
///   -isAutoAdvanceEnabled / -autoAdvanceToNextItem   both     state getters
///   -shouldForceEnableAutoScroll                     439      Swift-engine override
///   -autoScrollState                                 410      old feed getter
///   -_isAutoScrollingBlocked                         410      the real blocker
///   -_shouldAutoScrollToObject:exclusionRule:        410      the real decision
///   -advanceToNextItemDisabled                       439      a disable flag
///
/// Forcing only the state getters (the earlier tries) was not enough on 410, where
/// the timer already runs and simply refuses to advance because -_isAutoScrollingBlocked
/// says so and -_shouldAutoScrollToObject: returns NO. Those two are the ones that
/// were missing. Every gate is now driven to the value that means "yes, advance",
/// each behind a guard so a build without it is skipped, never handed a dead method.
///
/// Gate names came from RyukGram (github.com/faroukbmiled/RyukGram, GPLv3), which
/// ships one build per Instagram version; here a single build carries them all and
/// the guard picks. The mechanism is Albrhi's own.
///
/// No on-screen button — toggled from Reels settings — so the reels action bar and
/// its download button stay where Instagram puts them.
///

static BOOL SCIWantsAutoScroll(void) {
    return [SCIUtils getBoolPref:@"reels_auto_next"];
}

// MARK: - Argument-less gates

// A gate is a zero-argument BOOL getter. Each is driven to a fixed value while the
// feature is on — YES for an "enabled/should" gate, NO for a "blocked/disabled" one
// — and left to answer for itself when off, so nothing changes with the toggle down.
#define SCI_MAX_GATES 12
static struct { Class cls; SEL selector; IMP original; BOOL forced; } sGates[SCI_MAX_GATES];
static size_t sGateCount = 0;

static BOOL SCIGateTrampoline(id self, SEL _cmd) {
    for (size_t i = 0; i < sGateCount; i++) {
        if (sGates[i].selector == _cmd && [self isKindOfClass:sGates[i].cls]) {
            if (SCIWantsAutoScroll()) return sGates[i].forced;
            return sGates[i].original ? ((BOOL (*)(id, SEL))sGates[i].original)(self, _cmd) : NO;
        }
    }
    return NO;
}

static void SCIForceGate(Class cls, NSString *name, BOOL forced) {
    if (!cls || sGateCount >= SCI_MAX_GATES) return;

    SEL selector = NSSelectorFromString(name);
    if (!selector || !class_getInstanceMethod(cls, selector)) return;

    IMP original = NULL;
    MSHookMessageEx(cls, selector, (IMP)SCIGateTrampoline, &original);
    if (!original) return;

    sGates[sGateCount].cls = cls;
    sGates[sGateCount].selector = selector;
    sGates[sGateCount].original = original;
    sGates[sGateCount].forced = forced;
    sGateCount++;
}

// MARK: - The two-argument decision gate

// -_shouldAutoScrollToObject:exclusionRule: is where 410 finally decides. It takes
// arguments, so it needs its own trampoline: the generic one would drop them and
// corrupt the passthrough while the feature is off.
static BOOL (*orig_shouldAutoScrollToObject)(id, SEL, id, NSUInteger);
static BOOL sci_shouldAutoScrollToObject(id self, SEL _cmd, id object, NSUInteger rule) {
    if (SCIWantsAutoScroll()) return YES;
    return orig_shouldAutoScrollToObject ? orig_shouldAutoScrollToObject(self, _cmd, object, rule) : NO;
}

%ctor {
    @autoreleasepool {
        Class feed = objc_getClass("IGSundialFeedViewController");
        Class engine = SCIResolveClassWithHint(@"IGSundialAutoScroll",
            @"_TtC19IGSundialAutoScroll19IGSundialAutoScroll");

        // Enabled/should gates → YES.
        SCIForceGate(feed, @"isAutoAdvanceEnabled", YES);
        SCIForceGate(feed, @"autoAdvanceToNextItem", YES);
        SCIForceGate(feed, @"autoScrollState", YES);                // 410
        SCIForceGate(feed, @"_shouldAutoScrollAfterSwipeBack", YES); // 410
        SCIForceGate(engine, @"shouldForceEnableAutoScroll", YES);  // 439
        SCIForceGate(engine, @"isAutoAdvanceEnabled", YES);

        // Blocked/disabled gates → NO.
        SCIForceGate(feed, @"_isAutoScrollingBlocked", NO);         // 410
        SCIForceGate(feed, @"advanceToNextItemDisabled", NO);       // 439

        // The two-argument decision, where present.
        SEL decision = NSSelectorFromString(@"_shouldAutoScrollToObject:exclusionRule:");
        if (feed && class_getInstanceMethod(feed, decision)) {
            MSHookMessageEx(feed, decision,
                            (IMP)sci_shouldAutoScrollToObject,
                            (IMP *)&orig_shouldAutoScrollToObject);
        }

        [SCIDiagnostics recordReelsGatesForced:(NSInteger)sGateCount];
        SCILogV(@"[Albrhi] reels auto-scroll gates forced: %zu", sGateCount);
    }
}

// MARK: - On-screen toggle

// An optional button that turns auto-scroll on and off without a trip to settings.
//
// It is a floating overlay on the reels view controller — pinned to the trailing
// edge with constraints — not a member of Instagram's action bar. An earlier try
// added it into the sidebar, where it fought the download button's own layout hook
// for the same bar and, on a build whose bar is a different class, never appeared at
// all. Sitting on the view controller sidesteps both: it always shows, holds its
// place as reels scroll underneath, and never touches the action bar.

static const NSInteger SCIAutoScrollButtonTag = 0x5CA57;

static void SCIStyleAutoScrollButton(UIButton *button) {
    BOOL on = SCIWantsAutoScroll();
    NSString *glyph = on ? @"infinity.circle.fill" : @"infinity.circle";

    UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:17.0 weight:UIImageSymbolWeightSemibold];
    [button setImage:[UIImage systemImageNamed:glyph withConfiguration:config] forState:UIControlStateNormal];

    button.tintColor = on ? [SCIUtils SCIColor_Primary] : [UIColor whiteColor];
    button.accessibilityLabel = SCILocalized(@"p_reels_autonext_t");
}

%hook IGSundialFeedViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    if (![SCIUtils getBoolPref:@"reels_autoscroll_button"]) {
        [[self.view viewWithTag:SCIAutoScrollButtonTag] removeFromSuperview];
        return;
    }
    if ([self.view viewWithTag:SCIAutoScrollButtonTag]) return;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tag = SCIAutoScrollButtonTag;
    button.translatesAutoresizingMaskIntoConstraints = NO;

    // A dark disc so the glyph stays legible over any reel.
    button.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.35];
    button.layer.cornerRadius = 17.0;

    SCIStyleAutoScrollButton(button);
    [button addTarget:self action:@selector(sciToggleAutoScroll:) forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:button];

    // Upper-right, below the camera row and well above the like button at the top of
    // the action stack — the earlier centre placement landed right on the like.
    [NSLayoutConstraint activateConstraints:@[
        [button.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-14.0],
        [button.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:104.0],
        [button.widthAnchor constraintEqualToConstant:34.0],
        [button.heightAnchor constraintEqualToConstant:34.0]
    ]];
}

%new(v@:@) - (void)sciToggleAutoScroll:(UIButton *)sender {
    BOOL next = !SCIWantsAutoScroll();
    [[NSUserDefaults standardUserDefaults] setBool:next forKey:@"reels_auto_next"];

    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
    SCIStyleAutoScrollButton(sender);

    [SCIUtils showToastForDuration:1.6
                             title:SCILocalized(next ? @"reels_autonext_on" : @"reels_autonext_off")];
}

%end

// MARK: - Duration-aware drive from the progress indicator

// Forcing the gates does not start the older build's auto-scroll timer, and the
// countdown callback that would have fed it is itself gated off. The progress
// indicator is not: it updates continuously as the reel plays, on both builds, so it
// is the one reliable "the reel is ending" signal. When progress reaches the end the
// feed controller is told to advance, once per play — Instagram's own advance, so the
// transition is the native one.

// Which build this is, decided by a method only the older one has. The older build
// is the one this feature is confirmed working on, so everything added for the newer
// one is kept behind this test and cannot change what already works.
static BOOL SCIIsLegacyBuild(void) {
    static BOOL legacy = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class feed = objc_getClass("IGSundialFeedViewController");
        legacy = feed && class_getInstanceMethod(feed, @selector(advanceToNextReelForAutoScroll)) != NULL;
    });
    return legacy;
}

// The feed controller this cell belongs to, found up the responder chain.
static UIViewController *SCIFeedControllerForView(UIView *view) {
    Class feed = objc_getClass("IGSundialFeedViewController");
    UIResponder *responder = view;
    while ((responder = responder.nextResponder)) {
        if (feed && [responder isKindOfClass:feed]) return (UIViewController *)responder;
    }
    return nil;
}

// The scrolling view the reels are paged in, for the fallback below.
static UIScrollView *SCIEnclosingScrollView(UIView *view) {
    UIView *parent = view.superview;
    while (parent) {
        if ([parent isKindOfClass:[UIScrollView class]]) return (UIScrollView *)parent;
        parent = parent.superview;
    }
    return nil;
}

// One "already advanced this play" flag per reporter, cleared when the reel loops
// back to the start, so each play triggers exactly one advance.
static const void *SCIReelAdvancedKey = &SCIReelAdvancedKey;

// The previous progress reading, kept so a wrap back to the start can be told from
// an ordinary early-in-the-reel update.
static const void *SCIReelLastFractionKey = &SCIReelLastFractionKey;

// A second guard across reporters. On the newer build two objects report progress
// for the same reel, and without this each would advance — one skipped reel per
// tick. Not needed on the older build, where only the cell reports, so its timing
// is unaffected either way.
static NSTimeInterval sLastAdvance = 0;

static void SCIReelProgressTick(UIView *reporter, double progress, double remaining, double total) {
    if (!SCIWantsAutoScroll()) return;

    // Recorded before any threshold, so Diagnostics can say whether this fires at
    // all and how far progress actually gets — the two things guesswork got wrong.
    [SCIDiagnostics recordReelsProgress:progress total:total from:NSStringFromClass([reporter class])];

    // Progress is reported 0–1 on the builds measured, but a build reporting 0–100
    // would otherwise trip the end test on the first update and skip instantly.
    double fraction = progress > 1.5 ? progress / 100.0 : progress;

    // How near the end, in seconds. A percentage cannot answer this: the same 3%
    // short of the end is under a second on a short reel and nearly two on a long
    // one, which is exactly how the first version came to cut clips off early.
    // Instagram reports the remaining time itself; it is only derived when that
    // reading is missing or nonsensical.
    double secondsLeft = remaining;
    if (secondsLeft <= 0.0 || secondsLeft > total) secondsLeft = total * (1.0 - fraction);

    double previous = [objc_getAssociatedObject(reporter, SCIReelLastFractionKey) doubleValue];
    objc_setAssociatedObject(reporter, SCIReelLastFractionKey, @(fraction), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // The reel has looped back to the start, which is the only proof that it played
    // the whole way through. This is the trigger: anything based on being *near* the
    // end moves while the reel is still playing, and a quarter second of a clip cut
    // off is still a clip cut off — which is exactly what kept being reported.
    BOOL wrapped = (previous > 0.9 && fraction < 0.1);

    if (!wrapped) {
        // Early in the reel: arm for the coming end.
        if (fraction < 0.5) {
            objc_setAssociatedObject(reporter, SCIReelAdvancedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return;
        }

        // Not looped yet. The tiny remaining-time window below is only a safety net
        // for a build that stops reporting at the end instead of wrapping; at five
        // hundredths of a second it cannot cut anything short that a viewer would
        // notice. The total guards against zero-length or still-loading items
        // reading as finished the moment they appear.
        if (secondsLeft > 0.05 || total < 0.3) return;
    }

    if (objc_getAssociatedObject(reporter, SCIReelAdvancedKey)) return;

    objc_setAssociatedObject(reporter, SCIReelAdvancedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (now - sLastAdvance < 0.8) return;
    sLastAdvance = now;

    UIViewController *feed = SCIFeedControllerForView(reporter);

    // -scrollToNextItemAnimated: is the plain scroll both builds have, and is what
    // Instagram's own interaction coordinator calls to move on. The auto-scroll
    // advance was tried first and did nothing on the older build, which suggests it
    // is gated behind the same rollout this feature exists to bypass; a direct
    // scroll is not.
    NSString *used = nil;
    if ([feed respondsToSelector:@selector(scrollToNextItemAnimated:)]) {
        used = @"scrollToNextItemAnimated:";
    } else if ([feed respondsToSelector:@selector(advanceToNextReelForAutoScroll)]) {
        used = @"advanceToNextReelForAutoScroll";
    }

    [SCIDiagnostics recordReelsAdvance:used foundController:(feed != nil)];

    UIScrollView *pager = SCIEnclosingScrollView(reporter);

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!SCIWantsAutoScroll()) return;

        CGPoint before = pager ? pager.contentOffset : CGPointZero;

        if (feed && [used isEqualToString:@"scrollToNextItemAnimated:"]) {
            ((void (*)(id, SEL, BOOL))objc_msgSend)(feed, @selector(scrollToNextItemAnimated:), YES);
        } else if (feed && used) {
            ((void (*)(id, SEL))objc_msgSend)(feed, @selector(advanceToNextReelForAutoScroll));
        }

        // Ask afterwards whether it actually moved, and page the scroll view by hand
        // if it did not. Only on the newer build: the older one moves, so this never
        // runs there and cannot disturb it. This is the same "measure the result
        // rather than assume it" the rest of this file had to learn.
        if (SCIIsLegacyBuild() || !pager) return;

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (!SCIWantsAutoScroll()) return;
            if (fabs(pager.contentOffset.y - before.y) > 1.0) return;   // it moved

            CGFloat page = pager.bounds.size.height;
            CGFloat limit = pager.contentSize.height - page;
            if (page < 1.0 || before.y + page > limit + 1.0) return;

            [SCIDiagnostics recordReelsAdvance:@"manual page scroll" foundController:(feed != nil)];
            [pager setContentOffset:CGPointMake(before.x, before.y + page) animated:YES];
        });
    });
}

%hook IGSundialViewerVideoCell

- (void)updateProgressIndicatorWithProgress:(double)progress
                          remainingDuration:(double)remaining
                            elapsedDuration:(double)elapsed
                              totalDuration:(double)total {
    %orig;

    SCIReelProgressTick((UIView *)self, progress, remaining, total);
}

%end

// MARK: - The newer build's second reporter

// On the newer build the video cell alone did not carry this, so the Swift controls
// overlay — which reports the same progress and exists on both — is hooked as well.
// Installed only there: on the older build the cell is proven and adding a second
// reporter could only change timing that already works.
typedef void (*SCIProgressIMP)(id, SEL, double, double, double, double);

// One original per class. Each of these carries its own implementation of the
// method, so a single shared slot would run another class's body on this instance
// for whichever was hooked second.
#define SCI_MAX_PROGRESS_HOOKS 4
static struct { Class cls; SCIProgressIMP original; } sProgressHooks[SCI_MAX_PROGRESS_HOOKS];
static size_t sProgressHookCount = 0;

static void sci_overlayProgress(id self, SEL _cmd, double progress, double remaining,
                                double elapsed, double total) {
    for (size_t i = 0; i < sProgressHookCount; i++) {
        if ([self isKindOfClass:sProgressHooks[i].cls] && sProgressHooks[i].original) {
            sProgressHooks[i].original(self, _cmd, progress, remaining, elapsed, total);
            break;
        }
    }

    if ([self isKindOfClass:[UIView class]]) {
        SCIReelProgressTick((UIView *)self, progress, remaining, total);
    }
}

%ctor {
    @autoreleasepool {
        if (SCIIsLegacyBuild()) return;

        SEL progress = NSSelectorFromString(@"updateProgressIndicatorWithProgress:remainingDuration:elapsedDuration:totalDuration:");

        // Each name with the Swift runtime name we already knew for it, where there is one.
        //
        // This block was the worse half of the same mistake as the reels button: the array
        // was changed from mangled names to plain ones and a comment was written saying the
        // resolver would find them -- while the lookup below stayed objc_getClass. A plain
        // name for a Swift class finds nothing, on any build, so the progress hook simply
        // stopped attaching and said so nowhere. The comment described the change; the code
        // did not have it.
        NSArray<NSArray<NSString *> *> *candidates = @[
            @[@"IGSundialViewerControlsOverlayView",
              @"_TtC30IGSundialViewerControlsOverlay34IGSundialViewerControlsOverlayView"],
            @[@"IGSundialViewerCarouselCell", @""],
        ];

        for (NSArray<NSString *> *candidate in candidates) {
            if (sProgressHookCount >= SCI_MAX_PROGRESS_HOOKS) break;

            NSString *name = candidate[0];
            NSString *hint = candidate[1].length ? candidate[1] : nil;

            Class cls = SCIResolveClassWithHint(name, hint);
            if (!cls || !class_getInstanceMethod(cls, progress)) continue;

            IMP previous = NULL;
            MSHookMessageEx(cls, progress, (IMP)sci_overlayProgress, &previous);
            if (!previous) continue;

            sProgressHooks[sProgressHookCount].cls = cls;
            sProgressHooks[sProgressHookCount].original = (SCIProgressIMP)previous;
            sProgressHookCount++;
        }
    }
}
