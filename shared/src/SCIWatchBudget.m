//
//  SCIWatchBudget.m
//  Albrhi -- shared
//
//  **What it is for.** "Prevent doom scrolling" existed in Instagram only, as a hard cap. This is the soft version for every app that has short
//  videos: it counts what you watched today (videos and minutes), and when you reach the limit *you* set, it shows the numbers and asks. It never locks
//  anything, never reads what the videos are, and everything stays on this phone in a file of its own.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCIWatchBudget.h"
#import <UIKit/UIKit.h>
#import "SCICard.h"

static SCIWatchLimits (^sciWBProvider)(void) = nil;
static SCIWatchTotals sciWBTotals;
static NSString *sciWBDay = nil, *sciWBLastKey = nil, *sciWBPath = nil;
static BOOL sciWBStarted = NO, sciWBActive = NO;
static CFAbsoluteTime sciWBTick = 0, sciWBLastSave = 0;
static NSUInteger sciWBAsked = 0, sciWBKept = 0, sciWBLater = 0;
static NSTimer *sciWBTimer = nil;

static NSString *SCIWBDayKey(void) {
    NSDateComponents *c = [[NSCalendar currentCalendar] components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:[NSDate date]];
    return [NSString stringWithFormat:@"%04ld-%02ld-%02ld", (long)c.year, (long)c.month, (long)c.day];
}

