//
//  SCIYTSignInFix.m
//  Albrhi for YouTube
//
//  **Why a copy installed as an IPA cannot sign in, read from the app and from what the sign-in library asks.**
//
//  The App Store build is signed by Google's team (`EQHXZ8M8AV`, read from the entitlements of the 21.47.6 binary) and is entitled to three keychain
//  groups, `EQHXZ8M8AV.com.google.ios.youtube`, `….com.google.common.SSO` and `….com.google.common.folsom`, and to three app groups. Whoever re-signs it
//  -- a developer account, an enterprise certificate, a signing service -- signs under *their* team, so none of those names is theirs to use:
//
//    * the keychain refuses a write into a group the signature does not list (`errSecMissingEntitlement`, -34018), and Google's sign-in library
//      (`SSOKeychainHelper +accessGroup` / `+sharedAccessGroup`) writes the account into exactly such a group. Nothing is saved, so sign-in "works"
//      and the next launch is signed out;
//    * `-[NSFileManager containerURLForSecurityApplicationGroupIdentifier:]` answers nil for the app groups, and the library's shared files have no home;
//    * and the sign-in request carries a device-attestation challenge (`device_challenge_request`, produced by `SSOIOSGuardManagerImpl`) that Google's
//      attestation cannot answer for a copy it did not sign, which is the "Google can't verify this app is safe" refusal people see.
//
//  **What this does, and only for a copy that is not Google's.** It asks the keychain which group *this* copy owns (the documented way: add an item and
//  read `kSecAttrAccessGroup` back) and, when that group's team is not Google's, (1) answers that group where the library asks for its own,
//  (2) gives a shared-files folder inside the app's own container where the system gives none, and (3) leaves the attestation challenge out of the
//  sign-in request. (3) *withholds* a field; it never invents an answer to it. On the App Store build and on a jailbroken device with the original
//  signature the team is Google's, every one of these steps answers the original, and nothing changes.
//
//  The idea of each step is the community's and is old (2022: PoomSmart's `RemoveDeviceChallenge`, BandarHL's `fixYouTubeLogin`, both for 17.x, neither said to
//  work on 21.x). **None of that code was used**: the three selectors below were found in the 21.47.6 binary (`SSOKeychainHelper` has the group
//  accessors now, `SSOKeychainCore` and `SSOKeychain` no longer do) and are hooked only where the class declares them with the encoding read there.
//
//  Installed from the constructor, not at the first moment the app is active: the library reads its saved accounts while the app starts, and a read
//  made with the original group finds nothing -- the signed-out-after-restart fault the 2022 fixes had.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <objc/runtime.h>
#import <substrate.h>
#import <stdatomic.h>
#import "SCIYTSignInFix.h"
#import "../../SCILog.h"

static NSString *const kSCIGoogleTeam = @"EQHXZ8M8AV";

static atomic_ulong sGroupAsked, sGroupAnswered, sContainerAnswered, sRequestsSeen, sChallengeRemoved;
static NSString *sLastBodyKeys;
static NSMutableArray<NSString *> *sNotes;

// -- whose signature is this ----------------------------------------------------------------------------------------------------------------------

static NSString *sOwnGroup;      // "TEAM.bundle.id" -- the group this copy's keychain writes go to by default
static NSString *sOwnTeam;
static OSStatus sProbeStatus;

