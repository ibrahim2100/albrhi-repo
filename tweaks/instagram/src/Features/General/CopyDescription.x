#import <objc/runtime.h>
#import <objc/message.h>
#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../../Localization/SCILocalize.h"
#import "shared/src/SCIKVC.h"
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
/// The view the finger landed on **when it landed**, and where. A long-press fires half a second later, and by then
/// Instagram's own long-press (a comment's context menu) has put a dimming view over everything: a hit test at fire time
/// answers with that view (4.7.7 report: `IGWindow@0→UIDimmingView`, every time), the touch-down view does not.
@property (nonatomic, weak) UIView *touchDownView;
@property (nonatomic) CGPoint touchDownPoint;
@end

/// What a core-text view is showing, with its styling, or nil.
static NSAttributedString *SCICoreTextAttributed(id view) {
    SEL styledSel = NSSelectorFromString(@"styledString");
    if ([view respondsToSelector:styledSel]) {
        id styled = ((id (*)(id, SEL))objc_msgSend)(view, styledSel);
        SEL attributedSel = NSSelectorFromString(@"attributedString");
        if (styled && [styled respondsToSelector:attributedSel]) {
            id attributed = ((id (*)(id, SEL))objc_msgSend)(styled, attributedSel);
            if ([attributed isKindOfClass:[NSAttributedString class]] && ((NSAttributedString *)attributed).length) return attributed;
        }
    }

    SEL textSel = NSSelectorFromString(@"text");
    if ([view respondsToSelector:textSel]) {
        id text = ((id (*)(id, SEL))objc_msgSend)(view, textSel);
        if ([text isKindOfClass:[NSString class]] && [text length]) return [[NSAttributedString alloc] initWithString:text];
    }
    return nil;
}

/// How heavy the font is at `index`, and the run it covers: UIFont weight (-1…1) with the bold trait read as at least 0.4.
static CGFloat SCIWeightAt(NSAttributedString *text, NSUInteger index, NSRange *run) {
    NSDictionary *attributes = [text attributesAtIndex:index effectiveRange:run];
    UIFont *font = attributes[NSFontAttributeName];
    if (![font isKindOfClass:[UIFont class]]) return 0;
    NSDictionary *traits = font.fontDescriptor.fontAttributes[UIFontDescriptorTraitsAttribute];
    CGFloat weight = [traits[UIFontWeightTrait] doubleValue];
    if (font.fontDescriptor.symbolicTraits & UIFontDescriptorTraitBold) weight = MAX(weight, 0.4);
    return weight;
}

/// A feed caption or comment line reads `<account> <text>` with the account in a heavier font. The length of the heavy
/// prefix when something clearly lighter follows it, else 0. The prefix is every consecutive run as heavy as the first:
/// on the owner's 410 the account is one run (a link) and the space after it is a second run of the same weight
/// (`[0+6 w0.40 link][6+1 w0.40][7+69 w0.00]`), so comparing the first run with the next one found no difference.
static NSUInteger SCILeadingNameLength(NSAttributedString *text) {
    if (text.length < 2) return 0;
    NSRange run = NSMakeRange(0, 0);
    CGFloat heavy = SCIWeightAt(text, 0, &run);
    if (heavy < 0.2) return 0;   // nothing is called a name in the regular weight
    NSUInteger end = NSMaxRange(run);
    while (end < text.length) {
        NSRange next = NSMakeRange(0, 0);
        CGFloat weight = SCIWeightAt(text, end, &next);
        if (heavy - weight >= 0.1) return end;
        end = NSMaxRange(next);
    }
    return 0;
}

