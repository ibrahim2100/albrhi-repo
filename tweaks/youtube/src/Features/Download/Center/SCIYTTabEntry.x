#import <UIKit/UIKit.h>
#import "shared/src/SCIKVC.h"
#import "../../../Tweak.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import "SCIYTDownloadCenter.h"
#import "SCIYTIcon.h"
#import "../../../SCILog.h"
#import "../../../Prefs.h"
#import "../../../SCIYTLaunchGuard.h"
#import "../../../Localization/SCILocalize.h"
#import "../../../Diagnostics/SCIYTDiagnostics.h"
#import "../../Tabs/SCIYTTabBar.h"
#import "../../Tabs/SCIYTHistoryTab.h"

///
/// The way into the Download Centre, as one of YouTube's own tabs.
///
/// The first version of this drew a red circle over the tab bar. It worked and it looked
/// exactly like what it was: a button sitting on top of the bar rather than in it, with no
/// label, no selected state, no indicator dot, and no share of the width when the bar
/// re-laid itself out.
///
/// This does not draw anything. YouTube's tab bar is built from a protobuf -- a
/// YTIPivotBarRenderer holding one YTIPivotBarItemRenderer per tab -- and the bar is handed
/// that renderer through -setRenderer:. One more item is appended on the way through, and
/// YouTube then builds the tab itself: its own item view, its own label font, its own
/// selection behaviour, its own spacing. There is nothing to keep in sync because there is
/// nothing of ours being drawn.
///
/// **The fields are set with KVC, deliberately.** These are GPBMessage subclasses and their
/// fields are resolved dynamically, so -respondsToSelector: answers NO for a field that
/// -setValue:forKey: sets perfectly well. That is recorded in CLAUDE.md and it is the whole
/// reason this reads as key paths rather than as method calls.
///
/// **The icon is not set through the renderer.** A YTIIcon wants an iconType, which is an
/// enum whose names are not in the binary in any form that can be read -- so choosing a
/// value would be guessing at what draws, which is the one thing this project does not do.
/// The item view's own image view is given our symbol after YouTube has built it. If that
/// fails the tab is a label with no icon, which is a smaller loss than a wrong picture.
///
/// The failure is soft at every step. If the pivot bar classes are not there, or the append
/// throws, no tab appears and the old floating button is left in place instead -- so the
/// entrance never disappears entirely.
///

/// Ours, and nothing else's. Long enough that YouTube could not have one like it.
static NSString *const kSCIPivotIdentifier = @"albrhi.downloads.pivot";

/// Marks the one item view showing our tab. Item views are reused between tabs, so this
/// belongs on the view and not in a variable.
static char kSCIIsOurItemView;

/// Marks a bar whose deferred rebuild has already been queued. See -setRenderer:.
static char kSCIDeferredOnce;

/// Which of YouTube's own tabs was open before ours took over.
///
/// Kept because telling the bar our identifier is selected leaves it holding a name it has
/// no page for. YouTube works out the next transition from whatever it thinks is currently
/// selected, and an identifier it does not recognise gives it nothing to transition *from*
/// -- so it falls back to its default, which is Home. Every tab tapped after visiting the
/// Centre opened Home, whichever tab was tapped.
///
/// So its own answer is put back before it is asked to move, and the pair it computes from
/// is one it knows.
static NSString *sciPivotBeforeOurs = nil;


/// Whether a pivot item renderer is the one we added.
static BOOL SCIIsOurRenderer(id renderer) {
    if (!renderer) return NO;

    @try {
        return [SCISafeValueForKey(renderer, @"pivotIdentifier") isEqualToString:kSCIPivotIdentifier];
    } @catch (__unused NSException *exception) {
        return NO;
    }
}

