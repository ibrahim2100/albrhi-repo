//
//  SCITTKeyboard.x
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <string.h>
#import "SCITTKeyboard.h"
#import "../../Prefs.h"
#import "../../SCILog.h"

///
/// **A keyboard that is black, not dark grey, on an OLED screen.**
///
/// The system keyboard's backdrop is `UIKBBackdropView`, a private `UIView` subclass that is handed its colour through the ordinary
/// `-setBackgroundColor:` (`v24@0:8@16`, inherited from `UIView`; a subclass of the app's process sees every keyboard it shows). VibeTok (unlicensed;
/// architecture only, CLAUDE.md §2) replaces that colour only with one the person chose in its own colour picker, read from a defaults key it shares
/// with the author's Instagram tweak. Here there is no picker: **when the switch is on and the backdrop is in dark mode, the colour is black**, and
/// nothing else is touched. Light mode keeps the system's.
///
/// **The question is asked of the backdrop view's own traits, not of the global current trait collection** -- the latter is whatever the code
/// that called happens to be inside, and a keyboard can be dark while the app around it is not (a field with `keyboardAppearance` dark).
///
/// A **fresh switch is applied from the next time the keyboard draws**: the colour is only handed over when UIKit sets it.
///

@interface UIKBBackdropView : UIView
@end

static NSUInteger sciKeyboardSeen = 0, sciKeyboardBlack = 0;
static NSString *sciKeyboardState = nil;

%group SCITTKeyboardGroup
%hook UIKBBackdropView

- (void)setBackgroundColor:(UIColor *)color {
    sciKeyboardSeen++;
    if (SCIPrefEnabled(SCIPrefOLEDKeyboard) && self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        sciKeyboardBlack++;
        %orig([UIColor blackColor]);
        return;
    }
    %orig;
}

%end
%end

NSString *SCITTKeyboardReport(void) {
    return [NSString stringWithFormat:@"%@; backdrop colours set %lu, made black %lu",
            sciKeyboardState ?: @"not installed", (unsigned long)sciKeyboardSeen, (unsigned long)sciKeyboardBlack];
}

void SCITTInstallKeyboard(void) {
    Class backdrop = NSClassFromString(@"UIKBBackdropView");
    Method method = backdrop ? class_getInstanceMethod(backdrop, @selector(setBackgroundColor:)) : NULL;
    const char *types = method ? method_getTypeEncoding(method) : NULL;
    if (!types || strcmp(types, "v24@0:8@16") != 0) {
        sciKeyboardState = backdrop ? @"stood down: -setBackgroundColor: differently typed" : @"stood down: UIKBBackdropView absent";
        SCILogV(@"[Keyboard] %@", sciKeyboardState);
        return;
    }
    %init(SCITTKeyboardGroup);
    sciKeyboardState = @"installed: UIKBBackdropView -setBackgroundColor:";
    SCILogV(@"[Keyboard] %@", sciKeyboardState);
}
