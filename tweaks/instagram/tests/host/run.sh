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
