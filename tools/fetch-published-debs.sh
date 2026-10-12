#!/usr/bin/env bash
#
# Downloads the .deb assets of the newest published releases into one directory.
#
# Usage: tools/fetch-published-debs.sh <out-dir> <owner/repo> [keep-per-package]
#
# This exists so the APT index can be built from what is *published* rather than
# from whatever the current run happened to compile. That distinction is what lets
# more than one workflow in this repository rebuild the index safely.
#
# make-repo.sh wipes the published debs/ directory and rebuilds it, deliberately, so
# that a package deleted from the source disappears from Sileo instead of lingering
# forever. The moment a second tweak got its own workflow, that same wipe became a
# hazard: an index built from one tweak's build output would erase the other tweak
# from the source. Deriving the index from the releases removes the hazard at its
# root -- every workflow sees the same complete set, and whichever finishes last
# publishes a correct index rather than a partial one.
#
# It also closes a gap that existed with one tweak: when a build was skipped because
# the version was already released, the index depended on a separate download step
# succeeding. Now there is only one source of truth.
#
# Requires: gh (authenticated via GH_TOKEN) and dpkg-deb.

set -euo pipefail

OUT_DIR="${1:?output directory required}"
REPO="${2:?owner/repo required}"

# How many versions of each package stay installable.
#
# A published version must stay reachable after the next one goes out: if a build
# turns out to be broken on a device, rolling back has to be possible from Sileo
# rather than by hunting for an asset on the releases page. Three, not all of them --
# the source is a rollback path, not an archive.
KEEP="${3:-3}"

# Directories of freshly built .deb files to fold in, space separated.
#
# Asking the API for "every published release" a minute after publishing one does not
# reliably include it: a YouTube release published at 17:05:28 was missing from the
# listing the run asked for at 17:06:41. The listing is eventually consistent and this
# script runs inside the "eventually", so the run's own output is copied in as well.
#
# It goes through the same renaming as everything else, and that is the whole point of
# it being here rather than a `cp` in the workflow. The first attempt copied the build
# straight in under its own name -- com.albrhi.youtube_0.6.0+rootless.deb next to the
# gathered com.albrhi.youtube_0.6.0_iphoneos-arm64.deb -- two files, one identity, and
# the collision guard in make-repo.sh stopped the release. One naming rule, one place.
LOCAL_DIRS="${4:-}"

# Which tweak this run is responsible for, as a directory name under tweaks/.
#
# A run is strict about its own tweak and forgiving about the others, and that asymmetry is
# the whole point. The first version of this guard required every tweak's current version to
# be present in every run, which made the two workflows fail each other: YouTube's run could
# not see Instagram's release, Instagram's run could not see YouTube's, and both refused to
# deploy. Neither was broken. The index simply stopped being published at all, which is a
# worse failure than the stale index this was written to prevent -- a stale index serves an
# old version, a guard that never passes serves nothing new ever again.
OWNER_TWEAK="${5:-}"

