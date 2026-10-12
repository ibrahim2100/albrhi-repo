#!/usr/bin/env bash
#
# Build the standalone dylibs — the ones injected into an IPA — and drop them on the Desktop.
#
#   bash tools/build-dylibs.sh                    # all four
#   bash tools/build-dylibs.sh youtube            # one
#
# **Standalone means no CydiaSubstrate, and that is proved here rather than claimed.** A dylib
# that still links Substrate loads on a jailbroken phone and does nothing at all on a sideloaded
# one, where the failure is silent: the app simply looks untweaked. The same three checks CI runs
# are run here, because the whole point of building locally is to find that out on this machine.
#
#   1. no Substrate in the *dependencies* -- `otool -L` prints the file's own name and then its
#      install name before them, and every tweak here installs under /Library/MobileSubstrate,
#      so two lines are skipped or the file matches itself and a clean build reads as linked;
#   2. no undefined MS* symbols -- a library can be dropped from the load commands while a symbol
#      it needs remains, which fails at load time instead of here;
#   3. no licence code is compiled in -- the licence layer was removed (see CLAUDE.md §6), and a
#      symbol of it surviving in a build would mean a stale object or a reintroduced gate. This
#      check used to demand the opposite (`SCILicenseAllowsProduct` present, because a
#      self-contained build once answered the gate with an unconditional yes); it is inverted
#      rather than deleted so the removal stays proved.
#
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

OUT="$HOME/Desktop/Albrhi-Dylibs"
TWEAKS="${*:-instagram youtube twitter tiktok}"

export THEOS="${THEOS:-$HOME/theos}"
export PATH="/opt/homebrew/opt/make/libexec/gnubin:/opt/homebrew/bin:$PATH"

# The app each dylib belongs in, in the file's own name.
#
# `AlbrhiTT_0.20.2.dylib` is obvious to whoever built it and to nobody else -- and the one mistake
# this naming has to prevent is injecting the wrong dylib into an app, which does not fail loudly:
# the hooks simply attach to nothing and the app looks untweaked.
app_name() {
    case "$1" in
        instagram) echo "Instagram" ;;
        youtube)   echo "YouTube" ;;
        twitter)   echo "X-Twitter" ;;
        tiktok)    echo "TikTok" ;;
        *)         echo "$1" ;;
    esac
}

mkdir -p "$OUT"

for TWEAK in $TWEAKS; do
    [ -d "tweaks/$TWEAK" ] || { echo "no such tweak: $TWEAK" >&2; exit 1; }

    echo ""
    echo "=== $TWEAK"
    ( cd "tweaks/$TWEAK" && make clean >/dev/null 2>&1 || true )
    ( cd "tweaks/$TWEAK" && make SELFCONTAINED=1 FINALPACKAGE=1 >/tmp/albrhi-dylib-$TWEAK.log 2>&1 ) || {
        echo "  build failed — see /tmp/albrhi-dylib-$TWEAK.log" >&2
        grep -a 'error:' "/tmp/albrhi-dylib-$TWEAK.log" | head -3 >&2 || true
        exit 1
    }

    DYLIB=$(find "tweaks/$TWEAK/.theos/obj" -name '*.dylib' -type f | head -n1)
    [ -n "$DYLIB" ] || { echo "  no dylib produced" >&2; exit 1; }

    if otool -L "$DYLIB" | tail -n +3 | grep -qi 'substrate'; then
        echo "  FAILED: still links CydiaSubstrate" >&2
        otool -L "$DYLIB" | tail -n +3 | grep -i substrate >&2
        exit 1
    fi

    if nm -u "$DYLIB" | grep -qE '^_MS'; then
        echo "  FAILED: still expects Substrate symbols at load time" >&2
        nm -u "$DYLIB" | grep -E '^_MS' >&2
        exit 1
    fi

    if nm "$DYLIB" | grep -q 'SCILicense'; then
        echo "  FAILED: licence code is still compiled in" >&2
        nm "$DYLIB" | grep 'SCILicense' | head -5 >&2
        exit 1
    fi

    VERSION=$(grep -m1 '^Version:' "tweaks/$TWEAK/control" | awk '{print $2}')
    NAME=$(basename "$DYLIB" .dylib)
    FILE="$(app_name "$TWEAK")_${NAME}_${VERSION}.dylib"
    cp "$DYLIB" "$OUT/$FILE"

    SIZE=$(du -h "$OUT/$FILE" | awk '{print $1}')
    echo "  standalone, no MS symbols, no licence code  ·  $FILE  (${SIZE})"

    # The objects must not be inherited by a package build, or a .deb would ship the injected
    # flavour of the dylib -- which loads on a jailbreak and hooks nothing through Substrate.
    ( cd "tweaks/$TWEAK" && make clean >/dev/null 2>&1 || true; rm -rf .theos )
done

echo ""
echo "in $OUT:"
ls -lh "$OUT"
