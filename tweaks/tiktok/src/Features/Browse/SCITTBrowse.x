//
//  SCITTBrowse.x
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "SCITTBrowse.h"
#import "../Copy/SCITTCopyMenu.h"
#import "../../Prefs.h"
#import "../../SCILog.h"

///
/// **Seven answers to questions TikTok's own code asks, each found by reading TikTok 47.1.0 and none copied from anywhere.**
///
/// A closed reference tweak (ASJTok, unlicensed) showed that these places exist; this file was written from what
/// `tools/objc-classes.py` says the app declares, from `docs/investigations/na9-scripts/callers.py` for who asks, and from a
/// reading of what the reference *does* with each answer (a decompiler pass, no code carried over). Where the two disagreed the
/// binary won, and each hook below says what it is a decision of.
///
/// **Who asks** (caller scan over `MusicallyCore` 47.1.0):
///
///   * `-[TTKPlayInteractionTikBotElement p_shouldShowtikBotButton]` is read by `-containerDidFullyDisplayWithReason:` -- the element
///     asks once per video whether it should exist, so refusing the answer removes the button instead of hiding a view that is built
///     anyway. `p_shouldShowTikbotButtonStatic` is read by that method and by `…WithCompletion:`.
///   * `-[AWEThirdWebModuleServiceImpl shouldOpenURLInIAB:]` is read by `-tryOpenURL:dataflowId:` of the same class and of
///     `PHFDfidRouterServiceImpl`; `-tryOpenURL:dataflowId:` is read by `-tryOpenURLString:dataflowId:`, so the string door is covered by
///     the URL door.
///
/// **Not run on a device.** Every class and encoding below was read from the 47.1.0 binary. What happens on a phone is what the
/// Status screen's counters are for: "installed" beside "0 answered" would be a hook on a path nothing takes.
///

@interface AWEPlayInteractionWarningElementView : UIView
@end

@interface TTKPlayInteractionTikBotElement : NSObject
@end

@interface TTKMediaMusicComponent : NSObject
@end

@interface TTKMediaPlayerRuntime : NSObject
@end

@interface AWENewFeedTableViewController : UIViewController
- (void)scrollToNextVideo;
@end

@interface AWEFeedContainerViewController : UIViewController
- (id)tabControl;
- (NSInteger)segmentControlInitialIndex;
@end

@interface TTKEditProfileBioStrategy : NSObject
@end

static NSString *sciBrowseState = nil;

// Tallies, one per answer. A tally on the path that executes -- "installed" beside zero is a finding.
static NSUInteger sciWarningsHidden = 0;
static NSUInteger sciTikBotRefused = 0;
static NSUInteger sciUnmuteArmed = 0, sciUnmuteAnswered = 0;
static NSUInteger sciAdvanceSeen = 0, sciAdvanceDone = 0, sciAdvanceNoFeed = 0, sciAdvanceTooSoon = 0;
static NSUInteger sciFollowAsked = 0, sciFollowApplied = 0, sciFollowSkippedPending = 0, sciFollowNotFound = 0, sciFollowStoredWon = 0;
static NSInteger sciFollowLive = -2;   // what the live tab control said at the last question; -2 = never asked, -1 = nothing to read
static NSInteger sciFollowLastIndex = -1;
static NSUInteger sciBioAsked = 0;

/// How many `-muteMusicIfNeeded` calls are on this thread's stack. Thread-local: a mute asked on another thread while the main thread
/// happens to be inside that method is not the question being answered.
static _Thread_local NSUInteger sciUnmuteDepth = 0;

static NSString *const kSCITTFollowIndexKey = @"albrhi_tt_following_index";
static NSString *const kSCITTFollowPendingKey = @"albrhi_tt_following_pending";

static BOOL SCITTBrowseHas(Class cls, const char *selector, const char *encoding) {
    if (!cls) return NO;
    Method method = class_getInstanceMethod(cls, sel_registerName(selector));
    const char *types = method ? method_getTypeEncoding(method) : NULL;
    return types && strcmp(types, encoding) == 0;
}

#pragma mark - The warning label

%group SCITTBrowseWarnings
%hook AWEPlayInteractionWarningElementView

- (void)updateContent:(id)content {
    %orig;
    if (!SCIPrefEnabled(SCIPrefHideWarnings)) return;
    // Filled by TikTok first and hidden after: the content is whatever TikTok decided, and nothing about it is touched.
    sciWarningsHidden++;
    [self setHidden:YES];
}

