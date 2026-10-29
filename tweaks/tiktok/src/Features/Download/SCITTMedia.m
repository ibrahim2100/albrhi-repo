#import "SCITTMedia.h"
#import "../../Prefs.h"   // SCIPrefEnabled, SCIPrefPhotoDownload
#import "../../TikTokHeaders.h"
#import "../../SCILog.h"
#import <objc/message.h>
#import <objc/runtime.h>

@implementation SCITTMediaItem

/// The first link of each picture — what a caller wants when it only needs to count them or index
/// into them. Derived, never stored, so it cannot disagree with the variants it comes from.
- (NSArray<NSURL *> *)photoURLs {
    NSMutableArray<NSURL *> *first = [NSMutableArray array];
    for (NSArray<NSURL *> *group in self.photoVariants) {
        if (group.firstObject) [first addObject:group.firstObject];
    }
    return first;
}
@end


/// Private: a model whose resolution is still pending, retried on a timer. Not part
/// of the public interface -- SCITTAdBlock.x only ever calls +captureModel:, which
/// calls this itself when the first attempt finds nothing.
@interface SCITTMedia ()
+ (void)watchModel:(AWEAwemeModel *)model;
+ (void)retryPending;
@end


static NSMutableArray<SCITTMediaItem *> *sciRecent = nil;
static NSUInteger const kSCIMediaCap = 30;
static NSString *sciLastAttemptState = nil;

///
/// Successes counted and the winning chain remembered separately from the last
/// attempt, and this distinction cost two releases of fixing the wrong thing.
///
/// `sciLastAttemptState` alone is overwritten by *every* attempt, and the overwhelming
/// majority of attempts are brand-new models a moment after construction whose video
/// data is not populated yet -- so the row read "every chain failed" while the feed
/// button, which only ever appears when a URL has actually been resolved, was visibly
/// appearing. The failing line was the last of two hundred attempts, not the verdict
/// on all of them. A count of successes and the name of the chain that produced them
/// cannot be drowned out that way.
///
static NSUInteger sciResolveSuccesses = 0;
static NSUInteger sciResolveAttempts = 0;
static NSString *sciWinningChain = nil;

/// **The one fact never recorded, and the reason this went round in circles.** A chain
/// name alone says which selectors answered, not *what* they answered with -- and the
/// saved file kept coming back byte-identical (972317 bytes of `audio/mp4`) release
/// after release, which only the URL itself could explain. A music CDN host and a video
/// CDN host are told apart at a glance; "resolved via video.playURL.originURLList" is
/// not. Truncated to host plus the last path component, so it identifies the *kind* of
/// link without putting a signed, account-scoped URL in a report meant to be pasted.
static NSString *sciWinningURLShape = nil;

static void SCITTAddResolvedList(NSArray<NSURL *> *urls);
static void SCITTAddPhotoPost(NSArray<NSArray<NSURL *> *> *photos, NSURL *audio);

static NSString *SCITTURLShape(NSURL *url) {
    if (!url) return @"nil";
    return [NSString stringWithFormat:@"%@/…/%@",
        url.host ?: @"?", url.lastPathComponent ?: @"?"];
}

@implementation SCITTMedia

/// A value however TikTok's own accessor hands it back, turned into a URL without
/// assuming which shape it is -- `AWEURLModel -bestURLtoDownload` is confirmed to
/// exist and to be called by two reference tweaks; what type it actually returns on
/// this build is not, so both plausible shapes are read rather than one being trusted.
static NSURL *SCITTURLFromValue(id value) {
    if (!value) return nil;
    if ([value isKindOfClass:[NSURL class]]) return value;
    if ([value isKindOfClass:[NSString class]]) return [NSURL URLWithString:value];
    // A list of URLs/strings (several candidate chains from the live property dump
    // end in one, e.g. -URLList) -- the first entry is the same choice this project's
    // other "several plausible sources" pickers make elsewhere.
    if ([value isKindOfClass:[NSArray class]]) {
        for (id entry in (NSArray *)value) {
            NSURL *url = SCITTURLFromValue(entry);
            if (url) return url;
        }
    }
    return nil;
}

/// Sends `name` to `obj` if it answers, guarded the same way every step in this file
/// already is. `outFailure` is set to why it did not, only when it did not.
static id SCITTTry(id obj, NSString *name, NSString **outFailure) {
    if (!obj) {
        if (outFailure) *outFailure = @"nil object";
        return nil;
    }
    SEL selector = NSSelectorFromString(name);
    if (![obj respondsToSelector:selector]) {
        if (outFailure) *outFailure = [NSString stringWithFormat:
            @"%@ has no -%@", NSStringFromClass([obj class]), name];
        return nil;
    }
    id result = ((id (*)(id, SEL))objc_msgSend)(obj, selector);
    if (!result && outFailure) {
        *outFailure = [NSString stringWithFormat:@"-%@ answered nil", name];
    }
    return result;
}

/// Walks `model` through one candidate chain of selector names, converting the last
/// step's answer to a URL. Returns nil and fills `outFailure` on the step that stopped
/// it -- never a guess past a step that did not answer.
// Declared ahead of use: the photo resolver below needs it and it is defined further down,
// beside the URL helpers it belongs with. A flag used above its own definition is what
// check.py's rule caught in the panel yesterday, and C does not care that two things belong
// together.
static BOOL SCITTURLLooksDownloadable(NSURL *url);

///
/// Every picture of a photo post, in order, or nil for an ordinary video.
///
/// A TikTok photo post carries its pictures on the aweme model, not on the video model:
/// `imagePostInfo` holds them, and `images` / `imageList` are the two names the list itself
/// answers to. All four are confirmed in TikTok 46.4.0's own binary, and each entry is a URL
/// model read exactly like every other one here -- `originURLList`, then `urlList`, then
/// `URLList`.
///
/// **Order matters and the first entry is not enough.** Every other resolver in this file
/// looks for one link and stops; a photo post is six or eight separate pictures, and taking
/// the first would save one and look like it worked. So this collects all of them and the
/// caller saves the lot.
///
/// Read defensively at every step, the same as the URL chains: a name that does not answer is
/// stepped over rather than assumed, because the accessor list says a name exists somewhere
/// and never says on what.
/// The index the photo album is showing, recorded alongside the URLs it resolved.
static NSUInteger sciPhotoIndex = NSNotFound;

/// Every step of the photo chain, recorded as it is walked.
///
/// A photo post that saves one picture of several loses the others at exactly one of these steps,
/// and a count of what was saved cannot say which. Written here rather than assembled later, so the
/// report describes the walk that actually happened.
static NSString *sciPhotoHolder = nil;
static NSString *sciPhotoListVia = nil;
static NSString *sciPhotoElement = nil;
static NSUInteger sciPhotoListCount = 0;
static NSUInteger sciPhotoResolved = 0;
static NSUInteger sciPhotoVariantCount = 0;

/// Whether the app's own VVIC-replacement flag was there to ask. A build without it is a different
/// finding from a build that has it and answers with the same links.
static BOOL sciPhotoVVICAsked = NO;

/// Which accessor produced each link, one inner array per picture, built in the same pass as the
/// links themselves.
static NSMutableArray<NSArray<NSString *> *> *sciPhotoOrigins = nil;

/// Link -> the accessor that produced it.
///
/// A dictionary rather than a second array walked alongside the first: this project has already
/// shipped labels that named the *previous* link, because two lists were kept in step by hand and
/// one of them was inserted into. A key cannot drift from its own value.
static NSMutableDictionary<NSString *, NSString *> *sciPhotoOriginByURL = nil;

static void SCITTRecordPhotoOrigin(NSURL *url, NSString *origin) {
    if (!url.absoluteString.length || !origin.length) return;
    if (!sciPhotoOriginByURL) sciPhotoOriginByURL = [NSMutableDictionary dictionary];
    sciPhotoOriginByURL[url.absoluteString] = origin;
}

/// Where the live index came from, or why it did not.
static NSString *sciPhotoIndexVia = nil;

///
/// The links this URL model gives when it is asked for something other than VVIC.
///
/// `needReplaceVVICFormat` is TikTok's own property, so this is the app's mechanism rather than a
/// guess about one -- and it is read exactly the way every other private accessor here is: only if
/// the object answers, with the setter's own encoding (`v20@0:8B16`) matched by the cast.
///
/// **The flag is restored before returning.** The model belongs to TikTok and drives what the app
/// requests for its own display; a borrowed value that is never given back is a change to the app's
/// behaviour that outlives the save it was borrowed for.
static NSArray<NSURL *> *SCITTVVICReplacementURLs(id urlModel) {
    SEL getter = NSSelectorFromString(@"needReplaceVVICFormat");
    SEL setter = NSSelectorFromString(@"setNeedReplaceVVICFormat:");
    if (![urlModel respondsToSelector:getter] || ![urlModel respondsToSelector:setter]) return @[];

    BOOL original = ((BOOL (*)(id, SEL))objc_msgSend)(urlModel, getter);
    ((void (*)(id, SEL, BOOL))objc_msgSend)(urlModel, setter, YES);

    NSMutableArray<NSURL *> *out = [NSMutableArray array];
    for (NSString *name in @[@"originURLList", @"URLList", @"urlList"]) {
        SEL selector = NSSelectorFromString(name);
        if (![urlModel respondsToSelector:selector]) continue;

        NSURL *url = SCITTURLFromValue(((id (*)(id, SEL))objc_msgSend)(urlModel, selector));
        if (url && SCITTURLLooksDownloadable(url) && ![out containsObject:url]) [out addObject:url];
    }

    ((void (*)(id, SEL, BOOL))objc_msgSend)(urlModel, setter, original);
    sciPhotoVVICAsked = YES;
    return out;
}

