#!/usr/bin/env bash
#
# The deleted-messages log, run on this Mac against the macOS SDK.
#
# SCIUnsentLog is pure logic -- shape-tolerant capture of a message, the lookup when its removal
# arrives, de-duplication, bounds and persistence -- so it does not need an iPhone to be wrong in
# public. UIKit and the tweak's own headers are stubbed (stubs/), and the message shapes are mocks
# of the two the update stream may carry. **What this cannot say** is which shape Instagram
# really sends; that is the first line of the report (`insert element`). Run it after any change
# to SCIUnsentLog.m:
#
#   bash tweaks/instagram/tests/host/run.sh
#
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(cd ../../../.. && pwd)"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

# The log reads the stubbed headers by the same relative paths the real source uses, so the real
# file is compiled unmodified: copied into a tree that has the stubs where it expects Utils.h.
mkdir -p "$OUT/Features/StoriesAndMessages" "$OUT/Localization" "$OUT/Settings" "$OUT/UIKit"
cp ../../src/Features/StoriesAndMessages/SCIUnsentLog.[hm] "$OUT/Features/StoriesAndMessages/"
cp stubs/Utils.h "$OUT/"
cp stubs/UIKit/UIKit.h "$OUT/UIKit/"
cp stubs/Localization/SCILocalize.h "$OUT/Localization/"
cp stubs/Settings/SCIDiagnosticsViewController.h "$OUT/Settings/"

clang -fobjc-arc -Wall -Wno-objc-root-class -I"$OUT" -I"$ROOT" -framework Foundation \
    "$OUT/Features/StoriesAndMessages/SCIUnsentLog.m" "$ROOT/shared/src/SCIKVC.m" Test_UnsentLog.m \
    -o "$OUT/test"

# The test writes the real file under Application Support and removes it again; on a clean machine
# that is a no-op, on this one it would clobber nothing because it is the app's folder, not ours.
"$OUT/test" | grep -v '^COUNT\|^PATH'

# The link cleaner is plain Foundation: compiled on its own, from the real source.
mkdir -p "$OUT/Features/General"
cp ../../src/Features/General/SCILinkTracking.[hm] "$OUT/Features/General/"
clang -fobjc-arc -Wall -I"$OUT" -framework Foundation \
    "$OUT/Features/General/SCILinkTracking.m" Test_LinkTracking.m -o "$OUT/test-links"

cp ../../src/Features/General/SCICacheRules.[hm] "$OUT/Features/General/"
clang -fobjc-arc -Wall -I"$OUT" -framework Foundation \
    "$OUT/Features/General/SCICacheRules.m" Test_CacheRules.m -o "$OUT/test-cache"
cp ../../src/Features/General/SCICopyText.[hm] "$OUT/Features/General/"
clang -fobjc-arc -Wall -I"$OUT" -framework Foundation \
    "$OUT/Features/General/SCICopyText.m" Test_CopyText.m -o "$OUT/test-copy"
"$OUT/test-cache"
"$OUT/test-links"
"$OUT/test-copy"

# The keychain rule for a re-signed Instagram: compiled from the real source, run from a folder named *.app (only images inside an app are patched).
mkdir -p "$OUT/Keychain.app"
clang -DSCI_KEYCHAIN_TEST -fobjc-arc -Wall -Wno-unused-function -I"$ROOT" -framework Foundation -framework Security \
    Test_Keychain.m -o "$OUT/Keychain.app/test-keychain"
"$OUT/Keychain.app/test-keychain"

# The receipt address rule (a re-signed copy must not look like a TestFlight build).
clang -fobjc-arc -Wall -I"$ROOT" -framework Foundation "../../src/Features/Sideload/SCIReceipt.m" Test_Receipt.m -o "$OUT/test-receipt"
"$OUT/test-receipt"