/// The first three styled runs, for the ledger: "[0+8 w0.30 link][8+1 w0.00]…". Shows why a name stayed in the copy.
static NSString *SCIRunsSummary(NSAttributedString *text) {
    NSMutableString *out = [NSMutableString string];
    NSUInteger at = 0;
    for (int i = 0; i < 3 && at < text.length; i++) {
        NSRange run = NSMakeRange(0, 0);
        CGFloat weight = SCIWeightAt(text, at, &run);
        NSDictionary *attributes = [text attributesAtIndex:at effectiveRange:nil];
        BOOL link = NO;
        for (NSString *key in attributes) if ([key rangeOfString:@"ink" options:NSCaseInsensitiveSearch].location != NSNotFound || [key rangeOfString:@"URL"].location != NSNotFound) link = YES;
        [out appendFormat:@"[%lu+%lu w%.2f%@]", (unsigned long)run.location, (unsigned long)run.length, weight, link ? @" link" : @""];
        at = NSMaxRange(run);
    }
    return out;
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

/// The text a view draws when it is one of the plain UIKit ways to draw some (`UILabel`, `UITextView`, anything answering
/// `-attributedText`), or nil.
static NSAttributedString *SCIPlainTextOf(UIView *view) {
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        if (label.attributedText.length) return label.attributedText;
        return label.text.length ? [[NSAttributedString alloc] initWithString:label.text] : nil;
    }
    if ([view isKindOfClass:[UITextView class]]) {
        UITextView *textView = (UITextView *)view;
        return textView.attributedText.length ? textView.attributedText : nil;
    }
    SEL attributedSel = NSSelectorFromString(@"attributedText");
    if ([view respondsToSelector:attributedSel]) {
        id attributed = ((id (*)(id, SEL))objc_msgSend)(view, attributedSel);
        if ([attributed isKindOfClass:[NSAttributedString class]] && ((NSAttributedString *)attributed).length) return attributed;
    }
    return nil;
}

/// The first view at or under `root` that draws text and whose frame, in `window`, holds `point` (with slack).
static UIView *SCIPlainTextAt(UIView *root, CGPoint point, UIWindow *window, NSInteger *budget) {
    if (!root || *budget <= 0) return nil;
    (*budget)--;
    if (root.hidden || root.alpha < 0.01) return nil;

    CGRect frame = [root convertRect:root.bounds toView:window];
    if (SCIPlainTextOf(root) && CGRectContainsPoint(CGRectInset(frame, -14, -14), point)) return root;
    for (UIView *child in root.subviews) {
        UIView *found = SCIPlainTextAt(child, point, window, budget);
        if (found) return found;
    }
    return nil;
}

/// The topmost view under `point` that draws text (an `IGCoreTextView` or anything `SCIPlainTextOf` reads), found by where
/// views are and not by what a hit test says -- for a press that a covering view (Instagram's comment sheet answers with a
/// `UIDimmingView`) takes. Later subviews are in front, so they are asked first. `seen` collects what contains the point.
static UIView *SCITextTopmostAt(UIView *root, CGPoint point, UIWindow *window, Class coreText, NSInteger *budget, NSMutableArray<NSString *> *seen) {
    if (!root || *budget <= 0) return nil;
    (*budget)--;
    if (root.hidden || root.alpha < 0.01) return nil;

    CGRect frame = [root convertRect:root.bounds toView:window];
    BOOL contains = CGRectContainsPoint(frame, point);
    if (contains && seen.count < 14) {
        [seen addObject:[NSString stringWithFormat:@"%@ %.0fx%.0f", NSStringFromClass([root class]), frame.size.width, frame.size.height]];
    }
    if (contains || !root.clipsToBounds) {
        for (UIView *child in [root.subviews reverseObjectEnumerator]) {
            UIView *found = SCITextTopmostAt(child, point, window, coreText, budget, seen);
            if (found) return found;
        }
    }
    BOOL draws = (coreText && [root isKindOfClass:coreText]) || SCIPlainTextOf(root) != nil;
    return (draws && CGRectContainsPoint(CGRectInset(frame, -14, -14), point)) ? root : nil;
}

