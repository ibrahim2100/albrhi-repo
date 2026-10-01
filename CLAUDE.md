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
knowledge · **6** licensing · **7** known state and open work.

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
| `tweaks/panel` | `com.albrhi.panel` | the Settings app — switches, licence, guide | in `com.albrhi` only |
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
- What they taught is kept where it applies below: the bypass-versus-payment line (§2), the `%ctor`
  gate and `SELFCONTAINED` lessons (§4), and CarPlay's display-mechanism notes (§5.9).

---

## 2. The lines this project draws

**Provenance.** Four kinds of source, treated differently, and the difference is the licence:

- **SCInsta (GPLv3, SoCuul)** is the ancestor of the Instagram tweak. Credit is a licence
  obligation, not a courtesy: it stays in-app, in the README, in the package metadata and in source
  headers. Never remove it.
- **GPL and MIT code that is carried over**: NextUp 3 by Yves (GPLv3), EeveeSpotify's ad blockers
  (GPLv3), YTMusicUltimate and YTMEnhanced (GPLv3), `watched` by 34306 (MIT, notice shipped inside
  the package), YTKACE's ad gates (MIT) and Mark02's YTPlaybackFix approach (MIT). Every ported file
  is kept diffable against upstream with each edit written where it is, attribution is in `control`,
  the changelog and the panel page's footer, and `tweaks/nextup/CHANGELOG.md` lists every change
  rather than letting the port read as original work.
- **Unlicensed references are read for architecture only, and nothing is copied**: BHTikTok and the
  al3raQe fork, NA9 For TikTok, VibeTok, BHTwitter, TWIGalaxy, `carsurf`, RyukGram, Regram, InstaPlus,
  and Legizmo (a paid tweak — its licence and DRM components were deliberately not examined).
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

**Hiding is not forbidding.** "Hide Spaces" in X set `voice_rooms_consumption_enabled: NO`, which tells
X the account may not *listen* to a Space at all, so a link somebody sent came back "unavailable". The
strip is hidden by withholding `-_t1_initializeFleets` and the tab by its own `audiospace` entry;
neither ever needed the key. The name on a switch is the promise, and «إخفاء» is not «تعطيل».

**Never erase what somebody already has because a switch went on.** X's `clearRecentSearches` exists
and is deliberately not called; keeping unsent messages never restores them *as though nothing happened* —
a tweak that leaves no trace of what it decided is deciding on your behalf without saying so, so the
message is marked.

**Wording.** "Free and open source" was removed from every description: the software needs a licence to
run. **Dropping a word is not dropping an obligation** — GPLv3 is named where it applies, MIT for Watch,
and every credit is exactly as before; the free trial is a feature, untouched. The Arabic name is
**البرهي**, never البرهان (a different word; eighteen strings once said it).

---

## 3. Repository mechanics

### 3.1 Layout

One tweak per directory under `tweaks/`: its own `Makefile`, `control`, filter plist, `CHANGELOG.md`
and `src/`. Nothing outside it knows which app it patches.

