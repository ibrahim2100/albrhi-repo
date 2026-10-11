#!/bin/bash
#
# The lyrics module, compiled for the Mac and actually run.
#
# **Why this exists.** CLAUDE.md says compilation is the second of three gates and the third is a
# device -- true of every hook, and not true of everything. An LRC parser, a title normaliser and a
# romaniser are pure functions of their input: they can be proved here, in seconds, with no phone in
# the room. Three of this project's most expensive bugs lived in exactly that layer.
#
# The arrangement is YTMEnhanced's (GPLv3): build the pure sources against the macOS SDK's
# iOSSupport frameworks as a Catalyst binary. What is ours is the source list -- only the modules
# this package actually carries -- and the absence of a resource bundle, which upstream's own
# YTMULocalized() already handles by falling back to the inline English.
#
set -euo pipefail
cd "$(dirname "$0")/../.."

XCODE="${XCODE:-/Applications/Xcode.app}"
if [[ ! -d "$XCODE/Contents/Developer" ]]; then
  echo "tests/host/run.sh: needs Xcode.app at $XCODE (set XCODE=/path/to/Xcode.app)" >&2
  exit 2
fi

export DEVELOPER_DIR="$XCODE/Contents/Developer"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
IOS_FW="$SDK/System/iOSSupport/System/Library/Frameworks"
THEOS="${THEOS:-$HOME/theos}"
OUT=".theos/host-tests"
mkdir -p "$OUT"

SOURCES=(
  src/Lyrics/*.m
  src/Lyrics/Providers/*.m
  src/Translation/*.m
  src/Translation/Providers/*.m
  src/Utils/*.m
  ../../shared/src/SCIKVC.m
  tests/host/*.m
)

xcrun clang \
  -fobjc-arc -Wall \
  -Wno-deprecated-declarations -Wno-unguarded-availability-new \
  -target arm64-apple-ios16.0-macabi -isysroot "$SDK" \
  -iframework "$IOS_FW" -F "$IOS_FW" \
  -I "$THEOS/include" -I "$THEOS/vendor/include" -I src -I tests/host -I ../.. \
  -D THEOS_PACKAGE_INSTALL_PREFIX='""' -DDEBUG -DYTMU_HOST_TESTS=1 \
  -framework UIKit -framework Foundation -framework QuartzCore \
  -framework MediaPlayer -framework NaturalLanguage -framework CoreGraphics \
  "${SOURCES[@]}" -o "$OUT/albrhi-ytm-host-tests"

APP="$OUT/AlbrhiYTMHostTests.app"
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS"
cp "$OUT/albrhi-ytm-host-tests" "$APP/Contents/MacOS/AlbrhiYTMHostTests"
# The real resource bundle, found the way the tweak's own code finds it -- which is what makes the
# localization test an assertion about this package rather than about upstream's.
mkdir -p "$APP/Contents/Resources"
cp -R "tweaks/ytmusic/layout/Library/Application Support/YTMusicUltimate.bundle" "$APP/Contents/Resources/" 2>/dev/null \
  || cp -R "layout/Library/Application Support/YTMusicUltimate.bundle" "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.albrhi.ytmusic.host-tests</string>
  <key>CFBundleName</key><string>AlbrhiYTMHostTests</string>
  <key>CFBundleExecutable</key><string>AlbrhiYTMHostTests</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>UIApplicationSceneManifest</key><dict>
    <key>UIApplicationSupportsMultipleScenes</key><false/>
    <key>UISceneConfigurations</key><dict>
      <key>UIWindowSceneSessionRoleApplication</key><array><dict>
        <key>UISceneConfigurationName</key><string>Default</string>
        <key>UISceneDelegateClassName</key><string>YTMUTestSceneDelegate</string>
      </dict></array>
    </dict>
  </dict>
</dict></plist>
PLIST

# Every on-disk cache the module writes is rooted here when it is set, so a test run touches a
# scratch directory rather than the real caches -- and so the paths test has something to assert
# against at all. Trimming this line out of the first draft is what made two tests fail.
CACHES="$OUT/caches"
rm -rf "$CACHES"; mkdir -p "$CACHES"

YTMU_CACHES_ROOT="$CACHES" "$APP/Contents/MacOS/AlbrhiYTMHostTests" "$@"
