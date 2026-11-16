#!/usr/bin/env bash
#
# Builds an APT repository that Sileo, Zebra and Cydia can add as a source.
#
# Takes the .deb files in a directory and produces the index files APT needs:
# Packages (plus compressed variants) and Release. Output is a self-contained
# folder ready to be served by GitHub Pages.
#
# Packages come from two places: the debs just built, and anything dropped into
# extra-debs/ in the source tree. Adding another tweak to the source is therefore
# a matter of copying its .deb into that folder and pushing.
#
# Usage: tools/make-repo.sh <deb-dirs> <output-dir> <base-url> [previous-deb-dirs]
#
# <deb-dirs> and <previous-deb-dirs> may each name several directories, separated
# by spaces -- one per tweak this repository builds. A directory that does not
# exist is skipped rather than fatal, so a run that built only some of the tweaks
# still publishes an index for the ones it did.

set -euo pipefail

MAKE_REPO_DIR="$(cd "$(dirname "$0")" && pwd)"   # absolute: the script changes directory before it needs this
DEB_DIRS="${1:?deb directory required}"
OUT_DIR="${2:?output directory required}"
BASE_URL="${3:?base url required}"
PREV_DIRS="${4:-}"

# Copies every .deb directly inside each named directory. Kept in one place
# because the built packages, the rollback copies and extra-debs all need it and
# differ only in whether an existing file may be overwritten.
copy_debs() {
    local mode="$1"; shift
    local total=0

    for dir in "$@"; do
        [ -d "$dir" ] || continue
        local n
        n=$(find "$dir" -maxdepth 1 -name '*.deb' -type f | wc -l | tr -d ' ')
        total=$((total + n))
        if [ "$n" -gt 0 ]; then
            find "$dir" -maxdepth 1 -name '*.deb' -type f -exec cp "$mode" {} "$OUT_DIR/debs/" \;
        fi
    done

    echo "$total"
}

# Rebuilt from scratch every run, so the published repo is an exact mirror of what
# is in the tree right now. Copying without clearing left deleted packages behind:
# the file stayed on the gh-pages branch and kept being re-indexed, so removing a
# tweak from extra-debs never removed it from Sileo.
rm -rf "$OUT_DIR/debs"
mkdir -p "$OUT_DIR/debs"

# Everything below is therefore a fresh copy, not a merge.
built=$(copy_debs -f $DEB_DIRS)
echo "Built packages found: ${built}"

# Earlier releases of Albrhi itself, so a bad build is not a dead end: the
# previous version stays installable from the source and Sileo offers it under
# the package's version list.
#
# These come from the published releases rather than from whatever the last run
# happened to leave on gh-pages. Keeping the old files in place would have done
# it too, but then a package deleted from extra-debs would linger forever --
# which is the exact bug the wipe above exists to prevent. Re-fetching a bounded
# number of releases keeps both properties.
if [ -n "$PREV_DIRS" ]; then
    # -n, so a current build of the same filename is never overwritten by an
    # older copy of it.
    kept=$(copy_debs -n $PREV_DIRS)
    echo "Previous releases kept for rollback: ${kept}"
fi

# Hand-added packages. Copied after the built ones so a file placed here can
# deliberately override a build of the same name.
EXTRA_DIR="$(dirname "$0")/../extra-debs"
# find, not ls: a glob that matches nothing makes ls exit non-zero, and under
# `set -o pipefail` that killed the whole script before it printed anything.
count=$(copy_debs -f "$EXTRA_DIR")
echo "Extra packages found: ${count}"

if ! ls "$OUT_DIR"/debs/*.deb >/dev/null 2>&1; then
    echo "::error::No .deb files to index"
    exit 1
fi

# --- Collision guard -------------------------------------------------------
#
# APT identifies a package by name + version + architecture. Two debs sharing
# all three are indistinguishable to a package manager: it will list one and
# may install the wrong jailbreak's build. The rootless and roothide packages
# must therefore differ in architecture.
echo "Package identities:"
IDENTITIES=""
for deb in "$OUT_DIR"/debs/*.deb; do
    name=$(dpkg-deb -f "$deb" Package)
    version=$(dpkg-deb -f "$deb" Version)
    arch=$(dpkg-deb -f "$deb" Architecture)

    # Label the jailbreak each package targets. Old sourceless tweaks are usually
    # rootful, which no modern jailbreak can install -- better to see that here
    # than to field "it will not install" reports later.
    case "$arch" in
        iphoneos-arm)     note="  [rootful - will NOT install on rootless or roothide]" ;;
        iphoneos-arm64)   note="  [rootless]" ;;
        iphoneos-arm64e)  note="  [roothide]" ;;
        *)                note="  [unknown architecture]" ;;
    esac

    echo "  $(basename "$deb")  ->  ${name} ${version} ${arch}${note}"
    IDENTITIES="${IDENTITIES}${name}_${version}_${arch}"$'\n'
done

DUPES=$(printf '%s' "$IDENTITIES" | sort | uniq -d)
if [ -n "$DUPES" ]; then
    echo "::error::Two packages share name+version+architecture: ${DUPES}"
    echo "::error::A single APT repo cannot serve both. Give the roothide build its own architecture."
    exit 1
fi

# --- Index -----------------------------------------------------------------

cd "$OUT_DIR"

dpkg-scanpackages -m debs /dev/null > Packages 2>/dev/null

# dpkg-scanpackages drops SileoDepiction (see add-sileo-depiction.py for why this is an opt-in list and not every package).
python3 "$MAKE_REPO_DIR/add-sileo-depiction.py" . "$BASE_URL" com.albrhi.whatsapp com.albrhi.whatsapp.roothide

gzip  -9fkn Packages
bzip2 -9fk  Packages
xz    -9fk  Packages 2>/dev/null || true

cat > Release <<EOF
Origin: Albrhi
Label: Albrhi
Suite: stable
Version: 1.0
Codename: ios
Architectures: iphoneos-arm64 iphoneos-arm64e
Components: main
Description: Tweaks by Ibrahim Ismail AL-Rahn.
Icon: CydiaIcon.png
EOF

# Already inside $OUT_DIR after the cd above, so list the current directory --
# listing "$OUT_DIR" again looks for pages/pages and fails under set -e.
echo "Repo written to $OUT_DIR (base: $BASE_URL)"
ls -la
