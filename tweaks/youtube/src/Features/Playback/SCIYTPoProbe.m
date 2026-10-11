#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <VideoToolbox/VideoToolbox.h>
#import <sys/sysctl.h>
#import <UIKit/UIKit.h>
#import "SCIYTPoProbe.h"
#import "../../SCILog.h"
#import "../../SCIYTLaunchGuard.h"
#import "shared/src/SCIKVC.h"
#import "SCIYTCodecFilter.h"

static NSMutableDictionary<NSString *, NSNumber *> *sCounts = nil;
static NSMutableArray<NSString *> *sNotes = nil;      // distinct, bounded
static NSMutableArray<NSString *> *sHooks = nil;      // what attached and what did not
static NSMutableDictionary<NSString *, NSString *> *sFlags = nil;   // flag -> last answer

static const NSUInteger kMaxNotes = 24;
static const NSUInteger kMaxNoteLength = 700;

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

/// An error as a person debugging would want it, bounded: every userInfo key with a short value
/// (strings and numbers in full up to 60 characters, anything else as its class), and the
/// underlying errors down three levels. Never a token or a URL query -- values are cut, and
/// URLs are reduced to host and path.
static NSString *SCIPoValueLimit(id value, NSUInteger limit) {
    if ([value isKindOfClass:[NSString class]]) {
        NSString *s = value;
        return s.length > limit ? [[s substringToIndex:limit] stringByAppendingString:@"…"] : s;
    }
    if ([value isKindOfClass:[NSNumber class]]) return [value description];
    if ([value isKindOfClass:[NSURL class]]) return [NSString stringWithFormat:@"%@%@", [(NSURL *)value host] ?: @"", [(NSURL *)value path] ?: @""];
    if ([value isKindOfClass:[NSError class]]) return [NSString stringWithFormat:@"%@ %ld", [(NSError *)value domain], (long)[(NSError *)value code]];
    return value ? NSStringFromClass([value class]) : @"nil";
}

static NSString *SCIPoValue(id value) { return SCIPoValueLimit(value, 60); }

static NSString *SCIPoErrorFull(id error, int depth) {
    if (![error isKindOfClass:[NSError class]]) return SCIPoShape(error);
    NSError *e = error;

    NSMutableArray<NSString *> *info = [NSMutableArray array];
    for (id key in [e.userInfo.allKeys sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        return [[a description] compare:[b description]];
    }]) {
        if ([key isEqual:NSUnderlyingErrorKey]) continue;
        // The hamplayer's own account of itself is one long `name|k=v|k=v` string, and cutting it
        // at 60 characters is how the first report lost everything after "vw". Whole, to a ceiling.
        NSUInteger limit = [key isEqual:@"HAMErrorDetails"] ? 420 : 60;
        [info addObject:[NSString stringWithFormat:@"%@=%@", key, SCIPoValueLimit(e.userInfo[key], limit)]];
    }

    NSString *line = [NSString stringWithFormat:@"%@ %ld [%@]", e.domain, (long)e.code, [info componentsJoinedByString:@"; "]];
    NSError *underlying = e.userInfo[NSUnderlyingErrorKey];
    if (depth < 3 && [underlying isKindOfClass:[NSError class]]) {
        line = [line stringByAppendingFormat:@" ← %@", SCIPoErrorFull(underlying, depth + 1)];
    }
    return line;
}

