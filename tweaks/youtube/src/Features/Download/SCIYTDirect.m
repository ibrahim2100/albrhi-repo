#import "SCIYTDirect.h"
#import "SCIYTFragments.h"
#import "SCIYTParts.h"
#import "../../SCILog.h"
#import "../../Localization/SCILocalize.h"
#import "../../Diagnostics/SCIYTDiagnostics.h"

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
+ (void)sortFormats:(NSArray *)all video:(NSMutableArray<NSDictionary *> *)videos audio:(NSDictionary **)audio {
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

    [self askForVideo:videoID attempt:0 completion:^(NSDictionary *streamingData, NSString *failure) {
        if (!streamingData) { finish(@[], failure); return; }

        NSMutableArray<NSDictionary *> *videos = [NSMutableArray array];
        NSDictionary *audio = nil;
        [self sortFormats:streamingData[@"adaptiveFormats"] video:videos audio:&audio];

        if (!audio) { finish(@[], @"no AAC track served"); return; }
        if (!videos.count) { finish(@[], @"no H.264 picture served"); return; }

        // One entry per height, the highest bitrate of each (which is the 60 fps copy where
        // there is one), tallest first.
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

        [SCIYTDiagnostics recordStreamAttempt:[NSString stringWithFormat:
            @"direct (%@): %lu qualities, best %ldp, audio %.1f MB", videoID, (unsigned long)variants.count,
            (long)variants.firstObject.height, (double)SCIDirectNumber(audio[@"contentLength"]) / 1048576.0]];

        finish(variants, nil);
    }];
}

/// One player request. A second attempt takes a fresh visitor id, because a stale one is the
/// usual reason an otherwise healthy request is turned away.
+ (void)askForVideo:(NSString *)videoID attempt:(NSInteger)attempt
         completion:(void (^)(NSDictionary *streamingData, NSString *failure))completion {

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
                completion(streamingData, nil);
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
            completion(nil, why.length ? why : (error.localizedDescription ?: [NSString stringWithFormat:@"HTTP %ld, no formats", (long)status]));
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

static long long SCIDirectFileSize(NSURL *file) {
    return [[[NSFileManager defaultManager] attributesOfItemAtPath:file.path error:nil] fileSize];
}

/// Fetches the video (when given) and the sound together, joins each into a scratch file and
/// hands both back. A file whose length is not the length YouTube declared is a fetch that
/// lost a piece, and is refused here rather than discovered as a glitch halfway through playback.
+ (void)fetchVideoURL:(NSString *)videoURL videoBytes:(long long)videoBytes
             audioURL:(NSString *)audioURL audioBytes:(long long)audioBytes
             progress:(void (^)(double))progress
           completion:(void (^)(NSURL *video, NSURL *audio, NSString *failure))completion {

    NSArray<NSString *> *videoChunks = videoURL ? SCIDirectChunks(videoURL, videoBytes) : @[];
    NSArray<NSString *> *audioChunks = SCIDirectChunks(audioURL, audioBytes);
    NSArray<NSString *> *all = [videoChunks arrayByAddingObjectsFromArray:audioChunks];

    [SCIYTParts fetch:all progress:progress completion:^(NSArray<NSURL *> *ordered, NSURL *folder, NSString *error) {
        if (!ordered) { completion(nil, nil, error ?: SCILocalized(@"dl_failed")); return; }

        // Joining reads every part back, which is real work for a long video; off the main queue.
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            NSURL *unused = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]]];
            NSURL *video = nil, *audio = nil;

            if (videoChunks.count) {
                video = [SCIYTParts join:[ordered subarrayWithRange:NSMakeRange(0, videoChunks.count)]
                               extension:@"mp4" folder:unused];
            }
            audio = [SCIYTParts join:[ordered subarrayWithRange:NSMakeRange(videoChunks.count, audioChunks.count)]
                           extension:@"m4a" folder:folder];

            BOOL sound = audio && SCIDirectFileSize(audio) == audioBytes;
            BOOL picture = !videoChunks.count || (video && SCIDirectFileSize(video) == videoBytes);
            if (!sound || !picture) {
                if (video) [[NSFileManager defaultManager] removeItemAtURL:video error:nil];
                if (audio) [[NSFileManager defaultManager] removeItemAtURL:audio error:nil];
                [SCIYTDiagnostics recordStreamAttempt:[NSString stringWithFormat:
                    @"direct: fetched sizes %lld/%lld (video) %lld/%lld (audio) do not match what was declared",
                    video ? SCIDirectFileSize(video) : 0LL, videoBytes, audio ? SCIDirectFileSize(audio) : 0LL, audioBytes]];
                dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, nil, SCILocalized(@"dl_direct_incomplete")); });
                return;
            }
            dispatch_async(dispatch_get_main_queue(), ^{ completion(video, audio, nil); });
        });
    }];
}

+ (void)downloadVariant:(SCIHLSVariant *)variant
               progress:(void (^)(double))progress
             completion:(void (^)(NSURL *, NSString *))completion {

    [self fetchVideoURL:variant.directVideoURL videoBytes:variant.directVideoBytes
               audioURL:variant.directAudioURL audioBytes:variant.directAudioBytes
               progress:^(double fraction) { if (progress) progress(fraction * 0.95); }
             completion:^(NSURL *video, NSURL *audio, NSString *failure) {
        if (!video || !audio) {
            [self rememberFailure:variant.directVideoID];
            completion(nil, failure);
            return;
        }

        [SCIYTFragments mergeVideo:video audio:audio completion:^(NSURL *output, NSString *why) {
            [[NSFileManager defaultManager] removeItemAtURL:video error:nil];
            [[NSFileManager defaultManager] removeItemAtURL:audio error:nil];
            if (!output) [self rememberFailure:variant.directVideoID];
            if (progress && output) progress(1.0);
            completion(output, why);
        }];
    }];
}

+ (void)downloadAudioFor:(SCIHLSVariant *)variant
                progress:(void (^)(double))progress
              completion:(void (^)(NSURL *, NSString *))completion {

    [self fetchVideoURL:nil videoBytes:0
               audioURL:variant.directAudioURL audioBytes:variant.directAudioBytes
               progress:^(double fraction) { if (progress) progress(fraction * 0.95); }
             completion:^(NSURL *video, NSURL *audio, NSString *failure) {
        if (!audio) {
            [self rememberFailure:variant.directVideoID];
            completion(nil, failure);
            return;
        }

        [SCIYTFragments rewriteAudio:audio completion:^(NSURL *output, NSString *why) {
            [[NSFileManager defaultManager] removeItemAtURL:audio error:nil];
            if (!output) [self rememberFailure:variant.directVideoID];
            if (progress && output) progress(1.0);
            completion(output, why);
        }];
    }];
}

@end