/// Builds one tab, as the protobuf YouTube expects.
static id SCIMakePivotItem(void) {
    Class itemClass = NSClassFromString(@"YTIPivotBarItemRenderer");
    Class wrapperClass = NSClassFromString(@"YTIPivotBarSupportedRenderers");
    if (!itemClass || !wrapperClass) return nil;

    id item = [[itemClass alloc] init];
    [item setValue:kSCIPivotIdentifier forKey:@"pivotIdentifier"];

    // The label, as the formatted string every other tab carries. A plain NSString in this
    // field is not a shorter label, it is a tab that does not draw.
    Class stringClass = NSClassFromString(@"YTIFormattedString");
    SEL make = NSSelectorFromString(@"formattedStringWithString:");
    if (stringClass && [stringClass respondsToSelector:make]) {
        id title = ((id (*)(id, SEL, id))objc_msgSend)(stringClass, make,
                                                       SCILocalized(@"dl_centre_title"));
        if (title) [item setValue:title forKey:@"title"];
    }

    id wrapper = [[wrapperClass alloc] init];
    [wrapper setValue:item forKey:@"pivotBarItemRenderer"];
    return wrapper;
}

/// Puts our mark into the item view YouTube built.
///
/// **The button, not the first image view.** The first version of this walked for a
/// UIImageView and set its image, and the tab came up blank. A pivot tab is drawn by a
/// YTQTMButton -- the controller has a -YTQTMButtonFromPivotBarItemView: to fetch one, so
/// the button is what holds the picture -- and a UIButton's own image view either does not
/// exist until it has an image or is overwritten by the button on its next layout. Setting
/// it through the button is what sticks, and it also lets the selected state be set, which
/// the image view alone could not do.
///
/// Returns whether anything was found to paint, so the report can say which.
static BOOL SCIPaintIcon(UIView *view) {
    if (!view) return NO;

    // **Held here, not fetched each time, so identity is stable.**
    //
    // The comparison below is what stops a repaint on every layout pass, and it compares
    // pointers. `+downloadMarkOfSize:filled:` answers from an NSCache, which is free to evict
    // under memory pressure and hand back a freshly drawn image with a different address --
    // and the moment it did, the comparison would stop matching and the loop would be back.
    // A static holds the two images for the life of the process, which is a few kilobytes.
    static UIImage *mark = nil;
    static UIImage *filled = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        mark = [SCIYTIcon downloadMarkOfSize:24 filled:NO];
        filled = [SCIYTIcon downloadMarkOfSize:24 filled:YES];
    });
    if (!mark) return NO;

    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:view];
    UIImageView *fallback = nil;

    while (queue.count) {
        UIView *next = queue.firstObject;
        [queue removeObjectAtIndex:0];

        if ([next isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)next;

            // **Only when it is not already ours — this is what "idempotent" has to mean here.**
            //
            // `-setImage:forState:` marks the button as needing layout whether or not the image
            // changed. Called from `-layoutSubviews`, as it is, that asks for another layout
            // pass, which paints again: a loop on the main thread, on the tab bar, which is
            // built while the app is still showing its logo. The comment on the caller said
            // running every pass "costs a cache lookup"; it cost the launch.
            if ([button imageForState:UIControlStateNormal] != mark) {
                [button setImage:mark forState:UIControlStateNormal];
                [button setImage:filled forState:UIControlStateSelected];
                [button setImage:filled forState:UIControlStateHighlighted];
                button.tintColor = SCIAccent();
            }
            return YES;
        }

        // Remembered but not used yet: a button deeper in the tree is the better answer,
        // and taking the first image view would stop the search before finding it.
        if (!fallback && [next isKindOfClass:[UIImageView class]]) fallback = (UIImageView *)next;

        [queue addObjectsFromArray:next.subviews];
    }

    if (fallback) {
        // Same rule as the button above: assigning an identical image still invalidates layout.
        if (fallback.image != mark) {
            fallback.image = mark;
            fallback.tintColor = SCIAccent();
        }
        return YES;
    }
    return NO;
}


#pragma mark - The bar

/// Declared because the hooks below only forward-declare the classes, and a hook body may not send them a message.
@interface YTPivotBarView : UIView
@end
@interface YTFloatingPivotBarView : UIView
@end

