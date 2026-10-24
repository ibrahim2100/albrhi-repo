#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "SCITTBypass.h"
#import "../../Prefs.h"
#import "../../SCILog.h"
#import "../../Diagnostics/SCITTDiagnostics.h"

///
/// Every hook here answers one question TikTok's own code asks about the device, the
/// way an unmodified phone would answer it. Nothing here touches a purchase, a receipt
/// value, or a subscription flag -- that line is deliberate, the same one Locket's own
/// bypass keeps, and reviewed the same way before writing a line of this file.
///
/// Each class is declared where it is hooked, forward-declared as `NSObject` with only
/// the one selector this file sends it -- the same minimal-declaration discipline the
/// rest of this project uses for a hooked class it does not otherwise touch.
///

@interface TTAdSplashDeviceHelper : NSObject
@end

@interface GULAppEnvironmentUtil : NSObject
@end

@interface FBSDKAppEventsUtility : NSObject
@end

@interface AWEAPMManager : NSObject
@end

@interface AWESecurity : NSObject
- (void)resetCollectMode;
@end

@interface IOSSecuritySuite : NSObject
@end

@interface AppsFlyerUtils : NSObject
@end

@interface IESLiveDeviceInfo : NSObject
@end

@interface TTInstallUtil : NSObject
@end


%group Bypass

// The direct question: is this device jailbroken. Confirmed as a real selector on
// TikTok 46.4.0's own binary before this was written, not guessed at.
%hook TTAdSplashDeviceHelper

+ (BOOL)isJailBroken {
    if (!SCIPrefEnabled(SCIPrefBypass)) return %orig;
    [SCITTDiagnostics recordBypassAnswer:@"isJailBroken"];
    return NO;
}

%end


// Google's own environment probe, asked here for whether the app looks like a genuine
// App Store install running as itself.
%hook GULAppEnvironmentUtil

+ (BOOL)isFromAppStore {
    if (!SCIPrefEnabled(SCIPrefBypass)) return %orig;
    [SCITTDiagnostics recordBypassAnswer:@"isFromAppStore"];
    return YES;
}

+ (BOOL)isAppStoreReceiptSandbox {
    if (!SCIPrefEnabled(SCIPrefBypass)) return %orig;
    [SCITTDiagnostics recordBypassAnswer:@"isAppStoreReceiptSandbox"];
    return NO;
}

+ (BOOL)isAppExtension {
    if (!SCIPrefEnabled(SCIPrefBypass)) return %orig;
    [SCITTDiagnostics recordBypassAnswer:@"isAppExtension"];
    return YES;
}

%end


// Meta's SDK, asked whether this is a debug build -- a jailbroken, resigned app can
// answer this differently from a genuine App Store one.
%hook FBSDKAppEventsUtility

- (BOOL)isDebugBuild {
    if (!SCIPrefEnabled(SCIPrefBypass)) return %orig;
    [SCITTDiagnostics recordBypassAnswer:@"isDebugBuild"];
    return NO;
}

%end


// TikTok's own signing-info check, answered as a plain App Store install.
%hook AWEAPMManager

+ (id)signInfo {
    if (!SCIPrefEnabled(SCIPrefBypass)) return %orig;
    [SCITTDiagnostics recordBypassAnswer:@"signInfo"];
    return @"AppStore";
}

%end


// Whatever this collects, it is collected about the device's own modification state --
// answered by doing nothing, the same shape as every hook above it.
%hook AWESecurity

- (void)resetCollectMode {
    if (!SCIPrefEnabled(SCIPrefBypass)) {
        %orig;
        return;
    }
    [SCITTDiagnostics recordBypassAnswer:@"resetCollectMode"];
}

%end


// A general-purpose jailbreak-detection library some apps vendor wholesale rather than
// write their own checks -- confirmed present by class name in this build, cross-
// validated between both newer reference tweaks.
%hook IOSSecuritySuite

+ (BOOL)amIJailbroken {
    if (!SCIPrefEnabled(SCIPrefBypass)) return %orig;
    [SCITTDiagnostics recordBypassAnswer:@"amIJailbroken"];
    return NO;
}

