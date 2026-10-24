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
/// **There is no launch-ad suppression here, and the code that claimed there was is gone.** A `%group` hooked
/// `-isSplashDisabled` and `-shouldShowSplash` on three splash managers; read against the 46.4.0 and 47.1.0
/// binaries, `AWESplashManager` and `BDASplashManager` declare neither selector and `TTAdSplashManager` is not
/// there at all, so Logos *added* two methods nobody sends to classes that never asked for them. It was
/// "attached" in the log and did nothing in the app. The classes that decide a launch ad are
/// `BDASplashManager` (`-pickModelWithBlock:isWarmStart:`, `-displaySplashOnWindow:`) and
/// `AWESplashManager` (`-tryToShowSplash`); each is on the launch path, where a swallowed call is an app
/// waiting for a finish that never comes, so none is hooked until a device says what refusing it does.
///

void SCITTInstallAdBlock(void) {
    if (NSClassFromString(@"AWEAwemeModel")) {
        %init(AdBlock);
        SCILogV(@"ad filter attached to AWEAwemeModel");
    } else {
        SCILogV(@"AWEAwemeModel is not in this build — no ad filter");
    }
}
