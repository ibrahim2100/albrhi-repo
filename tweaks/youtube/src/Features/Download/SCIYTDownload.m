#import "SCIYTDownload.h"
#import "../../SCILog.h"
#import "../../Localization/SCILocalize.h"
#import "../../Diagnostics/SCIYTDiagnostics.h"
#import "SCIYTStreamAPI.h"
#import "SCIYTPlayerStreams.h"
#import "SCIYTHLS.h"
#import "SCIYTDirect.h"
#import "Center/SCIYTLibrary.h"
#import "Center/SCIYTChoiceSheet.h"
#import "Center/SCIYTDownloadCenter.h"
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <objc/message.h>

///
/// One playable format.
///
@interface SCIYTFormat : NSObject
@property (nonatomic, copy) NSString *urlString;
@property (nonatomic, copy) NSString *qualityLabel;
@property (nonatomic, assign) NSInteger itag;
@property (nonatomic, assign) NSInteger height;
@property (nonatomic, assign) NSInteger fps;
@property (nonatomic, assign) long long bitrate;
@property (nonatomic, assign) BOOL isVideo;
@property (nonatomic, assign) BOOL hasAudio;
@end

@implementation SCIYTFormat
@end


#pragma mark - Reading the streams

///
/// The helpers that read the app's own stream objects used to sit here.
///
/// They asked MLRemoteStream, and the formatStream nested inside it, for a link under
/// every name a link might have. A report from a real device settled it: every stream
/// answers -URL with "?cpn=â€¦" â€” a query fragment â€” because this build fetches ranges
/// over the piecewise protocol rather than downloading a file. There is no link to
/// find under any name, and more probing would not have produced one.
///
/// Formats come from a fresh player response now. See SCIYTStreamAPI.
///
///
/// itags iOS can actually play, listed rather than inferred.
///
/// A MIME type of "video/mp4" is not enough: YouTube serves VP9 and AV1 under container
/// names iOS will happily download and then refuse to play, and the result is a file in
/// Photos that shows a black frame. The itag says exactly which codec is inside.
///
/// H.264 video, and AAC audio. VP9 and AV1 are deliberately absent â€” the Instagram side
/// of this repository transcodes AV1 on device and it costs minutes of battery per clip;
/// doing that here before the plain path is proven would be building the hard half first.
///
static NSSet<NSNumber *> *SCIPlayableVideoItags(void) {
    static NSSet *itags = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        itags = [NSSet setWithArray:@[
            @18, @22,                                  // muxed: video and audio in one file
            @160, @133, @134, @135, @136, @137,        // H.264 video-only, 144p â†’ 1080p
            @298, @299,                                // H.264 60fps, 720p and 1080p
            @264, @266,                                // H.264 1440p and 2160p
        ]];
    });
    return itags;
}

static NSSet<NSNumber *> *SCIPlayableAudioItags(void) {
    static NSSet *itags = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // AAC in an MP4 container. Opus (249/250/251) is left out for the same reason
        // VP9 is: iOS will not put it in a .mp4 alongside H.264.
        itags = [NSSet setWithArray:@[@139, @140, @141, @256, @258]];
    });
    return itags;
}

/// The two itags that carry sound in the same file as the picture.
static BOOL SCIItagIsMuxed(NSInteger itag) {
    return itag == 18 || itag == 22;
}

///
/// The link, made fetchable.
///
/// Two changes, both from YouMod and both load-bearing:
///
///   `n` removed â€” a parameter that throttles the transfer to roughly playback speed,
///   which turns a two-minute download into the length of the video.
///
///   `ratebypass=yes` added, which asks for the whole file rather than a stream.
///
/// The cpn is left alone if one is already there. It identifies the playback session
/// and the URL arrives carrying it.
///
static NSString *SCIPreparedURL(NSString *urlString) {
    if (!urlString.length) return nil;

    NSURLComponents *components = [NSURLComponents componentsWithString:urlString];
    if (!components) return urlString;

    NSMutableArray<NSURLQueryItem *> *items = [NSMutableArray array];
    BOOL hasRateBypass = NO;

    for (NSURLQueryItem *item in components.queryItems) {
        if ([item.name isEqualToString:@"n"]) continue;
        if ([item.name isEqualToString:@"ratebypass"]) hasRateBypass = YES;
        [items addObject:item];
    }

    if (!hasRateBypass) {
        [items addObject:[NSURLQueryItem queryItemWithName:@"ratebypass" value:@"yes"]];
    }

    components.queryItems = items;
    return components.string ?: urlString;
}


@implementation SCIYTDownload

#pragma mark - Discovery

///
/// Why the last scan produced what it did.
///
/// "Nothing to download" is the least useful sentence this tweak could say, and it is
/// what 0.5.0 said for every one of three different causes: no streaming data at all,
/// formats with no fetchable link, and formats in a codec iOS will not play. Those need
/// three different answers, and telling them apart on a device meant reading the
/// diagnostics page â€” for a message that could have named the reason itself.
///
static NSInteger sciSeen = 0;
static NSInteger sciNoURL = 0;
static NSInteger sciUnplayable = 0;

/// Turns one JSON format object into a format we can use, or nil.
+ (SCIYTFormat *)formatFromJSON:(NSDictionary *)json {
    if (![json isKindOfClass:[NSDictionary class]]) return nil;

    NSInteger itag = [json[@"itag"] respondsToSelector:@selector(integerValue)]
        ? [json[@"itag"] integerValue] : 0;
    if (!itag) return nil;

    sciSeen++;

    BOOL isVideo = [SCIPlayableVideoItags() containsObject:@(itag)];
    BOOL isAudio = [SCIPlayableAudioItags() containsObject:@(itag)];
    if (!isVideo && !isAudio) {
        sciUnplayable++;
        return nil;
    }

    NSString *url = json[@"url"];
    if (![url isKindOfClass:[NSString class]] || ![url hasPrefix:@"http"]) {
        sciNoURL++;
        return nil;
    }

    SCIYTFormat *format = [[SCIYTFormat alloc] init];
    format.itag = itag;
    format.urlString = SCIPreparedURL(url);
    format.isVideo = isVideo;
    format.hasAudio = isAudio || SCIItagIsMuxed(itag);
    format.height = [json[@"height"] respondsToSelector:@selector(integerValue)]
        ? [json[@"height"] integerValue] : 0;
    format.fps = [json[@"fps"] respondsToSelector:@selector(integerValue)]
        ? [json[@"fps"] integerValue] : 0;
    format.bitrate = [json[@"bitrate"] respondsToSelector:@selector(longLongValue)]
        ? [json[@"bitrate"] longLongValue] : 0;
    format.qualityLabel = [json[@"qualityLabel"] isKindOfClass:[NSString class]]
        ? json[@"qualityLabel"] : nil;

    return format;
}