%end
%end

#pragma mark - The TikBot button

%group SCITTBrowseTikBot
%hook TTKPlayInteractionTikBotElement

- (BOOL)p_shouldShowtikBotButton {
    if (!SCIPrefEnabled(SCIPrefHideTikBot)) return %orig;
    sciTikBotRefused++;
    return NO;
}

- (BOOL)p_shouldShowTikbotButtonStatic {
    if (!SCIPrefEnabled(SCIPrefHideTikBot)) return %orig;
    sciTikBotRefused++;
    return NO;
}

%end
%end

#pragma mark - Sound on a muted video

%group SCITTBrowseUnmuteComponent
%hook TTKMediaMusicComponent

- (void)muteMusicIfNeeded {
    if (!SCIPrefEnabled(SCIPrefUnmute)) {
        %orig;
        return;
    }
    sciUnmuteArmed++;
    sciUnmuteDepth++;
    %orig;
    sciUnmuteDepth--;
}

%end
%end

%group SCITTBrowseUnmuteRuntime
%hook TTKMediaPlayerRuntime

- (void)setMute:(BOOL)mute {
    // Only a mute asked *while* the component decides whether music should be muted is turned into "not muted". A mute the user asked
    // for -- the speaker button, a muted autoplay -- comes from another path and passes through.
    if (sciUnmuteDepth > 0 && mute) {
        sciUnmuteAnswered++;
        %orig(NO);
        return;
    }
    %orig;
}

%end
%end

#pragma mark - Scroll on at the end of a video

/// The feed that is on screen, or nil. Weak, set when the feed appears and cleared when it goes: a video that loops under a profile the
/// user has opened must not scroll the feed beneath it.
static __weak AWENewFeedTableViewController *sciFeedOnScreen = nil;
static CFAbsoluteTime sciLastAdvance = 0;

%group SCITTBrowseFeedTracker
%hook AWENewFeedTableViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    sciFeedOnScreen = self;
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    if (sciFeedOnScreen == self) sciFeedOnScreen = nil;
}

%end
%end

%group SCITTBrowseAdvance
%hook TTKMediaPlayerRuntime

- (void)playerWillLoopPlaying:(id)player {
    if (!SCIPrefEnabled(SCIPrefAutoAdvance)) {
        %orig;
        return;
    }
    sciAdvanceSeen++;

    AWENewFeedTableViewController *feed = sciFeedOnScreen;
    if (!feed || !feed.viewIfLoaded.window || ![feed respondsToSelector:@selector(scrollToNextVideo)]) {
        sciAdvanceNoFeed++;
        %orig;
        return;
    }

    // A copy menu is open on this video: let it loop; scrolling away would leave the menu describing a video that is gone.
    if (SCITTCopyMenuIsOpen()) {
        sciAdvanceTooSoon++;
        %orig;
        return;
    }

    // The loop notice can arrive twice for one video while the scroll animates; one swipe is what was asked for.
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (now - sciLastAdvance < 1.2) {
        sciAdvanceTooSoon++;
        return;
    }
    sciLastAdvance = now;
    sciAdvanceDone++;
    dispatch_async(dispatch_get_main_queue(), ^{
        [feed scrollToNextVideo];
    });
}

%end
%end

#pragma mark - Starting on Following

/// Where the Following tab is among a tab control's items, found by the item's class and not by its title (titles are translated, and
/// this repository ships to an Arabic phone). -1 when there is no tab control yet or no such item.
static NSInteger SCITTFollowingIndexIn(id container) {
    if (![container respondsToSelector:@selector(tabControl)]) return -1;
    id control = [container tabControl];
    if (!control || ![control respondsToSelector:NSSelectorFromString(@"itemList")]) return -1;

    id list = ((id (*)(id, SEL))objc_msgSend)(control, NSSelectorFromString(@"itemList"));
    if (![list isKindOfClass:[NSArray class]]) return -1;

    Class following = NSClassFromString(@"TikTokFeedTabItemFollowControl");
    if (!following) return -1;

    NSArray *items = (NSArray *)list;
    for (NSUInteger i = 0; i < items.count; i++) {
        if ([items[i] isKindOfClass:following]) return (NSInteger)i;
    }
    return -1;
}

