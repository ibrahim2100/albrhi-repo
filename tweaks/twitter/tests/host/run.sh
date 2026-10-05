#!/usr/bin/env bash
#
# The timeline section filter, run on this Mac against the macOS SDK.
#
# Its decisions are pure: which item classes go, which module headers and footers go with an
# emptied module, how a Swift class name is matched in either of its two spellings. The code is
# copied out of SCITWTimelineFilter.x by marker -- not retyped -- so what passes is what ships.
# What this cannot say is which classes X 12.31 really puts in those sections: the class names
# are NeoFreeBird's and 12.20's, and the first device report says whether they matched.
#
#   bash tweaks/twitter/tests/host/run.sh
#
set -euo pipefail
cd "$(dirname "$0")"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

python3 - "$OUT" <<'PY'
import sys
src = open('../../src/Features/Timeline/SCITWTimelineFilter.x').read()
a = src.index('@interface TFNItemsDataViewController')
b = src.index('%group SectionDoorsCore')
assert a < b
open(sys.argv[1] + '/filter_region.inc', 'w').write(src[a:b])
PY

cat > "$OUT/Test.m" <<'EOM'
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "Prefs.h"
#import "SCILog.h"

// Stand-ins for what the region expects from UIKit: it declares one controller class and nothing
// in the logic below touches it.
@interface UIViewController : NSObject @end
@implementation UIViewController @end

#include "filter_region.inc"

static int fails = 0;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); fails++; } else printf("ok   %s\n", #c); } while (0)

/// A class registered under exactly this runtime name -- a dotted Swift name, a mangled one, or
/// plain ObjC -- with optional ivars.
static Class Make(NSString *name, NSArray<NSString *> *ivars) {
    Class existing = NSClassFromString(name);
    if (existing) return existing;
    Class cls = objc_allocateClassPair([NSObject class], name.UTF8String, 0);
    for (NSString *ivar in ivars) class_addIvar(cls, ivar.UTF8String, sizeof(id), log2(sizeof(id)), "@");
    objc_registerClassPair(cls);
    return cls;
}

static id Item(NSString *name) { return [[Make(name, @[]) alloc] init]; }

/// The runtime's mangled spelling of `Module.Class`, computed here independently of the code
/// under test so a typo in either shows as a failure.
static NSString *Mangled(NSString *module, NSString *cls) {
    return [NSString stringWithFormat:@"_TtC%lu%@%lu%@", (unsigned long)module.length, module,
            (unsigned long)cls.length, cls];
}

@interface MockStatus : NSObject @property BOOL isPromoted; @end
@implementation MockStatus @end

@interface Wrapper : NSObject @property (nonatomic, strong) id item; @end
@implementation Wrapper @end

// `class_addIvar` gives the ivar no ARC layout, so `object_setIvar` stores without retaining and
// the status would be freed under the item. Kept alive here, as the real object is by its owner.
static NSMutableArray *keepAlive;

static id StatusItem(BOOL promoted) {
    id item = [[Make(@"T1URTTimelineStatusItemViewModel", @[@"status"]) alloc] init];
    MockStatus *status = [[MockStatus alloc] init];
    status.isPromoted = promoted;
    if (!keepAlive) keepAlive = [NSMutableArray array];
    [keepAlive addObject:status];
    object_setIvar(item, class_getInstanceVariable([item class], "status"), status);
    return item;
}

static void SetPrefs(BOOL promoted, BOOL wtf, BOOL topics, BOOL trends, BOOL premium) {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setBool:promoted forKey:SCIPrefHidePromoted];
    [d setBool:wtf forKey:SCIPrefHideWhoToFollow];
    [d setBool:topics forKey:SCIPrefHideTopics];
    [d setBool:trends forKey:SCIPrefHideTrendVideos];
    [d setBool:premium forKey:SCIPrefHidePremiumOffer];
}

static void Reset(void) {
    memset(sciSecRemoved, 0, sizeof(sciSecRemoved));
    sciSecChromeRemoved = 0;
}