///
/// The formats the player is already holding.
///
/// Tried before the network request, and it should have been tried before it was ever
/// written. The tweak was reading MLStreamingData, whose streams answer -URL with a
/// fragment because the media layer fetches byte ranges; the player response holds a
/// second, entirely different streaming data whose YTIFormatStream objects carry a url.
/// Same app, same video, an object graph nobody had walked.
///
/// Costs no request, borrows no client identity, and cannot be revoked. Everything the
/// InnerTube path has to fight for is simply already here, if it is here at all.
///
+ (NSArray<SCIYTFormat *> *)formatsFromPlayer {
    sciSeen = 0;
    sciNoURL = 0;
    sciUnplayable = 0;

    NSArray *objects = [SCIYTPlayerStreams formatObjects];
    if (!objects.count) return @[];

    NSMutableArray<SCIYTFormat *> *out = [NSMutableArray array];
    NSMutableSet<NSNumber *> *seen = [NSMutableSet set];

    for (id object in objects) {
        // The list now mixes two shapes: protobuf format streams from the player
        // response, and media-layer streams that keep theirs nested. Both answer -itag,
        // but only the outer one of a media-layer stream is guaranteed to.
        NSInteger itag = [[SCIYTPlayerStreams valueOf:@"itag" on:object] integerValue];
        if (!itag) {
            id nested = [SCIYTPlayerStreams valueOf:@"formatStream" on:object];
            itag = [[SCIYTPlayerStreams valueOf:@"itag" on:nested] integerValue];
        }
        if (!itag || [seen containsObject:@(itag)]) continue;

        sciSeen++;

        BOOL isVideo = [SCIPlayableVideoItags() containsObject:@(itag)];
        BOOL isAudio = [SCIPlayableAudioItags() containsObject:@(itag)];
        if (!isVideo && !isAudio) {
            sciUnplayable++;
            continue;
        }

        // Every name, and the nested formatStream after them, taking the first that is
        // actually a link rather than the first that answers.
        //
        // That distinction is the whole bug. The diagnostics probe stopped at the first
        // non-empty value; `URL` answers with the fragment "?cpn=â€¦" on a media-layer
        // stream, so it reported that and never asked for anything else. Four releases
        // were spent on the conclusion that no link existed anywhere, drawn from a list
        // of one name.
        NSString *link = nil;

        for (NSString *name in @[@"url", @"URL", @"baseURL", @"urlString", @"URLString"]) {
            NSString *candidate = [SCIYTPlayerStreams stringOf:name on:object];
            if ([candidate hasPrefix:@"http"]) { link = candidate; break; }
        }

        if (!link) {
            // A media-layer stream keeps its protobuf under formatStream, and that is
            // where the link lives when the outer object has only a fragment.
            id nested = [SCIYTPlayerStreams valueOf:@"formatStream" on:object];
            for (NSString *name in @[@"url", @"URL"]) {
                NSString *candidate = [SCIYTPlayerStreams stringOf:name on:nested];
                if ([candidate hasPrefix:@"http"]) { link = candidate; break; }
            }
        }

        if (!link) {
            sciNoURL++;
            continue;
        }

        [seen addObject:@(itag)];

        SCIYTFormat *format = [[SCIYTFormat alloc] init];
        format.itag = itag;
        format.urlString = [SCIYTPlayerStreams preparedURLFrom:link];
        format.isVideo = isVideo;
        format.hasAudio = isAudio || SCIItagIsMuxed(itag);
        format.height = [[SCIYTPlayerStreams valueOf:@"height" on:object] integerValue];
        format.fps = [[SCIYTPlayerStreams valueOf:@"fps" on:object] integerValue];
        format.bitrate = [[SCIYTPlayerStreams valueOf:@"bitrate" on:object] longLongValue];
        format.qualityLabel = [SCIYTPlayerStreams stringOf:@"qualityLabel" on:object];

        [out addObject:format];
    }

    SCILogV(@"download: player held %ld formats, %lu usable",
            (long)sciSeen, (unsigned long)out.count);

    return out;
}

/// The player walk, written into the report whether it worked or not.
///
/// 0.8.0 recorded this path only on success, so a failed one left no trace at all and
/// the report jumped straight to the network attempts -- which reads as though the
/// player was never asked. Three different outcomes were indistinguishable: the walk
/// breaking early, the player holding formats with no links, and it holding formats in
/// codecs iOS cannot play.
+ (void)recordPlayerWalkWith:(NSUInteger)usable {
    NSString *trace = [SCIYTPlayerStreams lastTrace] ?: @"no walk";

    [SCIYTDiagnostics recordStreamAttempt:
        [NSString stringWithFormat:@"player: %@ | %ld seen, %ld no link, %ld unplayable, %lu usable",
         trace, (long)sciSeen, (long)sciNoURL, (long)sciUnplayable, (unsigned long)usable]];
}

/// Every usable format in a streaming-data dictionary.
+ (NSArray<SCIYTFormat *> *)formatsFromStreamingData:(NSDictionary *)streamingData {
    sciSeen = 0;
    sciNoURL = 0;
    sciUnplayable = 0;

    if (![streamingData isKindOfClass:[NSDictionary class]]) return @[];

    NSMutableArray<SCIYTFormat *> *out = [NSMutableArray array];
    NSMutableSet<NSNumber *> *seen = [NSMutableSet set];

    for (NSString *key in @[@"adaptiveFormats", @"formats"]) {
        NSArray *list = streamingData[key];
        if (![list isKindOfClass:[NSArray class]]) continue;

        for (NSDictionary *entry in list) {
            SCIYTFormat *format = [self formatFromJSON:entry];
            if (!format || [seen containsObject:@(format.itag)]) continue;

            [seen addObject:@(format.itag)];
            [out addObject:format];
        }
    }

    SCILogV(@"download: %ld seen, %ld unplayable, %ld without a link, %lu usable",
            (long)sciSeen, (long)sciUnplayable, (long)sciNoURL, (unsigned long)out.count);

    return out;
}

