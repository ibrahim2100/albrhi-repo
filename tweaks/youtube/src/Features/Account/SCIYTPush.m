//
//  SCIYTPush.m
//  Albrhi for YouTube
//
//  **The cause of "no notifications, only on the IPA", read off the copy.**
//
//  The App Store build is signed by Google with `aps-environment = production` under team EQHXZ8M8AV (read from the decrypted IPA's own signature:
//  `application-identifier EQHXZ8M8AV.com.google.ios.youtube`). A tool that installs an IPA throws that signature away and signs again with the installer's
//  own certificate and profile, and two things follow whatever the tool:
//
//    1. **No `aps-environment` in the new signature** (a free or personal profile cannot carry push; a wildcard App ID cannot either): iOS refuses to
//       register the app and the app is told `NSCocoaErrorDomain 3000`. No token exists, so nothing can be sent.
//    2. **Even with one** (a paid profile with an explicit App ID that has Push enabled), the device token is bound to the *signer's* team and bundle id.
//       Google's servers send to topic `com.google.ios.youtube` under their own team; APNs answers `DeviceTokenNotForTopic` and drops it.
//
//  Neither can be repaired from inside the app. What this does is show which of them is the one on *this* phone, instead of arguing it: the signature
//  the process runs under, the answer iOS gave when the app registered, and the permission. Only a copy that keeps Google's own signature (a tweak
//  injected into the App Store app on a jailbreak) gets pushes.
//
//  Reads only. `SecTask` is read through `dlsym` (its header is private) and nothing is called that changes state.
//

#import "SCIYTPush.h"
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import "../../SCIYTLaunchGuard.h"
#import "../../SCILog.h"

#ifdef __cplusplus
extern "C" {
#endif
extern void MSHookMessageEx(Class, SEL, IMP, IMP *);
#ifdef __cplusplus
}
#endif

static NSString *const kSCIGoogleTeamPush = @"EQHXZ8M8AV";

static NSString *sRegisterResult;        // "token, N bytes" / "refused: domain code text"
static NSString *sHookNote = @"not yet installed";
static NSString *sPermission;            // from UNUserNotificationCenter, asked once

typedef const void *SCISecTaskRef;
typedef SCISecTaskRef (*SCISecTaskCreateFromSelf)(CFAllocatorRef);
typedef CFTypeRef (*SCISecTaskCopyValue)(SCISecTaskRef, CFStringRef, CFErrorRef *);

static id SCIYTEntitlement(NSString *name) {
    SCISecTaskCreateFromSelf create = (SCISecTaskCreateFromSelf)dlsym(RTLD_DEFAULT, "SecTaskCreateFromSelf");
    SCISecTaskCopyValue copy = (SCISecTaskCopyValue)dlsym(RTLD_DEFAULT, "SecTaskCopyValueForEntitlement");
    if (!create || !copy) return nil;
    SCISecTaskRef task = create(kCFAllocatorDefault);
    if (!task) return nil;
    CFTypeRef value = copy(task, (__bridge CFStringRef)name, NULL);
    CFRelease(task);
    return value ? CFBridgingRelease(value) : nil;
}

// -- what the app is told when it registers ----------------------------------------------------------------------------------------------------

static void (*origDidRegister)(id, SEL, id, id);
static void (*origDidFail)(id, SEL, id, id);

static void hookedDidRegister(id self, SEL _cmd, id application, id token) {
    sRegisterResult = [NSString stringWithFormat:@"a device token was issued (%lu bytes)", (unsigned long)[token isKindOfClass:NSData.class] ? [(NSData *)token length] : 0UL];
    if (origDidRegister) origDidRegister(self, _cmd, application, token);
}

static void hookedDidFail(id self, SEL _cmd, id application, id error) {
    NSError *e = [error isKindOfClass:NSError.class] ? error : nil;
    sRegisterResult = [NSString stringWithFormat:@"iOS refused: %@ %ld — %@", e.domain ?: @"?", (long)e.code, e.localizedDescription ?: @"?"];
    if (origDidFail) origDidFail(self, _cmd, application, error);
}

static BOOL SCIYTHookDelegate(Class delegate, const char *selector, IMP replacement, IMP *original) {
    SEL sel = sel_registerName(selector);
    Method method = class_getInstanceMethod(delegate, sel);
    const char *encoding = method ? method_getTypeEncoding(method) : NULL;
    if (!encoding || strcmp(encoding, "v32@0:8@16@24") != 0) return NO;
    MSHookMessageEx(delegate, sel, replacement, original);
    return *original != NULL;
}

