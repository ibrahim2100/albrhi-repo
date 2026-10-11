#import "SCIYTDownloadCenter.h"
#import "SCIYTDownloadList.h"
#import "SCIYTCentrePage.h"
#import "SCIYTLibrary.h"
#import "../../../SCILog.h"
#import "../../../Localization/SCILocalize.h"
#import "../../../UI/SCIYTWindow.h"

@implementation SCIYTDownloadCenter

+ (void)present {
    UIViewController *top = SCIYTTopViewController();
    if (!top) {
        // No key window yet: the first one there is, as this lookup always allowed.
        top = [UIApplication sharedApplication].windows.firstObject.rootViewController;
        while (top.presentedViewController) top = top.presentedViewController;
    }
    if (!top) return;

    // Wrapped, the way the settings panel is. A screen of ours failing to build must be
    // a screen that does not open, never a crash inside YouTube.
    @try {
        [top presentViewController:[self build] animated:YES completion:nil];
    } @catch (NSException *exception) {
        SCILogV(@"centre: could not open — %@", exception.reason);
    }
}

/// The page as YouTube's own tabs have it: in the content area, under the bar.
///
/// Held so tapping away can take it down again, weakly -- YouTube owns it once it is a
/// child, and a strong reference here would outlive the screen it belongs to.
static __weak UIViewController *sciAttached = nil;

/// And the view separately, which is not the same thing.
///
/// A child view controller is retained by its parent; its view is retained by its superview.
/// Those are two different owners and they can let go at different times — if YouTube drops
/// the child while the view is still a subview, the controller deallocates, the weak pointer
/// above becomes nil, and the view is left on screen with nothing able to reach it. YouTube
/// then swaps tabs underneath it and every page looks the same, because the one on top never
/// moved.
///
/// That is the shape of "it sticks on one page", and one weak pointer more is the whole fix.
static __weak UIView *sciAttachedView = nil;

+ (BOOL)showInsidePivotBar:(UIViewController *)bar {
    if (!bar.view.superview) return NO;

    // The bar's own superview is the container both it and the content live in, so a page
    // added there is a sibling of the bar rather than something on top of it. Found this
    // way rather than by naming YouTube's container class: the arrangement is what matters
    // and it is visible from the bar, whereas the class name is a guess that would have to
    // be re-checked every release.
    UIView *container = bar.view.superview;

    UIViewController *host = bar.parentViewController;
    if (!host) return NO;

    [self removeFromPivotBar];

    SCIYTCentrePage *page = [[SCIYTCentrePage alloc] initWithDismissButton:NO];
    UINavigationController *wrapped =
        [[UINavigationController alloc] initWithRootViewController:page];

    [host addChildViewController:wrapped];
    wrapped.view.translatesAutoresizingMaskIntoConstraints = NO;

    // Below the bar in the stacking order, so the bar keeps its place on top and its
    // shadow falls the right way.
    [container insertSubview:wrapped.view belowSubview:bar.view];

    [NSLayoutConstraint activateConstraints:@[
        [wrapped.view.topAnchor constraintEqualToAnchor:container.topAnchor],
        [wrapped.view.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [wrapped.view.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [wrapped.view.bottomAnchor constraintEqualToAnchor:bar.view.topAnchor]
    ]];

    [wrapped didMoveToParentViewController:host];
    sciAttached = wrapped;
    sciAttachedView = wrapped.view;
    return YES;
}

+ (void)removeFromPivotBar {
    UIViewController *page = sciAttached;

    if (page) {
        [page willMoveToParentViewController:nil];
        [page.view removeFromSuperview];
        [page removeFromParentViewController];
    }

    // Even when the controller is gone. This is not belt and braces: the view outlives its
    // controller whenever the parent lets go first, and that leftover is the only thing that
    // can be on top of every YouTube page at once.
    [sciAttachedView removeFromSuperview];

    sciAttached = nil;
    sciAttachedView = nil;
}


+ (UIViewController *)build {
    // The same page the tab shows, with a way out added. One screen in two places rather
    // than two screens that drift apart -- the tab bar version and the settings version
    // were separate before, and only one of them ever got looked at.
    SCIYTCentrePage *page = [[SCIYTCentrePage alloc] initWithDismissButton:YES];

    UINavigationController *wrapped =
        [[UINavigationController alloc] initWithRootViewController:page];
    wrapped.modalPresentationStyle = UIModalPresentationPageSheet;
    return wrapped;
}

@end
