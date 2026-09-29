#import "SCIYTDiagnostics.h"
#import "../SCIYTLaunchGuard.h"
#import "shared/src/SCIKVC.h"
#import "../YouTubeHeaders.h"
#import "../Tweak.h"
#import "../SCILog.h"
#import "../Prefs.h"
#import "../Localization/SCILocalize.h"
#import "../Features/Download/SCIYTDownload.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import "../Features/Tabs/SCIYTTabBar.h"
#import "../Features/Tabs/SCIYTHistoryTab.h"

///
/// The classes worth reporting on, and why each one is here.
///
/// A name alone is not enough: a report saying "YTSettingsSectionItem: found" tells
/// nobody anything unless it also says what depends on it. So each row carries the
/// question it answers.
///
static NSArray<NSDictionary *> *SCIAuditTable(void) {
    return @[
        @{@"class": @"YTSettingsSectionItem",         @"why": @"builds our settings rows"},
        @{@"class": @"YTSettingsViewController",      @"why": @"shows our settings section"},
        @{@"class": @"YTSettingsSectionItemManager",  @"why": @"answers for our category"},

        // These two are what actually put the section on screen. The one below them
        // looked like it did, and 0.1.0 shipped relying on it: it exists, it accepts
        // the category, and the screen never reads it.
        @{@"class": @"YTAppSettingsGroupPresentationData",
          @"why": @"the group list the screen is really built from"},
        @{@"class": @"YTSettingsGroupData",
          @"why": @"holds the categories — announcing one here crashed 0.1.1"},
        @{@"class": @"YTAppSettingsPresentationData",
          @"why": @"legacy category order; present but not consulted on 21.30.5"},

        // The row under a video, and the button in it. A device report said "not one of these
        // buttons has been built" about the second, which is the answer to whether a button can
        // be added to that row at all -- so both are named here rather than left to be inferred
        // from a feature's own line.
        @{@"class": @"YTSlimVideoScrollableDetailsActionsView",
          @"why": @"the row with Like and Share -- where a Save button would go"},
        @{@"class": @"YTSlimVideoDetailsActionView",
          @"why": @"one button in that row; never constructed on 21.32.4"},
        @{@"class": @"YTSlimVideoScrollableActionBarCell",
          @"why": @"the cell that hosts the row"},

        @{@"class": @"YTPlayerOverlayWrapper",        @"why": @"hands us the player response"},
        @{@"class": @"MLVideo",                       @"why": @"carries the streams in use"},
        @{@"class": @"YTIPlayerResponse",            @"why": @"the response itself"},
        @{@"class": @"YTIStreamingData",             @"why": @"the stream list inside it"},

        // The two paths a download could take. Which of these is real decides
        // whether downloading is a week of work or a month, so the report says
        // plainly which one is present rather than leaving it to be assumed.
        @{@"class": @"YTOfflineVideoStreamsDownloadController",
          @"why": @"YouTube's own downloader — the path worth riding"},
        @{@"class": @"MLOnesieUMPController",
          @"why": @"the piecewise stream protocol — the path that needs a client"},
        @{@"class": @"MLServerABROnesieDataLoader",
          @"why": @"server-driven bitrate: no plain file URLs"},
    ];
}

@implementation SCIYTDiagnostics

// Held strongly, and exactly one of each.
//
// Weak was the first attempt and it was wrong: the response is released as soon as
// playback moves on, so by the time anyone walks over to Settings the page had
// nothing left to show — which is the one thing it exists to do. One protobuf
// message and one stream list is a bounded, deliberate cost, and each new video
// replaces them rather than adding to them.
//
// The video object itself is not kept: what the report needs from it is its ID and
// its streams, and holding the whole player-layer object to reach two fields would
// pin far more than this page is worth.
static id sciLastResponse = nil;
static id sciLastStreamingData = nil;

/// The last few videos' stream objects, by video id. See -recordVideo: for why.
static NSMutableDictionary<NSString *, id> *sciStreamsByVideo = nil;
static NSMutableArray<NSString *> *sciStreamsOrder = nil;

/// Player responses filed by video id, from the object that owns the clip.
///
/// **The reasoning that put this here was wrong, and it is kept because it still helps.**
/// 0.29.1 concluded Shorts never produces an MLVideo, from two reports showing the same
/// stale streams id while the clip changed. It does produce one; it simply runs a clip
/// ahead, and the keyed stream store was failing for an unrelated reason -- it was asking
/// MLStreamingData for a field only the player response has, fixed in 0.30.1.
///
/// This remains a second source for a clip the stream store has not filed yet, which is a
/// real case on the first Short of a session.
static NSMutableDictionary<NSString *, id> *sciResponsesByVideo = nil;
static NSMutableArray<NSString *> *sciResponsesOrder = nil;
static NSString *sciLastVideoID = nil;
static NSString *sciLastVideoTitle = nil;

/// Titles by video id. See -recordVideo: for why the newest one is the wrong one in Shorts.
static NSMutableDictionary<NSString *, NSString *> *sciTitlesByVideo = nil;

// The settings groups, as text, captured the moment the screen asked for them.
// Text and not the objects: the report needs the numbers and the names, and holding
// YouTube's model objects to reach two fields each would pin far more than that.
static NSString *sciSettingsGroups = nil;

+ (void)recordSettingsGroups:(NSArray *)groups {
    if (!groups.count) return;

    NSMutableString *text = [NSMutableString string];
    for (id group in groups) {
        unsigned long long type = 0;
        NSString *title = nil;

        if ([group respondsToSelector:@selector(type)]) {
            type = ((YTSettingsGroupData *)group).type;
        }
        if ([group respondsToSelector:@selector(title)]) {
            title = ((YTSettingsGroupData *)group).title;
        }

        // -orderedCategories is deliberately *not* called here.
        //
        // This runs inside +orderedGroups, while that method is still returning, and
        // asking a group for its contents at that moment means reading an object whose
        // construction may not have finished. The category count was never worth that:
        // what the next attempt needs from this report is which groups exist and what
        // number each one carries.
        [text appendFormat:@"  type %llu — %@\n", type, title ?: @"?"];
    }

    sciSettingsGroups = [text copy];
}

// Kept so the report can say the panel failed and why. A caught exception that is
// recorded nowhere is worse than one that crashes: the app survives and the fault goes
// silent, which is the exact failure mode this page exists to prevent.
static NSString *sciPanelFailure = nil;

+ (void)recordPanelFailure:(NSString *)reason {
    if (!reason.length) return;
    sciPanelFailure = [reason copy];
    [self writeReportToFile];
}

// The latest SponsorBlock line, and only the latest: this is a status, not a log, and
// a page that grows without bound is one nobody reads to the end of.
//
// Not written to the file on every update. This is touched on each time change during
// playback, and writing the whole report to disk that often would cost far more than
// the line is worth -- it lands on the next capture, which is a video away at most.
static NSString *sciSponsorState = nil;

+ (void)recordSponsorState:(NSString *)state {
    if (!state.length) return;
    sciSponsorState = [state copy];
}

// Which bar the markers landed on. Set on every layout pass of that bar, so it is
// assigned far more often than it changes -- a copy of a short string, and cheaper than
// the comparison that would avoid it.
static NSString *sciMarkerBar = nil;

+ (void)recordMarkerBar:(NSString *)className count:(NSInteger)count {
    if (!className.length) return;
    sciMarkerBar = [NSString stringWithFormat:SCILocalized(@"diag_markers_drawn"),
        className, (long)count];
}

/// The last thing the Downloads tab did, in order, kept short.
///
/// Ordered rather than latest-only: attaching and drawing are two separate steps that fail
/// for different reasons, and "the icon did not appear" needs both answers at once -- was a
/// tab built, and did anything take the picture.
static NSMutableOrderedSet<NSString *> *sciTabStates = nil;

+ (void)recordTabState:(NSString *)state {
    if (!state.length) return;
    if (!sciTabStates) sciTabStates = [NSMutableOrderedSet orderedSet];
    if (sciTabStates.count >= 5) return;

    [sciTabStates addObject:state];
}

/// The last four, not the first four -- unlike the tab's attach sequence above, a track
/// starting is not a one-time event whose *first* moments matter most, and the useful
/// question is what the most *recent* video and the most recent sound each did, side by
/// side, on the report someone sends in right after reproducing this.
static NSMutableArray<NSString *> *sciLockScreenStates = nil;

+ (void)recordLockScreenState:(NSString *)state {
    if (!state.length) return;
    if (!sciLockScreenStates) sciLockScreenStates = [NSMutableArray array];

    [sciLockScreenStates addObject:state];
    while (sciLockScreenStates.count > 4) [sciLockScreenStates removeObjectAtIndex:0];
}

/// Running totals, not the last call: the feed is filled a page at a time, and the last
/// page alone says nothing about whether the ads were caught.
static NSUInteger sciFeedSeen = 0;
static NSUInteger sciFeedDropped = 0;

+ (void)recordFeedSections:(NSUInteger)seen dropped:(NSUInteger)dropped {
    sciFeedSeen += seen;
    sciFeedDropped += dropped;
}

