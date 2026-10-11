#import "SCILinkTracking.h"

/// Parameters that identify who shared a link or which campaign sent it. Deliberately short: a
/// parameter this does not name is somebody's real query (`?hl=ar`, `?img_index=2`) and stays.
static NSSet<NSString *> *SCITrackingParameters(void) {
    static NSSet *names;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        names = [NSSet setWithArray:@[@"igsh", @"igshid", @"ig_rid",
                                      @"utm_source", @"utm_medium", @"utm_campaign", @"utm_term", @"utm_content",
                                      @"fbclid"]];
    });
    return names;
}

static BOOL SCIIsInstagramHost(NSString *host) {
    host = host.lowercaseString;
    for (NSString *base in @[@"instagram.com", @"instagr.am", @"ig.me"]) {
        if ([host isEqualToString:base] || [host hasSuffix:[@"." stringByAppendingString:base]]) return YES;
    }
    return NO;
}

NSString *SCIStripTrackingFromURLString(NSString *urlString) {
    if (![urlString isKindOfClass:[NSString class]] || urlString.length < 12) return urlString;

    NSURLComponents *components = [NSURLComponents componentsWithString:urlString];
    if (!components || !SCIIsInstagramHost(components.host)) return urlString;

    // The *encoded* query, split by hand: going through `queryItems` would decode and re-encode
    // every parameter that is kept, and a link must come back byte for byte except for what was removed.
    NSString *query = components.percentEncodedQuery;
    if (!query.length) return urlString;

    NSMutableArray<NSString *> *kept = [NSMutableArray array];
    BOOL removed = NO;
    for (NSString *pair in [query componentsSeparatedByString:@"&"]) {
        NSString *name = [[[pair componentsSeparatedByString:@"="] firstObject] stringByRemovingPercentEncoding].lowercaseString ?: @"";
        if ([SCITrackingParameters() containsObject:name]) { removed = YES; continue; }
        if (pair.length) [kept addObject:pair];
    }
    if (!removed) return urlString;

    components.percentEncodedQuery = kept.count ? [kept componentsJoinedByString:@"&"] : nil;
    return components.string ?: urlString;
}

NSString *SCIStripTrackingFromText(NSString *text) {
    if (![text isKindOfClass:[NSString class]] || [text rangeOfString:@"://"].location == NSNotFound) return text;

    static NSRegularExpression *link;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        link = [NSRegularExpression regularExpressionWithPattern:@"https?://[^\\s<>\"']+" options:0 error:nil];
    });

    NSMutableString *out = [text mutableCopy];
    NSArray<NSTextCheckingResult *> *matches = [link matchesInString:text options:0 range:NSMakeRange(0, text.length)];
    for (NSTextCheckingResult *match in matches.reverseObjectEnumerator) {
        NSString *found = [text substringWithRange:match.range];

        // Closing punctuation belongs to the sentence, not to the address.
        NSUInteger end = found.length;
        NSCharacterSet *trailing = [NSCharacterSet characterSetWithCharactersInString:@".,;:!?)]}»…"];
        while (end > 0 && [trailing characterIsMember:[found characterAtIndex:end - 1]]) end--;

        NSString *address = [found substringToIndex:end];
        NSString *cleaned = SCIStripTrackingFromURLString(address);
        if (![cleaned isEqualToString:address]) {
            [out replaceCharactersInRange:NSMakeRange(match.range.location, end) withString:cleaned];
        }
    }
    return out;
}
