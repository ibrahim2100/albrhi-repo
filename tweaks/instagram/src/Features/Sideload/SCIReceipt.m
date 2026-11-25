//
//  SCIReceipt.m
//  Albrhi for Instagram
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCIReceipt.h"

///
/// **Why "You're now using Instagram Beta" appears on a copy that is not a beta.**
///
/// Instagram decides it is a TestFlight build from the address of its receipt: `-[NSBundle appStoreReceiptURL]` ends in `sandboxReceipt` for a
/// TestFlight install *and for every app that was not installed from the store*, a re-signed copy included (the binary names both
/// `appStoreReceiptURL` and `sandboxReceipt`, and carries `IGCoreRootTestFlightNagPlugin`, `IGTestFlightBuildGate`, "You're now using Instagram Beta" and
/// "Please update the app using TestFlight"). So a sideloaded Instagram is a "beta", is nagged to update through TestFlight, and whatever that path
/// runs next is a path nobody tested on a copy with no TestFlight. Rocket's build changes the last component of that one address for the main bundle
/// (read from its disassembly, 2026-11-25; the comparison and replacement strings are decoded at run time, the rule is the well-known one); this does the same,
/// and only for an address that really ends in `sandboxReceipt`.
///

static NSUInteger sRewritten = 0;
static NSString *sLast = nil;
static NSObject *SCIReceiptLock(void) {
    static NSObject *lock;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ lock = [[NSObject alloc] init]; });
    return lock;
}

NSURL *SCIReceiptRewritten(NSURL *url) {
    if (![url isKindOfClass:[NSURL class]]) return url;
    if (![url.lastPathComponent isEqualToString:@"sandboxReceipt"]) return url;
    NSURL *fixed = [[url URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"receipt"];
    @synchronized (SCIReceiptLock()) {
        sRewritten++;
        sLast = fixed.path;
    }
    return fixed;
}

NSArray<NSString *> *SCIReceiptReportLines(void) {
    NSUInteger count;
    NSString *last;
    @synchronized (SCIReceiptLock()) { count = sRewritten; last = sLast; }
    return @[
        [NSString stringWithFormat:@"receipt address: asked for %lu time(s) as a sideloaded copy (sandboxReceipt -> receipt)%@",
         (unsigned long)count, last ? [@"; last given: " stringByAppendingString:last] : @""],
    ];
}