/// The classes under `root` with their sizes, depth first, for the ledger when a comment cell gave nothing to copy: the
/// next round names whatever draws the text.
static void SCISubtree(UIView *root, int depth, NSMutableArray<NSString *> *out) {
    if (!root || out.count >= 24 || depth > 7) return;
    [out addObject:[NSString stringWithFormat:@"%@%@ %.0fx%.0f", [@"" stringByPaddingToLength:(NSUInteger)depth withString:@">" startingAtIndex:0],
                    NSStringFromClass([root class]), root.bounds.size.width, root.bounds.size.height]];
    for (UIView *child in root.subviews) SCISubtree(child, depth + 1, out);
}

/// Every window of the app with what a hit test says at `point` there: a comment sheet that lives in another window shows up.
static NSString *SCIWindowsSummary(CGPoint point, UIWindow *from) {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (UIWindow *w in UIApplication.sharedApplication.windows) {
        UIView *hit = [w hitTest:[w convertPoint:point fromWindow:from] withEvent:nil];
        [parts addObject:[NSString stringWithFormat:@"%@@%.0f%@→%@", NSStringFromClass([w class]), w.windowLevel, w.hidden ? @" hidden" : @"",
                          hit ? NSStringFromClass([hit class]) : @"nil"]];
    }
    return [parts componentsJoinedByString:@" · "];
}

/// The names of the views `text` sits in, up to and including its cell: what `SCICopyOffered` judges. It must stop there --
/// the view controllers above include Instagram's tab bar controller, and "TabBar" is an excluded word.
static NSArray<NSString *> *SCIOwnersOf(UIView *view) {
    NSMutableArray<NSString *> *owners = [NSMutableArray array];
    UIResponder *responder = view.superview;
    for (int step = 0; step < 16 && responder; step++, responder = responder.nextResponder) {
        if ([responder isKindOfClass:[UIViewController class]] || [responder isKindOfClass:[UIScrollView class]]) break;
        [owners addObject:NSStringFromClass([responder class])];
        if ([responder isKindOfClass:[UICollectionViewCell class]] || [responder isKindOfClass:[UITableViewCell class]]) break;
    }
    return owners;
}

/// A comment's own text, remembered on its cell when Instagram binds the cell to its model. The comment text view is a Swift
/// lazy var whose type ObjC cannot see (the 4.7.5 report found a table header label instead), but the model it is built
/// from is ObjC. **`-bindViewModel:` is handed an `IGCommentModel` on 410** (the 4.7.6 report: `comment cells bound: 4
/// (with text: 0) · model class: IGCommentModel`) -- its text is `text`, and `commentText` belongs to the section view model
/// the first guess assumed. Both shapes are read, in the order a plain model is most likely.
static const void *kSCICommentTextKey = &kSCICommentTextKey;

static NSString *SCICommentTextOf(id model) {
    for (NSString *key in @[@"text", @"commentText"]) {
        id text = SCISafeValueForKey(model, key);
        if ([text isKindOfClass:[NSString class]] && [text length]) return text;
    }
    id comment = SCISafeValueForKey(model, @"comment");
    id text = comment ? SCISafeValueForKey(comment, @"text") : nil;
    return ([text isKindOfClass:[NSString class]] && [text length]) ? text : nil;
}