///
/// The same picture asked for in a format the phone can read, by rewriting the CDN's own template.
///
/// **A guess, appended last, and never trusted without decoding it.** TikTok served a picture as
/// `..._photomode_vvic_vqe2_cae_v1~tplv-photomode-offline.image` — a VVC still, which iOS has no
/// decoder for. Everything after `~` in a ByteDance image URL is a processing template the CDN
/// applies on the way out, so asking the same object for a JPEG is a request the server may simply
/// honour. It may equally ignore it and hand back the same bytes, which is why these sit *after*
/// every link the model itself offered and are read like any other candidate: decoded before they
/// are offered to Photos, and named in the report when they are what worked.
///
/// This is the same shape as the external-HD switch's own rule — a guess is allowed when the thing
/// it produces is measured rather than assumed — and unlike that one it costs no privacy: it is the
/// same host, the same object, one query string away.
static NSArray<NSURL *> *SCITTRewrittenPictureURLs(NSURL *url) {
    NSString *text = url.absoluteString;
    NSRange marker = [text rangeOfString:@"~tplv-" options:NSBackwardsSearch];
    if (marker.location == NSNotFound) return @[];

    NSString *stem = [text substringToIndex:marker.location];
    NSMutableArray<NSURL *> *out = [NSMutableArray array];

    for (NSString *suffix in @[@"~tplv-photomode-image.jpeg", @"", @"~tplv-photomode-image.heic"]) {
        NSURL *rewritten = [NSURL URLWithString:[stem stringByAppendingString:suffix]];
        if (rewritten && ![rewritten isEqual:url]) [out addObject:rewritten];
    }

    return out;
}

static NSArray<NSArray<NSURL *> *> *SCITTPhotoURLsFromModel(id model) {
    if (!model) return nil;

    id holder = model;

    // `AWEAwemeModel` answers `-images` itself -- it has no `imagePostInfo` in this build at
    // all, which is why 0.13.0 found nothing. The wrapper is still tried first because a
    // build that does have one would put the list inside it, and asking costs a
    // -respondsToSelector: that already answers NO here.
    for (NSString *wrapper in @[@"imagePostInfo", @"photoAlbum"]) {
        SEL info = NSSelectorFromString(wrapper);
        if (![model respondsToSelector:info]) continue;
        id posted = ((id (*)(id, SEL))objc_msgSend)(model, info);
        if (posted) { holder = posted; break; }
    }

    // `photos` first: a photo post in this build is an `AWEPhotoAlbumModel` reached through
    // `-photoAlbum`, and its list is called `photos`. 0.13.1 reached the album correctly and
    // then asked it for `images`, which is the *other* container's name -- so the wrapper was
    // right, the list accessor was not, and the post read as empty for a second release.
    // `currentIndex` is a declared property on AWEPhotoAlbumModel and is how the app itself
    // knows which picture the swipe is on. Read here, beside the list it indexes into, so the
    // two can never disagree about which post they describe.
    sciPhotoIndex = NSNotFound;
    NSString *chainHolder = NSStringFromClass([holder class]);
    NSString *chainVia = nil;
    SEL current = NSSelectorFromString(@"currentIndex");
    if (holder != model && [holder respondsToSelector:current]) {
        NSInteger index = ((NSInteger (*)(id, SEL))objc_msgSend)(holder, current);
        if (index >= 0) sciPhotoIndex = (NSUInteger)index;
    }

    NSArray *list = nil;
    for (NSString *name in @[@"photos", @"images", @"imageList", @"displayImageList"]) {
        SEL selector = NSSelectorFromString(name);
        if (![holder respondsToSelector:selector]) continue;

        id value = ((id (*)(id, SEL))objc_msgSend)(holder, selector);
        if ([value isKindOfClass:[NSArray class]] && [(NSArray *)value count]) {
            list = value;
            chainVia = name;
            break;
        }
    }
    if (!list.count) return nil;

    NSMutableArray<NSArray<NSURL *> *> *groups = [NSMutableArray array];
    sciPhotoOrigins = [NSMutableArray array];

    for (id entry in list) {
        // **Every accessor, not the first that answers.** The loop below used to stop at the first
        // non-nil URL model and take one link from it; a device report then came back with a VVC
        // still (`ISO media (vvic)`) that iOS cannot decode at all, and there was nothing behind it
        // to try. `AWEPhotoAlbumPhoto` offers the same picture several ways, so all of them are
        // collected in preference order and the saver takes the first whose bytes actually read.
        NSMutableArray<NSURL *> *variants = [NSMutableArray array];
        NSMutableArray<NSString *> *origins = [NSMutableArray array];

        // An `AWEImageModel` is not a URL model and answers none of the list accessors below.
        // It holds three of them -- one per appearance -- and the light one is the picture as
        // posted. `displayImage` was tried in 0.13.0 and is on no class here; every image then
        // fell through to the list accessors on the wrong object and the post looked empty.
        // Two element classes, one per container, and their URL accessors share no names.
        //
        // `AWEPhotoAlbumPhoto` (from `photoAlbum.photos`) carries the picture at four
        // qualities; `originPhotoURL` is the one as posted, and the thumbnail is last because
        // saving a preview instead of a photo is the same class of mistake as saving SD.
        // `AWEImageModel` (from `-images`) instead names its by appearance.
        //
        // **Every clean copy before any watermarked one, and that is a correction.**
        //
        // The list used to read origin, owner-watermarked, user-watermarked, dynamic, … because it
        // was written when only the *first* entry was ever used: whatever came second was a
        // fallback nobody reached. Now that the saver walks the whole list until something decodes,
        // the order is the decision -- and a post whose original is an undecodable VVIC still fell
        // straight through to the watermarked copy and saved that. Reported from a device as
        // "it saves, but with a watermark", which is exactly what this order asked for.
        //
        // So the watermarked pair moved behind every clean variant, including the thumbnail. A
        // thumbnail is small and this project's own rule says a preview is not a photo -- but a
        // watermark cannot be undone, and the small clean copy is the one a person can still use.
        // The saver names which variant won, so neither outcome is a silent surprise.
        //
        // `photoRankedURLModels` is an *array* of URL models rather than one -- TikTok's own ranked
        // list of the ways this picture is available, read from the class's declared type
        // (`@"NSArray"`) rather than assumed. It sits second because a ranking the app itself
        // publishes is worth more than the order guessed here, and first place stays with the
        // picture as posted.
        for (NSString *inner in @[@"originPhotoURL", @"photoRankedURLModels", @"dynamicImageURL",
                                  @"lightURLModel", @"localURLModel", @"darkURLModel",
                                  @"displayImage", @"thumbnailPhotoURL",
                                  @"ownerWatermarkedPhotoURL", @"userWatermarkedPhotoURL"]) {
            SEL selector = NSSelectorFromString(inner);
            if (![entry respondsToSelector:selector]) continue;
            id resolved = ((id (*)(id, SEL))objc_msgSend)(entry, selector);
            if (!resolved) continue;

            // One accessor answers with a list; the rest answer with a single model. Both are
            // walked the same way below rather than branching twice.
            NSArray *models = [resolved isKindOfClass:[NSArray class]] ? resolved : @[resolved];
            for (id model in models) {

            // `URLList` with that casing is what AWEURLModel declares; the lowercase spelling is
            // kept only because a different build might use it, and it costs one failed question.
            for (NSString *name in @[@"originURLList", @"URLList", @"urlList"]) {
                SEL listSelector = NSSelectorFromString(name);
                if (![model respondsToSelector:listSelector]) continue;

                NSURL *url = SCITTURLFromValue(((id (*)(id, SEL))objc_msgSend)(model, listSelector));
                if (url && SCITTURLLooksDownloadable(url) && ![variants containsObject:url]) {
                    [variants addObject:url];
                    [origins addObject:inner];
                    SCITTRecordPhotoOrigin(url, inner);
                }
                break;
            }

            //
            // **TikTok has its own answer to the unreadable format, and it is a property on this
            // very object.** `AWEURLModel` declares `needReplaceVVICFormat` (`B16@0:8`, with
            // `-setNeedReplaceVVICFormat:` as `v20@0:8B16`) -- the app's own flag for "hand me this
            // picture in something other than VVIC". Whatever the guessed template rewrite below
            // might achieve, this is the mechanism the app itself uses, which makes it the one to
            // ask first.
            //
            // Set, read, **and put back**. This is TikTok's object, not ours: it decides its own
            // requests from that flag, and leaving it flipped would change what the app fetches for
            // its own display long after the save is over. Borrowing a value is fine; keeping it is
            // not.
            //
            for (NSURL *replaced in SCITTVVICReplacementURLs(model)) {
                if (![variants containsObject:replaced]) {
                    [variants addObject:replaced];
                    NSString *label = [inner stringByAppendingString:@" (VVIC replaced)"];
                    [origins addObject:label];
                    SCITTRecordPhotoOrigin(replaced, label);
                }
            }
            }  // models
        }

        // The rewrites go after everything the model offered, for every variant, so a post whose
        // links are *all* in a format this phone cannot read still has somewhere to go.
        for (NSURL *known in [variants copy]) {
            for (NSURL *rewritten in SCITTRewrittenPictureURLs(known)) {
                if (![variants containsObject:rewritten]) {
                    [variants addObject:rewritten];
                    [origins addObject:@"template rewrite"];
                    SCITTRecordPhotoOrigin(rewritten, @"template rewrite");
                }
            }
        }

        // Origins are recorded beside the links, in one pass, never matched up afterwards by
        // value -- the parallel-array mistake this project has already made once, when every
        // link label named the accessor of the link before it.
        if (variants.count) [sciPhotoOrigins addObject:origins];

        if (variants.count) [groups addObject:variants];
    }

    if (!groups.count) return nil;

    // **Committed only on success, and that is a correction to the first version of this
    // diagnostic.** These are written by every model the resolver walks, and virtually all of them
    // are ordinary videos with no album at all -- so a report read one line built from several
    // different calls: `AWEAwemeModel → photos ×0 (empty) → 6 link(s)`, which describes nothing that
    // ever happened. A record of the last *successful* chain is one call's worth of truth.
    sciPhotoHolder = chainHolder;
    sciPhotoListVia = chainVia;
    sciPhotoListCount = list.count;
    sciPhotoElement = NSStringFromClass([list.firstObject class]);
    // `groups.count`, read plainly. This was a KVC collection operator over an array of arrays
    // and reported **zero pictures** on a post that had just saved one -- a diagnostic disagreeing
    // with the thing it describes, which this file has now been bitten by three times.
    sciPhotoResolved = groups.count;

    // How many ways the shown picture is offered, which is the number that says whether a
    // failed save had anywhere left to go.
    sciPhotoVariantCount = 0;
    for (NSArray<NSURL *> *group in groups) {
        if (group.count > sciPhotoVariantCount) sciPhotoVariantCount = group.count;
    }

    return groups;
}

