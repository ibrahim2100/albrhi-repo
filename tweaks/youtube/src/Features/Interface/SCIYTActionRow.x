#import <objc/runtime.h>
#import <objc/message.h>
#import "shared/src/SCIResponder.h"
#import "shared/src/SCIKVC.h"
#import "../../YouTubeHeaders.h"
#import "../../SCILog.h"
#import "../../Prefs.h"
#import "../../SCIYTLaunchGuard.h"
#import "../../Localization/SCILocalize.h"
#import "../../Diagnostics/SCIYTDiagnostics.h"
#import "../Download/SCIYTDownload.h"

///
/// Save, in the row with Like and Share.
///
/// **YouTube builds that row from renderers, so this adds a renderer rather than a view.** The
/// row is `YTSlimVideoScrollableDetailsActionsView` and it is handed its buttons through
/// `-createActionViewsFromSupportedRenderers:` (`v24@0:8@16`); one more entry in that array and
/// YouTube builds the button itself — its own metrics, its own label font, its own collapse
/// behaviour when the row runs out of width, its own scrolling. There is nothing of ours being
/// drawn and so nothing to keep in sync, which is the same reason the Download Centre tab is a
/// pivot renderer rather than a circle painted over the tab bar.
///
/// **Every hop of the chain was read from the app's own class metadata, not guessed:**
///
///   YTISlimMetadataButtonSupportedRenderers . slimMetadataButtonRenderer : YTISlimMetadataButtonRenderer
///   YTISlimMetadataButtonRenderer           . button                     : YTIButtonSupportedRenderers
///   YTIButtonSupportedRenderers             . buttonRenderer             : YTIButtonRenderer
///   YTIButtonRenderer                       . text : YTIFormattedString, targetId : NSString, icon : YTIIcon
///
/// Each class names the next in its declared property *type*, which is what `tools/objc-classes.py`
/// prints and the only kind of chain that has ever worked in this project.
///
/// **`targetId` is why this needs no title matching.** It is a plain string the renderer carries,
/// so the button is recognised at tap time by a value this file wrote — not by comparing an
/// accessibility label against an English word, which is a test that fails on the owner's own
/// Arabic phone.
///
/// **The icon is painted on afterwards, deliberately.** `YTIIcon` wants an `iconType`, an enum
/// whose values are not readable from the binary in any form — so choosing one is guessing at
/// what draws. The Download Centre tab already made that refusal and this makes the same one: the
/// button YouTube built is given our symbol once it exists, and a build where that fails shows a
/// labelled button with no picture rather than the wrong picture.
///
/// **Not on the launch path.** This row is built when a video is opened, which is why the feature
/// can be on by default at all: the tab-bar work next door had to be moved off the launch and this
/// never was on it. The launch guard is still consulted, because a hook that stands down with the
/// others is one fewer thing to reason about when something goes wrong.
///

/// Ours, and nothing else's.
static NSString *const kSCIActionTargetId = @"albrhi.download.action";

/// Set on the action view YouTube built for our renderer, so the tap knows which button it is.
static char kSCIIsOurActionView;

/// How many of these rows the app actually *built*, counted separately from how many times it
/// asked us to fill one.
///
/// **Two different answers hide behind "no button": the class is never constructed, or it is
/// constructed and the method we hook is not the one it uses.** The first means the row is drawn
/// some other way entirely and no renderer can help; the second is a selector to find. One number
/// cannot say which, and this project has paid for that confusion on four features now.
static NSUInteger sciActionRowsBuilt = 0;

static NSUInteger sciActionRowsSeen = 0;
static NSUInteger sciActionRenderersAdded = 0;
static NSUInteger sciActionViewsFound = 0;
static NSUInteger sciActionTaps = 0;
static NSString *sciActionRowState = nil;

static void SCIReportActionRow(void) {
    [SCIYTDiagnostics recordActionRow:
        [NSString stringWithFormat:SCILocalized(@"diag_action_row"),
            (unsigned long)sciActionRowsBuilt,
            (unsigned long)sciActionRowsSeen, (unsigned long)sciActionRenderersAdded,
            (unsigned long)sciActionViewsFound, (unsigned long)sciActionTaps,
            sciActionRowState ?: SCILocalized(@"diag_action_row_nothing")]];
}

