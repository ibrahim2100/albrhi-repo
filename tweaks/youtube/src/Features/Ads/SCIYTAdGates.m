#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#import "../../SCILog.h"
#import "../../Prefs.h"
#import "../../SCIYTLaunchGuard.h"
#import "../../Diagnostics/SCIYTDiagnostics.h"

///
/// Ad gates beyond the three layers in SCIYTAdBlock.x -- installed at runtime, each one only
/// where this build declares it with the signature written below, and each one counted.
///
/// **Where they come from.** YTKACE (github.com/itzzace/ytkace, MIT) hooks these places and ships
/// on YouTube 21.33.6 and 21.39.4. That is a *map* of where ads can be stopped, not a manifest
/// of this build -- this project has lost releases to exactly that difference on TikTok, X and
/// Instagram -- so nothing here is written as `%hook`. A `%hook` on a method the class does not
/// declare *adds* it, and an added getter that never calls an original quietly replaces whatever
/// the app resolves for itself. The code below never adds anything: it asks, and steps over what
/// is not there. Read for where to look; nothing copied.
///
/// **Protobuf getters need asking first.** `YTIPlayerResponse` is a generated model whose
/// accessors are resolved on first use, so `class_getInstanceMethod` answers NULL for a getter
/// the class certainly has -- the same fact `SCISafeValueForKey` was written around. Sending
/// `+instancesRespondToSelector:` runs the resolver, which installs the real method, and only
/// then is there something to hook *with its original preserved*: switched off, the app gets its
/// own answer back.
///
/// **After the launch, not during it.** This is registered for the first moment the app is
/// active, for the reason the tab bar and the request decorators are: the launch is the one part
/// of a process a tweak must not be inside.
///

typedef NS_ENUM(NSInteger, SCIYTGateKind) {
    SCIYTGateEmptyArray,     // -(id)x            -> an empty array
    SCIYTGateNilObject,      // -(id)x            -> nil
    SCIYTGateReelFilter,     // -(id)x:(id)entry  -> nil when the model is an ad
    SCIYTGateSwallowEvent,   // -(void)x:(id)e    -> nothing
    SCIYTGateSwallow,        // -(void)x          -> nothing
    SCIYTGateSwallowContext, // -(void)x:(id)ctx serviceType:(NSInteger)t -> nothing   (21.47: the request decorators' new shape)
    SCIYTGateReelList,       // -(id)x:(NSArray *)entries -> the models, without the ones that are ads
};

static BOOL SCIYTGateActive(void) {
    return SCIPrefEnabled(SCIPrefHideAds) && !SCIYTStoodDown();
}

static const char *SCIYTGateEncoding(SCIYTGateKind kind) {
    switch (kind) {
        case SCIYTGateEmptyArray:
        case SCIYTGateNilObject:    return "@16@0:8";
        case SCIYTGateReelFilter:   return "@24@0:8@16";
        case SCIYTGateSwallowEvent: return "v24@0:8@16";
        case SCIYTGateSwallow:      return "v16@0:8";
        case SCIYTGateSwallowContext: return "v32@0:8@16q24";
        case SCIYTGateReelList:     return "@24@0:8@16";
    }
    return "";
}

/// A reel's kind, asked of the model itself. In YTKACE's build `videoType == 3` is an ad; the
/// selector is only sent when this build's model declares it with an integer return, and a model
/// that does not answers "not an ad" -- which leaves the Short in the feed, the side to err on.
static BOOL SCIYTReelIsAd(id model) {
    SEL selector = NSSelectorFromString(@"videoType");
    Method method = class_getInstanceMethod(object_getClass(model), selector);
    if (!method) return NO;

    const char *encoding = method_getTypeEncoding(method);
    if (!encoding || strcmp(encoding, "q16@0:8") != 0) return NO;

    return ((NSInteger (*)(id, SEL))objc_msgSend)(model, selector) == 3;
}

/// A BOOL getter asked of somebody else's object only when the object declares it with exactly that encoding.
static BOOL SCIYTBoolGetter(id object, NSString *name) {
    if (!object) return NO;
    SEL selector = NSSelectorFromString(name);
    Method method = class_getInstanceMethod(object_getClass(object), selector);
    const char *encoding = method ? method_getTypeEncoding(method) : NULL;
    if (!encoding || strcmp(encoding, "B16@0:8") != 0) return NO;
    return ((BOOL (*)(id, SEL))objc_msgSend)(object, selector);
}

static id SCIYTObjectGetter(id object, NSString *name) {
    if (!object) return nil;
    SEL selector = NSSelectorFromString(name);
    Method method = class_getInstanceMethod(object_getClass(object), selector);
    const char *encoding = method ? method_getTypeEncoding(method) : NULL;
    if (!encoding || strcmp(encoding, "@16@0:8") != 0) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(object, selector);
}

