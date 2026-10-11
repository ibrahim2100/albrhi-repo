#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#import "SCIYTPoProbe.h"
#import "../../SCILog.h"
#import "../../SCIYTLaunchGuard.h"

static NSMutableDictionary<NSString *, NSNumber *> *sCounts = nil;
static NSMutableArray<NSString *> *sNotes = nil;      // distinct, bounded
static NSMutableArray<NSString *> *sHooks = nil;      // what attached and what did not
static NSMutableDictionary<NSString *, NSString *> *sFlags = nil;   // flag -> last answer

static const NSUInteger kMaxNotes = 24;
static const NSUInteger kMaxNoteLength = 220;

static void SCIPoCount(NSString *key) {
    @synchronized (sCounts) { sCounts[key] = @(sCounts[key].unsignedIntegerValue + 1); }
}

/// A line worth keeping once: the same line repeated for every video is a count, not a note.
static void SCIPoNote(NSString *line) {
    if (line.length > kMaxNoteLength) line = [line substringToIndex:kMaxNoteLength];
    @synchronized (sNotes) {
        if ([sNotes containsObject:line] || sNotes.count >= kMaxNotes) return;
        [sNotes addObject:line];
    }
}

/// What kind of thing this is and how big -- never its content. A proof-of-origin token is an
/// account-adjacent credential, so this records "NSData, 142 bytes" and nothing else.
static NSString *SCIPoShape(id object) {
    if (!object) return @"nil";
    NSString *name = NSStringFromClass([object class]);
    if ([object isKindOfClass:[NSData class]]) return [NSString stringWithFormat:@"%@ %lu bytes", name, (unsigned long)[(NSData *)object length]];
    if ([object isKindOfClass:[NSString class]]) return [NSString stringWithFormat:@"%@ %lu chars", name, (unsigned long)[(NSString *)object length]];
    return name;
}

static NSString *SCIPoError(id error) {
    if (![error isKindOfClass:[NSError class]]) return error ? SCIPoShape(error) : @"none";
    NSError *e = error;
    NSString *line = [NSString stringWithFormat:@"%@ %ld \"%@\"", e.domain, (long)e.code, e.localizedDescription ?: @""];
    NSError *underlying = e.userInfo[NSUnderlyingErrorKey];
    if ([underlying isKindOfClass:[NSError class]]) {
        line = [line stringByAppendingFormat:@" ← %@ %ld", underlying.domain, (long)underlying.code];
    }
    return line;
}

static BOOL SCIPoHook(NSString *className, NSString *selectorName, const char *encoding,
                      IMP replacement, IMP *original, BOOL classMethod) {
    NSString *label = [NSString stringWithFormat:@"%@%@ %@", classMethod ? @"+" : @"-", className, selectorName];
    Class cls = objc_getClass(className.UTF8String);
    if (!cls) { [sHooks addObject:[label stringByAppendingString:@" — class not in this build"]]; return NO; }

    SEL selector = NSSelectorFromString(selectorName);
    Method method = classMethod ? class_getClassMethod(cls, selector) : class_getInstanceMethod(cls, selector);
    if (!method) { [sHooks addObject:[label stringByAppendingString:@" — method not on this build"]]; return NO; }

    const char *actual = method_getTypeEncoding(method);
    if (!actual || strcmp(actual, encoding) != 0) {
        [sHooks addObject:[NSString stringWithFormat:@"%@ — encoding %s, expected %s", label, actual ?: "?", encoding]];
        return NO;
    }

    MSHookMessageEx(classMethod ? object_getClass(cls) : cls, selector, replacement, original);
    [sHooks addObject:[label stringByAppendingString:@" — attached"]];
    return YES;
}

static IMP sMintImmediate = NULL, sMintManager = NULL, sStreamStatus = NULL, sPoMinted = NULL;
static IMP sHandleChallenge = NULL, sEndState = NULL;
static IMP sFlagMedia = NULL, sFlagInjection = NULL, sFlagCabr = NULL, sFlagOutside = NULL;

