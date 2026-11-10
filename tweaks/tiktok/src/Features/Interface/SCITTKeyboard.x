//
//  SCITTKeyboard.x
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
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
/// **"Dark" is asked three ways, and any one is enough** (0.29.1 -- the owner's phone said the first version did nothing). The first version asked only the
/// backdrop view's own traits, and a keyboard's backdrop does not always carry the dark style its keys are drawn in: UIKit gives a keyboard its look through
/// the field's `keyboardAppearance` and private styling, not necessarily through the view's trait collection. VibeTok asks the *current* trait collection
/// and the phone's own dark mode; so does this now: the view's traits, the trait collection of whoever is calling, and the screen's (the system's setting).
///
/// **And the colour is applied when the backdrop arrives in a window as well as when UIKit sets it**, because a colour set while the keyboard was being
/// built (before the switch was read) is never set again until the keyboard changes.
///

@interface UIKBBackdropView : UIView
@end

static NSUInteger sciKeyboardSeen = 0, sciKeyboardBlack = 0, sciKeyboardArrived = 0;

static BOOL SCITTKeyboardShouldBeBlack(UIView *backdrop) {
    if (!SCIPrefEnabled(SCIPrefOLEDKeyboard)) return NO;
    return backdrop.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
        || [UITraitCollection currentTraitCollection].userInterfaceStyle == UIUserInterfaceStyleDark
        || [UIScreen mainScreen].traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
}
static NSString *sciKeyboardState = nil;

/// **What a keyboard backdrop looks like on a phone, written down.** 0.29.1's own report said `backdrop colours set 10, made black 10` beside a keyboard
/// that stayed grey on the owner's iOS 16.1: the colour reaches the view and the view is not what is seen. Which layer is, is not knowable from this
/// machine (the simulator runs iOS 27, where the same code works), so the first few backdrops are described here -- own class, frame, colour, the
/// classes of its layers and views, its parents and its siblings -- and the next report names the one that is actually drawn.
static NSMutableArray<NSString *> *sciKeyboardShapes = nil;

static NSString *SCITTKeyboardShapeOf(UIView *view) {
    NSMutableArray<NSString *> *layers = [NSMutableArray array];
    for (CALayer *layer in view.layer.sublayers) {
        if (layers.count >= 8) break;
        NSString *name = NSStringFromClass([layer class]);
        if (layer.filters.count) name = [name stringByAppendingFormat:@"(filters %lu)", (unsigned long)layer.filters.count];
        if (layer.compositingFilter) name = [name stringByAppendingString:@"(composited)"];
        [layers addObject:name];
    }
    NSMutableArray<NSString *> *views = [NSMutableArray array];
    for (UIView *sub in view.subviews) {
        if (views.count >= 8) break;
        [views addObject:NSStringFromClass([sub class])];
    }
    NSMutableArray<NSString *> *parents = [NSMutableArray array];
    NSMutableArray<NSString *> *siblings = [NSMutableArray array];
    UIView *parent = view.superview;
    for (NSInteger i = 0; parent && i < 4; i++, parent = parent.superview) {
        [parents addObject:NSStringFromClass([parent class])];
        if (i == 0) {
            for (UIView *sibling in parent.subviews) {
                if (siblings.count >= 8) break;
                [siblings addObject:sibling == view ? @"[this]" : NSStringFromClass([sibling class])];
            }
        }
    }
    CGRect frame = view.frame;
    return [NSString stringWithFormat:@"%@ %.0fx%.0f at y %.0f, alpha %.2f, layer colour %@, layers [%@], views [%@], parents [%@], siblings [%@]",
            NSStringFromClass([view class]), frame.size.width, frame.size.height, frame.origin.y, view.alpha,
            view.layer.backgroundColor ? @"set" : @"none", [layers componentsJoinedByString:@", "], [views componentsJoinedByString:@", "],
            [parents componentsJoinedByString:@" < "], [siblings componentsJoinedByString:@", "]];
}

static void SCITTKeyboardNoteShape(UIView *view) {
    if (!sciKeyboardShapes) sciKeyboardShapes = [NSMutableArray array];
    if (sciKeyboardShapes.count >= 4) return;
    NSString *shape = SCITTKeyboardShapeOf(view);
    if (![sciKeyboardShapes containsObject:shape]) [sciKeyboardShapes addObject:shape];
}

%group SCITTKeyboardGroup
%hook UIKBBackdropView

- (void)setBackgroundColor:(UIColor *)color {
    sciKeyboardSeen++;
    if (SCITTKeyboardShouldBeBlack(self)) {
        sciKeyboardBlack++;
        %orig([UIColor blackColor]);
        return;
    }
    %orig;
}

- (void)didMoveToWindow {
    %orig;
    if (self.window && SCITTKeyboardShouldBeBlack(self)) {
        sciKeyboardArrived++;
        SCITTKeyboardNoteShape(self);
        // Through the hook above, so the count and the colour are one code path.
        [self setBackgroundColor:[UIColor blackColor]];
    }
}

%end
%end

NSString *SCITTKeyboardReport(void) {
    NSString *base = [NSString stringWithFormat:@"%@; backdrop colours set %lu, made black %lu, backdrops arrived in a window and made black %lu",
                      sciKeyboardState ?: @"not installed", (unsigned long)sciKeyboardSeen, (unsigned long)sciKeyboardBlack, (unsigned long)sciKeyboardArrived];
    if (!sciKeyboardShapes.count) return base;
    return [base stringByAppendingFormat:@"; backdrops seen: %@", [sciKeyboardShapes componentsJoinedByString:@" || "]];
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
