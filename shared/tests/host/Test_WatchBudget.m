//
//  Test_WatchBudget.m -- the rule behind SCIWatchBudget
//
#import <Foundation/Foundation.h>
#import "shared/src/SCIWatchBudget.h"

static int failures = 0, checks = 0;
#define CHECK(cond, ...) do { checks++; if (!(cond)) { failures++; NSLog(@"FAIL: %@", __VA_ARGS__); } } while (0)

int main(void) {
    @autoreleasepool {
        SCIWatchLimits off = {0, 0};
        SCIWatchLimits v20 = {20, 0};
        SCIWatchLimits m30 = {0, 30};
        SCIWatchLimits both = {20, 30};
        SCIWatchTotals zero = {0, 0, 0, 0, 0};
        NSInteger now = 1000000;

        CHECK(SCIWatchBudgetCheck((SCIWatchTotals){9999, 999999, 0, 0, 0}, off, now) == SCIWatchReasonNone, @"no limit, never asks");

        // The limit is reached when the counter is AT it.
        CHECK(SCIWatchBudgetCheck((SCIWatchTotals){19, 0, 0, 0, 0}, v20, now) == SCIWatchReasonNone, @"19 of 20");
        CHECK(SCIWatchBudgetCheck((SCIWatchTotals){20, 0, 0, 0, 0}, v20, now) == SCIWatchReasonVideos, @"20 of 20");
        CHECK(SCIWatchBudgetCheck((SCIWatchTotals){0, 30 * 60 - 1, 0, 0, 0}, m30, now) == SCIWatchReasonNone, @"29:59");
        CHECK(SCIWatchBudgetCheck((SCIWatchTotals){0, 30 * 60, 0, 0, 0}, m30, now) == SCIWatchReasonMinutes, @"30:00");

        // Whichever comes first.
        CHECK(SCIWatchBudgetCheck((SCIWatchTotals){5, 31 * 60, 0, 0, 0}, both, now) == SCIWatchReasonMinutes, @"minutes first");
        CHECK(SCIWatchBudgetCheck((SCIWatchTotals){21, 60, 0, 0, 0}, both, now) == SCIWatchReasonVideos, @"videos first");

        // Keep going: ten more FROM NOW, even when the person was already past the limit (the app was in the background at the 20th).
        SCIWatchTotals t = {23, 0, 0, 0, 0};
        t = SCIWatchBudgetKeepGoing(t, v20, SCIWatchReasonVideos);
        CHECK(t.extraVideos == 13, @"allowance is measured from where they are");
        CHECK(SCIWatchBudgetCheck((SCIWatchTotals){32, 0, t.extraVideos, 0, 0}, v20, now) == SCIWatchReasonNone, @"32 of 33");
        CHECK(SCIWatchBudgetCheck((SCIWatchTotals){33, 0, t.extraVideos, 0, 0}, v20, now) == SCIWatchReasonVideos, @"asks again at 33");
        t = (SCIWatchTotals){0, 31 * 60, 0, 0, 0};
        t = SCIWatchBudgetKeepGoing(t, m30, SCIWatchReasonMinutes);
        CHECK(t.extraSeconds == 60 + 600, @"minutes: from where they are");

        // Keep going on one counter does not silence the other.
        t = (SCIWatchTotals){25, 31 * 60, 0, 0, 0};
        t = SCIWatchBudgetKeepGoing(t, both, SCIWatchReasonVideos);
        CHECK(SCIWatchBudgetCheck(t, both, now) == SCIWatchReasonMinutes, @"the other limit still holds");

        // Remind later is quiet for five minutes, then asks again.
        t = (SCIWatchTotals){20, 0, 0, 0, 0};
        t = SCIWatchBudgetRemindLater(t, now);
        CHECK(SCIWatchBudgetCheck(t, v20, now + 299) == SCIWatchReasonNone, @"quiet");
        CHECK(SCIWatchBudgetCheck(t, v20, now + 300) == SCIWatchReasonVideos, @"asks again");

        // A new day starts from nothing; the same day keeps everything.
        t = (SCIWatchTotals){12, 700, 3, 60, 5};
        SCIWatchTotals same = SCIWatchBudgetRollover(t, @"2026-11-10", @"2026-11-10");
        CHECK(same.videos == 12 && same.seconds == 700 && same.extraVideos == 3, @"same day");
        SCIWatchTotals next = SCIWatchBudgetRollover(t, @"2026-11-10", @"2026-11-11");
        CHECK(next.videos == 0 && next.seconds == 0 && next.extraVideos == 0 && next.extraSeconds == 0 && next.quietUntil == 0, @"new day");
        SCIWatchTotals unseen = SCIWatchBudgetRollover(t, nil, @"2026-11-11");
        CHECK(unseen.videos == 0, @"no stored day starts fresh");
        (void)zero;
    }
    printf("SCIWatchBudget rule: %d checks, %d failed\n", checks, failures);
    return failures ? 1 : 0;
}