///
/// Reads `-bitRate` without guessing its type.
///
/// **This is what crashed the app in 0.12.0.** It was read through `objc_msgSend` cast to
/// `long long`. A framework selector dump gives *names, not signatures*, so nothing there says
/// whether the property is an integer, a double or an `NSNumber *` -- and the wrong cast is
/// undefined behaviour, not a wrong number: the value arrives in a different register, or a
/// pointer is read as an integer.
///
/// So the type is asked for at runtime rather than assumed. `property_getAttributes` returns
/// an encoding whose first letter after `T` is the type: `q` long long, `i` int, `d` double,
/// `f` float, `@` an object. Each is then read through a cast that matches, and an encoding
/// this does not recognise returns 0 rather than a guess -- a variant that cannot be compared
/// simply loses, which costs quality and never stability.
///
/// A declared integer property, read through the encoding the runtime reports.
///
/// The same discipline `SCITTBitRateOf` uses and for the same reason: 0.12.0 crashed the app by
/// casting a property whose type it had assumed. An encoding this does not recognise returns 0,
/// which costs a line in a report and never a process.
static long long SCITTIntegerOf(id entry, NSString *name) {
    SEL selector = NSSelectorFromString(name);
    if (![entry respondsToSelector:selector]) return 0;

    objc_property_t property = class_getProperty([entry class], name.UTF8String);
    const char *attributes = property ? property_getAttributes(property) : NULL;
    if (!attributes || attributes[0] != 'T') return 0;

    switch (attributes[1]) {
        case 'q': case 'l':
            return ((long long (*)(id, SEL))objc_msgSend)(entry, selector);
        case 'i': case 's': case 'c': case 'B':
            return (long long)((int (*)(id, SEL))objc_msgSend)(entry, selector);
        case 'Q': case 'L': case 'I':
            return (long long)((unsigned long long (*)(id, SEL))objc_msgSend)(entry, selector);
        case 'd':
            return (long long)((double (*)(id, SEL))objc_msgSend)(entry, selector);
        case '@': {
            id boxed = ((id (*)(id, SEL))objc_msgSend)(entry, selector);
            return [boxed respondsToSelector:@selector(longLongValue)] ? [boxed longLongValue] : 0;
        }
        default:
            return 0;
    }
}

static double SCITTBitRateOf(id entry) {
    if (!entry) return 0;

    // `bitrate`, not `bitRate` -- and this cost 0.13.0 the whole feature.
    //
    // The entries in `-bitrateModels` are `AWEVideoBSModel`, whose own method list (read out
    // of MusicallyCore's class metadata, not out of a framework-wide name dump) says
    // `bitrate`, all lowercase. `bitRate` belongs to a *different* class in this same binary,
    // `TTKECVideoBitModel`, which is nowhere near the feed -- so the name existed, answered a
    // string search, and was on the wrong object. Exactly the shape of `downloadinfoModel`'s
    // capital I and of `downloadAddr` before it.
    //
    // Both are tried, in the order this build actually uses, and the one the object answers
    // is the one whose type is then read.
    NSString *name = nil;
    SEL selector = NULL;
    for (NSString *candidate in @[@"bitrate", @"bitRate"]) {
        SEL trial = NSSelectorFromString(candidate);
        if (![entry respondsToSelector:trial]) continue;
        name = candidate;
        selector = trial;
        break;
    }
    if (!selector) return 0;

    objc_property_t property = class_getProperty([entry class], name.UTF8String);
    const char *attributes = property ? property_getAttributes(property) : NULL;

    // No property entry means a plain method, whose type this cannot read either. Treated as
    // unknown for the same reason: not comparing is a worse download, and guessing is a crash.
    if (!attributes || attributes[0] != 'T') return 0;

    switch (attributes[1]) {
        case 'q': case 'l':
            return (double)((long long (*)(id, SEL))objc_msgSend)(entry, selector);
        case 'i': case 's':
            return (double)((int (*)(id, SEL))objc_msgSend)(entry, selector);
        case 'Q': case 'L': case 'I':
            return (double)((unsigned long long (*)(id, SEL))objc_msgSend)(entry, selector);
        case 'd':
            return ((double (*)(id, SEL))objc_msgSend)(entry, selector);
        case 'f':
            return (double)((float (*)(id, SEL))objc_msgSend)(entry, selector);
        case '@': {
            id boxed = ((id (*)(id, SEL))objc_msgSend)(entry, selector);
            return [boxed respondsToSelector:@selector(doubleValue)] ? [boxed doubleValue] : 0;
        }
        default:
            return 0;
    }
}

///
/// The highest-bitrate variant TikTok offers for this video, or nil.
///
/// **A chain of named accessors cannot answer this.** Every other resolver here walks a path
/// and takes the first thing it finds; `bitrateModels` is a list of *alternatives* and the
/// right one is chosen by comparing them. Taking `firstObject` yields whichever gear TikTok
/// listed first, which is the SD copy as often as not -- and that is why downloads were SD
/// while every chain reported success.
///
/// Each entry carries `-bitRate`, `-gearName`, `-qualityType` and its own `-playAddr`, all
/// four confirmed in TikTok 46.4.0's binary. The address is a URL model like any other.
///
/// **Only ever called for a settled model** -- see `+captureSettledModel:`. Walking a list of
/// sub-objects off a model still inside its own `-init` is the other half of what 0.12.0 got
/// wrong, and no amount of type safety fixes that one.
///
/// Every gear the last settled video offered, newest first.
///
/// **"Is 720 the highest TikTok has" is not a question this code can answer by reasoning.** It
/// is a fact about one video on one account, and the only place it exists is the ladder the app
/// itself was handed. So the ladder is recorded verbatim -- each gear's own `gearName`, which
/// encodes the resolution, beside its bitrate, with the chosen one marked -- and the settings
/// screen prints it. A report then says what was available, not just what was taken, which is
/// the difference between "the picker chose wrong" and "there was nothing better".
static NSString *sciGearLadder = nil;

