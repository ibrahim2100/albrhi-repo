//
//  main.m -- a throwaway simulator app that shows Albrhi's REAL Settings panel (tweaks/panel) so it can be looked at from this machine.
//
//  The panel is a Preferences bundle: Settings loads it and asks for `SCIPanelRootController`. This does the same thing in a plain app --
//  loads the bundle built by build.sh from a folder laid out like a jailbreak (Library/PreferenceBundles, Library/MobileSubstrate,
//  Library/dpkg), so the panel's own prefix logic finds its filters and its installed version exactly as it does on a phone -- and
//  pushes the controller into a navigation controller.
//
//  **What is real and what is not.** Real: every row, string, colour and layout of the panel, drawn by the panel's own code through the
//  simulator's own Preferences.framework. Not real: *which apps are installed* (the simulator has only TikTok from this project's set, so
//  the harness answers LSApplicationWorkspace with stand-in apps and their versions, and a stand-in has no icon), and Settings' own chrome.
//
//  Launch arguments:  -bundle <absolute path of AlbrhiPanel.bundle>   [-fakeapps NO]   [-push <inner page class>]   [-AppleLanguages (ar)]
//
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>

@interface HarnessProxy : NSObject
@property (nonatomic, copy) NSString *applicationIdentifier, *localizedName, *bundleExecutable, *shortVersionString;
@end
@implementation HarnessProxy
+ (instancetype)id:(NSString *)identifier name:(NSString *)name version:(NSString *)version executable:(NSString *)executable {
    HarnessProxy *proxy = [[HarnessProxy alloc] init];
    proxy.applicationIdentifier = identifier; proxy.localizedName = name; proxy.shortVersionString = version; proxy.bundleExecutable = executable;
    return proxy;
}
@end

static NSArray *HarnessApps(void) {
    return @[
        [HarnessProxy id:@"com.burbn.instagram" name:@"Instagram" version:@"441.0.3" executable:@"Instagram"],
        [HarnessProxy id:@"com.google.ios.youtube" name:@"YouTube" version:@"21.41.5" executable:@"YouTube"],
        [HarnessProxy id:@"com.atebits.Tweetie2" name:@"X" version:@"12.20" executable:@"Twitter"],
        [HarnessProxy id:@"com.zhiliaoapp.musically" name:@"TikTok" version:@"47.1.0" executable:@"TikTok"],
        [HarnessProxy id:@"com.google.ios.youtubemusic" name:@"YT Music" version:@"8.10.2" executable:@"YouTubeMusic"],
        [HarnessProxy id:@"com.spotify.client" name:@"Spotify" version:@"9.0.0" executable:@"Spotify"],
    ];
}

@interface HarnessDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIViewController *root;
@end

@implementation HarnessDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    // Settings' own framework, from the simulator runtime, before the bundle: the bundle's superclass is bound at load.
    void *preferences = dlopen("/System/Library/PrivateFrameworks/Preferences.framework/Preferences", RTLD_NOW);
    NSLog(@"[PanelHarness] Preferences.framework: %@", preferences ? @"loaded" : @"NOT loaded");

    if (![defaults objectForKey:@"fakeapps"] || [defaults boolForKey:@"fakeapps"]) {
        Class workspace = NSClassFromString(@"LSApplicationWorkspace");
        Method original = workspace ? class_getInstanceMethod(workspace, NSSelectorFromString(@"allInstalledApplications")) : NULL;
        if (original) method_setImplementation(original, imp_implementationWithBlock(^NSArray *(id self_) { return HarnessApps(); }));
    }

    NSString *path = [defaults stringForKey:@"bundle"];
    NSBundle *bundle = path ? [NSBundle bundleWithPath:path] : nil;
    NSError *error = nil;
    BOOL loaded = bundle && [bundle loadAndReturnError:&error];
    NSLog(@"[PanelHarness] bundle %@: %@ %@", path, loaded ? @"loaded" : @"NOT loaded", error ?: @"");

    Class root = NSClassFromString(@"SCIPanelRootController");
    UIViewController *controller = root ? [[root alloc] init] : [[UIViewController alloc] init];
    if (!root) controller.view.backgroundColor = [UIColor systemRedColor];

    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:controller];
    navigation.navigationBar.prefersLargeTitles = YES;

    // -push <ClassName>: open one of the panel's inner pages straight away (SCIPanelGuideController, SCISpotifySettingsController...).
    Class inner = NSClassFromString([defaults stringForKey:@"push"] ?: @"");
    if (inner) [navigation pushViewController:[[inner alloc] init] animated:NO];

    self.root = navigation;
    return YES;
}
@end

/// Current UIKit refuses an app that has no scene (the crash is `UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption`), so the window
/// is made here, from the scene, with the controller the app delegate built.
@interface HarnessScene : UIResponder <UIWindowSceneDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
@implementation HarnessScene
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    HarnessDelegate *delegate = (HarnessDelegate *)[UIApplication sharedApplication].delegate;
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.rootViewController = delegate.root;
    [self.window makeKeyAndVisible];
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass([HarnessDelegate class])); }
}
