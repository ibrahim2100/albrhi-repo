#import "SCIYTDirect.h"
#import <ImageIO/ImageIO.h>
#import "SCIYTFragments.h"
#import "SCIYTSubtitles.h"
#import "SCIYTAV1Convert.h"
#import "SCIYTParts.h"
#import "../../SCILog.h"
#import "../../Localization/SCILocalize.h"
#import "../../Diagnostics/SCIYTDiagnostics.h"
#import "../../Prefs.h"

static NSString * const kSCIDirectVisitorKey = @"sci_yt_direct_visitor";
static const NSTimeInterval kSCIDirectVisitorLifetime = 7 * 24 * 60 * 60;

/// A chunk is asked for as its own URL, `&range=START-END`, which googlevideo answers with
/// exactly those bytes and a plain 200 -- measured, from this project's build machine. That is
/// what lets the existing parallel background fetcher do the work with no new transport.
static const long long kSCIDirectChunk = 8 * 1024 * 1024;

static NSString * const kSCIDirectAgent =
    @"Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 "
     "(KHTML, like Gecko) Version/26.0 Safari/605.1.15";

static NSMutableSet<NSString *> *sFailed = nil;

static NSDictionary *SCIDirectContext(NSString *visitor) {
    NSMutableDictionary *client = [@{
        @"clientName": @"VISIONOS", @"clientVersion": @"1.02",
        @"osName": @"visionOS", @"osVersion": @"26.5.23O471",
        @"deviceMake": @"Apple", @"deviceModel": @"RealityDevice17,1",
        @"userAgent": kSCIDirectAgent,
        @"hl": @"en", @"gl": @"US",
    } mutableCopy];
    if (visitor.length) client[@"visitorData"] = visitor;
    return @{@"client": client};
}

@implementation SCIYTDirect

+ (void)initialize {
    if (self == [SCIYTDirect class]) sFailed = [NSMutableSet set];
}

+ (BOOL)hasFailedForVideo:(NSString *)videoID {
    if (!videoID.length) return NO;
    @synchronized (sFailed) { return [sFailed containsObject:videoID]; }
}

+ (void)rememberFailure:(NSString *)videoID {
    if (!videoID.length) return;
    @synchronized (sFailed) { [sFailed addObject:videoID]; }
}

+ (NSURLSession *)session {
    static NSURLSession *session;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        // No cookies and no cache: the request is about one video, asked as a different client,
        // and carrying the signed-in session would make it a request about this account.
        config.HTTPCookieStorage = nil;
        config.URLCache = nil;
        config.timeoutIntervalForRequest = 15;
        config.timeoutIntervalForResource = 30;
        session = [NSURLSession sessionWithConfiguration:config];
    });
    return session;
}

+ (NSMutableURLRequest *)requestFor:(NSString *)path body:(NSDictionary *)body visitor:(NSString *)visitor {
    NSString *address = [@"https://youtubei.googleapis.com/youtubei/v1/" stringByAppendingString:path];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:address]];
    request.HTTPMethod = @"POST";
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:kSCIDirectAgent forHTTPHeaderField:@"User-Agent"];
    if (visitor.length) [request setValue:visitor forHTTPHeaderField:@"X-Goog-Visitor-Id"];
    return request;
}

/// A visitor id from `/guide`, kept a week. Answered to whoever asks, and tied to nothing.
+ (void)visitorRefreshing:(BOOL)refresh completion:(void (^)(NSString *visitor))completion {
    NSDictionary *cached = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kSCIDirectVisitorKey];
    if (!refresh && cached) {
        NSString *value = cached[@"id"];
        NSNumber *time = cached[@"time"];
        if ([value isKindOfClass:[NSString class]] && value.length && [time isKindOfClass:[NSNumber class]] &&
            [NSDate date].timeIntervalSince1970 - time.doubleValue < kSCIDirectVisitorLifetime) {
            completion(value);
            return;
        }
    }

    NSMutableURLRequest *request = [self requestFor:@"guide?prettyPrint=false&fields=responseContext.visitorData"
                                               body:@{@"context": SCIDirectContext(nil)} visitor:nil];
    [[[self session] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        id json = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        id responseContext = [json isKindOfClass:[NSDictionary class]] ? json[@"responseContext"] : nil;
        id value = [responseContext isKindOfClass:[NSDictionary class]] ? responseContext[@"visitorData"] : nil;
        NSString *visitor = [value isKindOfClass:[NSString class]] && [value length] ? value : nil;
        if (visitor) {
            [[NSUserDefaults standardUserDefaults] setObject:@{@"id": visitor, @"time": @([NSDate date].timeIntervalSince1970)}
                                                      forKey:kSCIDirectVisitorKey];
        }
        completion(visitor);
    }] resume];
}

