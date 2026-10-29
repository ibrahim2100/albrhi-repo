#!/usr/bin/env bash
#
# Put a decrypted IPA, with one of this repository's standalone dylibs injected, into the iOS Simulator and launch it.
#
#   bash tools/sim-install.sh <decrypted.ipa> [<dylib>] [<simulator name or UDID>]
#   bash tools/sim-install.sh ~/Downloads/com.zhiliaoapp.musically_47.1.0_und3fined.ipa ~/Desktop/Albrhi-Dylibs/TikTok_AlbrhiTT_0.26.4.dylib
#   SIM_KEEP_DATA=1 bash tools/sim-install.sh ...    # install over the existing copy: its terms, onboarding and preferences stay
#
# **Why this works at all.** An Apple-silicon simulator runs arm64 code natively. What stops a device build loading in it is only the
# *platform* stamped in each Mach-O (`LC_BUILD_VERSION`: iOS vs iOS Simulator), so every Mach-O in the bundle is re-stamped with `vtool` and
# the bundle is signed ad hoc. Nothing is recompiled. Measured on TikTok 47.1.0 (the first app this was done for, 2026-10-29): it loads, runs
# its start-up, draws the For You feed with this tweak's download button on the rail, and the tweak's constructor logs.
#
# **What a device build needs fixed on the way, each found by running it:**
#   1. App extensions are removed (they are not run here and each would need the same treatment).
#   2. A Mach-O with the same `LC_RPATH` twice is refused by the simulator's dyld (a device's dyld tolerated it): TikTok's
#      `ffmpeg_dashdec` had `@executable_path/Frameworks` and `@loader_path/Frameworks` twice each. The duplicates are deleted.
#   3. **The app's Metal libraries are built for the device**, so the simulator refuses them ("library was not compiled for the simulator"), and
#      TikTok's completion handler then builds a C++ string from a nil NSString and dies in `strlen(NULL)`. `tools/sim/SimShim.m` -- a
#      simulator-only helper, never shipped -- swallows those failed callbacks. It also refuses a texture made from a non-private buffer, which
#      the simulator's driver asserts on and a device accepts. Everything it does is logged as `[SimShim]`.
#
# **What this is not.** The app is the real one, but the simulator has no hardware video decoders, no camera, no App Attest and a different GPU
# driver: a failure here is a lead, never proof, and a success here is not "works on the phone". The tweak's hooks, the settings pages, the
# banner and the menus are exactly what it is good for. Needs the iOS Simulator runtime and Xcode's command line tools; ~1.5 GB of scratch space.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IPA="${1:?usage: sim-install.sh <decrypted.ipa> [<dylib>] [<simulator>]}"
DYLIB="${2:-}"
SIM="${3:-}"
WORK="${SIM_WORK:-${TMPDIR:-/tmp}/albrhi-sim}"

[ -f "$IPA" ] || { echo "no such IPA: $IPA" >&2; exit 1; }
command -v xcrun >/dev/null || { echo "Xcode command line tools are required" >&2; exit 1; }

# A simulator to use: the one named, else a booted one, else the first iPhone that is available.
if [ -z "$SIM" ]; then
    SIM="$(xcrun simctl list devices booted | grep -Eo '[0-9A-F-]{36}' | head -1 || true)"
fi
if [ -z "$SIM" ]; then
    SIM="$(xcrun simctl list devices available | grep -E 'iPhone' | grep -Eo '[0-9A-F-]{36}' | tail -1)"
fi
[ -n "$SIM" ] || { echo "no simulator found" >&2; exit 1; }
xcrun simctl boot "$SIM" 2>/dev/null || true

echo "==> unpacking into $WORK (an empty directory of its own; the IPA is untrusted data)"
rm -rf "$WORK"; mkdir -p "$WORK"
( cd "$WORK" && unzip -q "$IPA" )
APP="$(echo "$WORK"/Payload/*.app)"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")"
EXEC="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Info.plist")"
rm -rf "$APP/PlugIns" "$APP/Watch" "$APP/_CodeSignature" "$APP/SC_Info"
echo "    $BUNDLE_ID ($EXEC)"