static void SCIPoInstall(void) {
    static BOOL once = NO;
    if (once) return;
    once = YES;

    // IGDManager -mintPOTokenImmediately: -- the iOS guard asked for a token on the spot.
    SCIPoHook(@"IGDManager", @"mintPOTokenImmediately:", "@24@0:8@16", imp_implementationWithBlock(^id(id me, id binding) {
        id result = sMintImmediate ? ((id (*)(id, SEL, id))sMintImmediate)(me, @selector(mintPOTokenImmediately:), binding) : nil;
        SCIPoCount(result ? @"iosguard mint: token" : @"iosguard mint: NIL");
        SCIPoNote([NSString stringWithFormat:@"iosguard mintPOTokenImmediately(%@) → %@", SCIPoShape(binding), SCIPoShape(result)]);
        return result;
    }), &sMintImmediate, NO);

    // The manager the player asks.
    SCIPoHook(@"YTProofOfOriginTokenManager", @"mintWithVideoID:", "@24@0:8@16", imp_implementationWithBlock(^id(id me, id videoID) {
        id result = sMintManager ? ((id (*)(id, SEL, id))sMintManager)(me, @selector(mintWithVideoID:), videoID) : nil;
        SCIPoCount(result ? @"manager mint: token" : @"manager mint: NIL");
        SCIPoNote([NSString stringWithFormat:@"manager mintWithVideoID → %@", SCIPoShape(result)]);
        return result;
    }), &sMintManager, NO);

    // The media layer: the server told the stream's protection status changed.
    //
    // The argument is a pointer to a C++ message, whose layout is not read out of anything here.
    // Its first 32 bytes are recorded as eight 32-bit words -- a hint that costs nothing and can be
    // compared between a working and a failing run -- and no field is interpreted.
    SCIPoHook(@"MLABRPolicy", @"onStreamProtectionStatus:", "v24@0:8r^v16", imp_implementationWithBlock(^(id me, const void *status) {
        SCIPoCount(@"media layer: stream protection status heard");

        NSMutableString *words = [NSMutableString string];
        if (status) {
            const int32_t *w = (const int32_t *)status;
            for (int i = 0; i < 8; i++) [words appendFormat:@"%d%@", w[i], i < 7 ? @"," : @""];
        }

        NSString *token = @"?";
        Ivar tokenIvar = class_getInstanceVariable([me class], "_proofOfOriginToken");
        if (tokenIvar) token = SCIPoShape(object_getIvar(me, tokenIvar));
        NSString *minting = @"?";
        Ivar mintingIvar = class_getInstanceVariable([me class], "_isMintingPoToken");
        if (mintingIvar) minting = *(BOOL *)((uint8_t *)(__bridge void *)me + ivar_getOffset(mintingIvar)) ? @"yes" : @"no";

        SCIPoNote([NSString stringWithFormat:@"stream protection status heard — policy token %@ · minting %@ · words %@", token, minting, words]);
        if (sStreamStatus) ((void (*)(id, SEL, const void *))sStreamStatus)(me, @selector(onStreamProtectionStatus:), status);
    }), &sStreamStatus, NO);

    SCIPoHook(@"MLABRPolicy", @"onPoTokenMinted:", "v24@0:8@16", imp_implementationWithBlock(^(id me, id token) {
        SCIPoCount(token ? @"media layer: po token delivered" : @"media layer: po token delivered NIL");
        SCIPoNote([NSString stringWithFormat:@"onPoTokenMinted → %@", SCIPoShape(token)]);
        if (sPoMinted) ((void (*)(id, SEL, id))sPoMinted)(me, @selector(onPoTokenMinted:), token);
    }), &sPoMinted, NO);

    // The attestation challenge: the error here is the closest thing to "why".
    SCIPoHook(@"YTIOSGuardSnapshotControllerImpl", @"handleAttestationChallengeResponse:error:videoID:identityID:completionHandler:",
              "v56@0:8@16@24@32@40@?48", imp_implementationWithBlock(^(id me, id response, id error, id videoID, id identity, id completion) {
        SCIPoCount(error ? @"iosguard challenge: ERROR" : @"iosguard challenge: response");
        SCIPoNote([NSString stringWithFormat:@"iosguard challenge response %@ · error %@", SCIPoShape(response), SCIPoError(error)]);
        if (sHandleChallenge) ((void (*)(id, SEL, id, id, id, id, id))sHandleChallenge)(me, NSSelectorFromString(@"handleAttestationChallengeResponse:error:videoID:identityID:completionHandler:"), response, error, videoID, identity, completion);
    }), &sHandleChallenge, NO);

    SCIPoHook(@"YTAttestationChallengeProvider", @"logExecutionEndState:", "v20@0:8i16", imp_implementationWithBlock(^(id me, int state) {
        SCIPoCount([NSString stringWithFormat:@"attestation end state %d", state]);
        if (sEndState) ((void (*)(id, SEL, int))sEndState)(me, @selector(logExecutionEndState:), state);
    }), &sEndState, NO);

    // The app's own switches for the whole path, as it reads them. Recorded as answered, never
    // changed here: whether a flag is worth overriding is a decision for after this is read.
    struct { NSString *selector; IMP *original; } flags[] = {
        { @"enablePoTokenManagerMedia", &sFlagMedia },
        { @"enablePoTokenManagerInjection", &sFlagInjection },
        { @"iosSpsEnablePoTokenCabr", &sFlagCabr },
        { @"enablePoTokenGetPlayerOutsideOfPlayerlib", &sFlagOutside },
    };
    for (size_t i = 0; i < sizeof(flags) / sizeof(flags[0]); i++) {
        NSString *name = flags[i].selector;
        IMP *slot = flags[i].original;
        SCIPoHook(@"YTHotConfigIosPlayerClientSharedConfigImpl", name, "B16@0:8", imp_implementationWithBlock(^BOOL(id me) {
            BOOL value = *slot ? ((BOOL (*)(id, SEL))*slot)(me, NSSelectorFromString(name)) : NO;
            @synchronized (sFlags) { sFlags[name] = value ? @"YES" : @"NO"; }
            return value;
        }), slot, NO);
    }
}

NSString *SCIYTPoProbeReport(void) {
    NSMutableString *out = [NSMutableString stringWithString:@"po-token probe (read-only; lengths and counts, never a token):\n"];

    @synchronized (sCounts) {
        if (!sCounts.count) [out appendString:@"  nothing seen yet — play a video that fails, then read this again\n"];
        for (NSString *key in [sCounts.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            [out appendFormat:@"  %@ ×%@\n", key, sCounts[key]];
        }
    }
    @synchronized (sFlags) {
        for (NSString *key in [sFlags.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            [out appendFormat:@"  app flag %@ = %@\n", key, sFlags[key]];
        }
    }
    @synchronized (sNotes) {
        for (NSString *note in sNotes) [out appendFormat:@"  · %@\n", note];
    }
    for (NSString *hook in sHooks) [out appendFormat:@"  hook %@\n", hook];
    return out;
}

__attribute__((constructor)) static void SCIPoProbeRegister(void) {
    sCounts = [NSMutableDictionary dictionary];
    sNotes = [NSMutableArray array];
    sHooks = [NSMutableArray array];
    sFlags = [NSMutableDictionary dictionary];
    SCIYTWhenActive(^{ SCIPoInstall(); });
}