///
/// **What happens to the array of tabs, for either bar.** Called from `-setRenderer:` *before* `%orig`, so YouTube builds its tabs from the array this
/// leaves behind. Written once and shared, because 21.47.6 has two bars: the classic `YTPivotBarView`, and `YTFloatingPivotBarView`, the glass bar
/// iOS 27 gets (`ios27EnableLiquidGlass`, `YTFloatingBarExperiment`). A bar of the second kind has no `-setRenderer:` of ours on it, so on iOS 27 the
/// tab was never added: the bar was hooked, and the bar on screen was a different class.
///
static void SCIYTPivotPrepare(UIView *bar, id renderer) {

    if (!renderer) return;

    if (SCIYTStoodDown() || !SCIPrefEnabled(SCIPrefPivotBar)) return;

    //
    // **Not during the launch. The same change, made a second later.**
    //
    // This is where the app stopped starting. YouTube calls `-setRenderer:` while it builds the
    // bar, which is before anything has been drawn and while iOS's own watchdog is counting --
    // so a fault here does not cost a tab, it costs the app, and it cannot be undone from
    // inside an app that will not open. The block had been dead code for months and was woken
    // by a fix to a shared helper, which is why nothing in this tweak's own history pointed at
    // it.
    //
    // So the bar is left exactly as YouTube built it until the app is active, and then this
    // same method is called again with the renderer it was given. The mutation is unchanged;
    // only its moment is. Whatever it costs is now paid by a running app, in front of somebody
    // who can switch it off.
    //
    if (!SCIYTAppIsActive()) {
        // **Asked for once per bar.** The re-application calls this same method again, and
        // YouTube calls it itself on every page style change, rotation and account switch -- so
        // without this a bar can queue one deferred rebuild per call and then rebuild itself
        // once per queued block. A device reported YouTube stuck again after a licence and a
        // settings change, cured by clearing the app's data; the only state on this path that
        // clearing removes is the stored tab arrangement below.
        if (objc_getAssociatedObject(bar, &kSCIDeferredOnce)) return;
        objc_setAssociatedObject(bar, &kSCIDeferredOnce, @YES, OBJC_ASSOCIATION_RETAIN);

        __weak UIView *weakBar = bar;
        __weak id weakRenderer = renderer;
        SCIYTWhenActive(^{
            UIView *again = weakBar;
            id held = weakRenderer;
            // Both gone means the bar was rebuilt while we waited, and YouTube's own rebuild
            // will have come back through here with the app active. Nothing to do.
            if (again && held) ((void (*)(id, SEL, id))objc_msgSend)(again, @selector(setRenderer:), held);
        });
        return;
    }

    // Two things happen to this array and they are deliberately in one hook rather than
    // two: our tab is appended, and then the whole bar is arranged. Written as separate
    // %hooks in separate files they would still both run, but which ran first would decide
    // whether our own tab could be placed anywhere but last -- and hook order is an
    // artefact of install order, not something a reader of either file could see.
    @try {
        NSMutableArray *items = SCISafeValueForKey(renderer, @"itemsArray");

        // Both tabs are offered here and switched off in one place only: the arranging
        // screen. The Download Centre had a switch of its own until 1.25.0, which was a
        // second answer to the question that screen already asks -- the same mistake
        // History's own switch was, removed for the same reason.
        //
        // Appended once, and never when a tab for it already exists: YouTube ships a
        // History tab on some accounts, and two of them is worse than none.
        if (SCIYTHistoryTabWanted() && items) {
            BOOL haveHistory = NO;
            for (id entry in items) {
                if (SCIYTIsHistoryRenderer(SCIYTTabBarInnerRenderer(entry))) {
                    haveHistory = YES;
                    break;
                }
            }
            // No count check. History is only ever wanted when an arrangement exists, and
            // the arrangement is what makes room -- checking the count here is what made
            // hiding the create button fail to free a slot.
            if (!haveHistory) {
                id history = SCIYTMakeHistoryItem();
                if (history) [items addObject:history];
            }
        }

        // Appended once. -setRenderer: is called again on every page style change, on
        // rotation, and when the account switches; without this the bar would gain a tab
        // each time until it ran out of item views.
        BOOL already = NO;
        for (id entry in items) {
            if (SCIIsOurRenderer(SCIYTTabBarInnerRenderer(entry))) { already = YES; break; }
        }

        // The bar holds six item views and no more. Five tabs is the usual shape, so ours
        // is the sixth and it fits -- but a build that already fills all six gets left
        // alone rather than handed a seventh that has nowhere to be drawn.
        if (already) {
            // Nothing to say. This runs on every style change and a report that repeats
            // itself is one nobody reads to the end of.
        } else if (!items) {
            [SCIYTDiagnostics recordTabState:@"the bar has no items array"];
        } else if (items.count >= SCIYTTabBarMaximum && !SCIYTTabBarWillArrange()) {
            // Full, and nothing is going to remove anything. With an arrangement stored the
            // append goes ahead and the arranger settles the count afterwards -- one place
            // enforcing the limit instead of two that can each refuse in turn, which is how
            // hiding the create button and adding History left the Download Centre with no
            // tab and the old floating button back in its place.
            [SCIYTDiagnostics recordTabState:
                [NSString stringWithFormat:@"the bar is already full (%lu tabs)",
                    (unsigned long)items.count]];
        } else {
            id wrapper = SCIMakePivotItem();
            if (!wrapper) {
                [SCIYTDiagnostics recordTabState:@"the pivot bar classes are not on this build"];
            } else {
                [items addObject:wrapper];
                [SCIYTDiagnostics recordTabState:
                    [NSString stringWithFormat:@"item added, now %lu tabs",
                        (unsigned long)items.count]];
            }
        }
        // After both appends, never before: a tab has to be in the array for the stored
        // order to be able to place it anywhere other than the end.
        SCIYTTabBarArrange(items);

        // The last word on the count, and it belongs here rather than only inside the
        // arranger. `YTPivotBarView` declares itemView1 … itemView6 and no seventh, so an
        // array longer than six is not a preference this tweak is failing to honour -- it
        // is a bar with items that cannot be drawn. Every path that adds anything passes
        // through this line, including one added later by someone who has not read the
        // arranger, which is the whole point of a guard sitting at the exit.
        if (items.count > SCIYTTabBarMaximum) {
            [SCIYTDiagnostics recordTabState:
                [NSString stringWithFormat:@"%lu tabs trimmed to %lu",
                    (unsigned long)items.count, (unsigned long)SCIYTTabBarMaximum]];
            [items removeObjectsInRange:NSMakeRange(SCIYTTabBarMaximum,
                                                    items.count - SCIYTTabBarMaximum)];
        }
    } @catch (NSException *exception) {
        [SCIYTDiagnostics recordTabState:
            [NSString stringWithFormat:@"refused: %@", exception.reason ?: @"?"]];
    }
}