void SCIYTPoProbeRecordPlayerError(id error) {
    if (!sNotes) return;
    SCIPoCount(@"player error seen");
    SCIPoNote([@"player error: " stringByAppendingString:SCIPoErrorFull(error, 0)]);
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

// MARK: - What reaches the screen

///
/// **"sbdl_failed" is not a network word.** The first report of a failing video named the
/// hamplayer's own error, `com.google.ios.hamplayer 2101`, with a details string whose format is
/// in the binary: `sbdl_failed|lyr=%d|dcd=%d|rls=%d|plr=%d|itm=%d|vws=%d|seq=%d|vcs=%d|hdnl=%d|
/// lpc=%d|tlm=%d|svs=%d|fg=%d|cpns=%@`. `sbdl` is the app's own abbreviation for
/// `AVSampleBufferDisplayLayer` (`alwaysEnqueueDecodedSamplesToAvsbdl`,
/// `hamplayerPrepareVideoDecoderForAvsbdl`), and the same report showed the stream itself fine:
/// thirty-six chunks completed without an error and the SABR loader failed nothing. So the stop is
/// at the *display layer* -- a frame it cannot decode or show -- and the useful questions are
/// what was being handed to it and what it said when it refused.
///
/// Two read-only observations answer them. The layer posts a documented notification when it
/// fails to decode, with the NSError (a VideoToolbox/CoreMedia status). And `-enqueueSampleBuffer:`
/// is wrapped to remember the *shape* of what goes in -- the codec of a compressed sample or the
/// pixel format and size of a decoded one -- counted by kind and kept for the last one, so the
/// failure line can say "the last thing enqueued was …". The wrapper runs once per frame and does
/// a handful of integer reads; it stores no pixels and no timestamps.
typedef struct { uint32_t subtype; uint32_t pixelFormat; int32_t width; int32_t height; uint32_t decoded; } SCIPoFrame;
static SCIPoFrame sLastFrame;
static uint32_t sSlotType[8];
static uint32_t sSlotDecoded[8];
static uint64_t sSlotCount[8];
static uint64_t sFramesEnqueued = 0;
static IMP sEnqueue = NULL;

static NSString *SCIPoFourCC(uint32_t code) {
    char text[5] = { (char)(code >> 24), (char)(code >> 16), (char)(code >> 8), (char)code, 0 };
    for (int i = 0; i < 4; i++) if (text[i] < 32 || text[i] > 126) return [NSString stringWithFormat:@"0x%08x", code];
    return [NSString stringWithUTF8String:text];
}

static NSString *SCIPoFrameString(SCIPoFrame f) {
    if (!f.subtype && !f.pixelFormat) return @"none yet";
    return f.decoded
        ? [NSString stringWithFormat:@"decoded pixels %@ %dx%d", SCIPoFourCC(f.pixelFormat), f.width, f.height]
        : [NSString stringWithFormat:@"compressed %@ %dx%d", SCIPoFourCC(f.subtype), f.width, f.height];
}

static void SCIPoSawFrame(CMSampleBufferRef buffer) {
    if (!buffer) return;
    SCIPoFrame frame = {0};

    CVImageBufferRef image = CMSampleBufferGetImageBuffer(buffer);
    if (image) {
        frame.decoded = 1;
        frame.pixelFormat = (uint32_t)CVPixelBufferGetPixelFormatType(image);
        frame.width = (int32_t)CVPixelBufferGetWidth(image);
        frame.height = (int32_t)CVPixelBufferGetHeight(image);
        frame.subtype = frame.pixelFormat;
    } else {
        CMFormatDescriptionRef description = CMSampleBufferGetFormatDescription(buffer);
        if (description) {
            frame.subtype = (uint32_t)CMFormatDescriptionGetMediaSubType(description);
            CMVideoDimensions size = CMVideoFormatDescriptionGetDimensions(description);
            frame.width = size.width;
            frame.height = size.height;
        }
    }

    sLastFrame = frame;
    __atomic_add_fetch(&sFramesEnqueued, 1, __ATOMIC_RELAXED);

    for (int i = 0; i < 8; i++) {
        uint32_t existing = __atomic_load_n(&sSlotType[i], __ATOMIC_RELAXED);
        if (existing == 0) {
            uint32_t expected = 0;
            if (!__atomic_compare_exchange_n(&sSlotType[i], &expected, frame.subtype, 0, __ATOMIC_RELAXED, __ATOMIC_RELAXED) &&
                expected != frame.subtype) continue;
            sSlotDecoded[i] = frame.decoded;
            existing = frame.subtype;
        }
        if (existing == frame.subtype) {
            __atomic_add_fetch(&sSlotCount[i], 1, __ATOMIC_RELAXED);
            return;
        }
    }
}

static void SCIPoInstallDisplayProbe(void) {
    Class layer = NSClassFromString(@"AVSampleBufferDisplayLayer");
    SEL selector = NSSelectorFromString(@"enqueueSampleBuffer:");
    Method method = layer ? class_getInstanceMethod(layer, selector) : NULL;
    const char *encoding = method ? method_getTypeEncoding(method) : NULL;

    if (encoding && strncmp(encoding, "v24@0:8^{opaqueCMSampleBuffer=}16", 33) == 0) {
        MSHookMessageEx(layer, selector, imp_implementationWithBlock(^(id me, CMSampleBufferRef buffer) {
            SCIPoSawFrame(buffer);
            if (sEnqueue) ((void (*)(id, SEL, CMSampleBufferRef))sEnqueue)(me, @selector(enqueueSampleBuffer:), buffer);
        }), &sEnqueue);
        [sHooks addObject:@"-AVSampleBufferDisplayLayer enqueueSampleBuffer: — attached"];
    } else {
        [sHooks addObject:[NSString stringWithFormat:@"-AVSampleBufferDisplayLayer enqueueSampleBuffer: — not hooked (encoding %s)", encoding ?: "?"]];
    }

    // Documented: posted when the layer fails to decode what it was given.
    [[NSNotificationCenter defaultCenter]
        addObserverForName:AVSampleBufferDisplayLayerFailedToDecodeNotification object:nil queue:nil
                usingBlock:^(NSNotification *note) {
        SCIPoCount(@"display layer: FAILED TO DECODE");
        id error = note.userInfo[AVSampleBufferDisplayLayerFailedToDecodeNotificationErrorKey];
        SCIPoNote([NSString stringWithFormat:@"display layer failed to decode: %@ · last enqueued: %@ · %llu enqueued",
                   SCIPoErrorFull(error, 0), SCIPoFrameString(sLastFrame), (unsigned long long)sFramesEnqueued]);
        // The measurement that found the cause is also what acts on it: a failure on VP9 or AV1
        // switches the H.264-only filter on (once, and it says so).
        if (!sLastFrame.decoded) SCIYTCodecFilterDecodeFailed(sLastFrame.subtype);
    }];
    [sHooks addObject:@"observing AVSampleBufferDisplayLayerFailedToDecodeNotification"];
}

// MARK: - What this phone tells YouTube it can play

///
/// **The server picks the codec from a declaration the app makes.** `MLMediaCapabilitiesProviderImpl`
/// hands the SABR request a `YTVSMediaCapabilities` -- a list of video formats the device claims
/// to handle, each with a codec, the largest size and rate, 10-bit and "efficient" flags -- and
/// the stream that arrives is chosen from it. The failing video offered **twenty** formats and the
/// working one **six, all H.264**; if the declaration says this phone can play a codec it cannot
/// show, the server will send exactly that to exactly the videos that have it, and the display
/// layer will fail a second or two in. Whether the declaration says so is a question this answers
/// by reading it: one line per entry, the codec as the number the proto stores, no guessing at
/// names.
static BOOL sCapsAttached = NO;
static IMP sCapsGetter = NULL, sCapsLoaded = NULL, sSwAv1 = NULL;
static NSString *sSwAv1Answer = nil;

static void SCIPoDescribeCaps(id caps) {
    if (!caps) return;
    id entries = SCISafeValueForKey(caps, @"videoFormatCapabilitiesArray");
    if (![entries isKindOfClass:[NSArray class]]) return;

    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    for (id entry in (NSArray *)entries) {
        NSNumber *codec = SCISafeNumberForKey(entry, @"videoCodec");
        NSNumber *w = SCISafeNumberForKey(entry, @"maxWidth"), *h = SCISafeNumberForKey(entry, @"maxHeight");
        NSNumber *fps = SCISafeNumberForKey(entry, @"maxFramerate");
        NSNumber *tenBit = SCISafeNumberForKey(entry, @"is10BitSupported");
        NSNumber *efficient = SCISafeNumberForKey(entry, @"efficient");
        [lines addObject:[NSString stringWithFormat:@"codec#%@ ≤%@x%@ %@fps%@%@", codec ?: @"?", w ?: @"?", h ?: @"?", fps ?: @"?",
                          tenBit.boolValue ? @" 10bit" : @"", efficient.boolValue ? @" efficient" : @""]];
    }
    NSNumber *hdr = SCISafeNumberForKey(caps, @"hdrModeBitmask");
    SCIPoCount(@"media capabilities declared");
    SCIPoNote([NSString stringWithFormat:@"declared to the server (%lu entries; hdr mask %@): %@",
               (unsigned long)lines.count, hdr ?: @"?", [lines componentsJoinedByString:@" | "]]);
}

static void SCIPoInstallCapabilityProbe(void) {
    SCIPoHook(@"MLMediaCapabilitiesProviderImpl", @"objcMediaCapabilities", "@16@0:8", imp_implementationWithBlock(^id(id me) {
        id caps = sCapsGetter ? ((id (*)(id, SEL))sCapsGetter)(me, @selector(objcMediaCapabilities)) : nil;
        SCIPoDescribeCaps(caps);
        return caps;
    }), &sCapsGetter, NO);

    SCIPoHook(@"MLMediaCapabilitiesProviderImpl", @"objcMediaCapabilitiesIfLoaded", "@16@0:8", imp_implementationWithBlock(^id(id me) {
        id caps = sCapsLoaded ? ((id (*)(id, SEL))sCapsLoaded)(me, @selector(objcMediaCapabilitiesIfLoaded)) : nil;
        SCIPoDescribeCaps(caps);
        return caps;
    }), &sCapsLoaded, NO);

    // The server-driven switch that adds *software* AV1 (the app carries its own dav1d) to that
    // declaration. Recorded as answered; whether to override it is a decision for after the
    // declaration above is read.
    SCIPoHook(@"YTColdConfig", @"iosPlayerClientSharedConfigPopulateSwAv1MediaCapabilities", "B16@0:8", imp_implementationWithBlock(^BOOL(id me) {
        BOOL value = sSwAv1 ? ((BOOL (*)(id, SEL))sSwAv1)(me, NSSelectorFromString(@"iosPlayerClientSharedConfigPopulateSwAv1MediaCapabilities")) : NO;
        @synchronized (sFlags) { sFlags[@"populateSwAv1MediaCapabilities"] = value ? @"YES" : @"NO"; }
        // In H.264-only mode the declaration stops adding software AV1: a claim this phone is
        // better off not making. Only the claim is narrowed; nothing is added to it.
        if (value && [[NSUserDefaults standardUserDefaults] boolForKey:@"h264_only"]) {
            @synchronized (sFlags) { sFlags[@"populateSwAv1MediaCapabilities"] = @"YES (answered NO: H.264-only mode)"; }
            return NO;
        }
        return value;
    }), &sSwAv1, NO);
    sCapsAttached = YES;
}

static IMP sMintImmediate = NULL, sMintManager = NULL, sStreamStatus = NULL, sPoMinted = NULL;
static IMP sHandleChallenge = NULL, sEndState = NULL;
static IMP sFlagMedia = NULL, sFlagInjection = NULL, sFlagCabr = NULL, sFlagOutside = NULL;
static IMP sFailWith = NULL, sQoeError = NULL, sChunkError = NULL, sOnesieChunks = NULL, sOnesieDone = NULL;
static IMP sNonFatal = NULL, sReloadResp = NULL, sDebugInfo = NULL;

/// The loader's own account of why, when it has one: `-QOEDebugDetails` is a getter the SABR
/// loader keeps for exactly this. Cut and never a URL.
static NSString *SCIPoDetails(id loader) {
    SEL selector = NSSelectorFromString(@"QOEDebugDetails");
    if (![loader respondsToSelector:selector]) return @"(no details getter)";
    id details = ((id (*)(id, SEL))objc_msgSend)(loader, selector);
    return SCIPoValue(details);
}

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

    SCIPoInstallDisplayProbe();
    SCIPoInstallCapabilityProbe();

    // The SABR loader: where the stream stops. These carry real NSErrors -- and the loader's own
    // note of why -- which the player-level error ("Something went wrong") does not. The one
    // that takes a C++ struct by value (`-failWithError:fallbackConfig:`) is deliberately not
    // hooked: its layout is not read from anything, and the object-only sibling is.
    SCIPoHook(@"MLPlatypusABRLoader", @"failWithError:", "v24@0:8@16", imp_implementationWithBlock(^(id me, id error) {
        SCIPoCount(@"sabr loader: failWithError");
        SCIPoNote([NSString stringWithFormat:@"sabr failWithError: %@ · details: %@", SCIPoErrorFull(error, 0), SCIPoDetails(me)]);
        if (sFailWith) ((void (*)(id, SEL, id))sFailWith)(me, @selector(failWithError:), error);
    }), &sFailWith, NO);

    SCIPoHook(@"MLPlatypusABRLoader", @"onQoeError:fallbackConfig:", "v32@0:8r^v16r^{FallbackConfig=iBBB}24",
              imp_implementationWithBlock(^(id me, const void *qoe, const void *fallback) {
        SCIPoCount(@"sabr loader: onQoeError");
        SCIPoNote([NSString stringWithFormat:@"sabr onQoeError — details: %@", SCIPoDetails(me)]);
        if (sQoeError) ((void (*)(id, SEL, const void *, const void *))sQoeError)(me, NSSelectorFromString(@"onQoeError:fallbackConfig:"), qoe, fallback);
    }), &sQoeError, NO);

    SCIPoHook(@"MLPlatypusABRLoader", @"onChunk:completeWithError:", "v32@0:8@16@24", imp_implementationWithBlock(^(id me, id chunk, id error) {
        if (error) {
            SCIPoCount(@"sabr loader: chunk completed WITH ERROR");
            SCIPoNote([@"sabr chunk error: " stringByAppendingString:SCIPoErrorFull(error, 0)]);
        } else {
            SCIPoCount(@"sabr loader: chunk completed ok");
        }
        if (sChunkError) ((void (*)(id, SEL, id, id))sChunkError)(me, NSSelectorFromString(@"onChunk:completeWithError:"), chunk, error);
    }), &sChunkError, NO);

    SCIPoHook(@"MLPlatypusABRLoader", @"onesieDataLoader:didCompleteChunks:withError:", "v40@0:8@16@24@32",
              imp_implementationWithBlock(^(id me, id loader, id chunks, id error) {
        if (error) {
            SCIPoCount(@"onesie data loader: chunks completed WITH ERROR");
            SCIPoNote([@"onesie chunks error: " stringByAppendingString:SCIPoErrorFull(error, 0)]);
        }
        if (sOnesieChunks) ((void (*)(id, SEL, id, id, id))sOnesieChunks)(me, NSSelectorFromString(@"onesieDataLoader:didCompleteChunks:withError:"), loader, chunks, error);
    }), &sOnesieChunks, NO);

    SCIPoHook(@"MLPlatypusABRLoader", @"onesieDataLoader:didCompleteWithError:", "v32@0:8@16@24",
              imp_implementationWithBlock(^(id me, id loader, id error) {
        if (error) {
            SCIPoCount(@"onesie data loader: completed WITH ERROR");
            SCIPoNote([@"onesie loader error: " stringByAppendingString:SCIPoErrorFull(error, 0)]);
        }
        if (sOnesieDone) ((void (*)(id, SEL, id, id))sOnesieDone)(me, NSSelectorFromString(@"onesieDataLoader:didCompleteWithError:"), loader, error);
    }), &sOnesieDone, NO);

    SCIPoHook(@"MLPlatypusABRLoader", @"recordNonFatalQOEErrorWithCode:details:", "v32@0:8@16@24",
              imp_implementationWithBlock(^(id me, id code, id details) {
        SCIPoCount(@"sabr loader: non-fatal QoE error");
        SCIPoNote([NSString stringWithFormat:@"non-fatal QoE error: code %@ · %@", SCIPoValue(code), SCIPoValue(details)]);
        if (sNonFatal) ((void (*)(id, SEL, id, id))sNonFatal)(me, NSSelectorFromString(@"recordNonFatalQOEErrorWithCode:details:"), code, details);
    }), &sNonFatal, NO);

    // The server asking the client to start the player over (a stale playback context, a new
    // token wanted). Counted only: its payload is a C++ message.
    SCIPoHook(@"MLPlatypusABRLoader", @"didParseReloadPlayerResponse:", "v24@0:8r^v16", imp_implementationWithBlock(^(id me, const void *response) {
        SCIPoCount(@"sabr: server asked to RELOAD the player");
        if (sReloadResp) ((void (*)(id, SEL, const void *))sReloadResp)(me, @selector(didParseReloadPlayerResponse:), response);
    }), &sReloadResp, NO);

    SCIPoHook(@"MLPlatypusABRLoader", @"didReceivePlaybackDebugInfo:", "v24@0:8r^v16", imp_implementationWithBlock(^(id me, const void *info) {
        SCIPoCount(@"sabr: playback debug info received");
        if (sDebugInfo) ((void (*)(id, SEL, const void *))sDebugInfo)(me, @selector(didReceivePlaybackDebugInfo:), info);
    }), &sDebugInfo, NO);

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

/// The phone itself, which no report had said: the model and the system, and what VideoToolbox
/// answers when *asked* whether each codec decodes in hardware. A pure query -- nothing is
/// registered, created or decoded. It is the other half of "the app declared VP9": what the
/// declaration claims, next to what the system says about the same codec.
static NSString *SCIPoDeviceLine(void) {
    char machine[64] = {0};
    size_t size = sizeof(machine);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);

    struct { const char *name; CMVideoCodecType codec; } codecs[] = {
        { "h264", kCMVideoCodecType_H264 }, { "hevc", kCMVideoCodecType_HEVC },
        { "vp9", kCMVideoCodecType_VP9 },   { "av1", kCMVideoCodecType_AV1 },
    };
    NSMutableArray<NSString *> *answers = [NSMutableArray array];
    for (size_t i = 0; i < sizeof(codecs) / sizeof(codecs[0]); i++) {
        [answers addObject:[NSString stringWithFormat:@"%s %@", codecs[i].name,
                            VTIsHardwareDecodeSupported(codecs[i].codec) ? @"yes" : @"no"]];
    }
    return [NSString stringWithFormat:@"device: %s · iOS %@ · VideoToolbox hardware decode: %@",
            machine, [UIDevice currentDevice].systemVersion, [answers componentsJoinedByString:@", "]];
}

NSString *SCIYTPoProbeReport(void) {
    NSMutableString *out = [NSMutableString stringWithFormat:@"po-token probe (read-only; lengths and counts, never a token):\n  %@\n", SCIPoDeviceLine()];

    @synchronized (sCounts) {
        if (!sCounts.count) [out appendString:@"  nothing seen yet — play a video that fails, then read this again\n"];
        for (NSString *key in [sCounts.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            [out appendFormat:@"  %@ ×%@\n", key, sCounts[key]];
        }
    }
    if (sFramesEnqueued) {
        NSMutableArray<NSString *> *kinds = [NSMutableArray array];
        for (int i = 0; i < 8; i++) {
            if (!sSlotType[i]) continue;
            [kinds addObject:[NSString stringWithFormat:@"%@%@ ×%llu", sSlotDecoded[i] ? @"decoded " : @"", SCIPoFourCC(sSlotType[i]), (unsigned long long)sSlotCount[i]]];
        }
        [out appendFormat:@"  frames handed to the display layer: %llu — %@ — last: %@\n",
         (unsigned long long)sFramesEnqueued, [kinds componentsJoinedByString:@", "], SCIPoFrameString(sLastFrame)];
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