/// Latest only, and appended to the feed line rather than given a section of its own --
/// it is a fact about that filter, and a reader looking at the counts is the reader who
/// needs to know the filter stood down.
static NSString *sciFeedBrake = nil;

+ (NSString *)feedState {
    // First, and above everything else this section says, because if the guard tripped then
    // every number below it is the number for a session in which the tweak was standing down.
    // A report that lists "0 dropped" without saying that is a report that sends the next hour
    // in the wrong direction.
    if (SCIYTStoodDown()) return SCIYTLaunchGuardReport();

    if (!sciFeedSeen) return SCILocalized(@"diag_feed_none");

    NSString *counts = [NSString stringWithFormat:SCILocalized(@"diag_feed_counts"),
        (unsigned long)sciFeedSeen, (unsigned long)sciFeedDropped];

    // The brake belongs on the same line as the counts. Read on its own, "0 dropped" says
    // the filter recognised nothing -- which is a different problem from the filter standing
    // down because it recognised far too much, and they need different fixes.
    if (!sciFeedBrake.length) return counts;
    return [NSString stringWithFormat:@"%@\n  %@", counts, sciFeedBrake];
}

/// Latest only. This runs on every layout pass of the Shorts overlay, so a growing list
/// would be a log file inside a report.
static NSString *sciShortsButton = nil;

+ (void)recordShortsButton:(NSString *)state {
    if (state.length) sciShortsButton = [state copy];
}


/// Latest only, and it is a tally rather than an event: the string handed in already
/// carries both counts, so overwriting it loses nothing.
static NSString *sciNativeDownloadButton = nil;

+ (void)recordNativeDownloadButton:(NSString *)state {
    if (state.length) sciNativeDownloadButton = [state copy];
}

+ (NSString *)nativeDownloadButtonState {
    return sciNativeDownloadButton ?: SCILocalized(@"diag_native_button_none");
}

static NSString *sciNativeDownloadNote = nil;

+ (void)recordNativeDownloadNote:(NSString *)note {
    if (note.length) sciNativeDownloadNote = [note copy];
}

+ (NSString *)nativeDownloadNote {
    return sciNativeDownloadNote ?: SCILocalized(@"diag_native_button_no_tap");
}

static NSString *sciOverlayButton = nil;

+ (void)recordOverlayButton:(NSString *)state {
    if (state.length) sciOverlayButton = [state copy];
}

+ (NSString *)overlayButtonState {
    return sciOverlayButton ?: SCILocalized(@"diag_overlay_none");
}

/// The action row's own slot. See the header for why it is not shared with the overlay's.
static NSString *sciActionRow = nil;

+ (void)recordActionRow:(NSString *)state {
    if (state.length) sciActionRow = [state copy];
}

+ (NSString *)actionRowState {
    return sciActionRow ?: SCILocalized(@"diag_action_row_none");
}

static NSString *sciActionBar = nil;

+ (void)recordActionBar:(NSString *)state {
    if (state.length) sciActionBar = [state copy];
}

+ (NSString *)actionBarState {
    return sciActionBar ?: SCILocalized(@"diag_action_bar_none");
}


static NSString *sciWatchScan = nil;

/// The names worth printing. Everything else on a watch page is UIKit and YouTube's own
/// containers, and a dump of all of it is a dump nobody reads to the end of.
static BOOL SCINameIsInteresting(NSString *name) {
    // YouTube's own classes, first and foremost. The first version of this listed five words --
    // Action, Slim, Metadata, ELM, Button -- and the row being looked for is drawn by a class
    // whose name carries none of them, which is precisely why it is being looked for. A filter
    // built from the names you expect cannot show you the name you did not.
    if ([name hasPrefix:@"YT"] || [name hasPrefix:@"ELM"]) return YES;

    for (NSString *needle in @[@"Action", @"Slim", @"Metadata", @"Button", @"Engagement"]) {
        if ([name rangeOfString:needle].location != NSNotFound) return YES;
    }
    return NO;
}

static BOOL sciWatchScanWanted = NO;

+ (void)requestWatchScan {
    sciWatchScanWanted = YES;
    sciWatchScan = SCILocalized(@"diag_scan_waiting");

    //
    // **On a timer, because neither of the two clever answers reached the right tree.**
    //
    // Run from the settings row, it scanned the settings screen -- a full-screen presentation
    // takes YouTube's hierarchy out of the window. Run from the player's overlay and walked from
    // that view's own root, it scanned **the overlay**: 48 views of playback controls, because
    // the overlay is the root of its own tree and the metadata row under the video is not in it.
    // Both reports were accurate and neither was about the row.
    //
    // Ten seconds and the key window is the dull answer that works: by then the settings screen
    // is closed and a video is open, so the window holds the watch page and the walk starts above
    // everything rather than inside one branch of it.
    //
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (!sciWatchScanWanted) return;   // a player already answered it
        sciWatchScanWanted = NO;
        [self scanWatchPage];
    });
}

+ (BOOL)watchScanRequested {
    if (!sciWatchScanWanted) return NO;
    sciWatchScanWanted = NO;
    return YES;
}

+ (void)scanWatchPage {
    // The biggest window of an active scene, and key beats size.
    //
    // Not simply "the first window": an app has several -- a keyboard's, an alert's, a
    // screenshot's -- and the small ones are the ones most likely to be answered first.
    UIWindow *window = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        if (scene.activationState != UISceneActivationStateForegroundActive) continue;

        for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
            if (candidate.hidden) continue;
            if (candidate.isKeyWindow) { window = candidate; break; }

            CGFloat area = candidate.bounds.size.width * candidate.bounds.size.height;
            CGFloat best = window.bounds.size.width * window.bounds.size.height;
            if (!window || area > best) window = candidate;
        }
        if (window.isKeyWindow) break;
    }

    if (!window) {
        sciWatchScan = SCILocalized(@"diag_scan_no_window");
        [self writeReportToFile];
        return;
    }

    [self scanTree:window];
}

+ (void)scanFromView:(UIView *)view {
    if (!view) return;

    // The window first, when there is one: a view's own root is its own branch, and the row this
    // is looking for is a sibling of the player rather than a child of it. Only when the view is
    // off the window entirely does its own root become the best available answer.
    if (view.window) { [self scanTree:view.window]; return; }

    // Up to the top of whatever tree this view is in, which is not the same as the window: a
    // full-screen presentation detaches the hierarchy behind it, and that hierarchy is exactly
    // the one being asked about.
    UIView *root = view;
    while (root.superview) root = root.superview;

    [self scanTree:root];
}

/// The first view of this class in `root`'s tree, breadth-first.
static UIView *SCIFindByClassName(UIView *root, NSString *name) {
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:root];
    while (queue.count) {
        UIView *next = queue.firstObject;
        [queue removeObjectAtIndex:0];
        if ([NSStringFromClass([next class]) isEqualToString:name]) return next;
        [queue addObjectsFromArray:next.subviews];
    }
    return nil;
}

+ (void)scanTree:(UIView *)window {
    //
    // **Aimed at the list under the player rather than at the whole window.**
    //
    // The first scan that reached the right window walked 210 views and printed 120 of them
    // before its budget ran out -- and every one was chrome: the tab bar, the mini player, the
    // ghost cells YouTube draws while a page loads. The row being looked for is deeper than a
    // breadth-first walk of a whole window can reach on any budget worth printing.
    //
    // `YTWatchNextView` is the list below the video, named by that same scan. Starting there
    // spends the whole budget on the part of the screen the question is about.
    //
    UIView *watchNext = SCIFindByClassName(window, @"YTWatchNextView");
    if (watchNext) window = watchNext;

    //
    // **And then narrower still, to the row itself.**
    //
    // Starting from the list under the video printed its title, its chips and two
    // `ELMAnimatedVectorViewObjC`s -- element-drawn icons, which is what Like and Dislike are in
    // this build. Everything else in that row is a plain `UIView` the element system made, so a
    // filter that prints `YT…` and `ELM…` names shows the icons and hides the container they sit
    // in, which is the one thing being looked for.
    //
    // So: find an element icon, climb to the ancestor wide enough to be the row, and print that
    // subtree with **no name filter at all**. A name filter is right for a whole window and
    // wrong here, for the same reason it was wrong before -- it cannot show a name nobody has
    // guessed yet.
    //
    UIView *icon = SCIFindByClassName(window, @"ELMAnimatedVectorViewObjC");
    UIView *row = nil;
    for (UIView *up = icon; up; up = up.superview) {
        if (up.bounds.size.width >= 300 && up.bounds.size.height > 0 &&
            up.bounds.size.height <= 120) { row = up; break; }
        if (up == window) break;
    }
    if (row) window = row;
    BOOL nameFilter = (row == nil);

    NSMutableString *out = [NSMutableString string];
    NSUInteger printed = 0;

    // Counted as well as printed. "Nothing matched" and "there was almost nothing there" are two
    // different answers, and the second means the scan was taken from the wrong tree again.
    NSUInteger walked = 0;

    [out appendFormat:@"  (from %@)\n", NSStringFromClass([window class])];

    // Breadth-first with the depth carried alongside, so the output reads as a tree rather than
    // as a list of names with no relationship between them.
    NSMutableArray *queue = [NSMutableArray arrayWithObject:@[window, @0]];
    while (queue.count && printed < 200) {
        NSArray *pair = queue.firstObject;
        [queue removeObjectAtIndex:0];

        UIView *view = pair[0];
        NSUInteger depth = [pair[1] unsignedIntegerValue];
        walked++;
        NSString *name = NSStringFromClass([view class]);

        // Hidden views are skipped. YouTube keeps a screenful of ghost placeholder cells around
        // and they are all hidden, all interesting by name, and none of them on screen.
        if (!view.hidden && (!nameFilter || SCINameIsInteresting(name))) {
            CGRect frame = view.frame;
            [out appendFormat:@"  %@%@  %.0f,%.0f %.0f×%.0f%@\n",
                [@"" stringByPaddingToLength:MIN(depth, 8) * 2 withString:@" " startingAtIndex:0],
                name, frame.origin.x, frame.origin.y, frame.size.width, frame.size.height,
                view.hidden ? SCILocalized(@"diag_scan_hidden") : @""];
            printed++;
        }

        for (UIView *child in view.subviews) {
            [queue addObject:@[child, @(depth + 1)]];
        }
    }

    [out appendFormat:@"  (%lu view(s) walked in all)\n", (unsigned long)walked];

    sciWatchScan = printed
        ? [NSString stringWithFormat:SCILocalized(@"diag_scan_found"), (unsigned long)printed, out]
        : [NSString stringWithFormat:@"%@\n%@", SCILocalized(@"diag_scan_nothing"), out];

    [self writeReportToFile];
}

