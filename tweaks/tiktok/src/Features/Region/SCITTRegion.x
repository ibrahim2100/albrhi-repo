//
//  SCITTRegion.x
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "SCITTRegion.h"
#import "SCITTRegionTable.h"
#import "../../Prefs.h"
#import "../../SCILog.h"

///
/// **Which country TikTok believes the phone is in -- chosen by the person, never by default.**
///
/// The reference this was read from (BHTikTok's family) ships the switch on and a country picked for the person, to
/// get recommendations from somewhere else. Here nothing is rewritten until somebody picks a country, the row says
/// what it does, and picking the real one again puts every answer back: **only getters are answered**, so nothing
/// TikTok stored is ever overwritten with a country the phone is not in (a hook on a setter would leave the lie in
/// TikTok's own cache after the switch went off).
///
/// What it costs, stated where it is chosen: TikTok is told something untrue about the device. That can change what
/// the app offers, and an account that is moved between regions can be asked to verify itself. It is a choice, not a
/// repair.
///
/// Every class below was read from 46.4.0's MusicallyCore with tools/objc-classes.py before a hook was written
/// (`TTKPassportAppStoreRegionModel`, which the reference hooks, is NOT in that binary and is left out).
///

static NSUInteger sciRegionAnswered = 0;
static NSString *sciRegionState = nil;

static NSDictionary *SCITTChosenRegion(void) {
    if (!SCIPanelAllowsThisApp()) return nil;
    NSString *code = [[NSUserDefaults standardUserDefaults] stringForKey:SCIPrefRegionCode];
    return code.length ? SCITTRegionFind(code) : nil;
}

static NSString *SCITTRegionCodeLower(void)  { NSDictionary *r = SCITTChosenRegion(); if (r) sciRegionAnswered++; return [r[@"code"] lowercaseString]; }
static NSString *SCITTRegionCodeUpper(void)  { NSDictionary *r = SCITTChosenRegion(); if (r) sciRegionAnswered++; return [r[@"code"] uppercaseString]; }
static NSString *SCITTRegionMCCMNC(void)     { NSDictionary *r = SCITTChosenRegion(); if (!r) return nil; sciRegionAnswered++; return [r[@"mcc"] stringByAppendingString:r[@"mnc"]]; }
static NSString *SCITTRegionMCC(void)        { NSDictionary *r = SCITTChosenRegion(); if (r) sciRegionAnswered++; return r[@"mcc"]; }
static NSString *SCITTRegionMNC(void)        { NSDictionary *r = SCITTChosenRegion(); if (r) sciRegionAnswered++; return r[@"mnc"]; }

static BOOL SCITTHas(Class cls, BOOL meta, const char *selector, const char *encoding) {
    if (!cls) return NO;
    Method method = class_getInstanceMethod(meta ? object_getClass(cls) : cls, sel_registerName(selector));
    const char *types = method ? method_getTypeEncoding(method) : NULL;
    return types && strcmp(types, encoding) == 0;
}

%group SCITTRegionStoreService
%hook TTKStoreRegionService
- (id)storeRegion {
    NSString *mine = SCITTRegionCodeLower();
    if (!mine) return %orig;
    return mine;
}
- (id)getStoreRegion {
    NSString *mine = SCITTRegionCodeLower();
    if (!mine) return %orig;
    return mine;
}
%end
%end

%group SCITTRegionManagerGroup
%hook TIKTOKRegionManager
+ (id)region {
    NSString *mine = SCITTRegionCodeUpper();
    if (!mine) return %orig;
    return mine;
}
+ (id)systemRegion {
    NSString *mine = SCITTRegionCodeUpper();
    if (!mine) return %orig;
    return mine;
}
+ (id)storeRegion {
    NSString *mine = SCITTRegionCodeUpper();
    if (!mine) return %orig;
    return mine;
}
+ (id)currentRegionV2 {
    NSString *mine = SCITTRegionCodeUpper();
    if (!mine) return %orig;
    return mine;
}
+ (id)localRegion {
    NSString *mine = SCITTRegionCodeUpper();
    if (!mine) return %orig;
    return mine;
}
+ (id)carrierRegion {
    NSString *mine = SCITTRegionCodeUpper();
    if (!mine) return %orig;
    return mine;
}
+ (id)mccmnc {
    NSString *mine = SCITTRegionMCCMNC();
    if (!mine) return %orig;
    return mine;
}
%end
%end

%group SCITTRegionCache
%hook ATSRegionCacheManager
- (id)getRegion {
    NSString *mine = SCITTRegionCodeLower();
    if (!mine) return %orig;
    return mine;
}
- (id)region {
    NSString *mine = SCITTRegionCodeLower();
    if (!mine) return %orig;
    return mine;
}
- (id)storeRegionFromCache {
    NSString *mine = SCITTRegionCodeLower();
    if (!mine) return %orig;
    return mine;
}
%end
%end

