//
//  SCIYTFailure.m
//  Albrhi for YouTube
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCIYTFailure.h"
#import "../../Localization/SCILocalize.h"

static BOOL SCIHasAny(NSString *haystack, NSArray<NSString *> *needles) {
    for (NSString *needle in needles) if ([haystack rangeOfString:needle].location != NSNotFound) return YES;
    return NO;
}

@implementation SCIYTFailure

+ (SCIYTFailureCause)causeForText:(NSString *)text status:(NSInteger)status {
    NSString *t = text.lowercaseString ?: @"";

    // Most specific first: a 403 caused by an age gate and a 403 caused by an expired address end the
    // same way and need different advice.
    if (SCIHasAny(t, @[@"age-restricted", @"age restricted", @"confirm your age", @"inappropriate for some users"])) return SCIYTFailureAge;
    if (SCIHasAny(t, @[@"not available in your country", @"not made this video available in your country", @"blocked it in your country", @"in your country", @"region lock"])) return SCIYTFailureRegion;
    if (SCIHasAny(t, @[@"sign in", @"login_required", @"not a bot", @"confirm you"])) return SCIYTFailureSignIn;
    if (SCIHasAny(t, @[@"live event will begin", @"premieres in", @"live stream", @"is live"])) return SCIYTFailureLive;
    if (SCIHasAny(t, @[@"private video", @"video unavailable", @"has been removed", @"members-only", @"join this channel", @"unplayable", @"no longer available", @"this video is not available"])) return SCIYTFailureUnavailable;
    if (SCIHasAny(t, @[@"no space", @"out of space", @"not enough space", @"disk full", @"nsfilewriteoutofspace", @"code=640"])) return SCIYTFailureDiskFull;
    if (SCIHasAny(t, @[@"internet connection appears to be offline", @"not connected to the internet", @"network connection was lost", @"timed out", @"could not connect", @"-1009", @"-1001", @"-1005", @"-1004"])) return SCIYTFailureOffline;
    if (SCIHasAny(t, @[@"web page", @"error page", @"html"])) return SCIYTFailureBadFile;
    if (SCIHasAny(t, @[@"no aac track", @"no h.264 picture", @"no formats", @"no streams", @"no data"])) return SCIYTFailureNoFormats;

    if (status == 429 || status == 503) return SCIYTFailureThrottled;
    if (status == 403 || status == 410) return SCIYTFailureExpired;
    if (status == 401) return SCIYTFailureSignIn;
    if (status == 404) return SCIYTFailureUnavailable;
    return SCIYTFailureUnknown;
}

+ (SCIYTFailureCause)causeForError:(NSError *)error {
    if (!error) return SCIYTFailureUnknown;
    if ([error.domain isEqualToString:NSCocoaErrorDomain] && (error.code == NSFileWriteOutOfSpaceError || error.code == 640)) return SCIYTFailureDiskFull;
    if ([error.domain isEqualToString:NSPOSIXErrorDomain] && error.code == ENOSPC) return SCIYTFailureDiskFull;
    if ([error.domain isEqualToString:NSURLErrorDomain]) {
        switch (error.code) {
            case NSURLErrorNotConnectedToInternet:
            case NSURLErrorNetworkConnectionLost:
            case NSURLErrorTimedOut:
            case NSURLErrorCannotConnectToHost:
            case NSURLErrorCannotFindHost:
            case NSURLErrorDNSLookupFailed:
            case NSURLErrorInternationalRoamingOff:
                return SCIYTFailureOffline;
            default: break;
        }
    }
    return [self causeForText:error.localizedDescription status:0];
}

+ (NSString *)keyForCause:(SCIYTFailureCause)cause {
    switch (cause) {
        case SCIYTFailureSignIn: return @"dlf_signin";
        case SCIYTFailureAge: return @"dlf_age";
        case SCIYTFailureUnavailable: return @"dlf_unavailable";
        case SCIYTFailureRegion: return @"dlf_region";
        case SCIYTFailureDiskFull: return @"dlf_disk";
        case SCIYTFailureOffline: return @"dlf_offline";
        case SCIYTFailureExpired: return @"dlf_expired";
        case SCIYTFailureThrottled: return @"dlf_throttled";
        case SCIYTFailureBadFile: return @"dlf_badfile";
        case SCIYTFailureNoFormats: return @"dlf_noformats";
        case SCIYTFailureLive: return @"dlf_live";
        default: return @"dl_failed";
    }
}

+ (NSString *)messageForCause:(SCIYTFailureCause)cause { return SCILocalized([self keyForCause:cause]); }

+ (NSString *)sentenceForReason:(NSString *)reason fallback:(NSString *)fallback {
    SCIYTFailureCause cause = [self causeForText:reason status:0];
    return cause == SCIYTFailureUnknown ? fallback : [self messageForCause:cause];
}

@end