+ (NSString *)watchScanState {
    return sciWatchScan ?: SCILocalized(@"diag_scan_none");
}


+ (NSString *)methodsOfClassNamed:(NSString *)name {
    Class cls = NSClassFromString(name);
    if (!cls) return [NSString stringWithFormat:SCILocalized(@"diag_methods_absent"), name];

    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    if (!methods) return [NSString stringWithFormat:SCILocalized(@"diag_methods_none"), name];

    NSMutableArray<NSString *> *names = [NSMutableArray arrayWithCapacity:count];
    for (unsigned int i = 0; i < count; i++) {
        [names addObject:NSStringFromSelector(method_getName(methods[i]))];
    }
    free(methods);

    [names sortUsingSelector:@selector(caseInsensitiveCompare:)];

    // Capped, because a report nobody reads to the end of answers nothing. Sixty selectors is
    // more than any class this tweak has needed to be told about.
    NSUInteger shown = MIN(names.count, (NSUInteger)60);
    NSString *list = [[names subarrayWithRange:NSMakeRange(0, shown)] componentsJoinedByString:@", "];

    return [NSString stringWithFormat:SCILocalized(@"diag_methods_list"),
            name, (unsigned long)count, list];
}

/// The last save actually attempted, kept apart from the placement line above.
///
/// They shared one slot and placement won every time. Placement is written whenever an
/// overlay is built, which is on every clip you swipe to -- so tapping save wrote the one
/// line that mattered and the next swipe erased it. The report I asked for could never have
/// contained it.
///
/// This is 0.10.2 again: a record wiped by the activity it was measuring, in a different
/// file, after the lesson had been written down. A status and an event do not belong in one
/// variable, because the status is always the more recent of the two.
static NSString *sciShortsSave = nil;

+ (void)recordShortsSave:(NSString *)detail {
    if (detail.length) sciShortsSave = [detail copy];
    [self writeReportToFile];
}

+ (NSString *)shortsSaveState {
    return sciShortsSave ?: SCILocalized(@"diag_shorts_save_none");
}

/// Bounded and de-duplicated: the same file failing twice is one fact.
static NSMutableOrderedSet<NSString *> *sciPlaybackFailures = nil;

+ (void)recordPlaybackFailure:(NSString *)detail {
    if (!detail.length) return;
    if (!sciPlaybackFailures) sciPlaybackFailures = [NSMutableOrderedSet orderedSet];
    if (sciPlaybackFailures.count >= 6) return;

    [sciPlaybackFailures addObject:detail];
    [self writeReportToFile];
}

static NSMutableDictionary<NSString *, NSArray<NSNumber *> *> *sciFeedDoors = nil;

+ (void)recordFeedEntryPoint:(NSString *)where
                        seen:(NSUInteger)seen
                     dropped:(NSUInteger)dropped {
    if (!where.length) return;
    if (!sciFeedDoors) sciFeedDoors = [NSMutableDictionary dictionary];

    NSArray<NSNumber *> *running = sciFeedDoors[where];
    NSUInteger totalSeen = running.firstObject.unsignedIntegerValue + seen;
    NSUInteger totalDropped = running.lastObject.unsignedIntegerValue + dropped;
    sciFeedDoors[where] = @[@(totalSeen), @(totalDropped)];
    [self writeReportToFile];
}

+ (NSString *)feedEntryPoints {
    if (!sciFeedDoors.count) return @"no feed batch has arrived yet";

    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSString *where in [sciFeedDoors.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        NSArray<NSNumber *> *pair = sciFeedDoors[where];
        [parts addObject:[NSString stringWithFormat:@"%@ %@ seen / %@ dropped",
                          where, pair.firstObject, pair.lastObject]];
    }
    return [parts componentsJoinedByString:@" · "];
}

+ (void)recordFeedBrake:(NSString *)detail {
    if (!detail.length) return;
    sciFeedBrake = [detail copy];
    [self writeReportToFile];
}

/// Words worth a longer look. Not a filter -- nothing here is dropped for carrying one of
/// these, which would be the exact "a marker inside a shelf condemned the whole shelf"
/// mistake the real filter above already learned not to make. This only decides how much
/// of a section's own description gets kept for reading, not whether the section survives.
static NSArray<NSString *> *SCISuspiciousMarkers(void) {
    static NSArray *markers = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        markers = @[@"ad_logging_data", @"ad_slot", @"advertis", @"sponsor", @"promo",
                    @"shopping", @"masthead", @"companion_ad", @"display_ad"];
    });
    return markers;
}

/// The latest batch only. A 220-character excerpt cut a genuinely promising section off
/// mid-word right as its ad_logging_data field was starting to say something -- the field
/// that would identify a section as an ad sits deeper in than a short excerpt reaches.
/// So a section is read in full for a suspicious word first, and
/// only given the longer allowance if one is actually there; an ordinary section still
/// gets a short excerpt, so twelve untagged videos do not turn one report into a log file.
static NSMutableArray<NSString *> *sciFeedKeptSample = nil;

+ (void)recordFeedKeptSampleTexts:(NSArray<NSString *> *)texts {
    NSArray<NSString *> *markers = SCISuspiciousMarkers();
    NSMutableArray<NSString *> *flagged = [NSMutableArray array];
    NSMutableArray<NSString *> *ordinary = [NSMutableArray array];

    for (NSString *text in texts) {
        if (!text.length) continue;

        BOOL suspicious = NO;
        for (NSString *marker in markers) {
            if ([text rangeOfString:marker options:NSCaseInsensitiveSearch].location != NSNotFound) {
                suspicious = YES;
                break;
            }
        }

        // Flagged sections are collected in full first, regardless of where in the batch
        // they sit -- the one worth reading might be the last of fourteen, and a plain
        // scan-order cap would drop it before it was ever looked at.
        if (suspicious) {
            NSString *text1800 = text.length > 1800 ? [text substringToIndex:1800] : text;
            [flagged addObject:[@"[flagged] " stringByAppendingString:text1800]];
        } else if (ordinary.count < 8) {
            [ordinary addObject:text.length > 150 ? [text substringToIndex:150] : text];
        }

        if (flagged.count >= 6) break;
    }

    NSMutableArray<NSString *> *sample = [NSMutableArray arrayWithArray:flagged];
    [sample addObjectsFromArray:ordinary];
    sciFeedKeptSample = sample;
}

+ (NSString *)feedKeptSampleState {
    if (!sciFeedKeptSample.count) return SCILocalized(@"diag_feed_sample_none");
    return [sciFeedKeptSample componentsJoinedByString:@"\n  ---\n  "];
}

+ (NSString *)playbackFailures {
    if (!sciPlaybackFailures.count) return SCILocalized(@"diag_playback_none");
    return [[sciPlaybackFailures array] componentsJoinedByString:@"\n  "];
}

/// Counted rather than listed: the interesting facts are whether this class exists on this
/// build at all and whether it is reached often, and a list of identical lines says neither.
static NSUInteger sciShortsAdsRefused = 0;
static NSString *sciShortsAdDetail = nil;

+ (void)recordShortsAd:(NSString *)detail {
    sciShortsAdsRefused += 1;
    if (detail.length) sciShortsAdDetail = [detail copy];
}

static NSMutableArray<NSString *> *sciGateLabels = nil;
static NSMutableDictionary<NSString *, NSString *> *sciGateStatus = nil;
static NSMutableDictionary<NSString *, NSNumber *> *sciGateCounts = nil;

