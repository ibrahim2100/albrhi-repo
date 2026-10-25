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

    // Not an IGCoreTextView: a comment can be drawn by something else. Inside a comment cell, take any view that draws text
    // under the finger -- and if there is none, put the cell's whole subtree in the ledger so the next round can name it.
    NSAttributedString *attributed = nil;
    NSString *via = @"";
    if (!target && [NSStringFromClass([hit class]) containsString:@"Dimming"]) {
        // A covering view took the touch (a sheet's dimming view): look for the text by where it is.
        NSInteger geoBudget = 2500;
        NSMutableArray<NSString *> *seen = [NSMutableArray array];
        target = SCITextTopmostAt(window, point, window, coreText, &geoBudget, seen);
        via = @" · found by position under a dimming view";
        if (!target) {
            SCICopyNoteMiss(@"a dimming view took the press and no text view is under it",
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
            SCICopyNoteMiss(@"no IGCoreTextView at the finger", [NSString stringWithFormat:@"%@ ⟨%@⟩", SCIChain(hit), SCIWindowsSummary(point, window)]);
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

    [UIPasteboard generalPasteboard].string = result;
    SCICopyNoteCopied(NSStringFromClass([target class]), result.length,
                      [NSString stringWithFormat:@"name %lu · runs %@%@", (unsigned long)nameLength, SCIRunsSummary(attributed), via]);

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
