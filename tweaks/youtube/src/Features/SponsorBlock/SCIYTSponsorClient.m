#import "SCIYTSponsorClient.h"
#import "../../SCILog.h"
#import "../../Prefs.h"
#import "../../Localization/SCILocalize.h"
#import <CommonCrypto/CommonDigest.h>

@implementation SCISponsorSegment
@end


/// Category identifier -> the preference that governs it.
///
/// A table rather than a naming convention, so a category the server adds later cannot
/// silently switch itself on by matching a pattern.
static NSDictionary<NSString *, NSString *> *SCICategoryPrefs(void) {
    static NSDictionary *table = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        table = @{
            @"sponsor":        SCIPrefSBSponsor,
            @"selfpromo":      SCIPrefSBSelfPromo,
            @"interaction":    SCIPrefSBInteraction,
            @"intro":          SCIPrefSBIntro,
            @"outro":          SCIPrefSBOutro,
            @"preview":        SCIPrefSBPreview,
            @"filler":         SCIPrefSBFiller,
            @"music_offtopic": SCIPrefSBMusicOffTopic,
        };
    });
    return table;
}

static NSArray<NSString *> *SCIEnabledCategories(void) {
    NSMutableArray *enabled = [NSMutableArray array];
    NSDictionary *table = SCICategoryPrefs();

    // Sorted, so the cache key for one set of choices is always the same string.
    for (NSString *category in [table.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        if (SCIPrefEnabled(table[category])) {
            [enabled addObject:category];
        }
    }
    return enabled;
}

/// First four hex characters of the SHA-256 of the video ID.
///
/// Four is what SponsorBlock recommends: short enough that the reply covers many videos
/// and the server cannot tell which one is being watched, long enough that the reply is
/// small.
static NSString *SCIHashPrefix(NSString *videoID) {
    const char *bytes = videoID.UTF8String;
    if (!bytes) return nil;

    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(bytes, (CC_LONG)strlen(bytes), digest);

    return [NSString stringWithFormat:@"%02x%02x", digest[0], digest[1]];
}


@implementation SCIYTSponsorClient

+ (NSString *)displayNameForCategory:(NSString *)category {
    if ([category isEqualToString:@"sponsor"])        return SCILocalized(@"sb_sponsor");
    if ([category isEqualToString:@"selfpromo"])      return SCILocalized(@"sb_selfpromo");
    if ([category isEqualToString:@"interaction"])    return SCILocalized(@"sb_interaction");
    if ([category isEqualToString:@"intro"])          return SCILocalized(@"sb_intro");
    if ([category isEqualToString:@"outro"])          return SCILocalized(@"sb_outro");
    if ([category isEqualToString:@"preview"])        return SCILocalized(@"sb_preview");
    if ([category isEqualToString:@"filler"])         return SCILocalized(@"sb_filler");
    if ([category isEqualToString:@"music_offtopic"]) return SCILocalized(@"sb_music_offtopic");
    return category;
}

+ (NSCache *)cache {
    static NSCache *cache = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [[NSCache alloc] init];
        // Bounded: a long session should not accumulate every video ever opened.
        cache.countLimit = 64;
    });
    return cache;
}

+ (NSURLSession *)session {
    static NSURLSession *session = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSURLSessionConfiguration *config =
            [NSURLSessionConfiguration ephemeralSessionConfiguration];

        // Ephemeral, so nothing about these lookups is written to disk and no cookie
        // travels with them. The point of the hashed endpoint is that the request says
        // as little as possible; a stored cookie would undo that in one step.
        config.HTTPCookieStorage = nil;
        config.URLCache = nil;
        config.timeoutIntervalForRequest = 8;
        config.timeoutIntervalForResource = 12;

        session = [NSURLSession sessionWithConfiguration:config];
    });
    return session;
}

