#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#import "SCIYTCodecFilter.h"
#import "../../SCILog.h"
#import "../../Prefs.h"
#import "../../SCIYTLaunchGuard.h"
#import "../../Localization/SCILocalize.h"
#import "shared/src/SCIKVC.h"

static NSString *sHookState = @"not installed";
static NSUInteger sResponses = 0, sFilteredResponses = 0, sSkippedNoAvc = 0;
static NSUInteger sRemoved = 0, sKept = 0;
static NSMutableDictionary<NSString *, NSNumber *> *sRemovedByCodec = nil;
static NSString *sAutoNote = nil;
static BOOL sAutoAlertShown = NO;
static IMP sOriginalStreamingData = NULL;
static IMP sOriginalSetConstraint = NULL;
static NSString *sConstraintHookState = @"not installed";
static NSUInteger sConstraintsWrapped = 0, sReductions = 0, sReductionsNoAvc = 0;
static NSMutableArray<NSString *> *sConstraintNotes = nil;
static char kSCIFiltered;

static NSString *SCICodecOf(NSString *mime) {
    NSString *lower = mime.lowercaseString;
    if (![lower hasPrefix:@"video/"]) return nil;
    if ([lower containsString:@"av01"] || [lower containsString:@"av1"]) return @"AV1";
    if ([lower containsString:@"vp09"] || [lower containsString:@"vp9"]) return @"VP9";
    return nil;
}

/// Removes the VP9 and AV1 video entries from `adaptiveFormatsArray`, in place, when an H.264
/// video entry is left. A video offered *only* as VP9/AV1 (some 4K) is left whole: no picture is
/// worse than a picture that may fail.
static void SCIYTFilterStreamingData(id streamingData) {
    if (!streamingData || objc_getAssociatedObject(streamingData, &kSCIFiltered)) return;
    sResponses++;

    @synchronized (streamingData) {
        id list = SCISafeValueForKey(streamingData, @"adaptiveFormatsArray");
        if (![list isKindOfClass:[NSMutableArray class]]) return;
        NSMutableArray *formats = list;

        NSMutableIndexSet *drop = [NSMutableIndexSet indexSet];
        NSUInteger avc = 0;
        NSMutableDictionary<NSString *, NSNumber *> *dropped = [NSMutableDictionary dictionary];

        for (NSUInteger i = 0; i < formats.count; i++) {
            NSString *mime = SCISafeValueForKey(formats[i], @"mimeType");
            if (![mime isKindOfClass:[NSString class]]) continue;

            NSString *codec = SCICodecOf(mime);
            if (codec) {
                [drop addIndex:i];
                dropped[codec] = @(dropped[codec].unsignedIntegerValue + 1);
            } else if ([mime.lowercaseString hasPrefix:@"video/"] && [mime.lowercaseString containsString:@"avc1"]) {
                avc++;
            }
        }

        if (!drop.count) { objc_setAssociatedObject(streamingData, &kSCIFiltered, @YES, OBJC_ASSOCIATION_RETAIN); return; }
        if (!avc) { sSkippedNoAvc++; objc_setAssociatedObject(streamingData, &kSCIFiltered, @YES, OBJC_ASSOCIATION_RETAIN); return; }

        [formats removeObjectsAtIndexes:drop];
        objc_setAssociatedObject(streamingData, &kSCIFiltered, @YES, OBJC_ASSOCIATION_RETAIN);

        sFilteredResponses++;
        sRemoved += drop.count;
        sKept += avc;
        if (!sRemovedByCodec) sRemovedByCodec = [NSMutableDictionary dictionary];
        for (NSString *codec in dropped) {
            sRemovedByCodec[codec] = @(sRemovedByCodec[codec].unsignedIntegerValue + dropped[codec].unsignedIntegerValue);
        }
    }
}

static void SCIYTInstallCodecFilter(void) {
    Class cls = objc_getClass("YTIPlayerResponse");
    if (!cls) { sHookState = @"YTIPlayerResponse not in this build"; return; }

    SEL selector = NSSelectorFromString(@"streamingData");
    // A generated model: the getter is resolved on first use, so ask before looking.
    (void)[cls instancesRespondToSelector:selector];

    Method method = class_getInstanceMethod(cls, selector);
    if (!method) { sHookState = @"-streamingData not on this build"; return; }

    const char *encoding = method_getTypeEncoding(method);
    if (!encoding || strcmp(encoding, "@16@0:8") != 0) {
        sHookState = [NSString stringWithFormat:@"-streamingData encoding %s, expected @16@0:8", encoding ?: "?"];
        return;
    }

    MSHookMessageEx(cls, selector, imp_implementationWithBlock(^id(id me) {
        id data = sOriginalStreamingData ? ((id (*)(id, SEL))sOriginalStreamingData)(me, selector) : nil;
        if (data && SCIPrefEnabled(SCIPrefH264Only) && !SCIYTStoodDown()) SCIYTFilterStreamingData(data);
        return data;
    }), &sOriginalStreamingData);
    sHookState = @"attached to YTIPlayerResponse -streamingData";
}

