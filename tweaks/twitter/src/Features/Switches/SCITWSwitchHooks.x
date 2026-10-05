#import "SCITWSwitches.h"
#import "Prefs.h"
#import "SCILog.h"
#import <objc/runtime.h>

static NSMutableDictionary<NSString *, NSNumber *> *sciTypedAttached = nil;

///
/// The hooks themselves. Three classes, one question.
///
/// Each provider gets its own `%group`, initialised only when the class is really there.
/// A `%hook` on a class this build of X does not have is not an error and not a crash --
/// it is silence, and silence is the failure mode this project has spent the most time
/// paying for. With a group per provider the diagnostics page can say "two of three
/// attached", which is a sentence somebody can act on.
///
/// `-unsafePeekBoolForKey:` is hooked beside `-boolForKey:` because it is the same
/// question asked without waiting for the cache, and code that takes that route would
/// otherwise see X's answer where its neighbour sees the user's -- one screen obeying the
/// override and the one beside it not, which reads as the tweak being unreliable rather
/// than as a route that was missed.
///

%group Switches

%hook TFSFeatureSwitches

- (BOOL)boolForKey:(NSString *)key {
    BOOL answer = %orig;
    [SCITWSwitches interceptKey:key
                      appAnswer:answer
                       provider:@"TFSFeatureSwitches"
                         answer:&answer];
    return answer;
}

- (BOOL)unsafePeekBoolForKey:(NSString *)key {
    BOOL answer = %orig;
    [SCITWSwitches interceptKey:key
                      appAnswer:answer
                       provider:@"TFSFeatureSwitches"
                         answer:&answer];
    return answer;
}

%end

%end


%group CachingProvider

%hook TFSCachingFeatureSwitchProvider

- (BOOL)boolForKey:(NSString *)key {
    BOOL answer = %orig;
    [SCITWSwitches interceptKey:key
                      appAnswer:answer
                       provider:@"TFSCachingFeatureSwitchProvider"
                         answer:&answer];
    return answer;
}

%end

%end


%group TPSwitches

%hook TPSTwitterFeatureSwitches

- (BOOL)boolForKey:(NSString *)key {
    BOOL answer = %orig;
    [SCITWSwitches interceptKey:key
                      appAnswer:answer
                       provider:@"TPSTwitterFeatureSwitches"
                         answer:&answer];
    return answer;
}

%end

%end



///
/// The wrapper, and the typed getters.
///
/// **Two gaps in the first version, both visible in NeoFreeBird's hook list for X 12.31.**
/// `TFSInstrumentedFeatureSwitches` wraps a `TFSFeatureSwitches` and implements every typed
/// getter itself, so a question that reaches X through the wrapper never touches the
/// provider hooked above -- an override that works on one screen and not on its neighbour,
/// which is how a half-missing hook reads. And only `-boolForKey:` was hooked: a switch that
/// is a *number* (how long the app may sit in the background before the timeline refreshes,
/// how long a video must run before the player advances on its own) is read through
/// `-integerForKey:`, `-doubleForKey:` or `-numberForKey:`, none of which a yes-or-no
/// override can answer.
///
/// Every selector below was read out of the 12.20 class metadata with the encoding it is
/// hooked with (`q24@0:8@16`, `d24@0:8@16`, `@24@0:8@16`, `B24@0:8@16`) before it was
/// written, and a class only gets its group when it really answers all of them -- a `%hook`
/// on a method the class does not declare *adds* it, which is the one thing a hook on a
/// getter must never do.
///

%group InstrumentedBool

%hook TFSInstrumentedFeatureSwitches

- (BOOL)boolForKey:(NSString *)key {
    BOOL answer = %orig;
    [SCITWSwitches interceptKey:key
                      appAnswer:answer
                       provider:@"TFSInstrumentedFeatureSwitches"
                         answer:&answer];
    return answer;
}

- (BOOL)unsafePeekBoolForKey:(NSString *)key {
    BOOL answer = %orig;
    [SCITWSwitches interceptKey:key
                      appAnswer:answer
                       provider:@"TFSInstrumentedFeatureSwitches"
                         answer:&answer];
    return answer;
}

%end

%end


%group TypedFS

%hook TFSFeatureSwitches

- (NSInteger)integerForKey:(NSString *)key {
    NSInteger value = %orig;
    NSNumber *override = [SCITWSwitches numberOverrideForKey:key];
    if (override) value = override.integerValue;
    return value;
}

- (NSInteger)unsafePeekIntegerForKey:(NSString *)key {
    NSInteger value = %orig;
    NSNumber *override = [SCITWSwitches numberOverrideForKey:key];
    if (override) value = override.integerValue;
    return value;
}

- (double)doubleForKey:(NSString *)key {
    double value = %orig;
    NSNumber *override = [SCITWSwitches numberOverrideForKey:key];
    if (override) value = override.doubleValue;
    return value;
}

- (double)unsafePeekDoubleForKey:(NSString *)key {
    double value = %orig;
    NSNumber *override = [SCITWSwitches numberOverrideForKey:key];
    if (override) value = override.doubleValue;
    return value;
}