// host-test:begin direct
// MARK: - Choosing formats

static NSString *SCIDirectCodec(NSDictionary *format) {
    NSString *mime = format[@"mimeType"];
    if (![mime isKindOfClass:[NSString class]]) return @"";
    NSRange r = [mime rangeOfString:@"codecs=\""];
    if (r.location == NSNotFound) return @"";
    NSString *rest = [mime substringFromIndex:NSMaxRange(r)];
    NSRange q = [rest rangeOfString:@"\""];
    return q.location == NSNotFound ? rest : [rest substringToIndex:q.location];
}

static long long SCIDirectNumber(id value) {
    return ([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSNumber class]]) ? [value longLongValue] : 0;
}

/// The formats that can be written into an .mp4 untouched, already split by kind.
+ (void)sortFormats:(NSArray *)all video:(NSMutableArray<NSDictionary *> *)videos av1:(NSMutableArray<NSDictionary *> *)av1 audio:(NSDictionary **)audio {
    NSDictionary *bestAudio = nil;

    for (NSDictionary *format in all) {
        if (![format isKindOfClass:[NSDictionary class]]) continue;
        NSString *url = format[@"url"];
        NSString *mime = format[@"mimeType"];
        if (![url isKindOfClass:[NSString class]] || ![url hasPrefix:@"http"]) continue;
        if (![mime isKindOfClass:[NSString class]]) continue;
        if (SCIDirectNumber(format[@"contentLength"]) <= 0) continue;

        NSString *codec = SCIDirectCodec(format);

        if ([mime hasPrefix:@"video/mp4"] && [codec hasPrefix:@"avc1"]) {
            [videos addObject:format];
        } else if ([mime hasPrefix:@"video/mp4"] && [codec hasPrefix:@"av01"]) {
            // AV1 in fragmented MP4 -- the only way YouTube serves 1440p and 4K as something this
            // route can write. (The same resolutions in VP9 are WebM, which it cannot.)
            [av1 addObject:format];
        } else if ([mime hasPrefix:@"audio/mp4"] && [codec hasPrefix:@"mp4a.40.2"]) {
            // Not the dynamic-range-compressed copy, and the default language when a video has
            // several dubbed ones -- the track a person who just pressed play would be hearing.
            if ([format[@"isDrc"] boolValue]) continue;
            NSDictionary *track = format[@"audioTrack"];
            if ([track isKindOfClass:[NSDictionary class]] && track[@"audioIsDefault"] && ![track[@"audioIsDefault"] boolValue]) continue;

            if (!bestAudio || SCIDirectNumber(format[@"bitrate"]) > SCIDirectNumber(bestAudio[@"bitrate"])) bestAudio = format;
        }
    }
    *audio = bestAudio;
}

/// Every sound track served, one per language, the original first -- or nothing when there is only
/// one, because then there is nothing to choose.
///
/// A dubbed video serves the *same* AAC under several `audioTrack` ids (`en-US.4`, `ar.3`, `de.3`...),
/// each with its own bitrates; the highest-bitrate non-DRC copy of each is taken. The prefix of the id
/// before the dot is the language tag the file is labelled with.
+ (NSArray<NSDictionary *> *)audioTracksFromFormats:(NSArray *)all {
    NSMutableDictionary<NSString *, NSDictionary *> *best = [NSMutableDictionary dictionary];
    NSMutableArray<NSString *> *order = [NSMutableArray array];

    for (NSDictionary *format in all) {
        if (![format isKindOfClass:[NSDictionary class]]) continue;
        NSString *url = format[@"url"], *mime = format[@"mimeType"];
        if (![url isKindOfClass:[NSString class]] || ![url hasPrefix:@"http"] || ![mime isKindOfClass:[NSString class]]) continue;
        if (SCIDirectNumber(format[@"contentLength"]) <= 0) continue;
        if (![mime hasPrefix:@"audio/mp4"] || ![SCIDirectCodec(format) hasPrefix:@"mp4a.40.2"]) continue;
        if ([format[@"isDrc"] boolValue]) continue;

        NSDictionary *track = format[@"audioTrack"];
        NSString *identifier = [track isKindOfClass:[NSDictionary class]] ? track[@"id"] : nil;
        if (![identifier isKindOfClass:[NSString class]] || !identifier.length) continue;

        NSDictionary *held = best[identifier];
        if (!held) [order addObject:identifier];
        if (!held || SCIDirectNumber(format[@"bitrate"]) > SCIDirectNumber(held[@"bitrate"])) best[identifier] = format;
    }
    if (order.count < 2) return @[];

    NSMutableArray<NSDictionary *> *tracks = [NSMutableArray array];
    for (NSString *identifier in order) {
        NSDictionary *format = best[identifier];
        NSDictionary *track = format[@"audioTrack"];
        NSString *name = [track[@"displayName"] isKindOfClass:[NSString class]] ? track[@"displayName"] : identifier;
        NSString *lang = [identifier componentsSeparatedByString:@"."].firstObject;
        [tracks addObject:@{@"id": identifier, @"lang": lang ?: @"", @"name": name, @"url": format[@"url"],
                            @"bytes": @(SCIDirectNumber(format[@"contentLength"])),
                            @"default": @([track[@"audioIsDefault"] boolValue])}];
    }

    // The original first: it is what plays unasked and what is always kept. When none is marked,
    // the order YouTube served them in stands.
    NSMutableArray<NSDictionary *> *ordered = [NSMutableArray array];
    for (NSDictionary *t in tracks) if ([t[@"default"] boolValue]) { [ordered addObject:t]; break; }
    for (NSDictionary *t in tracks) if (![ordered containsObject:t]) [ordered addObject:t];
    return ordered;
}