static NSString *SCIWBPath(void) {
    NSString *support = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
    if (!support.length) return nil;
    NSString *folder = [support stringByAppendingPathComponent:@"Albrhi"];
    [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
    return [folder stringByAppendingPathComponent:@"watch-budget.json"];
}

static void SCIWBLoad(void) {
    sciWBPath = SCIWBPath();
    NSData *data = sciWBPath ? [NSData dataWithContentsOfFile:sciWBPath] : nil;
    NSDictionary *d = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
    SCIWatchTotals t = {0, 0, 0, 0, 0};
    NSString *stored = nil;
    if ([d isKindOfClass:[NSDictionary class]]) {
        stored = d[@"day"];
        t.videos = MAX(0, [d[@"videos"] integerValue]);
        t.seconds = MAX(0, [d[@"seconds"] integerValue]);
        t.extraVideos = MAX(0, [d[@"extraVideos"] integerValue]);
        t.extraSeconds = MAX(0, [d[@"extraSeconds"] integerValue]);
        t.quietUntil = MAX(0, [d[@"quietUntil"] integerValue]);
    }
    sciWBDay = SCIWBDayKey();
    sciWBTotals = SCIWatchBudgetRollover(t, stored, sciWBDay);
}

static void SCIWBSave(void) {
    if (!sciWBPath) return;
    NSDictionary *d = @{@"day": sciWBDay ?: @"", @"videos": @(sciWBTotals.videos), @"seconds": @(sciWBTotals.seconds),
                        @"extraVideos": @(sciWBTotals.extraVideos), @"extraSeconds": @(sciWBTotals.extraSeconds), @"quietUntil": @(sciWBTotals.quietUntil)};
    [[NSJSONSerialization dataWithJSONObject:d options:0 error:NULL] writeToFile:sciWBPath options:NSDataWritingAtomic error:NULL];
    sciWBLastSave = CFAbsoluteTimeGetCurrent();
}

/// A new day since the last look: start from zero.
static void SCIWBRoll(void) {
    NSString *today = SCIWBDayKey();
    if ([today isEqualToString:sciWBDay]) return;
    sciWBTotals = SCIWatchBudgetRollover(sciWBTotals, sciWBDay, today);
    sciWBDay = today;
    sciWBLastKey = nil;
    SCIWBSave();
}

static NSString *SCIWBMinutesText(NSInteger seconds, BOOL ar) {
    NSInteger minutes = seconds / 60;
    if (minutes < 1) return ar ? @"أقل من دقيقة" : @"under a minute";
    return ar ? [NSString stringWithFormat:@"%ld دقيقة", (long)minutes] : [NSString stringWithFormat:@"%ld min", (long)minutes];
}

static void SCIWBCheck(void) {
    if (!sciWBProvider || SCICardIsShowing() || !sciWBActive) return;
    SCIWBRoll();
    SCIWatchLimits limits = sciWBProvider();
    NSInteger now = (NSInteger)[[NSDate date] timeIntervalSince1970];
    SCIWatchReason reason = SCIWatchBudgetCheck(sciWBTotals, limits, now);
    if (reason == SCIWatchReasonNone) return;

    BOOL ar = SCICardArabic();
    NSString *numbers = ar
        ? [NSString stringWithFormat:@"شفت %ld مقطع اليوم خلال %@.", (long)sciWBTotals.videos, SCIWBMinutesText(sciWBTotals.seconds, YES)]
        : [NSString stringWithFormat:@"You have watched %ld videos today in %@.", (long)sciWBTotals.videos, SCIWBMinutesText(sciWBTotals.seconds, NO)];
    NSString *title = reason == SCIWatchReasonVideos ? (ar ? @"وصلت حدّ المقاطع" : @"Video limit reached") : (ar ? @"وصلت حدّ الوقت" : @"Time limit reached");
    NSString *keep = ar ? (reason == SCIWatchReasonVideos ? @"كمّل 10 مقاطع" : @"كمّل 10 دقايق") : (reason == SCIWatchReasonVideos ? @"Keep going: 10 more" : @"Keep going: 10 more minutes");
    NSString *later = ar ? @"ذكّرني بعد 5 دقايق" : @"Remind me in 5 minutes";
    sciWBAsked++;
    BOOL shown = SCICardShow(title, [numbers stringByAppendingString:ar ? @"\nتبي تكمّل ولا تستريح؟" : @"\nKeep going, or take a break?"], @[keep, later], 0, ^(NSInteger index) {
        if (index == 0) { sciWBTotals = SCIWatchBudgetKeepGoing(sciWBTotals, limits, reason); sciWBKept++; }
        else { sciWBTotals = SCIWatchBudgetRemindLater(sciWBTotals, (NSInteger)[[NSDate date] timeIntervalSince1970]); sciWBLater++; }
        SCIWBSave();
    });
    if (!shown) sciWBAsked--;
}

static void SCIWBTickNow(void) {
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (sciWBActive && sciWBTick > 0) {
        // Real elapsed time, capped: a timer that slept through a call must not count the call as watching.
        double delta = now - sciWBTick;
        if (delta > 0 && delta < 15) sciWBTotals.seconds += (NSInteger)llround(delta);
    }
    sciWBTick = now;
    if (now - sciWBLastSave > 20) SCIWBSave();
    SCIWBCheck();
}

static void SCIWBStart(void) {
    if (sciWBStarted) return;
    sciWBStarted = YES;
    SCIWBLoad();
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    NSOperationQueue *main = [NSOperationQueue mainQueue];
    [center addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:main usingBlock:^(NSNotification *n) {
        sciWBActive = YES;
        sciWBTick = CFAbsoluteTimeGetCurrent();
        SCIWBRoll();
        if (!sciWBTimer) {
            sciWBTimer = [NSTimer scheduledTimerWithTimeInterval:5 repeats:YES block:^(NSTimer *t) { SCIWBTickNow(); }];
            sciWBTimer.tolerance = 1;
        }
    }];
    void (^away)(NSNotification *) = ^(NSNotification *n) {
        if (sciWBActive) SCIWBTickNow();
        sciWBActive = NO;
        sciWBTick = 0;
        SCIWBSave();
    };
    [center addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:main usingBlock:away];
    [center addObserverForName:UIApplicationWillTerminateNotification object:nil queue:main usingBlock:away];
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
        sciWBActive = YES;
        sciWBTick = CFAbsoluteTimeGetCurrent();
        sciWBTimer = [NSTimer scheduledTimerWithTimeInterval:5 repeats:YES block:^(NSTimer *t) { SCIWBTickNow(); }];
        sciWBTimer.tolerance = 1;
    }
}

void SCIWatchBudgetSetProvider(SCIWatchLimits (^provider)(void)) {
    sciWBProvider = [provider copy];
    dispatch_async(dispatch_get_main_queue(), ^{ SCIWBStart(); });
}

void SCIWatchBudgetNoteVideo(NSString *key) {
    if (!sciWBProvider || !key.length) return;
    SCIWatchLimits limits = sciWBProvider();
    if (limits.maxVideos <= 0 && limits.maxMinutes <= 0) return;   // the budget is off: count nothing, keep nothing
    SCIWBStart();
    SCIWBRoll();
    if ([key isEqualToString:sciWBLastKey]) return;
    sciWBLastKey = [key copy];
    sciWBTotals.videos += 1;
    SCIWBSave();
    SCIWBCheck();
}

NSString *SCIWatchBudgetReport(void) {
    return [NSString stringWithFormat:@"today %ld videos, %ld min; asked %lu, kept going %lu, remind later %lu; extra allowance %ld videos / %ld min",
            (long)sciWBTotals.videos, (long)(sciWBTotals.seconds / 60), (unsigned long)sciWBAsked, (unsigned long)sciWBKept, (unsigned long)sciWBLater,
            (long)sciWBTotals.extraVideos, (long)(sciWBTotals.extraSeconds / 60)];
}
