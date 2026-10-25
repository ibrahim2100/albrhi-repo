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
/// **Version 1 attached a recognizer to each `IGCoreTextView` and copied nothing on the owner's phone (Instagram 410.1.0).**
/// The cause is not in the report that came back, so this is a reading and not a finding: `IGCoreTextView` overrides
/// `-pointInside:withEvent:` (it is on the 410 and 450 method lists), and a view that answers NO for the points that are not a
/// link never receives the long-press that starts on plain text -- which is where a caption is pressed. The first version
/// could not see that failure and neither could its report. This one does not depend on the text view receiving the touch:
///
///  * **One recognizer on the window**, added once (`becomeKeyWindow`, `makeKeyAndVisible`), the way the TikTok tweak's own
///    two-finger hold works. It cancels no touch and lets every other recognizer run.
///  * **When it fires, the finger's position finds the text**: hit-test, then climb the owners and search each one's
///    subviews for an `IGCoreTextView` whose frame, in window coordinates, contains the point (14 points of slack, hidden
///    views skipped, a budget of views so a huge hierarchy cannot make a long-press slow).
///  * **Only where copy makes sense** (`SCICopyOffered`: not message bubbles, settings, banners, forms) -- judged on the
///    found view's owners.
///  * **The text is read from where Instagram keeps it**: `IGStyledString -attributedString` first (a real API in 410 and
///    450), `-text` -- a `Jest` test-automation category -- as the fallback.
///  * **A ledger**, shown on Settings › Diagnostics: windows attached, long-presses seen, copies, and for every miss the
///    chain of classes under the finger. If a comment is drawn by something other than `IGCoreTextView`, that chain names it.
///

static const void *kSCICopyWindowKey = &kSCICopyWindowKey;

@interface SCICopyTarget : NSObject <UIGestureRecognizerDelegate>
+ (instancetype)shared;
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

/// The first `IGCoreTextView` at or under `root` whose frame, in `window`, contains `point` (with slack).
static UIView *SCICoreTextAt(UIView *root, CGPoint point, UIWindow *window, Class coreText, NSInteger *budget) {
    if (!root || *budget <= 0) return nil;
    (*budget)--;
    if (root.hidden || root.alpha < 0.01) return nil;

    if ([root isKindOfClass:coreText]) {
        CGRect frame = [root convertRect:root.bounds toView:window];
        return CGRectContainsPoint(CGRectInset(frame, -14, -14), point) ? root : nil;
    }
    for (UIView *child in root.subviews) {
        UIView *found = SCICoreTextAt(child, point, window, coreText, budget);
        if (found) return found;
    }
    return nil;
}

/// "IGCoreTextView ← UIView ← IGFeedItemTextCell ← …" -- nearest first, for the ledger.
static NSString *SCIChain(UIView *view) {
    NSMutableArray *names = [NSMutableArray array];
    for (UIView *v = view; v && names.count < 8; v = v.superview) [names addObject:NSStringFromClass([v class])];
    return [names componentsJoinedByString:@" ← "];
}

static void SCICopyAttachTo(UIWindow *window) {
    if (!window || objc_getAssociatedObject(window, kSCICopyWindowKey)) return;
    objc_setAssociatedObject(window, kSCICopyWindowKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UILongPressGestureRecognizer *press =
        [[UILongPressGestureRecognizer alloc] initWithTarget:[SCICopyTarget shared] action:@selector(fired:)];
    press.minimumPressDuration = 0.5;
    press.cancelsTouchesInView = NO;
    press.delaysTouchesBegan = NO;
    press.delaysTouchesEnded = NO;
    press.delegate = [SCICopyTarget shared];
    [window addGestureRecognizer:press];
    SCICopyNoteAttached(NSStringFromClass([window class]));
}

@implementation SCICopyTarget

+ (instancetype)shared {
    static SCICopyTarget *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[SCICopyTarget alloc] init]; });
    return shared;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
    shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    return YES;
}

- (void)fired:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) return;
    if (![SCIUtils getBoolPref:@"copy_description"]) return;
    SCICopyNoteLongPress();

    UIWindow *window = (UIWindow *)sender.view;
    if (![window isKindOfClass:[UIWindow class]]) return;

    CGPoint point = [sender locationInView:window];
    UIView *hit = [window hitTest:point withEvent:nil];
    Class coreText = NSClassFromString(@"IGCoreTextView");
    if (!hit || !coreText) {
        SCICopyNoteMiss(!coreText ? @"IGCoreTextView is not in this build" : @"nothing under the finger", nil);
        return;
    }

    // On the text itself, or on something that contains it (a cell, a header): climb, searching each owner's subviews.
    UIView *target = nil;
    for (UIView *v = hit; v && !target; v = v.superview) {
        if ([v isKindOfClass:coreText]) { target = v; break; }
    }
    NSInteger budget = 1500;
    UIView *owner = hit;
    for (int level = 0; owner && owner != window && !target && level < 10; level++, owner = owner.superview) {
        target = SCICoreTextAt(owner, point, window, coreText, &budget);
        // A cell is the unit that holds a caption or a comment: past it the search would only find other rows' text.
        if ([owner isKindOfClass:[UICollectionViewCell class]] || [owner isKindOfClass:[UITableViewCell class]]) break;
    }

    if (!target) {
        SCICopyNoteMiss(@"no IGCoreTextView at the finger", SCIChain(hit));
        return;
    }

    // The owners are the views the text sits in, up to its cell. Going further reached the view controllers: the feed's
    // sits under Instagram's tab bar controller, whose name holds "TabBar", and every caption in the feed was refused
    // (4.7.2 on 410: "kept out by the exclusion list" for IGFeedItemTextCell).
    NSMutableArray<NSString *> *owners = [NSMutableArray array];
    UIResponder *responder = target.superview;
    for (int step = 0; step < 16 && responder; step++, responder = responder.nextResponder) {
        if ([responder isKindOfClass:[UIViewController class]] || [responder isKindOfClass:[UIScrollView class]]) break;
        [owners addObject:NSStringFromClass([responder class])];
        if ([responder isKindOfClass:[UICollectionViewCell class]] || [responder isKindOfClass:[UITableViewCell class]]) break;
    }
    if (!SCICopyOffered(owners)) {
        SCICopyNoteMiss(@"kept out by the exclusion list", SCIChain(target));
        return;
    }

    NSString *result = SCICopyableText(SCICoreTextString(target));
    if (!result) {
        SCICopyNoteMiss(@"the text view has no text", SCIChain(target));
        return;
    }

    [UIPasteboard generalPasteboard].string = result;
    SCICopyNoteCopied(NSStringFromClass([target class]), result.length);

    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [haptic impactOccurred];

    JGProgressHUD *HUD = [[JGProgressHUD alloc] init];
    HUD.textLabel.text = SCILocalized(@"p_copied_text");
    HUD.indicatorView = [[JGProgressHUDSuccessIndicatorView alloc] init];

    [HUD showInView:topMostController().view];
    [HUD dismissAfterDelay:2.0];
}

@end

%hook UIWindow

- (void)becomeKeyWindow {
    %orig;
    SCICopyAttachTo(self);
}

- (void)makeKeyAndVisible {
    %orig;
    SCICopyAttachTo(self);
}

%end