/// A Shorts content model that is an ad, asked of the models themselves: `YTReelContentModel` carries a `reelModel` (and a `watchModel`), and
/// `YTReelModel -isAdVideo` is the app's own answer. Anything that cannot be asked is "not an ad", the side to err on.
static BOOL SCIYTReelContentIsAd(id content) {
    if (SCIYTBoolGetter(content, @"isAdVideo")) return YES;
    if (SCIYTBoolGetter(SCIYTObjectGetter(content, @"reelModel"), @"isAdVideo")) return YES;
    if (SCIYTBoolGetter(SCIYTObjectGetter(content, @"watchModel"), @"isAdVideo")) return YES;
    return NO;
}

static BOOL SCIYTInstallGate(NSString *className, NSString *selectorName, SCIYTGateKind kind) {
    NSString *label = [NSString stringWithFormat:@"%@ %@", className, selectorName];

    Class cls = objc_getClass(className.UTF8String);
    if (!cls) {
        [SCIYTDiagnostics registerAdGate:label status:@"class not in this build"];
        return NO;
    }

    SEL selector = NSSelectorFromString(selectorName);

    // Runs the resolver for a generated model's getter; a no-op for an ordinary method.
    (void)[cls instancesRespondToSelector:selector];

    Method method = class_getInstanceMethod(cls, selector);
    if (!method) {
        [SCIYTDiagnostics registerAdGate:label status:@"method not on this build"];
        return NO;
    }

    const char *actual = method_getTypeEncoding(method);
    if (!actual || strcmp(actual, SCIYTGateEncoding(kind)) != 0) {
        [SCIYTDiagnostics registerAdGate:label
                                  status:[NSString stringWithFormat:@"not hooked: encoding is %s, expected %s",
                                          actual ?: "?", SCIYTGateEncoding(kind)]];
        return NO;
    }

    // One cell per gate so each block calls its own original.
    IMP *orig = calloc(1, sizeof(IMP));
    IMP replacement = NULL;

    switch (kind) {
        case SCIYTGateEmptyArray: {
            replacement = imp_implementationWithBlock(^id(id me) {
                if (SCIYTGateActive()) {
                    [SCIYTDiagnostics countAdGate:label];
                    return [NSMutableArray array];
                }
                return *orig ? ((id (*)(id, SEL))*orig)(me, selector) : nil;
            });
            break;
        }
        case SCIYTGateNilObject: {
            replacement = imp_implementationWithBlock(^id(id me) {
                if (SCIYTGateActive()) {
                    [SCIYTDiagnostics countAdGate:label];
                    return nil;
                }
                return *orig ? ((id (*)(id, SEL))*orig)(me, selector) : nil;
            });
            break;
        }
        case SCIYTGateReelFilter: {
            replacement = imp_implementationWithBlock(^id(id me, id entry) {
                id model = *orig ? ((id (*)(id, SEL, id))*orig)(me, selector, entry) : nil;
                if (model && SCIYTGateActive() && SCIYTReelIsAd(model)) {
                    [SCIYTDiagnostics countAdGate:label];
                    return nil;
                }
                return model;
            });
            break;
        }
        case SCIYTGateSwallowEvent: {
            replacement = imp_implementationWithBlock(^(id me, id event) {
                if (SCIYTGateActive()) {
                    [SCIYTDiagnostics countAdGate:label];
                    return;
                }
                if (*orig) ((void (*)(id, SEL, id))*orig)(me, selector, event);
            });
            break;
        }
        case SCIYTGateSwallowContext: {
            replacement = imp_implementationWithBlock(^(id me, id context, NSInteger serviceType) {
                if (SCIYTGateActive()) {
                    [SCIYTDiagnostics countAdGate:label];
                    return;
                }
                if (*orig) ((void (*)(id, SEL, id, NSInteger))*orig)(me, selector, context, serviceType);
            });
            break;
        }
        case SCIYTGateReelList: {
            replacement = imp_implementationWithBlock(^id(id me, id entries) {
                id models = *orig ? ((id (*)(id, SEL, id))*orig)(me, selector, entries) : nil;
                if (!models || ![models isKindOfClass:[NSArray class]] || !SCIYTGateActive()) return models;

                NSMutableArray *kept = [NSMutableArray arrayWithCapacity:[models count]];
                for (id content in (NSArray *)models) {
                    if (SCIYTReelContentIsAd(content)) { [SCIYTDiagnostics countAdGate:label]; continue; }
                    [kept addObject:content];
                }
                if (kept.count == [models count]) return models;
                return [models isKindOfClass:[NSMutableArray class]] ? kept : [kept copy];
            });
            break;
        }
        case SCIYTGateSwallow: {
            replacement = imp_implementationWithBlock(^(id me) {
                if (SCIYTGateActive()) {
                    [SCIYTDiagnostics countAdGate:label];
                    return;
                }
                if (*orig) ((void (*)(id, SEL))*orig)(me, selector);
            });
            break;
        }
    }

    MSHookMessageEx(cls, selector, replacement, orig);
    [SCIYTDiagnostics registerAdGate:label status:@"hooked"];
    SCILogV(@"ads: gate installed on %@", label);
    return YES;
}

