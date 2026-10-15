#import "SCITTAdBlock.h"
#import "../../TikTokHeaders.h"
#import "../../Prefs.h"
#import "../../SCILog.h"
#import "../../Diagnostics/SCITTDiagnostics.h"
#import "../Download/SCITTMedia.h"
#import "../Feed/SCITTFeedFilters.h"

///
/// One gate, at the model's own construction, rather than a view hidden after the fact.
///
/// `-isAds` is the server's own mark for a promoted item — read from `AWEAwemeModel`
/// itself, confirmed present in TikTok 46.4.0's own binary rather than guessed. Refusing
/// the object at `-init`/`-initWithDictionary:error:` means an ad is never built into a
/// feed cell in the first place, which is sturdier than hiding a cell afterwards: nothing
/// downstream that reads the feed array ever sees a gap where an ad used to be, because
/// there was never anything there.
///
/// `%orig` still runs first in both hooks. Refusing the object *after* construction,
/// not by skipping construction, is deliberate: `-isAds` cannot be read before the
/// model has actually decoded the dictionary that sets it.
///
/// `isAd`/`isAdItem`/`isAdsOrPseudoAds` are checked the same way, each guarded by its
/// own `-respondsToSelector:` — see TikTokHeaders.h for why those three are held to a
/// lower confirmation bar than `isAds` itself, and why any one of the four is enough
/// to drop the model rather than requiring all four to exist.
///
/// A kept, non-ad model is handed to SCITTMedia so its download URL can be resolved
/// while the model is still alive -- the only point in this whole pipeline that ever
/// sees the real object.
///

static BOOL SCITTModelIsAd(id built) {
    if (!built) return NO;
    if ([built respondsToSelector:@selector(isAds)] && [built isAds]) return YES;
    if ([built respondsToSelector:@selector(isAd)] && [built isAd]) return YES;
    if ([built respondsToSelector:@selector(isAdItem)] && [built isAdItem]) return YES;
    if ([built respondsToSelector:@selector(isAdsOrPseudoAds)] && [built isAdsOrPseudoAds]) return YES;
    return NO;
}

%group AdBlock

%hook AWEAwemeModel

- (instancetype)initWithDictionary:(NSDictionary *)dictionary error:(NSError **)error {
    id built = %orig;
    [SCITTDiagnostics recordModelsSeen:1 droppedAsAds:0];

    // The ad switch, then the two filters that drop a model at this same moment (LIVE items, suggested-account cards): one place that
    // decides what a feed model is allowed to be.
    if (SCIPrefEnabled(SCIPrefHideAds) && SCITTModelIsAd(built)) {
        [SCITTDiagnostics recordModelsSeen:0 droppedAsAds:1];
        return nil;
    }
    if (SCITTModelIsFilteredOut(built)) return nil;

    [SCITTMedia captureModel:built];
    return built;
}

- (instancetype)init {
    id built = %orig;

    // The ad switch, then the two filters that drop a model at this same moment (LIVE items, suggested-account cards): one place that
    // decides what a feed model is allowed to be.
    if (SCIPrefEnabled(SCIPrefHideAds) && SCITTModelIsAd(built)) {
        [SCITTDiagnostics recordModelsSeen:0 droppedAsAds:1];
        return nil;
    }
    if (SCITTModelIsFilteredOut(built)) return nil;

    [SCITTMedia captureModel:built];
    return built;
}

%end

%end


///
/// The splash/launch ad is a separate surface from the feed -- a full-screen interstitial
/// shown before the app is even usable, decided by a manager object rather than built from
/// a model this tweak already refuses. Three class names are hooked because reference
/// tweaks disagree on which one a given TikTok build actually ships; each is guarded by
/// its own `NSClassFromString` check in the installer below, so a name absent from this
/// build simply never attaches rather than failing to compile or crashing at runtime.
///

@interface AWESplashManager : NSObject
@end

@interface BDASplashManager : NSObject
@end

@interface TTAdSplashManager : NSObject
@end

%group Splash

%hook AWESplashManager
- (BOOL)isSplashDisabled { return YES; }
- (BOOL)shouldShowSplash { return NO; }
%end

%hook BDASplashManager
- (BOOL)isSplashDisabled { return YES; }
- (BOOL)shouldShowSplash { return NO; }
%end

%hook TTAdSplashManager
- (BOOL)isSplashDisabled { return YES; }
- (BOOL)shouldShowSplash { return NO; }
%end

%end


void SCITTInstallAdBlock(void) {
    if (NSClassFromString(@"AWEAwemeModel")) {
        %init(AdBlock);
        SCILogV(@"ad filter attached to AWEAwemeModel");
    } else {
        SCILogV(@"AWEAwemeModel is not in this build — no ad filter");
    }

    // Each hook in this group only fires from a class that answers %orig's own
    // selector, so it is safe to %init the whole group even when only one of the
    // three names exists in this build -- the other two simply never attach.
    if (NSClassFromString(@"AWESplashManager") ||
        NSClassFromString(@"BDASplashManager") ||
        NSClassFromString(@"TTAdSplashManager")) {
        %init(Splash);
        SCILogV(@"splash-ad suppression attached");
    } else {
        SCILogV(@"no known splash-ad manager in this build");
    }
}