static void SCIYTProbeOwnGroup(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // The documented way to learn an app's own default access group: put one throwaway item in and read the group it landed in. It is removed again
        // at once, so nothing is left in the keychain.
        NSDictionary *base = @{ (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                                (__bridge id)kSecAttrService: @"albrhi.signin-probe",
                                (__bridge id)kSecAttrAccount: @"albrhi.signin-probe" };
        NSMutableDictionary *add = [base mutableCopy];
        add[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlock;
        add[(__bridge id)kSecReturnAttributes] = @YES;

        CFTypeRef result = NULL;
        OSStatus status = SecItemAdd((__bridge CFDictionaryRef)add, &result);
        if (status == errSecDuplicateItem) {
            NSMutableDictionary *query = [base mutableCopy];
            query[(__bridge id)kSecReturnAttributes] = @YES;
            if (result) { CFRelease(result); result = NULL; }
            status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
        }
        sProbeStatus = status;
        if (status == errSecSuccess && result) {
            NSString *group = ((__bridge NSDictionary *)result)[(__bridge id)kSecAttrAccessGroup];
            if ([group isKindOfClass:NSString.class] && group.length) {
                sOwnGroup = [group copy];
                NSRange dot = [group rangeOfString:@"."];
                sOwnTeam = dot.location != NSNotFound ? [group substringToIndex:dot.location] : nil;
            }
        }
        if (result) CFRelease(result);
        SecItemDelete((__bridge CFDictionaryRef)base);
    });
}

/// YES only for a copy whose own keychain group is known and is not Google's.
static BOOL SCIYTRepairActive(void) {
    SCIYTProbeOwnGroup();
    return sOwnGroup.length && sOwnTeam.length && ![sOwnTeam isEqualToString:kSCIGoogleTeam];
}

// -- the three repairs ----------------------------------------------------------------------------------------------------------------------------

/// Takes the sign-in request's JSON body, if it is one, and leaves the attestation challenge out of it. Key names are noted for the report; no value is.
static void SCIYTScrubSignInRequest(NSMutableURLRequest *request) {
    atomic_fetch_add(&sRequestsSeen, 1);
    NSData *data = [request isKindOfClass:NSMutableURLRequest.class] ? request.HTTPBody : nil;
    if (!data.length) return;

    id parsed = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    if (![parsed isKindOfClass:NSMutableDictionary.class]) return;
    NSMutableDictionary *body = parsed;

    NSArray *keys = [[body allKeys] sortedArrayUsingSelector:@selector(compare:)];
    @synchronized ([NSNull null]) { sLastBodyKeys = [keys componentsJoinedByString:@", "]; }

    if (!body[@"device_challenge_request"]) return;
    [body removeObjectForKey:@"device_challenge_request"];
    NSData *rewritten = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    if (!rewritten) return;
    request.HTTPBody = rewritten;
    // The length was written for the old body; a request that says one length and sends another is refused by the server.
    if ([request valueForHTTPHeaderField:@"Content-Length"]) [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)rewritten.length] forHTTPHeaderField:@"Content-Length"];
    atomic_fetch_add(&sChallengeRemoved, 1);
}

static BOOL SCIYTHookMethod(NSString *className, BOOL classMethod, NSString *selectorName, const char *expected, IMP (^make)(SEL selector, IMP *orig)) {
    NSString *label = [NSString stringWithFormat:@"%@%@ %@", classMethod ? @"+" : @"-", className, selectorName];
    Class cls = objc_getClass(className.UTF8String);
    if (!cls) { [sNotes addObject:[label stringByAppendingString:@" — class not in this build"]]; return NO; }

    SEL selector = NSSelectorFromString(selectorName);
    Class target = classMethod ? object_getClass(cls) : cls;
    Method method = class_getInstanceMethod(target, selector);
    if (!method) { [sNotes addObject:[label stringByAppendingString:@" — method not on this build"]]; return NO; }

    const char *actual = method_getTypeEncoding(method);
    if (!actual || strcmp(actual, expected) != 0) {
        [sNotes addObject:[NSString stringWithFormat:@"%@ — not hooked: encoding is %s, expected %s", label, actual ?: "?", expected]];
        return NO;
    }

    IMP *orig = calloc(1, sizeof(IMP));
    MSHookMessageEx(target, selector, make(selector, orig), orig);
    [sNotes addObject:[label stringByAppendingString:@" — hooked"]];
    return YES;
}