/// The sentence shown when nothing can be saved, naming which of the three walls it hit.
+ (NSString *)refusalReason {
    if (sciSeen == 0) {
        return SCILocalized(@"dl_why_no_formats");
    }

    // The link comes first, and getting that order wrong made an earlier version of
    // this message actively misleading. A real report had twelve formats: eight in VP9
    // and AV1, and four in H.264 that this tweak accepts. It said "all in a codec iOS
    // will not play" â€” because eight is more than four â€” when what actually stopped the
    // download was that those four carried no link.
    //
    // Anything that survives the codec check and still cannot be fetched is the wall.
    // The codec only matters when nothing survived it at all.
    if (sciNoURL > 0) {
        return [NSString stringWithFormat:SCILocalized(@"dl_why_no_urls"), (long)sciNoURL];
    }
    if (sciUnplayable > 0) {
        return [NSString stringWithFormat:SCILocalized(@"dl_why_unplayable_api"),
                (long)sciUnplayable];
    }
    return SCILocalized(@"dl_why_unknown");
}

+ (NSString *)diagnosticsSummary {
    // Deliberately not a live count any more. Formats come from a request to YouTube
    // now, and a diagnostics page that fired one off every time it was opened would be
    // asking about the user's video without being told to.
    //
    // What it can report without asking anything is what the last hold found, which is
    // the number that matters when someone says saving did not work.
    if (sciSeen == 0) {
        return SCILocalized(@"dl_diag_none");
    }
    return [NSString stringWithFormat:SCILocalized(@"dl_diag_found"),
            (long)(sciSeen - sciUnplayable - sciNoURL), (long)sciSeen];
}

/// The best audio available, for pairing with a video-only format.
+ (SCIYTFormat *)bestAudio:(NSArray<SCIYTFormat *> *)formats {
    SCIYTFormat *best = nil;
    for (SCIYTFormat *format in formats) {
        if (format.isVideo) continue;
        if (!best || format.bitrate > best.bitrate) best = format;
    }
    return best;
}

#pragma mark - Choosing

/// Which video the caller insisted on, if any. Cleared as soon as it has been read.
///
/// A one-shot rather than a parameter threaded through eight methods: this is read twice,
/// both times within the same run of one sheet, and widening every signature between here
/// and there to carry it would touch far more code than the fix is worth.
static NSString *sciRequestedVideoID = nil;

+ (void)presentFrom:(UIViewController *)presenter videoID:(NSString *)videoID {
    sciRequestedVideoID = [videoID copy];
    [self beginFrom:presenter];
}

+ (void)presentFrom:(UIViewController *)presenter {
    // Cleared, not left. Without this a long press on an ordinary video would inherit
    // whichever Short was saved last -- the one-shot outliving its one shot.
    sciRequestedVideoID = nil;
    [self beginFrom:presenter];
}

+ (void)beginFrom:(UIViewController *)presenter {
    if (!presenter) return;

    [SCIYTDiagnostics clearStreamAttempts];

    // The direct route first, and the playlist only when it cannot serve this video.
    //
    // The playlist is something the *app* was handed, which YouTube reshapes whenever it
    // reshapes the app; the direct route is a request this tweak makes itself, as a client
    // that still gets plain files (SCIYTDirect has the whole argument). It is skipped, not
    // retried, for a video it already failed on this launch -- a second identical refusal
    // costs a network round trip and a waiting dialog for nothing.
    NSString *directID = sciRequestedVideoID
        ?: [SCIYTDiagnostics activeVideoID]
        ?: [SCIYTDiagnostics lastVideoID];

    if (directID.length && ![SCIYTDirect hasFailedForVideo:directID]) {
        [self presentDirectFrom:presenter videoID:directID];
        return;
    }

    [self beginFromPlaylist:presenter];
}

/// The waiting dialog, then the direct route's qualities -- or, when it has none for this video,
/// the route that existed before it, reached with the reason already in the report.
+ (void)presentDirectFrom:(UIViewController *)presenter videoID:(NSString *)videoID {
    UIAlertController *waiting =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"dl_title")
                                            message:SCILocalized(@"dl_asking")
                                     preferredStyle:UIAlertControllerStyleAlert];

    __block BOOL shown = NO;
    __block void (^pending)(void) = nil;

    void (^done)(void (^)(void)) = ^(void (^after)(void)) {
        void (^close)(void) = ^{
            [waiting dismissViewControllerAnimated:YES completion:after];
        };
        if (shown) close(); else pending = close;
    };

    [presenter presentViewController:waiting animated:YES completion:^{
        shown = YES;
        if (pending) { void (^queued)(void) = pending; pending = nil; queued(); }
    }];

    [SCIYTDirect variantsForVideo:videoID
                       completion:^(NSArray<SCIHLSVariant *> *variants, NSString *failure) {
        done(^{
            if (variants.count) {
                [self presentVariants:variants from:presenter];
            } else {
                [self beginFromPlaylist:presenter];
            }
        });
    }];
}

