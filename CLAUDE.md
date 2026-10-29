# Albrhi — working context

Read this before touching anything. It is the accumulated reasoning behind the project: what
things are, why they are that way, and which mistakes have already been made so they are not
made again.

Owner: **Ibrahim Ismail AL-Rahn** (`@ibrahim2100`). Arabic is the working language; code,
comments and user-facing strings are English + Arabic.

**How this file is kept.** It is the single source of project context — `AGENTS.md` is only a
pointer to it, because two full copies edited by different tools drifted apart and contradicted
each other. Three rules keep it honest:

1. **A correction goes into the paragraph it corrects.** Appending "Correction: …" beside a claim
   that is now false leaves two answers and no way to know which is current. Rewrite the claim and
   say, once, what the earlier belief cost.
2. **The state lines are moved with the code, not after it.** *Known state* (last section) carries
   every version number; a stale line here is believed first, because this is the file read first.
3. **A rule that lives only in prose gets broken by whoever did not read it.** If a rule can be
   checked by a machine, it belongs in `tools/check.py` (see *Source checks*).

Contents: **1** what this is · **2** the lines this project draws · **3** repository mechanics
(build, check, CI, publishing) · **4** engineering rules that apply everywhere · **5** per-app
knowledge · **6** licensing (removed — what stayed behind) · **7** known state and open work.

---

## 1. What this is

Tweaks for jailbroken and sideloaded iOS, published as an APT source. **Nine tweaks:** six ship
inside one package, three stand apart.

| directory | package | patches | ships as |
|---|---|---|---|
| `tweaks/instagram` | `com.albrhi.tweak` | Instagram — tested on **410, 439, 441** from one build | in `com.albrhi`; standalone dylib |
| `tweaks/youtube` | `com.albrhi.youtube` | YouTube — tested on **21.30.5** | in `com.albrhi`; standalone dylib |
| `tweaks/twitter` | `com.albrhi.twitter` | X / Twitter — tested on **12.15** | in `com.albrhi`; standalone dylib |
| `tweaks/tiktok` | `com.albrhi.tiktok` | TikTok — tested on **46.4.0** | in `com.albrhi`; standalone dylib |
| `tweaks/ytmusic` | `com.albrhi.ytmusic` | YouTube Music | in `com.albrhi` only |
| `tweaks/panel` | `com.albrhi.panel` | the Settings app — switches, guide, backup | in `com.albrhi` only |
| `suite/` | **`com.albrhi`** | the five app tweaks and the panel | **the package people install** |
| `tweaks/spotify` | `com.albrhi.spotify` | Spotify — **Swift and Orion, the only one** | built by hand; **not published** (no workflow) |
| `tweaks/nextup` | `com.albrhi.nextup` | SpringBoard + five media apps — what plays next | own package, `nextup-v*` releases — **a GPLv3 port** |
| `tweaks/watch` | `com.albrhi.watch` | SpringBoard + Watch app — pairing a newer watchOS | own package, `watch-v*` releases — **an MIT port** |

- Repo `github.com/ibrahim2100/albrhi-repo` · source `https://ibrahim2100.github.io/albrhi-repo/` ·
  browser tools at `…/deb-edit/`. The tested app versions are the newest builds the owner's phone
  accepts, not a ceiling: nothing is pinned, every class is looked up at runtime.
- **`com.albrhi` is the front door for the social apps.** One install, one update, and a new tweak
  arrives inside it. It declares `Conflicts`/`Replaces` on the individual identities (rootless and
  roothide: tweak, youtube, twitter, tiktok, ytmusic, panel) and on `com.dvntm.ytmultimate`, and
  `suite/DEBIAN/preinst` removes them itself (see *Package managers*). The individual packages are
  **no longer served**; their old releases remain on the releases page as history.
- **`tools/make-suite.sh` merges every `tweaks/*/control` automatically**, skipping any directory
  with a `.no-suite` marker — **Spotify, NextUp and Watch** carry it. Joining the suite is the
  default and costs a version bump in `suite/control`; staying out needs the marker *and* matching
  edits in `buildsuite.yml` (see *CI*).
- **The suite is roothide and rootless**, `com.albrhi` and `com.albrhi.roothide` — separate package
  identities declaring `Conflicts`/`Replaces` on each other. **The owner's phone is roothide.**
- **The repository name is lower case, and that is load-bearing.** Sileo on a rootless device could
  not read the source at all (no `Release` file) while roothide read the same address fine. GitHub
  Pages paths are case sensitive; the request arriving was lower case: `/albrhi-repo/Release` 404 vs
  `/Albrhi-Repo/Release` 200, measured, before the rename. Retyping the source with exact capitals
  changed nothing, which ruled out a typo and pointed at the client lower-casing the path. **A source
  that serves perfectly and a source nobody can read are indistinguishable from this machine.** Do
  not reintroduce capitals into the repository name or any published path.

### Tweaks that are gone — what stayed behind

- **Locket** (a Flutter app) was taken out of the suite on request, then out of the project to
  isolate it completely: `tweaks/locket/` and `buildlocket.yml` are deleted.
- **CarPlay** patched SpringBoard and Camera to put an ordinary app on the car display. It **never ran
  on a device** (0.3.0 and 0.4.0 each looked finished and were not; 0.4.1's fixes for a real iOS 16.1
  report were never observed). It was never in the suite, and the owner's decision is to rebuild it
  from scratch in a repository of its own, because a wrong hook there takes the home screen with it.
- **Deleting a tweak does not stop the source serving it.** The index is built from what is
  *published* (`tools/fetch-published-debs.sh`), so `locket-v*` and `carplay-v*` releases would be
  gathered and offered forever at their last version. Both flavours of both — `com.albrhi.locket`,
  `.locket.roothide`, `.carplay`, `.carplay.roothide` — are named in **`WITHHELD_PACKAGES`**.
  Withholding is an explicit list and never an absence of action. And the suite's
  `Conflicts`/`Replaces` do **not** name them: it has no business deleting a package it never carried.
- **The licence layer** (keys, a free week, short codes, a Cloudflare Worker, an admin app) was removed
  in suite 1.95.0 at the owner's decision: **Albrhi is free.** `shared/src/SCILicense*`, the panel's Licence
  and plans pages, every tweak's licence row, `server/`, `app/`, `licence/` and their tools are deleted from
  the tree (git history has all of it). **The deployed Worker was not touched and is still answering for
  installs older than 1.95.0** — §6 says what that means before anyone switches it off.
- What they taught is kept where it applies below: the bypass-versus-payment line (§2), the `%ctor`
  gate and `SELFCONTAINED` lessons (§4), and CarPlay's display-mechanism notes (§5.9).

---

## 2. The lines this project draws

**Provenance.** Four kinds of source, treated differently, and the difference is the licence:

- **SCInsta (GPLv3, SoCuul)** is the ancestor of the Instagram tweak. Credit is a licence
  obligation, not a courtesy: it stays in-app, in the README, in the package metadata and in source
  headers. Never remove it.
- **GPL and MIT code that is carried over**: NextUp 3 by Yves (GPLv3), EeveeSpotify's ad blockers
  (GPLv3), NeoFreeBird by orionblur (GPLv3 — a BHTwitter fork, so the *same* licence as BHTwitter's
  original ideas but a licence that lets code be carried: X's section filter, typing/screenshot
  switches, counts and interface switches), YTMusicUltimate and YTMEnhanced (GPLv3), `watched` by 34306 (MIT, notice shipped inside
  the package), YTKACE's ad gates (MIT) and Mark02's YTPlaybackFix approach (MIT). Every ported file
  is kept diffable against upstream with each edit written where it is, attribution is in `control`,
  the changelog and the panel page's footer, and `tweaks/nextup/CHANGELOG.md` lists every change
  rather than letting the port read as original work.
- **Unlicensed references are read for architecture only, and nothing is copied**: BHTikTok and the
  al3raQe fork, NA9 For TikTok, VibeTok, ProfileBanner (TikTok, by Nasser | NoTimeToChill: four hooks and no licence; its hook table was the list of places to look and nothing was carried over), BHTwitter (the original — NeoFreeBird is a different, GPLv3 case),
  TWIGalaxy, `carsurf`, Regram, InstaPlus,
  Legizmo (a paid tweak — its licence and DRM components were deliberately not examined), and **Rocket for Instagram 4.23.1** (closed source, obfuscated, with a paid store: read for its public feature list and the
  selector names it carries in the clear; store and entitlement code not examined; call recording not proposed — `docs/investigations/rocket-feature-map.md`).
- **RyukGram is NOT in that list, and was wrongly in it until 2026-10-15.** Its repository carries a *proprietary* licence (all rights reserved) that forbids reverse engineering and forbids using
  any part of it, README included, to "build, train, or assist a competing product" -- which this project's Instagram tweak is. It is not read at all, for architecture or for its feature list. **Check the LICENSE file
  before reading a reference, not after:** "no licence file" and "a licence that forbids this" are different things and the second one was filed under the first.
- **ASJTok (TikTok, 2026) and ASJTube (YouTube) have no source in their repository** (a README and pictures; the builds are compiled) and no licence. 0.23.0 took only the public feature list, and every hook in it was found by our own reading of the TikTok
  binaries. **On 2026-10-27 the two compiled dylibs themselves were opened with REA** for their hook tables and what each replacement returns (nothing copied; store and entitlement code not examined) -- `docs/investigations/asjtok-asjtube.md`. TikTok 0.26.0 took nine small
  features and one jailbreak selector from that reading, each re-measured in 47.1.0 (§5.4). What was not taken on purpose: saving every story somebody opens automatically (holds others' temporary content without their knowledge), an auto-like button in LIVE, `PIPOStoreKitHelper`, and
  ASJTube's twelve `…Attestation…` getters forced to 0 (the same shape as X's `app_attest_*`, §2 Money) and its background-play getters (a Premium feature, the owner's call).
- **A reference tweak's selectors are a map of *its* build, never a manifest of ours.** NA9's list
  was written against an older TikTok (`downloadHDVideo`, `canDownload`, `isPreventDownload` are not
  in 46.4.0); InstaPlus hooks six selectors that do not exist in Instagram 410, even as strings;
  BHTwitter has four switches with no target in X 12.20; TWIGalaxy's binary still names a class
  that is not in X 12.15. Check each selector against the running build before hooking.

**Money.** A tweak that hands somebody a paid subscription is taking money from the app's developers,
not modifying a device, and this project does not do it — however often it is asked. Refused:
Locket's `Check0verPlus.dylib` (fakes RevenueCat entitlements), the Spotify and YouTube Music
"Premium" spoofs (`-isPremiumSubscriber` → YES on six classes), YTKACE's queue "without Premium" and
Premium logo, and TikTok's `PIPOStoreKitHelper -isJailBroken` (it sits inside the in-app-purchase
surface; the same question is answered by six other checks that *are* hooked). **A jailbreak-detection
bypass is different**: Locket and TikTok *report* the jailbreak to analytics and attribution SDKs
where it can count against an account, and answering as an unmodified phone would is hiding, not
taking. The reason is recorded next to the code each time, because "no" without a reason is
re-litigated.
- Spotify audio quality cannot be raised: `high-bitrate`, `very-high-bitrate` and `audio-quality` are
  account attributes the server sends, rewritten only by the Premium spoof. There is no 320 kbps
  hidden on the device. The ad blockers never consult the subscription state — measured in the
  upstream sources before a line was copied — which is why they could be taken and the rest could not.
- **`app_attest_*` is not offered in the X tweak.** Those keys are how X proves to its servers that the
  device is unmodified; switching them off is telling the server something it will not believe, on an
  account that can be locked for it.

**Telling an outside service what somebody is watching** is a cost paid only by whoever chose it, so
every such feature is **off until turned on and says so on its own row**: TikTok's external HD fetch
(`tikwm.com`), SponsorBlock for Spotify podcasts and YouTube Music, YouTube Music's lyrics sources
(on because asked for by name; translation is a separate off-by-default switch needing the user's own
key). YouTube's SponsorBlock uses the *private* hash lookup so the server cannot tell the video. The
line is not "never touch a third party"; it is that a privacy cost is never paid on someone's behalf
without telling them. The same goes for the *hold*: Albrhi Watch makes iOS say "up to date" in a
sentence the tweak caused, so the Software Update page names Albrhi as the reason. **A tweak that makes
the system state a fact about your device, without saying it did, is worse than the thing it hid.**

**Telling the server something untrue about the device is a cost, and the row that causes it says so and is off by default.** TikTok's region choice (§5.4) and the profile-background switch (0.25.0) are the two: the second sends
`profileBgInAllowList = 1` with the profile request. A tweak that only *shows* something on the device the person holds is a different thing from one that changes what the server is told.

**Hiding is not forbidding.** "Hide Spaces" in X set `voice_rooms_consumption_enabled: NO`, which tells
X the account may not *listen* to a Space at all, so a link somebody sent came back "unavailable". The
strip is hidden by withholding `-_t1_initializeFleets` and the tab by its own `audiospace` entry;
neither ever needed the key. The name on a switch is the promise, and «إخفاء» is not «تعطيل».

**Never erase what somebody already has because a switch went on.** X's `clearRecentSearches` exists
and is deliberately not called; keeping unsent messages never restores them *as though nothing happened* —
a tweak that leaves no trace of what it decided is deciding on your behalf without saying so, so the
message is marked.

**Wording.** "Free and open source" was removed from every description while the software needed a licence
to run. **That reason is gone (1.95.0) and the words were not put back** — descriptions say what a tweak does;
whether to say "free" again is the owner's call. **Dropping a word is not dropping an obligation** — GPLv3 is
named where it applies, MIT for Watch, and every credit is exactly as before. The Arabic name is
**البرهي**, never البرهان (a different word; eighteen strings once said it).

---

## 3. Repository mechanics

### 3.1 Layout

One tweak per directory under `tweaks/`: its own `Makefile`, `control`, filter plist, `CHANGELOG.md`
and `src/`. Nothing outside it knows which app it patches.

```
tweaks/<app>/        a complete Theos project (control Version drives the release)
suite/               com.albrhi — control, DEBIAN/preinst, CHANGELOG.md
shared/              tweak.mk, SCIPanelGate, SCIKVC, SCIResponder, Prefs/ — what every tweak shares
docs/                investigations/ — what was measured, in what order, and what turned out wrong · audit-2026-10.md — the whole-repo audit and what it left open
tools/               checks, APT index, depictions, signing, injection, browser tools (§3.6)
modules/ vendor/     third-party code (JGProgressHUD, dav1d, LightMessaging, libSandy, FLEXing)
extra-debs/          drop a .deb here and the source publishes it
build.sh <tweak> <mode> · build-dev.sh (local, skips packaging)
```

Per-tweak specifics worth knowing: Instagram's `src/Settings/Pages/` self-register in `+load` through
`SCISettingsRegistry` (a builder returning no rows is not drawn; adding a feature means adding one file)
and **every Instagram download goes through `SCIMediaDownloader` — do not add a second path** (before it
existed each surface built its own call and settings applied to one of them). YouTube's pipeline is in
`src/Features/Download/` (`Center/` is the library, player and tabs). X's feature switches live in
`src/Features/Switches/`. TikTok's `TikTokHeaders.h` records which confirmation bar each class meets.
NextUp is a near-verbatim copy (`NU*` prefix and layout kept so it can be diffed against upstream);
everything the port adds is in `src/NUAlbrhi.m`.

### 3.2 Adding a tweak

Create `tweaks/<name>/` with a `Makefile` ending in `include $(ROOT)/shared/tweak.mk`, a `control`, a
filter plist named after `TWEAK_NAME`, and `src/` with at least `Localization/SCILocalize.m` and a
`SCIVersionString` matching `control`. `tools/check.py` finds it, `./build.sh <name> rootless` builds it,
and `make-suite.sh` merges it. **A tweak earns its own publishing workflow only when it has nothing to do
with what the suite bundles** — copy `buildnextup.yml`'s shape (own version gate, own tag namespace, own
assets, a `.no-suite` marker). Taking one *out* of the suite touches **three places, checked together**:
the `.no-suite` marker, the `!tweaks/<name>/**` line in `buildsuite.yml`'s `paths:`, and the "holds every
tweak" assertion in that workflow. Spotify once left with the first two and the next suite release failed
*after compiling everything*, because the assertion still demanded `AlbrhiSpotify.dylib`.

### 3.3 Versions — four numbers move together

Bump the tweak's `control` **and** its `SCIVersionString`, add a `CHANGELOG.md` entry (release notes and
the Sileo depiction are generated from it), **and bump `suite/control`** — `com.albrhi` is rebuilt from
every tweak and its version is its own. `buildsuite.yml` asks the remote whether `v${SUITE_VERSION}` is
tagged and, finding it, prints "already released — building, not releasing": compiled, thrown away, a green
run, no update offered. The fourth number is the only one a device ever sees. Then update *Known state* (§7).

### 3.4 Building locally

Build locally before pushing — the CI round trip is five minutes, the local one under one. Per machine:

```bash
brew install ldid make dpkg            # dpkg only for dpkg-deb; it cannot install here
git clone --recursive https://github.com/theos/theos.git ~/theos
# + iPhoneOS16.2.sdk from xybp888/iOS-SDKs into ~/theos/sdks/ (the SDK CI uses)
export THEOS=$HOME/theos
export PATH="/opt/homebrew/opt/make/libexec/gnubin:$PATH"     # GNU make; Apple's fails Theos
python3 tools/check.py && bash build.sh <tweak> rootless
```

**roothide needs a second Theos.** A rootless package carries everything under `var/jb`; a roothide one does
not, because roothide decides its prefix on the device — and **Theos settles that when it stages, so the
flavour is chosen by which Theos builds it, never by the control file.** The `roothide` scheme exists only in
the fork (`git clone --recursive https://github.com/roothide/theos.git ~/theos-roothide`; copy `sdks/` across).
`tools/build-local.sh [suite|<tweak>] [roothide|rootless]` builds roothide by default into `~/Desktop/Albrhi/`
and **proves the flavour from the staged paths rather than the filename**, refusing to copy a mismatch out
(1.0.2 shipped a "roothide" package built from a rootless tree and it installed as rootless).
`tools/build-dylibs.sh` builds the four standalone dylibs into `~/Desktop/Albrhi-Dylibs`.