/// Turns one JSON segment object into a segment, or nil if it is not usable.
///
/// Every check here rejects something a real reply can contain. The hashed endpoint
/// returns raw submissions, so this is where the curation the other endpoint would have
/// done on the server has to happen.
+ (SCISponsorSegment *)segmentFromJSON:(NSDictionary *)json
                    enabledCategories:(NSArray<NSString *> *)enabled {
    if (![json isKindOfClass:[NSDictionary class]]) return nil;

    NSString *category = json[@"category"];
    if (![category isKindOfClass:[NSString class]]) return nil;
    if (![enabled containsObject:category]) return nil;

    // Only segments meant to be skipped. The database also carries "mute", "poi" (a
    // single highlight point) and "full" (the whole video is one category); acting on
    // those as if they were skips would jump to the end of a video.
    id actionType = json[@"actionType"];
    if ([actionType isKindOfClass:[NSString class]] && ![actionType isEqualToString:@"skip"]) {
        return nil;
    }

    // Downvoted submissions are wrong often enough that the server hides them. Locked
    // ones are moderator-approved and always kept.
    id votes = json[@"votes"];
    id locked = json[@"locked"];
    BOOL isLocked = [locked respondsToSelector:@selector(integerValue)] && [locked integerValue] > 0;
    if (!isLocked && [votes respondsToSelector:@selector(integerValue)] && [votes integerValue] < 0) {
        return nil;
    }

    NSArray *bounds = json[@"segment"];
    if (![bounds isKindOfClass:[NSArray class]] || bounds.count != 2) return nil;
    if (![bounds[0] respondsToSelector:@selector(doubleValue)]) return nil;
    if (![bounds[1] respondsToSelector:@selector(doubleValue)]) return nil;

    double start = [bounds[0] doubleValue];
    double end = [bounds[1] doubleValue];

    // isfinite, because a NaN would compare false against everything and a segment that
    // never matches is invisible rather than obviously broken.
    if (!isfinite(start) || !isfinite(end)) return nil;
    if (start < 0 || end <= start) return nil;

    SCISponsorSegment *segment = [[SCISponsorSegment alloc] init];
    segment.category = category;
    segment.start = start;
    segment.end = end;
    segment.uuid = [json[@"UUID"] isKindOfClass:[NSString class]] ? json[@"UUID"]
                 : [NSString stringWithFormat:@"%@-%.3f", category, start];
    return segment;
}

/// Pulls this video's segments out of a reply that covers several videos.
///
/// Both response shapes are handled: the hashed endpoint returns an array of video
/// objects each holding a "segments" array, and the plain endpoint returns the segments
/// directly. Accepting both means the endpoint can be switched without this parser
/// caring which one answered.
+ (NSArray<SCISponsorSegment *> *)parse:(id)json
                             forVideoID:(NSString *)videoID
                     enabledCategories:(NSArray<NSString *> *)enabled {
    if (![json isKindOfClass:[NSArray class]]) return @[];

    NSMutableArray<SCISponsorSegment *> *out = [NSMutableArray array];

    for (id entry in (NSArray *)json) {
        if (![entry isKindOfClass:[NSDictionary class]]) continue;

        NSArray *segments = ((NSDictionary *)entry)[@"segments"];
        if ([segments isKindOfClass:[NSArray class]]) {
            // Hashed shape. Only this video's entry matters -- the rest of the reply is
            // other people's videos, which is exactly the point of asking this way.
            NSString *entryID = ((NSDictionary *)entry)[@"videoID"];
            if (![entryID isKindOfClass:[NSString class]] || ![entryID isEqualToString:videoID]) {
                continue;
            }
            for (id raw in segments) {
                SCISponsorSegment *segment = [self segmentFromJSON:raw enabledCategories:enabled];
                if (segment) [out addObject:segment];
            }
        } else {
            // Flat shape.
            SCISponsorSegment *segment = [self segmentFromJSON:entry enabledCategories:enabled];
            if (segment) [out addObject:segment];
        }
    }

    [out sortUsingComparator:^NSComparisonResult(SCISponsorSegment *a, SCISponsorSegment *b) {
        if (a.start < b.start) return NSOrderedAscending;
        if (a.start > b.start) return NSOrderedDescending;
        return NSOrderedSame;
    }];

    return out;
}