+ (void)beginFromPlaylist:(UIViewController *)presenter {
    if (!presenter) return;

    // The activated video first, and the last MLVideo only as a fallback.
    //
    // They are not the same thing: MLVideo objects are created for videos the app is
    // preloading as well as the one on screen. A report showed SponsorBlock working on
    // one id while this asked YouTube about another, which is a download that could only
    // ever fail -- and failed with a message blaming the video for being private.
    // The player first. If it is holding formats with links, there is no reason to ask
    // anyone for anything: no request, no borrowed client identity, nothing YouTube can
    // withdraw. The network path exists for when this comes up empty, not the reverse.
    // Not cleared here: -beginFrom: already did, and clearing again would erase the line
    // saying why the direct route stood aside.

    // The playlist first, because it is the only route measurement says exists.
    //
    // Nine releases established that no individual format on this build carries an
    // address -- through the media layer, the nested format, the player response and four
    // InnerTube clients. The playlist that lists them does, and that is where every tweak
    // whose downloading works ends up.
    // ...but only when it is the playlist for the video being asked for.
    //
    // This is captured from the live player, so it belongs to whatever YouTube is playing.
    // On a normal video that is the video. In Shorts it is routinely the clip queued below,
    // because the next one is prepared while you are still watching this one -- and 0.25.0
    // passing the right id changed nothing, since this branch is taken before the id is ever
    // read. Naming the video was necessary and not sufficient; this is the other half.
    // Compared against the video the captured *response* is for, which is the video whose
    // playlist this is. Not the announced one, and not the last MLVideo built.
    //
    // 0.25.1 compared against the announced id and that is why it did nothing. In Shorts
    // those three ids differ routinely -- a device report showed the announced id and the
    // overlay's id agreeing perfectly on KMBaTpD5KiM while the captured response was still
    // HIEcjnGa004 -- so the check agreed with itself and handed over another video's
    // playlist. Everywhere outside Shorts the three coincide, which is why this was only
    // ever wrong there.
    NSString *requested = sciRequestedVideoID;
    NSString *owner = [SCIYTDiagnostics responseVideoID];

    // An unknown owner means "cannot tell", and cannot-tell must not mean no.
    //
    // 0.28.0 wrote this as `owner.length && equal`, so a nil owner made every capture
    // somebody else's and refused every download -- the report came back with `playlist ?`
    // and four failed API clients. That is worse than the bug it was guarding against: the
    // wrong video is a bad download, no video is no feature.
    //
    // The guard only fires on a positive disagreement now: an owner that is known and is
    // not the video asked for. Unknown falls through to the announced id, which is what
    // 0.25.1 compared against and what worked everywhere outside Shorts.
    //
    // The rule I broke: a check written on a value never once seen produced is a guess
    // wearing a guard's clothes. This one is now written so that being wrong about the
    // value costs the check, not the feature.
    BOOL disagrees = NO;
    if (requested.length) {
        if (owner.length) {
            disagrees = ![requested isEqualToString:owner];
        } else {
            NSString *announced = [SCIYTDiagnostics activeVideoID];
            disagrees = announced.length && ![requested isEqualToString:announced];
        }
    }

    BOOL captureIsOurs = !disagrees;

    // The named video's own playlist first, whenever one was asked for.
    //
    // This replaces three releases of trying to work out whether the latest capture happened
    // to belong to the right clip. It never had to be worked out -- the captures are filed
    // by video id now, so the right one can simply be fetched. Detecting a mismatch was
    // solving the harder version of an easier problem.
    NSString *manifest = requested.length
        ? [SCIYTPlayerStreams hlsManifestURLForVideo:requested] : nil;

    if (manifest.length) {
        [SCIYTDiagnostics recordStreamAttempt:
            [NSString stringWithFormat:@"hls: playlist filed under %@", requested]];
    } else {
        manifest = captureIsOurs ? [SCIYTPlayerStreams hlsManifestURL] : nil;

        // Used, and said to be checked or not.
        //
        // Never refused on this test again. 0.30.2 dropped every address there is by
        // comparing the two encodings of a video's name directly; the check is written
        // properly now and still only chooses between candidates. Having nothing to
        // download is worse than having the wrong thing, and this path is the last one
        // left when the filed playlist did not answer.
        if (manifest.length && requested.length) {
            [SCIYTDiagnostics recordStreamAttempt:
                [NSString stringWithFormat:@"hls: live playlist for %@ — %@", requested,
                    [SCIYTPlayerStreams manifest:manifest isForVideo:requested]
                        ? @"and it is that video's" : @"but it names another video"]];
        }
    }

    if (!captureIsOurs) {
        [SCIYTDiagnostics recordStreamAttempt:
            [NSString stringWithFormat:@"hls: captured playlist is for %@, wanted %@ — asking instead",
             owner ?: @"unknown", requested]];
    }

    if (manifest.length) {
        [SCIYTDiagnostics recordStreamAttempt:
            [NSString stringWithFormat:@"hls: manifest found (%lu chars)",
             (unsigned long)manifest.length]];
        [self presentHLSFrom:presenter manifest:manifest];
        return;
    }

    // Guarded, on the same principle the settings screen already follows: a tweak whose
    // job is to report what is happening must not be able to kill the app it is
    // reporting on. 0.8.2 read a numeric field as an object pointer and took YouTube
    // down on the first format of the first video -- and the report, written only after
    // the walk, said nothing at all because the process never got that far.
    NSArray<SCIYTFormat *> *local = nil;

    @try {
        // Skipped for the same reason the captured playlist is: this reads the live player,
        // so what it finds belongs to whatever is playing rather than to what was asked for.
        if (captureIsOurs) local = [self formatsFromPlayer];
    } @catch (NSException *exception) {
        [SCIYTDiagnostics recordStreamAttempt:
            [NSString stringWithFormat:@"player: threw â€” %@: %@",
             exception.name, exception.reason]];
        SCILogV(@"download: the player walk threw â€” %@", exception.reason);
        local = nil;
    }

    [self recordPlayerWalkWith:local.count];

    if (local.count) {
        [self presentSheetFor:local from:presenter];
        return;
    }

    // What the caller named wins. Shorts names it, because what this tweak knows as
    // "playing" follows YouTube's announcements and those run ahead into the preloaded clip.
    NSString *videoID = sciRequestedVideoID
        ?: [SCIYTDiagnostics activeVideoID]
        ?: [SCIYTDiagnostics lastVideoID];
    if (!videoID.length) {
        [self showMessage:SCILocalized(@"dl_why_no_data") from:presenter];
        return;
    }

    // There is a network round trip in front of the sheet now, so something has to say
    // so. Asking YouTube takes a moment, and a hold that appears to do nothing reads as
    // a broken gesture â€” which is exactly how 0.6.0's looked while it was silently
    // losing to YouTube's own recognisers.
    UIAlertController *waiting =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"dl_title")
                                            message:SCILocalized(@"dl_asking")
                                     preferredStyle:UIAlertControllerStyleAlert];

    __block BOOL shown = NO;
    __block void (^pending)(void) = nil;

    void (^done)(void (^)(void)) = ^(void (^next)(void)) {
        void (^close)(void) = ^{
            [waiting dismissViewControllerAnimated:YES completion:next];
        };
        if (shown) close(); else pending = close;
    };

    [presenter presentViewController:waiting animated:YES completion:^{
        shown = YES;
        if (pending) { void (^queued)(void) = pending; pending = nil; queued(); }
    }];

    [SCIYTStreamAPI streamingDataForVideo:videoID
                               completion:^(NSDictionary *streamingData, NSString *failure) {
        NSArray<SCIYTFormat *> *formats = [self formatsFromStreamingData:streamingData];

        // The response carries the playlist for the video that was asked for, and the
        // playlist is the only route that works on this build -- so it is preferred over the
        // format list, exactly as the captured one is above. Reading it costs one key and it
        // was there the whole time.
        NSString *apiManifest = streamingData[@"hlsManifestUrl"];

        done(^{
            if (apiManifest.length) {
                [SCIYTDiagnostics recordStreamAttempt:
                    [NSString stringWithFormat:@"hls: playlist from the API (%lu chars)",
                     (unsigned long)apiManifest.length]];
                [self presentHLSFrom:presenter manifest:apiManifest];
                return;
            }

            if (!formats.count) {
                // The server's own sentence when it gave one -- private, age-gated,
                // blocked here -- and our tally when it did not.
                [self showMessage:(failure ?: [self refusalReason]) from:presenter];
                return;
            }
            [self presentSheetFor:formats from:presenter];
        });
    }];
}