///
/// **The Centre page comes down whenever the bar stops saying our name, whichever door says so.**
///
/// `-setSelectedPivotIdentifier:` and `-didTapItemWithRenderer:` were the two doors this knew, and on iOS 27 the glass bar has more: its items can be
/// icon-only (`YTFloatingBarExperiment +isIconsOnly`), which tap through `-didTapItemWithIconOnlyItemRenderer:…` and not `-didTapItemWithRenderer:`,
/// and the bars themselves select through `-selectItemWithPivotIdentifier:` (a tap, a drag of the selection pill, or the app restoring a tab). A tab
/// chosen through a door that was not hooked left our page in the content area on top of every page YouTube then showed. **Reported by the owner on
/// iOS 27; not reproduced in the simulator with a signed-out account (taps and a pill drag all came back to Home), so the cause is an inference.**
/// Every door that names a pivot other than ours now takes the page down, and counts that it did, so a report says which door it was.
///
static NSUInteger sciCentreDroppedBy[3] = {0, 0, 0};   // classic bar select, controller update, glass bar select

static void SCIYTCentreSelectionChanged(NSString *identifier, NSUInteger door) {
    if (![identifier isKindOfClass:[NSString class]] || identifier.length == 0) return;
    if ([identifier isEqualToString:kSCIPivotIdentifier]) return;
    if (![SCIYTDownloadCenter isShownInPivotBar]) return;

    [SCIYTDownloadCenter removeFromPivotBar];
    sciPivotBeforeOurs = nil;
    if (door < 3) sciCentreDroppedBy[door]++;
}

NSString *SCIYTCentreDropReport(void) {
    return [NSString stringWithFormat:@"page taken down by: bar select %lu, controller update %lu, glass bar select %lu",
            (unsigned long)sciCentreDroppedBy[0], (unsigned long)sciCentreDroppedBy[1], (unsigned long)sciCentreDroppedBy[2]];
}

%hook YTPivotBarView