+ (BOOL)anyCategoryEnabled {
    return SCIPrefEnabled(SCIPrefSponsorBlock) && SCIEnabledCategories().count > 0;
}

+ (BOOL)categoryIsEnabled:(NSString *)category {
    NSString *key = SCICategoryPrefs()[category];
    return key && SCIPrefEnabled(SCIPrefSponsorBlock) && SCIPrefEnabled(key);
}

+ (void)segmentsForSavedVideo:(NSString *)videoID
                   completion:(void (^)(NSArray<SCISponsorSegment *> *))completion {
    if (!completion) return;
    if (!SCIEnabledCategories().count) { completion(@[]); return; }
    [self segmentsForVideo:videoID categories:[SCICategoryPrefs().allKeys sortedArrayUsingSelector:@selector(compare:)]
                completion:completion];
}

+ (void)segmentsForVideo:(NSString *)videoID
              completion:(void (^)(NSArray<SCISponsorSegment *> *))completion {
    [self segmentsForVideo:videoID categories:SCIEnabledCategories() completion:completion];
}

+ (void)segmentsForVideo:(NSString *)videoID
              categories:(NSArray<NSString *> *)enabled
              completion:(void (^)(NSArray<SCISponsorSegment *> *))completion {
    if (!completion) return;

    // Nothing is sent when the feature is off, or when every category is off. Someone
    // who does not want this makes no network request at all -- not a request whose
    // result is then discarded.
    if (!SCIPrefEnabled(SCIPrefSponsorBlock) || !enabled.count || !videoID.length) {
        completion(@[]);
        return;
    }

    NSString *key = [NSString stringWithFormat:@"%@|%@",
        videoID, [enabled componentsJoinedByString:@","]];

    NSArray *cached = [[self cache] objectForKey:key];
    if (cached) {
        completion(cached);
        return;
    }

    NSString *prefix = SCIHashPrefix(videoID);
    if (!prefix) {
        completion(@[]);
        return;
    }

    NSURLComponents *components = [NSURLComponents componentsWithString:
        [NSString stringWithFormat:@"https://sponsor.ajay.app/api/skipSegments/%@", prefix]];

    // Repeated `category=` rather than a JSON array: the array form has to be
    // percent-encoded and is easy to get subtly wrong, and repeated keys are what the
    // API documents first.
    NSMutableArray<NSURLQueryItem *> *query = [NSMutableArray array];
    for (NSString *category in enabled) {
        [query addObject:[NSURLQueryItem queryItemWithName:@"category" value:category]];
    }
    components.queryItems = query;

    NSURL *url = components.URL;
    if (!url) {
        completion(@[]);
        return;
    }

    SCILogV(@"sponsorblock: asking for prefix %@ (%lu categories)",
            prefix, (unsigned long)enabled.count);

    NSURLSessionDataTask *task = [[self session] dataTaskWithURL:url
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {

        NSArray<SCISponsorSegment *> *segments = @[];

        if (error || !data) {
            SCILogV(@"sponsorblock: lookup failed — %@", error.localizedDescription);
        } else {
            NSInteger status = [(NSHTTPURLResponse *)response statusCode];

            // 404 means nobody has submitted anything for this prefix, which is normal
            // and not a failure worth reporting.
            if (status == 200) {
                NSError *parseError = nil;
                id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
                if (json) {
                    segments = [self parse:json forVideoID:videoID enabledCategories:enabled];
                } else {
                    SCILogV(@"sponsorblock: unreadable reply — %@", parseError.localizedDescription);
                }
            } else if (status != 404) {
                SCILogV(@"sponsorblock: server said %ld", (long)status);
            }
        }

        // Only real answers are cached. Caching an empty result would turn one failed
        // request into a video with no segments for the rest of the session.
        if (segments.count) {
            [[self cache] setObject:segments forKey:key];
        }

        SCILogV(@"sponsorblock: %lu segments for %@",
                (unsigned long)segments.count, videoID);

        dispatch_async(dispatch_get_main_queue(), ^{
            completion(segments);
        });
    }];

    [task resume];
}

@end
