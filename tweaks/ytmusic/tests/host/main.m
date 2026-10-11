// The suite runs inside a real UIApplication (Mac Catalyst) so UIKit code
// under test — windows, display links, layout — behaves as on device.
#import <UIKit/UIKit.h>
#import "YTMUTestKit.h"
#import "YTMUTestSettings.h"

// Newer UIKit refuses to launch an app that has not adopted the scene life cycle ("UIScene life
// cycle is required for apps built with this SDK"). A scene with an empty window is all it asks for;
// the suite still runs from the application delegate, as before.
@interface YTMUTestSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation YTMUTestSceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    if (![scene isKindOfClass:[UIWindowScene class]]) return;
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
}
@end

@interface YTMUTestAppDelegate : UIResponder <UIApplicationDelegate>
@end

@implementation YTMUTestAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Kick the suite off from a run-loop timer rather than a main-queue
    // block: tests spin the run loop while waiting for completions that
    // arrive via dispatch_async(main), and the main queue is serial — it
    // would not drain those blocks while one of its own blocks (this one)
    // is still executing.
    [self performSelector:@selector(runSuite) withObject:nil afterDelay:0];
    return YES;
}

- (UISceneConfiguration *)application:(UIApplication *)application
    configurationForConnectingSceneSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    UISceneConfiguration *configuration = [[UISceneConfiguration alloc] initWithName:@"Default" sessionRole:session.role];
    configuration.delegateClass = [YTMUTestSceneDelegate class];
    return configuration;
}

- (void)runSuite {
    YTMUTestResetDefaultsDomain();
    NSUInteger failed = YTMUTestRunAll();
    YTMUTestResetDefaultsDomain();
    fflush(stdout);
    exit(failed ? 1 : 0);
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([YTMUTestAppDelegate class]));
    }
}