- (void)setRenderer:(id)renderer {
    SCIYTPivotPrepare((UIView *)self, renderer);
    %orig;
}

- (void)selectItemWithPivotIdentifier:(NSString *)identifier {
    %orig;
    SCIYTCentreSelectionChanged(identifier, 0);
}

%end

// The glass bar. Its own group, installed only where the class is in the build and answers `-setRenderer:` with the encoding the classic bar's does.
%group SCIYTFloatingBar
%hook YTFloatingPivotBarView

- (void)setRenderer:(id)renderer {
    SCIYTPivotPrepare((UIView *)self, renderer);
    %orig;
}

- (void)selectItemWithPivotIdentifier:(NSString *)identifier {
    %orig;
    SCIYTCentreSelectionChanged(identifier, 2);
}

%end
%end

static BOOL sciFloatingBarInstalled = NO;
static NSString *sciFloatingBarNote = @"not tried";

static void SCIYTTryInstallFloatingBar(void) {
    if (sciFloatingBarInstalled) return;
    Class bar = NSClassFromString(@"YTFloatingPivotBarView");
    if (!bar) { sciFloatingBarNote = @"class not in this build"; return; }
    Method method = class_getInstanceMethod(bar, @selector(setRenderer:));
    const char *encoding = method ? method_getTypeEncoding(method) : NULL;
    if (!encoding || strcmp(encoding, "v24@0:8@16") != 0) {
        sciFloatingBarNote = [NSString stringWithFormat:@"-setRenderer: %s", encoding ? "has another encoding" : "is missing"];
        return;
    }
    %init(SCIYTFloatingBar);
    sciFloatingBarInstalled = YES;
    sciFloatingBarNote = @"installed";
}

/// What the report says about the glass bar.
NSString *SCIYTFloatingBarReport(void) {
    return sciFloatingBarNote;
}

%ctor {
    %init;
    SCIYTTryInstallFloatingBar();
    // A class that is not there yet at load is asked again once the app has launched.
    if (!sciFloatingBarInstalled) {
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:nil
                                                      usingBlock:^(NSNotification *note) { SCIYTTryInstallFloatingBar(); }];
    }
}


#pragma mark - The tab itself

%hook YTPivotBarItemView