/// The caption tracks of a player response's `playerCaptionsTracklistRenderer`, written-by-people
/// before automatic ones, one per language and kind.
+ (NSArray<NSDictionary *> *)captionTracksFromRenderer:(NSDictionary *)renderer {
    NSArray *raw = [renderer isKindOfClass:[NSDictionary class]] ? renderer[@"captionTracks"] : nil;
    if (![raw isKindOfClass:[NSArray class]]) return @[];

    NSMutableArray<NSDictionary *> *manual = [NSMutableArray array], *automatic = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];

    for (NSDictionary *track in raw) {
        if (![track isKindOfClass:[NSDictionary class]]) continue;
        NSString *url = track[@"baseUrl"], *lang = track[@"languageCode"];
        if (![url isKindOfClass:[NSString class]] || ![url hasPrefix:@"http"]) continue;
        if (![lang isKindOfClass:[NSString class]] || !lang.length) continue;

        BOOL isAuto = [track[@"kind"] isKindOfClass:[NSString class]] && [track[@"kind"] isEqualToString:@"asr"];
        NSString *identifier = isAuto ? [lang stringByAppendingString:@"-auto"] : lang;
        if ([seen containsObject:identifier]) continue;
        [seen addObject:identifier];

        NSDictionary *nameObject = track[@"name"];
        NSString *name = nil;
        if ([nameObject isKindOfClass:[NSDictionary class]]) {
            name = [nameObject[@"simpleText"] isKindOfClass:[NSString class]] ? nameObject[@"simpleText"] : nil;
            if (!name && [nameObject[@"runs"] isKindOfClass:[NSArray class]]) {
                NSMutableString *joined = [NSMutableString string];
                for (NSDictionary *run in nameObject[@"runs"]) {
                    if ([run isKindOfClass:[NSDictionary class]] && [run[@"text"] isKindOfClass:[NSString class]]) [joined appendString:run[@"text"]];
                }
                name = joined.length ? joined : nil;
            }
        }

        [(isAuto ? automatic : manual) addObject:@{@"id": identifier, @"lang": lang, @"name": name ?: lang, @"url": url, @"auto": @(isAuto)}];
    }
    return [manual arrayByAddingObjectsFromArray:automatic];
}

