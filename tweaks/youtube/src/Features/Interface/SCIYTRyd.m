//
//  SCIYTRyd.m
//  Albrhi for YouTube
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCIYTRyd.h"
#import "../../Prefs.h"
#import "../../SCILog.h"
#import "../../Localization/SCILocalize.h"

NSNotificationName const SCIYTRydDidChangeNotification = @"SCIYTRydDidChange";

static NSString *sCurrentID = nil;
static NSDictionary<NSString *, NSNumber *> *sCurrent = nil;

@implementation SCIYTRyd

+ (NSCache *)cache {
    static NSCache *cache; static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [[NSCache alloc] init]; cache.countLimit = 64; });
    return cache;
}

+ (NSURLSession *)session {
    static NSURLSession *session; static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        config.HTTPCookieStorage = nil;       // nothing travels with the request but the video id
        config.URLCache = nil;
        config.timeoutIntervalForRequest = 8;
        config.timeoutIntervalForResource = 12;
        session = [NSURLSession sessionWithConfiguration:config];
    });
    return session;
}

+ (NSString *)compact:(double)count {
    if (!isfinite(count) || count < 0) return @"—";
    if (count < 1000) return [NSString stringWithFormat:@"%.0f", count];
    static const char *units[] = { "K", "M", "B" };
    double value = count;
    int unit = -1;
    while (value >= 1000 && unit < 2) { value /= 1000; unit++; }
    // One decimal below ten of a unit ("1.2M"), none at ten and above ("34K"); a trailing ".0" is dropped.
    NSString *text = value < 10 ? [NSString stringWithFormat:@"%.1f", value] : [NSString stringWithFormat:@"%.0f", value];
    if ([text hasSuffix:@".0"]) text = [text substringToIndex:text.length - 2];
    // 999.9K rounds to 1000K: say 1M instead.
    if ([text isEqualToString:@"1000"] && unit < 2) return [NSString stringWithFormat:@"1%s", units[unit + 1]];
    return [text stringByAppendingString:[NSString stringWithUTF8String:units[unit]]];
}

+ (NSDictionary<NSString *, NSNumber *> *)parseVotes:(id)json {
    if (![json isKindOfClass:[NSDictionary class]]) return nil;
    NSDictionary *d = json;
    if ([d[@"deleted"] boolValue]) return nil;
    id likes = d[@"likes"], dislikes = d[@"dislikes"];
    if (![likes isKindOfClass:[NSNumber class]] || ![dislikes isKindOfClass:[NSNumber class]]) return nil;
    if ([likes doubleValue] < 0 || [dislikes doubleValue] < 0) return nil;
    if (![likes doubleValue] && ![dislikes doubleValue]) return nil;          // nothing known: not a zero to show
    NSMutableDictionary *out = [@{@"likes": likes, @"dislikes": dislikes} mutableCopy];
    out[@"rating"] = [d[@"rating"] isKindOfClass:[NSNumber class]] ? d[@"rating"] : @0;
    out[@"views"] = [d[@"viewCount"] isKindOfClass:[NSNumber class]] ? d[@"viewCount"] : @0;
    return out;
}

+ (NSDictionary<NSString *, NSNumber *> *)current { return sCurrent; }

+ (void)announce {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:SCIYTRydDidChangeNotification object:nil];
    });
}

+ (void)videoActivated:(NSString *)videoID {
    @synchronized (self) {
        if ([videoID isEqualToString:sCurrentID] && sCurrent) return;
        sCurrentID = [videoID copy];
        sCurrent = nil;
    }
    [self announce];

    // Off means nothing is asked: not a request whose answer is then thrown away.
    if (!videoID.length || !SCIPrefEnabled(SCIPrefOverlayDislikes)) return;

    NSDictionary *cached = [[self cache] objectForKey:videoID];
    if (cached) {
        @synchronized (self) { if ([sCurrentID isEqualToString:videoID]) sCurrent = cached; }
        [self announce];
        return;
    }

    NSURLComponents *components = [NSURLComponents componentsWithString:@"https://returnyoutubedislikeapi.com/votes"];
    components.queryItems = @[[NSURLQueryItem queryItemWithName:@"videoId" value:videoID]];
    NSURLRequest *request = [NSURLRequest requestWithURL:components.URL];

    NSString *asked = [videoID copy];
    [[[self session] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)response statusCode] : 0;
        id json = (status == 200 && data.length) ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        NSDictionary *votes = [self parseVotes:json];
        SCILogV(@"ryd: %@ -> %@ (HTTP %ld)", asked, votes ? @"figures" : @"nothing", (long)status);
        if (!votes) return;
        [[self cache] setObject:votes forKey:asked];
        BOOL stillThisVideo;
        @synchronized (self) { stillThisVideo = [sCurrentID isEqualToString:asked]; if (stillThisVideo) sCurrent = votes; }
        if (stillThisVideo) [self announce];
    }] resume];
}

+ (NSString *)buttonTitle {
    NSDictionary *votes = sCurrent;
    return votes ? [NSString stringWithFormat:@"👎\n%@", [self compact:[votes[@"dislikes"] doubleValue]]] : @"👎\n—";
}

+ (NSString *)summary {
    NSDictionary *votes = sCurrent;
    if (!votes) return SCILocalized(@"ryd_none");
    return [NSString stringWithFormat:SCILocalized(@"ryd_summary"),
            [self compact:[votes[@"likes"] doubleValue]], [self compact:[votes[@"dislikes"] doubleValue]],
            [votes[@"rating"] doubleValue], [self compact:[votes[@"views"] doubleValue]]];
}

@end