/// Sets one protobuf field, reporting rather than throwing.
///
/// KVC on purpose: these are GPBMessage subclasses whose fields resolve dynamically, so
/// `-respondsToSelector:` answers NO for a field `-setValue:forKey:` sets perfectly well. That is
/// recorded in CLAUDE.md and it is why this file reads as keys rather than as messages.
static BOOL SCISetField(id object, id value, NSString *key) {
    if (!object || !value) return NO;
    @try {
        [object setValue:value forKey:key];
        return YES;
    } @catch (NSException *exception) {
        sciActionRowState = [NSString stringWithFormat:SCILocalized(@"diag_action_row_refused"),
                             key, exception.reason ?: @"?"];
        return NO;
    }
}

/// Builds the renderer for one more button in the row.
static id SCIMakeActionRenderer(void) {
    Class supportedClass = NSClassFromString(@"YTISlimMetadataButtonSupportedRenderers");
    Class slimClass      = NSClassFromString(@"YTISlimMetadataButtonRenderer");
    Class buttonsClass   = NSClassFromString(@"YTIButtonSupportedRenderers");
    Class buttonClass    = NSClassFromString(@"YTIButtonRenderer");

    if (!supportedClass || !slimClass || !buttonsClass || !buttonClass) {
        sciActionRowState = SCILocalized(@"diag_action_row_classes");
        return nil;
    }

    id button = [[buttonClass alloc] init];
    if (!SCISetField(button, kSCIActionTargetId, @"targetId")) return nil;

    // The label, as the formatted string every other button in this row carries. A plain
    // NSString here is not a shorter label, it is a button that does not draw -- learned twice
    // already, by the Download Centre tab and by the History tab, and not worth learning again.
    Class stringClass = NSClassFromString(@"YTIFormattedString");
    SEL make = NSSelectorFromString(@"formattedStringWithString:");
    if (stringClass && [stringClass respondsToSelector:make]) {
        id title = ((id (*)(id, SEL, id))objc_msgSend)(stringClass, make,
                                                       SCILocalized(@"action_save"));
        if (title) SCISetField(button, title, @"text");
    }

    id buttons = [[buttonsClass alloc] init];
    if (!SCISetField(buttons, button, @"buttonRenderer")) return nil;

    id slim = [[slimClass alloc] init];
    if (!SCISetField(slim, buttons, @"button")) return nil;

    id supported = [[supportedClass alloc] init];
    if (!SCISetField(supported, slim, @"slimMetadataButtonRenderer")) return nil;

    return supported;
}

/// Whether a supported-renderer is the one this file made.
static BOOL SCIIsOurActionRenderer(id renderer) {
    if (!renderer) return NO;
    @try {
        id slim = SCISafeValueForKey(renderer, @"slimMetadataButtonRenderer");
        id buttons = slim ? SCISafeValueForKey(slim, @"button") : nil;
        id button = buttons ? SCISafeValueForKey(buttons, @"buttonRenderer") : nil;
        id target = button ? SCISafeValueForKey(button, @"targetId") : nil;
        return [target isKindOfClass:[NSString class]] &&
               [(NSString *)target isEqualToString:kSCIActionTargetId];
    } @catch (__unused NSException *exception) {
        return NO;
    }
}