// MARK: - Choosing one format, the way a manual quality choice does

///
/// **Filtering the list was not enough, and what the owner did by hand showed why.** With the
/// list filtered (1.40.0) the failing video stopped at 0:00 and, after a long wait, played sound
/// with no picture; the report showed **41,984** non-fatal `sabr.invalidformat` errors --
/// `init_metadata_badid_formatid_243_…`, `…248…`, `…244…`, `…247…`, all VP9 itags the player no
/// longer knew. The server still chose VP9: in automatic mode it picks the format *itself*
/// (`_serverDrivenSelectableFormats`) from everything it has, and the client's list is not a
/// restriction on it. Then the owner chose **1080p by hand, and the video played normally** --
/// a manual choice leaves the client with exactly one format, and the server serves that one.
///
/// So the automatic mode is made to do the same thing: the loader's *video* format constraint is
/// handed to the player as it is, except that its `-filterFormats:` -- whatever it decides -- is
/// followed by "and of those, only the best H.264 one". It is done by giving that one constraint
/// object a subclass of its own class (so everything else it answers is unchanged and
/// `-isKindOfClass:` still holds), rather than by hooking all six constraint classes, because
/// constraints are applied in a chain and a reduction in the middle of it could be dropped by a
/// later cap and leave nothing at all -- the loader holds *one* constraint, and this is applied to it.
///
/// The price is adaptivity: one format, as with a manual choice. Lower it by hand on a slow line.
static NSString *SCIYTMimeOfFormat(id format) {
    id stream = SCISafeValueForKey(format, @"formatStream");
    id mime = SCISafeValueForKey(stream, @"mimeType");
    return [mime isKindOfClass:[NSString class]] ? mime : nil;
}

static NSArray *SCIYTBestH264(NSArray *formats) {
    if (![formats isKindOfClass:[NSArray class]] || formats.count < 2) return formats;
    if (!SCISafeBoolForKey(formats.firstObject, @"isVideo")) return formats;

    id best = nil;
    NSInteger bestHeight = -1, bestBitrate = -1;
    for (id format in formats) {
        NSString *mime = SCIYTMimeOfFormat(format).lowercaseString;
        if (![mime hasPrefix:@"video/"] || ![mime containsString:@"avc1"]) continue;

        NSInteger height = SCISafeNumberForKey(format, @"height").integerValue;
        NSInteger bitrate = SCISafeNumberForKey(format, @"bitrate").integerValue;
        if (height > bestHeight || (height == bestHeight && bitrate > bestBitrate)) {
            best = format; bestHeight = height; bestBitrate = bitrate;
        }
    }

    if (!best) { sReductionsNoAvc++; return formats; }

    sReductions++;
    if (!sConstraintNotes) sConstraintNotes = [NSMutableArray array];
    NSString *note = [NSString stringWithFormat:@"reduced %lu → 1: itag %@ %@p (%@)", (unsigned long)formats.count,
                      SCISafeNumberForKey(best, @"itag") ?: @"?", @(bestHeight), SCIYTMimeOfFormat(best)];
    if (sConstraintNotes.count < 6 && ![sConstraintNotes containsObject:note]) [sConstraintNotes addObject:note];
    return @[best];
}

/// The original class's constraint with the reduction added; one subclass per original class.
static Class SCIYTReducingSubclass(Class original) {
    NSString *name = [@"SCIYTH264_" stringByAppendingString:NSStringFromClass(original)];
    Class existing = NSClassFromString(name);
    if (existing) return existing;

    SEL selector = @selector(filterFormats:);
    IMP base = class_getMethodImplementation(original, selector);
    Class subclass = objc_allocateClassPair(original, name.UTF8String, 0);
    if (!subclass || !base) return Nil;

    class_addMethod(subclass, selector, imp_implementationWithBlock(^id(id me, NSArray *formats) {
        id filtered = ((id (*)(id, SEL, id))base)(me, selector, formats);
        return SCIPrefEnabled(SCIPrefH264Only) ? SCIYTBestH264(filtered) : filtered;
    }), "@24@0:8@16");
    objc_registerClassPair(subclass);
    return subclass;
}

