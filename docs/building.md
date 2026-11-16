[← Albrhi](../README.md)

# 🔨 Building

Requires [Theos](https://theos.dev) with an iOS SDK (the pinned **iPhoneOS 16.2**), GNU `make`, `ldid`
and `dpkg`.

```bash
git clone https://github.com/ibrahim2100/albrhi-repo.git
cd albrhi-repo
git submodule update --init --recursive
export THEOS=$HOME/theos
export PATH="/opt/homebrew/opt/make/libexec/gnubin:$PATH"   # GNU make; Apple's fails Theos

python3 tools/check.py            # always first — seconds, not a five-minute compile
./build.sh youtube rootless       # result lands in tweaks/youtube/packages/
```

Swap `youtube` for `instagram`, `twitter`, `tiktok`, `ytmusic`, `spotify`, `panel`, `nextup` or `watch`,
and `rootless` for `roothide`, `rootful` or `sideload`. **roothide needs a second Theos** (the roothide
fork) — the flavour is chosen by which Theos stages the package, never by the control file:

```bash
tools/build-local.sh                # the whole suite, roothide, onto ~/Desktop/Albrhi
tools/build-local.sh youtube rootless
```

It proves the flavour from the staged paths rather than the filename, and refuses to copy out a mismatch.
See [BUILD.md](../BUILD.md) for the checks, the roothide flavour and what CI does.

**Pure logic is run, not only compiled.** Parsers, rankings and decision rules (the YouTube Music lyrics module,
the YouTube transport, Instagram's deleted-messages log and copy rules, X's timeline filter, TikTok's link ranking,
the panel's version check) build against the macOS SDK and execute on the build machine — and CI runs them before
it will build a release:

```bash
bash tools/run-host-tests.sh          # every tweaks/*/tests/host/run.sh
```

A hook needs a device and there is no way around that. A parser does not.

## Layout

```
tweaks/<app>/     a complete tweak: Makefile, control, filter plist, src/, CHANGELOG.md
suite/            com.albrhi — the combined package, and the preinst that clears the old ones
shared/           Theos flags, build modes, the panel gate, safe launch, the message card, file names and the watch limit — see shared/README.md
docs/             investigations — what was measured, in what order, and what turned out wrong
tools/            source checks, APT index, depictions, signing, .deb editing, the browser tools
modules/ vendor/  third-party code, shared
extra-debs/       drop a .deb here and the source publishes it
```

Adding a tweak means adding a directory under `tweaks/` — `tools/check.py` finds it, `./build.sh <name>`
builds it, and `make-suite.sh` pulls it into `com.albrhi` automatically. Staying out takes a `.no-suite`
marker, and a tweak with nothing to do with the suite gets a publishing workflow of its own.

## 🛟 If an app stops starting
Every app Albrhi is in is watched during start-up. If the app does not manage to start **twice in a row**, Albrhi
installs nothing for the next launch and shows a card offering to bring it back. A crash later in a session that
started fine is not its business, and nothing in your settings is touched.

## 🧰 The tools

Everything under `tools/` is meant to be run by hand as well as by CI.

| | |
|---|---|
| **`check.py`** | **Twenty-six source checks**, run before Theos. Every rule comes from a build or a device that actually broke — unbalanced `%hook`/`%end`, a hooked class touching `self` without an `@interface`, a fragile `%orig`, a missing localisation key, a `%new` parameter carrying an attribute, and `-valueForKey:` probing (which runs the app's own code and cannot be made safe by `@catch`). Run from the root it re-runs itself once per tweak. |
| **`objc-classes.py`** | Prints a class's real methods, **declared property types**, ivars and **type encodings** straight out of a Mach-O's ObjC metadata; `--find-method` / `--find-ivar` answer "who answers this selector / owns this field". A framework-wide selector dump says a name *exists*, never on which class — this project lost releases to that gap. |
| **`make-suite.sh`** | Merges every tweak without `.no-suite` into `com.albrhi`, and refuses a staged tree that does not match the scheme it was asked for. |
| **`make-repo.sh`** · **`fetch-published-debs.sh`** | Build the APT index **from the published releases** (so several workflows can rebuild one index safely), with an explicit `WITHHELD_PACKAGES` list — because building the index from releases means silence removes nothing. |
| **`make-depiction.py`** | Sileo depiction and HTML fallback generated **from the changelog**, so they cannot go stale. |
| **`inject-dylib.py`** · **`ipa-inject.html`** | Put a dylib into an IPA, with entitlements read first and handed back. |
| **`deb-edit.py`** · **`deb-edit.html`** | Edit `.deb` metadata from a terminal or browser (served at `…/deb-edit/`). |
| **`build-local.sh`** · **`build-dylibs.sh`** · **`build-dav1d.sh`** | Local suite builds, the standalone dylibs, and the AV1 decoder. |
| **`release-notes.py`** · **`make-logo.py`** · **`repo-index.html`** | Release bodies from a changelog, the repo icon in pure Python, and the landing page. |

---
