#!/usr/bin/env bash
#
# The panel's update check, run on this Mac: which version in the published `Packages` file is the
# newest. The source lists several versions of a package on purpose (so a bad build can be rolled
# back), which is exactly the shape that reports an update as a downgrade if the first match is
# taken. Copied out of SCIPanelUpdate.m by marker -- not retyped -- so what passes is what ships.
#
#   bash tweaks/panel/tests/host/run.sh
#
set -euo pipefail
cd "$(dirname "$0")"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

python3 - "$OUT" <<'PY'
import sys
src = open('../../src/SCIPanelUpdate.m').read()
a = src.index('// host-test:begin newest')
b = src.index('// host-test:end newest')
assert a < b
open(sys.argv[1] + '/region.inc', 'w').write(src[a:b])
PY

cat > "$OUT/Test.m" <<'EOM'
#import <Foundation/Foundation.h>

// What the region asks of the rest of the panel.
static NSSet<NSString *> *SCISuitePackages(void) { return [NSSet setWithObjects:@"com.albrhi", @"com.albrhi.roothide", nil]; }

#include "region.inc"

static int fails = 0;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); fails++; } else printf("ok   %s\n", #c); } while (0)

static NSString *Stanza(NSString *name, NSString *version) {
    return [NSString stringWithFormat:@"Package: %@\nVersion: %@\nArchitecture: iphoneos-arm64\n", name, version];
}

int main(void) {
    @autoreleasepool {
        NSString *two = [@[Stanza(@"com.albrhi", @"1.57.0"), Stanza(@"com.albrhi", @"1.58.10")] componentsJoinedByString:@"\n"];
        CHECK([SCINewestVersionIn(two) isEqualToString:@"1.58.10"]);

        // The newest listed first or last gives the same answer.
        NSString *reversed = [@[Stanza(@"com.albrhi", @"1.58.10"), Stanza(@"com.albrhi", @"1.57.0")] componentsJoinedByString:@"\n"];
        CHECK([SCINewestVersionIn(reversed) isEqualToString:@"1.58.10"]);

        // Numeric, not lexical: 1.100.0 is newer than 1.99.0, and 1.9.0 is older than 1.10.0.
        NSString *numeric = [@[Stanza(@"com.albrhi", @"1.99.0"), Stanza(@"com.albrhi", @"1.100.0"), Stanza(@"com.albrhi", @"1.9.0")] componentsJoinedByString:@"\n"];
        CHECK([SCINewestVersionIn(numeric) isEqualToString:@"1.100.0"]);

        // A package that is not in the suite does not count, however new.
        NSString *other = [@[Stanza(@"com.albrhi", @"1.93.0"), Stanza(@"com.albrhi.nextup", @"9.0.0")] componentsJoinedByString:@"\n"];
        CHECK([SCINewestVersionIn(other) isEqualToString:@"1.93.0"]);

        // Both flavours of the suite are read.
        NSString *both = [@[Stanza(@"com.albrhi", @"1.93.2"), Stanza(@"com.albrhi.roothide", @"1.93.3")] componentsJoinedByString:@"\n"];
        CHECK([SCINewestVersionIn(both) isEqualToString:@"1.93.3"]);

        // Nothing usable is nil, never an empty string that reads as "a version".
        CHECK(SCINewestVersionIn(@"") == nil);
        CHECK(SCINewestVersionIn(@"Package: com.albrhi\nArchitecture: iphoneos-arm64\n") == nil);
        CHECK(SCINewestVersionIn(Stanza(@"com.example.other", @"5.0.0")) == nil);

        printf(fails ? "\n%d FAILED\n" : "\nall passed\n", fails);
        return fails ? 1 : 0;
    }
}
EOM

clang -fobjc-arc -Wall -Wno-unused-function -framework Foundation "$OUT/Test.m" -o "$OUT/test"
"$OUT/test"