%end


// AppsFlyer's own device-integrity check, asked with the option to skip its own more
// advanced validation -- answered as an unmodified device either way.
%hook AppsFlyerUtils

+ (BOOL)isJailbrokenWithSkipAdvancedJailbreakValidation:(BOOL)skip {
    if (!SCIPrefEnabled(SCIPrefBypass)) return %orig;
    [SCITTDiagnostics recordBypassAnswer:@"AppsFlyer isJailbroken"];
    return NO;
}

%end


// TikTok's own live-streaming device-info object, asked the same question its
// download and signing checks are.
%hook IESLiveDeviceInfo

+ (BOOL)isJailBroken {
    if (!SCIPrefEnabled(SCIPrefBypass)) return %orig;
    [SCITTDiagnostics recordBypassAnswer:@"IESLiveDeviceInfo isJailBroken"];
    return NO;
}

%end


%hook TTInstallUtil

+ (BOOL)isJailBroken {
    if (!SCIPrefEnabled(SCIPrefBypass)) return %orig;
    [SCITTDiagnostics recordBypassAnswer:@"TTInstallUtil isJailBroken"];
    return NO;
}

%end


// PIPOStoreKitHelper is deliberately left alone even though a reference tweak names an
// -isJailBroken selector on it -- this project's own TikTok changelog (v0.1.0) already
// drew the line at that class and its sibling PIPOIAPStoreManager, the same way
// Check0verPlus was refused for Locket: it sits inside the in-app-purchase/StoreKit
// surface, and one confirmed method on it is not enough reason to cross a boundary this
// project set on purpose. If a jailbreak question genuinely needs answering there, it
// is answered upstream by the six checks already hooked above -- TikTok never asks the
// same question in only one place.


// A signed app has no embedded provisioning profile; a resigned one usually does, and
// this is one of the places that gets checked for. Only the one file extension is
// touched -- every other resource lookup passes straight through.
%hook NSBundle

- (NSString *)pathForResource:(NSString *)name ofType:(NSString *)extension {
    if ([extension isEqualToString:@"mobileprovision"] && SCIPrefEnabled(SCIPrefBypass)) {
        [SCITTDiagnostics recordBypassAnswer:@"mobileprovision lookup"];
        return nil;
    }
    return %orig;
}

%end

%end


// **Two answers that are installed only where the process already has the selector.** Logos *adds* a
// method to a class that lacks it: an added `-btd_isJailBroken` on UIDevice is a selector the app never
// sends, and an added `-jailbroken` on NSObject would make every object in the process answer
// `respondsToSelector:@selector(jailbroken)` with YES -- a side effect on code that never asked, with
// nothing to call when the switch is off. Neither selector is declared by any class in the 46.4.0 or
// 47.1.0 dumps; each is a category method if it exists at all, so the question is put to the runtime.
%group BypassUIDevice
%hook UIDevice

- (BOOL)btd_isJailBroken {
    if (!SCIPrefEnabled(SCIPrefBypass)) return %orig;
    [SCITTDiagnostics recordBypassAnswer:@"btd_isJailBroken"];
    return NO;
}

%end
%end

%group BypassNSObject
%hook NSObject

- (BOOL)jailbroken {
    if (!SCIPrefEnabled(SCIPrefBypass)) return %orig;
    [SCITTDiagnostics recordBypassAnswer:@"jailbroken"];
    return NO;
}

%end
%end


void SCITTInstallBypass(void) {
    %init(Bypass);

    NSMutableArray *absent = [NSMutableArray array];
    if (class_getInstanceMethod([UIDevice class], sel_registerName("btd_isJailBroken"))) {
        %init(BypassUIDevice);
    } else {
        [absent addObject:@"-[UIDevice btd_isJailBroken]"];
    }
    if (class_getInstanceMethod([NSObject class], sel_registerName("jailbroken"))) {
        %init(BypassNSObject);
    } else {
        [absent addObject:@"-[NSObject jailbroken]"];
    }
    SCILogV(@"bypass hooks attached; not attached, selector not in this process: %@",
            absent.count ? [absent componentsJoinedByString:@", "] : @"none");
}