+ (void)registerAdGate:(NSString *)label status:(NSString *)status {
    if (!label.length) return;
    @synchronized (self) {
        if (!sciGateLabels) {
            sciGateLabels = [NSMutableArray array];
            sciGateStatus = [NSMutableDictionary dictionary];
            sciGateCounts = [NSMutableDictionary dictionary];
        }
        if (![sciGateLabels containsObject:label]) [sciGateLabels addObject:label];
        sciGateStatus[label] = status ?: @"?";
    }
}

+ (void)countAdGate:(NSString *)label {
    if (!label.length) return;
    @synchronized (self) {
        if (!sciGateCounts) return;
        sciGateCounts[label] = @([sciGateCounts[label] integerValue] + 1);
    }
}

+ (NSString *)adGateState {
    @synchronized (self) {
        if (!sciGateLabels.count) return SCILocalized(@"diag_ad_gates_none");
        NSMutableArray<NSString *> *lines = [NSMutableArray array];
        for (NSString *label in sciGateLabels) {
            [lines addObject:[NSString stringWithFormat:@"%@ — %@ · ×%@", label,
                              sciGateStatus[label], sciGateCounts[label] ?: @0]];
        }
        return [lines componentsJoinedByString:@"\n  "];
    }
}

+ (NSString *)shortsAdState {
    if (!sciShortsAdsRefused) return SCILocalized(@"diag_shorts_ads_none");
    return [NSString stringWithFormat:SCILocalized(@"diag_shorts_ads_count"),
        (unsigned long)sciShortsAdsRefused, sciShortsAdDetail ?: @"?"];
}

/// The SABR investigation, in four numbers and two facts.
///
/// Counts and not a log: these gates are read on every reload and every request, and a
/// hundred identical lines would push the rest of the report off the end while saying no
/// more than one line and a total.
static BOOL sciSabrReloadClass = NO;
static BOOL sciSabrOnesieClass = NO;
static NSUInteger sciSabrForced = 0;

/// The video the counts above were taken on.
///
/// Without it, a report that was never re-measured is indistinguishable from one where the
/// setting was tried and refused — which is what happened, twice.
static NSString *sciSabrVideo = nil;

/// One line per gate rather than one total.
///
/// The 1.8.0 report said the gates were consulted four times and named only the last of
/// them, which left the question it was built to answer half open: two gates were counted
/// together, so "consulted" could have meant both of them or one of them four times. Those
/// need different next steps -- a gate nobody asks cannot be forced into mattering -- and a
/// single counter cannot tell them apart.
static NSMutableDictionary<NSString *, NSNumber *> *sciSabrCounts = nil;
static NSMutableDictionary<NSString *, NSNumber *> *sciSabrAnswers = nil;

+ (void)recordSabrClasses:(BOOL)reloadContext onesie:(BOOL)onesie {
    sciSabrReloadClass = reloadContext;
    sciSabrOnesieClass = onesie;
}

+ (void)recordSabrGate:(NSString *)gate original:(BOOL)original forced:(BOOL)forced {
    if (!gate.length) return;

    // Built here rather than in an +initialize: these are written from whichever thread the
    // player happens to be reloading on, and the first of those may be the first call.
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sciSabrCounts = [NSMutableDictionary dictionary];
        sciSabrAnswers = [NSMutableDictionary dictionary];
    });

    @synchronized (sciSabrCounts) {
        sciSabrCounts[gate] = @(sciSabrCounts[gate].unsignedIntegerValue + 1);
        sciSabrAnswers[gate] = @(original);
        if (forced) sciSabrForced += 1;

        // Which playback these counts belong to.
        //
        // Two reports arrived identical down to the cpn, and the counts alone could not say
        // whether the setting had been tried and refused or the video had simply not been
        // played again. A number that has not moved and a number that was never taken look
        // the same; the video id tells them apart.
        sciSabrVideo = [sciLastVideoID copy];
    }
}

+ (NSString *)sabrState {
    NSMutableString *out = [NSMutableString string];

    [out appendFormat:SCILocalized(@"diag_sabr_classes"),
        sciSabrReloadClass ? @"yes" : @"no",
        sciSabrOnesieClass ? @"yes" : @"no"];

    // There is no setting to report any more. The counts stay: they cost nothing, and if a
    // future YouTube consults these gates differently the report will say so without anyone
    // having to remember to go and look.

    // Typed, and not `NSDictionary *`. A bare one subscripts to `id`, and `id` has no
    // -unsignedLongValue to find -- which is a compile error rather than a wrong number, so
    // it cost a build and nothing else, but it cost a build.
    NSDictionary<NSString *, NSNumber *> *counts = nil;
    NSDictionary<NSString *, NSNumber *> *answers = nil;

    if (sciSabrCounts) {
        @synchronized (sciSabrCounts) {
            counts = [sciSabrCounts copy];
            answers = [sciSabrAnswers copy];
        }
    }

    // The distinction the whole idea turns on. A gate that is never asked cannot be answered
    // differently, and no amount of forcing changes that -- so this reads as a finished
    // answer rather than as a blank waiting to be filled.
    if (!counts.count) {
        [out appendFormat:@"\n  %@", SCILocalized(@"diag_sabr_never")];
        return out;
    }

    for (NSString *gate in [counts.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        [out appendFormat:@"\n  "];
        [out appendFormat:SCILocalized(@"diag_sabr_gate"),
            gate,
            counts[gate].unsignedLongValue,
            answers[gate].boolValue ? @"YES" : @"NO"];
    }

    [out appendFormat:@"\n  "];
    [out appendFormat:SCILocalized(@"diag_sabr_forced"), (unsigned long)sciSabrForced];

    if (sciSabrVideo.length) {
        [out appendFormat:@"\n  "];
        [out appendFormat:SCILocalized(@"diag_sabr_video"), sciSabrVideo];
    }
    return out;
}

+ (NSString *)shortsButtonState {
    return sciShortsButton ?: SCILocalized(@"diag_shorts_none");
}

+ (NSString *)tabState {
    if (!sciTabStates.count) return SCILocalized(@"diag_tab_none");
    return [[sciTabStates array] componentsJoinedByString:@"\n  "];
}

+ (NSString *)lockScreenState {
    if (!sciLockScreenStates.count) return SCILocalized(@"diag_lock_screen_none");
    return [sciLockScreenStates componentsJoinedByString:@"\n  "];
}

/// One video's worth of what each candidate ad-slot selector answered, kept the same way
/// the lock-screen states are -- the last three, not the first three, because the useful
/// question is what a *recent* capture looked like when the report was actually sent.
static NSMutableArray<NSString *> *sciAdSlotStates = nil;

+ (void)recordAdSlotProbe:(NSString *)state {
    if (!state.length) return;
    if (!sciAdSlotStates) sciAdSlotStates = [NSMutableArray array];

    [sciAdSlotStates addObject:state];
    while (sciAdSlotStates.count > 3) [sciAdSlotStates removeObjectAtIndex:0];
}

+ (NSString *)adSlotProbeState {
    if (!sciAdSlotStates.count) return SCILocalized(@"diag_ad_slots_none");
    return [sciAdSlotStates componentsJoinedByString:@"\n  "];
}

/// Which video the captured response is for.
///
/// This is the id that matters for downloading and it was the one nobody wrote down. The
/// HLS playlist the downloader uses comes out of sciLastResponse, and until now the only
/// ids kept were the MLVideo's and the announced one -- two different things, neither of
/// them this. So the guard added in 0.25.1 compared the video being asked for against an id
/// that had nothing to do with the playlist it was guarding, agreed with itself, and handed
/// over the wrong video's playlist. In Shorts all three ids differ routinely, which is why
/// it was wrong there every time and fine everywhere else.
static NSString *sciResponseVideoID = nil;

/// What a value answered, described without assuming its class.
///
/// A protobuf repeated field is not an NSArray -- it is Google's own container type, not
/// public API this file can import and check with -isKindOfClass:. Checked by selector
/// instead: anything that answers -count is described with its count, which covers both
/// the real container type and a plain NSArray alike without needing to name either one.
static NSString *SCIDescribeAdSlotValue(id value) {
    if (!value) return @"nil";

    if ([value respondsToSelector:@selector(count)]) {
        NSUInteger count = ((NSUInteger (*)(id, SEL))objc_msgSend)(value, @selector(count));
        return [NSString stringWithFormat:@"%@(%lu)", NSStringFromClass([value class]), (unsigned long)count];
    }

    return NSStringFromClass([value class]);
}

/// Reads a small, named set of selectors off a captured player response, one at a time.
///
/// Every name here is confirmed real on this build already -- present in the class dump
/// this file's other reasoning is measured from -- so the open question is not whether
/// they exist but which class answers and what it hands back. `-respondsToSelector:`
/// decides that per name, and only a name that answers is ever sent.
static void SCIProbeAdSlots(id response) {
    if (!response) return;

    static NSArray<NSString *> *candidates = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        candidates = @[@"playerAdsArray", @"adPlacementsArray", @"adSlotsArray",
                       @"adSlotRenderer", @"adParams", @"adNextParams", @"adBreakParams"];
    });

    NSMutableArray<NSString *> *parts = [NSMutableArray array];

    @try {
        for (NSString *name in candidates) {
            SEL selector = NSSelectorFromString(name);
            if (![response respondsToSelector:selector]) continue;

            id value = ((id (*)(id, SEL))objc_msgSend)(response, selector);
            [parts addObject:[NSString stringWithFormat:@"%@=%@", name, SCIDescribeAdSlotValue(value)]];
        }
    } @catch (NSException *exception) {
        [SCIYTDiagnostics recordAdSlotProbe:
            [NSString stringWithFormat:@"%@ — probe failed: %@",
                sciResponseVideoID ?: @"?", exception.reason ?: @"?"]];
        return;
    }

    [SCIYTDiagnostics recordAdSlotProbe:parts.count
        ? [NSString stringWithFormat:@"%@ — %@", sciResponseVideoID ?: @"?",
            [parts componentsJoinedByString:@", "]]
        : [NSString stringWithFormat:@"%@ — none of the candidate selectors answered on %@",
            sciResponseVideoID ?: @"?", NSStringFromClass([response class])]];
}

