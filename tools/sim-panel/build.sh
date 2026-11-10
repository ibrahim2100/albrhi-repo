#!/usr/bin/env bash
#
# Albrhi's Settings panel, looked at from this machine: the REAL sources of tweaks/panel built as a Preferences bundle for the iOS Simulator
# and shown by a throwaway app (main.m).
#
#   bash tools/sim-panel/build.sh                  build, install, launch on the booted simulator
#   SUITE_VERSION=1.111.0 bash tools/sim-panel/build.sh
#   xcrun simctl launch <sim> com.albrhi.panelharness -bundle <printed path> -AppleLanguages '(ar)'
#
# The bundle is laid out like a jailbreak (<STAGE>/Library/PreferenceBundles/AlbrhiPanel.bundle, <STAGE>/Library/MobileSubstrate/
# DynamicLibraries with every tweak's real filter plist beside an empty dylib of the same name, <STAGE>/Library/dpkg/status naming the suite
# version), because the panel finds its tweaks and its version by walking up from its own bundle. The private Preferences headers come from
# $THEOS/include; the framework itself is the simulator runtime's, loaded by the app before the bundle.
set -euo pipefail
H="$(cd "$(dirname "$0")" && pwd)"; R="$(cd "$H/../.." && pwd)"
THEOS="${THEOS:-$HOME/theos}"
SIM="${SIM:-$(xcrun simctl list devices booted | grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}' | head -1)}"
STAGE="${PANEL_STAGE:-${TMPDIR:-/tmp}/albrhi-sim-panel-jb}"; APP="${TMPDIR:-/tmp}/albrhi-sim-panel/PanelHarness.app"
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
VERSION="${SUITE_VERSION:-$(awk '/^Version:/{print $2; exit}' "$R/suite/control")}"

rm -rf "$STAGE" "$APP"; B="$STAGE/Library/PreferenceBundles/AlbrhiPanel.bundle"; D="$STAGE/Library/MobileSubstrate/DynamicLibraries"
mkdir -p "$B" "$D" "$STAGE/Library/dpkg" "$APP"

P="$R/tweaks/panel"
clang -bundle -fobjc-arc -target arm64-apple-ios15.0-simulator -isysroot "$SDK" -I"$R" -I"$THEOS/vendor/include" -I"$THEOS/include" -I"$P/src" \
  -Wno-deprecated-declarations -Wno-nullability-completeness -Wno-unused-function -Wno-unsupported-availability-guard -Wno-objc-method-access \
  $(find "$P/src" -type f -name '*.m') "$R/shared/src/Prefs/SCIPanelHeader.m" "$R/shared/src/Prefs/SCIPanelAppCell.m" "$R/shared/src/Prefs/SCIPanelButtonAction.m" \
  "$R/shared/src/SCIKVC.m" "$R/shared/src/SCIPanelGate.m" "$R/shared/src/SCISafeLaunch.m" "$R/shared/src/SCISafeLaunchRule.m" "$R/shared/src/SCICard.m" \
  -framework UIKit -framework Foundation -framework CoreGraphics -framework Security -Wl,-undefined,dynamic_lookup \
  -o "$B/AlbrhiPanel" 2>&1 | grep -E "error" | head -20 || true
test -f "$B/AlbrhiPanel"
cp "$P/Resources/"* "$B/"
for f in "$R"/tweaks/*/Albrhi*.plist; do
  stem=$(basename "$f" .plist); cp "$f" "$D/$stem.plist"; head -c 400000 /dev/zero > "$D/$stem.dylib"
done
printf 'Package: com.albrhi\nVersion: %s\nStatus: install ok installed\n\n' "$VERSION" > "$STAGE/Library/dpkg/status"

clang -fobjc-arc -target arm64-apple-ios15.0-simulator -isysroot "$SDK" -framework UIKit -framework Foundation "$H/main.m" -o "$APP/PanelHarness"
cp "$H/Info.plist" "$APP/Info.plist"; codesign -s - --force "$APP" >/dev/null 2>&1
xcrun simctl terminate "$SIM" com.albrhi.panelharness >/dev/null 2>&1 || true
xcrun simctl install "$SIM" "$APP"
xcrun simctl launch "$SIM" com.albrhi.panelharness -bundle "$B" "$@"
echo "bundle: $B"