/// Puts our mark on the button YouTube built, and marks the view as ours.
///
/// Found by asking each action view what it was built from rather than by comparing labels: the
/// renderer is passed to `-initWithSlimMetadataButtonSupportedRenderer:`, and where a build keeps
/// it under a readable name this is exact. Where it does not, the accessibility label is the
/// fallback -- and it is compared against *our own* string, which this file wrote, so it is not
/// the English-title matching this project refuses elsewhere.
static void SCIMarkOurActionView(UIView *row) {
    static UIImage *mark = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ mark = [UIImage systemImageNamed:@"arrow.down.circle"]; });

    Class actionClass = NSClassFromString(@"YTSlimVideoDetailsActionView");
    if (!actionClass) return;

    NSString *ours = SCILocalized(@"action_save");

    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:row];
    while (queue.count) {
        UIView *next = queue.firstObject;
        [queue removeObjectAtIndex:0];

        if ([next isKindOfClass:actionClass]) {
            if (![objc_getAssociatedObject(next, &kSCIIsOurActionView) boolValue]) {
                NSString *label = next.accessibilityLabel;
                if ([label isEqualToString:ours]) {
                    objc_setAssociatedObject(next, &kSCIIsOurActionView, @YES,
                                             OBJC_ASSOCIATION_RETAIN);
                    sciActionViewsFound++;
                    sciActionRowState = SCILocalized(@"diag_action_row_placed");

                    // The button, not the first image view -- the same finding the pivot tab
                    // cost: a UIButton's own image view either does not exist until it has an
                    // image or is overwritten on the button's next layout.
                    if (mark && [next respondsToSelector:@selector(button)]) {
                        UIButton *button = [(YTSlimVideoDetailsActionView *)next button];
                        if ([button isKindOfClass:[UIButton class]] &&
                            [button imageForState:UIControlStateNormal] != mark) {
                            [button setImage:mark forState:UIControlStateNormal];
                        }
                    }
                }
            }
            continue;
        }

        [queue addObjectsFromArray:next.subviews];
    }

    SCIReportActionRow();
}


///
/// **What that row actually is, measured on the device rather than assumed.**
///
/// The scan settled it:
///
///     (from _ASDisplayView)  0,0 390×48        <- the row
///       _ASDisplayView  12,0  96×48            <- the like/dislike pill
///       _ASDisplayView  185,0 205×48           <- five more, 41 wide each
///         ELMAnimatedVectorViewObjC / LOTAnimationView   <- the icons themselves
///
/// So the row is Texture (`_ASDisplayView` is an AsyncDisplayKit node's view) driven by the
/// element system: no UIButtons, no YouTube view class to hook, and nothing that answers a
/// selector worth guessing at. Every renderer-based approach is closed -- the class that would
/// have built the buttons, `YTSlimVideoDetailsActionView`, is never constructed in this build,
/// which the report has now said four times.
///
/// **What is open is the space between the two groups.** The left group ends at 108 and the
/// right begins at 185: seventy-seven points of nothing, on every video measured. A button
/// placed there sits in the row, at the row's own height, beside Like and Share -- which is what
/// was asked for.
///
/// Three rules this obeys, each of them paid for earlier this week:
///
///   - **the frame is written only when it differs.** Writing an equal frame from a layout pass
///     invalidates layout, which asks for another pass -- that is what kept the app from
///     launching two days ago;
///   - **nothing is brought to the front on every pass**, for the same reason;
///   - **and if there is no gap wide enough, nothing is placed at all** and the report says so.
///     A button overlapping Like is worse than no button, and guessing that the gap is always
///     there is exactly the kind of assumption this file exists to avoid.
///

static char kSCIBarButton;

static NSUInteger sciBarCellsBuilt = 0;
static NSUInteger sciBarButtonsPlaced = 0;
static NSString *sciBarState = nil;

static void SCIReportBar(void) {
    [SCIYTDiagnostics recordActionBar:
        [NSString stringWithFormat:SCILocalized(@"diag_action_bar"),
            (unsigned long)sciBarCellsBuilt, (unsigned long)sciBarButtonsPlaced,
            sciBarState ?: SCILocalized(@"diag_action_row_nothing")]];
}

/// The widest child that looks like the row itself.
static UIView *SCIRowInside(UIView *cell) {
    UIView *best = nil;
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:cell];

    while (queue.count) {
        UIView *next = queue.firstObject;
        [queue removeObjectAtIndex:0];

        CGSize size = next.bounds.size;
        if (size.width >= 300 && size.height > 20 && size.height <= 80) {
            if (!best || size.width > best.bounds.size.width) best = next;
        }
        [queue addObjectsFromArray:next.subviews];
    }
    return best;
}