# Packages that are deliberately kept out of the source, whatever the releases hold.
#
# Not publishing a package is not the same as withholding it, and that gap is why this
# list exists rather than a workflow being switched off and left at that. This script
# builds the index from what is *published* -- the whole reason it survives two
# publishers writing one index -- so a package whose workflow stops releasing is still
# gathered from its old releases and served forever, at the last version it shipped.
# Silence removes nothing.
#
# **CarPlay was removed from this repository**, on the owner's decision to stop carrying it
# here and rebuild it from scratch in a repository of its own. It never ran on a device: 0.3.0
# and 0.4.0 each looked finished and were not, and 0.4.1's fixes for what a real iOS 16.1
# report found missing were themselves never observed.
#
# Its entries stay in this list for the reason the paragraph above gives, and this is the
# second time that reason has been paid for: five `carplay-v*` releases are still published,
# and an index built from what is published would go on offering 0.4.1 forever -- from a tweak
# whose source is no longer in the tree to fix. Deleting the directory removes nothing from the
# source; these two lines do.
#
# **Withheld permanently** -- the individual social-app packages still bundled in the
# suite. com.albrhi is the front door for these; it declares Conflicts and Replaces on
# exactly these identities and suite/DEBIAN/preinst removes them by hand, because
# dpkg -i honours neither. So a device can never hold one of these *and* the suite, and
# serving them offers an install that the next suite update deletes.
#
# What made this urgent rather than tidy: they were being served **frozen**. Nothing has
# published them since the per-tweak workflows went manual, and this script builds the
# index from what is published -- so the last release each one ever made was being offered
# forever. The source was handing out com.albrhi.youtube 1.9.0 while the suite carried
# 1.13.0, four minor versions further on, with no update path off it. A stale package that
# can never move is worse than an absent one.
#
# Every one named here has never been published at all (tweak, youtube, twitter, panel,
# each in two flavours) except where a package outgrew the list -- see Locket below. The
# list is cheaper than the accident: if one is ever released by mistake, the withholding
# is already in place rather than something to remember afterwards. It is the same set
# suite/control declares Conflicts on, so the package and the source now say the same
# thing.
#
# **Locket is back on this list, and this time permanently.** It left the suite first, then
# left the repository: tweaks/locket and buildlocket.yml are both gone, on the owner's
# instruction to isolate it completely. Deleting a tweak does not stop the source serving it
# -- that is the whole point of the paragraph above -- because five published `locket-v*`
# releases still exist and this script builds the index from what is *published*. Without
# these two lines the source would go on offering Locket 0.4.1 forever, from a tweak whose
# source is no longer in the tree to fix. The releases stay as history; the source stops
# mentioning them.
#
# Matched exactly, against the archive's own Package field. Every flavour has to be named
# because rootless and roothide are separate package identities: listing only the first
# would withhold one and go on serving the other.
#
# TikTok and YouTube Music are in the suite exactly as the four above them are, and were
# missing from this list purely because their own workflows have never published anything --
# so the asymmetry cost nothing and looked deliberate. It is a trap either way: whoever gives
# one of them a publishing step later would find the index offering it beside the suite with
# no warning. Withholding is an explicit list here, never an absence of action.
#
# **Nothing but package names may go between the quotes below.** The note above was first
# written *inside* them, where `#` is not a comment -- it is a word. Every word of that
# sentence became a withheld package name, and one of them was the suite's own, so the
# rootless `com.albrhi` disappeared from the source entirely while the roothide flavour and
# every other package stayed exactly where they were. The build was green; the index was
# simply missing the package most people install. `buildsuite.yml`'s "does the source
# actually serve this version" step is what caught it, which is precisely why that step
# exists and why it runs against the live URL rather than against the build's own output.
#
# **The four social tweaks came off this list, and that is a decision rather than a fix.**
#
# They were withheld when com.albrhi became the front door: one package to install, one to update,
# and eight half-identities in the source that nobody should be choosing between. What changed is
# that each of them is now installable on its own -- so somebody who wants only YouTube has a
# package to install, and the others stay out of the way.
#
# The suite still declares Conflicts and Replaces on all of them, so this is a choice between two
# installs and never a way to end up with the same dylib injected twice.
#
# What stays withheld, and why each one:
#
#   panel     it is not a product on its own -- it is the screen the suite ships
#   ytmusic   only ever shipped inside the suite
#   carplay   never confirmed on a device; rebuilt in its own repository
#   locket    removed from this repository entirely; the releases stay as history
#
WITHHELD_PACKAGES="
com.albrhi.carplay          com.albrhi.carplay.roothide
com.albrhi.panel            com.albrhi.panel.roothide
com.albrhi.ytmusic          com.albrhi.ytmusic.roothide
com.albrhi.locket           com.albrhi.locket.roothide
"

# How far back to look, **per tag namespace**, and that qualifier is the whole fix.
#
# It used to be the newest 40 releases outright, and Locket silently fell out of the source
# because of it: the suite publishes constantly, so `locket-v0.4.1` -- perfectly healthy, still
# the current release then -- had been pushed to position 66 by the suite's own version history
# and stopped being gathered. **The source had no Locket in it at all, and nothing failed.**
# (Locket is deliberately withheld now, for an unrelated reason -- see the list above. The bug
# this fixes was never about Locket; it was about any slower publisher, and the next one will
# hit it identically.)
#
# That is the same class of failure this script's own header warns about, arriving from the
# opposite direction: it says a package is not removed by not releasing it, and this was a
# package removed by *someone else* releasing. One global window means the fastest publisher
# starves every slower one, and the starvation is invisible -- the index simply stops
# mentioning a package that is still perfectly current.
#
# So the window is per namespace: `v*` (the suite), `locket-v*`, and anything a future tweak
# adds. A namespace of its own is exactly what a separate publisher already has -- see the
# tag-namespace rule in CLAUDE.md -- so grouping by it needs no new bookkeeping.
SCAN=15