static void SCIYTInstallConstraintHook(void) {
    Class loader = objc_getClass("MLPlatypusABRLoader");
    SEL selector = NSSelectorFromString(@"setVideoFormatConstraint:");
    Method method = loader ? class_getInstanceMethod(loader, selector) : NULL;
    const char *encoding = method ? method_getTypeEncoding(method) : NULL;

    if (!encoding || strcmp(encoding, "v24@0:8@16") != 0) {
        sConstraintHookState = loader ? [NSString stringWithFormat:@"-setVideoFormatConstraint: encoding %s", encoding ?: "missing"]
                                      : @"MLPlatypusABRLoader not in this build";
        return;
    }

    MSHookMessageEx(loader, selector, imp_implementationWithBlock(^(id me, id constraint) {
        if (constraint && SCIPrefEnabled(SCIPrefH264Only) && !SCIYTStoodDown()) {
            Class cls = object_getClass(constraint);
            BOOL already = [NSStringFromClass(cls) hasPrefix:@"SCIYTH264_"];
            BOOL answers = [constraint respondsToSelector:@selector(filterFormats:)];
            // A constraint that switches the track off is not a choice of format.
            BOOL disables = SCISafeBoolForKey(constraint, @"disableTrack");

            if (!already && answers && !disables) {
                Class subclass = SCIYTReducingSubclass(cls);
                if (subclass) { object_setClass(constraint, subclass); sConstraintsWrapped++; }
            }
        }
        if (sOriginalSetConstraint) ((void (*)(id, SEL, id))sOriginalSetConstraint)(me, selector, constraint);
    }), &sOriginalSetConstraint);
    sConstraintHookState = @"attached to MLPlatypusABRLoader -setVideoFormatConstraint:";
}

// MARK: - Turning itself on

static UIViewController *SCIYTRoot(void) {
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *window in [(UIWindowScene *)scene windows]) {
            if (window.isKeyWindow && window.rootViewController) {
                UIViewController *top = window.rootViewController;
                while (top.presentedViewController && !top.presentedViewController.isBeingDismissed) top = top.presentedViewController;
                return top;
            }
        }
    }
    return nil;
}

void SCIYTCodecFilterDecodeFailed(uint32_t subtype) {
    // 'vp09' and 'av01'. Anything else failing to decode is not what this is for.
    BOOL vp9 = subtype == 0x76703039, av1 = subtype == 0x61763031;
    if (!vp9 && !av1) return;
    if (SCIPrefEnabled(SCIPrefH264Only) || !SCIPrefEnabled(SCIPrefAutoH264)) return;

    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:SCIPrefH264Only];
    sAutoNote = [NSString stringWithFormat:@"switched on by itself: the display layer failed on %@ samples", vp9 ? @"VP9" : @"AV1"];

    if (sAutoAlertShown) return;
    sAutoAlertShown = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *top = SCIYTRoot();
        if (!top) return;
        UIAlertController *note = [UIAlertController alertControllerWithTitle:SCILocalized(@"h264_auto_title")
                                                                      message:SCILocalized(@"h264_auto_message")
                                                               preferredStyle:UIAlertControllerStyleAlert];
        [note addAction:[UIAlertAction actionWithTitle:SCILocalized(@"ok") style:UIAlertActionStyleDefault handler:nil]];
        [top presentViewController:note animated:YES completion:nil];
    });
}

NSString *SCIYTCodecFilterReport(void) {
    NSMutableString *out = [NSMutableString stringWithFormat:@"h264-only filter: %@ · hook: %@",
                            SCIPrefEnabled(SCIPrefH264Only) ? @"ON" : @"off", sHookState];
    [out appendFormat:@"\n  %lu response(s) filtered of %lu seen · %lu format(s) removed (%@) · %lu H.264 video(s) kept · %lu left whole (no H.264 video in them)",
     (unsigned long)sFilteredResponses, (unsigned long)sResponses, (unsigned long)sRemoved,
     sRemovedByCodec.count ? [[sRemovedByCodec.allKeys sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@"/"] : @"none",
     (unsigned long)sKept, (unsigned long)sSkippedNoAvc];
    [out appendFormat:@"\n  one-format choice: %@ · %lu constraint(s) wrapped · %lu reduction(s) · %lu with no H.264 to pick",
     sConstraintHookState, (unsigned long)sConstraintsWrapped, (unsigned long)sReductions, (unsigned long)sReductionsNoAvc];
    for (NSString *note in sConstraintNotes) [out appendFormat:@"\n    · %@", note];
    if (sAutoNote) [out appendFormat:@"\n  %@", sAutoNote];
    return out;
}

__attribute__((constructor)) static void SCIYTCodecFilterRegister(void) {
    SCIYTWhenActive(^{ SCIYTInstallCodecFilter(); SCIYTInstallConstraintHook(); });
}