static void SCIRememberComment(UIView *cell, id viewModel) {
    if (!viewModel || ![SCIUtils getBoolPref:@"copy_description"]) return;
    NSString *text = SCICommentTextOf(viewModel);
    SCICopyNoteBind(NSStringFromClass([viewModel class]), text != nil);
    objc_setAssociatedObject(cell, kSCICommentTextKey, [text copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

/// The comment cell (`IGCommentCell` and its subclasses) under `point`, by where cells are and not by a hit test, front to back.
static UICollectionViewCell *SCICommentCellAt(UIView *root, CGPoint point, UIWindow *window, NSInteger *budget) {
    if (!root || *budget <= 0) return nil;
    (*budget)--;
    if (root.hidden || root.alpha < 0.01) return nil;

    CGRect frame = [root convertRect:root.bounds toView:window];
    BOOL contains = CGRectContainsPoint(frame, point);
    if (contains && [root isKindOfClass:[UICollectionViewCell class]] && [NSStringFromClass([root class]) containsString:@"IGComment"]) {
        return (UICollectionViewCell *)root;
    }
    if (contains || !root.clipsToBounds) {
        for (UIView *child in [root.subviews reverseObjectEnumerator]) {
            UICollectionViewCell *found = SCICommentCellAt(child, point, window, budget);
            if (found) return found;
        }
    }
    return nil;
}

/// A button or other control inside `cell` at `point` (the like button's own long-press must keep its meaning).
static UIView *SCIControlAt(UIView *root, CGPoint point, UIWindow *window) {
    if (root.hidden || root.alpha < 0.01 || !CGRectContainsPoint([root convertRect:root.bounds toView:window], point)) return nil;
    for (UIView *child in [root.subviews reverseObjectEnumerator]) {
        UIView *found = SCIControlAt(child, point, window);
        if (found) return found;
    }
    return [root isKindOfClass:[UIControl class]] ? root : nil;
}

/// The finish every copy shares: pasteboard, a tap of feedback, the "copied" notice, and the ledger.
static void SCICopyFinish(NSString *result, NSString *viewClass, NSString *detail) {
    [UIPasteboard generalPasteboard].string = result;
    SCICopyNoteCopied(viewClass, result.length, detail);

    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [haptic impactOccurred];

    JGProgressHUD *HUD = [[JGProgressHUD alloc] init];
    HUD.textLabel.text = SCILocalized(@"p_copied_text");
    HUD.indicatorView = [[JGProgressHUDSuccessIndicatorView alloc] init];

    [HUD showInView:topMostController().view];
    [HUD dismissAfterDelay:2.0];
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

/// What a long press does, whichever way it was noticed: `down` is the view the finger landed on **when it landed**, `point`
/// where, in `window`. A half second later Instagram's own long-press (a comment's context menu) has put a dimming view over
/// everything, so a hit test then answers with that view.
static CFAbsoluteTime sciLastHandled = 0;
static CGPoint sciLastHandledPoint;

static void SCICopyHandlePress(UIWindow *window, UIView *down, CGPoint point) {
    // Two ways of noticing the same press (the recognizer and the touch timer) must copy once.
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (now - sciLastHandled < 1.5 && hypot(point.x - sciLastHandledPoint.x, point.y - sciLastHandledPoint.y) < 30) return;
    sciLastHandled = now;
    sciLastHandledPoint = point;
    SCICopyNoteLongPress();

    UIView *hit = [window hitTest:point withEvent:nil];
    BOOL usingTouchDown = down && down.window == window;
    if (usingTouchDown) hit = down;   // what was under the finger when it landed, not what covers it half a second later
    Class coreText = NSClassFromString(@"IGCoreTextView");
    if (!hit || !coreText) {
        SCICopyNoteMiss(!coreText ? @"IGCoreTextView is not in this build" : @"nothing under the finger", nil);
        return;
    }

    // A comment: the cell is found by position and its text is the one remembered from its model. This comes first because
    // the comment's text view cannot be named (Swift) and, under a sheet's dimming view, a hit test answers with the dimming view.
    NSString *via = @"";
    UICollectionViewCell *commentCell = nil;
    UIControl *touchedControl = nil;
    for (UIView *v = hit; v && v != window; v = v.superview) {
        if (!touchedControl && [v isKindOfClass:[UIControl class]]) touchedControl = (UIControl *)v;
        if ([v isKindOfClass:[UICollectionViewCell class]]) {
            if ([NSStringFromClass([v class]) containsString:@"IGComment"]) commentCell = (UICollectionViewCell *)v;
            break;
        }
    }
    if (!commentCell && !usingTouchDown) {
        NSInteger cellBudget = 2500;
        commentCell = SCICommentCellAt(window, point, window, &cellBudget);
    }
    if (commentCell) {
        NSString *remembered = objc_getAssociatedObject(commentCell, kSCICommentTextKey);
        NSString *comment = SCICopyableText(remembered);
        if (touchedControl || (!usingTouchDown && SCIControlAt(commentCell, point, window))) {
            SCICopyNoteMiss(@"a control inside the comment cell was pressed", SCIChain(hit));
            return;
        }
        if (comment) {
            SCICopyFinish(comment, NSStringFromClass([commentCell class]),
                          usingTouchDown ? @"comment text from its model · cell from the touch-down view" : @"comment text from its model · cell found by position");
            return;
        }
        // Nothing remembered (the cell was bound before the tweak could see it, or the model has another shape): fall through
        // to the text-view search, and say so wherever that ends.
        via = [NSString stringWithFormat:@" · %@ found with no text remembered from its model", NSStringFromClass([commentCell class])];
    } else if (usingTouchDown) {
        via = [NSString stringWithFormat:@" · touch-down chain %@", SCIChain(hit)];
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

    // Not an IGCoreTextView: a comment can be drawn by something else. Inside a comment cell, take any view that draws text
    // under the finger -- and if there is none, put the cell's whole subtree in the ledger so the next round can name it.
    NSAttributedString *attributed = nil;
    if (!target && [NSStringFromClass([hit class]) containsString:@"Dimming"]) {
        // A covering view took the touch (a sheet's dimming view): look for the text by where it is.
        NSInteger geoBudget = 2500;
        NSMutableArray<NSString *> *seen = [NSMutableArray array];
        target = SCITextTopmostAt(window, point, window, coreText, &geoBudget, seen);
        via = [via stringByAppendingString:@" · found by position under a dimming view"];
        if (!target) {
            SCICopyNoteMiss([@"a dimming view took the press and no text view is under it" stringByAppendingString:via],
                            [NSString stringWithFormat:@"%@ ⟨%@⟩ ⟨%@⟩", SCIChain(hit), SCIWindowsSummary(point, window), [seen componentsJoinedByString:@" > "]]);
            return;
        }
        if (![target isKindOfClass:coreText]) attributed = SCIPlainTextOf(target);
    }
    if (!target) {
        UIView *cell = nil;
        for (UIView *v = hit; v && v != window; v = v.superview) {
            if ([v isKindOfClass:[UICollectionViewCell class]] || [v isKindOfClass:[UITableViewCell class]]) { cell = v; break; }
        }
        if (cell && [NSStringFromClass([cell class]) containsString:@"Comment"]) {
            NSInteger plainBudget = 600;
            target = SCIPlainTextAt(cell, point, window, &plainBudget);
            if (!target) {
                NSMutableArray<NSString *> *tree = [NSMutableArray array];
                SCISubtree(cell, 0, tree);
                SCICopyNoteMiss(@"comment cell, no text view at the finger",
                                [NSString stringWithFormat:@"%@ ⟨%@⟩", SCIChain(hit), [tree componentsJoinedByString:@" "]]);
                return;
            }
            attributed = SCIPlainTextOf(target);
        } else {
            SCICopyNoteMiss([@"no IGCoreTextView at the finger" stringByAppendingString:via], [NSString stringWithFormat:@"%@ ⟨%@⟩", SCIChain(hit), SCIWindowsSummary(point, window)]);
            return;
        }
    }

    if (!SCICopyOffered(SCIOwnersOf(target))) {
        SCICopyNoteMiss(@"kept out by the exclusion list", SCIChain(target));
        return;
    }

    if (!attributed) attributed = SCICoreTextAttributed(target);
    NSUInteger nameLength = attributed ? SCILeadingNameLength(attributed) : 0;
    NSString *result = SCICopyableText(attributed ? SCICopyDropLeadingName(attributed.string, nameLength) : nil);
    if (!result) {
        SCICopyNoteMiss(@"the text view has no text", SCIChain(target));
        return;
    }

    SCICopyFinish(result, NSStringFromClass([target class]),
                  [NSString stringWithFormat:@"name %lu · runs %@%@", (unsigned long)nameLength, SCIRunsSummary(attributed), via]);
}

// MARK: - The touch timer
//
// **Why a second way of noticing a press.** In the 4.7.8 report the comment presses never reached the recognizer at all
// (`long-presses seen: 1`, and that one was on the tab bar): inside Instagram's comments something takes the touches
// before a window recognizer can finish -- most likely the comment's own context-menu gesture, which this code cannot
// inspect. The touches themselves still pass through `-[UIWindow sendEvent:]` whatever the gesture system decides, so a
// plain half-second timer started there cannot be starved by it. It stops on lift-off, on a move of more than 12 points,
// on a second finger, or on the system cancelling the touch (each counted in the ledger).

static NSUInteger sciTouchToken = 0;
static BOOL sciTouchTracking = NO;
static CGPoint sciTouchPoint;
static __weak UIView *sciTouchView;

static void SCICopyObserveTouches(UIWindow *window, UIEvent *event) {
    if (event.type != UIEventTypeTouches) return;
    if (!objc_getAssociatedObject(window, kSCICopyWindowKey)) return;

    NSSet<UITouch *> *touches = [event touchesForWindow:window];
    if (touches.count > 1) { sciTouchTracking = NO; return; }
    UITouch *touch = touches.anyObject;
    if (!touch) return;

    switch (touch.phase) {
        case UITouchPhaseBegan: {
            sciTouchTracking = NO;
            if (![SCIUtils getBoolPref:@"copy_description"]) return;
            sciTouchTracking = YES;
            sciTouchPoint = [touch locationInView:window];
            sciTouchView = touch.view;
            SCICopyNoteTouch(0);
            NSUInteger token = ++sciTouchToken;
            __weak UIWindow *weakWindow = window;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                UIWindow *strongWindow = weakWindow;
                if (!strongWindow || !sciTouchTracking || token != sciTouchToken) return;
                sciTouchTracking = NO;
                SCICopyNoteSource(YES);
                SCICopyHandlePress(strongWindow, sciTouchView, sciTouchPoint);
            });
            break;
        }
        case UITouchPhaseMoved: {
            if (!sciTouchTracking) break;
            CGPoint now = [touch locationInView:window];
            if (hypot(now.x - sciTouchPoint.x, now.y - sciTouchPoint.y) > 12) { sciTouchTracking = NO; SCICopyNoteTouch(2); }
            break;
        }
        case UITouchPhaseEnded:
            if (sciTouchTracking) SCICopyNoteTouch(1);
            sciTouchTracking = NO;
            break;
        case UITouchPhaseCancelled:
            if (sciTouchTracking) SCICopyNoteTouch(3);
            sciTouchTracking = NO;
            break;
        default:
            break;
    }
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

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    self.touchDownView = touch.view;
    UIWindow *window = touch.window;
    self.touchDownPoint = window ? [touch locationInView:window] : CGPointZero;
    return YES;
}

- (void)fired:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) return;
    if (![SCIUtils getBoolPref:@"copy_description"]) return;

    UIWindow *window = (UIWindow *)sender.view;
    if (![window isKindOfClass:[UIWindow class]]) return;
    SCICopyNoteSource(NO);
    SCICopyHandlePress(window, self.touchDownView, [sender locationInView:window]);
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

%hook IGCommentCell

- (void)bindViewModel:(id)viewModel {
    %orig;
    SCIRememberComment(self, viewModel);
}

%end

%hook UIWindow

- (void)sendEvent:(UIEvent *)event {
    SCICopyObserveTouches(self, event);
    %orig;
}

%end
