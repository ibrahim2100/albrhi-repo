//
//  SCITTHold.x
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "SCITTHold.h"
#import "../Download/SCITTButton.h"
#import "../../UI/SCITTToast.h"
#import "../../Localization/SCILocalize.h"
#import "../../Prefs.h"
#import "../../SCILog.h"

///
/// **The hold is followed by the window, not by a recogniser on the thing held.**
///
/// The first version put a long-press recogniser on the download button and copied nothing: TikTok's feed has its own long-press (the
/// panel), a gesture that recognises first fails the others, and a recogniser added below it loses that race. Instagram's copy feature in
/// this repository met the same wall and was fixed the same way (CLAUDE.md §5.1, 4.7.9): `-[UIWindow sendEvent:]` sees the raw touch
/// before any recogniser, so a half-second timer started at touch-down, stopped by a lift, a move of more than 12 points, a second finger or a
/// cancel, does not depend on who else is listening. The touch is never consumed -- `%orig` always runs -- so everything underneath
/// behaves exactly as before.
///
/// What the hold was on:
///
///   * one of the tweak's download buttons -> the copy menu for that video (`SCITTCopyHoldOnDownloadButton`);
///   * text on a profile -> that text is copied. "A profile" is a responder chain that passes through a controller whose class name holds
///     `Profile`; the text is the first label, text view or text-bearing view at or above the finger, within five superviews. A control
///     in the way (a button, a tab) means no copy: a hold on a button is not a request to copy its title.
///
/// **Not run on a device.** The report keeps the class chain under the last hold that matched nothing: a miss will name the view.
///

static NSUInteger sciHoldToken = 0;
static CGPoint sciHoldStart;
static __weak UIView *sciHoldView = nil;
static __weak UIWindow *sciHoldWindow = nil;

static NSUInteger sciHoldBegan = 0, sciHoldFired = 0, sciHoldOnButton = 0, sciHoldTextCopied = 0, sciHoldMissed = 0, sciHoldNotProfile = 0;
static NSString *sciHoldLastChain = nil;
static NSString *sciHoldState = nil;

static NSString *SCITTChainOf(UIView *view) {
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (NSInteger i = 0; view && i < 7; i++, view = view.superview) [names addObject:NSStringFromClass([view class])];
    return [names componentsJoinedByString:@" < "];
}

static BOOL SCITTInProfile(UIView *view) {
    UIResponder *responder = view;
    for (NSInteger i = 0; responder && i < 40; i++, responder = responder.nextResponder) {
        if ([responder isKindOfClass:[UIViewController class]] &&
            [NSStringFromClass([responder class]) rangeOfString:@"Profile"].location != NSNotFound) return YES;
    }
    return NO;
}

/// The text a view shows, or nil. Only objects that answer with an object are asked.
static NSString *SCITTTextOfView(UIView *view) {
    NSString *text = nil;
    if ([view isKindOfClass:[UILabel class]]) text = ((UILabel *)view).text ?: ((UILabel *)view).attributedText.string;
    else if ([view isKindOfClass:[UITextView class]]) text = ((UITextView *)view).text;
    else {
        for (NSString *name in @[@"text", @"attributedText"]) {
            SEL selector = NSSelectorFromString(name);
            Method method = class_getInstanceMethod(object_getClass(view), selector);
            const char *types = method ? method_getTypeEncoding(method) : NULL;
            if (!types || types[0] != '@') continue;
            id value = ((id (*)(id, SEL))objc_msgSend)(view, selector);
            if ([value isKindOfClass:[NSString class]]) text = value;
            else if ([value isKindOfClass:[NSAttributedString class]]) text = [(NSAttributedString *)value string];
            if (text.length) break;
        }
    }
    text = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return text.length ? text : nil;
}

static NSString *SCITTProfileTextAt(UIView *hit) {
    UIView *view = hit;
    for (NSInteger i = 0; view && i < 5; i++, view = view.superview) {
        if ([view isKindOfClass:[UIControl class]]) return nil;
        NSString *text = SCITTTextOfView(view);
        if (text) return text;
    }
    return nil;
}

static void SCITTHoldFire(NSUInteger token) {
    if (token != sciHoldToken) return;
    UIView *hit = sciHoldView;
    if (!hit || !SCIPrefEnabled(SCIPrefCopyMenu)) return;
    sciHoldFired++;

    if (SCITTCopyHoldOnDownloadButton(hit)) {
        sciHoldOnButton++;
        return;
    }

    if (!SCITTInProfile(hit)) {
        sciHoldNotProfile++;
        sciHoldLastChain = [@"not a profile: " stringByAppendingString:SCITTChainOf(hit)];
        return;
    }

    NSString *text = SCITTProfileTextAt(hit);
    if (!text) {
        sciHoldMissed++;
        sciHoldLastChain = [@"profile, no text: " stringByAppendingString:SCITTChainOf(hit)];
        return;
    }

    [UIPasteboard generalPasteboard].string = text;
    sciHoldTextCopied++;
    [SCITTToast noticeWithText:SCILocalized(@"copy_done") symbol:@"doc.on.doc.fill"];
}

static void SCITTHoldObserve(UIWindow *window, UIEvent *event) {
    if (event.type != UIEventTypeTouches) return;
    NSSet<UITouch *> *all = event.allTouches;
    if (all.count != 1) {
        sciHoldToken++;   // a second finger is a pinch or a swipe, never a hold
        return;
    }

    UITouch *touch = all.anyObject;
    switch (touch.phase) {
        case UITouchPhaseBegan: {
            if (!SCIPrefEnabled(SCIPrefCopyMenu)) return;
            CGPoint point = [touch locationInView:window];
            UIView *hit = [window hitTest:point withEvent:nil];
            if (!hit) return;

            sciHoldBegan++;
            sciHoldStart = point;
            sciHoldView = hit;
            sciHoldWindow = window;
            NSUInteger token = ++sciHoldToken;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                SCITTHoldFire(token);
            });
            break;
        }
        case UITouchPhaseMoved: {
            if (window != sciHoldWindow) return;
            CGPoint point = [touch locationInView:window];
            if (hypot(point.x - sciHoldStart.x, point.y - sciHoldStart.y) > 12) sciHoldToken++;
            break;
        }
        case UITouchPhaseEnded:
        case UITouchPhaseCancelled:
            sciHoldToken++;
            break;
        default:
            break;
    }
}

%group SCITTHoldGroup
%hook UIWindow

- (void)sendEvent:(UIEvent *)event {
    SCITTHoldObserve(self, event);
    %orig;
}

%end
%end

NSString *SCITTHoldReport(void) {
    return [NSString stringWithFormat:@"%@; holds begun %lu, reached half a second %lu: on a download button %lu, profile text copied %lu, "
            @"profile but no text %lu, not a profile %lu%@",
            sciHoldState ?: @"not installed",
            (unsigned long)sciHoldBegan, (unsigned long)sciHoldFired, (unsigned long)sciHoldOnButton, (unsigned long)sciHoldTextCopied,
            (unsigned long)sciHoldMissed, (unsigned long)sciHoldNotProfile,
            sciHoldLastChain ? [@"; last miss: " stringByAppendingString:sciHoldLastChain] : @""];
}

void SCITTInstallHold(void) {
    Method method = class_getInstanceMethod([UIWindow class], @selector(sendEvent:));
    if (!method) {
        sciHoldState = @"skipped: UIWindow -sendEvent: not found";
        return;
    }
    %init(SCITTHoldGroup);
    sciHoldState = @"installed: UIWindow -sendEvent:";
    SCILogV(@"[Hold] %@", sciHoldState);
}
