#import <objc/runtime.h>
#import <objc/message.h>
#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../../Localization/SCILocalize.h"
#import "SCICopyText.h"
#import "modules/JGProgressHUD/JGProgressHUD.h"

///
/// Long-press a caption, a comment or a bio to copy it.
///
/// `IGCoreTextView` is Instagram's rich-text view: feed captions (`IGFeedItemTextCell._coreTextView`), comments and bios
/// all render through it, so one hook covers them. Four things changed from the first version, each found by reading the
/// 410.1.0 and 450.1.0 binaries rather than by trying it:
///
///  * **One recognizer per view.** The old hook added a new one every time `-didMoveToSuperview` fired, which is every
///    time a recycled cell is reused, so a view that had been scrolled around a while copied several times and showed
///    several confirmations. It is added once (an associated object marks the view) and only when the view is in a window.
///  * **Only where copy makes sense.** A hundred and ninety-eight Instagram classes own an `IGCoreTextView`; settings rows,
///    banners and message bubbles are not captions. The owners' class names decide, once, in `SCICopyOffered`.
///  * **The text is read from where Instagram keeps it.** `-text` on this class is not a method of the class: it is a
///    `Jest` category (a test-automation hook) that happens to be in the release build today. `-styledString` is the real
///    API (`IGStyledString -attributedString`, both builds), so it is asked first and `-text` is the fallback.
///  * **The setting is read when the finger lifts, too**, so switching it off takes effect without scrolling the view away.
///
/// Does not claim to know which of Instagram's own long-presses it overlaps (the comment's own menu, a link preview): the
/// recognizer lets the others run, and copying alongside them is the cost.
///

static const void *kSCICopyStateKey = &kSCICopyStateKey;

/// Lets this recognizer coexist with Instagram's own long-press on the same view.
@interface SCICopyGestureDelegate : NSObject <UIGestureRecognizerDelegate>
+ (instancetype)shared;
@end

@implementation SCICopyGestureDelegate
+ (instancetype)shared {
    static SCICopyGestureDelegate *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[SCICopyGestureDelegate alloc] init]; });
    return shared;
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
    shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    return YES;
}
@end

/// The string a core-text view is showing, or nil.
static NSString *SCICoreTextString(id view) {
    SEL styledSel = NSSelectorFromString(@"styledString");
    if ([view respondsToSelector:styledSel]) {
        id styled = ((id (*)(id, SEL))objc_msgSend)(view, styledSel);
        SEL attributedSel = NSSelectorFromString(@"attributedString");
        if (styled && [styled respondsToSelector:attributedSel]) {
            id attributed = ((id (*)(id, SEL))objc_msgSend)(styled, attributedSel);
            if ([attributed isKindOfClass:[NSAttributedString class]]) {
                NSString *string = ((NSAttributedString *)attributed).string;
                if (string.length) return string;
            }
        }
    }

    SEL textSel = NSSelectorFromString(@"text");
    if ([view respondsToSelector:textSel]) {
        id text = ((id (*)(id, SEL))objc_msgSend)(view, textSel);
        if ([text isKindOfClass:[NSString class]]) return text;
    }
    return nil;
}

%hook IGCoreTextView

- (void)didMoveToWindow {
    %orig;

    if (!self.window) return;
    if (objc_getAssociatedObject(self, kSCICopyStateKey)) return;   // decided already, either way
    if (![SCIUtils getBoolPref:@"copy_description"]) return;        // not recorded: switching it on later still finds the view

    // The owners, nearest first, up to the view controller. Walked once per view, here, never while scrolling.
    NSMutableArray<NSString *> *owners = [NSMutableArray array];
    UIResponder *responder = self.superview;
    for (int step = 0; step < 16 && responder; step++, responder = responder.nextResponder) {
        [owners addObject:NSStringFromClass([responder class])];
    }

    if (!SCICopyOffered(owners)) {
        objc_setAssociatedObject(self, kSCICopyStateKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }

    UILongPressGestureRecognizer *press =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(sci_copyLongPressed:)];
    press.minimumPressDuration = 0.5;
    press.cancelsTouchesInView = NO;
    press.delegate = [SCICopyGestureDelegate shared];
    [self addGestureRecognizer:press];

    objc_setAssociatedObject(self, kSCICopyStateKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%new - (void)sci_copyLongPressed:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) return;
    if (![SCIUtils getBoolPref:@"copy_description"]) return;

    NSString *result = SCICopyableText(SCICoreTextString(self));
    if (!result) return;

    [UIPasteboard generalPasteboard].string = result;

    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [haptic impactOccurred];

    JGProgressHUD *HUD = [[JGProgressHUD alloc] init];
    HUD.textLabel.text = SCILocalized(@"p_copied_text");
    HUD.indicatorView = [[JGProgressHUDSuccessIndicatorView alloc] init];

    [HUD showInView:topMostController().view];
    [HUD dismissAfterDelay:2.0];
}

%end