# How many releases to ask the API for. Larger than the window because the window is applied
# per namespace afterwards, and a slow publisher's newest release can sit a long way down one
# combined listing.
FETCH=100

is_withheld() {
    local candidate="$1" withheld
    for withheld in $WITHHELD_PACKAGES; do
        [ "$candidate" = "$withheld" ] && return 0
    done
    return 1
}

mkdir -p "$OUT_DIR"
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT

# Newest first, and prereleases included -- /releases/latest skips those, and this
# project's releases have been published as prereleases before.
# The namespace is the tag up to its version: `locket-v0.4.1` -> `locket`, `v1.42.0` -> the
# suite's own unnamed one. Newest first within each, then the newest SCAN of each are kept.
tags=$(gh api "repos/${REPO}/releases?per_page=${FETCH}" \
       --jq '.[] | select(.draft == false) | .tag_name' \
     | awk -v keep="$SCAN" '
           {
               namespace = $0
               sub(/-?v[0-9].*$/, "", namespace)
               if (namespace == "") namespace = "(suite)"
               if (++seen[namespace] <= keep) print
           }')

if [ -z "$tags" ]; then
    echo "::warning::No published releases found in ${REPO}"
    exit 0
fi

# Package id -> how many versions of it have been taken so far. Kept in a file
# rather than an associative array so this runs the same under bash 3, which is
# still what macOS ships as /bin/bash.
counts="${staging}/counts"
: > "$counts"

# Downloads a release's .deb assets, retrying a failure that is not "there are none".
#
# Distinguishing the two is the point. A release with no .deb is ordinary -- a dylib-only
# one -- and must be skipped without fuss. A request that failed is not ordinary, and
# treating it as an empty release removes a published version from the source.
#
# The test is the listing: if the release has assets matching the pattern, a download that
# came back empty was a failure and is worth another go.
fetch_debs() {
    local tag="$1" dir="$2" attempt

    for attempt in 1 2 3; do
        if gh release download "$tag" --repo "$REPO" \
                --pattern '*.deb' --dir "$dir" --clobber 2>/dev/null; then
            return 0
        fi

        # Does it actually have one? If not, there is nothing to retry for.
        if ! gh release view "$tag" --repo "$REPO" --json assets \
                --jq '.assets[].name' 2>/dev/null | grep -q '\.deb$'; then
            return 1
        fi

        if [ "$attempt" = 3 ]; then
            echo "::error::${tag} lists .deb assets but they could not be downloaded."
            return 1
        fi

        echo "::warning::${tag} has .deb assets but the download failed (attempt ${attempt}) — retrying."
        sleep $((attempt * 10))
    done

    return 1
}

taken_for() {
    awk -v key="$1" '$1 == key { print $2; found = 1 } END { if (!found) print 0 }' "$counts"
}

record_for() {
    local key="$1" value="$2"
    grep -v "^${key} " "$counts" > "${counts}.new" 2>/dev/null || true
    mv "${counts}.new" "$counts"
    echo "${key} ${value}" >> "$counts"
}

for tag in $tags; do
    dir="${staging}/${tag//\//_}"
    mkdir -p "$dir"

    # A release with no .deb -- a dylib-only one, say -- must not count against the
    # limit, or it would push a real one out of the index.
    #
    # Retried first, because those two outcomes look identical here and are not.
    # `gh release download` exits non-zero both when a release genuinely has no matching
    # asset and when the request failed, and the asset endpoint really does return HTTP 500
    # on its own account -- it did, on a release that was present and intact. Taking that at
    # face value quietly drops a published version out of the index, which is the one failure
    # this whole script exists to prevent.
    if ! fetch_debs "$tag" "$dir"; then
        echo "No .deb in ${tag} — skipping."
        continue
    fi

    for deb in "$dir"/*.deb; do
        [ -f "$deb" ] || continue

        # Grouped by the package's own identity, read from the archive rather than
        # guessed from the filename: the rootless and roothide builds of one tweak
        # are separate packages and each is entitled to its own rollback copies.
        package=$(dpkg-deb -f "$deb" Package 2>/dev/null || true)
        if [ -z "$package" ]; then
            echo "::warning::${deb##*/} has no Package field — skipping."
            continue
        fi

        # Checked before the keep-count, so a withheld package never takes a slot it
        # would then be dropped from -- it is not "an old version of something served",
        # it is not served at all.
        if is_withheld "$package"; then
            echo "Withheld ${package} (from ${tag}) — kept out of the source on purpose."
            continue
        fi

        count=$(taken_for "$package")
        if [ "$count" -ge "$KEEP" ]; then
            continue
        fi

        version=$(dpkg-deb -f "$deb" Version 2>/dev/null || echo "0")
        arch=$(dpkg-deb -f "$deb" Architecture 2>/dev/null || echo "unknown")

        # Renamed to the Debian convention on the way in. Two flavours of one tweak
        # have collided on a single filename before, and the second silently replaced
        # the first; name plus version plus architecture is exactly what tells them
        # apart.
        target="${OUT_DIR}/${package}_${version}_${arch}.deb"
        cp -f "$deb" "$target"

        record_for "$package" "$((count + 1))"
        echo "Kept ${package} ${version} ${arch} (from ${tag})"
    done