/// The qualities offered for a set of H.264 (and, when switched on, AV1) video formats and one
/// audio format: **one entry per height, the highest bitrate of each** (which is the 60 fps copy
/// where there is one), tallest first. Pure -- no request, no preference -- so the order and the
/// de-duplication can be run on this Mac against `tests/host/Test_Direct.m`.
+ (NSArray<SCIHLSVariant *> *)ladderForVideos:(NSMutableArray<NSDictionary *> *)videos
                                        audio:(NSDictionary *)audio
                                      videoID:(NSString *)videoID {
    [videos sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        long long ha = SCIDirectNumber(a[@"height"]), hb = SCIDirectNumber(b[@"height"]);
        if (ha != hb) return ha > hb ? NSOrderedAscending : NSOrderedDescending;
        return SCIDirectNumber(a[@"bitrate"]) > SCIDirectNumber(b[@"bitrate"]) ? NSOrderedAscending : NSOrderedDescending;
    }];

    NSMutableArray<SCIHLSVariant *> *variants = [NSMutableArray array];
    NSMutableSet<NSNumber *> *heights = [NSMutableSet set];
    for (NSDictionary *format in videos) {
        NSNumber *height = @(SCIDirectNumber(format[@"height"]));
        if ([heights containsObject:height]) continue;
        [heights addObject:height];

        SCIHLSVariant *variant = [[SCIHLSVariant alloc] init];
        variant.height = height.integerValue;
        variant.width = (NSInteger)SCIDirectNumber(format[@"width"]);
        variant.codecs = [NSString stringWithFormat:@"%@,%@", SCIDirectCodec(format), SCIDirectCodec(audio)];
        variant.bandwidth = SCIDirectNumber(format[@"bitrate"]) + SCIDirectNumber(audio[@"bitrate"]);
        variant.directVideoURL = format[@"url"];
        variant.directVideoBytes = SCIDirectNumber(format[@"contentLength"]);
        variant.directAudioURL = audio[@"url"];
        variant.directAudioBytes = SCIDirectNumber(audio[@"contentLength"]);
        variant.directVideoID = videoID;
        [variants addObject:variant];
    }

    return variants;
}
// host-test:end direct

// MARK: - Asking

+ (void)variantsForVideo:(NSString *)videoID
              completion:(void (^)(NSArray<SCIHLSVariant *> *, NSString *))completion {
    void (^finish)(NSArray *, NSString *) = ^(NSArray *variants, NSString *failure) {
        if (!variants.count) {
            [self rememberFailure:videoID];
            [SCIYTDiagnostics recordStreamAttempt:[NSString stringWithFormat:@"direct (%@): %@", videoID, failure ?: @"nothing"]];
        }
        dispatch_async(dispatch_get_main_queue(), ^{ completion(variants, failure); });
    };

    if (!videoID.length) { finish(@[], SCILocalized(@"dl_why_no_data")); return; }

    [self askForVideo:videoID attempt:0 completion:^(NSDictionary *streamingData, NSDictionary *captions, NSDictionary *details, NSString *failure) {
        if (!streamingData) { finish(@[], failure); return; }

        NSMutableArray<NSDictionary *> *videos = [NSMutableArray array];
        NSMutableArray<NSDictionary *> *av1 = [NSMutableArray array];
        NSDictionary *audio = nil;
        [self sortFormats:streamingData[@"adaptiveFormats"] video:videos av1:av1 audio:&audio];

        if (!audio) { finish(@[], @"no AAC track served"); return; }
        if (!videos.count) { finish(@[], @"no H.264 picture served"); return; }

        // 1440p and 4K, only when asked for (SCIPrefOffer4K, off): above 1080p, and joined to the
        // H.264 list *before* the sort below, so one rule orders and de-duplicates both -- one entry
        // per height, best bitrate, tallest first. **Not mixed in at 1080p and below**: there H.264 is
        // what plays everywhere, and an AV1 copy would only be a smaller file fewer things can open.
        if (SCIPrefEnabled(SCIPrefOffer4K)) {
            for (NSDictionary *format in av1) {
                if (SCIDirectNumber(format[@"height"]) > 1080) [videos addObject:format];
            }
            [SCIYTDiagnostics recordStreamAttempt:[NSString stringWithFormat:
                @"direct (%@): 4K switch on, %lu AV1 formats served", videoID, (unsigned long)av1.count]];
        }

        NSMutableArray<SCIHLSVariant *> *variants = [[self ladderForVideos:videos audio:audio videoID:videoID] mutableCopy];

        // What can be chosen besides the quality, attached to every row because it belongs to the
        // video and not to a quality: other languages of the sound, and the captions.
        NSArray<NSDictionary *> *soundTracks = [self audioTracksFromFormats:streamingData[@"adaptiveFormats"]];
        NSArray<NSDictionary *> *captionTracks = [self captionTracksFromRenderer:captions];
        NSString *name = [details[@"title"] isKindOfClass:[NSString class]] ? details[@"title"] : nil;
        NSString *channel = [details[@"author"] isKindOfClass:[NSString class]] ? details[@"author"] : nil;
        for (SCIHLSVariant *variant in variants) {
            variant.directAudioTracks = soundTracks;
            variant.directCaptionTracks = captionTracks;
            variant.directTitle = name;
            variant.directAuthor = channel;
        }
        [SCIYTDiagnostics recordStreamAttempt:[NSString stringWithFormat:
            @"direct (%@): %lu sound track(s), %lu caption track(s) offered", videoID,
            (unsigned long)soundTracks.count, (unsigned long)captionTracks.count]];

        [SCIYTDiagnostics recordStreamAttempt:[NSString stringWithFormat:
            @"direct (%@): %lu qualities, best %ldp, audio %.1f MB", videoID, (unsigned long)variants.count,
            (long)variants.firstObject.height, (double)SCIDirectNumber(audio[@"contentLength"]) / 1048576.0]];

        finish(variants, nil);
    }];
}

