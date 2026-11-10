//
//  SCIWatchBudgetRule.m
//  Albrhi -- shared
//
//  The rule on its own, with no UIKit (shared/tests/host).
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCIWatchBudget.h"

const NSInteger SCIWatchStepVideos = 10;
const NSInteger SCIWatchStepSeconds = 600;
const NSInteger SCIWatchQuietSeconds = 300;

SCIWatchReason SCIWatchBudgetCheck(SCIWatchTotals t, SCIWatchLimits l, NSInteger now) {
    if (now < t.quietUntil) return SCIWatchReasonNone;
    if (l.maxVideos > 0 && t.videos >= l.maxVideos + t.extraVideos) return SCIWatchReasonVideos;
    if (l.maxMinutes > 0 && t.seconds >= l.maxMinutes * 60 + t.extraSeconds) return SCIWatchReasonMinutes;
    return SCIWatchReasonNone;
}

SCIWatchTotals SCIWatchBudgetKeepGoing(SCIWatchTotals t, SCIWatchLimits l, SCIWatchReason reason) {
    // The allowance is measured from where the person is, not from where the limit was, so "keep going" always means "ten more from now".
    if (reason == SCIWatchReasonVideos) t.extraVideos = MAX(0, t.videos - l.maxVideos) + SCIWatchStepVideos;
    if (reason == SCIWatchReasonMinutes) t.extraSeconds = MAX(0, t.seconds - l.maxMinutes * 60) + SCIWatchStepSeconds;
    t.quietUntil = 0;
    return t;
}

SCIWatchTotals SCIWatchBudgetRemindLater(SCIWatchTotals t, NSInteger now) {
    t.quietUntil = now + SCIWatchQuietSeconds;
    return t;
}

SCIWatchTotals SCIWatchBudgetRollover(SCIWatchTotals t, NSString *stored, NSString *key) {
    if ([stored isEqualToString:key]) return t;
    return (SCIWatchTotals){0, 0, 0, 0, 0};
}
