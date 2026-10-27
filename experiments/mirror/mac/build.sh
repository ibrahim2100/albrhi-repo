#!/bin/bash
# Builds the viewer and, for testing without a phone, the daemon's host build (moving test picture instead of the screen).
set -e
cd "$(dirname "$0")"
OUT="${OUT:-$HOME/Desktop/Albrhi-Mirror}"
mkdir -p "$OUT"
clang -fobjc-arc -Wall -Wno-deprecated-declarations Viewer.m -framework Cocoa -o "$OUT/viewer"
clang -fobjc-arc -Wall -Wno-deprecated-declarations ../device/main.m -framework Foundation -framework CoreGraphics -framework ImageIO -o "$OUT/mirrord-host"
echo "built: $OUT/viewer  $OUT/mirrord-host"