static NSURL *SCITTBestBitrateURL(id videoModel, NSString **outVia) {
    if (!videoModel) return nil;

    // Three ladders, not one. `AWEVideoModel` declares `bitrateModels`, `SDRBitrateModels`
    // and `HDRBitrateModels` -- all three confirmed properties -- and only the first was ever
    // read. A gear missing from one list is not a gear the app does not have, so they are
    // gathered together and compared as a single ladder; whichever list the winner came from
    // is named in the report.
    NSMutableArray *list = [NSMutableArray array];
    NSMutableArray<NSString *> *sources = [NSMutableArray array];

    // **The playback ladder first, because `bitrateModels` is not it.**
    //
    // A device probe put the two side by side and they carry the *same gear names at four
    // times the bitrate*: `adapt_lower_720_1` reads 373,349 through `bitrateModels` and
    // 1,512,265 in the list TikTok hands its own picker. So every download so far has taken a
    // reduced copy of the right gear — which is exactly one cause for both complaints, the
    // picture and the sound, since none of these gears carries a separate audio track.
    //
    // `__playBSModel` and its siblings are where the player's own models live. They are
    // methods rather than declared properties, so nothing states their type: each is asked
    // behind `-respondsToSelector:`, and whatever comes back is accepted only if it looks like
    // a gear list — an array whose members answer `playAddr`. Anything else is stepped over.
    for (NSString *name in @[@"__playBSModel", @"__playBSModelV2", @"awe_playBSModel",
                             @"ttk_playBSModel",
                             @"bitrateModels", @"SDRBitrateModels", @"HDRBitrateModels"]) {
        SEL models = NSSelectorFromString(name);
        if (![videoModel respondsToSelector:models]) continue;

        id value = ((id (*)(id, SEL))objc_msgSend)(videoModel, models);

        // A single gear rather than a list is still a gear.
        if (value && ![value isKindOfClass:[NSArray class]]) {
            value = [value respondsToSelector:NSSelectorFromString(@"playAddr")] ? @[value] : nil;
        }
        if (![value isKindOfClass:[NSArray class]] || ![(NSArray *)value count]) continue;

        id first = [(NSArray *)value firstObject];
        if (![first respondsToSelector:NSSelectorFromString(@"playAddr")]) continue;

        [list addObjectsFromArray:(NSArray *)value];
        [sources addObject:[NSString stringWithFormat:@"%@×%lu",
                            name, (unsigned long)[(NSArray *)value count]]];
    }
    if (!list.count) return nil;

    id best = nil;
    double bestRate = -1;
    NSUInteger bestIndex = NSNotFound;

    NSMutableArray<NSString *> *ladder = [NSMutableArray array];

    for (id entry in (NSArray *)list) {
        double rate = SCITTBitRateOf(entry);

        // `gearName` is a declared NSString property on AWEVideoBSModel and encodes the
        // resolution ("…_720_…"), which is the part of this report a person can read.
        NSString *gear = nil;
        SEL gearSel = NSSelectorFromString(@"gearName");
        if ([entry respondsToSelector:gearSel]) {
            id value = ((id (*)(id, SEL))objc_msgSend)(entry, gearSel);
            if ([value isKindOfClass:[NSString class]]) gear = value;
        }

        // Deduplicated by what the gear *is*, not by object identity.
        //
        // On this build the three lists are identical -- a device report printed the same five
        // gears three times over -- and they are separate objects, so `containsObject:` would
        // not have caught it. A ladder that repeats itself is a report nobody can read, and
        // being read is the whole point of this line.
        // **Frame rate and codec, beside the bitrate — because the owner noticed the saved
        // clips sit under 30 fps and neither the gear name nor the byte count says a word about
        // it.** Both are declared properties on `AWEVideoBSModel` (`fps : q`, `isBytevc1 : q`),
        // so this is a plain read, not a guess: `SCITTIntegerOf` asks the runtime for the real
        // encoding first, exactly as the bitrate read does, and answers 0 for anything it cannot
        // type rather than inventing a cast. If the ladder turns out to hold a 60 fps gear we are
        // not taking, that is the next fix; if every gear is 30, the source is 30 and there is
        // nothing here to win.
        long long fps = SCITTIntegerOf(entry, @"fps");
        long long hevc = SCITTIntegerOf(entry, @"isBytevc1");

        NSString *label = [NSString stringWithFormat:@"%@ @ %.0f%@%@",
                           gear ?: NSStringFromClass([entry class]), rate,
                           fps > 0 ? [NSString stringWithFormat:@", %lldfps", fps] : @"",
                           hevc > 0 ? @", hevc" : @", h264"];
        if ([ladder containsObject:label]) {
            if (rate > bestRate) { bestRate = rate; best = entry; }
            continue;
        }
        [ladder addObject:label];

        if (rate > bestRate) {
            bestRate = rate;
            best = entry;
            bestIndex = ladder.count - 1;   // the label just appended
        }
    }

    sciGearLadder = [NSString stringWithFormat:@"%lu gear(s) from %@: %@ — took %@",
                     (unsigned long)ladder.count,
                     [sources componentsJoinedByString:@" + "],
                     [ladder componentsJoinedByString:@", "],
                     bestIndex == NSNotFound ? @"none" : ladder[bestIndex]];

    // Every variant answered 0 -- an unreadable type, or a list of something else entirely.
    // Falling through to the ordinary chains is right: they already produce a working file.
    if (!best || bestRate <= 0) return nil;

    // `AWEVideoBSModel` carries both: `playAddr`, an AWEURLModel, and `playURLList`, the
    // plain array. Either answers the question, so whichever this build populated is used.
    id urlModel = nil;
    for (NSString *addr in @[@"playAddr", @"playURLList"]) {
        SEL selector = NSSelectorFromString(addr);
        if (![best respondsToSelector:selector]) continue;
        id value = ((id (*)(id, SEL))objc_msgSend)(best, selector);
        if (!value) continue;

        // An array here is already the list; anything else is a URL model to ask.
        if ([value isKindOfClass:[NSArray class]]) {
            NSURL *url = SCITTURLFromValue(value);
            if (url && SCITTURLLooksDownloadable(url)) {
                if (outVia) {
                    *outVia = [NSString stringWithFormat:@"bitrateModels[%.0f bps].%@",
                               bestRate, addr];
                }
                return url;
            }
            continue;
        }
        urlModel = value;
        break;
    }
    if (!urlModel) return nil;

    for (NSString *name in @[@"originURLList", @"URLList", @"urlList"]) {
        SEL selector = NSSelectorFromString(name);
        if (![urlModel respondsToSelector:selector]) continue;

        NSURL *url = SCITTURLFromValue(((id (*)(id, SEL))objc_msgSend)(urlModel, selector));
        if (!url || !SCITTURLLooksDownloadable(url)) continue;

        if (outVia) {
            *outVia = [NSString stringWithFormat:@"bitrateModels[%.0f bps].playAddr.%@",
                       bestRate, name];
        }
        return url;
    }

    return nil;
}

static NSURL *SCITTResolveChain(id model, NSArray<NSString *> *chain, NSString **outFailure) {
    id current = model;
    for (NSString *step in chain) {
        NSString *failure = nil;
        current = SCITTTry(current, step, &failure);
        if (!current) {
            if (outFailure) *outFailure = failure;
            return nil;
        }
    }
    NSURL *url = SCITTURLFromValue(current);
    if (!url && outFailure) {
        *outFailure = [NSString stringWithFormat:@"chain ended at %@, not a URL or string",
            NSStringFromClass([current class])];
    }
    return url;
}

/// `playURIString` answering a real object was the first chain to ever "resolve" --
/// and the download that followed it failed outright, which a plain HTTP or HTTPS
/// check would have caught before ever reaching the downloader. `NSURL URLWithString:`
/// happily builds a URL object out of an internal resource identifier that is not a
/// fetchable link at all -- this app almost certainly carries its own custom scheme or
/// a bare opaque ID for exactly this property, the same way `AVFoundation` names
/// carry `avkit_`/`_ttvideoengine_` prefixes on this same class. Treated as a failed
/// step rather than a success, so the resolver moves on to try the next chain instead
/// of handing the downloader something it can never fetch.
static BOOL SCITTURLLooksDownloadable(NSURL *url) {
    NSString *scheme = url.scheme.lowercaseString;
    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) return NO;

    // The music is never the answer, and it was getting in as a candidate.
    //
    // A report showed the recorded link as `sf77-ies-music-sg.tiktokcdn.com/….mp3` -- the
    // sound, not the video. Ordering by measured type catches it before the save, but a
    // candidate that is audio by its own address should never have been on the list: it makes
    // the diagnostics lie about what was resolved, and it is one HEAD request wasted proving
    // what the URL already said.
    NSString *extension = url.pathExtension.lowercaseString;
    if ([@[@"mp3", @"m4a", @"aac", @"wav"] containsObject:extension]) return NO;
    if ([url.host.lowercaseString containsString:@"-music-"]) return NO;

    return YES;
}

