// SCIKeychain: the retry-in-own-group rule (with fake originals) and the pointer take-over (against this executable's own SecItem stub).
// The executable runs from a folder named *.app, because only images inside an app bundle are touched.
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#include "../../src/Features/Sideload/SCIKeychain.m"

static int failures = 0;
#define CHECK(cond, label) do { if (!(cond)) { printf("FAIL  %s\n", label); failures++; } else printf("ok    %s\n", label); } while (0)

static NSMutableArray<NSString *> *asked;
static OSStatus fakeCopy(CFDictionaryRef q, CFTypeRef *r) {
    NSString *g = (__bridge NSString *)CFDictionaryGetValue(q, kSecAttrAccessGroup);
    [asked addObject:g ?: @"(none)"];
    return [g isEqualToString:@"OLD.com.burbn.instagram"] ? errSecMissingEntitlement : errSecItemNotFound;
}
static OSStatus fakeAdd(CFDictionaryRef q, CFTypeRef *r) {
    if (!CFDictionaryGetValue(q, kSecAttrAccessGroup) && r) {   // the probe: no group named -> the keychain reports the app's own
        *r = CFBridgingRetain(@{(__bridge id)kSecAttrAccessGroup: @"NEW.com.me.instagram"});
        return errSecSuccess;
    }
    return errSecMissingEntitlement;
}
static OSStatus fakeDelete(CFDictionaryRef q) { return errSecSuccess; }

int main(void) { @autoreleasepool {
    asked = [NSMutableArray array];
    sLock = [NSObject new]; sCopy = fakeCopy; sAdd = fakeAdd; sDelete = fakeDelete;

    NSDictionary *refused = @{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword, (__bridge id)kSecAttrAccessGroup: @"OLD.com.burbn.instagram"};
    CFTypeRef out = NULL;
    OSStatus status = SCICopy((__bridge CFDictionaryRef)refused, &out);
    CHECK(asked.count == 2 && [asked[1] isEqualToString:@"NEW.com.me.instagram"], "a refused group is asked again in the app's own");
    CHECK(status == errSecItemNotFound, "the answer of the second ask is the one returned");
    CHECK(atomic_load(&sRefused[kCopy]) == 1 && atomic_load(&sRetried[kCopy]) == 1 && atomic_load(&sRescued[kCopy]) == 1, "refused, asked again and worked are counted");

    [asked removeAllObjects];
    NSDictionary *accepted = @{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword, (__bridge id)kSecAttrAccessGroup: @"OTHER.x"};
    status = SCICopy((__bridge CFDictionaryRef)accepted, &out);
    CHECK(asked.count == 1 && [asked[0] isEqualToString:@"OTHER.x"], "a request the keychain accepts is made once, unchanged");

    [asked removeAllObjects];
    NSDictionary *none = @{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword};
    SCICopy((__bridge CFDictionaryRef)none, &out);
    CHECK(asked.count == 1, "a request with no group is never touched");

    NSDictionary *add = @{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword, (__bridge id)kSecAttrAccessGroup: @"OLD.com.burbn.instagram"};
    CHECK(SCIAdd((__bridge CFDictionaryRef)add, &out) == errSecMissingEntitlement, "an add refused in both groups reports the refusal (nothing hidden)");

    // The take-over: this executable's own call to SecItemCopyMatching reaches the replacement.
    sCopy = NULL; sAdd = NULL; sDelete = NULL; sUpdate = NULL; sState = nil; sLock = nil;
    for (int k = 0; k < kKinds; k++) atomic_store(&sCalls[k], 0);
    SCIKeychainInstall();
    NSDictionary *real = @{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword, (__bridge id)kSecAttrService: @"albrhi.no.such.service"};
    CFTypeRef found = NULL;
    SecItemCopyMatching((__bridge CFDictionaryRef)real, &found);
    CHECK(atomic_load(&sPointers) >= 1, "the SecItem pointer of an image inside an app bundle is taken over");
    CHECK(atomic_load(&sCalls[kCopy]) == 1, "a real call reaches the replacement once");
    CHECK(SCIKeychainReportLines().count >= 6, "the report has its lines");
    printf(failures ? "KEYCHAIN TESTS FAILED\n" : "keychain: all passed\n");
} return failures ? 1 : 0; }