/// The gap between the row's own groups, in the row's coordinates.
///
/// Measured from the direct children rather than chosen: the left group is wider on a video with
/// a like count than on one without, and a number written here would be right on one of them.
static CGRect SCIGapInRow(UIView *row, UIView *ours) {
    CGFloat rightEdgeOfLeft = 0;
    CGFloat leftEdgeOfRight = row.bounds.size.width;

    for (UIView *child in row.subviews) {
        if (child == ours || child.hidden) continue;
        CGRect frame = child.frame;
        if (frame.size.width <= 0) continue;

        CGFloat middle = CGRectGetMidX(frame);
        if (middle < row.bounds.size.width / 2.0) {
            rightEdgeOfLeft = MAX(rightEdgeOfLeft, CGRectGetMaxX(frame));
        } else {
            leftEdgeOfRight = MIN(leftEdgeOfRight, CGRectGetMinX(frame));
        }
    }

    CGFloat width = leftEdgeOfRight - rightEdgeOfLeft;
    if (width < 44) return CGRectNull;

    // Centred in the gap, at the row's height, with the same 41-point width its neighbours use.
    CGFloat button = MIN(44, width - 4);
    return CGRectMake(rightEdgeOfLeft + (width - button) / 2.0, 0, button, row.bounds.size.height);
}


///
/// **Finding the row by its shape, because it has no name of its own on this build.**
///
/// Three classes have now been hooked for this row and none of them is ever constructed here:
/// `YTSlimVideoScrollableDetailsActionsView`, `YTSlimVideoDetailsActionView` and
/// `YTSlimVideoScrollableActionBarCell` — all three present in the binary, all three at zero.
/// The row is Texture nodes inside an element-rendered cell, and `_ASDisplayView` is the class
/// of a thousand other things, so there is nothing left to hook by name.
///
/// So it is found by what it is: a view as wide as the list, about the height of a row, holding
/// an element-drawn icon somewhere under it. **The icon is the part that makes this honest** —
/// plenty of views are 390×48, and only the actions row has `ELMAnimatedVectorViewObjC` in it.
///
/// This is the technique this project normally refuses, and the refusal is about *identity*: a
/// frame or a subview index must never be used to decide *which button* something is. Here it
/// decides only *where there is room*, the icon check is the identity, and nothing is modified
/// but our own button's frame.
static BOOL SCIHasElementIcon(UIView *view, NSUInteger depth) {
    if (depth > 6) return NO;
    for (UIView *child in view.subviews) {
        if ([NSStringFromClass([child class]) isEqualToString:@"ELMAnimatedVectorViewObjC"]) return YES;
        if (SCIHasElementIcon(child, depth + 1)) return YES;
    }
    return NO;
}

static UIView *SCIFindActionsRow(UIView *root) {
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:root];
    NSUInteger walked = 0;

    while (queue.count && walked < 600) {
        UIView *next = queue.firstObject;
        [queue removeObjectAtIndex:0];
        walked++;

        CGSize size = next.bounds.size;
        if (!next.hidden && size.width >= 300 && size.height >= 36 && size.height <= 64 &&
            next.subviews.count >= 2 && SCIHasElementIcon(next, 0)) {
            return next;
        }

        for (UIView *child in next.subviews) {
            if (!child.hidden) [queue addObject:child];
        }
    }
    return nil;
}


%group SCIActionBar

%hook YTAsyncCollectionView