```
tweaks/<app>/        a complete Theos project (control Version drives the release)
suite/               com.albrhi — control, DEBIAN/preinst, CHANGELOG.md
shared/              tweak.mk, SCIPanelGate, SCILicense, SCILicenseUI, SCIKVC, Prefs/ — what every tweak shares
server/              the licence server (Cloudflare Worker, wrangler.toml)
app/                 the owner's native admin app for that server (Theos, fake-signed for TrollStore) + widget/
licence/             codes.json (hashes, never codes) and revoked.json, published beside the source
docs/                LICENCE-KEYS.md — read before touching anything licence-shaped
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
**Twenty-four rules, each from something that actually broke:**

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
`bash tweaks/youtube/tests/host/run.sh` (the transport). A hook needs a device; a parser does not, and several of
this project's most expensive bugs lived in exactly that layer. Open: the DASH ladder, the TikTok quality ranking
and the version comparison are pure functions with no tests yet.

### 3.6 Tools

| tool | what it is for |
|---|---|
| `check.py` | the rules above |
| `objc-classes.py` | a class's real method list, **declared property types**, ivars, class methods and **type encodings** out of a Mach-O's ObjC metadata; `--find-method` / `--find-ivar` answer "who answers this selector / owns this field" |
| `make-suite.sh` · `merge-control.py` | merge the staged trees into `com.albrhi`; refuse a tree that does not match the scheme; **keep the fields Theos computed and override only your own** (replacing `DEBIAN/control` wholesale once threw away what Theos had written) |
| `make-repo.sh` · `fetch-published-debs.sh` | build the APT index **from the published releases**; `WITHHELD_PACKAGES`; guard against two packages sharing name+version+architecture; label rootful/rootless/roothide |
| `make-depiction.py` · `release-notes.py` | Sileo depiction + HTML fallback and GitHub release bodies, **generated from the changelog** so they cannot go stale |
| `build-local.sh` · `build-dylibs.sh` · `build-app.sh` · `build-dav1d.sh` | local suite, standalone dylibs, the admin app, the AV1 decoder |
| `inject-dylib.py` · `ipa-inject.html` | put a dylib into an IPA; entitlements are read with `ldid -e` **before** anything is modified and handed back with `ldid -S<file>` (re-signing with `-S` alone erases them — TikTok carries twenty) |
| `licence.py` · `licence-panel.html` · `build-store.sh` | issue and revoke licences, keep the ledger, build a one-shop copy (§6) |
| `deb-edit.py` · `deb-edit.html` | edit `.deb` metadata (`label` appends `(rootless)`/`(roothide)`/`(rootful)`; `normalize` converts an xz control archive to gzip — the browser tool carries a hand-written DEFLATE because `DecompressionStream` is iOS 16.4+) |
| `make-logo.py` · `make-app-icon.py` · `repo-index.html` | repo icon in pure Python, app icon, the source's landing page (built from the live index) |

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
  undefined `MS*` symbol, and `SCILicenseAllowsProduct` compiled in) — `build-dylibs.sh` runs the same three checks
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
- **`SCI_SELFCONTAINED` builds answer the gate differently**, and for the licence the first answer on a standalone build is
  always "no": `SCIPanelAllowsThisApp()` is **cached, not frozen** (`dispatch_once` froze the unlicensed answer for the life of
  the process); `SCIPanelGateInvalidate()` drops it wherever a licence is entered or removed, and
  `SCIPanelGateWasAllowedAtLaunch()` keeps the first answer apart so the screen can say "reopen the app" only to those who need
  it (a process refused at `%ctor` installed no hooks, and none can be installed later).
- **Identity is a random value the panel provisions once**, derived from nothing about the phone: `MGCopyAnswer("SerialNumber")`
  is entitlement-gated per process (Settings sees it, a sandboxed app does not — one phone computed two fingerprints and every
  tweak stood down while the panel said `licensed`). On a jailbreak the panel owns it and a tweak must not provision its own
  where one exists; a dylib in an IPA falls back to the app's own defaults, and the test is **a read after the write**.
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
  410; Regram 6.3 was read for architecture only. **Not built:** a full log of deleted messages (needs text/sender/time saved before
  deletion) and hiding the reels *seen* mark (`/api/v1/clips/write_seen_state` still goes out).
- **Reels auto-advance** forces every gate a build has, each behind `class_getInstanceMethod`: `-isAutoAdvanceEnabled` and
  `-autoAdvanceToNextItem` on both, `-shouldForceEnableAutoScroll` on the Swift `IGSundialAutoScroll` in 439 only, `-autoScrollState`
  in 410 only. Hidden for a long time because the old hook forced the 410-only getter and left the shared gate alone — established by
  counting selectors in the real binaries, which is why both IPAs are kept.
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
  (`video/mp4`, `avc1`) and AAC LC (`mp4a.40.2`, not `isDrc`, default `audioTrack`) are offered — 1440p/4K are VP9/AV1 and would save and
  not play; `mp4a.40.5` is skipped. One entry per height, highest bitrate (the 60 fps copy where there is one). A chunk is the plain URL
  plus `&range=A-B` (8 MB, exact bytes with a plain 200), carried by `SCIYTParts`; the joined size is compared with the declared
  `contentLength` before anything is written. URLs carry **no `n` challenge** (checked by fetching a file). A video that needs a login is
  refused and goes to the playlist route; **a video that fails once is remembered for the session** and goes straight there
  (`+hasFailedForVideo:`). The report carries `direct:` lines (qualities, sizes, the writer's duration against what the sources claimed,
  or YouTube's own refusal). Checked on Mac with a 19 s clip, a 3:33 song and a 10:35 1080p60 film.
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
  `-didTapButton:`, and a button becomes the download button at `-setOfflineStatus:offlineability:`, not at construction. **Hold-to-save is kept but off by default** (1.26.0 moved downloading onto YouTube's button after hold-to-speed-up started downloading; the hold's own switch was
  missing in a second way — see §4.2).

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
once served every bar until 1.22.0), private hash lookup. **Quality ceiling** per Wi-Fi/mobile, full quality list. **Settings** open with two
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
  "saved N of M", **it asks first** (this picture or all, defaulting to the visible one), and a single picture can be saved as a 5/10/15-second clip
  with the post's own sound. Photos infers a type from the file name of a *data* resource: bytes are named by their first four bytes (a WebP
  announced as JPEG earned `PHPhotosErrorDomain 3302`), `originalFilename` set, JPEG re-encode as a last resort via `ImageIO`; downloads use
  `NSURLSession` because `+dataWithContentsOfURL:` cannot report an HTTP status. A format string is a callee with types (`%.0f` with an `int`
  literal read every clip as `0 seconds`).
- **Settings** (0.20.0) is a collection view with a layout per section — identity card, two-column category grid, option cards — one row away
  from a copyable Status report that names every number behind every feature; **hold two fingers anywhere**. Confirmations (like heart *and* double tap,
  follow on feed and profile) are off until turned on.
- Non-obvious refusals: `PIPOStoreKitHelper -isJailBroken` is not hooked (§2); the `tikwm` path was refused *as the fix, arriving quietly* and shipped as a
  switch once the owner asked knowing the trade — the earlier refusal was a different question, not wrong.

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
than the first listed; keeps "could not be reached" distinct from "up to date"), the licence page (§6). Detail pages exist for Spotify, NextUp and Watch
(`tweaks/panel/src/{NextUp,Spotify,Watch}/`; NextUp and Watch also ship their own bundles). `SCIPanelScan` draws every row from whichever `Albrhi*.plist` filters sit beside
a dylib on the device, so a new tweak needs no panel change.

---

## 6. Licensing — what it is, and what it is honest about

Albrhi has a licence layer (Panel 0.9.25, **enforced since 0.9.27**). Everything is in `shared/src/SCILicense.{h,m}`, `shared/src/SCILicenseUI`, `server/`,
`tools/licence.py`, `tools/licence-panel.html`, `docs/LICENCE-KEYS.md` and one page in the panel. **Read the doc before touching any of it.**

### 6.1 Principles

- **The two-release gap was the design.** Introduce the layer, prove it end to end on a real device (issued, entered, accepted, refused again once the key was
  removed), *then* turn it on — a gate introduced and enforced in one release stops every existing install before a key exists to fix them with. **The two
  defaults point opposite ways on purpose:** the per-app switch reads absence as *off* (installing must not patch apps nobody asked about); the licence reads
  absence as *on* (the question is whether the software may be used at all, and silence is not a licence).
- **No check on the user's own device can be made unbreakable, and this one is not sold as such.** Whoever holds the phone holds the file. What it buys: most
  people never crack anything, removing it is real work rather than one `if`, and — the part no client-side trick provides — **revocation**: a key that turns up
  on a forum is named in a list and stops working wherever the file is reached. Building as though it bought certainty is how a layer breaks paying users while the
  crack circulates anyway.
- **A tweak standing down is indistinguishable from a broken install**, so the panel says why (switches reading ON while nothing happens is a screen lying). **The
  panel itself is never behind the gate** (a Settings bundle does not ask), so nobody can be locked out of the screen that lets them back in; entering a licence is the
  way back in, and disabling the check never can be. **A licence gate with a user-visible off switch is not a gate**: enforcement and the server address were both
  preferences for a release (the panel ships to everybody, so every user had a control reading "turn licensing off"); both are unconditional now, stored values
  *ignored* rather than read, no one grandfathered. A staging address is a build-time define.
- **The gate is one line in `SCIPanelAllowsThisApp()`**, which every tweak already calls before installing a hook — no tweak changed. It answers YES whenever
  enforcement is off. Under `SCI_SELFCONTAINED` it once answered YES unconditionally (correct about the *switch*, wrong about the *licence*): every self-contained build
  was ungated. Caching and invalidation are in §4.6.
- **ECDSA P-256, not Ed25519**: Ed25519 on iOS means CryptoKit (Swift-only) or a vendored library, and the one Swift tweak here cost three things Logos does not;
  `Security.framework` verifies P-256 from plain Objective-C with no dependency. `kSecKeyAlgorithmECDSASignatureMessageX962SHA256` consumes exactly what
  `openssl dgst -sha256 -sign` produces. **WebCrypto signs P1363 and `Security.framework` verifies DER, and getting the conversion wrong does not fail loudly** — it
  mints well-formed keys every device refuses. Three signers exist (`licence.py`, the Worker, the browser panel) and agree byte for byte on sorted-key JSON and
  P1363→DER; the panel page's *own script block* was extracted and run in node against the real Objective-C verifier, both directions and against `licence.py`, and the
  page proves a freshly loaded key against the public half compiled into the tweak and refuses to issue when they differ. **The private key lives in `~/.albrhi/` and
  never enters this repository** (not in a build, CI or a message; `.gitignore` is a second line of defence).
- **Signature first, contents afterwards.** Three refusals need three sentences — expired, issued to another device, not a key — and `SCILicenseDescribeState` exists
  because asking for the *stored* key's status after a rejection describes the wrong key.
- **Only a 200 with real JSON counts as revoked**; a timeout, a 500 or a captive portal's login page must never withdraw a paying user's features. The check-in never
  blocks and is never waited on. **A failed check is reported as "nothing was decided", never as a licence problem.** And **reporting a refusal is not acting on
  it**: a 200 carrying `revoked` is unambiguously the server *deciding*, so the signed token is dropped at the next check (it once stayed valid for its remaining week).
- **The grace period is one day** (`SCILicenseGraceSeconds`, the single place it lives) — short, and the owner's decision recorded rather than argued. A phone in
  airplane mode for two days stops being licensed.

### 6.2 Server, renewal and cost

- **A Cloudflare Worker in `server/`**: requests arrive on their own and the device renews a **seven-day** signed licence in the background (`exp`); the licence's
  **term is `until`**, carried alongside so the screen shows the term (telling somebody who bought a year that it expires in seven days is a support message the code
  wrote itself). **The server decides; it is never trusted**: a token that does not verify against the compiled public key or is not for this device is dropped, so a
  hostile address earns a refusal and nothing else; https is required.
- **The offline path is kept deliberately**: a key issued by `tools/licence.py` verifies with no network, and that is the way back in when the server is unreachable —
  what makes "the server holds the only signing key" a decision rather than a single point of failure.
- **KV writes are a budget** (Cloudflare's free allowance is 1,000 a day). The check-in used to run every six hours with its last-check time in `[NSUserDefaults
  standardUserDefaults]` — *each app's own* domain — while the token it renews is in the shared one, so a phone with four patched apps asked sixteen times a day and
  renewed one token sixteen times. The cadence now follows the **licence's own end date**: a day ordinarily, eight hours in the last three days and after it ends, the
  thirty-minute last-chance rule untouched, taking whichever is shorter (a pure function of two numbers, twelve cases checked before any device). **The cost is stated:
  a withdrawn licence dies within a day, the design promising only "within a week" at worst.** The check-in says which product asks and at what version, written at
  most hourly per product, bounded to eight.
- **KV `list()` lags a delete by about a minute and returns keys with no value**: spreading the `null` made a row of nothing whose approve button posted `dev:
  undefined`. The server drops entries whose value is gone; the panel removes a row it has already acted on rather than re-asking a lagging index; a button re-enables in
  a `finally` and says why it failed. Knowing a store is eventually consistent is not handling every shape the inconsistency arrives in.
- **File the record before handing the user to another app**: the plans card sends the request to the server *then* opens WhatsApp — somebody who never sends the message
  still leaves a request in the panel, and that person meant to pay. The message opens whether or not the request landed.

### 6.3 Instruments, scopes, trial

- **Three ways in, three different instruments.** A device-bound **key** is the strong one. A **request** (`ALBREQ1.…`) is the phone asking: unsigned on purpose (nothing
  on a phone can sign it, nothing in it is worth forging; the trailing four characters are a *check* for a typo, never called a signature). A **short code**
  (`ALB-4K7M-9QX2-P3RT`) is for selling without a conversation: too short to carry a signature, so the device hashes the normalised code and finds the hash in
  `licence/codes.json` (**hashes, never codes**); redemption is the one moment this layer touches the network, once; **a code is not bound to a device until
  redeemed**, so one code works for everybody who has it until its hash is removed (the trade for being typeable — keys remain the instrument for anything that
  matters); **the clock starts at redemption**; typing is folded (no I, L, O or U: `O`→`0`, `I`/`L`→`1`, `U`→`V`; dashes, spaces, case, missing prefix) and device and
  issuer agree byte for byte. One row decides by the string's shape and routes an unrecognised string down the path that can ask the server — which one a person holds
  is a fact about how their licence was issued, not something to ask them.
- **Scope is `tier`**: absent or `suite` means everything; `apps` is the shared code across the separate tweaks; `app:<name>` one tweak alone; `store:<id>` a shop's
  copies. **The device answers an unrecognised scope as "everything"** (an old build meeting a newer server must not refuse a licence somebody paid for) while the
  **server refuses an unknown value at the point of writing**. Any place that writes `tier` must offer every value the server accepts — a picker missing the app scopes
  in the "issue by hand" card meant the licence a single-tweak buyer needs could not be minted. **Lifetime is `until = 0`**, not a scope (conflating them is how a
  lifetime for one app becomes a lifetime for everything). Absent keeps, empty clears.
- **The free week** is taken from the licence screen, once per device, marked by a KV record that is **never deleted** (the licence it creates expires and can be
  replaced, so anything shorter-lived would make it once a *week*); it refuses a device that already holds a licence. **A trial is a convenience for honest people, not a
  lock**: the device id is a random value written once, so wiping Albrhi's preferences earns a second trial, and there is no fix that does not reintroduce a real
  device identifier (refused for privacy and because it is not readable from every process). Written at the function as well as here. Clearing the marker is a decision,
  not a side effect. **Revoke and delete are different acts**: revoke keeps the record ("was it taken away or never issued" is answerable in six months); delete is for
  a test or duplicate.
- **Store copies** (`tools/build-store.sh`): one code, any number of devices, three months — a different product from the device-bound layer, by request (a shop's
  customers should not each need a device code). The code is in a dylib the shop hands out so anyone holding it can read it; what it buys is that it works on *those*
  builds and nowhere else (an ordinary Albrhi has no store id, so `store:<id>` matches nothing). **The shop's window lives on the server**: the code goes to `/v1/store`,
  the server returns an ordinary signed token (`tier: store:<id>`), and renewal, grace and revocation run through the existing machinery; unlimited devices is the
  server's rule (it counts them, showing both "ever activated" and "seen this week" — only the second answers "worth renewing"). The compiled date is a backstop for a copy
  that can never reach a server, deliberately the second answer.
- **Shipping three ways.** Instagram, YouTube, X and TikTok are built as individual `.deb`s and **standalone dylibs** alongside `com.albrhi`, which declares
  `Conflicts`/`Replaces` on them so the same dylib is never injected twice; the licence is what made that possible (`shared/src/SCILicenseUI` — the panel's licence page in
  UIKit — is presented from a row in each tweak's own settings). **One publisher still**: they are built by the suite's workflow and attached to its release, because a
  fourth publisher would race the others for `gh-pages`. YouTube Music and the panel ship only inside the suite; Spotify is unpublished; NextUp and Watch are their own
  packages.

### 6.4 The admin side

- **`app/` is the licence panel on the owner's own phone** (Theos, no Xcode project, fake-signed for TrollStore): the admin token in the **Keychain** (one string that can
  revoke every licence sold), **Face ID** asked only after a minute away (a lock that fires on every switch gets turned off; the shield goes up *before* the load), the
  address compiled in so it asks for the token alone, the token **injected** not typed. It is **native** now — five tabs (a sixth folds into "More"; Codes live under
  Licences, Settings behind a gear), a requests badge posted by `SCINotify` (a page inside a navigation controller does not own the tab bar's item), background refresh and a
  notification **naming the person, once per licence per day**, WhatsApp with the message already written (four editable templates, chosen by the licence's own state),
  copy on anything anybody would transcribe, per-licence history (the server keeps the last ten changes), which tweak/version each device runs, summary cards that open the list
  they counted with the filter pinned, **undo not a second confirmation** (a real five-second delay; leaving the screen sends it), a swipe never performing its first
  action on a full swipe, a cached answer offered with its age (in Caches, not a backed-up directory), an `/admin/export` backup handed to the share sheet (**nothing here
  has a second copy** — every licence, code and trial lives in one KV namespace with no export or history; an automatic backup is open work, §7), and a widget that is a second
  binary **never given the token** (it reads three numbers the app writes; a failure to build it is printed, not fatal). The web panel stays and is not the specification.
- **Searching a phone number is searching digits or not at all**: Arabic-Indic numerals folded, everything but digits dropped, last nine compared (`+966 50 000 0000`
  finds `0500000000`), and the digit path only runs when the query really is a number; `name` and `contact` stay separate fields. A search that found nothing and a list
  with nothing in it are different sentences. A dictionary of actions is a sheet in no particular order (`SCIChoice` in an array, the destructive one last); a licence
  panel's tab selector is `section[data-page]` (the bare attribute also matched the tabs and hid the navigation); `prompt()` cannot offer a choice, so a control built on
  one silently narrows the action; the approve call with no `days` once fell into the extend branch where a missing number is zero — **absent keeps**.
- A page that is a bundle of cards one scroll long is a scroll rather than a click — the licence panel has tabs; the admin app asks "reopen" only of those who need it.

---

## 7. Known state and open work

**Versions** (move these with the four numbers, not after them): Instagram **4.2.2** · YouTube **1.34.0** · X **0.19.1** · TikTok **0.20.3** · YouTube Music **0.9.3** ·
Panel **0.9.38** · Spotify **0.2.5** (unpublished) · NextUp **0.3.1** · Watch **0.6.1** · suite **1.82.0**.

**Confirmed on a device:** the YouTube direct route (1.34.0) and, before it, the Download Centre tab, History, the in-player save button and the action-row Save;
Instagram unsent-message keeping and its badge (410), story-seen hiding (439), story/repost downloads; X's draggable button, Communities/Profile tabs and Hide Spaces
(0.18.4: the strip and tab hidden, a Space opens); TikTok's button, photo posts, the 1080p60 external route and the cell placement; NextUp on iOS 16.1 (Music, Podcasts,
YouTube, YT Music, Spotify); Watch pairing and the update hold (watchOS 26.6 refused). **Not confirmed:** Spaces removal at `-setTabViews:` separately; TikTok's
comment-media Save row and photo-as-clip on every video type; YouTube's playback-error recovery's reload budget in the wild; the 1.34.0 fallback path to the playlist for
a login-gated video.

**Open work** (owner's priorities, highest first): (1) **a full log of deleted Instagram messages** — text, sender and time saved *before* deletion (only the badge exists);
(2) **an automatic backup of the licence KV** (the largest unmitigated risk in the project); (3) hiding the reels **seen** mark; (4) **publishing Spotify** — its own
workflow shaped like `buildnextup.yml`, or into the suite; (5) host tests for `SCIYTFragments`, the DASH ladder, TikTok's ranking and version comparison; (6) the **WhatsApp
tweak** — postponed, Watusi 3's architecture already read; (7) CarPlay rebuilt from scratch in its own repository; settings profiles; crash isolation that disables a faulting
feature rather than the whole tweak.

**Working agreement.** The owner works in Arabic and pushes **directly to `main`** (no pull requests; `gh` is installed via brew but not signed in — `gh auth login` is the
owner's step). A diagnostic is written when asked for, never on its own. When a report says "worked" it was run on the device; when it was only compiled or run on this
Mac, say so plainly. The README is a map of what exists, not a second source of rules: update it when a tweak's visible features or versions change.

**When something does not work on a device:** (1) the tweak's diagnostics — read what actually attached; (2) Instagram's magnifier scans the live view hierarchy and names the
real classes; (3) the speech-bubble files a GitHub issue with the whole report. That loop replaced several rounds of guessing — use it first. The device answers what a
class dump cannot (`class_copyMethodList`), and a report line that is blank rather than wrong names the stage to look at.
