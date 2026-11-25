#import <Foundation/Foundation.h>
#import "../../src/Features/Sideload/SCIReceipt.h"
static int failures = 0;
#define CHECK(cond, label) do { if (!(cond)) { printf("FAIL  %s\n", label); failures++; } else printf("ok    %s\n", label); } while (0)
int main(void) { @autoreleasepool {
    NSURL *sandbox = [NSURL fileURLWithPath:@"/var/mobile/Containers/Bundle/Application/X/Instagram.app/StoreKit/sandboxReceipt"];
    NSURL *store = [NSURL fileURLWithPath:@"/var/mobile/Containers/Bundle/Application/X/Instagram.app/StoreKit/receipt"];
    CHECK([SCIReceiptRewritten(sandbox).path hasSuffix:@"/Instagram.app/StoreKit/receipt"], "sandboxReceipt becomes receipt, same folder");
    CHECK([SCIReceiptRewritten(store) isEqual:store], "a store receipt address is untouched");
    CHECK(SCIReceiptRewritten(nil) == nil, "nil stays nil");
    CHECK([SCIReceiptRewritten([NSURL fileURLWithPath:@"/tmp/sandboxReceiptX"]).path isEqualToString:@"/tmp/sandboxReceiptX"], "a name that only starts with it is untouched");
    CHECK([SCIReceiptReportLines().firstObject containsString:@"asked for 1 time"], "the report counts the rewrite");
    printf(failures ? "RECEIPT TESTS FAILED\n" : "receipt: all passed\n");
} return failures ? 1 : 0; }
