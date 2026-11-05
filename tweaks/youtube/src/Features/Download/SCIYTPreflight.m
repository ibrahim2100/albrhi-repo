//
//  SCIYTPreflight.m
//  Albrhi for YouTube
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCIYTPreflight.h"

static const double kSCIAudioRate = 0.0162 * 1e6;   // bytes per second

/// Bytes per second of video, by height. Between two rungs the lower one is used.
static double SCIVideoRate(NSInteger height) {
    // The upper part of what was measured, not the median: a verdict that errs low fills the phone.
    if (height <= 0 || height >= 1080) return 0.50 * 1e6;
    if (height >= 720) return 0.20 * 1e6;
    if (height >= 480) return 0.09 * 1e6;
    if (height >= 360) return 0.05 * 1e6;
    if (height >= 240) return 0.025 * 1e6;
    return 0.012 * 1e6;
}

@implementation SCIYTPreflight

+ (long long)estimatedBytesForSeconds:(double)seconds height:(NSInteger)height soundOnly:(BOOL)soundOnly {
    if (!isfinite(seconds) || seconds <= 0) return 0;
    double rate = soundOnly ? kSCIAudioRate : SCIVideoRate(height) + kSCIAudioRate;
    return (long long)(seconds * rate);
}

+ (long long)estimatedBytesForVideoIDs:(NSArray<NSString *> *)ids
                             durations:(NSDictionary<NSString *, NSNumber *> *)durations
                                height:(NSInteger)height
                             soundOnly:(BOOL)soundOnly {
    NSMutableArray<NSNumber *> *known = [NSMutableArray array];
    for (NSString *video in ids) {
        NSNumber *seconds = durations[video];
        if (seconds.doubleValue > 0) [known addObject:seconds];
    }
    [known sortUsingSelector:@selector(compare:)];
    double unknown = known.count ? known[known.count / 2].doubleValue : 600;

    long long total = 0;
    for (NSString *video in ids) {
        double seconds = durations[video].doubleValue;
        total += [self estimatedBytesForSeconds:seconds > 0 ? seconds : unknown height:height soundOnly:soundOnly];
    }
    return total;
}

+ (SCIYTPreflightVerdict)verdictForBytes:(long long)bytes free:(long long)free {
    if (free < 0 || bytes <= 0) return SCIYTPreflightFits;       // cannot tell: do not nag
    double needed = (double)bytes * 1.3 + 512.0 * 1024 * 1024;
    if (needed > (double)free) return SCIYTPreflightTooBig;
    if (needed > (double)free * 0.6) return SCIYTPreflightTight;
    return SCIYTPreflightFits;
}

+ (long long)freeBytes {
    NSURL *home = [NSURL fileURLWithPath:NSHomeDirectory()];
    NSDictionary *values = [home resourceValuesForKeys:@[NSURLVolumeAvailableCapacityForImportantUsageKey] error:nil];
    NSNumber *free = values[NSURLVolumeAvailableCapacityForImportantUsageKey];
    return free ? free.longLongValue : -1;
}

@end
