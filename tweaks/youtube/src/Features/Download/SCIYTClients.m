//
//  SCIYTClients.m
//  Albrhi for YouTube
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCIYTClients.h"

@implementation SCIYTClients

+ (NSArray<NSDictionary *> *)all {
    static NSArray *table;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        table = @[
            @{@"name": @"visionOS",
              @"visitor": @YES,
              @"agent": @"Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15",
              @"client": @{@"clientName": @"VISIONOS", @"clientVersion": @"1.02", @"osName": @"visionOS", @"osVersion": @"26.5.23O471",
                           @"deviceMake": @"Apple", @"deviceModel": @"RealityDevice17,1", @"hl": @"en", @"gl": @"US"}},
            @{@"name": @"iOS 20.10.4",
              @"visitor": @NO,
              @"agent": @"com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)",
              @"client": @{@"clientName": @"IOS", @"clientVersion": @"20.10.4", @"deviceMake": @"Apple", @"deviceModel": @"iPhone16,2",
                           @"osName": @"iPhone", @"osVersion": @"18.3.2.22D82", @"hl": @"en", @"gl": @"US"}},
            @{@"name": @"Android VR 1.60.19",
              @"visitor": @NO,
              @"agent": @"com.google.android.apps.youtube.vr.oculus/1.60.19 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip",
              @"client": @{@"clientName": @"ANDROID_VR", @"clientVersion": @"1.60.19", @"deviceMake": @"Oculus", @"deviceModel": @"Quest 3",
                           @"osName": @"Android", @"osVersion": @"12L", @"androidSdkVersion": @32, @"hl": @"en", @"gl": @"US"}},
        ];
    });
    return table;
}

+ (BOOL)looksDegradedMaxHeight:(NSInteger)maxHeight seconds:(double)seconds {
    return maxHeight > 0 && maxHeight <= 360 && seconds >= 120;
}

+ (BOOL)refusalMayDifferByClient:(NSString *)status reason:(NSString *)reason {
    NSString *s = status.uppercaseString ?: @"";
    NSString *r = reason.lowercaseString ?: @"";
    // Gone for everyone: another client will say the same.
    if ([r containsString:@"private video"] || [r containsString:@"has been removed"] || [r containsString:@"copyright"]
        || [r containsString:@"in your country"] || [r containsString:@"terminated"]) return NO;
    if ([s isEqualToString:@"LOGIN_REQUIRED"] || [s isEqualToString:@"UNPLAYABLE"] || [s isEqualToString:@"ERROR"] || s.length == 0) return YES;
    return NO;
}

@end
