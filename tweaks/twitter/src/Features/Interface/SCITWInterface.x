#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <string.h>
#import "SCITWInterface.h"
#import "Prefs.h"
#import "SCILog.h"

// Declared because each hook below sends `self` messages, and a forward declaration cannot be
// sent any (rule 3 in tools/check.py).
@interface TFNFloatingActionButton : UIView
@end

@interface T1TabView : UIView
@end

@interface _TtC14T1TwitterSwift28GuideContainerViewController : UIViewController
@end

static NSMutableDictionary<NSString *, NSNumber *> *sciIFAttached = nil;
static NSMutableDictionary<NSString *, NSNumber *> *sciIFHits = nil;

static BOOL SCITWIFPref(NSString *key) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

static void SCITWIFHit(NSString *name) {
    sciIFHits[name] = @(sciIFHits[name].unsignedIntegerValue + 1);
}

/// All or nothing: the class answers every selector with exactly this encoding, as an instance
/// or class method. A group whose method is missing would *add* it.
static BOOL SCITWIFAnswers(NSString *className, NSArray<NSArray *> *specs) {
    Class cls = NSClassFromString(className);
    if (!cls) return NO;

    for (NSArray *spec in specs) {
        BOOL classMethod = [spec[2] boolValue];
        SEL selector = NSSelectorFromString(spec[0]);
        Method method = classMethod ? class_getClassMethod(cls, selector) : class_getInstanceMethod(cls, selector);
        if (!method) return NO;

        const char *encoding = method_getTypeEncoding(method);
        if (!encoding || strcmp(encoding, [spec[1] UTF8String]) != 0) return NO;
    }
    return YES;
}

static NSArray *SCITWIFInstance(NSString *selector, NSString *encoding) { return @[selector, encoding, @NO]; }
static NSArray *SCITWIFClassM(NSString *selector, NSString *encoding) { return @[selector, encoding, @YES]; }


// MARK: - The floating compose button

%group ComposeButton

%hook TFNFloatingActionButton

- (void)didMoveToWindow {
    %orig;
    if (!SCITWIFPref(SCIPrefHideCompose)) return;

    self.userInteractionEnabled = NO;
    self.hidden = YES;
    self.alpha = 0.0;
    SCITWIFHit(@"compose button");
}

%end

%end


// MARK: - The tab bar that slides away

// The scroll-driven hide only reaches the tab bar as a collapse ratio, so clamping that one
// number spares the deliberate hides (full-screen media, the immersive player).
%group KeepTabBar

%hook T1TabBarViewController

- (void)setTabBarCollapseRatio:(double)ratio {
    double wanted = SCITWIFPref(SCIPrefKeepTabBar) ? 0.0 : ratio;
    %orig(wanted);
}

%end

%end


// MARK: - Tab labels

%group TabLabels

%hook T1TabView

- (BOOL)showsTitleInDisplayMode:(long long)mode {
    BOOL shows = %orig;
    if (SCITWIFPref(SCIPrefTabLabels)) shows = YES;
    return shows;
}

- (void)didMoveToWindow {
    %orig;
    if (!self.window || !SCITWIFPref(SCIPrefTabLabels)) return;

    SEL layout = NSSelectorFromString(@"_t1_layoutForTabBar");
    if ([self respondsToSelector:layout]) {
        ((void (*)(id, SEL))objc_msgSend)(self, layout);
        SCITWIFHit(@"tab labels");
    }
}

%end

%end


// MARK: - The scroll indicator

%group ScrollIndicator

%hook TFSAccountFeatureSwitches

+ (BOOL)isShowsVerticalScrollIndicatorEnabled {
    BOOL answer = %orig;
    if (SCITWIFPref(SCIPrefScrollIndicator)) answer = YES;
    return answer;
}

%end

%end


// MARK: - Full-quality photos

%group HighQualityImages

%hook T1ImageDisplayView

- (BOOL)_tfn_shouldUseHighestQualityImage {
    BOOL answer = %orig;
    if (SCITWIFPref(SCIPrefHighQualityImages)) answer = YES;
    return answer;
}

- (BOOL)_tfn_shouldUseHighQualityImage {
    BOOL answer = %orig;
    if (SCITWIFPref(SCIPrefHighQualityImages)) answer = YES;
    return answer;
}

%end

%end


// MARK: - The badge on a paying account

///
/// Written four times because the badge reads from four user models and from the status view
/// model's own cached copy. The author-row badge builds from the merged `verified` flag plus
/// an identity type and ignores `isBlueVerified`, so *both* getters are silenced; brand and
/// government badges are carried by the identity type, which is left alone, so they survive.
/// Which is the point: this hides what money bought, not what an organisation is.
///

%group BlueBadge

%hook TFSTwitterUser

- (id)isBlueVerified {
    id value = %orig;
    if (SCITWIFPref(SCIPrefHideBlueBadge)) value = nil;
    return value;
}