int main(void) {
    @autoreleasepool {
        // The name matcher: both spellings of a Swift class, and nothing that merely resembles one.
        CHECK(SCISecClassIs(@"TwitterURT.URTModuleHeaderViewModel", @"TwitterURT.URTModuleHeaderViewModel"));
        CHECK(SCISecClassIs(Mangled(@"TwitterURT", @"URTModuleHeaderViewModel"), @"TwitterURT.URTModuleHeaderViewModel"));
        CHECK(!SCISecClassIs(Mangled(@"TwitterURT", @"URTModuleHeaderViewModelX"), @"TwitterURT.URTModuleHeaderViewModel"));
        CHECK(!SCISecClassIs(@"_TtC10TwitterURT99URTModuleHeaderViewModel", @"TwitterURT.URTModuleHeaderViewModel"));
        CHECK(!SCISecClassIs(@"URTModuleHeaderViewModel", @"TwitterURT.URTModuleHeaderViewModel"));
        CHECK(!SCISecClassIs(@"", @"TwitterURT.URTModuleHeaderViewModel"));

        id plain = Item(@"SomeOtherItem");
        id ordinary = StatusItem(NO);
        id promoted = StatusItem(YES);
        id wtf = Item(@"T1URTTimelineUserItemViewModel");
        id topic = Item(@"TwitterURT.URTTimelinePromptViewModel");
        id header = Item(@"TwitterURT.URTModuleHeaderViewModel");
        id footer = Item(@"TwitterURT.URTModuleFooterViewModel");
        id ad = Item(Mangled(@"TwitterURT", @"URTTimelineGoogleNativeAdViewModel"));
        id offer = Item(@"TwitterURT.URTTimelineMessageItemViewModel");

        // Nothing switched on: the very same array comes back, untouched.
        SetPrefs(NO, NO, NO, NO, NO);
        NSArray *sections = @[@[plain, ordinary, promoted, wtf]];
        CHECK(SCISecFiltered(sections, 0) == sections);

        // Promoted only: the promoted status goes, the ordinary one and the others stay.
        Reset(); SetPrefs(YES, NO, NO, NO, NO);
        NSArray *out = SCISecFiltered(@[@[plain, ordinary, promoted, wtf]], 0);
        CHECK([out count] == 1 && [out[0] count] == 3);
        CHECK([out[0] containsObject:ordinary] && ![out[0] containsObject:promoted]);
        CHECK(sciSecRemoved[SCISecPromoted] == 1);

        // A promoted status the filter was told to keep (switch off) is kept.
        Reset(); SetPrefs(NO, YES, NO, NO, NO);
        out = SCISecFiltered(@[@[ordinary, promoted, wtf]], 0);
        CHECK([out[0] count] == 2 && [out[0] containsObject:promoted]);
        CHECK(sciSecRemoved[SCISecWhoToFollow] == 1);

        // A module whose only content is removed takes its header and footer with it, and a
        // section left with nothing is dropped.
        Reset(); SetPrefs(NO, YES, NO, NO, NO);
        out = SCISecFiltered(@[@[header, wtf, footer], @[ordinary]], 0);
        CHECK([out count] == 1 && [out[0] count] == 1 && out[0][0] == ordinary);
        CHECK(sciSecChromeRemoved == 2);

        // A module with content left keeps its header and footer.
        Reset(); SetPrefs(NO, YES, NO, NO, NO);
        out = SCISecFiltered(@[@[header, wtf, ordinary, footer]], 0);
        CHECK([out[0] count] == 3 && [out[0] containsObject:header] && [out[0] containsObject:footer]);
        CHECK(sciSecChromeRemoved == 0);

        // Items arrive wrapped in a TFNDataViewItem; the wrapper is looked through.
        Make(@"TFNDataViewItem", @[]);   // registered under the name the code asks for
        Class wrapperClass = NSClassFromString(@"TFNDataViewItem");
        class_addMethod(wrapperClass, @selector(item), imp_implementationWithBlock(^id(id self_) {
            return objc_getAssociatedObject(self_, "item");
        }), "@@:");
        id wrapped = [[wrapperClass alloc] init];
        objc_setAssociatedObject(wrapped, "item", promoted, OBJC_ASSOCIATION_RETAIN);
        Reset(); SetPrefs(YES, NO, NO, NO, NO);
        out = SCISecFiltered(@[@[wrapped, ordinary]], 0);
        CHECK([out[0] count] == 1 && out[0][0] == ordinary);

        // Ads, either spelling; offers and topics only when asked for.
        Reset(); SetPrefs(YES, NO, YES, NO, YES);
        out = SCISecFiltered(@[@[ad, offer, topic, ordinary]], 0);
        CHECK([out[0] count] == 1 && out[0][0] == ordinary);
        CHECK(sciSecRemoved[SCISecAds] == 1 && sciSecRemoved[SCISecPremium] == 1 && sciSecRemoved[SCISecTopics] == 1);

        Reset(); SetPrefs(YES, NO, NO, NO, NO);
        out = SCISecFiltered(@[@[ad, offer, ordinary]], 0);
        CHECK([out[0] count] == 2 && [out[0] containsObject:offer]);

        // A non-array "section" and a nil item are passed through rather than crashing.
        Reset(); SetPrefs(YES, YES, YES, YES, YES);
        out = SCISecFiltered(@[@"not an array", @[ordinary]], 0);
        CHECK([out count] == 2);
        CHECK(SCISecFiltered((NSArray *)@"x", 0) != nil);

        printf(fails ? "\n%d FAILED\n" : "\nall passed\n", fails);
        return fails ? 1 : 0;
    }
}
EOM

clang -fobjc-arc -Wall -Wno-objc-root-class -Wno-unused-function -Wno-unused-variable -Wno-unused-const-variable \
    -I"$OUT" -Istubs -framework Foundation "$OUT/Test.m" -o "$OUT/test"
"$OUT/test"