done

# Folded in after the gather, so a locally built package always wins over the copy the
# listing returned. They are the same bytes; the local one is certainly current.
for dir in $LOCAL_DIRS; do
    [ -d "$dir" ] || continue

    for deb in "$dir"/*.deb; do
        [ -f "$deb" ] || continue

        package=$(dpkg-deb -f "$deb" Package 2>/dev/null || true)
        [ -n "$package" ] || continue

        # A withheld package is withheld here too. This fold-in exists because the
        # releases listing lags behind a release the same run just made -- but a run
        # that builds a withheld package without releasing it would otherwise smuggle
        # it into the index by this door, which is the one path the gather above
        # cannot see.
        if is_withheld "$package"; then
            echo "Withheld ${package} — built this run, kept out of the source on purpose."
            continue
        fi

        version=$(dpkg-deb -f "$deb" Version 2>/dev/null || echo "0")
        arch=$(dpkg-deb -f "$deb" Architecture 2>/dev/null || echo "unknown")

        cp -f "$deb" "${OUT_DIR}/${package}_${version}_${arch}.deb"
        echo "Added this run's ${package} ${version} ${arch}"
    done
done

#
# Every tweak's current version has to be here before this counts as complete.
#
# Both workflows build and deploy this index, and the note in CLAUDE.md said that made
# the order they run in irrelevant. It does not -- that only holds if both gathers see
# the same set of releases, and a release published *between* them breaks it. Exactly
# that happened: both runs started at 11:53:02, YouTube published 0.10.1 at 11:54:36,
# and the run that gathered first deployed an index without it, last. The release was
# fine, the packages were fine, and the source served a version older than both.
#
# So the index states what it must contain and checks. Each tweak's control names the
# version that has to be present for its package; anything missing means the listing was
# read too early, which is worth one more look and then worth failing over. A source that
# quietly serves a version behind the release is the failure this whole arrangement
# exists to prevent.
#
verify_versions() {
    local missing=""

    # Relative to the script, not to the working directory: the workflow runs this
    # from the workspace with the repository checked out into main/, the same reason
    # extra-debs is reached that way above.
    # suite/control, not tweaks/*/control.
    #
    # The individual packages are no longer released on their own -- everything ships in
    # one, and the tweaks' own versions are internal now. Asserting them here would fail
    # every run looking for a release that is deliberately never made, and a red build on
    # a correct source is how a check gets switched off.
    #
    # The older published releases are still gathered and still served, so anyone who has
    # them can still see and roll back to them. They are simply not what must be present.
    local controls="$(dirname "$0")/../suite/control"
    # A tweak that publishes its own releases -- CarPlay is the first -- has to be
    # asserted here too, or its gather would happily deploy an index missing the
    # version it was just built to publish. Suite-bundled tweaks have no entry of
    # their own; only OWNER_TWEAK names one when it does.
    if [ -n "$OWNER_TWEAK" ]; then
        controls="${controls} $(dirname "$0")/../tweaks/${OWNER_TWEAK}/control"
    fi

    for control in $controls; do
        [ -f "$control" ] || continue

        local package version
        package=$(awk -F': *' '/^Package:/ {print $2; exit}' "$control")
        version=$(awk -F': *' '/^Version:/ {print $2; exit}' "$control")
        [ -n "$package" ] && [ -n "$version" ] || continue

        # A withheld package must never be asserted present: it is missing by design,
        # and this check would fail every run demanding what the gather deliberately
        # dropped. That is not hypothetical -- it is precisely what a run would do if
        # OWNER_TWEAK still named the withheld tweak.
        if is_withheld "$package"; then
            continue
        fi

        # The rootless build publishes as name_version+rootless_arch.deb and the roothide
        # one as name.roothide_version_arch.deb, so the version is matched inside the
        # filename rather than against the whole of it.
        if ! ls "$OUT_DIR" 2>/dev/null | grep -q "^${package}_${version}"; then
            missing="${missing} ${package} ${version}"
        fi
    done

    printf '%s' "$missing"
}