/// One player request. A second attempt takes a fresh visitor id, because a stale one is the
/// usual reason an otherwise healthy request is turned away.
+ (void)askForVideo:(NSString *)videoID attempt:(NSInteger)attempt
         completion:(void (^)(NSDictionary *streamingData, NSDictionary *captions, NSDictionary *details, NSString *failure))completion {

    [self visitorRefreshing:(attempt > 0) completion:^(NSString *visitor) {
        NSDictionary *body = @{@"context": SCIDirectContext(visitor), @"videoId": videoID,
                               @"contentCheckOk": @YES, @"racyCheckOk": @YES};
        NSMutableURLRequest *request = [self requestFor:@"player?prettyPrint=false" body:body visitor:visitor];

        [[[self session] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)response statusCode] : 0;
            NSDictionary *json = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
            if (![json isKindOfClass:[NSDictionary class]]) json = nil;

            NSDictionary *streamingData = json[@"streamingData"];
            if ([streamingData isKindOfClass:[NSDictionary class]] && [streamingData[@"adaptiveFormats"] count]) {
                NSDictionary *captions = json[@"captions"][@"playerCaptionsTracklistRenderer"];
                NSDictionary *details = json[@"videoDetails"];
                completion(streamingData, [captions isKindOfClass:[NSDictionary class]] ? captions : nil,
                           [details isKindOfClass:[NSDictionary class]] ? details : nil, nil);
                return;
            }

            if (attempt < 1) { [self askForVideo:videoID attempt:attempt + 1 completion:completion]; return; }

            NSDictionary *playability = json[@"playabilityStatus"];
            NSString *why = nil;
            if ([playability isKindOfClass:[NSDictionary class]]) {
                NSString *s = playability[@"status"], *r = playability[@"reason"];
                why = [NSString stringWithFormat:@"%@%@", [s isKindOfClass:[NSString class]] ? s : @"",
                       [r isKindOfClass:[NSString class]] ? [@": " stringByAppendingString:r] : @""];
            }
            completion(nil, nil, nil, why.length ? why : (error.localizedDescription ?: [NSString stringWithFormat:@"HTTP %ld, no formats", (long)status]));
        }] resume];
    }];
}

// MARK: - Fetching

/// `&range=a-b` addresses covering `bytes`, in order.
static NSArray<NSString *> *SCIDirectChunks(NSString *url, long long bytes) {
    NSMutableArray *list = [NSMutableArray array];
    for (long long start = 0; start < bytes; start += kSCIDirectChunk) {
        long long end = MIN(start + kSCIDirectChunk, bytes) - 1;
        [list addObject:[url stringByAppendingFormat:@"&range=%lld-%lld", start, end]];
    }
    return list;
}

/// How many bytes each of those chunks is, in the same order -- what a resumed download checks the
/// parts already on disk against.
static NSArray<NSNumber *> *SCIDirectChunkSizes(long long bytes) {
    NSMutableArray *list = [NSMutableArray array];
    for (long long start = 0; start < bytes; start += kSCIDirectChunk) {
        [list addObject:@(MIN(start + kSCIDirectChunk, bytes) - start)];
    }
    return list;
}

static long long SCIDirectFileSize(NSURL *file) {
    return [[[NSFileManager defaultManager] attributesOfItemAtPath:file.path error:nil] fileSize];
}