///
/// The quality sheet, then the download, for the playlist route.
///
/// Kept apart from the format-list one rather than folded into it: the two share a shape
/// and nothing else. This has a network round trip before the sheet, a progress figure
/// during, and a different failure vocabulary â€” a playlist can be fetched and turn out to
/// list nothing playable, which no format list can do.
///
+ (void)presentHLSFrom:(UIViewController *)presenter manifest:(NSString *)manifest {
    UIAlertController *waiting =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"dl_title")
                                            message:SCILocalized(@"dl_asking")
                                     preferredStyle:UIAlertControllerStyleAlert];

    __block BOOL shown = NO;
    __block void (^pending)(void) = nil;

    void (^done)(void (^)(void)) = ^(void (^after)(void)) {
        void (^close)(void) = ^{
            [waiting dismissViewControllerAnimated:YES completion:after];
        };
        if (shown) close(); else pending = close;
    };

    [presenter presentViewController:waiting animated:YES completion:^{
        shown = YES;
        if (pending) { void (^queued)(void) = pending; pending = nil; queued(); }
    }];

    [SCIYTHLS variantsForManifest:manifest
                       completion:^(NSArray<SCIHLSVariant *> *variants, NSString *failure) {
        [SCIYTDiagnostics recordStreamAttempt:
            [NSString stringWithFormat:@"hls: %lu variants%@",
             (unsigned long)variants.count, failure ? [@" â€” " stringByAppendingString:failure] : @""]];

        done(^{
            if (!variants.count) {
                [self showMessage:(failure ?: SCILocalized(@"dl_hls_no_variants")) from:presenter];
                return;
            }

            [self presentVariants:variants from:presenter];
        });
    }];
}

+ (void)presentVariants:(NSArray<SCIHLSVariant *> *)variants from:(UIViewController *)presenter {
    // Sound or pictures, and which size, on one screen. The action sheet this
    // replaces was eight rows reading "1080p", "720p" and so on, with no way to
    // ask for the sound alone and nothing to tell one row from another at a
    // glance -- and it looked like a system warning rather than a choice.
    // The title of the video asked for, not of whichever was captured last.
    //
    // In Shorts those differ every time, and the download was fetching the right
    // clip and labelling it with the next one's name -- which is exactly what
    // "it saved the wrong video" looks like from the Download Centre.
    // The direct route names the video it asked about, and that is the one every line below
    // must agree with -- it may have fallen back to the last video seen, which the playlist
    // route never does.
    NSString *askedID = variants.firstObject.directVideoID
        ?: sciRequestedVideoID ?: [SCIYTDiagnostics activeVideoID];
    NSString *title = [SCIYTDiagnostics titleForVideoID:askedID]
        ?: [SCIYTDiagnostics lastVideoTitle];
    // The same id the title was resolved from, so the thumbnail section fetches the
    // cover of the video that was asked for rather than of whichever was captured
    // last -- the Shorts mismatch documented just above, in picture form.
    [SCIYTChoiceSheet presentFrom:presenter
                         variants:variants
                            title:title
                          videoID:askedID
                           chosen:^(SCIHLSVariant *variant, SCIYTJobKind kind) {
        NSString *chosenID = askedID;

        // Already here? Say so rather than fetching it again.
        //
        // Ninety parts is minutes of waiting and a second copy of the same file, and
        // the person asking has no way of knowing it is already saved -- the list is
        // a different screen. Only a finished save of the same kind counts: a video
        // and its audio are two different things to want.
        SCIYTJob *existing = [[SCIYTLibrary shared] existingJobForVideo:chosenID kind:kind];
        if (existing) {
            [self showMessage:SCILocalized(@"dl_already_have") from:presenter];
            return;
        }

        // Set only from the Shorts save button -- the one caller that ever hands
        // this class a video id up front, because a long press elsewhere means
        // "whatever is currently playing" and never means Shorts.
        [[SCIYTLibrary shared] startVariant:variant
                                        kind:kind
                                       title:title
                                     videoID:chosenID
                                     isShort:(sciRequestedVideoID != nil)];

        // And that is the end of it here. The download is a row in the centre
        // now, so the app is handed straight back -- watching something while a
        // video saves is the ordinary case, not an edge one.
        [self showMessage:SCILocalized(@"dl_started") from:presenter];
    }];
}