- (void)layoutSubviews {
    %orig;

    if (SCIYTStoodDown() || !SCIPrefEnabled(SCIPrefActionRowButton)) return;

    @try {
        UIButton *save = objc_getAssociatedObject(self, &kSCIBarButton);

        // Searched only when there is something to search for. The row is found once and kept;
        // a walk of six hundred views on every layout pass of a collection view is the kind of
        // cost that turns into a report about the app being slow.
        if (save && save.superview && save.superview.window) {
            CGRect wanted = SCIGapInRow(save.superview, save);
            if (!CGRectIsNull(wanted) && !CGRectEqualToRect(save.frame, wanted)) save.frame = wanted;
            return;
        }

        UIView *row = SCIFindActionsRow(self);
        if (!row) { sciBarState = SCILocalized(@"diag_action_bar_no_row"); return; }

        sciBarCellsBuilt++;

        if (!save) {
            save = [UIButton buttonWithType:UIButtonTypeSystem];
            [save setImage:[UIImage systemImageNamed:@"arrow.down.circle"]
                  forState:UIControlStateNormal];
            save.accessibilityLabel = SCILocalized(@"action_save");
            save.tintColor = [UIColor labelColor];
            [save addTarget:self action:@selector(sciBarSaveTapped:)
           forControlEvents:UIControlEventTouchUpInside];
            objc_setAssociatedObject(self, &kSCIBarButton, save, OBJC_ASSOCIATION_RETAIN);
        }

        CGRect wanted = SCIGapInRow(row, save);
        if (CGRectIsNull(wanted)) {
            sciBarState = SCILocalized(@"diag_action_bar_no_room");
            SCIReportBar();
            return;
        }

        save.frame = wanted;
        [row addSubview:save];
        sciBarButtonsPlaced++;
        sciBarState = SCILocalized(@"diag_action_bar_placed");
        SCIReportBar();
    } @catch (NSException *exception) {
        sciBarState = [NSString stringWithFormat:SCILocalized(@"diag_action_row_threw"),
                       exception.reason ?: @"?"];
        SCIReportBar();
    }
}

%new(v@:@)
- (void)sciBarSaveTapped:(UIButton *)sender {
    UIViewController *host = SCIControllerForView(sender);
    if (host) {
        [SCIYTDownload presentFrom:host];
    } else {
        sciBarState = SCILocalized(@"diag_action_row_no_host");
        SCIReportBar();
    }
}

%end

%hook YTSlimVideoScrollableActionBarCell

- (void)didMoveToWindow {
    %orig;
    if (!self.window) return;

    sciBarCellsBuilt++;
    SCIReportBar();
}

- (void)layoutSubviews {
    %orig;

    if (SCIYTStoodDown() || !SCIPrefEnabled(SCIPrefActionRowButton)) return;

    @try {
        UIView *row = SCIRowInside(self);
        if (!row) { sciBarState = SCILocalized(@"diag_action_bar_no_row"); return; }

        UIButton *save = objc_getAssociatedObject(self, &kSCIBarButton);
        if (!save) {
            save = [UIButton buttonWithType:UIButtonTypeSystem];
            [save setImage:[UIImage systemImageNamed:@"arrow.down.circle"]
                  forState:UIControlStateNormal];
            save.accessibilityLabel = SCILocalized(@"action_save");
            save.tintColor = [UIColor labelColor];
            [save addTarget:self action:@selector(sciBarSaveTapped:)
           forControlEvents:UIControlEventTouchUpInside];
            objc_setAssociatedObject(self, &kSCIBarButton, save, OBJC_ASSOCIATION_RETAIN);
        }

        if (save.superview != row) {
            [row addSubview:save];
            sciBarButtonsPlaced++;
        }

        CGRect wanted = SCIGapInRow(row, save);
        if (CGRectIsNull(wanted)) {
            save.hidden = YES;
            sciBarState = SCILocalized(@"diag_action_bar_no_room");
            SCIReportBar();
            return;
        }

        save.hidden = NO;

        // Only when it differs. An equal frame written from -layoutSubviews still invalidates
        // layout, and that is the loop that stopped the app launching.
        if (!CGRectEqualToRect(save.frame, wanted)) save.frame = wanted;

        if (!sciBarState || ![sciBarState isEqualToString:SCILocalized(@"diag_action_bar_placed")]) {
            sciBarState = SCILocalized(@"diag_action_bar_placed");
            SCIReportBar();
        }
    } @catch (NSException *exception) {
        sciBarState = [NSString stringWithFormat:SCILocalized(@"diag_action_row_threw"),
                       exception.reason ?: @"?"];
        SCIReportBar();
    }
}

%new(v@:@)
- (void)sciBarSaveTapped:(UIButton *)sender {
    UIViewController *host = SCIControllerForView(sender);
    if (host) {
        [SCIYTDownload presentFrom:host];
    } else {
        sciBarState = SCILocalized(@"diag_action_row_no_host");
        SCIReportBar();
    }
}

