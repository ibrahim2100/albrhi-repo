#import "SCIYTPlaylist.h"
#import "../../Localization/SCILocalize.h"

static NSString * const kSCIWebAgent =
    @"Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15";

/// Every value stored under `key`, anywhere in a decoded answer, in document order.
static void SCIWalk(id node, NSString *key, NSMutableArray *out) {
    if ([node isKindOfClass:[NSDictionary class]]) {
        for (NSString *k in (NSDictionary *)node) {
            id value = ((NSDictionary *)node)[k];
            if ([k isEqualToString:key]) [out addObject:value];
            SCIWalk(value, key, out);
        }
    } else if ([node isKindOfClass:[NSArray class]]) {
        for (id item in (NSArray *)node) SCIWalk(item, key, out);
    }
}

/// One load in progress. A class rather than a block that calls itself: each page's answer decides
/// whether to ask for the next, and a block that holds itself is a retain cycle.
@interface SCIPlaylistLoad : NSObject
@property (nonatomic, copy) NSString *playlistID;
@property (nonatomic) NSUInteger limit;
@property (nonatomic, copy) void (^completion)(NSArray<NSString *> *, NSString *, NSString *, NSString *);
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSMutableArray<NSString *> *all;
@property (nonatomic, strong) NSMutableSet<NSString *> *seen;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *total;
@end

@implementation SCIPlaylistLoad

- (instancetype)init {
    self = [super init];
    if (!self) return nil;
    _all = [NSMutableArray array];
    _seen = [NSMutableSet set];
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    configuration.timeoutIntervalForRequest = 15;
    configuration.timeoutIntervalForResource = 60;
    _session = [NSURLSession sessionWithConfiguration:configuration];
    return self;
}

- (void)finishWith:(NSString *)failure {
    NSArray *ids = [self.all copy];
    NSString *title = self.title, *total = self.total;
    void (^done)(NSArray<NSString *> *, NSString *, NSString *, NSString *) = self.completion;
    dispatch_async(dispatch_get_main_queue(), ^{ done(ids, title, total, failure); });
}

- (void)fetch:(NSString *)continuation page:(NSUInteger)pageNumber {
    NSDictionary *context = @{@"client": @{@"clientName": @"WEB", @"clientVersion": @"2.20250101.00.00",
                                           @"hl": @"en", @"gl": @"US", @"userAgent": kSCIWebAgent}};
    NSMutableDictionary *body = [NSMutableDictionary dictionaryWithObject:context forKey:@"context"];
    if (continuation) body[@"continuation"] = continuation;
    else body[@"browseId"] = [@"VL" stringByAppendingString:self.playlistID];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:
        [NSURL URLWithString:@"https://youtubei.googleapis.com/youtubei/v1/browse?prettyPrint=false"]];
    request.HTTPMethod = @"POST";
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:kSCIWebAgent forHTTPHeaderField:@"User-Agent"];

    [[self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)response statusCode] : 0;
        id json = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;

        if (![json isKindOfClass:[NSDictionary class]]) {
            // A later page failing keeps what was read; the first failing is the failure.
            if (self.all.count) { [self finishWith:nil]; return; }
            [self finishWith:(status == 400 || status == 404) ? SCILocalized(@"pl_why_missing")
                                                              : (error.localizedDescription ?: SCILocalized(@"pl_why_net"))];
            return;
        }

        NSString *next = nil, *title = nil, *total = nil;
        NSArray<NSString *> *ids = [SCIYTPlaylist videoIDsInBrowse:json token:&next title:&title total:&total];
        if (title.length && !self.title) self.title = title;
        if (total.length && !self.total) self.total = total;
        for (NSString *video in ids) {
            if (self.all.count < self.limit && ![self.seen containsObject:video]) { [self.seen addObject:video]; [self.all addObject:video]; }
        }

        if (next.length && self.all.count < self.limit && ids.count && pageNumber < 40) { [self fetch:next page:pageNumber + 1]; return; }
        [self finishWith:self.all.count ? nil : SCILocalized(@"pl_why_empty")];
    }] resume];
}

@end

@implementation SCIYTPlaylist