static void SCIYTInstallSignInFix(void) {
    sNotes = [NSMutableArray array];

    // 1. Where the sign-in library keeps what it saves.
    for (NSString *name in @[@"accessGroup", @"sharedAccessGroup"]) {
        SCIYTHookMethod(@"SSOKeychainHelper", YES, name, "@16@0:8", ^IMP(SEL selector, IMP *orig) {
            return imp_implementationWithBlock(^id(id me) {
                atomic_fetch_add(&sGroupAsked, 1);
                if (SCIYTRepairActive()) { atomic_fetch_add(&sGroupAnswered, 1); return sOwnGroup; }
                return *orig ? ((id (*)(id, SEL))*orig)(me, selector) : nil;
            });
        });
    }

    // 2. The sign-in request, without the challenge this copy cannot answer.
    SCIYTHookMethod(@"SSOService", YES, @"fetcherWithRequest:configuration:", "@32@0:8@16@24", ^IMP(SEL selector, IMP *orig) {
        return imp_implementationWithBlock(^id(id me, id request, id configuration) {
            if (SCIYTRepairActive()) SCIYTScrubSignInRequest(request);
            return *orig ? ((id (*)(id, SEL, id, id))*orig)(me, selector, request, configuration) : nil;
        });
    });

    // 3. A shared-files folder where the system gives none. Only for Google's group names, only when the system answered nothing.
    SCIYTHookMethod(@"NSFileManager", NO, @"containerURLForSecurityApplicationGroupIdentifier:", "@24@0:8@16", ^IMP(SEL selector, IMP *orig) {
        return imp_implementationWithBlock(^id(id me, NSString *group) {
            id real = *orig ? ((id (*)(id, SEL, id))*orig)(me, selector, group) : nil;
            if (real || ![group isKindOfClass:NSString.class] || ![group hasPrefix:@"group.com.google."] || !SCIYTRepairActive()) return real;

            NSURL *documents = [[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
            NSURL *folder = [[documents URLByAppendingPathComponent:@"AppGroup" isDirectory:YES] URLByAppendingPathComponent:group isDirectory:YES];
            [NSFileManager.defaultManager createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:nil];
            atomic_fetch_add(&sContainerAnswered, 1);
            return folder;
        });
    });
}

NSString *SCIYTSignInReport(void) {
    SCIYTProbeOwnGroup();

    NSString *bundle = NSBundle.mainBundle.bundleIdentifier ?: @"?";
    NSMutableString *out = [NSMutableString string];
    if (!sOwnGroup.length) {
        [out appendFormat:@"  this copy's own keychain group could not be read (status %d) — nothing is repaired\n", (int)sProbeStatus];
    } else {
        BOOL google = [sOwnTeam isEqualToString:kSCIGoogleTeam];
        [out appendFormat:@"  signed by team %@ — %@\n", sOwnTeam, google ? @"Google's: every step below answers the original, nothing is changed" : @"not Google's (an IPA): the repair is on"];
    }
    [out appendFormat:@"  bundle id: %@ %@\n", bundle, [bundle hasPrefix:@"com.google.ios.youtube"] ? @"(starts with Google's, as the sign-in needs)" : @"— does NOT start with com.google.ios.youtube: the sign-in can refuse for that alone; re-sign keeping that prefix"];
    [out appendFormat:@"  keychain group asked %lu · answered with this copy's own %lu\n", atomic_load(&sGroupAsked), atomic_load(&sGroupAnswered)];
    [out appendFormat:@"  sign-in requests seen %lu · challenge left out %lu · shared-files folder given %lu\n", atomic_load(&sRequestsSeen), atomic_load(&sChallengeRemoved), atomic_load(&sContainerAnswered)];
    @synchronized ([NSNull null]) {
        if (sLastBodyKeys.length) [out appendFormat:@"  last request body keys: %@\n", sLastBodyKeys];
    }
    for (NSString *note in sNotes) [out appendFormat:@"  hook %@\n", note];
    return out;
}

__attribute__((constructor)) static void SCIYTSignInFixRegister(void) {
    SCIYTInstallSignInFix();
}