/// Fetches the video (when given) and the sound together, joins each into a scratch file and
/// hands both back. A file whose length is not the length YouTube declared is a fetch that
/// lost a piece, and is refused here rather than discovered as a glitch halfway through playback.
+ (void)fetchVideoURL:(NSString *)videoURL videoBytes:(long long)videoBytes
             audioURL:(NSString *)audioURL audioBytes:(long long)audioBytes
               extras:(NSArray<NSDictionary *> *)extras
            resumeKey:(NSString *)resumeKey
             progress:(void (^)(double))progress
           completion:(void (^)(NSURL *video, NSURL *audio, NSArray<NSURL *> *extraFiles, NSString *failure))completion {

    NSArray<NSString *> *videoChunks = videoURL ? SCIDirectChunks(videoURL, videoBytes) : @[];
    NSArray<NSString *> *audioChunks = SCIDirectChunks(audioURL, audioBytes);

    // Each further language is its own run of chunks after the main sound, in the order given, so
    // one parallel fetch carries everything and the pieces are cut apart again by count.
    NSMutableArray<NSArray<NSString *> *> *extraChunks = [NSMutableArray array];
    NSMutableArray<NSString *> *all = [NSMutableArray arrayWithArray:videoChunks];
    [all addObjectsFromArray:audioChunks];

    // The expected size of every part, in the same order: what a resumed run compares the parts
    // already on disk with, so bytes from a different plan are not mistaken for this one's.
    NSMutableArray<NSNumber *> *sizes = [NSMutableArray array];
    if (videoURL) [sizes addObjectsFromArray:SCIDirectChunkSizes(videoBytes)];
    [sizes addObjectsFromArray:SCIDirectChunkSizes(audioBytes)];
    for (NSDictionary *extra in extras) {
        NSArray<NSString *> *chunks = SCIDirectChunks(extra[@"url"], [extra[@"bytes"] longLongValue]);
        [extraChunks addObject:chunks];
        [all addObjectsFromArray:chunks];
        [sizes addObjectsFromArray:SCIDirectChunkSizes([extra[@"bytes"] longLongValue])];
    }

    [SCIYTParts fetch:all sizes:sizes runIdentifier:resumeKey progress:progress completion:^(NSArray<NSURL *> *ordered, NSURL *folder, NSString *error) {
        if (!ordered) { completion(nil, nil, nil, error ?: SCILocalized(@"dl_failed")); return; }

        // Joining reads every part back, which is real work for a long video; off the main queue.
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            NSURL *video = nil, *audio = nil;
            NSMutableArray<NSURL *> *extraFiles = [NSMutableArray array];
            NSUInteger at = 0;

            if (videoChunks.count) {
                video = [SCIYTParts join:[ordered subarrayWithRange:NSMakeRange(at, videoChunks.count)]
                               extension:@"mp4" folder:nil];
            }
            at += videoChunks.count;
            audio = [SCIYTParts join:[ordered subarrayWithRange:NSMakeRange(at, audioChunks.count)]
                           extension:@"m4a" folder:nil];
            at += audioChunks.count;

            BOOL extrasOK = YES;
            for (NSUInteger k = 0; k < extras.count; k++) {
                NSUInteger count = extraChunks[k].count;
                NSURL *file = [SCIYTParts join:[ordered subarrayWithRange:NSMakeRange(at, count)] extension:@"m4a" folder:nil];
                at += count;
                if (file && SCIDirectFileSize(file) == [extras[k][@"bytes"] longLongValue]) [extraFiles addObject:file]; else extrasOK = NO;
            }

            // Every join has read what it needed. The first of them used to remove the folder, and
            // the ones after it then found their parts gone: a download with a second language
            // failed as "incomplete" every time.
            [[NSFileManager defaultManager] removeItemAtURL:folder error:nil];

            BOOL sound = audio && SCIDirectFileSize(audio) == audioBytes;
            BOOL picture = !videoChunks.count || (video && SCIDirectFileSize(video) == videoBytes);
            if (!sound || !picture || !extrasOK) {
                if (video) [[NSFileManager defaultManager] removeItemAtURL:video error:nil];
                if (audio) [[NSFileManager defaultManager] removeItemAtURL:audio error:nil];
                for (NSURL *file in extraFiles) [[NSFileManager defaultManager] removeItemAtURL:file error:nil];
                [SCIYTDiagnostics recordStreamAttempt:[NSString stringWithFormat:
                    @"direct: fetched sizes %lld/%lld (video) %lld/%lld (audio)%@ do not match what was declared",
                    video ? SCIDirectFileSize(video) : 0LL, videoBytes, audio ? SCIDirectFileSize(audio) : 0LL, audioBytes,
                    extrasOK ? @"" : @", and an extra sound track is short"]];
                dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, nil, nil, SCILocalized(@"dl_direct_incomplete")); });
                return;
            }
            dispatch_async(dispatch_get_main_queue(), ^{ completion(video, audio, extraFiles, nil); });
        });
    }];
}

