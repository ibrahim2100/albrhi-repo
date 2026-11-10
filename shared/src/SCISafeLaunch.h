//
//  SCISafeLaunch.h
//  Albrhi -- shared
//
//  If an app does not manage to start twice in a row while Albrhi is in it, Albrhi steps aside for the next launch and says so.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// The decision a launch gets. Pure data so the rule can be tested without an app.
typedef struct {
    BOOL pending;      // the previous launch never reached "started fine" or "left on purpose"
    NSInteger failures; // launches in a row that ended that way
    BOOL paused;       // Albrhi stands down until the person brings it back
} SCISafeLaunchState;

/// What can happen to a launch.
typedef NS_ENUM(NSInteger, SCISafeLaunchEvent) {
    SCISafeLaunchEventBegin,        // the tweak was loaded and is about to install its hooks
    SCISafeLaunchEventBackground,   // the process was started in the background (a push, a fetch): not a launch the person waited for
    SCISafeLaunchEventStable,       // the app has been on screen and active for a few seconds
    SCISafeLaunchEventLeft,         // the app went to the background or was ended by the system, on purpose
    SCISafeLaunchEventResume,       // the person chose to bring Albrhi back
};

/// How many launches in a row may fail before Albrhi steps aside. Two: one bad launch can be anything; a second in a row is a pattern.
FOUNDATION_EXPORT const NSInteger SCISafeLaunchLimit;

/// The rule. `Begin` is the only event that can pause (it is the next launch that finds the last one unfinished).
FOUNDATION_EXPORT SCISafeLaunchState SCISafeLaunchStep(SCISafeLaunchState state, SCISafeLaunchEvent event);

/// Whether Albrhi must stand down in this process. The first call counts this launch (so it must come before any hook is installed --
/// `SCIPanelAllowsThisApp()` does that, and every tweak already asks it first). Answers NO without recording anything in anything that is not an
/// app (SpringBoard, daemons), where "did it become active" means something else.
FOUNDATION_EXPORT BOOL SCISafeLaunchPaused(void);

/// One line for a diagnostics page.
FOUNDATION_EXPORT NSString *SCISafeLaunchReport(void);

NS_ASSUME_NONNULL_END