/// Set at install: whether the previous launch applied an index and never reached the feed's first appearance (see the hook below).
static BOOL sciFollowStale = NO;
/// The feed has appeared in this launch. Until it has, the initial index is ours to answer; after it, the app's own answer stands,
/// so a later regeneration of the tab bar (a login, a language change) never throws the user back to a tab they left.
static BOOL sciFollowFeedAppeared = NO;
/// Stood down after an unfinished launch, and stays down until the switch has been seen off once -- a switch that resets itself is a
/// switch that lies, and a launch that fails every other time is worse than a feature that waits to be turned on again.
static NSString *const kSCITTFollowTrippedKey = @"albrhi_tt_following_tripped";

%group SCITTBrowseFollowing
%hook AWEFeedContainerViewController

// Read by `-_generateSegmentControlByReason:` and `-p_onFinishLogin` (caller scan, 47.1.0) -- the app's own question "which tab first".
- (NSInteger)segmentControlInitialIndex {
    NSInteger original = %orig;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if (!SCIPrefEnabled(SCIPrefOpenFollowing)) {
        // Seen off: that is the "try again" a stood-down feature was waiting for.
        if ([defaults boolForKey:kSCITTFollowTrippedKey]) [defaults removeObjectForKey:kSCITTFollowTrippedKey];
        return original;
    }
    if (sciFollowFeedAppeared) return original;
    sciFollowAsked++;

    if ([defaults boolForKey:kSCITTFollowTrippedKey]) {
        sciFollowSkippedPending++;
        return original;
    }

    // **Where it was last seen, once the feed had drawn its whole tab row, beats what the control says while it is still being built.**
    // A cold start asks this question with Following as the first item and puts Community in front of it afterwards, so the live answer
    // was 0 -- Community -- and the app opened there (simulator, 2026-10-29, after a fresh install; the launch before had it right only
    // because Community was already in). The stored index is written at the feed's first appearance, from the complete row.
    NSInteger live = SCITTFollowingIndexIn(self);
    sciFollowLive = live;
    id stored = [defaults objectForKey:kSCITTFollowIndexKey];
    NSInteger last = [stored respondsToSelector:@selector(integerValue)] ? [stored integerValue] : -1;
    NSInteger found = last >= 0 ? last : live;
    if (last >= 0 && live >= 0 && live != last) sciFollowStoredWon++;
    if (found < 0 || found > 5) {
        sciFollowNotFound++;
        return original;
    }

    if (found != original) {
        sciFollowApplied++;
        sciFollowLastIndex = found;
        // Written before the answer leaves, cleared when the feed appears: if the process dies in between, the next launch finds it.
        [defaults setBool:YES forKey:kSCITTFollowPendingKey];
    }
    return found;
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    // The feed reached the screen: whatever was applied did not take the launch down, and the tab control now exists to be asked.
    sciFollowFeedAppeared = YES;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:kSCITTFollowPendingKey];
    NSInteger found = SCITTFollowingIndexIn(self);
    if (found >= 0) [defaults setInteger:found forKey:kSCITTFollowIndexKey];
}

%end
%end

#pragma mark - A longer bio

%group SCITTBrowseBio
%hook TTKEditProfileBioStrategy

- (long long)maxTextLength {
    if (!SCIPrefEnabled(SCIPrefLongBio)) return %orig;
    sciBioAsked++;
    return 500;
}

%end
%end

NSString *SCITTBrowseReport(void) {
    return [NSString stringWithFormat:
        @"%@; warnings hidden %lu; TikBot refused %lu; "
        @"unmute armed %lu, answered %lu; advance: loop notices %lu, scrolled %lu, no feed on screen %lu, too soon or a copy menu open %lu; "
        @"following: asked %lu, applied %lu (index %ld; live row said %ld; remembered index preferred over it %lu times), not found %lu, "
        @"skipped after an unfinished launch %lu; bio asked %lu",
        sciBrowseState ?: @"not installed",
        (unsigned long)sciWarningsHidden, (unsigned long)sciTikBotRefused,
        (unsigned long)sciUnmuteArmed, (unsigned long)sciUnmuteAnswered,
        (unsigned long)sciAdvanceSeen, (unsigned long)sciAdvanceDone, (unsigned long)sciAdvanceNoFeed, (unsigned long)sciAdvanceTooSoon,
        (unsigned long)sciFollowAsked, (unsigned long)sciFollowApplied, (long)sciFollowLastIndex,
        (long)sciFollowLive, (unsigned long)sciFollowStoredWon, (unsigned long)sciFollowNotFound, (unsigned long)sciFollowSkippedPending, (unsigned long)sciBioAsked];
}

