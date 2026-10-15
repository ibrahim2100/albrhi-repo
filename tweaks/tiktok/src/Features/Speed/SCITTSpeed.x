//
//  SCITTSpeed.x
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "SCITTSpeed.h"
#import "../../Prefs.h"
#import "../../SCILog.h"

///
/// **A video plays at the speed the person chose, unless TikTok asked for another on purpose.**
///
/// `TTKMediaSpeedControlService` is the one object that holds a video's rate. Three of its calls carry a rate in:
/// `-setPlaybackRate:`, `-changeToSpeed:` and `-changeSpeed:logExtraDict:`. When any of them is handed 1.0 -- TikTok
/// asking for normal -- the chosen rate goes in instead; every other rate passes untouched, so TikTok's own
/// hold-to-speed-up still works and still lets go back to the chosen speed. Mapping is idempotent (a chosen rate is
/// never 1.0), which is why answering all three cannot compound.
///
/// Confirmed on 46.4.0 with tools/objc-classes.py: `v24@0:8d16`, `v24@0:8d16`, `v32@0:8d16@24`. **Not confirmed on a
/// device**: which of the three actually moves the player is not read from the binary, so the report says how often each
/// one was asked.
///

static NSUInteger sciSpeedSet = 0, sciSpeedTo = 0, sciSpeedChange = 0;
static NSString *sciSpeedState = nil;

static double SCITTChosenSpeed(void) {
    if (!SCIPanelAllowsThisApp()) return 1.0;
    double rate = [[NSUserDefaults standardUserDefaults] doubleForKey:SCIPrefSpeedRate];
    return (rate >= 0.25 && rate <= 4.0) ? rate : 1.0;
}

static double SCITTMappedSpeed(double asked, NSUInteger *counter) {
    double chosen = SCITTChosenSpeed();
    if (asked != 1.0 || chosen == 1.0) return asked;
    (*counter)++;
    return chosen;
}

%group SCITTSpeedGroup
%hook TTKMediaSpeedControlService

- (void)setPlaybackRate:(double)rate {
    %orig(SCITTMappedSpeed(rate, &sciSpeedSet));
}

- (void)changeToSpeed:(double)rate {
    %orig(SCITTMappedSpeed(rate, &sciSpeedTo));
}

- (void)changeSpeed:(double)rate logExtraDict:(id)extra {
    %orig(SCITTMappedSpeed(rate, &sciSpeedChange), extra);
}

%end
%end

NSString *SCITTSpeedReport(void) {
    double chosen = SCITTChosenSpeed();
    return [NSString stringWithFormat:@"%@; chosen: %@; replaced 1.0 in setPlaybackRate: %lu, changeToSpeed: %lu, changeSpeed:logExtraDict: %lu",
            sciSpeedState ?: @"not installed", chosen == 1.0 ? @"TikTok's own" : [NSString stringWithFormat:@"%.2gx", chosen],
            (unsigned long)sciSpeedSet, (unsigned long)sciSpeedTo, (unsigned long)sciSpeedChange];
}

void SCITTInstallSpeed(void) {
    Class service = NSClassFromString(@"TTKMediaSpeedControlService");
    BOOL ok = service != nil;
    struct { const char *selector; const char *encoding; } wanted[] = {
        { "setPlaybackRate:", "v24@0:8d16" }, { "changeToSpeed:", "v24@0:8d16" }, { "changeSpeed:logExtraDict:", "v32@0:8d16@24" },
    };
    for (size_t i = 0; ok && i < sizeof(wanted) / sizeof(wanted[0]); i++) {
        Method method = class_getInstanceMethod(service, sel_registerName(wanted[i].selector));
        const char *types = method ? method_getTypeEncoding(method) : NULL;
        ok = types && strcmp(types, wanted[i].encoding) == 0;
        if (!ok) sciSpeedState = [NSString stringWithFormat:@"stood down: %s is %s here", wanted[i].selector, types ?: "absent"];
    }
    if (!ok) {
        if (!sciSpeedState) sciSpeedState = @"stood down: TTKMediaSpeedControlService is not in this build";
        SCILogV(@"[Speed] %@", sciSpeedState);
        return;
    }
    %init(SCITTSpeedGroup);
    sciSpeedState = @"installed: TTKMediaSpeedControlService (3 selectors)";
    SCILogV(@"[Speed] %@", sciSpeedState);
}