+ (void)recordPlayerResponse:(id)response {
    if (!response) return;
    sciLastResponse = response;
    sciResponseVideoID = nil;

    // Asked properly first, and only then read out of the text.
    //
    // The first version of this did the text alone, looking for `video_id: "`, and came back
    // empty every time -- the report said `playlist ?`. That made the guard downstream treat
    // every capture as somebody else's and refuse every download, which is worse than the
    // bug it was written for. Writing a guard on a value I had never once seen produced is
    // the whole of that mistake.
    @try {
        id details = SCISafeValueForKey(response, @"videoDetails");
        id identifier = details ? SCISafeValueForKey(details, @"videoId") : nil;

        if ([identifier isKindOfClass:[NSString class]] && [identifier length]) {
            sciResponseVideoID = [identifier copy];
        }
    } @catch (__unused NSException *exception) { }

    // Both spellings, because a GPBMessage prints proto field names and the accessor uses
    // the camel-cased one -- and which of the two a description carries is not something to
    // be confident about without looking.
    if (!sciResponseVideoID) {
        @try {
            NSString *text = [response description];

            for (NSString *key in @[@"video_id: \"", @"videoId: \""]) {
                NSRange found = [text rangeOfString:key];
                if (found.location == NSNotFound) continue;

                NSUInteger from = found.location + found.length;
                NSRange end = [text rangeOfString:@"\""
                                          options:0
                                            range:NSMakeRange(from, text.length - from)];
                if (end.location == NSNotFound) continue;

                sciResponseVideoID = [text substringWithRange:
                    NSMakeRange(from, end.location - from)];
                break;
            }
        } @catch (__unused NSException *exception) { }
    }

    SCILogV(@"captured player response %@ for %@", [response class], sciResponseVideoID);

    SCIProbeAdSlots(response);
}

+ (NSString *)responseVideoID { return sciResponseVideoID; }

+ (void)recordVideo:(id)video {
    if (!video) return;

    if ([video respondsToSelector:@selector(ID)]) {
        NSString *identifier = ((MLVideo *)video).ID;
        if ([identifier isKindOfClass:[NSString class]]) {
            sciLastVideoID = [identifier copy];
        }
    }

    if ([video respondsToSelector:@selector(streamingData)]) {
        sciLastStreamingData = [(MLVideo *)video streamingData];

        // Kept per video, not just the newest.
        //
        // "Which video is this capture for" turned out to be unanswerable from the capture
        // itself -- two readings of the response's own id came back empty -- and it is the
        // wrong question anyway. MLVideo carries an ID that has never failed to read, so the
        // streams can simply be filed under it and looked up by name later.
        //
        // That is what Shorts needs. The clip playing had its streams captured when it
        // became current; the next one's arrived afterwards and took the single slot. Both
        // are here, and asking for one by id gets the right one.
        if (sciLastVideoID.length && sciLastStreamingData) {
            if (!sciStreamsByVideo) sciStreamsByVideo = [NSMutableDictionary dictionary];

            // Bounded, and the oldest goes first. This holds YouTube's stream objects, so an
            // unbounded map would pin every video of the session.
            if (!sciStreamsOrder) sciStreamsOrder = [NSMutableArray array];

            // The oldest key, read before it is removed from the order.
            //
            // The first version took index 0 out of the order and then deleted the key of
            // whatever had become first -- so it evicted the second-oldest and left the
            // oldest in the dictionary with nothing tracking it, which grows without bound.
            // It also touched the order array before creating it.
            if (sciStreamsByVideo.count >= 6 && !sciStreamsByVideo[sciLastVideoID]) {
                NSString *oldest = sciStreamsOrder.firstObject;
                if (oldest) {
                    [sciStreamsByVideo removeObjectForKey:oldest];
                    [sciStreamsOrder removeObjectAtIndex:0];
                }
            }

            if (!sciStreamsByVideo[sciLastVideoID]) [sciStreamsOrder addObject:sciLastVideoID];
            sciStreamsByVideo[sciLastVideoID] = sciLastStreamingData;
        }
    }

    // The title, for naming the file a download produces. Best effort and never
    // required: an untitled save is a small annoyance, a crash here is not.
    @try {
        id details = [self value:@"videoDetails" from:video];
        NSString *title = [self value:@"title" from:details];
        NSString *author = [self value:@"author" from:details];

        if ([title isKindOfClass:[NSString class]] && title.length) {
            sciLastVideoTitle = [author isKindOfClass:[NSString class]] && author.length
                ? [NSString stringWithFormat:@"%@ - %@", author, title]
                : [title copy];

            // Filed by video id as well as kept as "the latest".
            //
            // The latest is the wrong one in Shorts, for the same reason the streams were:
            // MLVideo runs a clip ahead. A download was fetching the right video's playlist
            // -- proved from the address's own id -- and then naming the file after whatever
            // MLVideo was newest, so the saved clip arrived under the neighbouring clip's
            // title. Right bytes, wrong name, and from the outside those look identical.
            if (sciLastVideoID.length) {
                if (!sciTitlesByVideo) sciTitlesByVideo = [NSMutableDictionary dictionary];

                // Bounded like the others, and titles are small enough that six is generous.
                if (sciTitlesByVideo.count >= 12 && !sciTitlesByVideo[sciLastVideoID]) {
                    [sciTitlesByVideo removeAllObjects];
                }
                sciTitlesByVideo[sciLastVideoID] = sciLastVideoTitle;
            }
        }
    } @catch (__unused NSException *exception) {}

    SCILogV(@"captured video %@ (streams: %@)", sciLastVideoID,
            sciLastStreamingData ? @"yes" : @"no");

    // Refreshed on the file too, so the report is complete without the page having
    // to be reachable.
    [self writeReportToFile];
}

/// Only the rows the *features* depend on. The report lists more than this -- the
/// download paths, the settings model -- and none of those failing means a feature is
/// broken, so none of them may turn the identity badge amber.
+ (BOOL)featuresAttached {
    NSArray *required = @[
        @"YTAdsInnerTubeContextDecorator",
        @"YTAdShieldUtils",
        @"YTIPlayerResponse",
        @"YTLocalPlaybackController",
        @"YTInnerTubeCollectionViewController",
        @"YTIPlayabilityStatus",
        @"MLVideo",
    ];

    for (NSString *name in required) {
        if (objc_getClass([name UTF8String]) == NULL) {
            SCILogV(@"audit: %@ is missing", name);
            return NO;
        }
    }
    return YES;
}


+ (NSString *)titleForVideoID:(NSString *)videoID {
    return videoID.length ? sciTitlesByVideo[videoID] : nil;
}

+ (id)streamingDataForVideoID:(NSString *)videoID {
    return videoID.length ? sciStreamsByVideo[videoID] : nil;
}

+ (void)recordResponse:(id)response forVideo:(NSString *)videoID {
    if (!response || !videoID.length) return;

    if (!sciResponsesByVideo) sciResponsesByVideo = [NSMutableDictionary dictionary];
    if (!sciResponsesOrder) sciResponsesOrder = [NSMutableArray array];

    // Bounded and oldest-first, like the stream store: these are YouTube's own message
    // objects and an unbounded map would pin every clip swiped past in a session.
    if (sciResponsesByVideo.count >= 6 && !sciResponsesByVideo[videoID]) {
        NSString *oldest = sciResponsesOrder.firstObject;
        if (oldest) {
            [sciResponsesByVideo removeObjectForKey:oldest];
            [sciResponsesOrder removeObjectAtIndex:0];
        }
    }

    if (!sciResponsesByVideo[videoID]) [sciResponsesOrder addObject:videoID];
    sciResponsesByVideo[videoID] = response;
}

/// The last few things the Shorts model handed over, in order and de-duplicated.
///
/// Ordered rather than latest-only: whether this fires at all, and whether it fires before
/// the model knows its own id, are different faults that look identical from outside.
static NSMutableOrderedSet<NSString *> *sciShortsResponses = nil;