+ (NSURL *)resolveURLForModel:(AWEAwemeModel *)model {
    if (!model) return nil;

    @try {
        // The aweme model is now only a fallback -- `SCITTCapture.x` hooks
        // `AWEVideoModel` directly, because `-video` here is nil for nearly every
        // model at construction time. What is left are the same confirmed-sent
        // selectors `+captureVideoModel:` uses, reached one hop further out through
        // `-video` (sent by both reference tweaks) for the cases where it *is*
        // populated by the time a retry runs.
        //
        // `-playURIString` and `-URLList` are **not** absent -- a live property dump from a
        // device lists both. They were dropped for resolving the wrong thing, which is a
        // different fact and worth stating correctly:
        // `URLList` resolved 288 times of 706 and the file it produced was 972 KB of
        // `audio/mp4` with no video track at all. It is the *sound's* URL list. Every
        // one of those "successes" was the music, which is worse than resolving
        // nothing. `-playURIString` was already rejected for answering a non-http(s)
        // link. `-h264URL` and `-downloadURL` were invented here and are gone too:
        // neither tweak sends them and neither binary carries them as strings.
        NSArray<NSArray<NSString *> *> *chains = @[
            // What actually exists in TikTok 46.4.0, read from the app's own binary.
            //
            // Every selector below was confirmed by dumping __objc_methname out of
            // MusicallyCore.framework -- 785 MB and 1,032,816 selectors, which is where
            // TikTok's classes live; its main executable is 91 KB and holds none of them,
            // the same way X's do not live in X's binary.
            //
            // **That dump also deleted three assumptions.** `bestURLtoDownload` is not in
            // this build at all, and it was the first choice of nearly every chain here --
            // so most of this list has been dead for as long as it has existed.
            // `bitratePlayURL`, `bestURLtoDownloadFormat` and `downloadHDVideo:` are absent
            // too; they came from NA9's binary, which was built against an older TikTok, and
            // reading a working tweak's selectors is not the same as confirming they are in
            // *your* build. That is the same trap the X tweak's dead immersive class was.
            //
            // The real quality ladder, in order:
            //
            //   `bitrateModels`  a list of variants, each with -bitRate, -gearName,
            //                    -qualityType and its own -playAddr. This is where HD is.
            //   `downloadAddr`   the *download* address, which is not `playAddr`: TikTok
            //                    serves playback at a bitrate chosen for smooth streaming.
            //                    "It saves SD" was this distinction all along.
            //   `playAddrH264`   an explicit codec-named address, ahead of the generic one.
            //
            // Each ends in a URL model, whose confirmed accessors are `originURLList`,
            // `urlList` and `URLList` -- not `bestURLtoDownload`, which does not exist.
            // AWEVideoModel's real accessors, dumped from the device at last.
            //
            // `downloadAddr` -- guessed at twice, from NA9's binary and from a global
            // selector dump -- **is not on this class**. A framework-wide selector list says
            // a name exists somewhere in 785 MB; it never says on what. The device printed
            // the class's own list and settled it in one line.
            //
            // What is there, in the order that matters:
            //
            //   downloadNoWatermarkURL   download quality, no watermark
            //   downloadURL              download quality
            //   h264DownloadURL          codec-named download
            //   bitrateModels            the HD ladder (also HDR/SDR variants)
            //   playURL                  the *streaming* URL -- what we had been using
            //   playLowBitURL            named for exactly what it is
            //
            // And `audioBitrateModels` sits right beside them, which is the shape of the
            // "972317 bytes of audio/mp4" this has been saving: the model carries separate
            // audio lists, and a URL picked without regard to which list it came from can
            // easily be the sound.
            @[@"video", @"downloadNoWatermarkURL", @"originURLList"],
            @[@"video", @"downloadNoWatermarkURL", @"urlList"],
            @[@"video", @"downloadNoWatermarkURL", @"URLList"],

            @[@"video", @"downloadURL", @"originURLList"],
            @[@"video", @"downloadURL", @"urlList"],
            @[@"video", @"downloadURL", @"URLList"],

            @[@"video", @"playURL", @"originURLList"],
            @[@"video", @"playURL", @"urlList"],
            @[@"video", @"h264DownloadURL"],
            @[@"video", @"h264DownloadURL", @"originURLList"],
            @[@"video", @"playURLList", @"originURLList"],
            @[@"video", @"playURLList", @"urlList"],
            @[@"video", @"originURLList"],
            // downloadInfoModel, with a capital I.
            //
            // These two read `downloadinfoModel` for as long as they have existed, and a
            // live property dump from a device settles it: the accessor is
            // `downloadInfoModel`. Selectors are case-sensitive, so both lines were dead --
            // -respondsToSelector: answered NO every time and the chain moved on without
            // ever asking the one object on the model whose entire purpose is download
            // information.
            @[@"downloadInfoModel", @"originURLList"],
        ];

        sciResolveAttempts++;

        // **Every chain is run, not just up to the first that answers.** One chain
        // resolving is not the same as it resolving the video: `originURLList` answered
        // reliably for several releases and every file it produced was `audio/mp4` with
        // no video track. Collecting all of them gives the downloader something to fall
        // back to, and the file itself gets to pick the winner.
        NSMutableArray<NSURL *> *found = [NSMutableArray array];
        NSMutableArray<NSString *> *failures = [NSMutableArray array];

        for (NSArray<NSString *> *chain in chains) {
            NSString *failure = nil;
            NSURL *url = SCITTResolveChain(model, chain, &failure);
            if (url && !SCITTURLLooksDownloadable(url)) {
                failure = [NSString stringWithFormat:@"non-http(s) (%@)",
                    url.scheme ?: @"no scheme"];
                url = nil;
            }
            if (url) {
                if (![found containsObject:url]) [found addObject:url];
                if (!sciWinningChain) {
                    sciWinningChain = [chain componentsJoinedByString:@"."];
                    sciWinningURLShape = SCITTURLShape(url);
                }
                continue;
            }
            [failures addObject:[NSString stringWithFormat:@"%@: %@",
                [chain componentsJoinedByString:@"."], failure ?: @"?"]];
        }

        if (found.count) {
            sciResolveSuccesses++;
            sciLastAttemptState = [NSString stringWithFormat:@"%lu candidate link(s)",
                (unsigned long)found.count];
            SCITTAddResolvedList(found);
            return found.firstObject;
        }

        sciLastAttemptState = [NSString stringWithFormat:@"every chain failed — %@",
            [failures componentsJoinedByString:@" | "]];
        return nil;
    } @catch (NSException *exception) {
        sciLastAttemptState = [NSString stringWithFormat:@"threw: %@", exception.reason ?: @"?"];
        SCILogV(@"media resolve: %@", exception.reason);
        return nil;
    }
}

/// The post id belonging to the links about to be recorded.
static NSString *sciPendingItemID = nil;

/// The publish date, handed over the same way the id and the origins are.
///
/// **Set where the model is in scope, read where the item is built** -- this file already works
/// that way, and the first attempt at this feature put the read in the builder instead, where
/// `model` does not exist. The compiler said so immediately; inventing a second route for one
/// value is what would have been worth avoiding.
static NSDate *sciPendingPosted = nil;
static NSString *sciPendingStats = nil;

/// Counted separately, because "no date appeared" was true for four different reasons and one
/// number could not say which. Same shape as the stamp counters in Albrhi Watch, which turned a
/// silent zero into a sentence naming the stage that stopped.
static NSUInteger sciDateReads = 0;
static NSUInteger sciDateMisses = 0;

/// Which accessor produced each of the links about to be recorded.
static NSArray<NSString *> *sciPendingOrigins = nil;

static void SCITTAddResolvedList(NSArray<NSURL *> *urls) {
    if (!urls.count) return;
    if (!sciRecent) sciRecent = [NSMutableArray array];

    NSURL *primary = urls.firstObject;

    // Same video seen twice -- a recycled cell rebound, a scroll back up -- moves
    // to the front rather than duplicating.
    for (SCITTMediaItem *existing in [sciRecent copy]) {
        if ([existing.url isEqual:primary]) [sciRecent removeObject:existing];
    }

    SCITTMediaItem *item = [[SCITTMediaItem alloc] init];
    item.url = primary;
    item.candidates = urls;
    item.itemID = sciPendingItemID;

    item.posted = sciPendingPosted;
    item.stats = sciPendingStats;
    item.candidateOrigins = sciPendingOrigins;
    item.seen = [NSDate date];
    [sciRecent insertObject:item atIndex:0];

    while (sciRecent.count > kSCIMediaCap) [sciRecent removeLastObject];
}

