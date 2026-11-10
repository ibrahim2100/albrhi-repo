#!/usr/bin/env bash
#
# The pure parts of shared/: readable file names (SCIFileName). Compiled against the macOS SDK.
#
#   bash shared/tests/host/run.sh
#
set -euo pipefail
cd "$(dirname "$0")"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT
xcrun clang -fobjc-arc -framework Foundation -I../../.. -o "$OUT/Test_FileName" Test_FileName.m ../../src/SCIFileName.m
"$OUT/Test_FileName"
xcrun clang -fobjc-arc -framework Foundation -I../../.. -o "$OUT/Test_SafeLaunch" Test_SafeLaunch.m ../../src/SCISafeLaunchRule.m
"$OUT/Test_SafeLaunch"
xcrun clang -fobjc-arc -framework Foundation -I../../.. -o "$OUT/Test_WatchBudget" Test_WatchBudget.m ../../src/SCIWatchBudgetRule.m
"$OUT/Test_WatchBudget"
