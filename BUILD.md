# Building Albrhi

The short version lives in the README ([Building](README.md#-building)). This file is the longer one:
what to install once, what to run before pushing, and what CI does with it.
The reasoning behind each rule — what broke, and why it is a rule — is in [CLAUDE.md](CLAUDE.md) §3.

Building needs a **Mac** (or Linux) with Theos. The iOS SDK is not available anywhere else.

---

## 1. Once per machine

```bash
brew install ldid make dpkg                 # dpkg only for dpkg-deb; it cannot install packages here
git clone --recursive https://github.com/theos/theos.git ~/theos
# the SDK CI uses: iPhoneOS16.2.sdk from xybp888/iOS-SDKs, into ~/theos/sdks/

export THEOS=$HOME/theos
export PATH="/opt/homebrew/opt/make/libexec/gnubin:$PATH"     # GNU make; Apple's fails Theos
```

roothide needs a **second** Theos, the roothide fork, because Theos decides the package layout when it stages
(the flavour is chosen by which Theos builds it, never by the `control` file):

```bash
git clone --recursive https://github.com/roothide/theos.git ~/theos-roothide    # then copy sdks/ across
```

`bash tools/doctor.sh` checks all of this and says how to fix what is missing. It changes nothing.
`bash tools/install-hooks.sh` installs a pre-commit hook that runs the source checks.

## 2. Every time

```bash
python3 tools/check.py            # source rules: seconds, not a five-minute compile
python3 tools/check-repo.py       # versions, changelogs, README badges, workflows
bash tools/run-host-tests.sh      # pure logic, run on this Mac
./build.sh instagram rootless     # → tweaks/instagram/packages/
```

`build.sh <tweak> <mode>` takes `rootless`, `roothide`, `rootful` or `sideload`. A device is still the third gate:
compiling and host tests do not catch a wrong hook signature or a layout bug (see the Diagnostics pages).

## 3. A package for your own phone

```bash
tools/build-local.sh                    # the whole suite, roothide, into ~/Desktop/Albrhi
tools/build-local.sh instagram rootless
tools/build-dylibs.sh                   # the four standalone dylibs → ~/Desktop/Albrhi-Dylibs
```

It proves the flavour from the staged paths and refuses to copy out a mismatch. A local build carries a `+N`
suffix (`4.8.1+1`) so it installs over the last one. **`+N` is for this machine and is never pushed**
(`check-repo.py` refuses it when staged).

## 4. What CI does

| workflow | builds | publishes |
|---|---|---|
| `buildsuite.yml` | `com.albrhi` (rootless and roothide), the four standalone dylibs, the individual debs | **yes** — tag `v<suite version>` |
| `buildnextup.yml` · `buildwatch.yml` | NextUp · Watch | yes — `nextup-v*` · `watch-v*` |
| `buildtweak.yml` · `buildyoutube.yml` · `buildtwitter.yml` · `buildtiktok.yml` · `buildpanel.yml` | one tweak each | no — manual builds only |
| `build-dav1d.yml` | the AV1 decoder Instagram links | on demand |

A suite run: **host tests** (about 80 s; a failure withholds the release) → source checks → build only if
`v<suite version>` is not yet tagged → release assets → rebuild the APT index from what is published (newest three
versions of each package) → write `gh-pages` → ask the **live URL** whether it serves the version just built.
A daily run (05:17 UTC) retries anything a dropped run lost. All publishers share the `albrhi-pages` concurrency
group; a shared group keeps only the newest *pending* run, so **do not push a release in the same commit as a change
to `tools/` or `shared/`** — push those first, separately.

## 5. Releasing

See [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md). In one line: four numbers move together (the tweak's `control`,
its `SCIVersionString`, its `CHANGELOG.md`, and `suite/control` with the suite changelog), then README and
CLAUDE.md's *Known state*, and `check-repo.py` fails if one is missed.