- (NSNumber *)numberForKey:(NSString *)key {
    NSNumber *value = %orig;
    NSNumber *override = [SCITWSwitches numberOverrideForKey:key];
    if (override) value = override;
    return value;
}

// Some readers (the default-captions setup is the one NeoFreeBird names) only consult the
// value when the switch reports a non-default one, so an override on such a key is invisible
// until this says there is one.
- (BOOL)hasNonDefaultValueForKey:(NSString *)key {
    BOOL value = %orig;
    if ([SCITWSwitches numberOverrideForKey:key]) value = YES;
    return value;
}

%end

%end


%group TypedInstrumented

%hook TFSInstrumentedFeatureSwitches

- (NSInteger)integerForKey:(NSString *)key {
    NSInteger value = %orig;
    NSNumber *override = [SCITWSwitches numberOverrideForKey:key];
    if (override) value = override.integerValue;
    return value;
}

- (NSInteger)unsafePeekIntegerForKey:(NSString *)key {
    NSInteger value = %orig;
    NSNumber *override = [SCITWSwitches numberOverrideForKey:key];
    if (override) value = override.integerValue;
    return value;
}

- (double)doubleForKey:(NSString *)key {
    double value = %orig;
    NSNumber *override = [SCITWSwitches numberOverrideForKey:key];
    if (override) value = override.doubleValue;
    return value;
}

- (double)unsafePeekDoubleForKey:(NSString *)key {
    double value = %orig;
    NSNumber *override = [SCITWSwitches numberOverrideForKey:key];
    if (override) value = override.doubleValue;
    return value;
}

- (NSNumber *)numberForKey:(NSString *)key {
    NSNumber *value = %orig;
    NSNumber *override = [SCITWSwitches numberOverrideForKey:key];
    if (override) value = override;
    return value;
}

- (BOOL)hasNonDefaultValueForKey:(NSString *)key {
    BOOL value = %orig;
    if ([SCITWSwitches numberOverrideForKey:key]) value = YES;
    return value;
}

%end

%end


%group TypedTPS

%hook TPSTwitterFeatureSwitches

- (NSInteger)integerForKey:(NSString *)key {
    NSInteger value = %orig;
    NSNumber *override = [SCITWSwitches numberOverrideForKey:key];
    if (override) value = override.integerValue;
    return value;
}

- (NSInteger)unsafePeekIntegerForKey:(NSString *)key {
    NSInteger value = %orig;
    NSNumber *override = [SCITWSwitches numberOverrideForKey:key];
    if (override) value = override.integerValue;
    return value;
}

- (double)doubleForKey:(NSString *)key {
    double value = %orig;
    NSNumber *override = [SCITWSwitches numberOverrideForKey:key];
    if (override) value = override.doubleValue;
    return value;
}

- (double)unsafePeekDoubleForKey:(NSString *)key {
    double value = %orig;
    NSNumber *override = [SCITWSwitches numberOverrideForKey:key];
    if (override) value = override.doubleValue;
    return value;
}

- (NSNumber *)numberForKey:(NSString *)key {
    NSNumber *value = %orig;
    NSNumber *override = [SCITWSwitches numberOverrideForKey:key];
    if (override) value = override;
    return value;
}

%end

%end


%group TypedCaching

%hook TFSCachingFeatureSwitchProvider

- (NSInteger)integerForKey:(NSString *)key {
    NSInteger value = %orig;
    NSNumber *override = [SCITWSwitches numberOverrideForKey:key];
    if (override) value = override.integerValue;
    return value;
}

- (NSInteger)unsafePeekIntegerForKey:(NSString *)key {
    NSInteger value = %orig;
    NSNumber *override = [SCITWSwitches numberOverrideForKey:key];
    if (override) value = override.integerValue;
    return value;
}

- (double)doubleForKey:(NSString *)key {
    double value = %orig;
    NSNumber *override = [SCITWSwitches numberOverrideForKey:key];
    if (override) value = override.doubleValue;
    return value;
}

- (double)unsafePeekDoubleForKey:(NSString *)key {
    double value = %orig;
    NSNumber *override = [SCITWSwitches numberOverrideForKey:key];
    if (override) value = override.doubleValue;
    return value;
}

- (NSNumber *)numberForKey:(NSString *)key {
    NSNumber *value = %orig;
    NSNumber *override = [SCITWSwitches numberOverrideForKey:key];
    if (override) value = override;
    return value;
}

%end

%end


/// Whether `name` answers every selector in `selectors` with exactly that type encoding.
/// The gate for a group: all or nothing, because half a set of typed getters is a provider
/// whose integers obey the override and whose doubles do not.
static BOOL SCITWAnswersAll(NSString *name, NSArray<NSArray<NSString *> *> *selectors) {
    Class cls = NSClassFromString(name);
    if (!cls) return NO;

    for (NSArray<NSString *> *pair in selectors) {
        Method method = class_getInstanceMethod(cls, NSSelectorFromString(pair[0]));
        if (!method) return NO;

        const char *encoding = method_getTypeEncoding(method);
        if (!encoding || strcmp(encoding, pair[1].UTF8String) != 0) return NO;
    }
    return YES;
}