+ (void)recordShortsResponse:(NSString *)detail {
    if (!detail.length) return;
    if (!sciShortsResponses) sciShortsResponses = [NSMutableOrderedSet orderedSet];
    if (sciShortsResponses.count >= 5) return;

    [sciShortsResponses addObject:detail];
    [self writeReportToFile];
}

+ (NSString *)shortsResponseState {
    if (!sciShortsResponses.count) return SCILocalized(@"diag_shorts_resp_none");
    return [[sciShortsResponses array] componentsJoinedByString:@"\n  "];
}

+ (id)responseForVideoID:(NSString *)videoID {
    return videoID.length ? sciResponsesByVideo[videoID] : nil;
}
+ (id)lastPlayerResponse { return sciLastResponse; }
+ (NSString *)lastVideoID { return sciLastVideoID; }

/// The video the player actually started, as opposed to the last one it built an object
/// for. YouTube makes those for clips it is preloading too, so the two are not the same
/// question — and a download that asked the wrong one reported the video as private.
static NSString *sciActiveVideoID = nil;

/// What the format request did, client by client.
static NSMutableArray<NSString *> *sciStreamAttempts = nil;

+ (void)recordActiveVideoID:(NSString *)videoID {
    if (!videoID.length) return;

    sciActiveVideoID = [videoID copy];

    // The attempts are deliberately *not* cleared here.
    //
    // They used to be, so that the list always belonged to the video on screen. But
    // YouTube re-announces a video while one is being saved -- on a quality change, on a
    // resume -- and that wiped the record halfway through a download. The line naming
    // what the playlist turned out to be was gone by the time anyone opened the page,
    // which is exactly when it was wanted.
    //
    // The download clears them when it starts a round, which is the moment that actually
    // marks one attempt from the next.
}

+ (NSString *)activeVideoID { return sciActiveVideoID; }

/// Guarded, because this list is the one piece of the report written from more than one
/// thread, and it crashed the app the moment a second writer appeared.
///
/// Until 0.12.0 only the format request wrote here, always from its own network callback,
/// and one writer needs no lock. Then the transport converter began recording what a
/// stream declared -- from the conversion queue, while the report was being rendered on
/// the main thread. Mutating an array while it is enumerated is not a race that sometimes
/// loses a line; it throws, and the app went down the instant a download reached 100%.
///
/// The lock is on the class object so every path here shares one, and `attempts` hands
/// out a copy: a caller holding a snapshot cannot be enumerating the live array.
+ (void)clearStreamAttempts {
    @synchronized (self) {
        sciStreamAttempts = nil;
    }
}

+ (void)recordStreamAttempt:(NSString *)line {
    if (!line.length) return;

    @synchronized (self) {
        if (!sciStreamAttempts) sciStreamAttempts = [NSMutableArray array];

        // Bounded: two clients per video, and a run that somehow retried without end must
        // not turn the report into a log file. Raised from eight, because the download
        // path now contributes lines of its own and the earliest ones -- which say what
        // the playlist was -- must not be pushed out by the latest.
        if (sciStreamAttempts.count < 16) [sciStreamAttempts addObject:[line copy]];
    }
}

+ (NSArray<NSString *> *)attempts {
    @synchronized (self) {
        return [sciStreamAttempts copy];
    }
}
+ (NSString *)lastVideoTitle { return sciLastVideoTitle; }

+ (NSString *)appVersion {
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    return version.length ? version : @"unknown";
}

/// A protobuf message prints its whole tree from -description, which is the entire
/// reason this page can report the truth without a single hard-coded field name.
/// Guarded all the same: an object that is not what we expect must produce a line in
/// the report, not a crash inside a diagnostic.
+ (NSString *)describeMessage:(id)message {
    if (!message) return nil;

    @try {
        NSString *text = [message description];
        return text.length ? text : nil;
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"<%@ could not be described: %@>",
                NSStringFromClass([message class]), exception.reason];
    }
}

+ (NSString *)report {
    NSMutableString *out = [NSMutableString string];

    [out appendFormat:@"%@\n", SCILocalized(@"diag_build")];
    [out appendFormat:@"  %@: %@\n", SCILocalized(@"diag_tweak_version"), SCIVersionString];
    [out appendFormat:@"  %@: %@\n", SCILocalized(@"diag_app_version"), [self appVersion]];
    [out appendFormat:@"  %@: %@\n\n", SCILocalized(@"diag_bundle"),
        [[NSBundle mainBundle] bundleIdentifier] ?: @"?"];

    // Before anything else: how far this launch got. A report whose every section says "nothing
    // yet" is a report of a launch that never got anywhere, and until this line it could not say
    // where it stopped -- which is the state a device came back in.
    [out appendFormat:@"HOW FAR THIS LAUNCH GOT\n  %@\n  %@\n\n",
        SCIYTLaunchTrail(), SCIYTLaunchGuardReport()];

    [out appendFormat:@"%@\n", SCILocalized(@"diag_attached")];
    for (NSDictionary *row in SCIAuditTable()) {
        NSString *name = row[@"class"];
        BOOL present = objc_getClass([name UTF8String]) != NULL;
        [out appendFormat:@"  [%@] %@ — %@\n",
            present ? SCILocalized(@"diag_present") : SCILocalized(@"diag_absent"),
            name, row[@"why"]];
    }
    [out appendString:@"\n"];

    // First, because it is the answer to "I held two fingers and nothing happened".
    if (sciPanelFailure.length) {
        [out appendFormat:@"%@\n  %@\n\n", SCILocalized(@"diag_panel_failed"), sciPanelFailure];
    }

    // Printed before the video section because when the settings section itself is
    // missing, this is the part that says why -- and in 0.1.0 it was missing.
    [out appendFormat:@"%@\n", SCILocalized(@"diag_groups")];
    [out appendString:sciSettingsGroups ?: [NSString stringWithFormat:@"  %@\n",
        SCILocalized(@"diag_groups_none")]];
    [out appendString:@"\n"];

    // Before the video section, because when someone says "it never skips anything"
    // this line is the answer: whether a video ID was read, whether segments came
    // back, and whether a skip was performed.
    [out appendFormat:@"%@\n  %@\n  %@\n\n", SCILocalized(@"diag_sponsor"),
        sciSponsorState ?: SCILocalized(@"diag_sponsor_none"),
        sciMarkerBar ?: SCILocalized(@"diag_markers_none")];

    // Which counter buttons were seen and what each said before anything was written into
    // button -- or on none -- this is the line that says why.
    [out appendFormat:@"%@\n  %@\n\n", SCILocalized(@"diag_tab"), [self tabState]];
    [out appendFormat:@"  %@\n", SCIYTTabBarReport()];
    [out appendFormat:@"  %@\n\n", SCIYTHistoryTabReport()];

    // What the saved-media player last handed the lock screen, for whichever kinds were
    // actually played -- the fact needed to settle whether "sound does not show" is a
    // real difference between the two paths or a report about something else entirely.
    [out appendFormat:@"%@\n  %@\n\n", SCILocalized(@"diag_lock_screen"), [self lockScreenState]];

    // The ad-slot probe -- what a cluster of selectors two other tweaks touch actually
    // answer on this build's own player response, measured rather than guessed at before
    // any of them gets hooked.
    [out appendFormat:@"%@\n  %@\n\n", SCILocalized(@"diag_ad_slots"), [self adSlotProbeState]];

    // What the feed filter saw. 0.20.1 shipped a wider ad list and this line to judge it by,
    // and the line never got written -- so the release changed what is hidden and removed
    // the only way to tell what it hid.
    [out appendFormat:@"%@\n  %@\n  %@\n\n", SCILocalized(@"diag_feed"), [self feedState], [self feedEntryPoints]];

    // The actual content of the last batch the filter let through -- not just how many,
    // which section identifiers, so a scattered ad on Home can be matched to the exact
    // marker that needs adding to the list.
    [out appendFormat:@"%@\n  %@\n\n", SCILocalized(@"diag_feed_sample"), [self feedKeptSampleState]];

    // Above the Shorts lines because it is the surface a save now starts from. Empty means
    // no tap ever reached the hook, which is a different fault from a tap that was seen and
    // not answered -- the whole reason both numbers travel in this one string.
    [out appendFormat:@"%@\n  %@\n  %@\n\n", SCILocalized(@"diag_native_button"),
        [self nativeDownloadButtonState], [self nativeDownloadNote]];

    [out appendFormat:@"%@\n  %@\n\n", SCILocalized(@"diag_overlay"), [self overlayButtonState]];
    // In the report as well as on the screen. A row added to one and not the other is a round
    // trip spent looking for a line that was never where it was being looked for.
    [out appendFormat:@"%@\n  %@\n\n", SCILocalized(@"diag_action_row_title"), [self actionRowState]];
    [out appendFormat:@"%@\n  %@\n\n", SCILocalized(@"diag_action_bar_title"), [self actionBarState]];
    [out appendFormat:@"%@\n%@\n\n", SCILocalized(@"diag_scan_title"), [self watchScanState]];

    // The row's own class, as this device declares it. Printed unconditionally rather than
    // behind a switch: it is the one question three releases of this feature have turned on,
    // and it costs one runtime call.
    [out appendFormat:@"%@\n  %@\n\n", SCILocalized(@"diag_methods_title"),
        [self methodsOfClassNamed:@"YTSlimVideoScrollableDetailsActionsView"]];

    [out appendFormat:@"%@\n  %@\n\n", SCILocalized(@"diag_shorts"), [self shortsButtonState]];

    [out appendFormat:@"%@\n  %@\n\n", SCILocalized(@"diag_shorts_save"), [self shortsSaveState]];

    [out appendFormat:@"%@\n  %@\n\n", SCILocalized(@"diag_shorts_resp"), [self shortsResponseState]];

    // All three at once, because the download bug was exactly these disagreeing and no
    // report ever showed more than two of them.
    [out appendFormat:@"%@\n  %@\n\n", SCILocalized(@"diag_ids"),
        [NSString stringWithFormat:SCILocalized(@"diag_ids_line"),
            sciLastVideoID ?: @"?", sciActiveVideoID ?: @"?", sciResponseVideoID ?: @"?"]];

    [out appendFormat:@"%@\n  %@\n\n", SCILocalized(@"diag_shorts_ads"), [self shortsAdState]];

    [out appendFormat:@"%@\n  %@\n\n", SCILocalized(@"diag_ad_gates"), [self adGateState]];

    // Above the streams section on purpose: it says what was asked of the streaming protocol,
    // and the section below says what came back. Read the other way round they are two
    // unrelated facts.
    [out appendFormat:@"%@\n  %@\n\n", SCILocalized(@"diag_sabr"), [self sabrState]];

    // Why a saved file would not open. This is the one thing looking at the tweak's own code
    // can never answer: the file is on disk and AVFoundation is the only witness to what is
    // wrong with it.
    [out appendFormat:@"%@\n  %@\n\n", SCILocalized(@"diag_playback"), [self playbackFailures]];

    [out appendFormat:@"%@\n", SCILocalized(@"diag_video")];

    if (!sciLastResponse && !sciLastStreamingData && !sciLastVideoID) {
        [out appendFormat:@"  %@\n", SCILocalized(@"diag_no_video")];
        return out;
    }

    if (sciLastVideoID.length) {
        [out appendFormat:@"  %@: %@\n", SCILocalized(@"diag_video_id"), sciLastVideoID];
    }

    // Printed beside it, and only when the two disagree. A silent mismatch here is what
    // sent the download asking YouTube about a video nobody was watching; the ids being
    // equal is the normal case and not worth a line.
    if (sciActiveVideoID.length && ![sciActiveVideoID isEqualToString:sciLastVideoID]) {
        [out appendFormat:@"  %@: %@\n", SCILocalized(@"diag_active_video"), sciActiveVideoID];
    }

    // A snapshot, never the live array: a download writing its next line while this
    // enumerates is the crash described above.
    NSArray<NSString *> *attempts = [self attempts];
    if (attempts.count) {
        [out appendFormat:@"\n%@\n", SCILocalized(@"diag_stream_attempts")];
        for (NSString *line in attempts) {
            [out appendFormat:@"  %@\n", line];
        }
    }

    // Enumerated rather than described: MLStreamingData is not a protobuf and its
    // -description is a class name and an address, which is what this section printed
    // for four releases.
    // What the downloader makes of the same streams, first: it answers "can this video
    // be saved" in one line, where the dump below answers "why not".
    [out appendFormat:@"\n%@\n  %@\n", SCILocalized(@"diag_downloadable"),
        [SCIYTDownload diagnosticsSummary]];

    NSString *streams = [self describeStreams:sciLastStreamingData];
    if (streams.length) {
        [out appendFormat:@"\n%@\n%@\n", SCILocalized(@"diag_streams"), streams];
    }

    NSString *full = [self describeMessage:sciLastResponse];
    if (full) {
        [out appendFormat:@"\n%@\n%@\n%@\n",
            SCILocalized(@"diag_response"), SCILocalized(@"diag_response_note"), full];
    }

    return out;
}