/// A photo post: its own entry, holding every picture.
///
/// Deliberately not folded into SCITTAddResolvedList. That function treats its array as
/// *alternative links to one file* -- it takes `firstObject` as the primary and keeps the
/// rest as fallbacks -- and a six-picture post handed to it would save one picture and record
/// a success. Different meaning, different door.
///
/// The post's own sound, resolved the same guarded way every other chain here is.
///
/// `AWEAwemeModel.music : AWEMusicModel` and `AWEMusicModel.playURL : AWEURLModel` are both read
/// from this build's own class metadata rather than from a name that appears somewhere in the
/// framework -- the distinction that cost this project three releases. `addedSoundMusicInfo` is
/// tried second because a post can carry a sound added after the fact, which is the one the app
/// plays when it is there.
static NSURL *SCITTAudioURLFromModel(id model) {
    if (!model) return nil;

    for (NSString *name in @[@"music", @"addedSoundMusicInfo"]) {
        SEL selector = NSSelectorFromString(name);
        if (![model respondsToSelector:selector]) continue;

        id music = ((id (*)(id, SEL))objc_msgSend)(model, selector);
        if (!music) continue;

        for (NSString *link in @[@"playURL", @"fullSongPlayURL"]) {
            SEL linkSel = NSSelectorFromString(link);
            if (![music respondsToSelector:linkSel]) continue;

            id urlModel = ((id (*)(id, SEL))objc_msgSend)(music, linkSel);
            if (!urlModel) continue;

            for (NSString *listName in @[@"originURLList", @"URLList", @"urlList"]) {
                SEL listSel = NSSelectorFromString(listName);
                if (![urlModel respondsToSelector:listSel]) continue;

                NSURL *url = SCITTURLFromValue(((id (*)(id, SEL))objc_msgSend)(urlModel, listSel));
                if (url) return url;
            }
        }
    }

    return nil;
}

//
// **One reader, called from every entry that builds an item -- which is two, and only one of them
// had it.**
//
// `+captureModel:` builds photo posts too, from the model's own `-init`, and it never set this at
// all: a photo post arriving through that door would have taken whatever date the last *settled*
// video left behind. Not a missing date -- a confidently wrong one, which is worse and is exactly
// the failure mode a pending global has every time it is set in fewer places than it is read.
//
// Cleared first, so a model that cannot answer leaves nothing rather than the previous answer.
//
/// A two-letter country code as the flag it draws (regional-indicator letters), or the code itself when it is not two letters.
static NSString *SCITTFlagFor(NSString *code) {
    if (code.length != 2) return code;
    NSMutableString *flag = [NSMutableString string];
    for (NSUInteger i = 0; i < 2; i++) {
        unichar c = [[code uppercaseString] characterAtIndex:i];
        if (c < 'A' || c > 'Z') return code;
        uint32_t scalar = 0x1F1E6 + (c - 'A');
        [flag appendString:[[NSString alloc] initWithBytes:&scalar length:4 encoding:NSUTF32LittleEndianStringEncoding]];
    }
    return flag;
}

/// The video's region as a flag, from `-region` (confirmed on 46.4.0). Never throws a missing selector. (The like count that used to be read
/// beside it was removed on the owner's word: nothing here reads `-statistics` any more.)
static void SCITTCaptureStats(id model) {
    sciPendingStats = nil;
    if (!model) return;

    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    SEL regionSel = NSSelectorFromString(@"region");
    id region = [model respondsToSelector:regionSel] ? ((id (*)(id, SEL))objc_msgSend)(model, regionSel) : nil;
    if ([region isKindOfClass:[NSString class]] && [region length]) [parts addObject:SCITTFlagFor(region)];

    sciPendingStats = parts.count ? [parts componentsJoinedByString:@"  "] : nil;
}

static void SCITTCapturePostedDate(id model) {
    sciPendingPosted = nil;
    SCITTCaptureStats(model);
    if (!model) return;

    SEL createdSel = NSSelectorFromString(@"createTime");
    id created = [model respondsToSelector:createdSel]
        ? ((id (*)(id, SEL))objc_msgSend)(model, createdSel) : nil;

    if ([created isKindOfClass:[NSNumber class]] && [created doubleValue] > 0) {
        sciPendingPosted = [NSDate dateWithTimeIntervalSince1970:[created doubleValue]];
        sciDateReads++;
    } else {
        sciDateMisses++;
    }
}

static void SCITTAddPhotoPost(NSArray<NSArray<NSURL *> *> *photos, NSURL *audio) {
    if (!photos.count) return;
    if (!sciRecent) sciRecent = [NSMutableArray array];

    NSURL *primary = photos.firstObject.firstObject;

    for (SCITTMediaItem *existing in [sciRecent copy]) {
        if ([existing.url isEqual:primary]) [sciRecent removeObject:existing];
    }

    SCITTMediaItem *item = [[SCITTMediaItem alloc] init];
    item.url = primary;
    item.photoVariants = photos;
    item.photoIndex = (sciPhotoIndex < photos.count) ? sciPhotoIndex : NSNotFound;
    item.audioURL = audio;

    //
    // **The same pending value, and this is the second door it had to be carried through.**
    //
    // 0.19.1 fixed a date written on one path and read on four. The fix was right and it was
    // applied to `SCITTAddResolvedList` alone -- while a photo post deliberately does *not* go
    // through that function, because a list of pictures and a list of alternative links to one
    // file mean different things. Different meaning, different door, and the date was left at the
    // first one: every photo post got an item with no date, and the label had nothing to show.
    //
    // A value set in one place and consumed in two is only fixed when both consumers are found.
    //
    item.posted = sciPendingPosted;
    item.stats = sciPendingStats;
    item.seen = [NSDate date];
    [sciRecent insertObject:item atIndex:0];

    while (sciRecent.count > kSCIMediaCap) [sciRecent removeLastObject];
}

static void SCITTAddResolved(NSURL *url) {
    if (url) SCITTAddResolvedList(@[url]);
}

+ (void)captureVideoModel:(id)videoModel {
    if (!videoModel) return;

    @try {
        sciResolveAttempts++;

        // Only chains that end at AWEURLModel's own doubly-confirmed
        // -bestURLtoDownload, sent to the video model itself rather than to an aweme
        // model whose -video is nil at construction time. -playURL is confirmed on this
        // class by a device report ("chain ended at AWEURLModel"); -playAddr and
        // -bitratePlayAddr are tried after it because the reference tweaks name them
        // and one of them may be what a different build populates first.
        //
        // **Every selector below except the last two is a confirmed *sent* selector**,
        // taken from `_objc_msgSend$…` stub symbols in NA9's and VibeTok's own
        // binaries -- a stub the compiler emits only for a selector it actually saw
        // being sent, which is a far higher bar than a name appearing as a string.
        // The two tweaks turned out to use different names for the same job, and
        // reading only one of them is what kept this feature broken:
        //
        //   selector              NA9 sends   VibeTok sends
        //   playURL               yes         -
        //   h264DownloadURL       -           yes
        //   playURLList           -           yes
        //   bestURLtoDownload     yes         -
        //   originURL             yes         -
        //   originUrl             -           yes      (note the casing)
        //   originURLList         yes         yes      <- both, the strongest signal
        //   urlList               -           yes
        //
        // `originURLList` is the only one both tweaks send, so it is tried early on
        // every container. `-h264URL` and `-downloadURL`, which earlier versions of
        // this list guessed at, are sent by neither tweak and appear as strings in
        // neither binary -- they were invented here and are gone. `-playAddr` and
        // `-bitratePlayAddr` are strings only, never sent, so they stay last.
        //
        NSArray<NSArray<NSString *> *> *chains = @[
            // The same confirmed ladder as the aweme path above, for a video model reached
            // directly. downloadAddr before playAddr before playURL: download address, then
            // codec-named playback address, then the generic one.
            // Same confirmed ladder, for a video model reached directly.
            @[@"downloadNoWatermarkURL", @"originURLList"],
            @[@"downloadNoWatermarkURL", @"urlList"],
            @[@"downloadURL", @"originURLList"],
            @[@"downloadURL", @"urlList"],

            @[@"playURL", @"originURLList"],
            @[@"playURL", @"originURL"],
            @[@"playURL", @"originUrl"],
            @[@"playURL", @"urlList"],

            // VibeTok's own path, and the name suggests exactly what this feature
            // wants: the H.264 download link rather than a streaming address. Tried
            // both as a direct answer and as a container.
            @[@"h264DownloadURL"],
            @[@"h264DownloadURL", @"originURLList"],
            @[@"h264DownloadURL", @"urlList"],

            @[@"playURLList", @"originURLList"],
            @[@"playURLList", @"urlList"],
            @[@"playURLList"],

        ];

        // Every chain, same as the aweme path -- see the note there for why one
        // answering is not the same as one answering with the video.
        NSMutableArray<NSURL *> *found = [NSMutableArray array];
        NSMutableArray<NSString *> *failures = [NSMutableArray array];

        for (NSArray<NSString *> *chain in chains) {
            NSString *failure = nil;
            NSURL *url = SCITTResolveChain(videoModel, chain, &failure);
            if (url && !SCITTURLLooksDownloadable(url)) {
                failure = [NSString stringWithFormat:@"non-http(s) (%@)", url.scheme ?: @"no scheme"];
                url = nil;
            }
            if (url) {
                if (![found containsObject:url]) [found addObject:url];
                if (!sciWinningChain) {
                    sciWinningChain = [NSString stringWithFormat:@"AWEVideoModel.%@",
                        [chain componentsJoinedByString:@"."]];
                    sciWinningURLShape = SCITTURLShape(url);
                }
                continue;
            }
            [failures addObject:[NSString stringWithFormat:@"%@: %@",
                [chain componentsJoinedByString:@"."], failure ?: @"?"]];
        }

        if (found.count) {
            sciResolveSuccesses++;
            sciLastAttemptState = [NSString stringWithFormat:
                @"AWEVideoModel — %lu candidate link(s)", (unsigned long)found.count];
            SCITTAddResolvedList(found);
            return;
        }

        sciLastAttemptState = [NSString stringWithFormat:@"AWEVideoModel — every chain failed: %@",
            [failures componentsJoinedByString:@" | "]];
    } @catch (NSException *exception) {
        sciLastAttemptState = [NSString stringWithFormat:@"threw: %@", exception.reason ?: @"?"];
        SCILogV(@"video model capture: %@", exception.reason);
    }
}

