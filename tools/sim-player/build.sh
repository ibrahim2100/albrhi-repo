#!/usr/bin/env bash
# The Download Centre's player (the REAL sources) in a throwaway simulator app, so a change to it can be
# driven and looked at from this machine. Media: $SIM_PLAYER_MEDIA (default ~/Desktop/Albrhi-PlayerMedia)
# must hold clipA.mp4, clipB.mp4 and songC.m4a (any short H.264 clip with two audio tracks and a song).
#
#   bash tools/sim-player/build.sh                 build and install
#   xcrun simctl launch <sim> com.albrhi.playerharness [-resigntest YES] [-hosttest YES] [-nptest YES] [-sheettest YES]
#
# Flags: resigntest = WillResignActive/DidBecomeActive without a background; hosttest = fake YouTube classes with the
# 21.41.5 signatures drive the arbiter; nptest = asks MediaRemote (private, harness only) what the SYSTEM thinks is
# now playing; sheettest = the download choice sheet with dubbed-audio and caption choices.
set -euo pipefail
H="$(cd "$(dirname "$0")" && pwd)"; R="$(cd "$H/../.." && pwd)"; SRC=$R/tweaks/youtube/src; C=$SRC/Features/Download/Center
MEDIA="${SIM_PLAYER_MEDIA:-$HOME/Desktop/Albrhi-PlayerMedia}"
SIM="${SIM:-$(xcrun simctl list devices booted | grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}' | head -1)}"
# FULL=1: the real library, direct route, parts, recipe and muxer instead of stubs, so a download can be run end to end
# against YouTube itself (no AV1 conversion: that links a device-built dav1d).
FULLFLAGS=""; FULLSRC=""
if [ "${FULL:-0}" = "1" ]; then
  FULLFLAGS="-DSIM_FULL=1"
  D=$SRC/Features/Download
  FULLSRC="$C/SCIYTLibrary.m $C/SCIYTNotice.m $D/SCIYTDirect.m $D/SCIYTFragments.m $D/SCIYTRecipe.m $D/SCIYTPlaylist.m $C/SCIYTPlaylistSheet.m $D/SCIYTHLS.m $D/SCIYTTransport.m $H/stub/AV1Stub.m"
fi
OUT="${TMPDIR:-/tmp}/albrhi-sim-player"; mkdir -p "$OUT/PlayerHarness.app"; SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
clang -fobjc-arc -target arm64-apple-ios15.0-simulator -isysroot "$SDK" -Wall -Wno-unused-function -Wno-objc-method-access -Wno-incomplete-implementation \
  -I"$SRC" -I"$R" -I"$H/stub" -F"$SDK/System/Library/Frameworks" \
  -framework UIKit -framework Foundation -framework AVFoundation -framework AVKit -framework MediaPlayer -framework CoreMedia -framework QuartzCore -framework Photos -framework CoreGraphics -framework ImageIO -framework UserNotifications -framework VideoToolbox \
  $FULLFLAGS "$H/main.m" "$C/SCIYTPlayer.m" "$C/SCIYTJob.m" "$C/SCIYTPalette.m" "$C/SCIYTIcon.m" "$C/SCIYTThumbnails.m" "$C/SCIYTArbiter.m" "$C/SCIYTChoiceSheet.m" "$C/SCIYTQueueSheet.m" "$C/SCIYTCaptionSettings.m" "$SRC/Features/Download/SCIYTCaptionReader.m" "$SRC/Features/Download/SCIYTSubtitles.m" "$SRC/Features/SponsorBlock/SCIYTSponsorClient.m" "$SRC/Features/Download/SCIYTParts.m" $FULLSRC \
  "$SRC/Localization/SCILocalize.m" "$SRC/SCIYTLaunchGuard.m" \
  -o "$OUT/PlayerHarness.app/PlayerHarness" 2>&1 | grep -E "error|Undefined|referenced from|symbol" | head -30 || true
test -f "$OUT/PlayerHarness.app/PlayerHarness"
cp "$H/Info.plist" "$OUT/PlayerHarness.app/Info.plist"
cp "$MEDIA/clipA.mp4" "$MEDIA/clipB.mp4" "$MEDIA/songC.m4a" "$OUT/PlayerHarness.app/"
printf 'not a movie at all' > "$OUT/PlayerHarness.app/broken.mp4"
codesign -s - --force "$OUT/PlayerHarness.app" >/dev/null 2>&1
xcrun simctl terminate "$SIM" com.albrhi.playerharness >/dev/null 2>&1 || true
xcrun simctl install "$SIM" "$OUT/PlayerHarness.app"
echo "built, installed on $SIM"