%end

%end


%group SCIActionRow

%hook YTSlimVideoScrollableDetailsActionsView

- (void)createActionViewsFromSupportedRenderers:(NSArray *)renderers {
    if (SCIYTStoodDown() || !SCIPrefEnabled(SCIPrefActionRowButton) ||
        ![renderers isKindOfClass:[NSArray class]]) {
        %orig;
        return;
    }

    sciActionRowsSeen++;

    @try {
        // Never twice. This is called again when the video changes and on a page style change,
        // and a row that gains a button each time is the pivot bar's own old bug one screen over.
        BOOL already = NO;
        for (id renderer in renderers) {
            if (SCIIsOurActionRenderer(renderer)) { already = YES; break; }
        }

        if (!already) {
            id ours = SCIMakeActionRenderer();
            if (ours) {
                NSMutableArray *widened = [renderers mutableCopy];
                [widened addObject:ours];
                sciActionRenderersAdded++;
                sciActionRowState = SCILocalized(@"diag_action_row_added");
                %orig(widened);

                // After YouTube has built the views, never before: there is nothing to paint
                // until the button exists.
                SCIMarkOurActionView(self);
                return;
            }
        }
    } @catch (NSException *exception) {
        // A button in a row is a convenience; the row is not. Anything thrown here costs the
        // button and leaves YouTube's own row exactly as it was.
        sciActionRowState = [NSString stringWithFormat:SCILocalized(@"diag_action_row_threw"),
                             exception.reason ?: @"?"];
        SCILogV(@"action row: %@", exception.reason);
    }

    %orig;
    SCIMarkOurActionView(self);
}

%end


%hook YTSlimVideoScrollableDetailsActionsView

/// Counted here and nowhere else: `-didMoveToWindow` fires once per instance and changes nothing,
/// so it can say "the app built one of these" without being on a layout path.
- (void)didMoveToWindow {
    %orig;
    sciActionRowsBuilt++;
    SCIReportActionRow();
}

%end


%hook YTSlimVideoDetailsActionView

- (void)didTapButton:(id)sender {
    if (![objc_getAssociatedObject(self, &kSCIIsOurActionView) boolValue]) {
        %orig;
        return;
    }

    sciActionTaps++;
    SCIReportActionRow();

    // Deliberately without %orig. Our renderer carries no command, so YouTube has nothing to do
    // with the tap; calling through would only give it a button it does not recognise to reason
    // about.
    UIViewController *host = SCIControllerForView(self);
    if (host) {
        [SCIYTDownload presentFrom:host];
    } else {
        sciActionRowState = SCILocalized(@"diag_action_row_no_host");
        SCIReportActionRow();
    }
}

%end

%end


%ctor {
    // A `%hook` on an absent class never attaches, so this costs nothing on a build that draws
    // its row some other way -- and the report says which, rather than leaving "no button" to
    // mean two things at once.
    if (NSClassFromString(@"YTSlimVideoScrollableDetailsActionsView")) {
        %init(SCIActionRow);
        sciActionRowState = SCILocalized(@"diag_action_row_hooked");
    } else {
        sciActionRowState = SCILocalized(@"diag_action_row_absent");
    }

    // Both classes in one group: the cell if this build ever builds one, and the collection view
    // that certainly exists -- the scan found `YTAsyncCollectionView 0,0 390×577` under the
    // player on the device.
    if (NSClassFromString(@"YTAsyncCollectionView")) {
        %init(SCIActionBar);
    } else {
        sciBarState = SCILocalized(@"diag_action_bar_absent");
    }
    SCIReportBar();

    // **Written to the report here, and this is the whole of what 1.30.0 got wrong.**
    //
    // The state was set and never recorded, so the page printed "no action row has been built"
    // -- the empty-slot sentence -- whether the class was missing, present and never called, or
    // hooked and waiting. One sentence for three different investigations, which is the exact
    // failure this file's own diagnostics were written to prevent, one level up: setting a
    // variable is not reporting it.
    SCIReportActionRow();
}