- (BOOL)verified {
    BOOL value = %orig;
    if (SCITWIFPref(SCIPrefHideBlueBadge)) value = NO;
    return value;
}

%end

%hook TFSTwitterUserSource

- (id)isBlueVerified {
    id value = %orig;
    if (SCITWIFPref(SCIPrefHideBlueBadge)) value = nil;
    return value;
}

- (BOOL)verified {
    BOOL value = %orig;
    if (SCITWIFPref(SCIPrefHideBlueBadge)) value = NO;
    return value;
}

%end

%hook TFSTwitterTypeaheadUser

- (id)isBlueVerified {
    id value = %orig;
    if (SCITWIFPref(SCIPrefHideBlueBadge)) value = nil;
    return value;
}

- (BOOL)verified {
    BOOL value = %orig;
    if (SCITWIFPref(SCIPrefHideBlueBadge)) value = NO;
    return value;
}

%end

%hook TFSDirectMessageUser

- (id)isBlueVerified {
    id value = %orig;
    if (SCITWIFPref(SCIPrefHideBlueBadge)) value = nil;
    return value;
}

- (BOOL)verified {
    BOOL value = %orig;
    if (SCITWIFPref(SCIPrefHideBlueBadge)) value = NO;
    return value;
}

%end

// A status view model caches these flags at init, beyond the user models above; the author
// row reads `isFromUserVerified`.
%hook T1TwitterCoreStatusViewModelAdapter

- (BOOL)isFromUserBlueVerified {
    BOOL value = %orig;
    if (SCITWIFPref(SCIPrefHideBlueBadge)) value = NO;
    return value;
}

- (BOOL)isFromUserVerified {
    BOOL value = %orig;
    if (SCITWIFPref(SCIPrefHideBlueBadge)) value = NO;
    return value;
}

%end

%end


// MARK: - The immersive player's dock

%group NoDocking

%hook T1ImmersiveViewController

- (BOOL)isCurrentCardDockEligible {
    BOOL answer = %orig;
    if (SCITWIFPref(SCIPrefNoDocking)) answer = NO;
    return answer;
}

%end

%end


// The same question on the controller newer builds introduced beside it. Not in X 12.20 at
// all (the class is absent there), which is exactly why it is its own group: attached where
// it exists with the encoding NeoFreeBird hooks it with, nowhere else.
%group NoDockingV2

%hook T1ImmersiveViewControllerV2

- (BOOL)isCurrentCardDockEligible {
    BOOL answer = %orig;
    if (SCITWIFPref(SCIPrefNoDocking)) answer = NO;
    return answer;
}

%end

%end


// MARK: - Follow beside every post

// The conversation's focal post and the immersive player both draw their author row through
// this view, so forcing the flag here covers both.
%group FollowOnPosts

%hook TTAStatusAuthorView

- (void)setFollowControlHidden:(BOOL)hidden {
    BOOL wanted = SCITWIFPref(SCIPrefHideFollowOnPosts) ? YES : hidden;
    %orig(wanted);
}

%end

%end


// MARK: - Trends under Explore

// The trending content lives in a child view controller whose property has no ObjC getter,
// so it is found among the children. The strip of page tabs arrives separately, through
// `-tfn_navigationBarAccessoryView`.
%group ExploreTrends

%hook _TtC14T1TwitterSwift28GuideContainerViewController

- (void)viewDidLoad {
    %orig;
    if (!SCITWIFPref(SCIPrefHideTrends)) return;

    Class chrome = NSClassFromString(@"_TtC14T1TwitterSwift23URTChromeViewController");
    if (!chrome) return;

    for (UIViewController *child in self.childViewControllers) {
        if ([child isKindOfClass:chrome]) {
            child.view.hidden = YES;
            SCITWIFHit(@"explore trends");
        }
    }
}

- (UIView *)tfn_navigationBarAccessoryView {
    UIView *view = %orig;
    if (SCITWIFPref(SCIPrefHideTrends)) view = nil;
    return view;
}

%end

%end


NSString *SCITWInterfaceReport(void) {
    if (!sciIFAttached.count) return @"interface: nothing was switched on when X opened";

    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSString *name in [sciIFAttached.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        NSUInteger hits = sciIFHits[name].unsignedIntegerValue;
        [parts addObject:[NSString stringWithFormat:@"%@ %@%@", name,
                          sciIFAttached[name].boolValue ? @"attached" : @"NOT attached (class or encoding differs)",
                          hits ? [NSString stringWithFormat:@" ×%lu", (unsigned long)hits] : @""]];
    }
    return [@"interface: " stringByAppendingString:[parts componentsJoinedByString:@" · "]];
}

