#import "../../InstagramHeaders.h"
#import "../../Settings/SCISettingsViewController.h"
#import "../../SCILog.h"
#import "../../Compat/SCIResolve.h"

static NSString *const SCISettingsGestureName = @"com.albrhi.settings.longpress";

static BOOL SCIHasGestureNamed(UIView *view, NSString *name) {
    for (UIGestureRecognizer *gesture in view.gestureRecognizers) {
        if ([gesture.name isEqualToString:name]) return YES;
    }
    return NO;
}

// Show SCInsta tweak settings by holding on the settings/more icon under profile for ~1 second
%group SCIgIGBadgedNavigationButton

%hook IGBadgedNavigationButton
- (void)didMoveToWindow {
    %orig;

    if ([((IGBadgedNavigationButton *)self).accessibilityIdentifier isEqualToString:@"profile-more-button"]) {
        [self addLongPressGestureRecognizer];
    }

    return;
}

%new(v@:) - (void)addLongPressGestureRecognizer {
    if (SCIHasGestureNamed(self, SCISettingsGestureName)) return;

    SCILogV(@"[SCInsta] Adding tweak settings long press gesture recognizer");

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPress.name = SCISettingsGestureName;
    longPress.minimumPressDuration = 0.8;

    for (UIGestureRecognizer *existing in ((IGBadgedNavigationButton *)self).gestureRecognizers) {
        [existing requireGestureRecognizerToFail:longPress];
    }

    [self addGestureRecognizer:longPress];
}
%new(v@:@) - (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) return;
    
    SCILogV(@"[SCInsta] Tweak settings gesture activated");

    [SCIUtils showSettingsVC:[self window]];
}
%end

%end


// Quick access to tweak settings by holding on home tab button
%hook IGTabBarButton
- (void)didMoveToSuperview {
    %orig;

    // Only work on home/feed tab
    if (![self.accessibilityIdentifier isEqualToString:@"mainfeed-tab"]) return;
    
    if ([SCIUtils getBoolPref:@"settings_shortcut"]) {
        if (SCIHasGestureNamed(self, SCISettingsGestureName)) return;

        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        longPress.name = SCISettingsGestureName;
        longPress.minimumPressDuration = 0.3;
        
        // Take precidence over existing gesture recognizers
        for (UIGestureRecognizer *existing in self.gestureRecognizers) {
            [existing requireGestureRecognizerToFail:longPress];
        }
        
        [self addGestureRecognizer:longPress];
    }
}
%new(v@:@) - (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) return;

    [SCIUtils showSettingsVC:[self window]];
}
%end

%ctor {
    // The hooks outside the groups below. Logos writes this call itself for
    // a file with no %ctor -- and stops the moment there is one, so leaving
    // it out would silence every hook this file did not need to convert.
    %init;

    Class badgedNavigationButton = SCIResolveClass(@"IGBadgedNavigationButton");
    if (badgedNavigationButton) %init(SCIgIGBadgedNavigationButton, IGBadgedNavigationButton = badgedNavigationButton);
}
