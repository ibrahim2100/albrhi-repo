//
//  SCIWatchBudget.h
//  Albrhi -- shared
//
//  A gentle daily limit on how many short videos and how many minutes a person spends in an app: a card with the numbers, no lock.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Today's counters and the extra allowance granted by "keep going".
typedef struct {
    NSInteger videos;
    NSInteger seconds;
    NSInteger extraVideos;    // allowance added on top of the limit by "keep going"
    NSInteger extraSeconds;
    NSInteger quietUntil;     // unix time before which nothing is asked ("remind me later")
} SCIWatchTotals;

/// 0 means "no limit" for that counter.
typedef struct {
    NSInteger maxVideos;
    NSInteger maxMinutes;
} SCIWatchLimits;

typedef NS_ENUM(NSInteger, SCIWatchReason) {
    SCIWatchReasonNone = 0,
    SCIWatchReasonVideos,
    SCIWatchReasonMinutes,
};

/// How much more "keep going" allows, and how long "remind me later" is quiet.
FOUNDATION_EXPORT const NSInteger SCIWatchStepVideos;     // 10
FOUNDATION_EXPORT const NSInteger SCIWatchStepSeconds;    // 600
FOUNDATION_EXPORT const NSInteger SCIWatchQuietSeconds;   // 300

/// The rule (pure). The limit is reached when the counter is *at* it, so "20 videos" asks after the twentieth.
FOUNDATION_EXPORT SCIWatchReason SCIWatchBudgetCheck(SCIWatchTotals totals, SCIWatchLimits limits, NSInteger now);

/// "Keep going": allows `Step` more of whatever was reached.
FOUNDATION_EXPORT SCIWatchTotals SCIWatchBudgetKeepGoing(SCIWatchTotals totals, SCIWatchLimits limits, SCIWatchReason reason);

/// "Remind me later".
FOUNDATION_EXPORT SCIWatchTotals SCIWatchBudgetRemindLater(SCIWatchTotals totals, NSInteger now);

/// A new day starts from zero. `dayKey` is a string that changes at local midnight (e.g. "2026-11-10").
FOUNDATION_EXPORT SCIWatchTotals SCIWatchBudgetRollover(SCIWatchTotals totals, NSString *_Nullable storedDay, NSString *dayKey);

/// The limits, read live from the tweak's own settings each time they are needed. 0/0 switches the budget off completely.
FOUNDATION_EXPORT void SCIWatchBudgetSetProvider(SCIWatchLimits (^provider)(void));

/// A new short video came on screen. The same key twice in a row is one video. Cheap; main thread.
FOUNDATION_EXPORT void SCIWatchBudgetNoteVideo(NSString *key);

/// One line for a diagnostics page: today's numbers and what was asked.
FOUNDATION_EXPORT NSString *SCIWatchBudgetReport(void);

NS_ASSUME_NONNULL_END