/// The chosen captions, fetched as WebVTT and read into cues. A caption that cannot be fetched or
/// holds nothing is left out and the others go ahead -- a missing subtitle is not a failed download.
+ (void)fetchCaptions:(NSArray<NSDictionary *> *)tracks
           completion:(void (^)(NSArray<NSDictionary *> *subtitles))completion {
    if (!tracks.count) { completion(@[]); return; }

    NSMutableArray *results = [NSMutableArray arrayWithCapacity:tracks.count];
    for (NSUInteger i = 0; i < tracks.count; i++) [results addObject:[NSNull null]];
    dispatch_group_t group = dispatch_group_create();

    for (NSUInteger i = 0; i < tracks.count; i++) {
        NSDictionary *track = tracks[i];
        NSString *address = [track[@"url"] stringByAppendingString:@"&fmt=vtt"];
        NSURL *url = [NSURL URLWithString:address];
        if (!url) continue;

        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        [request setValue:kSCIDirectAgent forHTTPHeaderField:@"User-Agent"];

        dispatch_group_enter(group);
        [[[self session] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSString *text = data.length ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
            NSArray *cues = text ? [SCIYTSubtitles cuesFromVTT:text] : @[];
            if (cues.count) {
                @synchronized (results) { results[i] = @{@"lang": track[@"lang"] ?: @"", @"cues": cues}; }
            } else {
                [SCIYTDiagnostics recordStreamAttempt:[NSString stringWithFormat:@"direct: caption %@ gave no cues (%@)",
                    track[@"id"], error.localizedDescription ?: @"empty"]];
            }
            dispatch_group_leave(group);
        }] resume];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSMutableArray *kept = [NSMutableArray array];
        for (id item in results) if (![item isKindOfClass:[NSNull class]]) [kept addObject:item];
        completion(kept);
    });
}

/// The video's cover as JPEG bytes, or nil. Asked for in the two sizes the cover cache uses, for the
/// same reason: YouTube answers a missing "maxres" with a small grey placeholder, not a 404, so the
/// width is the test. Blocking, with a short timeout -- called from the merge's own queue, and a cover
/// that does not arrive costs the cover, never the download.
static NSData *SCIDirectCover(NSString *videoID) {
    if (!videoID.length) return nil;
    for (NSString *name in @[@"maxresdefault", @"hqdefault"]) {
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://i.ytimg.com/vi/%@/%@.jpg", videoID, name]];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:8];

        __block NSData *data = nil;
        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *body, NSURLResponse *response, NSError *error) {
            if ([(NSHTTPURLResponse *)response statusCode] == 200) data = body;
            dispatch_semaphore_signal(done);
        }] resume];
        dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC));

        CGImageSourceRef source = data.length ? CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL) : NULL;
        NSDictionary *properties = source ? CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL)) : nil;
        if (source) CFRelease(source);
        if ([properties[(NSString *)kCGImagePropertyPixelWidth] integerValue] >= 200) return data;
    }
    return nil;
}

/// What is written into the file about the video: its title and its channel, and for a song the cover.
static NSDictionary *SCIDirectTags(SCIHLSVariant *variant, BOOL withCover) {
    NSMutableDictionary *tags = [NSMutableDictionary dictionary];
    if (variant.directTitle.length) tags[@"title"] = variant.directTitle;
    if (variant.directAuthor.length) tags[@"artist"] = variant.directAuthor;
    if (withCover) {
        NSData *cover = SCIDirectCover(variant.directVideoID);
        if (cover) tags[@"artwork"] = cover;
    }
    return tags;
}