%group SCITTRegionModelGroup
%hook TTKStoreRegionModel
- (id)storeRegion {
    NSString *mine = SCITTRegionCodeUpper();
    if (!mine) return %orig;
    return mine;
}
%end
%end

%group SCITTRegionInstallID
%hook TTInstallIDManager
- (id)currentAppRegion {
    NSString *mine = SCITTRegionCodeUpper();
    if (!mine) return %orig;
    return mine;
}
%end
%end

%group SCITTRegionInstallConfig
%hook BDInstallGlobalConfig
- (id)currentAppRegion {
    NSString *mine = SCITTRegionCodeUpper();
    if (!mine) return %orig;
    return mine;
}
%end
%end

%group SCITTRegionCarrier
%hook CTCarrier
- (id)isoCountryCode {
    NSString *mine = SCITTRegionCodeLower();
    if (!mine) return %orig;
    return mine;
}
- (id)mobileCountryCode {
    NSString *mine = SCITTRegionMCC();
    if (!mine) return %orig;
    return mine;
}
- (id)mobileNetworkCode {
    NSString *mine = SCITTRegionMNC();
    if (!mine) return %orig;
    return mine;
}
%end
%end

NSString *SCITTRegionReport(void) {
    NSDictionary *chosen = SCITTChosenRegion();
    return [NSString stringWithFormat:@"%@; chosen: %@; answered with it: %lu",
            sciRegionState ?: @"not installed", chosen ? chosen[@"code"] : @"real (nothing rewritten)", (unsigned long)sciRegionAnswered];
}

void SCITTInstallRegion(void) {
    NSMutableArray *installed = [NSMutableArray array], *skipped = [NSMutableArray array];
    const char *obj = "@16@0:8";

    Class service = NSClassFromString(@"TTKStoreRegionService");
    if (SCITTHas(service, NO, "storeRegion", obj) && SCITTHas(service, NO, "getStoreRegion", obj)) {
        %init(SCITTRegionStoreService); [installed addObject:@"TTKStoreRegionService"];
    } else { [skipped addObject:@"TTKStoreRegionService"]; }

    Class manager = NSClassFromString(@"TIKTOKRegionManager");
    BOOL managerOK = manager != nil;
    const char *managerSelectors[] = { "region", "systemRegion", "storeRegion", "currentRegionV2", "localRegion", "carrierRegion", "mccmnc" };
    for (size_t i = 0; i < sizeof(managerSelectors) / sizeof(managerSelectors[0]); i++) managerOK = managerOK && SCITTHas(manager, YES, managerSelectors[i], obj);
    if (managerOK) { %init(SCITTRegionManagerGroup); [installed addObject:@"TIKTOKRegionManager"]; }
    else { [skipped addObject:@"TIKTOKRegionManager"]; }

    Class cache = NSClassFromString(@"ATSRegionCacheManager");
    if (SCITTHas(cache, NO, "getRegion", obj) && SCITTHas(cache, NO, "region", obj) && SCITTHas(cache, NO, "storeRegionFromCache", obj)) {
        %init(SCITTRegionCache); [installed addObject:@"ATSRegionCacheManager"];
    } else { [skipped addObject:@"ATSRegionCacheManager"]; }

    if (SCITTHas(NSClassFromString(@"TTKStoreRegionModel"), NO, "storeRegion", obj)) {
        %init(SCITTRegionModelGroup); [installed addObject:@"TTKStoreRegionModel"];
    } else { [skipped addObject:@"TTKStoreRegionModel"]; }

    if (SCITTHas(NSClassFromString(@"TTInstallIDManager"), NO, "currentAppRegion", obj)) {
        %init(SCITTRegionInstallID); [installed addObject:@"TTInstallIDManager"];
    } else { [skipped addObject:@"TTInstallIDManager"]; }

    if (SCITTHas(NSClassFromString(@"BDInstallGlobalConfig"), NO, "currentAppRegion", obj)) {
        %init(SCITTRegionInstallConfig); [installed addObject:@"BDInstallGlobalConfig"];
    } else { [skipped addObject:@"BDInstallGlobalConfig"]; }

    Class carrier = NSClassFromString(@"CTCarrier");
    if (SCITTHas(carrier, NO, "isoCountryCode", obj) && SCITTHas(carrier, NO, "mobileCountryCode", obj) && SCITTHas(carrier, NO, "mobileNetworkCode", obj)) {
        %init(SCITTRegionCarrier); [installed addObject:@"CTCarrier"];
    } else { [skipped addObject:@"CTCarrier"]; }

    sciRegionState = [NSString stringWithFormat:@"installed: %@%@",
                      installed.count ? [installed componentsJoinedByString:@", "] : @"none",
                      skipped.count ? [@" — skipped: " stringByAppendingString:[skipped componentsJoinedByString:@", "]] : @""];
    SCILogV(@"[Region] %@", sciRegionState);
}
