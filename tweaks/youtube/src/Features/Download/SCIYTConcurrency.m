//
//  SCIYTConcurrency.m
//  Albrhi for YouTube
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCIYTConcurrency.h"
#import "../../Prefs.h"

static const int kSCIConcDefault = 4;
static const double kSCIConcAlpha = 0.5;          // weight of the newest measurement
static const double kSCIConcMargin = 1.08;        // a step must beat the one below by 8% to count
static const int kSCIConcQuietToRelax = 4;        // runs without a refusal before the ceiling lifts one

void SCIConcInit(SCIConcState *state, int start) {
    memset(state, 0, sizeof(*state));
    state->n = MIN(MAX(start, SCI_CONC_MIN), SCI_CONC_MAX);
    state->ceiling = SCI_CONC_MAX;
}

void SCIConcRecordRun(SCIConcState *state, int n, double bytesPerSecond) {
    if (n < SCI_CONC_MIN || n > SCI_CONC_MAX || !isfinite(bytesPerSecond) || bytesPerSecond <= 0) return;

    double previous = state->rate[n];
    state->rate[n] = previous > 0 ? previous * (1 - kSCIConcAlpha) + bytesPerSecond * kSCIConcAlpha : bytesPerSecond;

    state->quiet += 1;
    if (state->quiet >= kSCIConcQuietToRelax && state->ceiling < SCI_CONC_MAX) { state->ceiling += 1; state->quiet = 0; }

    // Judge the count that was used against the one below it.
    double here = state->rate[n];
    double below = n > SCI_CONC_MIN ? state->rate[n - 1] : 0;
    double above = n < SCI_CONC_MAX ? state->rate[n + 1] : 0;

    if (below > 0 && here < below * kSCIConcMargin) {
        // More did not pay by a clear margin (equal counts as not paying: fewer connections is the
        // kinder choice): step back.
        state->n = n - 1;
    } else if (above > 0 && above > here * kSCIConcMargin) {
        // The count above was measurably better the last time it was tried.
        state->n = MIN(n + 1, state->ceiling);
    } else if (n < state->ceiling && (below == 0 || here >= below * kSCIConcMargin) && above == 0) {
        // Never tried higher and the climb so far has paid: try one more.
        state->n = n + 1;
    } else {
        state->n = MIN(n, state->ceiling);
    }
    state->n = MIN(MAX(state->n, SCI_CONC_MIN), SCI_CONC_MAX);
}

void SCIConcRecordThrottle(SCIConcState *state) {
    int hit = state->n;
    state->ceiling = MAX(SCI_CONC_MIN, hit - 1);
    state->n = MAX(SCI_CONC_MIN, hit / 2);
    state->quiet = 0;
    // What was measured at the counts that were refused is no longer a reason to go there.
    for (int i = state->ceiling + 1; i <= SCI_CONC_MAX; i++) state->rate[i] = 0;
}

NSDictionary *SCIConcDictionary(const SCIConcState *state) {
    NSMutableArray *rates = [NSMutableArray array];
    for (int i = 0; i <= SCI_CONC_MAX; i++) [rates addObject:@(state->rate[i])];
    return @{@"n": @(state->n), @"ceiling": @(state->ceiling), @"quiet": @(state->quiet), @"rate": rates};
}

void SCIConcLoad(SCIConcState *state, NSDictionary *dictionary, int fallbackStart) {
    SCIConcInit(state, fallbackStart);
    if (![dictionary isKindOfClass:[NSDictionary class]]) return;
    NSNumber *n = dictionary[@"n"], *ceiling = dictionary[@"ceiling"], *quiet = dictionary[@"quiet"];
    NSArray *rates = dictionary[@"rate"];
    if ([n isKindOfClass:[NSNumber class]]) state->n = MIN(MAX(n.intValue, SCI_CONC_MIN), SCI_CONC_MAX);
    if ([ceiling isKindOfClass:[NSNumber class]]) state->ceiling = MIN(MAX(ceiling.intValue, SCI_CONC_MIN), SCI_CONC_MAX);
    if ([quiet isKindOfClass:[NSNumber class]]) state->quiet = MAX(quiet.intValue, 0);
    if ([rates isKindOfClass:[NSArray class]]) {
        for (NSUInteger i = 0; i < rates.count && i <= SCI_CONC_MAX; i++) {
            NSNumber *r = rates[i];
            if ([r isKindOfClass:[NSNumber class]] && isfinite(r.doubleValue) && r.doubleValue >= 0) state->rate[i] = r.doubleValue;
        }
    }
    if (state->n > state->ceiling) state->n = state->ceiling;
}

static NSString *const kSCIConcKey = @"albrhi_yt_parallel_state";

@implementation SCIYTConcurrency

+ (NSUInteger)parallelism {
    NSInteger chosen = SCIPrefNumber(SCIPrefParallel);
    if (chosen >= 1 && chosen <= SCI_CONC_MAX) return (NSUInteger)chosen;      // the person's own choice stands
    SCIConcState state;
    SCIConcLoad(&state, [[NSUserDefaults standardUserDefaults] dictionaryForKey:kSCIConcKey], kSCIConcDefault);
    return (NSUInteger)state.n;
}

+ (void)recordRunBytes:(long long)bytes seconds:(double)seconds used:(NSUInteger)used {
    // Short runs say little: the first seconds are connection setup, and a few parts never filled the
    // pipe. 24 MB (three parts) and 4 seconds is the least that is a measurement.
    if (bytes < 24 * 1024 * 1024 || seconds < 4) return;
    SCIConcState state;
    SCIConcLoad(&state, [[NSUserDefaults standardUserDefaults] dictionaryForKey:kSCIConcKey], kSCIConcDefault);
    SCIConcRecordRun(&state, (int)used, (double)bytes / seconds);
    [[NSUserDefaults standardUserDefaults] setObject:SCIConcDictionary(&state) forKey:kSCIConcKey];
}

+ (void)recordThrottle {
    SCIConcState state;
    SCIConcLoad(&state, [[NSUserDefaults standardUserDefaults] dictionaryForKey:kSCIConcKey], kSCIConcDefault);
    SCIConcRecordThrottle(&state);
    [[NSUserDefaults standardUserDefaults] setObject:SCIConcDictionary(&state) forKey:kSCIConcKey];
}

@end