/// Attaches what is there and records what was not.
///
/// Called from the constructor rather than being a `%ctor` of its own, so the order is
/// visible in one file: the panel switch is consulted first, and nothing here runs when
/// this tweak has been turned off for X.
///
/// Written out three times rather than driven from a table, because `%init` is a macro
/// that expands to registration calls for one named group -- it cannot be reached through
/// a function pointer, and a loop over the three would have to be a loop over something
/// else entirely. Three near-identical paragraphs that compile beat one clever one that
/// does not.
///
void SCITWInstallSwitchHooks(void) {
    if (!sciTypedAttached) sciTypedAttached = [NSMutableDictionary dictionary];

    // The classes live in T1Twitter.framework and the two SPM migration frameworks, not
    // in the main binary -- so anything that looks for them by scanning the executable
    // finds nothing and concludes, wrongly, that this build of X has no switch layer.
    // Asking the runtime by name asks every image that is loaded, which is the point.
    if (NSClassFromString(@"TFSFeatureSwitches")) {
        %init(Switches);
        [SCITWSwitches noteProvider:@"TFSFeatureSwitches"];
    } else {
        SCILogV(@"TFSFeatureSwitches is not in this build");
    }

    if (NSClassFromString(@"TFSCachingFeatureSwitchProvider")) {
        %init(CachingProvider);
        [SCITWSwitches noteProvider:@"TFSCachingFeatureSwitchProvider"];
    } else {
        SCILogV(@"TFSCachingFeatureSwitchProvider is not in this build");
    }

    if (NSClassFromString(@"TPSTwitterFeatureSwitches")) {
        %init(TPSwitches);
        [SCITWSwitches noteProvider:@"TPSTwitterFeatureSwitches"];
    } else {
        SCILogV(@"TPSTwitterFeatureSwitches is not in this build");
    }

    // The wrapper's own bool answers, and the typed getters of all four classes. Each group
    // is attached only when its class answers every selector it hooks with the encoding it
    // hooks it with, and what happened is counted either way (see the report).
    NSArray *boolPair = @[@[@"boolForKey:", @"B24@0:8@16"],
                          @[@"unsafePeekBoolForKey:", @"B24@0:8@16"]];

    NSArray *typed = @[@[@"integerForKey:", @"q24@0:8@16"],
                       @[@"unsafePeekIntegerForKey:", @"q24@0:8@16"],
                       @[@"doubleForKey:", @"d24@0:8@16"],
                       @[@"unsafePeekDoubleForKey:", @"d24@0:8@16"],
                       @[@"numberForKey:", @"@24@0:8@16"]];
    NSArray *typedPlusNonDefault = [typed arrayByAddingObject:@[@"hasNonDefaultValueForKey:", @"B24@0:8@16"]];

    if (SCITWAnswersAll(@"TFSInstrumentedFeatureSwitches", boolPair)) {
        %init(InstrumentedBool);
        [SCITWSwitches noteProvider:@"TFSInstrumentedFeatureSwitches"];
        sciTypedAttached[@"instrumented bool"] = @YES;
    } else {
        sciTypedAttached[@"instrumented bool"] = @NO;
    }

    if (SCITWAnswersAll(@"TFSFeatureSwitches", typedPlusNonDefault)) {
        %init(TypedFS);
        sciTypedAttached[@"typed TFSFeatureSwitches"] = @YES;
    } else {
        sciTypedAttached[@"typed TFSFeatureSwitches"] = @NO;
    }

    if (SCITWAnswersAll(@"TFSInstrumentedFeatureSwitches", typedPlusNonDefault)) {
        %init(TypedInstrumented);
        sciTypedAttached[@"typed TFSInstrumentedFeatureSwitches"] = @YES;
    } else {
        sciTypedAttached[@"typed TFSInstrumentedFeatureSwitches"] = @NO;
    }

    if (SCITWAnswersAll(@"TPSTwitterFeatureSwitches", typed)) {
        %init(TypedTPS);
        sciTypedAttached[@"typed TPSTwitterFeatureSwitches"] = @YES;
    } else {
        sciTypedAttached[@"typed TPSTwitterFeatureSwitches"] = @NO;
    }

    if (SCITWAnswersAll(@"TFSCachingFeatureSwitchProvider", typed)) {
        %init(TypedCaching);
        sciTypedAttached[@"typed TFSCachingFeatureSwitchProvider"] = @YES;
    } else {
        sciTypedAttached[@"typed TFSCachingFeatureSwitchProvider"] = @NO;
    }
}

NSString *SCITWSwitchHooksReport(void) {
    if (!sciTypedAttached.count) return @"switch layer extras: not installed";

    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSString *name in [sciTypedAttached.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        [parts addObject:[NSString stringWithFormat:@"%@ %@", name,
                          sciTypedAttached[name].boolValue ? @"attached" : @"not attached (class or encoding differs)"]];
    }
    return [@"switch layer extras: " stringByAppendingString:[parts componentsJoinedByString:@" · "]];
}
