#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "SCITTGesture.h"
#import "SCITTStatus.h"
#import "SCITTSettingsEntry.h"
#import "../Prefs.h"
#import "../UI/SCITTWelcome.h"
#import "../SCILog.h"

///
/// Two fingers, held. The same technique Locket's own gesture uses, for the same
/// reason: attached to the app's own window rather than to any one screen, since a
/// window lives for the whole app and every screen sits inside it.
///

@interface SCITTGestureTarget : NSObject
+ (instancetype)shared;
- (void)fired:(UILongPressGestureRecognizer *)recogniser;
@end

@implementation SCITTGestureTarget

+ (instancetype)shared {
    static SCITTGestureTarget *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[SCITTGestureTarget alloc] init]; });
    return shared;
}

- (void)fired:(UILongPressGestureRecognizer *)recogniser {
    if (recogniser.state != UIGestureRecognizerStateBegan) return;

    // A choice, off by default. Two exceptions, both so the settings are never unreachable: the row in TikTok's
    // Settings is not installed in this build, or the tweak is switched off for the app (the panel is where it is
    // switched back on, and a hold is how this screen is reached from there).
    BOOL wanted = [[NSUserDefaults standardUserDefaults] boolForKey:SCIPrefGestureOpen];
    if (!wanted && SCIPanelAllowsThisApp() && SCITTSettingsEntryInstalled()) return;
    [SCITTStatus present];
}

@end


static void SCITTAttachGesture(UIWindow *window) {
    if (!window) return;

    static const char *marker = "SCITTGesture";
    if (objc_getAssociatedObject(window, marker)) return;
    objc_setAssociatedObject(window, marker, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UILongPressGestureRecognizer *hold =
        [[UILongPressGestureRecognizer alloc] initWithTarget:[SCITTGestureTarget shared]
                                                      action:@selector(fired:)];
    hold.numberOfTouchesRequired = 2;
    hold.minimumPressDuration = 0.65;

    // Without this every touch this watches is delayed while it decides, and it never
    // cancels TikTok's own gestures underneath it.
    hold.cancelsTouchesInView = NO;
    hold.delaysTouchesBegan = NO;
    hold.delaysTouchesEnded = NO;

    [window addGestureRecognizer:hold];
    SCILogV(@"gesture attached to %@", window);

    // **The welcome screen rides on this hook rather than adding one of its own.** It needs exactly
    // what the gesture needs -- a real window, once, at launch -- and a second `%hook UIWindow` for
    // the same moment would be two things to keep in step for no gain.
    //
    // Delayed, because a window becoming key is the start of TikTok putting its own screen up, not
    // the end: appearing in the middle of that is how a first-run screen ends up behind a splash.
    // The screen decides for itself whether it has ever been shown.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [SCITTWelcome showIfNeeded];
    });
}


%group Gesture

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    SCITTAttachGesture(self);
}

%end

%end


void SCITTInstallGesture(void) {
    %init(Gesture);
}