+ (NSString *)playlistIDFromText:(NSString *)text reason:(NSString **)reason {
    if (![text isKindOfClass:[NSString class]]) return nil;
    NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!trimmed.length) return nil;

    NSString *candidate = nil;
    NSRegularExpression *param = [NSRegularExpression regularExpressionWithPattern:@"[?&]list=([A-Za-z0-9_-]+)" options:0 error:nil];
    NSTextCheckingResult *match = [param firstMatchInString:trimmed options:0 range:NSMakeRange(0, trimmed.length)];
    if (match) {
        candidate = [trimmed substringWithRange:[match rangeAtIndex:1]];
    } else if ([trimmed rangeOfString:@" "].location == NSNotFound && [trimmed rangeOfString:@"/"].location == NSNotFound
               && ([trimmed hasPrefix:@"PL"] || [trimmed hasPrefix:@"UU"] || [trimmed hasPrefix:@"OLAK5uy_"] || [trimmed hasPrefix:@"FL"]
                   || [trimmed hasPrefix:@"RD"] || [trimmed isEqualToString:@"LL"] || [trimmed isEqualToString:@"WL"])) {
        candidate = trimmed;
    }
    if (!candidate.length) return nil;

    if ([candidate hasPrefix:@"RD"]) { if (reason) *reason = SCILocalized(@"pl_why_mix"); return nil; }
    if ([candidate isEqualToString:@"LL"] || [candidate isEqualToString:@"WL"]) { if (reason) *reason = SCILocalized(@"pl_why_private"); return nil; }
    if (candidate.length < 10) { if (reason) *reason = SCILocalized(@"pl_why_bad"); return nil; }
    return candidate;
}

+ (NSArray<NSString *> *)videoIDsInBrowse:(NSDictionary *)json
                                    token:(NSString **)token
                                    title:(NSString **)title
                                    total:(NSString **)total {
    NSMutableArray<NSString *> *ids = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];

    NSMutableArray *endpoints = [NSMutableArray array];
    SCIWalk(json, @"watchEndpoint", endpoints);
    for (id endpoint in endpoints) {
        NSString *video = [endpoint isKindOfClass:[NSDictionary class]] ? endpoint[@"videoId"] : nil;
        if ([video isKindOfClass:[NSString class]] && video.length == 11 && ![seen containsObject:video]) {
            [seen addObject:video];
            [ids addObject:video];
        }
    }

    // The next page: the last continuation command that carries a token.
    NSMutableArray *commands = [NSMutableArray array];
    SCIWalk(json, @"continuationCommand", commands);
    NSString *next = nil;
    for (id command in commands) {
        if ([command isKindOfClass:[NSDictionary class]] && [command[@"token"] isKindOfClass:[NSString class]] && [command[@"token"] length]) next = command[@"token"];
    }
    if (token) *token = next;

    if (title) {
        NSMutableArray *metadata = [NSMutableArray array];
        SCIWalk(json, @"playlistMetadataRenderer", metadata);
        id first = metadata.firstObject;
        *title = ([first isKindOfClass:[NSDictionary class]] && [first[@"title"] isKindOfClass:[NSString class]]) ? first[@"title"] : nil;
    }

    if (total) {
        // "1,693" and " videos" are two runs of one text.
        NSMutableArray *runLists = [NSMutableArray array];
        SCIWalk(json, @"runs", runLists);
        NSString *found = nil;
        for (id runs in runLists) {
            if (![runs isKindOfClass:[NSArray class]] || [(NSArray *)runs count] != 2) continue;
            NSString *count = [runs[0] isKindOfClass:[NSDictionary class]] ? runs[0][@"text"] : nil;
            NSString *word = [runs[1] isKindOfClass:[NSDictionary class]] ? runs[1][@"text"] : nil;
            if ([count isKindOfClass:[NSString class]] && [word isKindOfClass:[NSString class]]
                && [word hasPrefix:@" video"] && count.length
                && [count rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789,."] invertedSet]].location == NSNotFound) {
                found = count; break;
            }
        }
        *total = found;
    }
    return ids;
}

+ (void)loadPlaylistID:(NSString *)playlistID
                 limit:(NSUInteger)limit
            completion:(void (^)(NSArray<NSString *> *, NSString *, NSString *, NSString *))completion {
    SCIPlaylistLoad *load = [[SCIPlaylistLoad alloc] init];
    load.playlistID = playlistID;
    load.limit = limit;
    load.completion = completion;
    [load fetch:nil page:1];
}

@end