+ (void)presentSheetFor:(NSArray<SCIYTFormat *> *)formats from:(UIViewController *)presenter {

    // Highest first, and one entry per quality: three renditions of 1080p differ only
    // in a codec the user did not ask about.
    NSMutableArray<SCIYTFormat *> *videos = [NSMutableArray array];
    NSMutableSet<NSString *> *labels = [NSMutableSet set];

    NSArray<SCIYTFormat *> *sorted = [formats sortedArrayUsingComparator:^NSComparisonResult(SCIYTFormat *a, SCIYTFormat *b) {
        if (a.height != b.height) return a.height > b.height ? NSOrderedAscending : NSOrderedDescending;
        return a.bitrate > b.bitrate ? NSOrderedAscending : NSOrderedDescending;
    }];

    for (SCIYTFormat *format in sorted) {
        if (!format.isVideo) continue;

        NSString *label = format.qualityLabel.length ? format.qualityLabel
                        : [NSString stringWithFormat:@"%ldp", (long)format.height];
        if ([labels containsObject:label]) continue;

        [labels addObject:label];
        [videos addObject:format];
    }

    // No video worth offering, but the sound may still be there -- a track people
    // actually want on its own, and 0.5.0 refused the whole thing at this point.
    if (!videos.count && ![self bestAudio:formats]) {
        [self showMessage:[self refusalReason] from:presenter];
        return;
    }

    SCIYTFormat *audio = [self bestAudio:formats];

    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"dl_choose_quality")
                                            message:[SCIYTDiagnostics lastVideoTitle]
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    for (SCIYTFormat *video in videos) {
        NSString *label = video.qualityLabel.length ? video.qualityLabel
                        : [NSString stringWithFormat:@"%ldp", (long)video.height];

        // Says plainly when a quality needs the audio fetched separately, because that
        // one takes longer and the wait should not be a surprise.
        if (!video.hasAudio && audio) {
            label = [label stringByAppendingString:SCILocalized(@"dl_with_audio")];
        } else if (!video.hasAudio && !audio) {
            continue;   // video-only with nothing to pair: silent file, not worth offering
        }

        [sheet addAction:[UIAlertAction actionWithTitle:label
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            [self startVideo:video audio:(video.hasAudio ? nil : audio) from:presenter];
        }]];
    }

    // Sound on its own. Kept last so it never sits between two qualities, and offered
    // whenever there is an audio stream -- for music and podcasts it is the point, not a
    // fallback.
    if (audio) {
        [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"dl_audio_only")
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            [self startAudioOnly:audio from:presenter];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    // An unanchored action sheet is fatal on iPad.
    sheet.popoverPresentationController.sourceView = presenter.view;
    sheet.popoverPresentationController.sourceRect =
        CGRectMake(CGRectGetMidX(presenter.view.bounds), CGRectGetMidY(presenter.view.bounds), 1, 1);

    [presenter presentViewController:sheet animated:YES completion:nil];
}

#pragma mark - Fetching

/// A request that YouTube's CDN will serve.
///
/// The headers are not decoration: a bare request for one of these links is refused.
/// Identity encoding matters too â€” a gzipped video is not a video.
+ (NSURLRequest *)requestForURL:(NSURL *)url {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:@"https://www.youtube.com" forHTTPHeaderField:@"Origin"];
    [request setValue:@"https://www.youtube.com/" forHTTPHeaderField:@"Referer"];
    [request setValue:@"identity" forHTTPHeaderField:@"Accept-Encoding"];
    request.timeoutInterval = 60;
    return request;
}

/// Downloads one file to a temporary path.
///
/// No progress reporting, deliberately. A percentage would need an NSURLSession
/// delegate object living beyond this call, and the alert it fed would still not be
/// cancellable without more machinery again. Two transfers of a few tens of megabytes
/// finish quickly enough that "workingâ€¦" is honest, and it is one moving part instead
/// of four.
+ (void)fetch:(NSString *)urlString
    extension:(NSString *)extension
   completion:(void (^)(NSURL *file, NSError *error))completion {

    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        completion(nil, [NSError errorWithDomain:@"AlbrhiYT" code:1 userInfo:nil]);
        return;
    }

    NSURLSessionDownloadTask *task =
        [[NSURLSession sharedSession] downloadTaskWithRequest:[self requestForURL:url]
                                            completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        if (!location || error) {
            completion(nil, error);
            return;
        }

        NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]]
            ? [(NSHTTPURLResponse *)response statusCode] : 200;

        if (status != 200 && status != 206) {
            SCILogV(@"download: server said %ld", (long)status);
            completion(nil, [NSError errorWithDomain:@"AlbrhiYT" code:status userInfo:nil]);
            return;
        }

        // Moved out of the session's temporary directory, which is emptied the moment
        // this handler returns.
        NSString *name = [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:extension];
        NSURL *destination = [NSURL fileURLWithPath:
            [NSTemporaryDirectory() stringByAppendingPathComponent:name]];

        NSError *moveError = nil;
        [[NSFileManager defaultManager] moveItemAtURL:location toURL:destination error:&moveError];

        completion(moveError ? nil : destination, moveError);
    }];

    [task resume];
}

#pragma mark - Merging