#
# Fetches one release by tag, rather than waiting for it to show up in the listing.
#
# This is the actual fix for the eventual consistency, and it took a failed deploy of both
# tweaks to see it. The listing endpoint is what lags; a release asked for *by name* is
# served as soon as it exists. Every version that has to be present is already known -- it
# is written in the tweak's own control -- so there is no reason to go looking for it in a
# list. The two tag shapes are the two this repository uses: Instagram tags vX.Y.Z and
# YouTube tags youtube-vX.Y.Z, so the second one is tried when the first is not there.
#
fetch_by_tag() {
    local tweak="$1" version="$2"
    local dir="${staging}/direct-${tweak}-${version}"
    mkdir -p "$dir"

    local tag
    for tag in "${tweak}-v${version}" "v${version}" "${version}"; do
        if gh release download "$tag" --repo "$REPO" \
                --pattern '*.deb' --dir "$dir" --clobber 2>/dev/null; then
            echo "Fetched ${tag} directly."
            break
        fi
    done

    local deb package version_read arch
    for deb in "$dir"/*.deb; do
        [ -f "$deb" ] || continue
        package=$(dpkg-deb -f "$deb" Package 2>/dev/null || true)
        [ -n "$package" ] || continue
        version_read=$(dpkg-deb -f "$deb" Version 2>/dev/null || echo "0")
        arch=$(dpkg-deb -f "$deb" Architecture 2>/dev/null || echo "unknown")
        cp -f "$deb" "${OUT_DIR}/${package}_${version_read}_${arch}.deb"
    done
}

missing="$(verify_versions)"

if [ -n "$missing" ]; then
    echo "::warning::Missing from the listing:${missing} — asking for those releases by name."

    # The same ones the check above names. fetch_by_tag tries "<name>-v<version>",
    # "v<version>" and "<version>" in that order, and the suite's tag is the middle one.
    version=$(awk -F': *' '/^Version:/ {print $2; exit}' "$(dirname "$0")/../suite/control")
    [ -n "$version" ] && fetch_by_tag "albrhi" "$version"

    # And the run's own tweak, if it publishes independently of the suite -- its
    # tag is "<tweak>-v<version>", which fetch_by_tag tries first.
    if [ -n "$OWNER_TWEAK" ] && [ -f "$(dirname "$0")/../tweaks/${OWNER_TWEAK}/control" ]; then
        tweak_version=$(awk -F': *' '/^Version:/ {print $2; exit}' \
            "$(dirname "$0")/../tweaks/${OWNER_TWEAK}/control")
        [ -n "$tweak_version" ] && fetch_by_tag "$OWNER_TWEAK" "$tweak_version"
    fi

    missing="$(verify_versions)"
fi

if [ -n "$missing" ]; then
    # Strict about this run's own tweak: if the version this run just built is not in the
    # set, the run itself is wrong and publishing would serve something older than what it
    # released.
    for entry in $missing; do
        # The list alternates package and version. Told apart by the first character, not by
        # counting dots -- com.albrhi.tweak has two dots as surely as 3.8.2 does, and the
        # pattern that seemed to distinguish them skipped every entry instead.
        case "$entry" in
            [0-9]*) continue ;;
        esac

        if [ -n "$OWNER_TWEAK" ] && \
           grep -q "^Package: ${entry}$" "$(dirname "$0")/../tweaks/${OWNER_TWEAK}/control" 2>/dev/null; then
            echo "::error::This run's own package is missing from the index: ${entry}"
            echo "::error::Refusing to publish a source older than the release this run made."
            exit 1
        fi
    done

    # Another tweak's newest release is not visible yet. Warned, not failed -- that tweak's
    # own workflow is what guarantees its version lands, and it rebuilds this same index
    # from the same releases when it runs. Failing here would only mean neither ever
    # publishes.
    echo "::warning::Publishing without:${missing}"
    echo "::warning::That tweak's own workflow will put it in when it next runs."
fi

echo
echo "Published packages gathered into ${OUT_DIR}:"
ls -la "$OUT_DIR"
