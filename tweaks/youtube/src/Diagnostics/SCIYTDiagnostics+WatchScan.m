//
//  SCIYTDiagnostics+WatchScan.m
//  Albrhi for YouTube
//
//  The scan of the live watch page: which view classes it is built from.
//
//  Split out of SCIYTDiagnostics.m, which had grown to 1,783 lines holding every feature's
//  record as well as the report itself. This part keeps two variables of its own and nothing else
//  reads them, so it moves whole, as a category, with nothing about the report changed.
//
#import "SCIYTDiagnostics.h"
#import "SCIYTDiagnosticsInternal.h"
#import "../SCIYTLaunchGuard.h"
#import "shared/src/SCIKVC.h"
#import "../YouTubeHeaders.h"
#import "../Tweak.h"
#import "../SCILog.h"
#import "../Prefs.h"
#import "../Localization/SCILocalize.h"
#import "../Features/Download/SCIYTDownload.h"
#import "../Features/Download/Center/SCIYTWatch.h"
#import "../Features/Playback/SCIYTPoProbe.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import "../Features/Tabs/SCIYTTabBar.h"
#import "../Features/Tabs/SCIYTHistoryTab.h"

@implementation SCIYTDiagnostics (WatchScan)

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
            if (candidate.isKeyWindow) { window = candidate; break; }   // sci-allow-keywindow: picks the largest window, which SCIYTKeyWindow() does not

            CGFloat area = candidate.bounds.size.width * candidate.bounds.size.height;
            CGFloat best = window.bounds.size.width * window.bounds.size.height;
            if (!window || area > best) window = candidate;
        }
        if (window.isKeyWindow) break;   // sci-allow-keywindow
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

@end