/// Puts a video track and an audio track into one file.
///
/// AVMutableComposition rather than a remux library: both streams are already H.264 and
/// AAC in MP4 containers â€” that is what the itag filter guaranteed â€” so nothing needs
/// re-encoding and the export is a passthrough copy. It is why this feature does not
/// carry FFmpeg.
+ (void)mergeVideo:(NSURL *)videoURL
             audio:(NSURL *)audioURL
        completion:(void (^)(NSURL *file, NSError *error))completion {

    AVMutableComposition *composition = [AVMutableComposition composition];
    AVURLAsset *videoAsset = [AVURLAsset URLAssetWithURL:videoURL options:nil];
    AVURLAsset *audioAsset = [AVURLAsset URLAssetWithURL:audioURL options:nil];

    AVAssetTrack *videoTrack = [videoAsset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    AVAssetTrack *audioTrack = [audioAsset tracksWithMediaType:AVMediaTypeAudio].firstObject;

    if (!videoTrack) {
        completion(nil, [NSError errorWithDomain:@"AlbrhiYT" code:2 userInfo:nil]);
        return;
    }

    // Each insert gets its own error and its own check. Sharing one NSError* meant the
    // second call overwrote whatever the first reported, and neither return value was
    // read at all -- so a failed video insert exported an empty composition and the
    // result was saved as though it had worked.
    NSError *videoError = nil;
    CMTimeRange range = CMTimeRangeMake(kCMTimeZero, videoAsset.duration);

    AVMutableCompositionTrack *video =
        [composition addMutableTrackWithMediaType:AVMediaTypeVideo
                                 preferredTrackID:kCMPersistentTrackID_Invalid];

    if (![video insertTimeRange:range ofTrack:videoTrack atTime:kCMTimeZero error:&videoError]) {
        SCILogV(@"download: the picture would not go in â€” %@", videoError.localizedDescription);
        completion(nil, videoError);
        return;
    }

    BOOL soundIsIn = NO;

    if (audioTrack) {
        NSError *audioError = nil;
        AVMutableCompositionTrack *audio =
            [composition addMutableTrackWithMediaType:AVMediaTypeAudio
                                     preferredTrackID:kCMPersistentTrackID_Invalid];

        // The audio may run a fraction longer or shorter than the picture; the shorter
        // of the two is the safe range, and a mismatch here is an export failure.
        CMTime length = CMTimeMinimum(videoAsset.duration, audioAsset.duration);
        soundIsIn = [audio insertTimeRange:CMTimeRangeMake(kCMTimeZero, length)
                                   ofTrack:audioTrack
                                    atTime:kCMTimeZero
                                     error:&audioError];

        if (!soundIsIn) {
            SCILogV(@"download: the sound would not go in â€” %@", audioError.localizedDescription);
        }
    }

    NSURL *output = [NSURL fileURLWithPath:
        [NSTemporaryDirectory() stringByAppendingPathComponent:
            [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"mp4"]]];

    AVAssetExportSession *export =
        [[AVAssetExportSession alloc] initWithAsset:composition
                                         presetName:AVAssetExportPresetPassthrough];
    export.outputURL = output;
    export.outputFileType = AVFileTypeMPEG4;

    [export exportAsynchronouslyWithCompletionHandler:^{
        if (export.status == AVAssetExportSessionStatusCompleted) {
            completion(soundIsIn ? output : nil, nil);
        } else {
            SCILogV(@"download: export failed â€” %@", export.error.localizedDescription);
            completion(nil, export.error);
        }
    }];
}

#pragma mark - The run

/// Deletes a temporary file, if there is one.
///
/// 0.5.0 removed only the file it handed to Photos, so a merged save left both inputs
/// behind -- two files of tens of megabytes each, per download, sitting in the app's
/// temporary directory until iOS decided to reclaim it.
+ (void)discard:(NSURL *)file {
    if (!file) return;
    [[NSFileManager defaultManager] removeItemAtURL:file error:nil];
}

+ (void)startVideo:(SCIYTFormat *)video audio:(SCIYTFormat *)audio from:(UIViewController *)presenter {
    UIAlertController *progress =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"dl_saving")
                                            message:SCILocalized(@"dl_working")
                                     preferredStyle:UIAlertControllerStyleAlert];

    // Whether the alert has finished appearing.
    //
    // Dismissing a controller that is still animating in is ignored by UIKit, and its
    // completion block never runs -- which left an alert with no buttons on screen and
    // no way out but force-quitting YouTube. It was not a race in theory either: -fetch:
    // calls back synchronously when the URL will not parse, on the same runloop turn
    // that started the presentation.
    __block BOOL shown = NO;
    __block void (^pending)(void) = nil;

    void (^finish)(BOOL, NSString *) = ^(BOOL ok, NSString *detail) {
        dispatch_async(dispatch_get_main_queue(), ^{
            void (^close)(void) = ^{
                [progress dismissViewControllerAnimated:YES completion:^{
                    // detail is used on success too. 0.5.0 built the "saved without
                    // sound" sentence and then threw it away here, so a silent file was
                    // always reported as a clean save.
                    [self showMessage:(detail.length ? detail : SCILocalized(@"dl_saved"))
                                 from:presenter];
                }];
            };

            if (shown) {
                close();
            } else {
                // Held until the presentation finishes, rather than fired into it.
                pending = close;
            }
        });
    };

    [presenter presentViewController:progress animated:YES completion:^{
        shown = YES;
        if (pending) {
            void (^queued)(void) = pending;
            pending = nil;
            queued();
        }
    }];

    [self fetch:video.urlString extension:@"mp4" completion:^(NSURL *videoFile, NSError *error) {
        if (!videoFile) {
            finish(NO, SCILocalized(@"dl_failed"));
            return;
        }

        // Muxed already, or no audio to pair: save what arrived.
        if (!audio) {
            [self saveToPhotos:videoFile completion:^(BOOL ok, NSString *detail) {
                finish(ok, ok ? nil : detail);
            }];
            return;
        }

        [self fetch:audio.urlString extension:@"m4a" completion:^(NSURL *audioFile, NSError *audioError) {
            if (!audioFile) {
                // The picture arrived and the sound did not. Saving the silent file is
                // better than saving nothing, and the message now actually says so.
                [self saveToPhotos:videoFile completion:^(BOOL ok, NSString *detail) {
                    finish(ok, ok ? SCILocalized(@"dl_saved_silent") : detail);
                }];
                return;
            }

            [self mergeVideo:videoFile audio:audioFile completion:^(NSURL *merged, NSError *mergeError) {
                // Both inputs go, whichever way the merge went. saveToPhotos only ever
                // removes the one file it was handed.
                [self discard:audioFile];

                if (merged) {
                    [self discard:videoFile];
                    [self saveToPhotos:merged completion:^(BOOL ok, NSString *detail) {
                        finish(ok, ok ? nil : detail);
                    }];
                } else {
                    // The merge failed, so what gets saved is the picture on its own.
                    // Saying "saved" here would be a lie the user only discovers on
                    // playback.
                    [self saveToPhotos:videoFile completion:^(BOOL ok, NSString *detail) {
                        finish(ok, ok ? SCILocalized(@"dl_saved_silent") : detail);
                    }];
                }
            }];
        }];
    }];
}