/// One value from an object, boxed, or nil. KVC rather than -performSelector: it
/// returns numbers as NSNumber without the caller having to know the return type,
/// which is the whole difficulty with an unfamiliar class.
+ (id)value:(NSString *)key from:(id)object {
    if (!object || !key.length) return nil;
    @try {
        if (![object respondsToSelector:NSSelectorFromString(key)]) return nil;
        return SCISafeValueForKey(object, key);
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

/// What MLStreamingData actually holds.
///
/// Its -description prints the class and an address and nothing else: it is not a
/// protobuf, so the trick that makes the player response readable does not work here,
/// and this section of the report has been saying "<MLStreamingData: 0x...>" since
/// 0.1.0 — the one measurement the download feature was waiting on.
///
/// The question is narrow and worth stating: does this build hand out plain file URLs
/// per format, or only the piecewise UMP/ABR stream? A URL in the list below means the
/// first; an empty list, or formats with no URL, means the second — and the difference
/// is a week of work against a month of it.
+ (NSString *)describeStreams:(id)streamingData {
    if (!streamingData) return nil;

    NSMutableString *out = [NSMutableString string];
    [out appendFormat:@"  class: %@\n", NSStringFromClass([streamingData class])];

    // The names both this app and other tweaks use for the format lists. Asked in
    // order; every one that answers is reported, because which of them is populated
    // is exactly what is unknown.
    NSArray<NSString *> *containers = @[
        @"adaptiveStreams", @"adaptiveFormats", @"adaptiveFormatsArray",
        @"formats", @"formatsArray", @"allFormats", @"streams", @"videoStreams",
        @"audioStreams", @"progressiveStreams", @"hlsManifestURL", @"dashManifestURL",
    ];

    BOOL foundAny = NO;

    for (NSString *name in containers) {
        id value = [self value:name from:streamingData];
        if (!value) continue;

        foundAny = YES;

        if (![value isKindOfClass:[NSArray class]]) {
            [out appendFormat:@"  %@: %@\n", name, value];
            continue;
        }

        NSArray *list = value;
        [out appendFormat:@"  %@: %lu\n", name, (unsigned long)list.count];

        // Twelve is more than enough to see the shape of the ladder, and keeps the
        // page inside what a person will actually read.
        NSUInteger shown = MIN(list.count, (NSUInteger)12);
        for (NSUInteger i = 0; i < shown; i++) {
            id stream = list[i];

            id itag = [self value:@"itag" from:stream];
            NSString *mime = [self string:[self value:@"MIMEType" from:stream]
                                            ?: [self value:@"mimeType" from:stream]];
            NSString *quality = [self string:[self value:@"qualityLabel" from:stream]
                                               ?: [self value:@"quality" from:stream]];
            id width = [self value:@"width" from:stream];
            id height = [self value:@"height" from:stream];
            id fps = [self value:@"fps" from:stream] ?: [self value:@"frameRate" from:stream]
                     ?: [self value:@"videoFrameRate" from:stream];
            id bitrate = [self value:@"bitrate" from:stream] ?: [self value:@"averageBitrate" from:stream];

            // The decisive question, and the reason the whole page exists: is there a
            // fetchable link per format, or does playback go through the piecewise
            // protocol only? The first probe answered "?cpn=..." — a query fragment,
            // not a URL — so every name the stream might keep a real one under is asked
            // for, and the one that answered is named alongside it.
            // Every name that answers, not the first.
            //
            // This probe used to stop at the first non-empty one, and that single `break`
            // steered four releases down the wrong road. `URL` answers with "?cpn=…" — a
            // fragment — so the loop reported that and never tried `url`, `baseURL` or any
            // of the rest even once. "No links anywhere" was a conclusion drawn from a
            // list of one.
            //
            // The reference tweak whose download works reads `URL` and falls through to
            // the nested formatStream when it is not usable, which is exactly the step
            // this report was unable to show.
            NSMutableArray<NSString *> *links = [NSMutableArray array];

            for (NSString *key in @[@"URL", @"url", @"baseURL", @"streamURL", @"videoURL",
                                    @"assetURL", @"mediaURL", @"urlString", @"URLString",
                                    @"absoluteURL", @"downloadURL"]) {
                id candidate = [self value:key from:stream];
                if (!candidate) continue;

                NSString *text = [candidate isKindOfClass:[NSURL class]]
                    ? [(NSURL *)candidate absoluteString] : [self string:candidate];
                if (!text.length) continue;

                // A signed CDN link runs to a thousand characters of query string; the
                // opening is enough to tell a real one from a fragment.
                NSString *shown = text.length > 90
                    ? [[text substringToIndex:90] stringByAppendingString:@"…"] : text;
                [links addObject:[NSString stringWithFormat:@"%@ = %@", key, shown]];
            }

            NSString *link = links.count
                ? [links componentsJoinedByString:@"\n      "]
                : @"none";

            [out appendFormat:@"    [%@] %@ %@ %@x%@ %@fps %@bps\n      %@\n",
                itag ?: @"?", mime ?: @"?", quality ?: @"?",
                width ?: @"?", height ?: @"?", fps ?: @"?", bitrate ?: @"?", link];
        }

        if (list.count > shown) {
            [out appendFormat:@"    … and %lu more\n", (unsigned long)(list.count - shown)];
        }

        // What else a stream can be asked, taken from the runtime rather than guessed.
        // Printed once: if the fields above came back empty, this is the list that says
        // what to ask for instead.
        if (list.count) {
            [out appendFormat:@"  stream class: %@\n", NSStringFromClass([list.firstObject class])];
            [out appendFormat:@"  stream offers: %@\n", [self zeroArgumentSelectorsOn:list.firstObject]];

            // And what is nested inside it, which is the one place left to look.
            //
            // Every stream in a real report answered -URL with "?cpn=..." — a query
            // fragment and not a link — and four of the twelve were H.264, which iOS
            // plays. So the codec was never the obstacle; the missing link was. The
            // outer stream does not hold one, and this says whether the inner one does.
            //
            // If it does not either, the answer is settled: this build hands out no file
            // URLs at all and downloading has to go through YouTube's own downloader or
            // the piecewise protocol. That is a different project, and worth knowing
            // before starting it rather than after.
            id nested = [self value:@"formatStream" from:list.firstObject];
            if (nested) {
                [out appendFormat:@"  formatStream class: %@\n", NSStringFromClass([nested class])];
                [out appendFormat:@"  formatStream offers: %@\n",
                    [self zeroArgumentSelectorsOn:nested]];

                for (NSString *key in @[@"URL", @"url", @"baseURL", @"urlString"]) {
                    id candidate = [self value:key from:nested];
                    if (!candidate) continue;

                    NSString *text = [candidate isKindOfClass:[NSURL class]]
                        ? [(NSURL *)candidate absoluteString] : [self string:candidate];
                    if (!text.length) continue;

                    NSString *head = text.length > 120
                        ? [[text substringToIndex:120] stringByAppendingString:@"…"] : text;
                    [out appendFormat:@"  formatStream %@ = %@\n", key, head];
                }

                // A GPBMessage prints its whole tree, which for a format stream is every
                // field it carries — the fastest way to see a link that is under a name
                // nobody thought to ask for.
                NSString *tree = [self describeMessage:nested];
                if (tree.length && tree.length < 4000) {
                    [out appendFormat:@"  formatStream contents:\n%@\n", tree];
                }
            } else {
                [out appendString:@"  formatStream: nothing nested\n"];
            }
        }
    }

    if (!foundAny) {
        [out appendFormat:@"  no format list answered. offers: %@\n",
            [self zeroArgumentSelectorsOn:streamingData]];
    }

    return out;
}

/// The zero-argument selectors a class declares, as one line.
///
/// Asking the runtime instead of guessing is how the Instagram side found the DASH
/// manifest after three wrong guesses. Bounded, and only the class's own methods:
/// walking every superclass would print most of NSObject.
+ (NSString *)zeroArgumentSelectorsOn:(id)object {
    if (!object) return @"—";

    NSMutableArray<NSString *> *names = [NSMutableArray array];

    // Up the chain, not just the class itself. MLRemoteStream declares almost nothing
    // of its own -- the accessors are on its superclass -- so asking only the class
    // printed an empty list, which read as "this object offers nothing" when it in
    // fact offers everything the download feature needs to know about.
    //
    // Stopping before NSObject keeps -hash, -description and the rest out of it.
    Class cls = [object class];
    NSInteger levels = 0;

    while (cls && cls != [NSObject class] && levels++ < 6 && names.count < 90) {
        unsigned int count = 0;
        Method *methods = class_copyMethodList(cls, &count);

        for (unsigned int i = 0; i < count && names.count < 90; i++) {
            NSString *name = NSStringFromSelector(method_getName(methods[i]));
            if ([name containsString:@":"]) continue;      // takes arguments
            if ([name hasPrefix:@"."]) continue;           // .cxx_destruct
            if ([name hasPrefix:@"set"]) continue;         // setters answer nothing useful
            if ([names containsObject:name]) continue;     // overridden further down
            [names addObject:name];
        }

        free(methods);
        cls = class_getSuperclass(cls);
    }

    [names sortUsingSelector:@selector(compare:)];
    return names.count ? [names componentsJoinedByString:@", "] : @"—";
}

/// A value as text, whatever kind of object it turns out to be.
///
/// MIMEType came back as <HAMMIMEType: 0x…> — a wrapper, not a string — so the report
/// printed an address where a type should be. Anything that is not already a string is
/// asked for one before being given up on.
+ (NSString *)string:(id)value {
    if (!value) return nil;
    if ([value isKindOfClass:[NSString class]]) return value;
    if ([value isKindOfClass:[NSNumber class]]) return [value stringValue];

    for (NSString *key in @[@"stringValue", @"string", @"type", @"name", @"value"]) {
        id inner = [self value:key from:value];
        if ([inner isKindOfClass:[NSString class]] && [inner length]) return inner;
    }

    return [value description];
}

+ (NSString *)reportForDisplay {
    NSString *full = [self report];

    // 40 KB is far more than anyone reads on a phone and far less than TextKit
    // struggles with. The cut is announced rather than silent: a report that stops
    // without saying so is a report nobody can trust.
    const NSUInteger limit = 40000;
    if (full.length <= limit) return full;

    NSString *path = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"]
                      stringByAppendingPathComponent:@"AlbrhiYT-report.txt"];

    return [NSString stringWithFormat:@"%@\n\n%@",
            [full substringToIndex:limit],
            [NSString stringWithFormat:SCILocalized(@"diag_truncated"), path]];
}

+ (NSString *)writeReportToFile {
    NSString *directory = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSString *path = [directory stringByAppendingPathComponent:@"AlbrhiYT-report.txt"];

    NSError *error = nil;
    BOOL written = [[self report] writeToFile:path
                                   atomically:YES
                                     encoding:NSUTF8StringEncoding
                                        error:&error];

    // NSLog and not SCILogV: this line is the fallback for the case where the
    // settings section did not appear, so it cannot be behind a switch that only
    // that section can reach.
    if (written) {
        NSLog(@"[AlbrhiYT] report written to %@", path);
        return path;
    }

    NSLog(@"[AlbrhiYT] could not write the report to %@: %@", path, error.localizedDescription);
    return nil;
}

+ (UIViewController *)viewController {
    UIViewController *host = [[UIViewController alloc] init];
    host.title = SCILocalized(@"diag_title");
    host.view.backgroundColor = UIColor.systemBackgroundColor;

    // A text view rather than a table: the report is one long body of text whose
    // value is that it can be copied whole, and a table would invite splitting it
    // into rows that each lose the context of the one above.
    UITextView *text = [[UITextView alloc] init];
    text.translatesAutoresizingMaskIntoConstraints = NO;
    text.editable = NO;
    text.backgroundColor = UIColor.clearColor;
    text.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    text.text = [SCIYTDiagnostics reportForDisplay];
    text.textContainerInset = UIEdgeInsetsMake(16, 14, 16, 14);
    [host.view addSubview:text];

    // The button reports back in its own title. A HUD would be another dependency
    // for one line of feedback, and the title is where the user is already looking.
    //
    // The button is held by a **strong** local, and this is the whole bug that made
    // this page crash the app for four releases.
    //
    // It used to be assigned straight into a __weak variable so the handler block
    // could reference it without a cycle. But a freshly built button assigned only to
    // a weak reference has nothing retaining it, and ARC is entitled to release it on
    // the spot -- so `copyButton` was nil before the next line ran. -addSubview: on nil
    // does nothing, and then `copyButton.topAnchor` was nil too, which is what
    // "a constraint cannot be made from an anchor to a constant" actually means: the
    // other side of the pair was missing. The report named it once the page was
    // wrapped, which is the argument for wrapping it.
    //
    // Strong for the layout, weak inside the handler, which is the pairing that was
    // wanted in the first place.
    UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [copyButton setTitle:SCILocalized(@"diag_copy") forState:UIControlStateNormal];

    __weak UIButton *weakCopy = copyButton;
    UIAction *action = [UIAction actionWithTitle:@""
                                          image:nil
                                     identifier:nil
                                        handler:^(__kindof UIAction *sender) {
        UIPasteboard.generalPasteboard.string = [SCIYTDiagnostics report];
        [weakCopy setTitle:SCILocalized(@"diag_copied") forState:UIControlStateNormal];
    }];
    [copyButton addAction:action forControlEvents:UIControlEventPrimaryActionTriggered];

    copyButton.translatesAutoresizingMaskIntoConstraints = NO;
    copyButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    copyButton.backgroundColor = [UIColor.systemBlueColor colorWithAlphaComponent:0.14];
    copyButton.layer.cornerRadius = 14;
    copyButton.layer.cornerCurve = kCACornerCurveContinuous;
    [host.view addSubview:copyButton];

    UILayoutGuide *safe = host.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [text.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [text.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [text.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [text.bottomAnchor constraintEqualToAnchor:copyButton.topAnchor constant:-12],

        [copyButton.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [copyButton.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [copyButton.heightAnchor constraintEqualToConstant:48],
        [copyButton.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-12],
    ]];

    return host;
}

@end