static void SCIYTInstallAdGates(void) {
    static BOOL installed = NO;
    if (installed) return;
    installed = YES;

    // The player response: the lists and parameters an ad is scheduled from. Data, not views.
    SCIYTInstallGate(@"YTIPlayerResponse", @"playerAdsArray",    SCIYTGateEmptyArray);
    SCIYTInstallGate(@"YTIPlayerResponse", @"adSlotsArray",      SCIYTGateEmptyArray);
    SCIYTInstallGate(@"YTIPlayerResponse", @"adPlacementsArray", SCIYTGateEmptyArray);
    SCIYTInstallGate(@"YTIPlayerResponse", @"adBreakParams",     SCIYTGateNilObject);
    SCIYTInstallGate(@"YTIPlayerResponse", @"adNextParams",      SCIYTGateNilObject);
    SCIYTInstallGate(@"YTIPlayerResponse", @"adParams",          SCIYTGateNilObject);

    // Shorts: the list the pager is built from, so an ad is *not a page* -- where
    // SCIYTShortsAds.x can only refuse to draw one, leaving the slot to be swiped past.
    //
    // **`makeContentModelForEntry:` is not in 21.41.5 or 21.47.6** (read from both binaries, 2026-11-24): it was YTKACE's door on 21.33-21.39 and the Shorts
    // ad gate has been dead since. What the data source declares now is the plural, `-contentModelsForEntries:` (`@24@0:8@16`: entries in, models out), and
    // a model says what it is itself (`YTReelContentModel -reelModel` -> `YTReelModel -isAdVideo`, `B16@0:8`). Both doors stay: a build that has the old
    // one is served by it, and each is counted on its own line in the report.
    SCIYTInstallGate(@"YTReelDataSource",                @"makeContentModelForEntry:", SCIYTGateReelFilter);
    SCIYTInstallGate(@"YTReelInfinitePlaybackDataSource", @"makeContentModelForEntry:", SCIYTGateReelFilter);
    SCIYTInstallGate(@"YTReelDataSource",                @"contentModelsForEntries:",  SCIYTGateReelList);

    // The request: what attaches ad capabilities and targeting to an InnerTube request. Skipping it is the cheap way to get a response with no ads in
    // it, and it was done by `%hook` until 21.47.6 renamed the selector (`-decorateContext:` -> `-decorateContext:serviceType:`, `v32@0:8@16q24`) and moved
    // the account-scoped one to `...Impl`: a `%hook` on the old name quietly became a method nobody calls and the app asked for ads again. Every name this
    // has had is listed; each is installed only where the build declares it with that encoding, and counted.
    SCIYTInstallGate(@"YTAdsInnerTubeContextDecoratorImpl",             @"decorateContext:serviceType:", SCIYTGateSwallowContext);
    SCIYTInstallGate(@"YTAccountScopedAdsInnerTubeContextDecoratorImpl", @"decorateContext:serviceType:", SCIYTGateSwallowContext);
    SCIYTInstallGate(@"YTAdsInnerTubeContextDecoratorImpl",             @"decorateContext:",            SCIYTGateSwallowEvent);
    SCIYTInstallGate(@"YTAccountScopedAdsInnerTubeContextDecorator",    @"decorateContext:",            SCIYTGateSwallowEvent);
    SCIYTInstallGate(@"YTAdsInnerTubeContextDecorator",                 @"decorateContext:",            SCIYTGateSwallowEvent);

    // Premium upsells. Presentations only, each a single call to swallow; nothing here answers
    // a question the app is waiting on.
    SCIYTInstallGate(@"YTMealbarPromoController", @"showMealbarPromoWithEvent:",   SCIYTGateSwallowEvent);
    SCIYTInstallGate(@"YTPromosheetController",   @"presentPromosheetWithEvent:",  SCIYTGateSwallowEvent);
    SCIYTInstallGate(@"YTUpgradeController",      @"showUpgradeDialog",            SCIYTGateSwallow);
    SCIYTInstallGate(@"YTUpgradeController",      @"showOldUpgradeDialog",         SCIYTGateSwallow);
}

__attribute__((constructor)) static void SCIYTAdGatesRegister(void) {
    SCIYTWhenActive(^{ SCIYTInstallAdGates(); });
}