+ (void)downloadVariant:(SCIHLSVariant *)variant
               progress:(void (^)(double))progress
             completion:(void (^)(NSURL *, NSString *))completion {

    // Only what was ticked, and only when it is something the video really offers -- anything else
    // is a stale selection and is ignored rather than trusted.
    NSArray<NSDictionary *> *extras = variant.chosenExtraAudios ?: @[];
    NSArray<NSDictionary *> *captions = variant.chosenCaptions ?: @[];
    NSString *mainLanguage = nil;
    for (NSDictionary *track in variant.directAudioTracks) if ([track[@"default"] boolValue]) mainLanguage = track[@"lang"];

    BOOL isAV1 = [variant.codecs.lowercaseString containsString:@"av01"];
    BOOL converting = isAV1 && SCIPrefEnabled(SCIPrefConvertAV1);
    if (converting && (extras.count || captions.count)) {
        // The conversion path writes one picture and one sound; extras would be dropped silently, so say so.
        [SCIYTDiagnostics recordStreamAttempt:@"direct: extra sound/captions not written — AV1 is being converted to HEVC"];
        extras = @[]; captions = @[];
    }

    [self fetchVideoURL:variant.directVideoURL videoBytes:variant.directVideoBytes
               audioURL:variant.directAudioURL audioBytes:variant.directAudioBytes
                 extras:extras
              resumeKey:variant.resumeKey
               progress:^(double fraction) { if (progress) progress(fraction * 0.93); }
             completion:^(NSURL *video, NSURL *audio, NSArray<NSURL *> *extraFiles, NSString *failure) {
        if (!video || !audio) {
            [self rememberFailure:variant.directVideoID];
            completion(nil, failure);
            return;
        }

        void (^cleanup)(void) = ^{
            [[NSFileManager defaultManager] removeItemAtURL:video error:nil];
            [[NSFileManager defaultManager] removeItemAtURL:audio error:nil];
            for (NSURL *file in extraFiles) [[NSFileManager defaultManager] removeItemAtURL:file error:nil];
        };

        void (^merged)(NSURL *, NSString *) = ^(NSURL *output, NSString *why) {
            cleanup();
            if (!output) [self rememberFailure:variant.directVideoID];
            if (progress && output) progress(1.0);
            completion(output, why);
        };

        // AV1 turned into HEVC for a phone that cannot play AV1 -- only when asked for. The bar
        // spends its first tenth on the download and the rest on the conversion, which is where the
        // time goes; and the screen is kept awake, because the work has to run in the foreground
        // and a phone that locks mid-conversion has stopped doing it.
        if (converting) {
            UIApplication *app = [UIApplication sharedApplication];
            BOOL wasIdleDisabled = app.idleTimerDisabled;
            app.idleTimerDisabled = YES;

            [SCIYTAV1Convert convertVideo:video audio:audio
                                 progress:^(double fraction) { if (progress) progress(0.1 + fraction * 0.9); }
                               completion:^(NSURL *converted, NSString *failure) {
                app.idleTimerDisabled = wasIdleDisabled;

                if (converted) { merged(converted, nil); return; }

                // A conversion that cannot finish must not cost the download: the AV1 is intact in
                // the two files, so it is written untouched instead, and the report says why.
                SCILogV(@"direct: conversion failed (%@), saving the AV1 as it is", failure);
                [SCIYTDiagnostics recordStreamAttempt:@"av1→hevc: falling back to the untouched AV1 file"];
                [SCIYTFragments mergeVideo:video audio:audio completion:merged];
            }];
            return;
        }

        if (!extraFiles.count && !captions.count) {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                NSDictionary *tags = SCIDirectTags(variant, NO);
                [SCIYTFragments mergeVideo:video audio:audio audioLanguage:mainLanguage extraAudios:@[] subtitles:@[]
                                      tags:tags completion:merged];
            });
            return;
        }

        // Several sound tracks and/or captions: the captions are tiny and are fetched now, after the
        // heavy part, so a slow caption server never stands between a person and a finished video.
        NSMutableArray<NSDictionary *> *named = [NSMutableArray array];
        for (NSUInteger k = 0; k < extraFiles.count && k < extras.count; k++) {
            [named addObject:@{@"file": extraFiles[k], @"lang": extras[k][@"lang"] ?: @""}];
        }
        [self fetchCaptions:captions completion:^(NSArray<NSDictionary *> *subtitles) {
            if (progress) progress(0.96);
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                [SCIYTFragments mergeVideo:video audio:audio audioLanguage:mainLanguage
                               extraAudios:named subtitles:subtitles tags:SCIDirectTags(variant, NO) completion:merged];
            });
        }];
    }];
}

+ (void)downloadAudioFor:(SCIHLSVariant *)variant
                progress:(void (^)(double))progress
              completion:(void (^)(NSURL *, NSString *))completion {

    [self fetchVideoURL:nil videoBytes:0
               audioURL:variant.directAudioURL audioBytes:variant.directAudioBytes
                 extras:@[]
              resumeKey:variant.resumeKey
               progress:^(double fraction) { if (progress) progress(fraction * 0.95); }
             completion:^(NSURL *video, NSURL *audio, NSArray<NSURL *> *extraFiles, NSString *failure) {
        if (!audio) {
            [self rememberFailure:variant.directVideoID];
            completion(nil, failure);
            return;
        }

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSDictionary *tags = SCIDirectTags(variant, YES);
        [SCIYTFragments rewriteAudio:audio tags:tags completion:^(NSURL *output, NSString *why) {
            [[NSFileManager defaultManager] removeItemAtURL:audio error:nil];
            if (!output) [self rememberFailure:variant.directVideoID];
            if (progress && output) progress(1.0);
            completion(output, why);
        }];
        });
    }];
}

@end