void SCITTInstallBrowse(void) {
    // A launch that applied an index and never reached the feed left this key behind. Read once, here, before any hook can set it again.
    NSUserDefaults *launchDefaults = [NSUserDefaults standardUserDefaults];
    sciFollowStale = [launchDefaults boolForKey:kSCITTFollowPendingKey];
    if (sciFollowStale) {
        [launchDefaults removeObjectForKey:kSCITTFollowPendingKey];
        [launchDefaults setBool:YES forKey:kSCITTFollowTrippedKey];
    }

    NSMutableArray<NSString *> *installed = [NSMutableArray array];
    NSMutableArray<NSString *> *skipped = [NSMutableArray array];

    // Each decides for itself: a build missing one class must not cost the others, and a hook on a selector the class does not declare
    // would *add* it. Every one waits for its own type encoding.
    if (SCITTBrowseHas(NSClassFromString(@"AWEPlayInteractionWarningElementView"), "updateContent:", "v24@0:8@16")) {
        %init(SCITTBrowseWarnings);
        [installed addObject:@"warnings"];
    } else {
        [skipped addObject:@"AWEPlayInteractionWarningElementView -updateContent:"];
    }

    Class bot = NSClassFromString(@"TTKPlayInteractionTikBotElement");
    if (SCITTBrowseHas(bot, "p_shouldShowtikBotButton", "B16@0:8") && SCITTBrowseHas(bot, "p_shouldShowTikbotButtonStatic", "B16@0:8")) {
        %init(SCITTBrowseTikBot);
        [installed addObject:@"tikbot"];
    } else {
        [skipped addObject:@"TTKPlayInteractionTikBotElement -p_shouldShow…"];
    }

    if (SCITTBrowseHas(NSClassFromString(@"TTKMediaMusicComponent"), "muteMusicIfNeeded", "v16@0:8")
        && SCITTBrowseHas(NSClassFromString(@"TTKMediaPlayerRuntime"), "setMute:", "v20@0:8B16")) {
        %init(SCITTBrowseUnmuteComponent);
        %init(SCITTBrowseUnmuteRuntime);
        [installed addObject:@"unmute"];
    } else {
        [skipped addObject:@"TTKMediaMusicComponent -muteMusicIfNeeded / TTKMediaPlayerRuntime -setMute:"];
    }

    Class feed = NSClassFromString(@"AWENewFeedTableViewController");
    if (SCITTBrowseHas(NSClassFromString(@"TTKMediaPlayerRuntime"), "playerWillLoopPlaying:", "v24@0:8@16")
        && SCITTBrowseHas(feed, "scrollToNextVideo", "v16@0:8")
        && SCITTBrowseHas(feed, "viewDidAppear:", "v20@0:8B16") && SCITTBrowseHas(feed, "viewDidDisappear:", "v20@0:8B16")) {
        %init(SCITTBrowseFeedTracker);
        %init(SCITTBrowseAdvance);
        [installed addObject:@"advance"];
    } else {
        [skipped addObject:@"TTKMediaPlayerRuntime -playerWillLoopPlaying: / AWENewFeedTableViewController -scrollToNextVideo"];
    }

    Class container = NSClassFromString(@"AWEFeedContainerViewController");
    if (NSClassFromString(@"TikTokFeedTabItemFollowControl")
        && SCITTBrowseHas(container, "segmentControlInitialIndex", "q16@0:8")
        && SCITTBrowseHas(container, "tabControl", "@16@0:8")
        && SCITTBrowseHas(container, "viewDidAppear:", "v20@0:8B16")) {
        %init(SCITTBrowseFollowing);
        [installed addObject:@"following"];
    } else {
        [skipped addObject:@"AWEFeedContainerViewController -segmentControlInitialIndex / TikTokFeedTabItemFollowControl"];
    }

    if (SCITTBrowseHas(NSClassFromString(@"TTKEditProfileBioStrategy"), "maxTextLength", "q16@0:8")) {
        %init(SCITTBrowseBio);
        [installed addObject:@"bio"];
    } else {
        [skipped addObject:@"TTKEditProfileBioStrategy -maxTextLength"];
    }

    sciBrowseState = [NSString stringWithFormat:@"%@%@",
        installed.count ? [@"installed: " stringByAppendingString:[installed componentsJoinedByString:@", "]] : @"nothing installed",
        skipped.count ? [NSString stringWithFormat:@" — skipped: %@", [skipped componentsJoinedByString:@"; "]] : @""];
    SCILogV(@"[Browse] %@", sciBrowseState);
}
