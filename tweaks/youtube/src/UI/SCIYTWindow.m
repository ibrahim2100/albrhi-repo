#import "SCIYTWindow.h"

UIWindow *SCIYTKeyWindow(void) {
    UIApplication *application = [UIApplication sharedApplication];

    for (UIScene *scene in application.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isKeyWindow) return window;
        }
    }

    // Before a scene has any, or in a process that never adopted scenes.
    for (UIWindow *window in application.windows) {
        if (window.isKeyWindow) return window;
    }
    return nil;
}

UIViewController *SCIYTRootViewController(void) {
    return SCIYTKeyWindow().rootViewController;
}

UIViewController *SCIYTTopViewController(void) {
    UIViewController *top = SCIYTRootViewController();
    while (top.presentedViewController && !top.presentedViewController.isBeingDismissed) {
        top = top.presentedViewController;
    }
    return top;
}