**A local build carries a `+N` suffix** (`1.82.0+1`): dpkg sorts it above `1.82.0` and below `1.82.1`, so every
local build installs over the last one and the published number space is untouched. Holding the version while
the content changes makes a build indistinguishable from the installed one, and the package manager correctly
does nothing — two rounds were once spent on code that was never on the phone. **A `+N` is for this machine and
must never be pushed**: committed to main it becomes the version CI reads and the publish step refuses
`v1.76.0+1` — a red run for a build never meant to leave the Desktop. Strip it by editing the values back, never
with `git checkout -- <file>` (that threw away a day's diagnostic marks once).

**What compiling does not catch**, measured: `cellClass` set to a string where Preferences wants a Class (crashed
Settings), a constraint built from `bounds` at construction time, an `objc_msgSend` cast to the wrong return
type (crashed TikTok), and a hook signature guessed from a name. Compilation is the second of three gates; the
third is a device. That is what the Diagnostics pages are for — and why host tests exist for pure logic (§3.5).

### 3.5 Source checks and host tests

`python3 tools/check.py` runs in CI before Theos, so a typo fails in seconds, not after a five-minute compile.
Run from the root it re-executes once per `tweaks/*` directory (a failing tweak is named, the others still run).
**Twenty-six rules, each from something that actually broke** (plus the repository-wide ones, below):

1. duplicate `@interface` — compared per **translation unit** (transitive quoted-import closure), not per file
2. brace balance and `%hook`/`%group`/`%subclass`…`%end` pairing — one **scanner** that knows comments, strings and
   character literals (stripping them with regexes in sequence created two false findings for every one it fixed)
3. a hooked class that touches `self` (property, message send, or as a ternary operand) but is never declared —
   Logos leaves a forward declaration that can be sent *no* message; Apple-prefixed classes are skipped
4. `%orig` sharing a line with braces or unbraced control flow
5. unterminated string literals (comment-aware, so `https://` is not a hit)
6. localisation parity, undefined keys, a missing table
7. `control` version equals `SCIVersionString`
8. project symbols used without their header, resolved transitively (the class half builds itself from every
   `@interface` in the tweak's headers)
9. quoted imports that resolve to nothing, against the makefiles' `-I` flags
10. a header promising a method its `@implementation` never defines
11. a block variable that calls itself (ARC rejects the retain cycle — a build failure, not a leak)
12. a `%hook` whose class name is never bound anywhere
13. an untyped `NSDictionary`/`NSArray` subscripted for a property; a getter returning `void`
14. `self.<property>` inside a `%group` whose class is named at runtime (`self` is `id`)
15. a C function in a header imported by `.xm`/`.mm` without `extern "C"` — **including headers in `shared/`**
16. a local assigned and never used (`-Werror`); **16b** a column-0 `static const` never used (a different warning)
17. an `SCI…()` call defined in no header this tweak can reach
18. `--` inside a `.plist` XML comment (illegal XML; the project's own prose uses `--` constantly)
19. a `%new` parameter written with an attribute — Logos pastes the written type into `@encode()`
20. a parenthesis left open at the end of a line in `control` (Theos validates line by line, *after* a clean compile)
21. a `layout/DEBIAN` maintainer script not marked executable — **read from the git index**, not the working tree
22. an `SCI…()` function that only exists in a *different* tweak (`SCIPrefEnabled` is YouTube's, written into X)
23. **`-valueForKey:` on somebody else's object** — use `SCISafeValueForKey`/`BoolForKey`/`NumberForKey` from
    `shared/src/SCIKVC.h`
24. a `PSTitleValueCell` that sets a `value` and has no getter (a title-only cell of that kind is an ordinary row)
25. a second copy of the "find the key window" walk in a tweak that already has `SCI<..>KeyWindow(void)` (YouTube wrote it ten times, each a little different, and a fix to one reached none of the others); a deliberate different question says `sci-allow-keywindow` on its line
26. a `SCIPref…` macro that nothing reads — a switch that does nothing is a screen that lies (found by deleting `h264_only`, which had a macro, a default and a row and no reader once the filter was gone)

**Repository-wide checks** (`tools/check-repo.py`, run first by `check.py`) are the rules that were paragraphs: no `+N` in anything **staged** (a local build's `+N` sits in the tree and is none of its business; CI checks the tree);
a changelog's newest entry equals the `control` version, for every tweak and the suite; README badges, the README table and *Known state* equal the `control` version; **the suite is bumped whenever a tweak in it
is** (local only: compares with `HEAD`, which CI's shallow clone does not have); `.no-suite` and `buildsuite.yml`'s `!tweaks/<name>/**` agree; every workflow that publishes takes `albrhi-pages`; and a step id named
in an `if:` exists. Each was proved by reintroducing its bug. They found nothing in the tree when first run — the value is the next push, not the last one.
**A check that cries wolf gets ignored.** Rules are fixed in the rule, never in the code being checked, and **the
other tweaks are the oracle**: they build under `-Werror`, so any finding in them is by definition a false
positive. When a rule fires on imported code that builds clean, suspect the rule. Rule 16 once reported
`NSString *page = …` as `age` (a non-greedy pattern ate into the name): 180 false findings. The orphan count
(unused localisation keys) once read 54 in X where 5 were real, because keys handed to something that localises
later never appeared inside `SCILocalized(@"…")`; accepting a bare quoted occurrence fixed it and the first
attempt reported **zero** everywhere (the table file counts as a file) — **a zero is worse than an over-count,
it reads as checked and clean.** If you add a rule, prove it fails by reintroducing the bug.

**Host tests** run pure logic on the build machine against the macOS SDK: `bash tweaks/ytmusic/tests/host/run.sh`
(LRC parser, matching pipeline, caches, romaniser, extractors — 29 tests in about a second) and
`bash tweaks/youtube/tests/host/run.sh` (the transport), `bash tweaks/instagram/tests/host/run.sh` (the deleted-messages log) and `bash tweaks/twitter/tests/host/run.sh` (X's timeline section filter — the code is copied out of the `.x` by marker, so what passes is what ships). A hook needs a device; a parser does not, and several of
this project's most expensive bugs lived in exactly that layer. `bash tools/run-host-tests.sh` runs every `tweaks/*/tests/host/run.sh` (found by glob) and the class-dump diff tool's self-test. Added since: the direct route's format choice and quality ladder (`SCIYTDirect`,
the pure part was moved into `+ladderForVideos:audio:videoID:` so it could be copied out by `// host-test:begin` marker), the panel's "newest version in `Packages`", and TikTok's kind rank and demoted origins.
**Not covered, stated:** TikTok's comparator that orders measured links (it sits inside a method that makes network requests), `SCIYTFragments` (needs a fragmented MP4 fixture), and everything about what the apps
actually serve, which only a device says. **The YouTube Music harness had been failing** (no include path for `shared/`, `SCIKVC.m` not compiled, and newer UIKit refusing an app with no scene) while this file
said "29 tests in about a second" — a test nobody runs in CI is a test that rots; the three are fixed and it passes again.

### 3.6 Tools

| tool | what it is for |
|---|---|
| `check.py` · `check-repo.py` | the rules above · the repository-wide ones |
| `objc-classes.py` | a class's real method list, **declared property types**, ivars, class methods and **type encodings** out of a Mach-O's ObjC metadata; `--find-method` / `--find-ivar` answer "who answers this selector / owns this field" |
| `objc-diff.py` | **what changed between two builds, among the classes a tweak names** (`<old> <new> --tweak tweaks/x`), and `--check <build> --tweak tweaks/x` for one build: every `%hook` on a class the build lacks or on a selector nothing in the class chain declares (rule 4.2, automated; chain read through chained-fixup **binds**, so `UIView` is a name and not `?`; generated protobuf getters are reported as unknowable, not as missing). Fed by `objc-classes.py <binary> --dump` (YouTube 21.34.3: 33,263 classes in 17 s). 9 self-tests on two compiled dylibs |
| `ref-leads.py` | **the app-side selectors a reference tweak names** (Apple's SDK vocabulary and the reference's own selectors subtracted; `--tweak` splits off what our sources already name; licence/store selectors listed apart as *not examined*). Rocket: 1,376 raw → 106 leads, 13 already ours. A lead is unverified until the app's own binary is asked |
| `doctor.sh` | readiness: Theos, SDK, GNU make, ldid, dpkg, roothide Theos, Xcode, node, `gh`, the hook, and (optional) Java and Ghidra — each with the fix. Read-only. The shape is REA's `rea doctor` |
| `make-suite.sh` · `merge-control.py` | merge the staged trees into `com.albrhi`; refuse a tree that does not match the scheme; **keep the fields Theos computed and override only your own** (replacing `DEBIAN/control` wholesale once threw away what Theos had written) |
| `make-repo.sh` · `fetch-published-debs.sh` | build the APT index **from the published releases**; `WITHHELD_PACKAGES`; guard against two packages sharing name+version+architecture; label rootful/rootless/roothide |
| `make-depiction.py` · `release-notes.py` | Sileo depiction + HTML fallback and GitHub release bodies, **generated from the changelog** so they cannot go stale |
| `build-local.sh` · `build-dylibs.sh` · `build-dav1d.sh` | local suite, standalone dylibs (their check **fails the build if a `SCILicense` symbol is inside** — the removal stays proved), the AV1 decoder |
| `inject-dylib.py` · `ipa-inject.html` | put a dylib into an IPA; entitlements are read with `ldid -e` **before** anything is modified and handed back with `ldid -S<file>` (re-signing with `-S` alone erases them — TikTok carries twenty) |
| `sim-install.sh` · `sim/SimShim.m` | **a decrypted device IPA, with a standalone dylib injected, running in the iOS Simulator** (`bash tools/sim-install.sh <ipa> [<dylib>] [<simulator>]`, about 40 s): every Mach-O is re-stamped from the device platform to the simulator's with `vtool` (an Apple-silicon simulator runs arm64 natively; only the platform stamp stops it), duplicate `LC_RPATH`s are removed (the simulator's dyld refuses them), the bundle is signed ad hoc, and a simulator-only helper swallows the failures a device build does not have (see below) |
| `run-host-tests.sh` | every host test, by glob (§3.5) |
| `deb-edit.py` · `deb-edit.html` | edit `.deb` metadata (`label` appends `(rootless)`/`(roothide)`/`(rootful)`; `normalize` converts an xz control archive to gzip — the browser tool carries a hand-written DEFLATE because `DecompressionStream` is iOS 16.4+) |
| `make-logo.py` · `repo-index.html` | repo icon in pure Python, the source's landing page (built from the live index) |

**REA (`morluto/rea`, npm `rea-agents` 6.4.0 — 6.8.0 was the newest published on 2026-10-26, not installed — MIT) is installed on the owner's Mac as an aid, not a dependency** (nothing in the build or CI uses it): `npm install --global --ignore-scripts`, registered in
Claude Code as an MCP server by `rea setup --client claude_code` (backup `~/.claude.json.rea.backup`; tools appear after a restart), Ghidra 12.1.4 and JDK 21 from Homebrew. **Measured, not assumed:**
its ObjC metadata matches `objc-classes.py` on classes (adds protocols, categories, implementation addresses; **no type encodings**) and **refuses a binary whose metadata exceeds 64 MiB (YouTube 21.34.3)**;
its decompiler works through Ghidra and names ObjC methods `Class::selector:` (with the colon; `rea search --kind procedures` lists them) — **the one capability we lacked, not yet used on a real app**: the
one attempt, YouTube's 225 MB binary, was cancelled after 11 minutes (the whole binary is analysed before the first answer; a persistent MCP session is the right way to ask several questions of it).
Do not claim it answered something until it has. `rea setup` writes configuration files: ask first.

**The simulator route (2026-10-29), measured on TikTok 47.1.0:** the app starts, runs its launch, draws the For You feed with this tweak's download button on the rail, and the tweak's own welcome screen appears -- so hooks, banners, menus and settings pages can be driven and
screenshotted from this machine instead of waiting for a phone. Three things a device build needs fixed, each found by running it: the duplicate `LC_RPATH` in `ffmpeg_dashdec`; the app's **Metal libraries are built for the device** ("library was not compiled for the simulator"), whose failed completion handler
TikTok then feeds a nil `NSString` (`strlen(NULL)`); and a texture made from a non-private buffer, which the simulator's driver asserts on. `SimShim.m` handles the last two and logs each as `[SimShim]`. **What it cannot say:** whether it works on the phone -- no hardware video decoders, no App Attest,
a different GPU driver, no camera. A failure here is a lead; a success here is not "confirmed on a device" (§7). **Accepting TikTok's terms and answering the permission dialogs inside the simulator was authorised by the owner on 2026-10-29** (it is a test copy; the notifications, tracking and personal-question dialogs get the least-sharing answer); signing in is never done on his behalf.
**How to drive it, learned in one session:** a tap from the control tool is too short for a `UISwitch` (it toggles the row, not the switch: use `duration` 0.15); a screenshot lags a transition by about a second (wait with `sleep`, or a tap lands on the screen that was leaving); prefs can be written with `xcrun simctl spawn <sim> defaults write com.zhiliaoapp.musically <key> -bool YES` (the app reads them at its next launch); `SIM_KEEP_DATA=1` keeps the app's data across a rebuilt dylib (a plain run reinstalls and erases terms, onboarding and prefs); the pasteboard is `xcrun simctl pbpaste`, which is how a copy row is *measured* instead of looked at. **The simulator's software H.264 decoder (`H264SW.videocodec`) crashes the app at random (a stack-guard `EXC_BAD_ACCESS`, seen four times in one hour, once on every launch for several minutes) and videos render black: that is the simulator, not the tweak**, and photo posts and profiles are the stable surfaces to test on.

Packages are published as `package_version_architecture.deb`, not under the uploaded filename — a converted
package keeps its original name and two flavours once collided on one path. Converting rootless into roothide
mechanically was rejected: whether a binary hard-codes jailbreak paths cannot be known from outside, so the
result installs cleanly and fails on the device. Build both flavours from source.

### 3.7 CI and publishing

| workflow | builds | publishes? |
|---|---|---|
| `buildsuite.yml` | **`com.albrhi`** (+ the four standalone dylibs, individual debs, release assets) | **yes** — `v${SUITE_VERSION}` |
| `buildnextup.yml` | NextUp | yes — `nextup-v*` |
| `buildwatch.yml` | Watch | yes — `watch-v*` |
| `buildtweak.yml` · `buildyoutube.yml` · `buildtwitter.yml` · `buildtiktok.yml` · `buildpanel.yml` | one tweak each | **manual build only, write nothing** |
| `build-dav1d.yml` | the AV1 decoder Instagram links | on demand |

`buildsuite.yml` also carries a **`host-tests` job** (`tools/run-host-tests.sh` on a macOS runner, about 80 s) and **`build` waits for it** (`needs: host-tests`, since the 2026-10-26 audit): it was report-only while these harnesses had never run on a CI image, and it then passed fourteen runs in a row, so a red result now withholds the release; the daily schedule retries, so a flaky runner costs a day and not a release. **First run on CI (suite 1.93.4): all six Mac suites passed (instagram, panel, tiktok, twitter, youtube 11, ytmusic 29),** (a licence-server Node test also ran there and needed a glob rather than a directory; the server is gone and so is that test). **CI time is compiling** (measured on one run: about 7 of 8 minutes; Theos setup 12 s), so caching Theos was not worth adding.

There is no Spotify workflow. **Three workflows publish and all take the `albrhi-pages` concurrency group** — the
one thing stopping two runs writing `gh-pages` at once.

- **A shared concurrency group cancels a *pending* run**, which `cancel-in-progress: false` does not prevent (it
  protects a run already executing; GitHub keeps only the newest queued member). A commit touching a path two
  publishers watch — `tools/**`, `shared/**` — starts both and silently drops whichever queued second: status
  `cancelled`, not `failure`, no index update. It happened to suite 1.58.15 and again to 1.79.0 (a release
  bundled with an edit to `tools/`). **Before pushing a release, check the same commit does not touch `tools/` or
  `shared/`**; push those first and separately. `tweaks/nextup/**`, `tweaks/watch/**` and `tweaks/spotify/**` are
  excluded from the suite's triggers so a change confined there starts exactly one run.
- **Recovery is built in:** `buildsuite.yml` also runs on a daily cron (05:17 UTC). The version gate refuses a
  version already tagged, so an ordinary day costs one short run and the day a run was dropped it publishes what
  was lost.
- **The index is built from what is published**, so a quiet workflow keeps being gathered at its last version
  (hence `WITHHELD_PACKAGES`). The gather is **per tag namespace** (`v*`, `nextup-v*`, `watch-v*`, …): one
  global window of 40 releases let the suite's constant publishing push `locket-v0.4.1` to position 66 and the
  source silently stopped serving it. A bounded scan shared between producers is a starvation bug waiting for
  one of them to speed up.
- **The gather states what the index must contain and checks it** (`suite/control`, and the running workflow's own
  tweak) — a release published *between* two gathers once made the last deploy a version behind with nothing
  failing. And each run copies its own freshly built `.deb` into the set, because the releases API is eventually
  consistent and a run once finished with an index that stopped at the previous version.
- **A `#` inside a quoted shell string is a word, not a comment.** A note explaining `WITHHELD_PACKAGES` was
  written *between the quotes of the assignment*, so every word of the prose became a withheld package — including
  `com.albrhi`. The build was green, the release published, and the source silently lacked the package most people
  install. Only the step that asks the **live URL** caught it, which is exactly why that step must never be relaxed
  to test the build's own output.
- **A step copied between workflows brings its `if:` with it**, and a condition naming a step id that does not
  exist is silently false (the two store-copy steps carried `steps.release_check…` into a workflow whose gate is
  `steps.gate…` and were skipped). Grep a workflow's own ids after pasting into it.
- **Anything generated must be written to `gh-pages`**, not just handed to a Pages artifact (a depiction generated
  only into one workflow's artifact 404'd a minute after publishing, when the other workflow deployed from the
  branch). `debs/` on `gh-pages` is rebuilt from scratch each run, on purpose, so removals take effect.
- **Pages:** a repository serves from a branch or from a workflow artifact, and which one is a setting no file can
  read; `deploy-pages` works only in the second and polls `deployment_queued` forever in the first, so it was
  removed. `GITHUB_TOKEN` may deploy to Pages and may not reconfigure it. **What decides success is the live URL**,
  checked with `always()`, polling `/pages/builds/latest` until `built` — **a sleep is a guess about how long
  something takes**; every time one was replaced with a question the answer came back immediately and was right.
- **A release that fails while "finalizing" is worse than one that fails outright.** `action-gh-release` creates a
  draft, uploads, then publishes; v1.36.0's publish step 503'd during a GitHub outage, leaving a draft that the index
  cannot see (`.draft == false`) and a gate that says "already released". Publish the draft by hand, then re-run.
  The `deploy` failures in that outage were GitHub's own `pages-build-deployment`, not these workflows.
- **What a suite run does:** read `Version` from `suite/control`; build only if `v${SUITE_VERSION}` is not yet tagged (manual runs accept `force_rebuild`; otherwise reuse the published
  assets); release with rootless and roothide `.deb`s, the four individual `.deb`s and standalone dylibs; rebuild the index **keeping the newest three versions of every package** (so a bad
  build can be rolled back from Sileo; `repo-index.html` shows each package once, at its newest); rewrite the URLs in `control` from the repository the build runs in (so a rename needs no edit);
  write `gh-pages`; then ask the live URL whether it serves the version just built.
- **Per-tweak builds** (the manual ones) need `dpkg` installed on every run, not only build runs (the index needs
  `dpkg-scanpackages` even when compiling is skipped); `ldid` and `make` stay gated.
- **Package managers honour `Conflicts`/`Replaces`; dpkg does not.** `dpkg -i` on a downloaded file unpacks it and
  leaves the old package, so both dylibs end up injected. `suite/DEBIAN/preinst` removes the old ones itself —
  declaring a relationship and hoping is not performing it.
- **Re-signing, linking, flavour:** `otool -L` prints the file's own install name before its dependencies and every
  tweak installs under `/Library/MobileSubstrate/`, so a "no Substrate" check must skip **two** lines (`tail -n +3`)
  or a clean build reads as linked; a standalone dylib must be proved standalone (no Substrate dependency, no
  undefined `MS*` symbol, and **no `SCILicense` symbol** — inverted from "compiled in" when the layer was removed) — `build-dylibs.sh` runs the same three checks
  CI does.
- **Store-copy builds:** `-D` with a quoted string survives make and the shell only as `'"$(VAR)"'`; and `strings`
  answers "no" about a three-character string (default minimum four) — search the bytes for `na9\0` instead.

---

## 4. Engineering rules that apply everywhere

Every line here comes from something that actually broke. They are grouped by the question they answer.

### 4.1 What exists, and what is true of *this* build

- **A class dump is of one app version, and an undated dump is a trap.** The follow-badge crash fix was
  built from a dump that turned out to be Instagram **439** while the reporting device runs **410**; narrowing
  a lookup to an accessor confirmed on 439 alone, in a tweak that serves 410, 439 and 441 from one build,
  costs a feature silently. Date a dump before trusting it — `-autoScrollState` is 410-only,
  `IGSundialAutoScroll` is 439-only.
- **A framework-wide selector dump says a name exists; it never says on what class.** `downloadAddr` is a
  real string in TikTok's framework and on no class here; `bestURLtoDownload` is real in NA9's older build and
  absent from ours; `bitRate` belongs to `TTKECVideoBitModel` while the feed's `AWEVideoBSModel` calls it
  `bitrate`. Every bitrate entry answered `respondsToSelector:` NO, scored zero, and the whole HD comparison
  fell through to SD silently. When the question is "does *this* class answer *this* selector", ask
  `tools/objc-classes.py` — or the device, with `class_copyMethodList` in a diagnostics page, which is that tool
  run where it matters.
- **In a modern arm64 image the quadwords in `__DATA`/`__DATA_CONST` are not pointers**: chained fixups put the
  target in the low 36 bits and metadata above. Unmasked, the class list parses as one entry and every lookup
  says "not in this binary" — a confidently wrong answer. `otool -s` prints little-endian words, so piping its
  hex through a naive decoder scrambles text into clean-looking absence. And **one non-ASCII character moves a
  string literal out of `__cstring`** into UTF-16 `__ustring`, where `strings` and `grep` answer "missing"
  confidently; verify a string by dumping both sections, or verify with a symbol
  (`_logos_orig$Group$Class$selector` is ASCII).
- **The `_objc_msgSend$<selector>` stub symbol is evidence of a selector actually being sent**; its absence is
  evidence too (that is how TikTok's `-playAddr` was demoted and invented names were caught). Grep a reference
  binary for the stub, and for its **Logos symbols** (`Class$selector`), before ranking candidates — reading a
  working tweak's strings is not reading its technique (NA9's symbols answered the architecture question in one
  command after three releases of comparing names).
- **A class present in the binary is not a class the app draws.** `YTSlimVideoDetailsActionView` has metadata in
  21.34.3 and built zero instances over a whole session on 21.32.4; X's `ImmersiveInlinePlaybackButtonsStackView`
  is not in 12.15 at all (its sibling `ImmersiveCardView` is, so Swift classes are covered and the absence is
  real). **Count constructions, not outcomes.** And a class that exists plus a method never called is two
  faults — the app never builds one, or builds it and fills it through a selector this build names differently.
- **An app's classes are not in its executable.** TikTok's live in `MusicallyCore.framework` (785 MB, 1,032,816
  selectors; the executable is a 91 KB stub); X's in `T1Twitter.framework` and the `…SPMMigration` images
  (10,827 classes across 58 Mach-O images; `THFHomeTimelineItemsViewController` is in the *main* executable);
  YouTube's `YT*` classes are ASDK-built. `NSClassFromString` asks every loaded image — bind by it, do not scan.
- **A `%ctor` can run before the app's own Objective-C metadata is registered**, so `NSClassFromString` answers
  nil for a class the app certainly has and the report says "not in this build". Ask again on
  `UIApplicationDidFinishLaunchingNotification` and once more after a short delay, **and count the attempts** — "worked
  on the second try" and "worked immediately" are different facts about a build.
- **A view is not configured when its initialiser returns**: `-hasOfflineButton` at construction would answer NO
  for a button that becomes the download button a moment later. Ask at `-didMoveToWindow`, once per instance.
- **A generated model's getters do not exist until somebody asks.** `YTIPlayerResponse` is protobuf, so
  `class_getInstanceMethod` answers NULL for a getter it has; sending `+instancesRespondToSelector:` first runs the
  resolver. Instagram's `IGDirectCacheThreadUpdate` declares no ivars, no properties and one method
  (`+internal_classInfo` is the tell, one of ~2,800 such classes): ask the named field (`threadUpdates`,
  `mutationIds`, `sequenceIds`) through `SCISafeValueForKey` rather than enumerating — an empty `{}` in a report is a
  question, not an answer. A walk with a depth limit stops one hop short the day the chain grows (2 became 4).
- **A chain confirmed hop by hop is the only kind that has ever worked here**, and the tool prints declared property
  *types* for that reason (`YTIPivotBarItemRenderer.navigationEndpoint : YTICommand` → `browseEndpoint :
  YTIBrowseEndpoint` → `browseId`; TikTok's `photoAlbum : AWEPhotoAlbumModel` → `photos` → `AWEPhotoAlbumPhoto`).
  Fixing the *wrapper* and still asking it for `images` read the post as empty for a release.
- **Matching a row by the English words printed on it only works in English**, and this repository ships to an
  Arabic phone. Thirteen inherited comparisons against `@"Ask Meta AI"`, `@"Suggested for you"` go through
  `SCIMatchesEnglishTitle`, which counts `12 seen, 0 matched`; the Watch hold finds its rows **by structure** (the
  rows after the group whose identifier is `INSTALL_BUTTON_GROUP`). Where there is no confirmed identifier, say so
  rather than guessing one or deleting the feature.
- **A Info.plist is a fact about what a tweak can do, and it is readable from this machine.** YouTube declares
  `NSPhotoLibraryUsageDescription` and **not** `NSPhotoLibraryAddUsageDescription`, so an add-only request falls back
  to the reading key and the prompt is about uploading. The guard accepts either key (that is what lets saving work)
  and `denied`, `restricted` and `notDetermined` need three different sentences.

### 4.2 Hooking safely

- **`-valueForKey:` is not a safe probe — it runs the app's code.** It calls the real getter when one exists and
  reads the ivar when not; raising is its last resort. The follow badge probed twelve guessed keys on every object up
  the responder chain from `-layoutSubviews`, behind a comment asserting a missing key "just throws (caught)", and
  changing a profile picture crashed the app. **`@catch` does not make a probe safe** — it catches `NSException`;
  a Swift getter that traps, a failed assertion or a half-initialised object end the process. Rule 23 enforces
  `shared/src/SCIKVC.h`. KVC resolves a key four ways (`-key`, `-isKey`, `-getKey`, then the `_key`/`key` ivar), so a
  replacement checking one selector silently stops finding values; `SCISafeValueForKey` tries all four, reads each
  getter through a cast taken **from its own type encoding**, and reads the ivar with `object_getIvar` only when the
  runtime says it holds an object (which executes nothing — why it is *safer* than KVC, not merely equivalent). A
  scalar getter is a real answer of the wrong kind: `SCISafeValueForKey` returns nil for it and `SCISafeNumberForKey`
  asks for the number (grep converted sites for `boolValue`, `integerValue`, `isEqual:@(` before a sweep).
  **`class_getInstanceMethod` returning NULL does not mean the object cannot answer** — `LSApplicationProxy` and every
  protobuf class resolve selectors dynamically, and `-methodSignatureForSelector:` is what the forwarding machinery
  itself consults. A runtime query that comes back empty is not a fact about the object; test a replacement for a
  Foundation behaviour against the behaviour it replaces.
- **A `%hook` on a method the class does not declare does not politely do nothing — Logos *adds* it**, and an added
  getter with no original replaces whatever the app resolves for itself. Install hooks at runtime, behind
  `class_getInstanceMethod` **and the type encoding you expect** (stand down on a mismatch — non-NULL proves the
  selector exists, not its types). TikTok died repeatedly on a probe declared `(double)`, `(NSInteger)`, returning
  `id`; the real encoding was `v48@0:8@16d24^q32@40`, a `^q` out-parameter. Orion has no equivalent of Logos never
  attaching to a missing class: activating an Orion group whose target is absent is not polite either. Every runtime
  gate records installed / class absent / method absent / the encoding found instead, and counts hits.
- **Ask how often a hook runs, not only whether the method is there.** TikTok's `-viewDidLayoutSubviews` on
  `AWEAwemeBaseViewController` (whose methods are `loadView`, `setModel:`, `viewDidLoad`) ran a quality-ladder walk on
  every layout pass: two unchecked assumptions, one crash. `-setModel:` fires once per video and is the bind point.
  And **`_ASDisplayView` is not a class, it is every view in the app**: a `-didMoveToWindow` hook written to catch one
  ad card fires thousands of times before the first frame, and `accessibilityIdentifier` on a node-backed view can make
  the node materialise. It stands aside until the app is active.
- **Hook the decision, not the fifty-one views that read it.** X's `-boolForKey:` on `TFSFeatureSwitches`,
  `TFSCachingFeatureSwitchProvider` and `TPSTwitterFeatureSwitches` (`B24@0:8@16`) plus `-unsafePeekBoolForKey:`; its
  open-in-Safari was a feature switch (`ios_in_app_article_webview_enabled`, asked 72 times) while three releases hooked
  browser classes and the report's **`0 left to X` said the hook was on a path nothing takes** — the moment to stop
  refining it. **Hook a family's base and allow-list the members** (twenty-six classes descend from
  `T1BaseWebViewController`; sign-in, billing and password-reset browsers are among them, so exact-class compare and
  inclusion, never a deny list). **Count the entry points**: YouTube's collection fills through three selectors
  (`addSectionsFromArray:`, `insertSections:byPosition:error:`, `insertSections:byRelativePositionInSectionList:error:`);
  hooking one made a launch ad vanish after a pull-to-refresh — the refresh came through the filtered door.
- **A hook on a getter is not a hook on the field.** `-bypassOnesie` forced to YES changed nothing (code reading the
  ivar never passes through the getter); writing it through `-setBypassOnesie:` did change the stored value and stopped
  the HLS manifest arriving. Instagram's `IGStorySeenStateUploader` declares three methods and reads `_networker` from the
  ivar, so "`-networker`: installed" beside "receipts blocked: 0" was truthful and meant nothing; 4.2.0 clears the
  field itself, found by **identity** (the ivar holding the object `init` was handed), not by name. TikTok's
  `AWEAwemeACLItem.watermarkType` is forced to zero **at its setter**, for the same reason. **"Installed" beside "0
  blocked" is a finding, not a contradiction.**
- **Prefer the object a hook is already handed over any search for the object.** Instagram's
  `-fullscreenSectionController:willDisplayStoryModel:` hands over the story model and fires on 410 and 439 while a
  list of story class names matched nothing on 439; TikTok's `-configWithModel:`. A candidate is validated against the
  three questions the downloader asks (the model may be the whole reel, not the item on screen), and the accessor is a
  ladder behind `respondsToSelector:` with **which one answered recorded**. A search is a fallback for when the name is
  unknown, never a replacement for a known one (the reels download button shipped broken in 4.1.0 after exactly that).
- **A capability check must ask the question the capability answers.** `hasPlayableVideo:` asked `getVideoUrl:` while
  the download behind it asked `getBestVideoUrl:`, which also parses the DASH manifest — a video whose only rendition
  lived there was refused by a test the download would have passed. **"Can I do this now" and "what is this" are
  different questions**: a repost's `IGMedia` is a stub (`IGRepostModel` carries a `mediaId` and no media object; the `IGMedia` is built with `-initWithPk:` and
  `-needsFetch`, `-needsMediaFetch` and `-coverPhotoDidPartiallyLoad` are its own accessors — the cover arrives before the renditions), its
  `NO` was read as "therefore a photo", and the cover was saved. Ask the kind separately (`mediaDeclaresVideo:` — duration, DASH manifest or `mediaTypeEnum`, any one sufficient).
  **A non-nil object is not a working object** (`IGMedia.video` is a hollow `IGVideo` for photo posts); when an object
  accessor comes back hollow, ask whether the raw dictionary still has it (a story's `video_versions` /
  `video_dash_manifest`).
- **A gate that cannot identify its target must fail toward not intercepting.** YouTube's `-hasOfflineButton`
  (`B16@0:8`) answers "which button is the download button" where every frame, subview index, icon enum and localised
  title has been wrong on some build — ask the class. **A correct principle enforced in the wrong place removes working
  features**: "saving the wrong video is worse than none" is right at the *save*; applied to the TikTok *button* it
  removed the button. Refuse at the irreversible action, never at the step deciding whether the user can reach it.
- **`%orig` is never captured in a block; the replacement is a replay** — raise a flag and re-send the same selector so the
  hook passes it through. And **a confirmation that cannot be presented lets the action through** ("ask me first" must
  never become "liking is broken").
- **Refuse the irreversible action, never the machinery.** Feeding nil into Watch's state machine
  (`-setUpdate:`, `-handleManagerState:update:error:`) crashed the app — nil-messaging is safe, the code after it is not.
  The hold refuses `-downloadAndInstall:` / `-install:` instead. And refusing an asynchronous call is not withholding its
  answer: a swallowed `-scanForUpdates` is a spinner that never stops, so the answer is replaced (`%orig` with a nil update).
- **Adding and removing are different operations, and a hook that works is evidence about the direction tested.**
  `-isExcludedFromTabBar` put Communities and Profile into X's bar but could not take Spaces out: it is consulted
  while composing the set of tabs X *could* show, so a saved bar wins; removal happens at `-setTabViews:` matching each
  `T1TabView` on `scribePage` (`audiospace`). **Ask which surface the user is looking at before choosing a lever** —
  "Hide Spaces" moved tabs for two releases while the complaint was the row of live rooms above Home.
  A switch answered 784 times and ignored is not the gate (`voice_rooms_consumption_enabled`;
  `ios_tab_bar_default_show_communities` was asked twice and `default` is the tell). Counter-on-the-wrong-path again:
  "no search history" emptied `TTSSearchTypeaheadViewController` while the row was drawn by its child
  `TTSRecentSearchTypeaheadViewController`, and a history is queries **and** users (`recentUsers`, `recentUserIDs`) —
  refuse the write (`-storeRecentSearchQuery:`, `-storeRecentSearchUserID:` — takes `q`, a long long, read from
  `v24@0:8q16`).
- **Two switches for one intention is a bug even when both work**, and adding features in bulk is how it happens (X 0.17.0:
  a blunt hide-every-`T1UserRecommendationView` switch beside a timeline filter that recognises the view model; a view-count
  feature beside a hide-the-button switch). Keep the half that knows what it is looking at, prefer answering the app's own
  question over hiding a view (a hidden button leaves its space; a count never drawn leaves nothing), and delete the
  preference with the row. **Named features and hand-set keys are two maps**: features contribute a map recomputed from
  scratch on every change, the hand-set map always wins, and turning a feature off is a recompute.
- **A limit enforced in two places is two limits, and they applied in the wrong order.** YouTube's tab bar holds six
  (`itemView1`…`itemView6` — structure, measured, not a number we chose); both our tabs were appended before the arranger
  ran and each refused at six, so History took the sixth slot while the `+` was still in the array. The cap belongs to
  whichever step also *removes*; **the intermediate count of an add-and-remove pass is not a real count.** A feature that
  adds an item to a fixed-size list belongs in the screen that manages the list, not in a switch beside it.
- **One container, two payload kinds**: `YTIPivotBarSupportedRenderers` holds a `pivotBarItemRenderer` *or* a
  `pivotBarIconOnlyItemRenderer` (the `+`); asking for the first returned nil, read as "no identifier". YouTube's
  `-yt_pivotBarItem` answers either. **A nil from a field lookup means the field is absent, never that the object is empty.**
- **A fallback that covers for a fault turns a bug into a cosmetic complaint.** YouTube's floating download button fired on
  *any* failure to build the tab, including 1.24.0's own bug, so "the downloads became separate" and "the tab is missing"
  were both true. Deleted, not narrowed. Ask of any fallback what it would look like if the primary path had a bug — and
  **whether it fires at all** (a refusal once promised "the video is being handed to you instead" while no share sheet was
  ever presented). A fallback only reachable when the primary succeeds is not a fallback (TikTok's JPEG re-encode needed
  `UIImage` to have decoded the bytes, which is exactly when it fails; `ImageIO` decodes what `UIImage` declines).
  A fallback for an unlikely case that becomes the path for the only case needs a counter (X's open-in-Safari read
  `valueForKey:@"initialURL"`, nil every time).
- **Where a feature is armed from is part of its gate.** YouTube's hold-to-save was armed below SponsorBlock's own
  preference check *and* below a `return` taken whenever a video id could not be read — dead for eleven releases for
  anyone with SponsorBlock off. **A gesture that cannot go missing can still be in the way**: YouTube puts hold-to-speed-up
  on the same picture and ours answered YES to simultaneous recognition. Placement robustness and placement correctness are
  different questions. (Hold-to-save was then replaced by YouTube's own download button, 1.26.0.)
- **Fixing a helper turns dead code live.** `SCISafeValueForKey` answered nil for every protobuf class until its fix, and
  `YTPivotBarView -setRenderer:` reads YouTube's items through it **while the bar is built during launch** — a block dead
  since written woke up and the app stopped launching. After changing shared code ask **what starts running that was not
  running before**, and grep the callers, not just the tests. The last thing changed is the first thing suspected, which was
  wrong here: an ordering by recency is a heuristic, the switch that isolates it is the evidence.

### 4.3 A tweak may cost a feature; it may not cost the app

- **The launch is the one part of a process a tweak must not be inside.** YouTube's tab bar is changed from
  `-setRenderer:` (called while the bar is built, with the watchdog counting). It is now applied on the first
  `didBecomeActive` by calling the same method again with the renderer it was handed — not for correctness but for
  *recoverability*: the same bug a second later costs a tab in front of somebody who can switch it off.
- **Work done on a layout path must be free the second time.** A launch that hangs with no crash is the signature of work that
  re-arms itself: `-topControls` (a getter YouTube calls while laying out) did `-bringSubviewToFront:`, two localised
  `stringWithFormat:` and a diagnostics write per call; a constraint constant was written from `-layoutSubviews` measured
  from the row the view sits in (so our change moved the measurement — writing a *child's frame* settles in one pass);
  `-setImage:forState:` invalidates layout even when the image is identical (compare against images held in statics, not an
  `NSCache` whose eviction restores the loop). `setNeedsLayout` inside `layoutSubviews` schedules the next pass rather than
  recursing, so the symptom is a main thread that never goes idle. First question for any hook on `-layoutSubviews`,
  `-didMoveToWindow` or a getter used by layout: what does it do on the second call?
- **The launch guard** watches for `didBecomeActive` and, eight seconds after the tweak loads, stands every expensive hook
  down for the session and says so on the diagnostics page; **its timer is on a background queue**, because a main-queue one
  cannot fire while the main thread is what is stuck. `make NOHOOKS=1` builds a YouTube dylib with no hooks at all, to
  separate a hook's installation from the dylib's mere presence. **A build that launches once has not fixed an intermittent
  fault** — the diff between a hanging and a launching build was diagnostic marks alone.
- **A cost proportional to data you do not control is a fault waiting for a quiet day.** `-description` on a protobuf is the
  whole subtree as text; YouTube's ad filter and diagnostics described every section on the first home response, on the main
  thread, while the logo was up, and the responses came from Google and grew. Described once, carried to diagnostics, with a
  120 ms budget per batch past which the rest passes unexamined and the report counts how many.
- **A list of layout names is a list of the ads that already got through** (`video_display_carousel_button_group_layout`;
  the ad returned as `video_display_button_group_layout`). Prefer what the server attaches to something it charges for
  (`ad_slot_logging_data` beside `slot_data { type: SLOT_TYPE_IN_FEED }`) — **and measure it before trusting it**: 0.20.1
  emptied the home feed with a substring that was too broad; the marker matched one section in sixty-six.

### 4.4 Diagnostics

- **A diagnostic that reports the last event instead of a tally is not a diagnostic.** TikTok's `+lastAttemptState` read
  `every chain failed — -video answered nil` for three releases while resolution worked (it runs on every feed model, most
  asked before video data is populated) — two releases chased selector names that were already right. **Count attempts and
  successes separately, name the chain that won, and show the last failure only while nothing has succeeded. When a report and
  an observable behaviour disagree, suspect the report**, and read every number for whether it is a tally or a snapshot.
- **Count the thing that is supposed to have happened, not only its result.** An install-attempt count of **zero** exposed
  YouTube Music's download installer, commented out since 0.8.4 as a crash suspect and never un-commented after the real cause
  (an `iconType` the app has no case for) was fixed — every later report was internally consistent and described code that
  could not run. **A feature suspended as a suspect must be returned to duty when it is cleared.** Constructions counted as
  views are built answer "is the class live" with nobody tapping.
- **A diagnostic is not what a variable holds, it is what reaches the page.** Setting a state is not reporting it; a counter
  written out only on the success branch moved a number nobody could read (YouTube's tap hook); a record written into another
  feature's slot (the save button recorded through the SponsorBlock marker line) hid a surface for eight releases; a report
  written once from `%ctor` contains only launch-time counters (Watch). **A counter on a path that is not the path** reads
  working code as broken (TikTok's watermark counter sat on the setter; the getter did the work) and broken code as working.
  Before believing a zero, check the counter sits on the path that executes.
- **A copyable report and the screen it mirrors are two lists**, and a row added to one is silently absent from the other
  (TikTok's gear ladder went into the table; the report the user sent never had it). Anything added to one belongs in both.
- **A diagnostic that does not date itself will be read as current** — TikTok's "last save attempt" carried the identical byte
  count across three reports and nothing had happened at all. Print state from the object that kept it, not from the last thing
  that touched a global; a row set by every call describes no call (commit on success only).
- **Blank is not wrong, and "blank" names a stage.** `Last download treated as: —` proved the Instagram downloader was never
  entered (it records a kind on *every* branch) — nobody had suspected that stage. "Saved 0 of 1" is a count, not a cause:
  count the download, the decode and the library refusal separately and keep the first real error. A quality number is not a
  diagnosis ("it saves 720" has two causes): report every gear offered with the chosen one marked. A description of a fault is
  evidence; **a picture of it is proof** (X's mirrored post-to-image: ask for the artefact before theorising).
- **A diagnostic that writes itself is a cost paid by every phone for a fault almost nobody has.** YouTube's report was rebuilt
  in full and written at every launch, every launch milestone, every captured video and every feed batch. **A report is
  written when somebody asks** (Settings › General), plus the one case it exists for: the launch guard tripping. Audit rule for
  any new diagnostic: *what writes it, and how often?* Every file that can be written has a ceiling and says so inside itself
  when hit (1 MB for reports; NextUp's log **128 KB per process**, because seven processes write one file each and the total
  is the number that matters). `NSLog` is a line per event in the system log, so per-event ones sit behind a switch that is
  off by default (Spotify's did not). A diagnostic must also be **free on the path it is watching** (the launch trail took a
  lock on every mark of a hook that runs thousands of times; it is one atomic read now).
- **A diagnostic that fails in SpringBoard takes the device down.** Watch's domain probe sent messages to private classes
  inside SpringBoard and one branch trusted `-copyKeyList` to return an array by its name — an unrecognised selector there
  is a phone that will not boot to a home screen. Such probes are **off unless switched on** and do not switch themselves off
  (a switch that resets itself is a switch that lies).
- **Fixing a pipeline starts by measuring each stage.** The quality picker was fixed three times against the wrong stage; the
  bug surfaced once it reported `raw → parsed → deduped`. A filter loop that only adds from inside itself cannot be asked for
  "everything" — an optional predicate needs the empty case written (the accessor dumper returned nothing for an empty keyword
  list, which reads as "no accessors").
- **A ceiling measured on one model is a measurement of that model.** (YouTube Music's translation cap was 8192 from a bill with no
  thinking in it; Opus 5 thinks by default and Opus 5.5 always does, and thinking counts toward `max_tokens` — it is 32000.)

### 4.5 Layout, UI and right-to-left

- **A recycled cell is never removed from its window**, so `-didMoveToWindow` fires once for its whole life. X's buttons
  appeared on the first screenful and nowhere after. The bind point (`-setViewModel:`, `-configureWithViewModel:…`,
  TikTok's `-configWithModel:`) fires on first use and every reuse; keep `-didMoveToWindow` only as a fallback. A badge or
  button is toggled (built once), and placed in `-layoutSubviews` **only when its frame moved**.
- **A constraint built from `bounds` at construction time is built from zero**; an autoresizing mask applied while a bubble is
  zero wide keeps the badge outside it for good; an autoresizing mask measures against the superview's bounds, which move on a
  scroll view (a `PSListController`'s view *is* its table) — four-edge constraints work on every surface.
- **A button placed beside somebody else's is placed by their numbers, and each is a way to be wrong.** Anchor to the control
  that *changes*, take size only from a real `UIButton` of plausible size (not a 96-point container), convert every frame into
  the coordinate space you are placing in, and write it on the signals the overlay actually re-lays out on. **Write
  "leading/trailing", never "left/right"** (UIKit mirrors the row in RTL; use `effectiveUserInterfaceLayoutDirection` of the
  measured view). A button the user places is stored as **two fractions of the room it has**, clamped everywhere, never
  points (X's draggable save button: 2,879 harness checks, and a mutant with the clamp removed fails thirteen); a layout pass
  never moves it while a finger is on it; a pan's translation starts at *recognition* (~10 pt in), so follow from the
  touch-down point; `-shouldBeRequiredToFailByGestureRecognizer:` YES for *every* recogniser made drag and tap wait for each
  other (YES only for recognisers on other views). Index 0 of a container is the one position that requires nothing to be true
  about its contents (searching "after the last interaction view" is as many positions as the container has shapes).
- **A button added to an arranged-subview stack is swept out when the app rebuilds it** — a rising add-count with nothing on
  screen is the signature (X's `ImmersiveActionsStackView`: eleven adds, never visible). Suspect the container rebuilding its
  children, not that placement is nearly working. Prefer a surface that lays out by hand (X's
  `TTAStatusInlineActionsView` — drawn under a timeline post *and* over a playing video), a frame this code owns (TikTok's
  cell, not its rails), or — best — **adding a renderer, not a view**: YouTube's action row, tab bar and pivot items are
  built by YouTube itself from protobuf entries (`YTISlimMetadataButtonSupportedRenderers…buttonRenderer` →
  `YTIButtonRenderer{text, targetId, icon}`), so metrics, collapse and scrolling are the app's; `targetId` makes the tap
  unambiguous (a string this project wrote, not a localised label). The icon is still painted afterwards because `YTIIcon`'s
  enum is not readable from the binary. **A view in an array is not a view in a hierarchy** (a button appended to what
  `-topControls` returns had no superview; the report said "made and handed to its layout" — counting creation is not
  counting placement).
- **The safe area describes the device, never the app's own bars.** YouTube Music's Downloads heading vanished under the app's
  header; measure the app's chrome off the views by shape and take whichever ends lower. When the **third fix for one symptom
  is the same kind of fix, change what you are adjusting** (five `contentInset` fixes undone; a plain controller with a table
  *inside* gave a frame to place). `UITableViewAutomaticDimension` does nothing without `estimatedRowHeight` — TikTok's rows
  overlapped without it, and YouTube Music's added line simply never appeared (same missing property, opposite symptom).
  A scroll view has no height of its own (pinning content to its edges sets `contentSize` only — a card collapsed to an empty
  box until the scroller asked to match its content at less-than-required priority). Take the surface you already have (the
  presenting controller) — `keyWindow` is not something to search for inside Settings, and a lookup that fails quietly is worse
  than one that throws.
- **Settings screens:** a registry, not indices — a row carries its own title, key and action, a section's length is
  `rows.count`, sections register in `+load` (X's five section constants, seven row constants and a `switch` per section crashed
  the YouTube Music screen when a fourth list was added); a control that governs what is below it belongs above it; a section
  that builds no rows is not drawn. A `PSListController` that overrides `-specifiers` must assign `_specifiers` itself (the page opened black otherwise); a radio group is `PSSwitchCell` rows, not a `PSListItemsController` picker (a private class never confirmed to compile against the pinned SDK — this project does not ship a guess at private API it has not built once); a
  specifier list is **edited** (`-setProperty:forKey:` + `-reloadSpecifier:`), never rebuilt or removed from; a
  `PSTitleValueCell` asks for its value through the get selector (rule 24); `cellClass` takes a Class, not a string. Fourteen
  diagnostic rows among six switches is two screens interleaved — diagnostics sit one row away. A system `UIAlertController`
  over TikTok's feed reads as an error from the app; the tweak's own sheet (`SCITTSheet`, a view in the key window) makes a
  question look deliberate. A control that cannot help a user and can only confuse one is not worth its row.
- **Right-to-left is layout, and several bugs exist only on an Arabic phone.** Rendering a view into an image context
  re-lays it out with no window and no traits, so it resolves left-to-right (`-drawViewHierarchyInRect:afterScreenUpdates:YES` asks for that re-layout by definition, `-renderInContext:` does not; the BOOL the `NO` form returns was being discarded): X's post-to-image came out LTR *and* with the
  photograph mirrored (`@SaudiDCD` read `DCDibuaS@`) — UIKit mirrors with a transform that `-renderInContext:` does not
  apply, bitmaps are stored pre-mirrored; the correction is measured (convert two bounds points to window coordinates), so a
  build that stops mirroring gets none. A Latin run and a date on one Arabic line merge into nonsense (bidi reads the id and
  digits as one LTR run) — `SCIRun()` wraps in FSI…PDI; `NSDateFormatter` follows the **system locale** while a screen chooses
  its language from `preferredLanguages` — two settings, so tell the formatter and wrap date and count. A Latin field on an
  Arabic phone lays out RTL and a pasted token reads back reversed — force LTR on every field but a name. **A localisation
  list is a layout decision**: declaring `CFBundleLocalizations` as `ar, en` made an English phone lay the whole app out RTL.
- **A UI bug reported in words is a UI bug being guessed at.** Compile the pages into a throwaway simulator app and look: the
  licence plans card (collapsed scroller), the admin app's seven screens (six faults), the redesigned licence screen (cards the
  same white as the background, a date in two numbering systems) all answered in one look. The simulator is the cheapest tool
  here for anything drawn on a screen.
- **Zero means different things**: a licence's `until = 0` is lifetime, a last-seen of 0 is *never seen* (a shared formatter
  printed ∞ for both). A sentinel needs **one function that understands it** (`isLive`, `isLifetime`, `termOrder`) — three
  places compared one field and one was fixed ("0 valid of 3" on a panel of lifetime licences). Absent keeps, empty clears
  (`body.x === undefined ? existing : clean(body.x)`, not `|| existing`). **When a field appears twice, the editor and the
  display are one change** (an editor wrote `note` while the row drew `name || note`: a save that works and looks discarded).
  An absence answers nothing: the free-week row, hidden once a licence existed, read as a broken button — grey it and give
  the reason. A control that cannot do anything is not drawn (no contact number → no paid rows).

### 4.6 Preferences, sandboxes, identity

- **A sandboxed app asking cfprefsd for another application's domain is answered with nothing, not an error**, and a sandboxed
  *write* is **redirected into the app's own container and reads back perfectly** — so "did my write come back" verifies the
  wrong thing (Watch's report, the licence identity). The plist is read directly (`SCIPanelGate`), CFPreferences tried first;
  the jailbreak prefix comes from `dladdr` on this code's own address (the only way on roothide, where it is a different random
  directory per device); `SCIPanelIsInstalled()` reads the panel's own preference **file**. The report travels as a file the
  sandboxed app writes in its own container and SpringBoard copies into the shared domain.
- **A path derived from where a file *used to* be installed is a guess; the package answers it.** NextUp's libSandy fallback
  searched its own path for `/usr/lib/` (upstream stages into `<jbroot>/usr/lib/TweakInject/`); Theos stages this package into
  `<jbroot>/Library/MobileSubstrate/DynamicLibraries/`, so every lookup was denied — readable from this machine by unpacking
  the published `.deb`. A ported tweak inherits its upstream's assumptions about its installed layout, and the same
  derivation existed twice with only one copy right (a comment claiming two things match is not a check that they do).
- **The per-app switch is opt-in: absence reads as *off*.** `com.albrhi` carries five app tweaks, so reading silence as
  consent would modify apps the install never asked about; nothing is patched until asked, and the panel footer says so. The
  master switch defaults **on** (that answers "has the user pulled the handle"). Value lives in the panel's plist (dpkg leaves it
  alone on upgrade). Three places answer `app_enabled_<bundleid>` in three processes — `SCIPanelGate`, `SCIPanelRoot
  -isOnForSpecifier:`, and a tweak's own detail page — grep it before changing the default; sub-feature keys stay
  default-on because they sit inside a tweak already opted into. A tweak whose shape is not one-tweak-one-app uses its own master
  switch as the gate (Watch refused forever because the question had no answer), and the panel's `SCIPanelGroup*` keys collapse
  a multi-process filter to **one row**; `SCIPanelHidden` in a filter says "not Albrhi's page" (without it `SCIPanelScan` draws
  a row per process — "SpringBoard", "Music", "Spotify").
- **`SCI_SELFCONTAINED` builds answer the gate differently**: a standalone dylib injected into an IPA has no panel (a
  jailbreak package), so its switch could never be turned on and the opt-in reading would refuse forever — every hook standing
  down on every launch, which a real report of "nothing works, not even the welcome screen" turned out to be. It answers YES and
  asks nothing. `SCIPanelAllowsThisApp()` is otherwise answered once and kept (a cross-process preference read on a layout or
  playback path would show), so a changed switch takes effect when the app is next launched, which the panel says.
- **A device identity read from the hardware is entitlement-gated per process** (`MGCopyAnswer("SerialNumber")`: Settings sees it,
  a sandboxed app does not — one phone computed two fingerprints). It was learned building the licence layer; nothing here
  reads such an identity any more, and a feature that wants one should expect the same.
- **A page that ships in another package is missing whenever that package is not.** NextUp and Watch have their own preference
  bundle and Settings row (a Theos `SUBPROJECTS` bundle; a space-separated `TWEAK_NAME` builds two dylibs, not a bundle), with
  `src/Settings` pruned from the dylib's `find`. Nothing needed migrating because both already wrote into their own domains
  (`com.yves.nextup3`, `com.albrhi.watch`) — the coupling was the bundle, not the data. Shared furniture lives in
  `shared/src/Prefs/`, compiled by every bundle from one place.

### 4.7 Toolchain, Logos, Theos and shell gotchas

- **Logos `%orig`** must sit alone on its own line inside a full block (`if (x) { %orig; return; }` breaks). With a `%group`,
  `%init` is needed. A hooked class needs an `@interface` if you touch its properties or send it any message. **A `%new`
  method's parameter type is pasted into `@encode()`**, so `__unused` there is a `-Werror` failure (rule 19).
- **`FINALPACKAGE=1`** is set in `build.sh`; without it every published build carried debug symbols and a `-1+debug` suffix.
- **Rootless and roothide have separate identities**; `build.sh <tweak> roothide` swaps the id/name **derived from that tweak's own
  `control`** (matching literal ids with `sed` silently does nothing for a second tweak) and restores them via a `trap`.
- **A space-separated `TWEAK_NAME` builds two binaries; `$(TWEAK_NAME)_FILES +=` builds one badly-named variable** — use
  `$(foreach T,$(TWEAK_NAME),$(eval $(T)_FILES += …))`, **with a literal trailing space before the closing paren** (rule 9 reads
  `-I(\S+)` and `-I$(ROOT))` swallowed the paren into every include root). **A tab in column one of a makefile is always an
  attempted recipe** — it went unnoticed because neither `SIDELOAD` nor `SELFCONTAINED` is set by an ordinary build, and
  tripped on the first sideload CI step.
- **Swift/Orion** (Spotify): `orion_init()` is not called for you (the first build linked, loaded and installed zero hooks;
  without a constructor the dylib has no `__init_offsets` section); `-runtime-compatibility-version none` or it does not link
  (a force-load of `swiftCompatibility56` the pinned 16.2 SDK lacks); **SwiftUI cannot be compiled against that SDK** (its
  `.swiftinterface` is Swift 5.7.1, the toolchain 6.3.3 refuses to rebuild it — any ported SwiftUI file is out); **a missing
  `-D ROOTHIDE` chose a different code path** (a conditional compiled out is not one you can see — read upstream's makefile);
  ungrouped hooks activate at startup before any gate (the clean-share-link crash: eleven of fourteen hooks named a group, the
  three that did not were the whole fault — count the hooks against the groups).
- **An XML comment cannot contain `--`** (rule 18) — verify a `.plist` edit with `plistlib`. `control` descriptions cannot leave
  a parenthesis open at a line end (rule 20). A maintainer script's executable bit is read from the git index (rule 21): this
  repository was developed on Windows once, where `chmod +x` is a silent no-op.
- **Never write shell/Python heredocs containing `\n` inside string literals** — the escape becomes a real newline and Objective-C
  has no multi-line strings (it corrupted source files five times, once in the commit adding the rule). Use the editing tools for
  source; if a script must, `assert` every substitution **and re-read the file** — a half-applied script prints its success line
  anyway (once the header landed without the implementation; once `CLAUDE.md` stayed untouched while the commit claimed it had
  changed). **Run scripts before shipping them**: three CI failures in a row were shell one-liners never executed once locally.
- **A jailbreak-detection bypass hooks the primitives a detector calls, not the detector** (Shadow-shaped: `%hookf` on
  `stat`/`lstat`/`access`/`fopen`, `-[NSFileManager fileExistsAtPath:]`, `-canOpenURL:`, `getenv`, each lying only for a real probe,
  path list anchored at the start — never a substring match on "cydia"). `open` is left unhooked (variadic: a two-arg hook drops the
  mode on every real `O_CREAT`). Every hook is grouped and `%init`-ed from the `%ctor` after the panel gate, so "off" means no hooks.
- **A comment that was right when written is not a check that it still is.** (Watch's gate comment said SpringBoard is not sandboxed —
  true of SpringBoard; the tweak had stopped being only SpringBoard three releases earlier.) **A provider flag one implementer ignores
  is a feature off for that provider** — grep every implementer of a protocol parameter, not the one being edited (YouTube Music's
  `expectJSONMode` became `json_object` for OpenAI and `responseMimeType` for Gemini but was ignored by the Anthropic client, whose Messages API has only `output_config.format` with a schema; callers now pass a schema through `YTMULLMCompleteJSON`, sent to Anthropic's own
  host only because the base URL is user-configurable, and the tolerant parser stays while any path reaches it). Prompts that shout ten
  times in twenty lines say nothing ten times; what stays is the guidance only the author knows and "never write or complete lyrics".

---

## 5. Per-app knowledge

What is true of each app and tweak that is not derivable from reading the code. Sections 4 and 6 hold the rules these
instances taught; here are the facts.

### 5.1 Instagram (`tweaks/instagram`)

- **Do not guess at class names.** A class dump says what *exists*, not what the app *renders*; two features were "fixed"
  repeatedly against classes never instantiated. **Settings → Diagnostics** reports what attached at runtime, its magnifier scans
  the live view hierarchy, its speech-bubble files a GitHub issue with the whole report — use it before writing a hook. Instagram is
  the one tweak still written the old way (hooks installed whether or not the method exists); the newer tweaks read the real type
  encoding off the device first and stand down on a mismatch. 4.2.0 attaches each of its new hooks that way, counts it and lists the
  absent ones.
- **Downloads** go through `SCIMediaDownloader` only. A reel item's `IGVideo` is a hollow shell (`hasPlayableVideo:` NO), and a story's real
  renditions live in its API dictionary (`video_versions`, `video_dash_manifest`; `+mediaDictionary:` / `+videoURLFromMediaDict:`,
  read through the existing ladder parser so AV1 still goes to the transcoder); the dictionary path runs *after* the object path
  fails, so nothing that downloads today can change. The story search is the story model handed to
  `-fullscreenSectionController:willDisplayStoryModel:` (a list of `IGStoryModernVideoView`/`IGStoryPhotoView` matched nothing on 439 while a same-generation reference still names them), then a widened view search that records every story-named class whether it
  answered or not. AV1 is decoded on the device with dav1d (`build-dav1d.yml`), HDR kept.
- **Story-seen hiding** (4.2.0) clears `IGStorySeenStateUploader`'s `_networker` field itself and restores it for the eye button;
  confirmed on 439 by the report saying `-networker: installed` beside `receipts blocked: 0` — which was truthful (§4.2).
- **Keep unsent messages** works on 410 (4.2.1: `3 · reason 0`) by emptying the removal before Instagram applies it: the removal
  arrives inside `IGDirectCacheThreadUpdate` (field `threadUpdates`; key `IGDirectMessageUpdateMessageKey { _subtype,
  _messageServerId, _messageClientContext }`). It is **marked** (4.2.2): a red trash badge placed from
  `IGDirectMessageCell -configureWithViewModel:ringViewSpecFactory:launcherSet:` (the reuse-safe bind point) by joining the held
  key's `_messageServerId` with the drawn cell's `viewModel.messageMetadata.key.serverId`. InstaPlus's six selectors do not exist in
  410; Regram 6.3 was read for architecture only. **A refresh removes them** (a pull-to-refresh reloads from the server), so 4.3.0 *asks first* — always while any are
  held, otherwise only with the `refresh_chats_confirm` switch — by hooking `IGDirectInboxViewController`'s `-_pullToRefreshIfPossible` (410) **and** `-pullToRefreshIfPossible`
  (newer; the warning had never fired on 410 because it was hooked on the wrong spelling), replaying the selector on confirm and ending the pull on cancel through
  `-refreshControlDidEndFinishLoadingAnimation:`; the duplicate-pull guard expires after ten seconds so a sheet that never presented cannot block refreshing for good.
  Unconfirmed whether that selector is ever called by something other than the user's pull (the inbox's `refreshControl:didReleaseWithRefreshControlState:` is an empty
  stub in 410) — the report counts which spelling fired and how many asks. **Not built:** hiding the reels *seen* mark (`/api/v1/clips/write_seen_state` still goes out).
- **The deleted-messages log** (4.4.0, `SCIUnsentLog`, screen `SCIUnsentLogViewController` under Messages) writes a row per held unsend — what was said, sender, sent and
  deleted time — to one bounded JSON file (600 rows, 768 KB) in Application Support. **The unsend arrives as a key with no text**, so text comes from remembering every message
  that passes through the same stream: `IGDirectMessageUpdate`'s `_insertMessages` and `_replaceMessages_messages`, read by ivar inside `SCIDefuseMessageUpdate` (memory only,
  2,500 messages, never written). Two shapes are understood because the stream's element class was **not** known from the binary: a typed UI message (`IGDirectText`: `-text`,
  `.message` → `IGDirectUIMessage` → `.metadata` → `.key.serverId`) and a published message (`IGDirectPublishedMessage`: `.metadata.serverId` / `.clientContext` /
  `.serverTimestamp`, `.content` whose variant ivars `_text_string`, `_media`, … name the case). `IGDirectUIMessage` is a generated model: its fields (`metadata`,
  `quotedMessage`, `reactions`, …) were read by following `+internal_classInfo` to its table, not by guessing. Names come from `IGDirectThreadMetadata.users` as it passes
  (`_replaceThreadMetadata` on `IGDirectThreadUpdate`); unknown senders show their id. **A message that arrived before the launch and never replayed through the stream is logged
  without content and says so.** The first report's `insert element` line names the real element class — if rows have no text, that line is the next round. Not logged: the
  newer MSYS delete path (`deleteMessageDelta`), which is held back but has no row yet. 17 host tests: `bash tweaks/instagram/tests/host/run.sh` (mocks both shapes; cannot say which one
  Instagram really sends).
- **Reels auto-advance** forces every gate a build has, each behind `class_getInstanceMethod`: `-isAutoAdvanceEnabled` and
  `-autoAdvanceToNextItem` on both, `-shouldForceEnableAutoScroll` on the Swift `IGSundialAutoScroll` in 439 only, `-autoScrollState`
  in 410 only. Hidden for a long time because the old hook forced the 410-only getter and left the shared gate alone — established by
  counting selectors in the real binaries, which is why both IPAs are kept.
- **Measured against the decrypted 410.1.0 binary (4.6.0)** — `com.burbn.instagram_410.1.0_decrypted.ipa` is in iCloud Drive › Downloads (35,954 classes; `objc-classes.py --dump` 14 s):
  `tools/objc-diff.py --check` over this tweak found 8 hooks on selectors no class in the chain declares and 34 on classes 410 lacks. **Most are intentional per-version signatures** with a sibling that covers 410
  (`_applyThreadUpdates:` has three; ad hiding goes through `parsedObjectFromResponse:`, present in 410). Two were real and are fixed: **"disable view-once limitations" attached nowhere on 410**
  (`IGDirectVisualMessage` has no `-viewMode`; the value is `IGDirectPublishedMessageVisualMediaInfo -viewMode`, `q16@0:8`) and **the DM recipient recent-search storage has another initialiser in 410**
  (`initWithDiskManager:directRepo:userMap:currentUser:launcherSet:`). Both are installed behind a check that the class declares exactly that selector; **neither has run on a device.** A parser lesson: a
  Logos declaration wrapped over ten lines is one selector, not its first line (the first version of the check cried wolf eleven times on exactly that).
- **Link tracking (4.6.0)** — `strip_link_tracking`, off: `igsh`/`igshid`/`utm_*`/`fbclid`/`ig_rid` removed from Instagram's own addresses at the two doors a link leaves through
  (`UIPasteboard setURL:/setString:`, `UIActivityViewController`), so no Instagram class is involved. **Clean cache** keeps `albrhi-*` and every `<UUID>.<ext>` in Caches, because that folder also holds the
  download history and the finished downloads (found by reading where `SCIDownloadQueue` writes before writing the cleaner). 16 + 14 host tests.
- **Copy by long-press (4.7.6) — each attempt was fixed by the report of the one before, not by a better guess.** 4.7.1 put a recogniser on each `IGCoreTextView` and nothing copied; 4.7.2 moved it to the window (one per key
  `UIWindow`, the view found by walking the tree for an `IGCoreTextView` whose **frame** holds the point, because the class overrides `-pointInside:withEvent:`) and still copied nothing, but its ledger (Diagnostics, "Copy text by
  long-press": windows, presses, copies, misses **with the class chain under the finger**) said why in one report: every miss was `kept out by the exclusion list — IGCoreTextView ← UIView ← IGFeedItemTextCell`. The exclusion check
  walked **16 responders up** into Instagram's tab bar controller (`TabBar` is an excluded word); it now checks only the views around the text, up to its cell (`SCIOwnersOf`). **The harness had no tab bar controller above the list,
  which is why 4.7.2 "passed" there**: it has one now, and the old code was run first to reproduce the refusal. 4.7.3 copied captions on 410 **with the account name in front** (a feed caption is one string `<account> <text>`).
  4.7.4's rule — drop the first styled run when its font is clearly heavier than the next — **did nothing**, and the report said why: the 410 runs are `[0+6 w0.40 link][6+1 w0.40][7+69 w0.00]`, the account **and the space after it**
  are two heavy runs. 4.7.5 takes every consecutive run as heavy as the first (`SCILeadingNameLength`, first run ≥ 0.2) up to the first lighter one; whether a prefix is a plausible name is `SCICopyDropLeadingName` (host-tested; no
  whitespace inside it, a separator after it, something left). The harness now builds the string with that run shape.
  **Comments, third attempt (4.7.6, corrected in 4.7.7): take the text from the model, not from whatever draws it.** The 4.7.4 miss was `IGWindow@0→UIDimmingView` (the hit test at a comment is the sheet's dimming view). 4.7.5 searched the window
  **by position** for any text-drawing view and the report showed what that gets you: `_UITableViewHeaderFooterViewLabel`, 86 characters — a header label, not the comment (its text view is a Swift lazy var,
  `IGCommentCellContentView.commentTextView`, whose type ObjC cannot name). The model is ObjC: `IGCommentCell -bindViewModel:` (`v24@0:8@16`) is hooked, the model's text is read
  through `SCISafeValueForKey` and kept on the cell; at the press the comment cell is found **by position** (`SCICommentCellAt`, front to back, class name holds `IGComment`) and that text is copied, before any text-view search; a
  press on a `UIControl` inside the cell (the like button) copies nothing. The ledger line `comment cells bound: N (with text: M) · model class: X` says whether the hook ever ran (N), and whether the model had the shape
  assumed (M, X). **The first guess at the model was wrong, and the ledger line said so in one report** (4.7.6: `comment cells bound: 4 (with text: 0) · model class: IGCommentModel`): 410 hands `-bindViewModel:` an `IGCommentModel`, whose text is `text`; `commentText` is on the section view model, which is not what arrives. 4.7.7 reads `text`, then `commentText`, then `comment.text` (`SCICommentTextOf`), and the harness now uses a class named `IGCommentModel` with only `text`. **4.7.7 still copied the header label** (`comment cells bound: 6 (with text: 6)`, one press, `found by position under a dimming view`): the model was right and the cell was not found at the press.
  Reading: `IGCommentCell` has a `contextMenuDelegate`, so Instagram's own long-press on a comment (a context menu) puts a dimming view over everything *before our half second is up* and hides the view it lifts into the preview; a hit test
  then answers with the dimming view, a by-position search skips the hidden cell, and the nearest visible text is the menu's own table header. **That is an inference, not a measurement** — but it is reproduced in the harness (`-menu`:
  a dimming view after 0.25 s and the pressed cell hidden) where the 4.7.7 code copied nothing. 4.7.8 does not depend on it: `-gestureRecognizer:shouldReceiveTouch:` records the view the finger landed on **at touch-down**
  (`SCICopyTarget.touchDownView`), the comment cell is reached by climbing from that view, and a `UIControl` on the way (the like button) means no copy; by-position search is only the fallback when no touch-down view exists.
  Instagram's own menu still opens; the copy happens beside it.
  **4.7.8 copied nothing either, and its report moved the problem a step earlier than every fix so far:** `long-presses seen: 1`, that one on `IGTabBarButton`, with `comment cells bound: 5 (with text: 4)`. The comment presses never
  reached the window recognizer at all, so 4.7.5–4.7.8 were all repairs to a step that did not happen. Something inside the comments (most likely the comment's own context-menu gesture) takes the touch before a window recognizer
  can finish; **the cause is an inference**, but it is reproduced in the harness (`-menu -block`: a second recogniser with `cancelsTouchesInView` and a delegate refusing simultaneous recognition) where the 4.7.8 code saw
  `presses 0`. 4.7.9 therefore also **follows the touch itself** from `-[UIWindow sendEvent:]` (`SCICopyObserveTouches`, before `%orig`, only on windows the recognizer was attached to): a half-second timer from the touch-down,
  stopped by lift-off, a move over 12 pt, a second finger or a system cancel, each counted. Both ways call one `SCICopyHandlePress`, which ignores a second press within 1.5 s and 30 pt, so a screen where both work copies once.
  The ledger says which noticed it (`noticed by: recognizer N · touch timer M`) and what became of the touches (`touches followed … lifted early … moved away … cancelled by the system`). **Unverified:** that `touch.phase` seen in
  `sendEvent:` before `%orig` is the hardware's and not already cancelled when Instagram's menu starts; if it is cancelled, the last counter says so. **Lesson for this feature: when a fix does nothing, count the stage before it
  (did the press arrive?) before refining the stage after it** — the ledger had `long-presses seen` from 4.7.2 and it was read for the wrong number until the seventh report. **4.7.9 worked on the owner's phone** (copy of a caption and of a comment, "اشتغل النسخ حلو جدا"), and his screenshot of the comment menu (Reply with a reel, Add to story, Share, Report, Block) showed what to do next:
  **4.8.0 adds Copy to that menu** instead of copying by itself on a comment. The menu is built in Swift (`_TtC19IGCommentActionMenu19IGCommentActionMenu`, `-config` lazy) and its `UIContextMenuInteractionDelegate` is in no
  Objective-C method list, so nothing of Instagram's is hooked: `UIContextMenuConfiguration +configurationWithIdentifier:previewProvider:actionProvider:` is the one factory a Swift `UIContextMenuConfiguration(...)` reaches,
  and `SCICopyWrapProvider` wraps the provider only when the touch that opened the menu (`sciTouchView`, ≤ 3 s old, no `UIControl` on the way) landed on an `IGComment*` cell with remembered text; the action goes first
  (`menuByReplacingChildren:`). While the button is on offer (2 s), the by-itself copy for comments stays quiet (`press left to the button`), and is the fallback if the hook never fires. Captions have no menu and still copy on press.
  Ledger: `context menus built · Copy button added · tapped · press left to the button`. **Not seen on a device**; the harness builds the configuration through `SCICopyWrapProvider` because the Logos hook is not in the cut source.
  **4.8.1: a long press on a post's buttons copied nearby text** (the owner: the share button, "غلط هيك"). The 14 pt slack that finds text for a finger that missed it also reaches the like count and the caption, which sit a thumb's
  width from the action bar. A press that is not on text and lands on a `UIControl`, or on a view whose class holds `Button` or `UFI`, now copies nothing (`pressed on a control` / `pressed on a button or the action bar` in the ledger);
  `UFI` joined `SCICopyOffered`'s words, so text inside the action bar is excluded as well. Reproduced first in the harness with a `UIButton` and a plain `IGSocialUFIButtonView` under a caption (old code copied the caption from both).
  The real class names in 410's bar were not measured beyond what the report listed (`IGUFIButtonWithCountsView`, `IGSocialUFIView`, `IGUFIInteractionCountsView`).
   `IGCommentCell` is not in 450.1.0 under that name, so there the
  hook is inert and only the by-position search remains. The by-position text search under a dimming view is kept as the fallback; the 4.7.5 caption fix (heavy prefix) is separate and **not yet seen working on a device**: the 4.7.5 report's last copy was the header label, not a caption, and the owner did not say whether the account name was gone.
- **Removed in 3.1.4** (broken or redundant): liquid glass, teen icons, doom-scrolling limits, per-surface download toggles,
  long-press tuning, quality picker. Keep-deleted-messages came back as `keep_unsent_messages`. Do not reintroduce without a reason.
- **Known upstream crash, not ours:** on roothide Bootstrap, Instagram 442+ crashes when the profile picture is changed. Cut in half
  repeatedly — every feature removed, every hook installed with every setting false, **a one-file dylib that only logs a line** all
  crash; the same tweak merged by hand into the app does not. The loader is the cause; four releases of real fixes on that screen
  (a KVC probe running on every menu, a held reference to an Instagram object, an ivar read by name, sixteen list hooks rebuilding
  arrays) were each right and the crash was indifferent. Workaround: turn Albrhi off for Instagram while changing a picture.
- Date and time formats, OLED theme, accent colour, follow-back badge (`SCISafeValueForKey` with one confirmed selector, guarded),
  backup/restore, searchable settings: working. Settings open by **holding ☰** on the profile (or the home tab with quick-access on).

### 5.2 YouTube (`tweaks/youtube`)

**Downloading — three layers of history, one current design.**

- **SABR cannot be turned off from inside the app. Measured to the end — do not try again without new evidence.** Every format on
  21.30.5 answers with an empty `?cpn=` URL because the client asks a server-side controller for byte ranges. Two gates look like the
  answer and are not: `MLPlayerReloadContext -disableSABR` is never consulted on a first load; `MLOnesieRequestContext -bypassOnesie` is
  consulted 3–4 times per playback and forcing the getter, then the stored value via `-setBypassOnesie:`, still yielded 22 formats with
  no URLs *and stopped the HLS manifest arriving*. `content_length`, `init_range` and `index_range` arrive complete and only the URL is
  withheld — a server-side choice about which clients get plain files. Counting hooks stay in `SCIYTSabr.x`; the switch went in 1.12.0.
- **The direct route (1.34.0, `SCIYTDirect`, method from YTKACE, MIT) is first and confirmed on the owner's phone.** `VISIONOS` 1.02
  against `youtubei.googleapis.com`, `/guide` for a visitor id (cached a week), `/player` as JSON; **anonymous — no cookie, no account**
  (an earlier remark here that it risked the account was made without reading what the request carried). Only H.264 ≤1080p
  (`video/mp4`, `avc1`; **plus AV1 above 1080p behind `SCIPrefOffer4K`, off — see below**) and AAC LC (`mp4a.40.2`, not `isDrc`, default `audioTrack`) are offered — 1440p/4K are VP9/AV1 and would save and
  not play; `mp4a.40.5` is skipped. One entry per height, highest bitrate (the 60 fps copy where there is one). A chunk is the plain URL
  plus `&range=A-B` (8 MB, exact bytes with a plain 200), carried by `SCIYTParts`; the joined size is compared with the declared
  `contentLength` before anything is written. URLs carry **no `n` challenge** (checked by fetching a file). A video that needs a login is
  refused and goes to the playlist route; **a video that fails once is remembered for the session** and goes straight there
  (`+hasFailedForVideo:`). The report carries `direct:` lines (qualities, sizes, the writer's duration against what the sources claimed,
  or YouTube's own refusal). Checked on Mac with a 19 s clip, a 3:33 song and a 10:35 1080p60 film.
- **4K (1.35.0) is AV1, written untouched.** YouTube serves 1440p and 2160p only as AV1 (`video/mp4; codecs="av01…"`, itags 400/401, fragmented MP4 — the same container the
  route already reads) and as VP9 (WebM, which it cannot). `SCIYTFragments` reads the `av01` sample entry (width/height at body+24/+26, the `av1C` child verbatim) and describes it
  with `CMVideoFormatDescriptionCreate(kCMVideoCodecType_AV1, …, SampleDescriptionExtensionAtoms {av1C})`; `AVAssetWriter` passthrough on macOS 27 then writes a correct
  `.mp4` (3840×2160, 213.0 s, frames decoded at 0/1/100/212 s on this Mac, which has hardware AV1). **Unknown: whether the writer accepts AV1 on iOS 16.1** — the report's
  `AV1 description refused` / writer-refused line says. **The owner's iPhone cannot decode AV1** (iOS 16), so the file is saved intact but: never auto-sent to Photos (the row says
  so — Photos refuses it with an error code that explains nothing), and opening it in the Centre shows an alert with Share instead of a black player (the track's
  `CMFormatDescriptionGetMediaSubType` is checked against `VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1)`). **On-device conversion to HEVC is the optional second switch (1.36.0, `SCIYTAV1Convert`, off):** `SCIYTFragments`
  exposes the parsed tracks (`SCIYTFragmentsInternal.h`: `SCIFTrack`, `SCIFSample`), each AV1 sample goes to dav1d (`apply_grain = 0`, threads left at 0, vendored static
  `libdav1d-arm64.a` linked into this tweak too), each picture becomes an NV12 buffer for `AVAssetWriterInputPixelBufferAdaptor` and **AVAssetWriter runs the HEVC encoder** (~0.075
  bit/pixel/frame), and the AAC is copied across untouched. **Decoding happens only when the writer asks for a frame** (`requestMediaDataWhenReady`), so memory is a few frames — unlike
  Instagram's transcoder, which holds every compressed sample (fine for a reel, half a gigabyte for 4K). Measured on this Mac with the 213 s 4K clip: 74 s, 5326 of 5326 frames, 3840×2160
  `hvc1`, frame at 100 s visually identical to the AV1; the iPhone figure is unknown and certainly several times slower. Two faults were caught by that test: a pointer into a memory-mapped
  file taken outside the block while the owning track object died (crashed in `memmove` in the sound pump — use the object *inside* the block), and **dav1d does not drain on the first empty
  ask when frame-threaded: that call arms the drain and the next performs it**, so stopping at the first EAGAIN lost the last frame (Instagram's `SCIAV1Transcoder` stopped the same way; fixed in 4.4.1). On failure the untouched AV1 is written instead; the screen is kept awake during the run (`idleTimerDisabled`) because the work needs the foreground.
  The row is labelled `2160p · HEVC` while the switch is on (the Photos rule and the cannot-play check read the real codec/label). Labelled `2160p · AV1` with a hint under the row; only heights above 1080 are offered, one per height.
- **`SCIYTFragments` reads the DASH files itself** (boxes: `moov` → `trak` → `mdia`/`mdhd`/`hdlr`/`stsd` (`avc1`/`avcC`, `mp4a`/`esds`),
  `mvex`/`trex`, `moof` → `traf` → `tfhd`/`tfdt`/`trun`) and writes with `AVAssetWriter` passthrough, because **AVFoundation on the build
  machine reads these fragmented files with every timestamp doubled** (19 s reads as 37.9) while `mvhd`/`mdhd`/`sidx` and Core Audio agree —
  a composition exported passthrough would carry the wrong length. NAL length must be 4. Video and audio are fed from
  `requestMediaDataWhenReady` — feeding one then the other deadlocks at ninety per cent. **The AAC magic cookie for Core Audio is the whole
  ES descriptor, not the two-byte AudioSpecificConfig**: given the short form the writer produced an `esds` nothing opens, no audio track at
  all, *and reported success*. Found only by asking the output what it held — hence the duration comparison in the report.
- **The playlist route is the fallback** (the HLS manifest the app is handed; `SCIYTPlayerStreams`, `SCIYTHLS`, `SCIYTTransport` for
  MPEG-TS via our own demux + `AVAssetWriter`, `SCIYTStreamAPI` asking four stale InnerTube clients). Filed by video id so the right capture
  is simply fetched (detecting a mismatch was solving the harder problem; in Shorts announced, overlay and captured ids routinely differ).
  An unknown owner means "cannot tell" and cannot-tell must not mean no. The audio rendition is a separate playlist when the manifest says
  so (`AUDIO=` group; a variant's `CODECS` describes the presentation, not its parts — 0.11.0 produced silent files); packed AAC with no TS
  sync byte is renamed by its bytes, not its name. `+N` parts go through `SCIYTParts`: each part its own file named by index, join in numeric
  order — **order is guaranteed by construction, not arrival** (a misordered video downloads, saves and is wrong only when watched).
- **Why not what YTKACE does beyond this:** it carries its own SABR implementation, a TV route (PS4 TVHTML5 + a yt-dlp EJS solver for `n`)
  and FFmpeg (LGPL). Only the visionOS direct route is adopted — it needs no solver, no media library, no account.
- **Photos:** YouTube's Info.plist lacks `NSPhotoLibraryAddUsageDescription` (§4.1); "do not save to Photos" is off by default
  (the Centre is the home) and its refusal is written on the download's own row. The Share action exists in the same swipe menu.
- Download buttons: YouTube's own **download button under a video** (`YTSlimVideoDetailsActionView -hasOfflineButton`, §4.2) and a Shorts
  save button. The in-player save button sits in the player's top row (1.31.0, anchored to the control that changes, leading/trailing); a
  **Save** entry is added to the action row `YTSlimVideoScrollableDetailsActionsView` as a renderer through `-createActionViewsFromSupportedRenderers:` (really declared on 21.30.5
  while `YTSlimVideoDetailsActionView` is never constructed there — YouTube composes the row from elements in some builds; `targetId` ours, §4.5); taps arrive at
  `-didTapButton:`, and a button becomes the download button at `-setOfflineStatus:offlineability:`, not at construction. **Hold-to-save is gone** (removed in 1.37.0: 1.26.0 had already moved downloading onto YouTube's button after hold-to-speed-up started downloading, and a switch that
  only re-enabled a gesture the project had retreated from was clutter — see §4.2).

- **YouTube's own player stopped on iOS 16 / 21.33.6 — a stuck system decoder, cured by restarting the phone (n=1).** On the stock app, no tweak, regular videos played a second or two and
  stopped ("Something went wrong"); Shorts and this tweak's downloads were fine. The display layer reported `-12913` ("decoder busy") on `vp09` samples. **Two diagnoses were wrong and each shipped:**
  a missing proof-of-origin token (three releases of probe), and "this phone cannot decode VP9" — an "H.264 only" filter (1.40.0–1.40.2) that made *automatic* mode worse, because the server
  chooses the format itself and the client's list does not restrict it, and a switch that turned itself on and outlived the fault. VideoToolbox answered *yes* for VP9 on that phone throughout.
  After a restart, automatic mode played 100% with the filter off. 1.40.3 removed the filter; what remains is the read-only probe, the device line in the report, "Watch here" when the app's
  error is shown, and one alert per launch on `-12913`: restart the phone. **Not known:** why it began, or whether it returns. The full evidence and the order it arrived in:
  [`docs/investigations/youtube-ios16-playback.md`](docs/investigations/youtube-ios16-playback.md). **The lesson:** a switch that rewrites what the app is offered, to cure a fault whose
  cause is a guess about the device, is a second fault; and a setting that turns itself on outlives the thing it answered.

**Read against 21.41.5 with `tools/objc-diff.py --check` (2026-10-14) — the tweak was tested on 21.30.5/21.32.4 and the owner runs 21.41.5:** `MLVideo` no longer declares `-isPlayableInPictureInPictureByUserSettings`
(it is on `YTBackgroundabilityPolicyImpl`, fixed in 1.41.1: the old hook had become a method added to a class nobody asks); `YTSegmentableInlinePlayerBarView` is not in the binary but the marker hooks cover three bar classes and `YTInlinePlayerBarView` answers on 21.41.5 (no change needed);
`YTAdsInnerTubeContextDecorator` is now `YTAdsInnerTubeContextDecoratorImpl` (hooked in 1.42.1); the bottom bar class `YTInlinePlayerBarContainerView` is **absent** from 21.41.5, so the end-time label has no home there and only the top row is used.
1.42.0 added a quality-label button and a PiP button in the player's top row beside the save button (ideas from PoomSmart's YouQuality and YouPiP, MIT; placement ours): one hook builds up to three buttons, the neighbour
search skips all of ours (a button that measured its own sibling would walk), and each further button sits one gap beyond the previous, mirrored in Arabic. Both are **off by default and not run on a device**.
**YTUHD (software VP9/AV1 decoders + ABR policy changes) is deferred**: `MLABRPolicyNew/Old` and the decoder-factory selectors it hooks are not in 21.41.5.

**The Download Centre** is a **tab**, built as a pivot renderer YouTube draws itself (real label, selected state, width) — never a circle
painted over the bar; its icon is painted on afterwards because the `iconType` enum is unreadable. **History** (`FEhistory` browse id the app
already resolves) and the Centre are rows in the tab-bar arranger (Settings › Interface › Tab bar: drag to reorder, drag across to switch a
tab off, hide the `+`); every decision is on `pivotIdentifier`, never position. The tab bar is changed on the first `didBecomeActive`, not
during launch (§4.3). The library and player (`SCIYTLibrary`, mini bar, lock-screen remote, PiP, sleep timer, resume) live in `Center/`; `SCIYTHostPlayer.x` stops YouTube's own
player when ours starts (two videos at once: an audio session only arbitrates between *apps*, and both players are in one process — the other has to be told, by name); files are named by extension; simultaneous downloads is a setting; a finished save of the same kind is
reported as already saved rather than refetched.

**The app stopped launching in 1.29–1.31 and the lessons are in §4.3** (three hooks asking for layout from inside layout; `-topControls`
doing work per call; icon repaints; dead code woken by the `SCISafeValueForKey` fix; `_ASDisplayView`). The launch guard and `NOHOOKS`
exist because of it. One failure was cured by clearing the app's data, and on a second phone by deleting the app (1.31.1 added two guards on the tab bar for it).

**Ads** are blocked in three places — the app stops asking (request level), promoted rows are dropped (feed filter through *all three* doors,
measured against the server marker `ad_slot_logging_data`/`SLOT_TYPE_IN_FEED`), and the player refuses pre-, mid- and built-in ads — plus the
runtime-installed gates from YTKACE (1.32.0: player response, Shorts list, subscription pop-ups; each records installed / class absent /
method absent / encoding found, then counts hits; ships on 21.33.6 and 21.39.4, so most are absent on 21.30.5 and say so). **Declined on
purpose:** its queue "without Premium" and Premium logo. **Playback-error recovery** (1.33.0, YTPlaybackFix approach, MIT):
`handleError:` for error 14 and 0 → wait 0.8 s to see playback really stopped → reload the player and seek to the same second, **budget three
reloads per video per two minutes counted in reloads, not errors, handing the app's own error back when it gives up**, every error tallied by
domain and code. It was declined first on "nobody reported it" and taken the same day when the owner said the screen appears often: **a symptom
people put up with never reaches a bug list.**

**SponsorBlock**: eight categories each with a switch, coloured markers on the bar (iSponsorBlock, GPLv3; **one marker set per bar** — a global
once served every bar until 1.22.0), private hash lookup. **Quality ceiling** per Wi-Fi/mobile, full quality list. **Settings (1.37.0: six pages — Downloads, Player incl. quality, Screen, Ads and clutter, SponsorBlock, General incl. tools and about)** open with two
fingers anywhere (a settings entry in YouTube's own screen crashed the app twice: it must satisfy tables the tweak cannot reach); the report is
on request (§4.4). YouTube is hooked on its model and service layer, never its views, except the marker colouring (laid out with frames; a fault
there costs colours, never the video).

### 5.3 X (`tweaks/twitter`)

- Classes: see §4.1. **One capture point serves downloads**: `TFSTwitterMediaInfo`, the model every surface builds (timeline, full screen,
  quoted posts, DMs). The in-video button goes on `ImmersiveActionsStackView` (members `ImmersiveActionButton`; the old
  `ImmersiveInlinePlaybackButtonsStackView` is gone from 12.15 — both names are hooked, the report says which attached), the status bar is
  `TTAStatusInlineActionsView` (`-setViewModel:options:displayType:displayTextOptions:account:` is the bind point; X adds its own buttons to it so
  it takes another). The button is draggable and pinnable (0.19.0, confirmed on a device).
- **Feature switches**: the tweak records every question X asks and lets the user answer any of them (341 keys over 345,902 questions on 12.14);
  what a key *means* is read from its name and the screen says so; **`app_attest_*` is never offered** (§2). Fifteen features arrived in 0.17.0
  (BHTwitter, architecture only): link cleaning (`s`/`t` stripped), `t.co` shown as its target, Safari, search history withheld, Face ID cover
  (cover up *before* the prompt; a device that can evaluate neither biometry nor passcode is let through), who-to-follow/topics/trend videos
  refused at `TFNItemsDataViewController -tableViewCellForItem:atIndexPath:` by the view model's class (cells shown as well as hidden — reuse),
  view count and bookmark hidden, post-as-image on long-press share, confirmations (never before an unlike/unfollow), undo-post toast, bio
  translation, HQ upload, single photo uncropped (attachment type 2), LTR text (marked cautious). Four of BHTwitter's have no target in 12.20 (`_t1_showPremiumUpsellIfNeeded`, `-isVODCaptionsEnabled`, `TFNTableView -setShowsVerticalScrollIndicator:`, the cache clear) and two classes were renamed
  (`TTMUploadConfiguration` for `TFNTwitterMediaUploadConfiguration`, `TTSSearchTypeaheadViewController` for `T1SearchTypeaheadViewController`). The view count is answered by
  `view_counts_public_visibility_enabled`; `audio_articles_enabled` was the same hide-versus-forbid shape as the voice-room keys.
- **Spaces/tabs:** `-_t1_initializeFleets` on `THFHomeTimelineItemsViewController` (`v16@0:8`, main executable) is withheld to hide the strip;
  the bottom bar's `…AppNavigationTabEntry` objects declare `-isExcludedFromTabBar` and `-isTabViewSideBarOnly` (`B16@0:8`), forced together
  (the second is the iPad half). Communities and Profile in the bar are confirmed on a device (0.16.0); Spaces removal is at `-setTabViews:`.
- The settings are a **registry** of sections registered in `+load` from their own files (§4.5), reached by a two-finger hold on X's own window.
- **NeoFreeBird (0.21.0)** is the first reference for X that is **both current (written against 12.31) and carriable (GPLv3)**; our own IPA is 12.20, so every class,
  selector and key it names was checked against 12.20's metadata first (`tools/objc-classes.py` over `Twitter`, `T1Twitter`, `XAppLibraries`, `TwitterSPMMigration`;
  keys by searching the binaries for `key\0`). What differed from ours and was fixed: the switch layer answered only `-boolForKey:` (typed getters and the
  `TFSInstrumentedFeatureSwitches` wrapper are hooked now, each group only when the class answers *every* selector with the 12.20 encoding), and the timeline filter hid
  cells (a gap, and not reached on the collection-view path 12.28 introduced) where NeoFreeBird filters the **section data** in `TFNItemsDataViewController`
  (`setSections:restoreScrollPosition:` and `updateSections:reconfigureItemIdentifiers:withRowAnimation:completion:` are the two doors it hooks; ours also covers five more).
  Spaces gained a third path, `T1FleetLineHeaderController -_t1_shouldShowFleetLine`. **Not taken, on purpose:** the premium unlock (`TFNTwitterAccount -isSubscribedTo:` →
  YES for tiers 0/7/8 and `subscriptions_gating_bypass` — §2 Money), the age-verification bypass (the owner's call, not a default), web login/reply/posting and the account-location
  lookup (they harvest `auth_token`/`ct0` and send GraphQL the app never sent), and Tenor GIFs (a shared API key and a third party reading searches). **DM video/voice download**
  needs `DMConversation`/`ChatConversation` classes that are not in 12.20, so it cannot be checked here and is not written. What was taken needs a device: the typing frame shape is
  NeoFreeBird's measurement on a newer X (the report counts frames seen and dropped), and nothing in 0.21.0 has run on a phone.

### 5.4 TikTok (`tweaks/tiktok`)

- **Two reference tweaks doing one job use different selector names, and reading only one keeps a feature broken for eight releases.** NA9's symbols
  (`AWEFeedViewTemplateCell$na9AddDownloadButton`, `$downloadVideo`, `$downloadProgress`, `AWEAwemeACLItem$setWatermarkType`, `AWEAwemeModel$canDownload`/`isPreventDownload`)
  say it **asks the app to download its own video** and puts the button on the cell; of those `downloadVideo`, `downloadProgress` and `watermarkType` are in 46.4.0,
  `downloadHDVideo`, `canDownload`, `isPreventDownload` and `AWEFeedViewTemplateNewCell` are not. VibeTok has a whole `MSGDownloadSettingsViewController` and sends
  `-h264DownloadURL`/`-playURLList`/`-urlList`/`-originUrl` where NA9 sends `-playURL`/`-bestURLtoDownload`/`-originURL`; `-originURLList` is the only one both send.
  Class names that do **not** exist as exact strings in 46.4.0: `AWEPlayVideoPlayerController`, `TIKTOKProfileHeaderView` (plausible replacements
  `AWEPlayVideoPlayerControllerClass` and a `TTK` family were not confirmed enough to hook).
- **Architecture, every class confirmed against a real 46.4.0 IPA** (`MusicallyCore.framework`; the executable is a stub). The ad filter
  refuses an `AWEAwemeModel` marked `-isAds` (also `isAd`/`isAdItem`/`isAdsOrPseudoAds`) as it is built, never as a view hidden after, and the
  launch splash ad; the jailbreak bypass covers confirmed checks (`AWEAPMManager +signInfo` → `"AppStore"` is a jailbreak answer, not an ad
  control — misfiled once by name); privacy is **three** independent switches (a story's seen mark, a message's read-sync — its local-only
  sibling is left alone, the same local/receipt line as Instagram — and a profile view via `TTKProfileViewsVisitor` `-visit:` / `-p_shouldReportHasVeiwedProfileForUser:`); more logged-in accounts;
  messages taken back stay visible *and marked*; a record of profile visitors; the seek bar kept visible by refusing the hide
  (`AWEFeedPlayerBottomProgressBar` `-setHidden:` → NO, `-setAlpha:` refusing zero — the app often has the view and chooses not to show it);
  the publish date from `createTime` in a frame this code owns; save media from a comment (`TTKCommentAppReviewsLongPressHelper`
  `-buildActionSheetForModel:index:`, a row built as `AWEUserSheetAction` and handed to the sheet's own `-addAction:` — not a sheet of our own).
- **The button belongs on `AWEFeedViewTemplateCell`** (its `-configWithModel:`/`-configureWithModel:` fire on every reuse and hand over the model; the rails
  `TTKFeedInteractionStackView`/`TTKFeedRightInteractionStackView` rebuild their arranged subviews, so a guest is swept out — both rail hooks remain and stand down
  whenever a cell button exists), at index 0,
  its frame owned by this code; the model is on **`AWEFeedCellViewController.model`**, reached through the cell's `-viewController` (the cell has
  no aweme accessor — NA9 hooks `AWEAwemeBaseViewController` while putting its button on the cell; those are two halves of one design). The
  item is **re-resolved at tap**, never read from what was stashed at construction. A photo post's index comes from the paging controller
  (`AWEPlayPhotoAlbumViewController -currentIndex`, `Q16@0:8`, via `activePhotoAlbumController`), not `AWEPhotoAlbumModel.currentIndex` (which
  has an `initialIndex` sibling — the shape of a value set once).
- **Where links come from:** `AWEVideoModel.downloadNoWatermarkURL.originURLList` (confirmed from the class's own accessor list); the class
  also has `downloadURL` (the watermarked save copy, reliably the largest file), `h264DownloadURL`, `bitrateModels`, `playURL`, `playLowBitURL`.
  `bitrateModels`, `SDRBitrateModels` and `HDRBitrateModels` are the **same five gears** on this build (gathered, deduplicated in the report); every gear ever seen is named
  `lower`/`lowest` and none carries a `selectedAudio`, so audio is muxed and simply follows the bitrate (the two-stream theory was disproved by the probe built to test
  it). `bitrateModels` is populated **progressively** (a read before the app fetched real gears sees placeholder numbers — two different lists and one
  list read too early look identical in one snapshot), and `__playBSModel` and siblings are one gear at the same low bitrate. `-bitrate` is read
  through a cast taken from the runtime encoding; the ladder is only walked for a *settled* model (`+captureSettledModel:` is a second entry
  point, not a flag — "is this safe to walk" is a fact about the caller); a failure falls through to the ordinary chains.
- **Ranking is kind first, bytes second** (every wrong-file report was a different property size cannot see): a clean copy beats a watermarked
  one, video beats audio (0.14.0's `HEAD` kept only `Content-Length`: a 0.9 MB `audio/mpeg` beat an `.mp4` whose server answered 400 and the save
  was the music), the demoted `h264DownloadURL` (a larger H.264 is the worse picture next to a smaller HEVC — `AWEVideoBSModel` declares `codec`
  and `isBytevc1`) goes last (`SCITTOriginIsDemoted`), and bytes settle ties only *within* a kind (photos too: the largest variant was
  `userWatermarkedPhotoURL`). Origin travels beside each URL in lockstep arrays (walked by index, never re-found by value). A link that refuses
  `HEAD` is measured with a one-byte range `GET` (`Content-Range` carries the total) and is **not** "worst". 1080p60 was confirmed through the
  external switch; **internal-only downloads are 720 at 30 fps** because that is what TikTok streams.
- **The external HD switch (off by default)** fetches via `tikwm.com`, which is an **API, not an endpoint** (one JSON request names the links; the
  `…/hdplay/<id>.mp4` shortcut works only afterwards — NA9 parses JSON for exactly this call; a missing `User-Agent` was not the cause, tested
  with `curl`). It returns the **original upload**, which on some videos is dramatically better (13.9 MB vs 4.5, 60 fps vs 30) and on others is
  byte-for-byte what the tweak already had (3,786,622) — **n=1 was generalised twice here, in both directions**. When on, it takes precedence over
  the ranking (a switch the user turned on is a decision, not an input), and an unavailable service costs nothing. Both reference tweaks carry
  the same `tikwm.com` format string, so the reliability people attribute to their buttons is the external service, not a better internal chain.
- **Photo posts** are an `AWEPhotoAlbumModel` under `-photoAlbum` (list `photos`, elements `AWEPhotoAlbumPhoto`: `originPhotoURL` as posted,
  `thumbnailPhotoURL` a preview) — a photo post carries a video model too, so the picture branch is asked **first**. Saved one at a time with
  "saved N of M", **it asks first** (this picture or all, defaulting to the visible one), and a single picture can be saved as a 10/30/60-second clip
  with the post's own sound. Photos infers a type from the file name of a *data* resource: bytes are named by their first four bytes (a WebP
  announced as JPEG earned `PHPhotosErrorDomain 3302`), `originalFilename` set, JPEG re-encode as a last resort via `ImageIO`; downloads use
  `NSURLSession` because `+dataWithContentsOfURL:` cannot report an HTTP status. A format string is a callee with types (`%.0f` with an `int`
  literal read every clip as `0 seconds`).
- **Settings** (redesigned in 0.24.3) are the system's own inset-grouped list (`UICollectionLayoutListConfiguration`, cell registrations, `UIListContentConfiguration`) under a centred identity header: one row per registered section (outline icon, name, "on/total", chevron), and inside a section a title with its note beneath, the switch at the end (the whole row flips it), a choice showing its current value on the second line. Colour is meaning only (accent on a switch, orange on a warning); icons are the outline variant of the registry's symbol (`SCITTRowIcon.h`), shared with the status report. The registry (`SCITTRegisterSection`) is unchanged: the redesign touched drawing only. **Look at it before changing it:** a throwaway simulator app that compiles `SCITTStatus.m`, the registry, the sections and `SCILocalize.m` with three stubs (`SCITTReport`, `SCITTWelcome`, `SCIPanelAllowsThisApp`) builds in seconds with `clang -target arm64-apple-ios15.0-simulator` and was how this one was drawn, in light, dark and Arabic. A one-row-away copyable Status report names every number behind every feature; the way in is the Albrhi section in TikTok's own Settings (the two-finger hold is an off-by-default option). **The update screen** (`SCITTWelcome`) appears once on the first launch after an update that raises `kSCIWelcomeEdition` (an integer in SCITTWelcome.m, stored as `welcome_edition_seen`; a patch release leaves it alone and stays silent), says what changed in a light tone, and is recorded as seen when it is *drawn*, never before (the old screen used its single showing up when no window existed). It waits for an active app with a key window for about half a minute. Reduced-motion phones get no confetti and no staggered entrance. Raise the edition by hand when a release has something worth telling; the rows are `welcome_r1..r4` in both tables.
  Confirmations (like heart *and* double tap, follow on feed and profile) are off until turned on.
- **Region, speed and app lock (0.22.0), from TTF-Mod-iOS (a BHTikTok++ fork, unlicensed: architecture only).** Region is a **choice, real by default**: no key on disk means nothing is rewritten, only
  **getters** are answered (a setter hook would leave the lie in TikTok's own cache after the switch went off), and the row says it tells TikTok something untrue. The reference ships it on, set to Kazakhstan, without asking.
  Confirmed on 46.4.0 with `tools/objc-classes.py`: `TTKStoreRegionService`, `TIKTOKRegionManager` (seven class methods), `ATSRegionCacheManager`, `TTKStoreRegionModel`, `TTInstallIDManager`/`BDInstallGlobalConfig -currentAppRegion`;
  **`TTKPassportAppStoreRegionModel` is not in the binary** (the reference hooks it). The country table (36 entries, ITU E.212 codes) was written here and is best effort. Speed: `TTKMediaSpeedControlService`'s three rate
  calls map 1.0 to the chosen rate and leave every other rate alone (hold-to-speed-up keeps working); **which of the three moves the player is not read from the binary** and the report counts each. App lock: notifications +
  LocalAuthentication only, no TikTok class. Not taken from the reference: fake follower/verified numbers (deceiving others), its long jailbreak path list (`/bin/sh`, `/usr/lib/dyld` exist on every phone), unguarded hooks.
  New settings row kind `kSCIKindChoice` (first option = default = key removed). **Not run on a device.**
- **Profile background (0.25.0): TikTok ships the whole editor and the server keeps it off.** The binary has `TTKProfileBackgroundService`, a coordinator, crop, photo and video preview, an education manager and an
  edit request/result; `TIKTOKProfileEditMainViewController` has the buttons (`p_didTapProfileBackgroundChangeButton`, `p_runProfileBackgroundFlowWithBgInfo:sourceView:`, ivars `_hasProfileBackgroundComponent`,
  `_hasProfileBackground`, `_profileBackgroundInfo`). **Who reads the flags** (caller scan, `docs/investigations/na9-scripts/callers.py` over `MusicallyCore` 47.1.0): `+[TTKABTest profileBgInAllowList]` and
  `profileBgEnableConsumptionGroup` (`q16@0:8`) are read by `-[TTKProfileComponentDataController getRequestParamsWithParams:isCurrentUser:]` and by nothing else, so they are **request parameters**: the answer is the
  server's. `TTKProfileHeaderAdaptor p_setupComponentsWithModel:isCache:isPreload:` reads `hasProfileBackground`/`hasProfileBackgroundData`; `profileBgReduceTransparencyFixEnabled` has no caller. The editor shows its controls
  when `p_resolveProfileBackgroundSnapshot` finds `TTKProfileComponentResponseModel -profileBackground`. Ours (`Features/Profile/SCITTProfileBackground.x`, switch `profile_background`, **off by default** with the cost on the
  row) answers `profileBgInAllowList` with 1 and, only inside the editor's resolve and only on that thread, gives an empty `TTKProfileBaseComponentModel` (`bizData = @{}`) when the response has none. Each of the three hooks
  installs on its own behind the encoding check; `objc-diff --check` against 47.1.0 passes them. **Confirmed on the owner's phone (2026-10-27, 0.25.0): the editor appears and works** ("اشتغل و طلعت الميزه ممتاز"), so `bizData = @{}` is a shape it tolerates and the allow-list flag is enough for his account. **Still not known:** whether
  the server accepts the change for every account (one phone is one data point), (the reference passes the same thing: its imports include `___NSDictionary0__struct`, i.e. `@{}`; an earlier line here said it passed "something else", which was a guess from a constant that had not been resolved). `profileBgEnableConsumptionGroup` is left alone: it concerns *viewing* backgrounds.
  The idea came from `ProfileBanner` (unlicensed, §2); only the places to look were taken.
- **Browsing switches (0.26.0, all off, section «Browsing»): decisions, not views.** Who asks was measured first (caller scan, 47.1.0): `TTKPlayInteractionTikBotElement -p_shouldShowtikBotButton` is read by `-containerDidFullyDisplayWithReason:`,
  `AWEThirdWebModuleServiceImpl -shouldOpenURLInIAB:` by `-tryOpenURL:dataflowId:` of two classes (**`PHFDfidRouterServiceImpl` declares its own copy of the decision, which 0.26.0 never hooked: grep every implementer**), `AWEFeedContainerViewController -segmentControlInitialIndex` by `_generateSegmentControlByReason:` and `p_onFinishLogin`. The Following tab is found **by class**
  (`TikTokFeedTabItemFollowControl`), never by title (titles are translated); it is applied only until the feed first appears, behind a "did not finish" flag that stands the feature down until the switch has been seen off. **`TTKEditProfileBioStrategy -maxTextLength` is not the only
  reader**: `AWEProfileEditTextViewController` has its own `maxTextLength` for nickname and username too, and was left alone, so whether the bio really lengthens is a question for the counter. The copy menu (hold the download button) and the avatar Save button are this tweak's own views, not additions to TikTok's long-press
  panel (never read). **The hold on the button did nothing in 0.26.0**: a recogniser on the button loses to TikTok's own feed long-press, so 0.26.1 follows the touch from `-[UIWindow sendEvent:]` (the Instagram 4.7.9 lesson, §5.1) and also copies the name or bio under a hold on a profile; its report line keeps the class chain of the last hold that matched nothing. `+[BDADeviceHelper isJailBroken]` joined the bypass. **None of it has run on a device.**
- **Links in Safari did nothing in 0.26.0, and the reason was in the reference all along (0.26.2).** The first version hooked the "browser or system?" decision of one class. The reference (decompiled, not copied) intercepts where an address *enters*: `GBLRouterImpl`'s four `openURLString:…` and
  `AWE3rdWebContainerService`'s `openURL:…`, opens an http(s) address with `UIApplication` and **swallows the call**, with a `WKWebView loadRequest:` net underneath. Two further facts the first version missed: **TikTok wraps outbound links in its link-safety redirect** (a host containing `tiktoklinksafety`
  or a path beginning `/link/`, the real address percent-encoded in a query item), so "is this address foreign?" asked of the wrapper says no -- unwrap first; and the reference's list of TikTok-owned hosts is nine suffixes (`tiktokv.com`, `tiktokcdn.com`, `byteoversea.com`, `bytedance.com`, `musical.ly`,
  `ttwstatic.com`, `ibytedtos.com`, `tiktokglobalshop.com`, `capcut.com`), to which `tiktok.com` is added here. **Which door a bio or comment link takes is not known from this machine** (the router's callers are live-room components and `TPPieceParser handleClickableStringPiece:`), so every door counts
  (**one door is measured, though**: `AWE3rdWebContainerService -openURL:dataflowId:` is called three times by `TTKWebRouterUniversalThirdInterceptorV2 -handleBeforeAspect:error:`, the web router's "universal third-party" interceptor, and by `TTKAttributionLinkStickerDisplayHandler -p_openURLWithUniversalLinkOrIAB:linkName:` -- the path a third-party address takes)
  and a foreign address a web view loads with no door having caught it is named with its class chain on the Status screen. Not run on a device.
- **The download banner has a cancel button (0.26.4), and the banner still takes no touch except that button's.** `SCITTBannerView -hitTest:` answers for the button's circle plus 8 pt and returns nil elsewhere, so the feed keeps scrolling under it (measured in a simulator harness: a tap on the banner body reached the control beneath). Cancelling is
  an **epoch**: every operation (`+save:`, `+savePhotos:`, `+saveClipFromPicture:…`) notes it at the start and asks "is it still mine?" after every wait; `+cancelAll` bumps it, cancels every request registered in a weak table (`SCITTTrack`, the four shared-session requests) and invalidates the video sessions. Measured against a throttled local server: the
  connection was dropped on the tap. A late callback must never put the banner back (`-report:ok:since:`, the `cancelled` flag on `SCITTDownload`). What stays: pictures already saved, and the Photos import once the file has fully arrived. Not run on a device.
- **Cache cleaning (0.26.4, section «Storage») -- what NA9 does, read with REA 2026-10-29, and what this tweak does differently.** NA9's `na9_autoclear_cache` is read in a **constructor** (`__init_offsets` entry `0x7d7a0`, so it runs when the dylib loads, before TikTok's own
  code) and dispatches `+[TTKHelperTools clearCache:NO]` to a **global background queue**, concurrent with TikTok starting. `+cachePaths` = `Library/Caches`, `Library/Application Support/gurd_cache`, `tmp`; `clearCache:` lists each and `removeItemAtPath:`s every entry; the flag decides whether `gurd_cache` is skipped
  (launch: skipped; button: not). Its control flow is flattened (`br x9` to the next instruction, targets computed from a table, a word and an XOR key), so the decompiler stops after the first line: the targets were computed by hand from the table and the key. Ours renames entries into one trash folder and empties it afterwards, skips what was written
  after launch, offers a size threshold instead of "every launch" (a wipe also deletes what was just preloaded for the first swipes), and **never touches `gurd_cache`** (what it holds is not known; its size is in the report). **A cache clean cures a full disk and a corrupted cache, not lag and not hook crashes; do not promise more.** Measured in a simulator with fake folders only.
- **Driven end to end in the simulator (0.26.5) -- six faults a report would have taken rounds to find, each seen on screen.** (1) **The copy menu opened with TikTok's own long-press panel
  (Report / Download / Clear display) under it**: the window follower never consumes a touch, so TikTok's recogniser recognised at the same half second; at touch-down on one of our buttons the other
  one-finger long-press recognisers above it are switched off and given back at the lift (`SCITTSilenceForeignHolds`; the two-finger settings hold is exempt; the report counts the touches). (2) **The copied
  share address carried the sharer's tracking** (`_r`, `u_code`, `_d`, `sharer_language`, `share_item_id`, `source`): on a tiktok.com host everything after the `?` is removed from the video and sound links.
  (3) **"Start on Following" opened Community after a fresh install**: a cold start asks `segmentControlInitialIndex` with Following as the *first* item and inserts Community in front afterwards, so the live
  row said 0; the index remembered from the feed's first appearance (the complete row) is preferred and the report shows both. (4) **The settings sheet had no bar, no title and no "Done" after a profile
  had been visited**: TikTok's pages hide the navigation bar and the hiding outlived them; our pages show it in `-viewWillAppear:`. (5) A cache size read "132.5 MB · 261 KB" (two numbers read as one); it is
  one number. (6) The auto-advance switch scrolled the feed away under an open copy menu, leaving rows that described a video that had gone. Measured and unchanged: the launch-time clean took Caches 150 MB to
  5 MB, tmp to zero, `gurd_cache` untouched; a save wrote a valid 13 s 720x1280 video with sound to Photos. **Not seen:** the cancel button mid-transfer (a local download ends in under a second), the avatar
  Save button and bio copy (a guest's profile header arrives empty). **A feature added to a settings row can break the row**: the new "current choice" value squeezed the title of the Region row to "Re-gio-n"
  until it was limited to short values.
- Non-obvious refusals: `PIPOStoreKitHelper -isJailBroken` is not hooked (§2); the `tikwm` path was refused *as the fix, arriving quietly* and shipped as a
  switch once the owner asked knowing the trade — the earlier refusal was a different question, not wrong.
- **Reviewed against 46.4.0 and 47.1.0 (0.24.0): a hook that "attached" is not a hook that works.** Four findings, all from reading the binary rather than a report. (1) **Class method versus instance method, and a class that
  hides its methods.** `TTKStoryMarkReadService` is a Swift class: the runtime lists `-init`, `-initWithContext:`, `-readItemIDs` and `-setReadItemIDs:` and nothing else, so `-markAsRead:` was an added method nobody sent, in both
  builds; the report goes out through `+[TTKStoryNetworkService reportStoryViewedWithStoryID:uid:completion:]` (and the `unlocked:` sibling). `AppsFlyerUtils` and `IESLiveDeviceInfo` answer `+isJailbroken…`/`+isJailBroken` and were hooked as
  instance methods; `FBSDKAppEventsUtility -isDebugBuild` is an instance method hooked as a class one. `tools/objc-diff.py --check` finds exactly these (its group 1) and also lists the system-class hooks in group 2 that need a runtime
  question instead: **`%hook NSObject -jailbroken` made every object in the process answer YES to `respondsToSelector:`**, so it, and `-[UIDevice btd_isJailBroken]`, are installed only where `class_getInstanceMethod` finds the
  selector. (2) **A flag nobody reads, and a feature that was removed.** `-[ABTestCodeGen addFollowsYouLabelEnabled]` is a thunk that forwards to `+[TTKABTest addFollowsYouLabelEnabled]`, and a scan of every selector load in `MusicallyCore` found no caller of either: the
  "Follows you" label belongs to the suggested-account card (`UserSuggestionCardContentView.followsYouLabel`, Swift) and 47.1.0 does not ask the flag. A banner built on `followerStatus` replaced it in 0.24.0 and **the owner asked for it to be removed in 0.24.2** (he suspected it of the crashes, and its banner was the download banner), so there is no "Follows you" feature and the key is unread.
  **Before hooking a getter, ask who calls it** (the scan: selref slot of the selector, every `adrp`+`ldr` of that slot in `__text`, nearest preceding ObjC IMP as owner; `__objc_stubs` are checked first. The scripts are in `docs/investigations/na9-scripts/`; the owner attribution is a hint, since Swift code sits between ObjC methods). Callers exist for the five suggested-account gates, `isForbidComment` (read by `-disableComment`), the sort gates, the
  LIVE-entrance gates, `p_markReadSyncToServerWithMessage:`, and `+reportStoryViewedWithStoryID:uid:unlocked:completion:` (from `-[TTKStoryManager _reportStoryRead:authorID:unlocked:retryCnt:]`; its 3-argument sibling has none and forwards to it). **Not verified: any caller of `AWETopLiveBubbleManager -canShow`** (the scan returns twenty-three sends of the shared selector, none attributable to that class).
  **An information banner must not look like a finished download:** `SCITTToast finishWithText:` is a green check and a full bar, so the video-count banner (and the read alert) read as "saved"; `noticeWithText:symbol:` has no bar.
  (3) **"LIVE" is four surfaces:** the item in the feed list (dropped at construction), the badge in the top bar (`AWEFeedContainerViewController` `_shouldShowMTLiveEntranceView` + `…OnLeft`/`…OnRight` +
  `-shouldShowLiveBadge`), the "someone you follow is live" bubble (`AWETopLiveBubbleManager -canShow`) and the strip in the Following feed (`GBLInfeedSkylightLiveCellController`, **not** handled -- no gate was found that is safe to refuse).
  (4) **The splash-ad hooks were dead:** `-isSplashDisabled` / `-shouldShowSplash` exist on none of the three managers. The real deciders (`BDASplashManager -pickModelWithBlock:isWarmStart:`, `-displaySplashOnWindow:`,
  `AWESplashManager -tryToShowSplash`) are on the launch path and are left alone until a device says what refusing them does. Settings: the preferred row is a **native section**, the recipe read by disassembling NA9 (`docs/investigations/na9-analysis.md`): hook `-[TTKSettingsViewController sectionViewModels]` (inherited from `AWEBaseListViewController`), append an `AWESettingsNormalSectionViewModel` built with `initWithModelsArray:` around a `TTKSettingsBaseCellPlugin` whose `itemModel` is an `AWESettingItemModel` (`setCellType:4`, `setType:1`), and catch the tap in `-collectionView:didSelectItemAtIndexPath:` by the item's identifier; all fifteen messages exist with the same encodings in both builds and are re-checked at install. The earlier inset row (a view in the collection view, `contentInset.top` making room) is kept only as the fallback when a prerequisite is missing. **Neither has run on a device.**
  **A closed reference's hook table can be recovered even when its strings are XOR-encoded and its calls go through trampolines:** emulate the decoding blocks linearly and read `MSHookMessageEx`'s argument registers (`docs/investigations/na9-scripts/`); and NA9's own hooks are dead on the same selectors ours were (`TTKStoryMarkReadService -markAsRead:` and others), so a reference tweak naming a selector is a lead, never evidence.


### 5.5 YouTube Music (`tweaks/ytmusic`, in the suite)

Ported hooks (YTMusicUltimate, YTMEnhanced; GPLv3), the Premium claim deliberately not. **Synced lyrics** from six sources (LRCLib, Genius, MusixMatch,
NetEase, the video description, YouTube Music's own) with the wrong match discarded, romanisation, pinning, offset nudging, optional translation with
the user's own key (`YTMULLMCompleteJSON`, §4.7). **Saving a track** (0.7.0–0.9.0) through the download button the app already draws, without FFmpeg,
with a Downloads tab replacing the Upgrade tab and a player that behaves like the app's — **0.9.0 was the installer commented out since 0.8.4** (§4.4),
and the badge asked `YTMNowPlayingViewController` for `playerViewController`, which its parent `YTMWatchViewController` declares (two doors resolving the
same thing two ways; one resolver serves both now). The 0.8.x crash was a number: an `iconType` the app has no case for. Also: the Premium ad and
Upgrade tab hidden, background playback without the upsell notification, no autoplay radio, casting, true-black theme, speed control the app hides,
seek buttons, SponsorBlock for `music_offtopic` (off). The suite's `Conflicts` includes `com.dvntm.ytmultimate`. 29 host tests.

### 5.6 Spotify (`tweaks/spotify`, built by hand, not published)

Ad blocking and podcast SponsorBlock carried over from EeveeSpotify (GPLv3) **without the Premium unlock** (§2); one line in one file is the only edit
to a ported file and it says so. Swift/Orion gotchas are in §4.7. **A hook installed before its target was confirmed** caused two crashes
(`AdBlockerGroup().activate()` without the `NSClassFromString("HUB…") != nil` guard; the missing `-D ROOTHIDE`), and ungrouped hooks ran regardless of
the master switch (the clean-share-link crash). Upstream's `writeDebugLog` wrote every message to a file forever; it goes to `NSLog` behind a switch that is
off (0.2.5). The panel has a detail page for it (`tweaks/panel/src/Spotify/`). There is **no publishing workflow** — an open decision (§7).

### 5.7 NextUp (`tweaks/nextup`, own package, GPLv3 port of NextUp 3 by Yves)

SpringBoard plus the media apps (Music, Podcasts, YouTube, YouTube Music, Spotify; SoundCloud arrived with NextUp 3 1.2) in one binary gated at runtime on host
process and iOS major — the logs of its several processes are why the ceiling is per process; eight display-side hook files cover iOS 14.2–26. **Confirmed working on iOS 16.1** — the first "it didn't work" was a jailbreak
with per-app injection and the media apps not enabled: the display side was up and no provider answered, and the log named it exactly (`kr=1102`,
`BOOTSTRAP_UNKNOWN_SERVICE`, `vendor/LightMessaging/bootstrap.h`) — the first question for any tweak spanning a system process and App Store apps. Its
libSandy fallback path bug is in §4.6. **Follow upstream by applying its own commits, not by re-copying:** 0.3.0 took 1.1.2 → 1.2 as `git diff` between the two
upstream commits through `patch` onto the renamed tree (every file but the two new SoundCloud ones applied cleanly — that is what keeping `NU*` names and
layout buys). What a diff cannot carry across is anything this port *replaced* (the preference pane), so a new app is a switch added by hand in
`SCINUSettingsController` (and its bit in the toggle table, which must match `NUPrefs.h`) plus strings; read upstream's `git log` first. `NUPrefs.bundle` is
resources only (name and path are load-bearing — `NULocalization.h` compiles them in; 27 `.lproj` including Arabic). **Its log is compiled in and off** (an
always-on log writes what is playing into `/var/mobile/nu/` forever; compiling it out left the first install undiagnosable), 128 KB per process. The master
switch is off until turned on (this port's change). It injects into SpringBoard — keep a way back in.

### 5.8 Watch (`tweaks/watch`, own package, MIT core by 34306)

**Confirmed on a device:** pairing works and the update hold is installed on all five selectors — `-manager:scanRequestDidLocateUpdate:error:` on
`COSSoftwareUpdateController`; `-startDownload:`, `-startDownload:passcode:`, `-installUpdate:`, `-installUpdate:passcode:` on `SUBManager` — every encoding
read off the device before a hook was written. watchOS 26.6 is refused, 11.x would be offered, and the page says Albrhi is the reason.

- The page tracks its wait in `-isExpectingScanResult` and `-hasReceivedValidFirstScanResult`, so the scan answer is replaced (nil update, the path `-noUpdateFoundOrIsComplete` exists
  for) rather than swallowed; `-checkForSoftwareUpdate:` is not on `SUBManager` in this build at all.
- **The version is read from the update** (`SUBDescriptor`: `-humanReadableUpdateName`, `-productVersion` 26.6, `-productBuildVersion` 23U67, `-downloadSize` a
  `q`), compared on the **major** (a string compare puts 26.6 before 9.5); an update whose version cannot be read is **let through** (a hold that fires when it
  cannot tell what it is holding is the coarse behaviour wearing a filter's name). Each selector decides for itself in its own `%group`.
- The Software Update page has **two shapes**: six rows while it offers an update; two rows and *no footer anywhere* once settled into "up to date" — the notice
  was stamped onto rows about to be thrown away, and three timed passes did not help because it was never timing. `footerText` is a property: a group that had no
  footer draws one when given it. The report keeps both shapes.
- Restart: **a full userspace restart** applies a pairing change (the limits are written once by SpringBoard and every process reads them at its next start); a
  respring leaves the Watch app and daemons holding what they cached. The report names which classes were present, what the hold installed and skipped, the version
  held, and whether the tweak ran in the Watch app at all — "a pairing that fails looks exactly like a tweak that never loaded".
- **The four sync features are not being built, and not for a technical failure**: photo sync and notifications already work automatically on a watch this tweak
  has paired, so the feature had no user left. "We could not" and "there was nothing to fix" are different conclusions. NanoPreferencesSync (`NPSManager`: 17
  methods incl. `-synchronizeNanoDomain:keys:` and `-synchronizeUserDefaultsDomain:keys:container:appGroupContainer:cloudEnabled:`; `NPSDomainAccessor`: 54, with typed accessors, `-copyKeyList`,
  `-domainSize`; both confirmed in SpringBoard) is where a later attempt would start; nothing has been written to a synced domain, deliberately.
  Sixteen guessed domain names all answered `0 byte(s), no keys` while the accessor was bound to a real pairing ID — a uniform zero across unrelated things is a
  broken measurement. The real names are in `/var/mobile/Library/DeviceRegistry/<pairingID>/` (`NanoPhotos`, `NanoMaps`, `NanoAppRegistry`, `NanoSystemSettings`,
  `NanoMail`, `NanoPasses`, `com.apple.carousel`, …); a synced domain is a row in `NanoPreferencesSync/database.db`, not a file.
- **Legizmo Moonstone 6.3 contains no dylib and no filter — it injects into nothing.** It is an app, a `mobile` LaunchDaemon (`legizmoappd`, started by
  `com.apple.nanoregistry.devicedidpair`) and `.lgzfix` plugins loaded into its own app; it controls watchOS updates **on the watch** by changing the asset-audience
  enrolment over IDS (`BSU-IDS`, `BSUChangeEnrolmentRequest`, `assetAudience`, `DeveloperSeed`/`CustomerSeed`/`PublicSeed`). `LGZHephaestusScopeIdentifier` is a
  label for its own UI, not an injection target; "unsupported" (`BSU_CURRENT_SEED_CELL_UNSUPPORTED`) is Legizmo's own screen — **a screenshot of a screen is not
  evidence of where that screen lives.** Holding from inside `com.apple.Bridge` is not disproven, only not what the reference does. Read for architecture only.

### 5.9 CarPlay — what it established, for whoever rebuilds it

- **The display mechanism is the app patching itself**, not SpringBoard reaching into another app: a dylib in the target app rewrites its own incoming CarPlay
  scene role to `UIWindowSceneSessionRoleApplication`; UIKit then resolves the app's real Info.plist scene configuration, and a bug crashes that one app.
  `carplay-cast`'s `SBSceneManagerCoordinator` hosting is the old CarBridge-era mechanism, abandoned when CarPlay's UI left SpringBoard.
- **Admission is LaunchServices on iOS 15–17 and CarKit on 18+**, and one build must gate on the version (running the 16/17 hooks on 18 puts SpringBoard into safe
  mode). On 15–17: the typed entitlement getters plus `-entitlementValuesForKeys:`, whose result is a private `LSBundleInfoCachedValues` — **tag that object, never
  replace it**, and the tag set holds weak references.
- **An app that ships its own CarPlay interface must be left alone** (rewriting a template scene after CarPlay built one throws inside
  `+[UIScene _sceneForFBSScene:…]` on every launch).
- `carsurf` by pavunato (no LICENSE — architecture only) carries a "do not retry" table, each row a device recovery: no global `LSBundleInfoCachedValues` swizzle,
  nothing hooked in `carkitd`, no fabricated entitlement dictionaries, no forcing `launchUsingTemplateUI = NO` on a genuinely native template app; **a visible icon is
  never proof, a real `UIWindowScene` is.** It also taught the grouped panel row: a two-process filter (SpringBoard, Camera) showed as two rows until
  `SCIPanelGroupIdentifier`/`Name`/`DetailController` collapsed it.

### 5.10 Panel (`tweaks/panel`)

Settings › Albrhi: a switch per patched app (opt-in), a master switch (default on), a guide **built from the device** (the same scan as the main page, so it cannot
describe a tweak that is not there), settings backup/restore through the share sheet (a file beside the preferences would be destroyed by the event it exists for;
what it holds is stated; a file that is not ours is refused whole), an update check **on a tap** (never on page load; takes the highest published version rather
than the first listed; keeps "could not be reached" distinct from "up to date"), the Albrhi page itself never behind any gate (there is none now). Detail pages exist for Spotify, NextUp and Watch
(`tweaks/panel/src/{NextUp,Spotify,Watch}/`; NextUp and Watch also ship their own bundles). `SCIPanelScan` draws every row from whichever `Albrhi*.plist` filters sit beside
a dylib on the device, so a new tweak needs no panel change.

---

## 6. Licensing — removed in suite 1.95.0; what stayed behind, and what it taught

Albrhi had a licence layer from Panel 0.9.25 (enforced from 0.9.27): ECDSA-signed device-bound keys, short codes, a free week,
a seven-day token renewed from a Cloudflare Worker, store copies, and a native admin app on the owner's phone. **It was removed
because the owner decided Albrhi should be free** — every tweak, the suite and the standalone dylibs, with nothing to enter, renew
or check. Nothing else was meant to change, and **the way it was done is the point**: `SCIPanelAllowsThisApp()` — the one call every
tweak already made before installing a hook — stayed, and now asks only the master switch and the per-app switch (and answers YES in
a standalone build); so the only per-tweak edits were deleting a settings row and a localisation key. Build checks that demanded
the licence symbol now fail on it.

**What stayed behind — read this before switching anything off:**

- **The deployed Cloudflare Worker and its KV namespace are still running, untouched.** Installs older than 1.95.0 still enforce
  and renew against it; switching it off strands each of them (after the one-day grace they stop) until they update. Whether and
  when to switch it off is the owner's, and wants a last export kept first — **the KV namespace has no second copy** (the backup cron
  written in this repo was never deployed). The admin app that can export is still on his phone (`~/Desktop/Albrhi-App/*.ipa`); its
  source is in git history (`git log --diff-filter=D -- app/`).
- **The signing private key in `~/.albrhi/` still matters for the same reason**, and `.gitignore` keeps ignoring it.
- **`gh-pages` still serves `licence/revoked.json`, `licence/codes.json` and `/licence-panel/`** from earlier runs: the workflow no
  longer writes them, but the branch keeps what is there. Old clients treat a missing or non-200 revocation list as "nothing
  decided", so deleting them later is also safe; they were left because deleting is a decision and keeping costs nothing.
- Old tokens and stored keys remain in preferences, unread.

**Lessons that outlive the layer**, kept because they are about any gate, server or store:

- **Introduce a gate, prove it on a device, then enforce it** — one release that does both stops every existing install before
  a key exists to fix them with. Removing one is the same shape in reverse: keep the call, change what answers it.
- **Two defaults can point opposite ways on purpose**: the per-app switch reads absence as *off* (installing must not patch
  apps nobody asked about); the master switch reads it as *on* (nobody has pulled the handle). Both still hold.
- **A failed check is "nothing was decided", never a refusal**; only a 200 with real JSON counts as the server speaking.
- **No client-side check is unbreakable and none should be sold as such.** What a check buys is friction and revocation.
- **WebCrypto signs P1363 and `Security.framework` verifies DER**; the conversion does not fail loudly — it mints well-formed
  tokens every device refuses. Three signers existed and were made to agree byte for byte.
- **Workers KV**: `list()` returns at most 1,000 keys and a cursor (four callers read one page, silently, until a test that
  pages at three failed them); a delete lags about a minute and the list can return keys with no value; a write budget of 1,000 a
  day made a six-hour check-in sixteen writes a day for a phone with four patched apps.
- **A panel or a screen that lets you back in must never be behind the gate it controls**, and a control reading "turn the
  check off" is not a gate.
- **A trial is a convenience for honest people**, not a lock: any random-id scheme gives a second trial on a preference wipe.

---

## 7. Known state and open work

**Versions** (move these with the four numbers, not after them): Instagram **4.8.1** · YouTube **1.42.1** · X **0.22.0** · TikTok **0.26.5** · YouTube Music **0.10.0** ·
Panel **0.10.0** · Spotify **0.2.5** (unpublished) · NextUp **0.3.1** · Watch **0.6.1** · suite **1.101.21**.

**Confirmed on a device:** the YouTube direct route (1.34.0) and, before it, the Download Centre tab, History, the in-player save button and the action-row Save;
Instagram unsent-message keeping and its badge (410), story-seen hiding (439), story/repost downloads; X's draggable button, Communities/Profile tabs and Hide Spaces
(0.18.4: the strip and tab hidden, a Space opens); TikTok's button, photo posts, the 1080p60 external route and the cell placement; NextUp on iOS 16.1 (Music, Podcasts,
YouTube, YT Music, Spotify); Watch pairing and the update hold (watchOS 26.6 refused); Instagram copy of a caption (long-press) and of a comment (the Copy button in its menu, 4.8.0); TikTok's profile-background editor (0.25.0). **Not confirmed:** Spaces removal at `-setTabViews:` separately; TikTok's
comment-media Save row and photo-as-clip on every video type; YouTube's playback-error recovery's reload budget in the wild; the 1.34.0 fallback path to the playlist for
a login-gated video.

**Instagram features whose 410 selectors are confirmed but whose mechanics are not read** (a reference tweak names them; the 410 binary has them; nobody here has decompiled what they do, so none is built): stop
infinite Reels (`IGSundialTemplateMediaCompositionContainerView -sundialVideoPlaybackViewDidStartPlaying:`), stories not auto-advancing (`advanceToNextItemWithNavigationAction:` on five classes — the argument that
tells a timer from a tap is unknown), mark-seen-locally with exclusions (`IGStorySeenState -setForceSeenIds:`, `IGStoryViewSessionSeenStateManager -hasSeenMediaId:forReelPK:`), save a post without the collection
picker (`IGFeedItemUFICellConfigurableDelegateImpl -feedItemUFICellDidTapSaveButton:`), Story-viewer search, Following as the default feed (`IGMainFeedDataController`, `IGMainFeedViewModel -isSecondaryFeed`).
**The next step is a decompiler pass over those functions in the 410 binary**: plain Ghidra headless with `Decompiler Switch Analysis` and `Decompiler Parameter ID` off (REA's CLI cannot switch them off); on a
243 MB binary it was started and stopped by the owner before it finished, so the time it takes is unknown. `tools/doctor.sh` prints the installed and the newest REA, to review it now and then.

**Open work** (owner's priorities, highest first): (1) **confirm the deleted-messages log on a device** (which message shape the stream carries decides whether text is captured) and extend it to the MSYS delete path;
(2) **decide when to switch the old licence Worker off, after a last export** (§6 — until then installs older than 1.95.0 depend on it); (3) hiding the reels **seen** mark; (4) **publishing Spotify** — its own
workflow shaped like `buildnextup.yml`, or into the suite; (5) host tests for `SCIYTFragments` and TikTok's comparator (§3.5 says why they are not there); (6) the **WhatsApp
tweak** — postponed, Watusi 3's architecture already read; (7) CarPlay rebuilt from scratch in its own repository; settings profiles; crash isolation that disables a faulting
feature rather than the whole tweak.

**Working agreement.** The owner works in Arabic and pushes **directly to `main`** (no pull requests; `gh` is installed and signed in as `ibrahim2100`). **Since 2026-10-26 the owner has authorised pushing finished, checked work to `main` without asking each time** (the checks, the four numbers and a local build first; never a force-push, and nothing outside `main`); CI results are still not read back unless asked, so say that a push was not verified. A diagnostic is written when asked for, never on its own. When a report says "worked" it was run on the device; when it was only compiled or run on this
Mac, say so plainly. The README is a map of what exists, not a second source of rules: update it when a tweak's visible features or versions change.

**When something does not work on a device:** (1) the tweak's diagnostics — read what actually attached; (2) Instagram's magnifier scans the live view hierarchy and names the
real classes; (3) the speech-bubble files a GitHub issue with the whole report. That loop replaced several rounds of guessing — use it first. The device answers what a
class dump cannot (`class_copyMethodList`), and a report line that is blank rather than wrong names the stage to look at.