static void SCIYTInstallPushWatch(void) {
    id delegate = [UIApplication sharedApplication].delegate;
    Class cls = delegate ? object_getClass(delegate) : Nil;
    if (!cls) { sHookNote = @"the app has no delegate to watch"; return; }

    BOOL a = SCIYTHookDelegate(cls, "application:didRegisterForRemoteNotificationsWithDeviceToken:", (IMP)hookedDidRegister, (IMP *)&origDidRegister);
    BOOL b = SCIYTHookDelegate(cls, "application:didFailToRegisterForRemoteNotificationsWithError:", (IMP)hookedDidFail, (IMP *)&origDidFail);
    sHookNote = [NSString stringWithFormat:@"watching %s (token %@, refusal %@)", class_getName(cls), a ? @"yes" : @"no", b ? @"yes" : @"no"];

    [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *s) {
        NSString *state = s.authorizationStatus == UNAuthorizationStatusAuthorized ? @"allowed"
                        : s.authorizationStatus == UNAuthorizationStatusDenied ? @"denied"
                        : s.authorizationStatus == UNAuthorizationStatusNotDetermined ? @"not asked yet"
                        : s.authorizationStatus == UNAuthorizationStatusProvisional ? @"provisional" : @"other";
        sPermission = [NSString stringWithFormat:@"%@ (alerts %ld, sounds %ld, badges %ld)", state,
                       (long)s.alertSetting, (long)s.soundSetting, (long)s.badgeSetting];
    }];
}

__attribute__((constructor)) static void SCIYTPushRegister(void) {
    SCIYTWhenActive(^{ SCIYTInstallPushWatch(); });
}

// -- the report --------------------------------------------------------------------------------------------------------------------------------

NSString *SCIYTPushReport(void) {
    NSString *appID = SCIYTEntitlement(@"application-identifier");
    id aps = SCIYTEntitlement(@"aps-environment");
    NSString *bundle = [NSBundle mainBundle].bundleIdentifier ?: @"?";

    NSString *team = nil;
    if ([appID isKindOfClass:NSString.class]) {
        NSRange dot = [appID rangeOfString:@"."];
        if (dot.location != NSNotFound) team = [appID substringToIndex:dot.location];
    }
    BOOL google = [team isEqualToString:kSCIGoogleTeamPush];
    BOOL hasAPS = [aps isKindOfClass:NSString.class] && [(NSString *)aps length] > 0;
    BOOL registered = [UIApplication sharedApplication].isRegisteredForRemoteNotifications;

    NSMutableString *out = [NSMutableString string];
    [out appendFormat:@"  bundle id: %@%@\n", bundle, [bundle isEqualToString:@"com.google.ios.youtube"] ? @"" : @"  (not Google's: this copy was re-identified)"];
    [out appendFormat:@"  signed as: %@  (team %@ — %@)\n", appID ?: @"not readable", team ?: @"?",
        !team ? @"unknown" : (google ? @"Google's own signature" : @"NOT Google's: an IPA signed by whoever installed it")];
    [out appendFormat:@"  push entitlement (aps-environment): %@\n", hasAPS ? (NSString *)aps : @"ABSENT"];
    [out appendFormat:@"  iOS says registered for push: %@\n", registered ? @"yes" : @"no"];
    [out appendFormat:@"  when the app registered: %@\n", sRegisterResult ?: @"no answer seen in this launch (or the app registered before the watch was in place)"];
    [out appendFormat:@"  notification permission: %@\n", sPermission ?: @"not read yet"];
    [out appendFormat:@"  watch: %@\n", sHookNote];

    NSString *verdict;
    if (google && hasAPS) verdict = @"This copy carries Google's own signature and the push entitlement: nothing about the signing stops notifications. Look at the permission and at YouTube's own notification settings.";
    else if (!hasAPS) verdict = @"CAUSE: this copy was signed WITHOUT the push entitlement, so iOS refuses to register it and no token exists to send to. A personal/free profile or a wildcard App ID cannot carry push. It cannot be fixed from inside the app.";
    else verdict = @"CAUSE: the push entitlement is there but the signature is not Google's. The device token belongs to the signer's team and bundle id; Google sends to topic com.google.ios.youtube under its own team, and Apple drops it (DeviceTokenNotForTopic). It cannot be fixed from inside the app. Only a copy that keeps Google's signature (a tweak injected into the App Store app on a jailbreak) receives pushes.";
    [out appendFormat:@"  reading: %@\n", verdict];
    return out;
}
