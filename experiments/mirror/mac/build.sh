#!/bin/bash
# Builds the viewer into ~/Desktop/Albrhi-Mirror, and, for testing without a phone, the daemon's HOST build into /tmp.
# The host build sends a moving test picture, never the screen of anything. It is kept off the Desktop on purpose:
# it was once started by mistake and the viewer showed its test picture as though it were the phone.
set -e
cd "$(dirname "$0")"
OUT="${OUT:-$HOME/Desktop/Albrhi-Mirror}"
TEST_OUT="${TEST_OUT:-/tmp/albrhi-mirror-test}"
mkdir -p "$OUT" "$TEST_OUT"
rm -f "$OUT/mirrord-host"
clang -fobjc-arc -Wall -Wno-deprecated-declarations Viewer.m -framework Cocoa -o "$OUT/viewer"
clang -fobjc-arc -Wall -Wno-deprecated-declarations ../device/main.m -framework Foundation -framework CoreGraphics -framework ImageIO -o "$TEST_OUT/mirrord-host"
echo "built: $OUT/viewer   (test only: $TEST_OUT/mirrord-host)"