- (void)setRenderer:(id)renderer {
    %orig;

    // Cast because inside a %hook, self is the hooked class, which Logos only
    // forward-declares -- it has no way to know it descends from UIView.
    // Marked on the view itself rather than remembered in a variable. YTPivotBarItemView
    // has a -setRenderer: and no -renderer, so on the next layout pass there is no way to
    // ask the view what it is showing -- and item views are reused, so one global "ours"
    // flag would paint whichever tab inherited the view next.
    // Two tabs of ours can share this class, so the association records *which* -- a bare
    // yes/no would paint the download arrow onto History the moment a view was reused.
    NSString *mark = SCIIsOurRenderer(renderer) ? @"downloads"
                   : (SCIYTIsHistoryRenderer(renderer) ? @"history" : nil);
    objc_setAssociatedObject(self, &kSCIIsOurItemView, mark, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    if (!mark) return;

    BOOL painted = NO;
    if ([mark isEqualToString:@"history"]) painted = SCIYTPaintHistoryIcon((UIView *)self);
    else painted = SCIPaintIcon((UIView *)self);
    [SCIYTDiagnostics recordTabState:
        painted ? @"tab built, mark painted" : @"tab built, nothing found to paint"];
}

/// Painted again on layout, because once is not enough.
///
/// -setRenderer: can arrive before the button exists -- the tab's insides are built lazily
/// -- and the button reloads its own image when its state changes. A tab that came up blank
/// and stayed blank is what this is for; it is idempotent, so running on every pass costs a
/// cache lookup.
- (void)layoutSubviews {
    %orig;

    if (SCIYTStoodDown()) return;

    NSString *mark = objc_getAssociatedObject(self, &kSCIIsOurItemView);
    if ([mark isEqualToString:@"history"]) SCIYTPaintHistoryIcon((UIView *)self);
    else if (mark) SCIPaintIcon((UIView *)self);
}

%end


#pragma mark - What is actually in the content area

///
/// Reports the container's subviews after a tab change, and exists because three fixes for
/// one symptom were three guesses.
///
/// What is known now and was not before: the selection moves correctly. The bar reported
/// FEwhat_to_watch, then FEshorts, then FEsubscriptions, and we wrote nothing into any of
/// them. So the tab YouTube thinks is chosen is the tab that was tapped, and the thing that
/// does not follow is the content — which is a different fault from every one so far.
///
/// Two explanations remain and they need opposite fixes, so guessing between them is worth
/// nothing: either something of ours is still in the container covering YouTube's page, or
/// YouTube's own content is not being swapped at all. A list of what is in the container,
/// in order, with sizes, separates them in one reading. Ours would be named; a stale page of
/// YouTube's own would not.
///
/// Taken a runloop turn late, deliberately: at the moment of the tap the swap has not
/// happened yet, and a snapshot from before the event is a snapshot of the wrong thing.
///
static void SCIReportContentStack(UIViewController *bar) {
    UIView *container = bar.view.superview;
    if (!container) {
        [SCIYTDiagnostics recordTabState:@"content: the bar has no container"];
        return;
    }

    NSMutableString *out = [NSMutableString stringWithString:@"content now:"];
    NSUInteger index = 0;

    for (UIView *view in container.subviews) {
        CGRect frame = view.frame;
        [out appendFormat:@"\n      [%lu] %@ %@%@%.0f×%.0f",
            (unsigned long)index++,
            NSStringFromClass([view class]),
            view.hidden ? @"hidden " : @"",
            view.alpha < 0.99 ? @"faded " : @"",
            frame.size.width, frame.size.height];
    }

    [SCIYTDiagnostics recordTabState:out];
}


#pragma mark - The tap

/// Declared because the hook calls it on self. Inside a %hook, self is the hooked class and
/// Logos only forward-declares it, so a selector sent to self needs to be visible from here.
@interface YTPivotBarViewController : UIViewController
- (void)selectItemWithPivotIdentifier:(NSString *)identifier;
@end

%hook YTPivotBarViewController

// The bar's own "show this item as selected" step, reached by taps, pill drags and restores alike.
- (void)updateViewsWithSelectedPivotIdentifier:(NSString *)identifier {
    %orig;
    SCIYTCentreSelectionChanged(identifier, 1);
}

/// The one place every route through the bar passes.
///
/// Taking the page down only on a tap was the mistake, and it read as correct because a tap
/// is how a person leaves a tab. It is not how the *app* leaves one. A modal being dismissed
/// restores a selection, a notification opens a tab, YouTube's own code calls
/// -selectItemWithPivotIdentifier: — none of those is a tap, and after any of them our page
/// was still sitting in the content area, on top, while YouTube swapped its pages underneath
/// it. Every tab then showed the same thing, which is exactly what it looked like.
///
/// So the page comes down whenever the bar stops saying our name, whoever said so. A tap is
/// now one caller of this rather than the only one that works.
- (void)setSelectedPivotIdentifier:(NSString *)identifier {
    %orig;

    if (![identifier isEqualToString:kSCIPivotIdentifier]) {
        [SCIYTDownloadCenter removeFromPivotBar];

        // And the remembered tab is forgotten here, which is the part 1.11.0 missed.
        //
        // It was only ever cleared on the way out through a tap. Leave the Centre any other
        // way -- and playing something is exactly that, the full player is a modal and
        // dismissing it restores a selection -- and it survived, holding the name of a tab
        // from a visit that had already ended.
        //
        // The next tap then wrote that stale name into the selection before %orig, so
        // YouTube computed its move from a tab you were no longer on. When the stale name
        // happened to be the tab you tapped, it saw no move to make and did nothing: the
        // content stayed on whichever page you were last in, whatever you tapped. That is
        // the "it sticks on Home, or on You, depending where I was" exactly.
        //
        // Cleared at the same point the page comes down, so the two can no longer disagree.
        sciPivotBeforeOurs = nil;
    }
}

- (void)didTapItemWithRenderer:(id)renderer {
    if (!SCIIsOurRenderer(renderer)) {
        // Leaving. The page comes down first so YouTube's own tab is not laid out behind
        // ours -- and it is taken down whether or not it was up, which costs nothing and
        // means there is no state to get wrong.
        [SCIYTDownloadCenter removeFromPivotBar];

        // And the bar is handed back its own answer before it is asked to move.
        //
        // %orig works out the transition from what it believes is selected, and what it
        // believed was our identifier -- which names no page it has. Given nothing to
        // transition from it went to its default, so every tab tapped after a visit to the
        // Centre opened Home. Restoring first means the pair it computes from is one it
        // knows, and the tab actually tapped is where it goes.
        // Only while the bar actually believes ours is the selected tab.
        //
        // That condition is the whole correctness of this, and leaving it implicit is what
        // went wrong: restoring is repairing an answer we broke, so if we did not break it
        // there is nothing to repair and writing anything is inventing a transition YouTube
        // did not ask for. Checked rather than assumed, because "we remembered a tab" and
        // "we are on our tab" stopped being the same thing the moment anything but a tap
        // could take the page down.
        NSString *believed = nil;
        @try {
            believed = SCISafeValueForKey(self, @"selectedPivotIdentifier");
        } @catch (__unused NSException *exception) { }

        if (sciPivotBeforeOurs && [believed isEqualToString:kSCIPivotIdentifier]) {
            @try {
                [self setValue:sciPivotBeforeOurs forKey:@"selectedPivotIdentifier"];
            } @catch (__unused NSException *exception) { }
        }

        [SCIYTDiagnostics recordTabState:
            [NSString stringWithFormat:@"leaving: bar said %@, we remembered %@",
                believed ?: @"nothing", sciPivotBeforeOurs ?: @"nothing"]];

        sciPivotBeforeOurs = nil;

        %orig;

        // Weak, because this outlives the call by a runloop turn and the bar is YouTube's.
        __weak UIViewController *weakBar = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (weakBar) SCIReportContentStack(weakBar);
        });
        return;
    }

    // %orig is deliberately not reached. Our item carries no browse endpoint YouTube could
    // resolve, and asking it to navigate to a page that does not exist is how a tab bar
    // ends up on a blank screen it cannot leave.
    SCILogV(@"tab: download centre");

    // In the content area, under the bar, the way Home and You are. Presenting it slid the
    // whole screen up over YouTube and covered the tab bar, which read as something bolted
    // on -- because a modal is exactly that.
    if ([SCIYTDownloadCenter showInsidePivotBar:self]) {
        [SCIYTDiagnostics recordTabState:@"page shown in the content area"];

        // Remembered before it is overwritten, and only the first time -- tapping our own
        // tab twice must not record our own identifier as the one to go back to.
        if (!sciPivotBeforeOurs) {
            @try {
                NSString *current = SCISafeValueForKey(self, @"selectedPivotIdentifier");
                if ([current isKindOfClass:[NSString class]] &&
                    ![current isEqualToString:kSCIPivotIdentifier]) {
                    sciPivotBeforeOurs = [current copy];
                }
            } @catch (__unused NSException *exception) { }
        }

        // So the tab lights up like any other. Without this the bar still shows whichever
        // tab was open before, and the page underneath belongs to nothing.
        if ([self respondsToSelector:@selector(selectItemWithPivotIdentifier:)]) {
            [self selectItemWithPivotIdentifier:kSCIPivotIdentifier];
        }
        return;
    }

    // Only if the bar is not arranged the way that expects. A window over the app is worse
    // than a page in it, and better than no way in at all.
    [SCIYTDiagnostics recordTabState:@"content area not reachable, presented instead"];
    [SCIYTDownloadCenter present];
}

%end


#pragma mark - No fallback, deliberately

///
/// **There used to be a floating button here and it is gone on purpose.**
///
/// It predated the real tab and was kept as a fallback for a build whose pivot bar this
/// tweak could not read. What it actually did was appear whenever anything went wrong with
/// the tab -- and one of those things was a bug of ours, in 1.24.0, where hiding the create
/// button left no room for the tab: the report said the Centre had no tab, the screen showed
/// a red circle floating over the bar, and the two readings of "it works" and "it looks
/// broken" were both true at once.
///
/// A fallback that hides a fault is worse than no fallback. The Centre is a tab or it is
/// nothing, and if the tab cannot be built the diagnostics say so plainly -- the Centre is
/// still reachable from Settings, which is where a way in belongs when the way in that was
/// designed is not working.
///