///
/// Sound on its own, saved where sound can actually live.
///
/// Not Photos: it takes video and images, and an .m4a handed to it is refused. So the
/// file goes to the app's own Documents folder and the share sheet opens on it, which
/// puts it into Files, Music, a message, or anywhere else in one step.
///
/// Documents rather than the temporary directory, because a file the user chose to keep
/// must survive iOS reclaiming scratch space -- and because it is where the download
/// centre will read from next.
+ (void)startAudioOnly:(SCIYTFormat *)audio from:(UIViewController *)presenter {
    UIAlertController *progress =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"dl_saving")
                                            message:SCILocalized(@"dl_working")
                                     preferredStyle:UIAlertControllerStyleAlert];

    __block BOOL shown = NO;
    __block void (^pending)(void) = nil;

    void (^finish)(NSURL *, NSString *) = ^(NSURL *file, NSString *failure) {
        dispatch_async(dispatch_get_main_queue(), ^{
            void (^close)(void) = ^{
                [progress dismissViewControllerAnimated:YES completion:^{
                    if (!file) {
                        [self showMessage:(failure ?: SCILocalized(@"dl_failed")) from:presenter];
                        return;
                    }
                    [self shareFile:file from:presenter];
                }];
            };
            if (shown) close(); else pending = close;
        });
    };

    [presenter presentViewController:progress animated:YES completion:^{
        shown = YES;
        if (pending) { void (^queued)(void) = pending; pending = nil; queued(); }
    }];

    [self fetch:audio.urlString extension:@"m4a" completion:^(NSURL *file, NSError *error) {
        if (!file) {
            finish(nil, SCILocalized(@"dl_failed"));
            return;
        }

        NSString *title = [SCIYTDiagnostics lastVideoTitle] ?: @"audio";
        NSURL *kept = [self keep:file named:title extension:@"m4a"];
        finish(kept ?: file, nil);
    }];
}

/// Moves a finished file into Documents under a readable name.
+ (NSURL *)keep:(NSURL *)file named:(NSString *)title extension:(NSString *)extension {
    NSString *documents = [NSSearchPathForDirectoriesInDomains(
        NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    if (!documents) return nil;

    NSString *folder = [documents stringByAppendingPathComponent:@"Albrhi"];
    [[NSFileManager defaultManager] createDirectoryAtPath:folder
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];

    // Anything a file system objects to, replaced. A YouTube title can contain slashes,
    // colons and newlines, and a path built from one unfiltered simply fails to write.
    // The control characters are added separately rather than written into the literal:
    // Objective-C has no multi-line string, and this project has corrupted source files
    // three times by putting an escape sequence through a shell heredoc. Once more here.
    NSMutableCharacterSet *illegal =
        [NSMutableCharacterSet characterSetWithCharactersInString:@"/\\?%*|\"<>:"];
    [illegal formUnionWithCharacterSet:[NSCharacterSet controlCharacterSet]];
    [illegal formUnionWithCharacterSet:[NSCharacterSet newlineCharacterSet]];
    NSString *safe = [[title componentsSeparatedByCharactersInSet:illegal]
        componentsJoinedByString:@" "];

    safe = [safe stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (safe.length > 80) safe = [safe substringToIndex:80];
    if (!safe.length) safe = @"audio";

    NSString *path = [folder stringByAppendingPathComponent:
        [safe stringByAppendingPathExtension:extension]];

    // A second download of the same track must not fail on the name already being taken.
    NSUInteger attempt = 2;
    while ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        path = [folder stringByAppendingPathComponent:
            [[NSString stringWithFormat:@"%@ (%lu)", safe, (unsigned long)attempt++]
                stringByAppendingPathExtension:extension]];
    }

    NSError *error = nil;
    NSURL *destination = [NSURL fileURLWithPath:path];
    if (![[NSFileManager defaultManager] moveItemAtURL:file toURL:destination error:&error]) {
        SCILogV(@"download: could not keep the file â€” %@", error.localizedDescription);
        return nil;
    }
    return destination;
}

+ (void)shareFile:(NSURL *)file from:(UIViewController *)presenter {
    UIActivityViewController *share =
        [[UIActivityViewController alloc] initWithActivityItems:@[file]
                                          applicationActivities:nil];

    // An unanchored sheet is fatal on iPad, the same as the quality one.
    share.popoverPresentationController.sourceView = presenter.view;
    share.popoverPresentationController.sourceRect =
        CGRectMake(CGRectGetMidX(presenter.view.bounds), CGRectGetMidY(presenter.view.bounds), 1, 1);

    [presenter presentViewController:share animated:YES completion:nil];
}

+ (void)saveToPhotos:(NSURL *)file completion:(void (^)(BOOL ok, NSString *detail))completion {
    // Every answer below leaves on the main queue, and that is the whole of the crash that
    // arrived the instant a download first reached 100%.
    //
    // Photos calls its handlers on a thread of its own choosing. Both of them, and the
    // caller does not merely note the result -- it dismisses the progress sheet and puts
    // an alert up. That is UIKit from whatever thread the framework happened to pick, and
    // UIKit off the main thread does not fail politely.
    //
    // It looked like a download bug because it only ever happened at the end. It is a
    // threading bug, and it was there before any of this could reach the end at all.
    void (^done)(BOOL, NSString *) = ^(BOOL ok, NSString *detail) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(ok, detail); });
    };

    // Asking for access the host app never declared a reason for is not refused -- iOS
    // terminates the process on the spot, before the handler above ever runs.
    //
    // The app that has to declare it is YouTube, not this tweak: the keys come from the
    // main bundle's Info.plist and a tweak has no say in what is in it. YouTube declares
    // *reading* the library, because it has a picker. Adding to it is a separate key it
    // has no reason to carry. So this is checked rather than discovered from a crash, and
    // when it is missing the file is kept instead of thrown away.
    NSBundle *host = [NSBundle mainBundle];
    if (![host objectForInfoDictionaryKey:@"NSPhotoLibraryAddUsageDescription"] &&
        ![host objectForInfoDictionaryKey:@"NSPhotoLibraryUsageDescription"]) {
        SCILogV(@"download: the app declares no reason to add to Photos â€” keeping the file");
        done(NO, SCILocalized(@"dl_no_photos_access"));
        return;
    }

    [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly
                                               handler:^(PHAuthorizationStatus status) {
        if (status != PHAuthorizationStatusAuthorized && status != PHAuthorizationStatusLimited) {
            done(NO, SCILocalized(@"dl_no_permission"));
            return;
        }

        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:file];
        } completionHandler:^(BOOL success, NSError *error) {
            if (!success) SCILogV(@"download: Photos refused it â€” %@", error.localizedDescription);

            // The temporary file has served its purpose -- but only if it reached Photos.
            // Removing it on failure too is how a download that worked ended as nothing at
            // all, with no second chance to hand it anywhere else.
            if (success) [[NSFileManager defaultManager] removeItemAtURL:file error:nil];

            done(success, success ? nil : SCILocalized(@"dl_failed"));
        }];
    }];
}

+ (void)showMessage:(NSString *)message from:(UIViewController *)presenter {
    if (!message.length) return;

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"dl_title")
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:SCILocalized(@"ok")
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

@end