void SCITWInstallInterface(void) {
    sciIFAttached = [NSMutableDictionary dictionary];
    sciIFHits = [NSMutableDictionary dictionary];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if ([defaults boolForKey:SCIPrefHideCompose]) {
        BOOL ok = SCITWIFAnswers(@"TFNFloatingActionButton", @[SCITWIFInstance(@"didMoveToWindow", @"v16@0:8")]);
        if (ok) { %init(ComposeButton); }
        sciIFAttached[@"compose button"] = @(ok);
    }

    if ([defaults boolForKey:SCIPrefKeepTabBar]) {
        BOOL ok = SCITWIFAnswers(@"T1TabBarViewController", @[SCITWIFInstance(@"setTabBarCollapseRatio:", @"v24@0:8d16")]);
        if (ok) { %init(KeepTabBar); }
        sciIFAttached[@"tab bar"] = @(ok);
    }

    if ([defaults boolForKey:SCIPrefTabLabels]) {
        BOOL ok = SCITWIFAnswers(@"T1TabView", @[SCITWIFInstance(@"showsTitleInDisplayMode:", @"B24@0:8q16"),
                                                SCITWIFInstance(@"_t1_layoutForTabBar", @"v16@0:8")]);
        if (ok) { %init(TabLabels); }
        sciIFAttached[@"tab labels"] = @(ok);
    }

    if ([defaults boolForKey:SCIPrefScrollIndicator]) {
        BOOL ok = SCITWIFAnswers(@"TFSAccountFeatureSwitches", @[SCITWIFClassM(@"isShowsVerticalScrollIndicatorEnabled", @"B16@0:8")]);
        if (ok) { %init(ScrollIndicator); }
        sciIFAttached[@"scroll indicator"] = @(ok);
    }

    if ([defaults boolForKey:SCIPrefHighQualityImages]) {
        BOOL ok = SCITWIFAnswers(@"T1ImageDisplayView", @[SCITWIFInstance(@"_tfn_shouldUseHighestQualityImage", @"B16@0:8"),
                                                          SCITWIFInstance(@"_tfn_shouldUseHighQualityImage", @"B16@0:8")]);
        if (ok) { %init(HighQualityImages); }
        sciIFAttached[@"full-quality photos"] = @(ok);
    }

    if ([defaults boolForKey:SCIPrefHideBlueBadge]) {
        NSArray *userPair = @[SCITWIFInstance(@"isBlueVerified", @"@16@0:8"), SCITWIFInstance(@"verified", @"B16@0:8")];
        BOOL ok = SCITWIFAnswers(@"TFSTwitterUser", userPair) &&
                  SCITWIFAnswers(@"TFSTwitterUserSource", userPair) &&
                  SCITWIFAnswers(@"TFSTwitterTypeaheadUser", userPair) &&
                  SCITWIFAnswers(@"TFSDirectMessageUser", userPair) &&
                  SCITWIFAnswers(@"T1TwitterCoreStatusViewModelAdapter",
                                 @[SCITWIFInstance(@"isFromUserBlueVerified", @"B16@0:8"),
                                   SCITWIFInstance(@"isFromUserVerified", @"B16@0:8")]);
        if (ok) { %init(BlueBadge); }
        sciIFAttached[@"paid badge"] = @(ok);
    }

    if ([defaults boolForKey:SCIPrefNoDocking]) {
        BOOL ok = SCITWIFAnswers(@"T1ImmersiveViewController", @[SCITWIFInstance(@"isCurrentCardDockEligible", @"B16@0:8")]);
        if (ok) { %init(NoDocking); }
        sciIFAttached[@"video dock"] = @(ok);

        // Only when the class is there: its absence is the normal case on older X, not a failure.
        if (NSClassFromString(@"T1ImmersiveViewControllerV2")) {
            BOOL v2 = SCITWIFAnswers(@"T1ImmersiveViewControllerV2", @[SCITWIFInstance(@"isCurrentCardDockEligible", @"B16@0:8")]);
            if (v2) { %init(NoDockingV2); }
            sciIFAttached[@"video dock (newer player)"] = @(v2);
        }
    }

    if ([defaults boolForKey:SCIPrefHideFollowOnPosts]) {
        BOOL ok = SCITWIFAnswers(@"TTAStatusAuthorView", @[SCITWIFInstance(@"setFollowControlHidden:", @"v20@0:8B16")]);
        if (ok) { %init(FollowOnPosts); }
        sciIFAttached[@"follow on posts"] = @(ok);
    }

    if ([defaults boolForKey:SCIPrefHideTrends]) {
        BOOL ok = SCITWIFAnswers(@"_TtC14T1TwitterSwift28GuideContainerViewController",
                                 @[SCITWIFInstance(@"viewDidLoad", @"v16@0:8"),
                                   SCITWIFInstance(@"tfn_navigationBarAccessoryView", @"@16@0:8")]);
        if (ok) { %init(ExploreTrends); }
        sciIFAttached[@"explore trends"] = @(ok);
    }

    SCILogV(@"%@", SCITWInterfaceReport());
}