///
/// Every link this video model can offer, best guess first.
///
/// **The ladder was being preferred blind, and a device report showed why that is wrong**: on
/// one video it held five gears topping out at 720, and on the next it held exactly one,
/// `comet_lowest_540_1` — TikTok only populates the gears it is streaming. Preferring that over
/// `downloadNoWatermarkURL`, which is the copy TikTok serves for *saving*, means taking the
/// worse file whenever the app happens not to have fetched the better gears yet.
///
/// So nothing is preferred here. All of them are collected, and which one is actually largest
/// is measured with a HEAD request before the save, by the downloader.
static NSArray<NSURL *> *SCITTAllLinksForVideoModel(id videoModel, NSString **outVia,
                                                    NSArray<NSString *> **outOrigins) {
    if (!videoModel) return nil;

    NSMutableArray<NSURL *> *links = [NSMutableArray array];

    // Which accessor each link came from, kept alongside it.
    //
    // **Size alone cannot tell a watermarked copy from a clean one, and it reliably picks the
    // wrong one**: `downloadURL` is TikTok's watermarked save copy and is usually the largest
    // file on offer, so "take the biggest" stamps a watermark on every download. The name the
    // link came from is the only thing that knows, so it travels with it.
    NSMutableArray<NSString *> *origins = [NSMutableArray array];

    NSString *via = nil;
    NSURL *best = SCITTBestBitrateURL(videoModel, &via);
    if (best) {
        [links addObject:best];
        [origins addObject:@"bitrateModels"];
    }

    // The app's own save copies come first among the plain accessors: `downloadNoWatermarkURL`
    // is what TikTok itself hands out for a download, watermark-free.
    for (NSString *name in @[@"downloadNoWatermarkURL", @"downloadURL", @"h264DownloadURL",
                             @"playURL"]) {
        SEL selector = NSSelectorFromString(name);
        if (![videoModel respondsToSelector:selector]) continue;

        id urlModel = ((id (*)(id, SEL))objc_msgSend)(videoModel, selector);
        if (!urlModel) continue;

        for (NSString *list in @[@"originURLList", @"URLList", @"urlList"]) {
            SEL inner = NSSelectorFromString(list);
            if (![urlModel respondsToSelector:inner]) continue;

            NSURL *url = SCITTURLFromValue(((id (*)(id, SEL))objc_msgSend)(urlModel, inner));
            if (url && SCITTURLLooksDownloadable(url) && ![links containsObject:url]) {
                [links addObject:url];
                [origins addObject:name];
            }
            break;
        }
    }

    if (outOrigins) *outOrigins = origins;
    if (outVia) {
        *outVia = links.count
            ? [NSString stringWithFormat:@"%lu candidate(s)%@",
               (unsigned long)links.count, via ? [@", ladder: " stringByAppendingString:via] : @""]
            : nil;
    }
    return links.count ? links : nil;
}

+ (void)refreshPhotoIndexFromController:(id)controller {
    SCITTMediaItem *item = sciRecent.firstObject;
    if (!controller || !item.photoURLs.count) return;

    // Every candidate is read through its own real type encoding rather than a cast chosen here:
    // `currentIndex` is `Q` on the paging controller and `q` on the album model, and this project
    // has already crashed an app by assuming the width of a property it had only seen the name of.
    NSArray<NSArray<NSString *> *> *routes = @[
        @[@"activePhotoAlbumController", @"currentIndex"],
        @[@"cachedPhotoAlbumController", @"currentIndex"],
        @[@"", @"photoClearModeCurrentPage"],
    ];

    for (NSArray<NSString *> *route in routes) {
        id target = controller;

        if (route.firstObject.length) {
            SEL hop = NSSelectorFromString(route.firstObject);
            if (![controller respondsToSelector:hop]) continue;
            target = ((id (*)(id, SEL))objc_msgSend)(controller, hop);
            if (!target) continue;
        }

        NSString *name = route.lastObject;
        SEL selector = NSSelectorFromString(name);
        if (![target respondsToSelector:selector]) continue;

        Method method = class_getInstanceMethod([target class], selector);
        const char *types = method ? method_getTypeEncoding(method) : NULL;
        if (!types) continue;

        NSUInteger index = NSNotFound;
        if (types[0] == 'Q') {
            index = (NSUInteger)((unsigned long long (*)(id, SEL))objc_msgSend)(target, selector);
        } else if (types[0] == 'q') {
            long long value = ((long long (*)(id, SEL))objc_msgSend)(target, selector);
            if (value >= 0) index = (NSUInteger)value;
        } else {
            // An encoding this does not recognise loses rather than being guessed at, the same rule
            // the bitrate read follows.
            continue;
        }

        if (index >= item.photoURLs.count) continue;

        item.photoIndex = index;
        sciPhotoIndex = index;
        sciPhotoIndexVia = [NSString stringWithFormat:@"%@%@ (%c)",
            route.firstObject.length ? [route.firstObject stringByAppendingString:@"."] : @"",
            name, types[0]];
        return;
    }

    sciPhotoIndexVia = @"nothing live answered";
}

+ (NSString *)photoOriginFor:(NSURL *)url {
    return url.absoluteString.length ? sciPhotoOriginByURL[url.absoluteString] : nil;
}

+ (NSString *)photoReport {
    if (!sciPhotoHolder) return @"no photo post seen yet";

    SCITTMediaItem *item = sciRecent.firstObject;

    return [NSString stringWithFormat:
        @"%@ → %@ ×%lu (%@) → %lu picture(s), up to %lu link(s) each; showing index %@ via %@; "
        @"VVIC replacement %@",
        sciPhotoHolder,
        sciPhotoListVia ?: @"no list accessor answered",
        (unsigned long)sciPhotoListCount,
        sciPhotoElement ?: @"empty",
        (unsigned long)sciPhotoResolved,
        (unsigned long)sciPhotoVariantCount,
        // **Read off the item, not off the static, and the last report is why.** That line said
        // `index unknown via activePhotoAlbumController.currentIndex (Q)` -- two halves of one
        // sentence disagreeing, because the static is reset at the top of every resolution and the
        // resolver runs constantly, while the *item* keeps the index the tap actually used. The
        // saved picture was right; only the report was wrong, which is the more dangerous of the two.
        item.photoIndex == NSNotFound ? @"unknown" : @(item.photoIndex),
        sciPhotoIndexVia ?: @"not asked",
        sciPhotoVVICAsked ? @"asked" : @"absent"];
}

+ (NSString *)gearLadder {
    return sciGearLadder ?: @"no video has been asked for its gears yet this launch";
}

