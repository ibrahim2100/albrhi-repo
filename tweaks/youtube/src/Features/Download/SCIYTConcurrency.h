//
//  SCIYTConcurrency.h
//  Albrhi for YouTube
//
//  How many parts to fetch at once, learned from how fast the last downloads really went rather than
//  guessed. A fixed number is a guess the person cannot make: too high and the server answers 429, too
//  low and the link sits half idle, and the right answer differs by network and by hour. This is the
//  congestion-control shape CDNs use -- climb slowly while it keeps paying, fall fast on a refusal.
//  (The idea is OmniGet's `adaptive_concurrency.rs`, GPL-3.0; this is a rewrite for what iOS allows.)
//
//  **Why it is learned across runs and not inside one.** A background session fixes its connection
//  count when it is made, and queueing every part up front is what lets a download carry on while
//  the app is closed -- feeding parts one at a time would give that up. So each finished run reports
//  how fast it went at the count it used, and the next session starts at the better count.
//
//  Pure (a struct and functions), so a host test drives it against a simulated link.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#define SCI_CONC_MIN 1
#define SCI_CONC_MAX 8

typedef struct {
    int n;                       ///< the count the next session should use
    int ceiling;                 ///< never above this until throttling has stopped for a while
    int quiet;                   ///< runs since the last refusal
    double rate[SCI_CONC_MAX + 1];   ///< smoothed bytes per second seen at each count (0 = never tried)
} SCIConcState;

void SCIConcInit(SCIConcState *state, int start);

/// A run finished: `n` parts were allowed at once and the run moved `bytesPerSecond` overall.
/// Moves `state->n` one step toward better, or back one step if the last climb did not pay.
void SCIConcRecordRun(SCIConcState *state, int n, double bytesPerSecond);

/// The server refused (429/503): halve the count and keep it below where it happened for a while.
void SCIConcRecordThrottle(SCIConcState *state);

/// Plain-dictionary form, for the preferences.
NSDictionary *SCIConcDictionary(const SCIConcState *state);
void SCIConcLoad(SCIConcState *state, NSDictionary * _Nullable dictionary, int fallbackStart);

NS_ASSUME_NONNULL_END

@interface SCIYTConcurrency : NSObject
/// The count the next background session should be made with: the person's fixed choice in Settings
/// when there is one, else what past runs learned (four before any).
+ (NSUInteger)parallelism;
/// A finished run's measurement and a refusal, kept for next time.
+ (void)recordRunBytes:(long long)bytes seconds:(double)seconds used:(NSUInteger)used;
+ (void)recordThrottle;
@end
