#!/usr/bin/env bash
#
# Builds the three "Open in app" Safari extensions (Instagram, YouTube, TikTok) into tools/safari-ext/out/<app>/AlbrhiLinks.appex.
#
#   bash tools/safari-ext/build.sh
#
# A Safari web extension is a bundle: a manifest, two scripts, icons, an Info.plist and a small executable (common/Handler.m). Nothing here is
# a Theos tweak; it is built with clang against the iPhoneOS SDK Theos already has (the one CI uses).
#
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SDK="${SDK:-$HOME/theos/sdks/iPhoneOS16.2.sdk}"
[[ -d "$SDK" ]] || { echo "no SDK at $SDK (set SDK=...)"; exit 1; }
OUT="$HERE/out"; rm -rf "$OUT"; mkdir -p "$OUT"

# app dir | display name (shown in Safari > Extensions) | icon in brand/icons/512
APPS=(
  "instagram|Albrhi — Open in Instagram|instagram"
  "youtube|Albrhi — Open in YouTube|youtube"
  "tiktok|Albrhi — Open in TikTok|tiktok"
)

# One executable for all three: it does nothing the app could differ in.
BIN="$OUT/AlbrhiLinks"
clang -arch arm64 -isysroot "$SDK" -miphoneos-version-min=15.0 -fobjc-arc -fapplication-extension -Os \
  -e _NSExtensionMain -framework Foundation -framework SafariServices "$HERE/common/Handler.m" -o "$BIN"
ldid -S "$BIN" 2>/dev/null || true

for entry in "${APPS[@]}"; do
  IFS='|' read -r app name icon <<<"$entry"
  APPEX="$OUT/$app/AlbrhiLinks.appex"
  mkdir -p "$APPEX/images"
  cp "$BIN" "$APPEX/AlbrhiLinks"
  cp "$HERE/common/runner.js" "$APPEX/runner.js"
  cp "$HERE/$app/map.js" "$APPEX/map.js"
  for size in 48 96 128; do
    sips -z $size $size "$ROOT/brand/icons/512/$icon.png" --out "$APPEX/images/icon-$size.png" >/dev/null
  done
  case "$app" in
    instagram) MATCHES='"*://instagram.com/*", "*://*.instagram.com/*"' ;;
    youtube)   MATCHES='"*://youtube.com/*", "*://*.youtube.com/*", "*://youtu.be/*"' ;;
    tiktok)    MATCHES='"*://tiktok.com/*", "*://*.tiktok.com/*"' ;;
  esac
  cat > "$APPEX/manifest.json" <<JSON
{
  "manifest_version": 2,
  "name": "$name",
  "version": "1.0",
  "description": "Opens shared $app links in the app, where the Albrhi tweak is.",
  "permissions": [ $MATCHES ],
  "content_scripts": [
    { "matches": [ $MATCHES ], "js": [ "map.js", "runner.js" ], "run_at": "document_idle", "all_frames": false }
  ],
  "icons": { "48": "images/icon-48.png", "96": "images/icon-96.png", "128": "images/icon-128.png" }
}
JSON
  # The bundle id and version of the host app are written when it is put into an IPA (add-to-ipa.py); these are the placeholders.
  cat > "$APPEX/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleDisplayName</key><string>$name</string>
  <key>CFBundleExecutable</key><string>AlbrhiLinks</string>
  <key>CFBundleIdentifier</key><string>com.albrhi.links.$app</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>AlbrhiLinks</string>
  <key>CFBundlePackageType</key><string>XPC!</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>MinimumOSVersion</key><string>15.0</string>
  <key>NSExtension</key>
  <dict>
    <key>NSExtensionPointIdentifier</key><string>com.apple.Safari.web-extension</string>
    <key>NSExtensionPrincipalClass</key><string>AlbrhiLinksHandler</string>
  </dict>
</dict>
</plist>
PLIST
  plutil -lint "$APPEX/Info.plist" >/dev/null
  python3 -c "import json,sys; json.load(open('$APPEX/manifest.json'))"
  echo "built $APPEX"
done
rm -f "$BIN"
