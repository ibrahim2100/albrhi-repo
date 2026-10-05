#import "SCITWSwitches.h"
#import "Prefs.h"
#import "SCILog.h"
#import <pthread.h>

@implementation SCITWSwitchRecord
@end


///
/// State, and the lock that guards it.
///
/// A mutex rather than a serial queue: `-boolForKey:` is answered synchronously and the
/// caller is waiting, so dispatching to a queue and waiting for it would add a context
/// switch to a path that runs thousands of times a scroll. The critical section here is a
/// dictionary lookup and an integer add.
///
static pthread_mutex_t _lock = PTHREAD_MUTEX_INITIALIZER;
static NSMutableDictionary<NSString *, SCITWSwitchRecord *> *_records = nil;
static NSMutableDictionary<NSString *, NSNumber *> *_overrides = nil;
static NSDictionary<NSString *, NSNumber *> *_featureOverrides = nil;
static NSMutableArray<NSString *> *_providers = nil;
static NSUInteger _totalAsked = 0;

/// A ceiling on how many distinct keys are remembered.
///
/// X asks about a few hundred in normal use, but the count is not something this code
/// controls, and an unbounded dictionary filled from another program's strings is a leak
/// with extra steps. Past the ceiling the counters on keys already known keep rising --
/// which is the number that matters -- and new keys are dropped.
static const NSUInteger SCITWMaxKeys = 4000;

@implementation SCITWSwitches

+ (void)load {
    _records = [NSMutableDictionary dictionary];
    _providers = [NSMutableArray array];

    _featureOverrides = @{};
    _overrides = [NSMutableDictionary dictionary];
    NSDictionary *saved = [[NSUserDefaults standardUserDefaults] dictionaryForKey:SCIPrefOverrides];

    // Read defensively rather than trusted. This dictionary is on disk where anything can
    // edit it, and a stray value would otherwise become a message sent to the wrong type
    // deep inside the hot path, where the crash report points at X rather than at us.
    for (NSString *key in saved) {
        if (![key isKindOfClass:[NSString class]]) continue;
        if (![saved[key] isKindOfClass:[NSNumber class]]) continue;
        _overrides[key] = saved[key];
    }
}

+ (BOOL)interceptKey:(NSString *)key
           appAnswer:(BOOL)appAnswer
            provider:(NSString *)provider
              answer:(BOOL *)answer {
    if (![key isKindOfClass:[NSString class]] || !key.length) return NO;

    BOOL decided = NO;

    pthread_mutex_lock(&_lock);

    _totalAsked++;

    SCITWSwitchRecord *record = _records[key];
    if (!record && _records.count < SCITWMaxKeys) {
        record = [[SCITWSwitchRecord alloc] init];
        record.key = key;
        record.provider = provider;
        _records[key] = record;
    }
    record.asked++;
    record.appAnswer = appAnswer;

    // Hand-set first, then whatever the named features contribute. The order is the whole
    // rule: the more specific instruction wins, and it is expressed here once rather than
    // being reasoned about at each call site.
    NSNumber *override = _overrides[key] ?: _featureOverrides[key];
    if (override) {
        decided = YES;
        if (answer) *answer = override.boolValue;
    }

    pthread_mutex_unlock(&_lock);

    return decided;
}

+ (NSNumber *)numberOverrideForKey:(NSString *)key {
    if (![key isKindOfClass:[NSString class]] || !key.length) return nil;

    pthread_mutex_lock(&_lock);
    NSNumber *override = _overrides[key] ?: _featureOverrides[key];
    pthread_mutex_unlock(&_lock);
    return override;
}

+ (NSArray<SCITWSwitchRecord *> *)records {
    pthread_mutex_lock(&_lock);
    NSArray *snapshot = [_records allValues];
    pthread_mutex_unlock(&_lock);

    // Most asked first, and by name within a tie. The order is the point: a list of four
    // hundred keys in the order a dictionary happened to hash them is not a list anyone
    // can read, and what someone is looking for is nearly always near the top.
    return [snapshot sortedArrayUsingComparator:^NSComparisonResult(SCITWSwitchRecord *a,
                                                                   SCITWSwitchRecord *b) {
        if (a.asked != b.asked) return a.asked > b.asked ? NSOrderedAscending : NSOrderedDescending;
        return [a.key compare:b.key];
    }];
}

+ (NSUInteger)totalAsked {
    pthread_mutex_lock(&_lock);
    NSUInteger total = _totalAsked;
    pthread_mutex_unlock(&_lock);
    return total;
}

+ (SCITWOverride)overrideForKey:(NSString *)key {
    pthread_mutex_lock(&_lock);
    NSNumber *value = _overrides[key];
    pthread_mutex_unlock(&_lock);

    if (!value) return SCITWOverrideNone;
    return value.boolValue ? SCITWOverrideOn : SCITWOverrideOff;
}

+ (void)setOverride:(SCITWOverride)override forKey:(NSString *)key {
    if (!key.length) return;

    pthread_mutex_lock(&_lock);
    if (override == SCITWOverrideNone) {
        [_overrides removeObjectForKey:key];
    } else {
        _overrides[key] = @(override == SCITWOverrideOn);
    }
    NSDictionary *snapshot = [_overrides copy];
    pthread_mutex_unlock(&_lock);

    // Written outside the lock. NSUserDefaults takes locks of its own and can reach the
    // filesystem, and holding ours across that would stall every `-boolForKey:` X makes
    // while a write settles -- which is the whole app, for as long as the disk takes.
    [[NSUserDefaults standardUserDefaults] setObject:snapshot forKey:SCIPrefOverrides];

    SCILogV(@"override %@ = %ld", key, (long)override);
}

+ (NSDictionary<NSString *, NSNumber *> *)allOverrides {
    pthread_mutex_lock(&_lock);
    NSDictionary *snapshot = [_overrides copy];
    pthread_mutex_unlock(&_lock);
    return snapshot;
}

+ (void)clearOverrides {
    pthread_mutex_lock(&_lock);
    [_overrides removeAllObjects];
    pthread_mutex_unlock(&_lock);

    [[NSUserDefaults standardUserDefaults] removeObjectForKey:SCIPrefOverrides];
}

+ (void)setFeatureOverrides:(NSDictionary<NSString *, NSNumber *> *)overrides {
    NSDictionary *snapshot = [overrides copy] ?: @{};

    pthread_mutex_lock(&_lock);
    _featureOverrides = snapshot;
    pthread_mutex_unlock(&_lock);
}

+ (NSDictionary<NSString *, NSNumber *> *)featureOverrides {
    pthread_mutex_lock(&_lock);
    NSDictionary *snapshot = _featureOverrides ?: @{};
    pthread_mutex_unlock(&_lock);
    return snapshot;
}

+ (void)noteProvider:(NSString *)name {
    if (!name.length) return;

    pthread_mutex_lock(&_lock);
    if (![_providers containsObject:name]) [_providers addObject:name];
    pthread_mutex_unlock(&_lock);
}

+ (NSArray<NSString *> *)attachedProviders {
    pthread_mutex_lock(&_lock);
    NSArray *snapshot = [_providers copy];
    pthread_mutex_unlock(&_lock);
    return snapshot;
}

@end
