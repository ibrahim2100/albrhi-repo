#import "SCICacheRules.h"

const NSTimeInterval SCICacheRecentlyUsedSeconds = 300;

BOOL SCICacheNameIsOurs(NSString *name) {
    if (![name isKindOfClass:[NSString class]] || !name.length) return YES;   // unknown: keep

    // Anything this project names itself.
    if ([name.lowercaseString hasPrefix:@"albrhi"]) return YES;

    // A finished download: `<UUID>.<extension>` -- 36 characters of hex and dashes, one dot, an extension.
    static NSRegularExpression *download;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        download = [NSRegularExpression regularExpressionWithPattern:@"^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\\.[A-Za-z0-9]{1,8}$"
                                                             options:0 error:nil];
    });
    return [download numberOfMatchesInString:name options:0 range:NSMakeRange(0, name.length)] > 0;
}