restamp() {   # one Mach-O: device platform -> simulator platform
    local f="$1"
    case "$(file -b "$f")" in *"Mach-O 64-bit"*arm64*) ;; *) return 0 ;; esac
    xcrun vtool -show-build "$f" 2>/dev/null | grep -q "platform IOSSIMULATOR" && return 0
    local minos; minos="$(xcrun vtool -show-build "$f" 2>/dev/null | awk '/minos/{print $2; exit}')"
    xcrun vtool -set-build-version 7 "${minos:-14.0}" 26.0 -replace -output "$f" "$f" >/dev/null 2>&1 || echo "    could not re-stamp $f"
}
export -f restamp

echo "==> re-stamping every Mach-O for the simulator"
find "$APP" -type f ! -name '*.png' ! -name '*.plist' ! -name '*.json' ! -name '*.otf' ! -name '*.ttf' ! -name '*.car' -print0 \
    | xargs -0 -n1 -P4 bash -c 'restamp "$0"'

echo "==> removing duplicate LC_RPATH entries"
python3 -I - "$APP" <<'PY'
import os, subprocess, sys, collections
fixed = 0
for root, _, files in os.walk(sys.argv[1]):
    for name in files:
        path = os.path.join(root, name)
        if "Mach-O" not in subprocess.run(["file", "-b", path], capture_output=True, text=True, errors="replace").stdout: continue
        lines = subprocess.run(["xcrun", "otool", "-l", path], capture_output=True, text=True, errors="replace").stdout.splitlines()
        rpaths = [lines[i + 2].split("path ")[1].split(" (offset")[0] for i, l in enumerate(lines) if l.strip() == "cmd LC_RPATH"]
        for rpath, n in collections.Counter(rpaths).items():
            for _ in range(n - 1):
                subprocess.run(["xcrun", "install_name_tool", "-delete_rpath", rpath, path], capture_output=True)
                fixed += 1
print("    removed", fixed)
PY

inject() {   # a simulator-platform dylib into the app's frameworks, and a load command for it into the executable
    local dylib="$1" name; name="$(basename "$2")"
    mkdir -p "$APP/Frameworks"
    cp "$dylib" "$APP/Frameworks/$name"
    restamp "$APP/Frameworks/$name"
    python3 -I "$ROOT/tools/inject-dylib.py" "$APP/$EXEC" "@executable_path/Frameworks/$name" | tail -1 | sed 's/^/    /'
}

if [ -n "$DYLIB" ]; then
    echo "==> injecting the tweak: $DYLIB"
    inject "$DYLIB" AlbrhiSim.dylib
fi

echo "==> building the simulator helper (tools/sim/SimShim.m)"
xcrun clang -fobjc-arc -dynamiclib -target arm64-apple-ios15.0-simulator -isysroot "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
    "$ROOT/tools/sim/SimShim.m" -framework Foundation -framework Metal -install_name @rpath/SimShim.dylib -o "$WORK/SimShim.dylib"
inject "$WORK/SimShim.dylib" SimShim.dylib

echo "==> signing ad hoc, inside out"
find "$APP/Frameworks" -type f \( -name '*.dylib' -o -perm -u+x \) -print0 \
    | xargs -0 -n1 -P4 bash -c 'file -b "$0" | grep -q Mach-O && codesign -f -s - "$0" >/dev/null 2>&1 || true'
for framework in "$APP"/Frameworks/*.framework; do codesign -f -s - "$framework" >/dev/null 2>&1 || true; done
codesign -f -s - "$APP" >/dev/null 2>&1

echo "==> installing and launching on $SIM"
xcrun simctl terminate "$SIM" "$BUNDLE_ID" >/dev/null 2>&1 || true
# A fresh install erases the app's data: its terms, its onboarding, every preference the tweak wrote. SIM_KEEP_DATA=1 installs over
# the existing copy instead, which keeps the data container -- the way to try a rebuilt dylib without clicking through them again.
[ -n "${SIM_KEEP_DATA:-}" ] || xcrun simctl uninstall "$SIM" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$SIM" "$APP"
xcrun simctl launch "$SIM" "$BUNDLE_ID"
cat <<MSG

Running. Useful next:
  xcrun simctl launch --console-pty $SIM $BUNDLE_ID          # the app's own log, [AlbrhiTT] and [SimShim] lines included
  xcrun simctl io $SIM screenshot shot.png                   # a picture
  ls -t ~/Library/Logs/DiagnosticReports | head              # a crash, if there was one
MSG