+ (void)captureSettledModel:(AWEAwemeModel *)model {
    if (!model) return;

    //
    // **Set here, at the one entry that has the model, and cleared first so it cannot leak.**
    //
    // The first version set this beside the item id, inside one of the four routes that build an
    // item -- so the three other routes produced an item with no date, and the date never appeared.
    // A pending value written on one path and read on four is a value that is either missing or
    // stale, and this file already had the pattern right for the id: set it where the model is,
    // once, before anything below can take a branch.
    //
    SCITTCapturePostedDate(model);

    // The best gear, asked for only here.
    //
    // This entry point exists because the caller -- the feed cell's button, holding
    // AWEFeedCellViewController.model -- has an object the app has finished building and is
    // currently showing on screen. +captureModel: is called from -init hooks where the same
    // walk crashed the app in 0.12.0, and no amount of care inside this function would make
    // that safe.
    @try {
        SEL videoSel = NSSelectorFromString(@"video");
        id videoModel = [model respondsToSelector:videoSel]
            ? ((id (*)(id, SEL))objc_msgSend)(model, videoSel) : nil;

        // Pictures first, exactly as `+captureModel:` does -- and 0.14.0 lost this by trying
        // the video links first and returning. A photo post *has* a video model here (TikTok
        // renders the slideshow as one), so the video branch always won and a photo post saved
        // a video. The ordering is the whole fix: a post that has pictures is a photo post,
        // whatever else it also happens to carry.
        if (SCIPrefEnabled(SCIPrefPhotoDownload)) {
            NSArray<NSArray<NSURL *> *> *photos = SCITTPhotoURLsFromModel(model);
            if (photos.count) {
                SCITTAddPhotoPost(photos, SCITTAudioURLFromModel(model));
                sciLastAttemptState = [NSString stringWithFormat:@"settled photo post — %lu picture(s)",
                    (unsigned long)photos.count];
                return;
            }
        }

        if (videoModel) {
            NSString *via = nil;
            NSArray<NSString *> *origins = nil;
            NSArray<NSURL *> *links = SCITTAllLinksForVideoModel(videoModel, &via, &origins);
            if (links.count) {
                sciPendingOrigins = origins;
                SEL idSel = NSSelectorFromString(@"itemID");
                id identifier = [model respondsToSelector:idSel]
                    ? ((id (*)(id, SEL))objc_msgSend)(model, idSel) : nil;
                sciPendingItemID = [identifier isKindOfClass:[NSString class]] ? identifier : nil;


                SCITTAddResolvedList(links);
                sciWinningChain = via;
                sciLastAttemptState = [NSString stringWithFormat:@"settled — %@", via];
                return;
            }
        }
    } @catch (NSException *exception) {
        // Falls through to the ordinary path rather than giving up: the chains below already
        // produce a working file, and losing quality is not a reason to lose the download.
        SCILogV(@"bitrate: %@", exception.reason);
    }

    [self captureModel:model];
}

+ (void)captureModel:(AWEAwemeModel *)model {
    if (!model) return;

    SCITTCapturePostedDate(model);

    @try {
        // Pictures first, because a photo post has no video to resolve and the chains below
        // would all fail on it -- which is what "the button does nothing on photo posts"
        // would have looked like, indistinguishable from every other resolution failure.
        if (SCIPrefEnabled(SCIPrefPhotoDownload)) {
            NSArray<NSArray<NSURL *> *> *photos = SCITTPhotoURLsFromModel(model);
            if (photos.count) {
                SCITTAddPhotoPost(photos, SCITTAudioURLFromModel(model));
                sciLastAttemptState = [NSString stringWithFormat:@"photo post — %lu picture(s)",
                    (unsigned long)photos.count];
                return;
            }
        }

        NSURL *url = [self resolveURLForModel:model];
        if (url) {
            SCITTAddResolved(url);
            return;
        }

        // Nothing resolved yet -- possibly because none of the tried names are right,
        // possibly because the right one simply has not been populated on this model
        // this early. `+watchModel:` cannot tell those apart either, but retrying
        // costs nothing a first attempt has not already spent, and is the only way to
        // find out which one it is without guessing a third time.
        [self watchModel:model];
    } @catch (NSException *exception) {
        // A capture is a convenience; TikTok's own feed is not. Anything thrown here
        // costs this one row, never the app.
        sciLastAttemptState = [NSString stringWithFormat:@"threw: %@", exception.reason ?: @"?"];
        SCILogV(@"media capture: %@", exception.reason);
    }
}

///
/// A model whose first resolution attempt found nothing, watched weakly in case the
/// answer was simply not populated yet at construction time -- `-video` itself
/// existing on the live class but answering nil on every attempt so far is exactly
/// the shape that would produce. Weak, so nothing here extends how long a feed cell's
/// own model stays alive; a model that TikTok discards while still pending is simply
/// dropped from the next retry pass rather than kept alive for it.
///

static NSHashTable<AWEAwemeModel *> *sciPending = nil;
static NSMapTable<AWEAwemeModel *, NSNumber *> *sciRetryCounts = nil;
static NSTimer *sciRetryTimer = nil;
static NSUInteger const kSCIMaxRetries = 10;

+ (void)watchModel:(AWEAwemeModel *)model {
    if (!model) return;

    if (!sciPending) {
        sciPending = [NSHashTable weakObjectsHashTable];
        sciRetryCounts = [NSMapTable weakToStrongObjectsMapTable];
    }
    [sciPending addObject:model];

    dispatch_async(dispatch_get_main_queue(), ^{
        if (sciRetryTimer) return;
        sciRetryTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                          repeats:YES
                                                            block:^(NSTimer *timer) {
            [SCITTMedia retryPending];
        }];
    });
}

+ (void)retryPending {
    if (!sciPending.count) return;

    for (AWEAwemeModel *model in [sciPending allObjects]) {
        NSUInteger tries = [sciRetryCounts objectForKey:model].unsignedIntegerValue;

        NSURL *url = [self resolveURLForModel:model];
        if (url) {
            SCITTAddResolved(url);
            [sciPending removeObject:model];
            [sciRetryCounts removeObjectForKey:model];
            continue;
        }

        tries++;
        if (tries >= kSCIMaxRetries) {
            // Given up on this one -- almost certainly a photo post or something else
            // with no video at all, not a resolution this project got wrong.
            [sciPending removeObject:model];
            [sciRetryCounts removeObjectForKey:model];
        } else {
            [sciRetryCounts setObject:@(tries) forKey:model];
        }
    }
}

+ (NSArray<SCITTMediaItem *> *)recent {
    return [sciRecent copy] ?: @[];
}

+ (void)forgetAll {
    [sciRecent removeAllObjects];
}

+ (NSString *)lastAttemptState {
    if (!sciResolveAttempts) return @"nothing captured yet";

    // Successes first and prominently -- see the note beside sciResolveSuccesses for
    // why the last attempt's own text alone was actively misleading.
    NSMutableString *out = [NSMutableString stringWithFormat:@"%lu resolved of %lu tried",
        (unsigned long)sciResolveSuccesses, (unsigned long)sciResolveAttempts];

    if (sciWinningChain) {
        [out appendFormat:@"; via %@", sciWinningChain];
    }
    if (sciWinningURLShape) {
        [out appendFormat:@"; link %@", sciWinningURLShape];
    }
    [out appendFormat:@"; %lu kept", (unsigned long)sciRecent.count];

    // The last attempt's own detail is kept, but only after the counts, and only when
    // nothing has ever succeeded -- once one chain works, two hundred lines about
    // models that were merely asked too early say nothing worth the space.
    if (!sciResolveSuccesses && sciLastAttemptState) {
        [out appendFormat:@" — last: %@", sciLastAttemptState];
    }

    return out;
}

+ (NSString *)candidateAccessorsOnAwemeModel {
    return [self accessorsOnClassNamed:@"AWEAwemeModel"
                              matching:@[@"video", @"play", @"url", @"media",
                                         @"cover", @"download", @"aweme"]];
}
/// Does `name` pass the filter -- **and an empty filter passes everything.**
///
/// The loop this replaces iterated the keyword list and added a name only from inside it, so
/// an empty list meant the body never ran and every class came back with nothing. Asking for
/// "no filter" produced "no results", which is the opposite of what it reads as, and the call
/// that wanted an unfiltered dump would have failed silently.
static BOOL SCITTNameMatches(NSString *name, NSArray<NSString *> *keywords) {
    if (!keywords.count) return YES;

    NSString *lower = name.lowercaseString;
    for (NSString *keyword in keywords) {
        if ([lower containsString:keyword.lowercaseString]) return YES;
    }
    return NO;
}


+ (NSString *)accessorsOnClassNamed:(NSString *)className
                            matching:(NSArray<NSString *> *)keywords {
    Class cls = NSClassFromString(className);
    if (!cls) return [NSString stringWithFormat:@"%@ not in this build", className];

    NSMutableOrderedSet<NSString *> *names = [NSMutableOrderedSet orderedSet];

    // The accessor may sit on a superclass rather than on the named class itself --
    // TikTok's own hierarchy is not something this project has a class dump of, so a
    // few levels up are read too rather than assuming it is declared exactly here.
    Class walk = cls;
    for (int depth = 0; walk && depth < 4; depth++) {
        unsigned int propCount = 0;
        objc_property_t *props = class_copyPropertyList(walk, &propCount);
        for (unsigned int i = 0; i < propCount; i++) {
            NSString *name = [NSString stringWithUTF8String:property_getName(props[i])];
            if (SCITTNameMatches(name, keywords)) [names addObject:name];
        }
        if (props) free(props);

        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(walk, &methodCount);
        for (unsigned int i = 0; i < methodCount; i++) {
            NSString *name = NSStringFromSelector(method_getName(methods[i]));
            if ([name containsString:@":"]) continue; // getters only, no arguments
            if (SCITTNameMatches(name, keywords)) [names addObject:name];
        }
        if (methods) free(methods);

        walk = class_getSuperclass(walk);
    }

    if (!names.count) {
        return keywords.count
            ? [NSString stringWithFormat:@"%@: nothing matches %@",
                className, [keywords componentsJoinedByString:@"/"]]
            : [NSString stringWithFormat:@"%@: no accessors at all", className];
    }
    return [[names array] componentsJoinedByString:@", "];
}

@end
