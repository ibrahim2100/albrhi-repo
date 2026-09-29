# Albrhi NextUp — what changed

## v0.3.1

**سقف سجلّ التشخيص: ١٢٨ كيلوبايت لكل عملية بدل ٥١٢.** السجلّ مطفأ افتراضياً ولا يُكتب إلا إن شغّلته،
لكن سبع عمليات تكتب كل واحدة ملفها، فالسقف الذي يهمّ هو المجموع: سبعة في نصف ميغابايت = ٣٫٥ ميغابايت
على جهاز طلب صاحبه ميغابايت أقصى. الآن المجموع أقل من ميغابايت، ويقصّ الملف نفسه ويقول ذلك فيه.

## v0.3.0

**Brought up to NextUp 3 1.2 — two upstream releases by Yves, carried over unchanged.** Upstream is
GPLv3, so the code is taken as it stands and stays diffable against it; every line of this release
is his work, and what this port changed is confined to the settings page and the package identity.

**SoundCloud is the sixth app** (upstream 1.2, "Add SoundCloud support"). It reads SoundCloud's own
play queue like the other five, so the row shows what SoundCloud itself would play next. New in this
package: `NUSoundCloudProvider` and its hooks, a mach service and two Darwin notifications, the
process in the libSandy profile and in the injection filter, and one switch on the settings page
(`enabledSoundCloud`, bit 9 of the published state — declared in both places that must agree).
Written against SoundCloud 8.75.0, which is upstream's number, not something tested here.

**Playlists in Apple Music stop losing their cover** (upstream, "Unwrap playlist entries"). A queue
built from a library playlist wraps each track in a playlist entry whose `-song` and
`-artworkCatalog` answer nil, so the row showed a permanent placeholder, play-previous did nothing
and the history stayed empty. The song is unwrapped one level down now, behind `-respondsToSelector:`.

Not taken from upstream: its preference pane and header artwork, which this package replaced with
its own page. Nothing on the device needs migrating.

## v0.2.1

**"Free" is out of every description.** The tweak needs a licence; a package page saying it is
free was the first thing anybody read. The licence itself is unchanged and still named in full —
GPLv3 where it applies, MIT for the Watch pairing core — because dropping a word is not the same
as dropping an obligation, and the attribution those licences require is not negotiable.

## v0.2.0

**Its own row in Settings, and its own preference bundle to draw it.**

The settings page shipped inside Albrhi Panel — a different package, for a tweak that has
nothing to do with this one. Installing Albrhi NextUp without Albrhi therefore installed no
settings at all, and the row for it sat inside a panel for social-app tweaks.

It is **Settings › Albrhi NextUp** now, from a bundle in this package. Nothing about the
feature changed and no preference moved: the domain was always this port's own
(`com.yves.nextup3`), so every switch is where it was.

The filter also asks Albrhi's panel to ignore it. Without that the panel would have gone on
finding this filter and drawing a row per process in it — “SpringBoard”, “Music”, “Spotify” —
which is the mistake the grouped row existed to prevent, arriving from the other side.

## v0.1.6

**One line of upstream changed, and it is a safety fix rather than a port change.**

`NUIsNowPlayingActivityHost` read `_activitySceneDescriptor` with `-valueForKey:` inside an
`@try`. That runs the receiver's own code, and `@catch` only catches `NSException` — and this
runs **in SpringBoard**, where a feature that fails takes its feature down and a probe that
fails takes the home screen. It reads through this repository's guarded accessor now
(`shared/src/SCIKVC.h`), which checks the getter with `-respondsToSelector:` and touches an
ivar only when the runtime says it holds an object.

Every other line of the port stays diffable against NextUp 3 by Yves, as it was written down
that it would. The deviation is listed here for the same reason all the others are.

## v0.1.5

**A ceiling on the log file, which had none.**

Every line did `seekToEndOfFile`, forever. That is harmless while the switch is off — which it now
is by default — and it is not harmless the moment somebody turns it on to chase something and
forgets: SpringBoard runs for days and appends a line per track change. **A diagnostic that can
fill a phone is a bug of its own**, and "they will remember to turn it off" is not a design.

Half a megabyte, checked with a `stat` every 64 lines rather than every line, so the cost is
nothing while the log is on and nothing at all while it is off. Truncated rather than rotated: a
second file is a second thing to find, ask for and delete, and what matters in a log that has run
that long is what the process is doing *now*. The truncation writes itself into the file, so a
short log is never mistaken for a quiet process.

## v0.1.4

**The log is compiled in and switched off, instead of always writing.**

0.1.1 added `-DDEBUG=1` because the first install came back "it didn't work" with nothing to read.
That was right then and wrong now: the port is confirmed on iOS 16.1, and an always-on log writes
what each process is doing — **including the titles of what is playing** — into `/var/mobile/nu/`,
forever, from a package whose neighbour in this same source exists to stop watching being reported
at all. Compiling it back out would have made the next report undiagnosable, which is the trap
that produced the flag in the first place.

So both sinks stay in the binary and `NULogEnabled()` decides, from a preference that is **off**
until it is turned on in Settings › Albrhi › Albrhi NextUp › Advanced. Read once per process, at
the first line anything tries to write: a log switch is used by turning it on, reproducing and
reading, and the reopen is already part of that. Nothing is paid per line for a switch that is off.
The interface-drift probes follow the log rather than a build flag, so they are available exactly
when somebody is looking.

**And the `%ctor` announce and the sandbox profile now run once per process rather than once per
translation unit.** `NUApplySandbox()` is `static inline` in a header and kept its state in
`static` locals, so every file that included it got its own pair. A device log showed the cost:
fifty `ctor:` lines and fifty `applyProfile` calls across three SpringBoard launches — a hundred
of that file's hundred and seventy-four lines saying the same thing sixteen times over. The
retry semantics are unchanged, since only success was ever cached.

**The first line now names the build.** A log with no version in it is read as current, which is
the mistake this project has already paid for in another tweak: `ctor: Albrhi NextUp v0.1.4 …`.

The settings page's per-row default also travels on the row now instead of being inferred from the
key's name. `[key isEqualToString:@"Enabled"]` was a list of opt-in keys written as a comparison —
correct while there was one, and wrong the moment the log switch arrived, which would have
defaulted *on*.

## v0.1.3

**0.1.1 made the master switch opt-in and this republished it as on, which put the whole
change back.**

`NUPrefBool` trusts any bit the state word marks as known and only falls back to a caller's
default when the word says nothing about that key — so a published bit outranks the default.
`NUPrefsPublishState()` was still reading `Enabled` with upstream's fail-open `YES`, and
SpringBoard re-seeds that word from its own `%ctor` on every respring. On a fresh install, with
nothing ever written to the plist, that seed published master = 1 and every reader in every
process read the master as on. `NUMasterEnabled()`'s `NO` was unreachable.

The panel's own publisher was fixed for exactly this in Panel 0.9.1; the tweak's was not, so the
two halves of one decision disagreed — and the one that runs at every respring won.

**The rule under it:** a default written where state is *published* has to be the default the
reader would have used. They differ only when nothing is stored, which is the only moment a
default is consulted at all. The re-seed's own comment even names the failure it must not cause
— "NUPrefBool would fall back to the fail-open default" — while supplying that default itself.

Nothing else changed; every other key keeps upstream's `YES` deliberately, so one switch is
still enough to get a working tweak.

## v0.1.2

**The sandbox profile was never applied, and that alone is "it didn't work at all".**

Five of the seven injected processes are ordinary sandboxed apps. Each one registers a
mach service so the display side can ask it what plays next, and an app sandbox does not
permit that on its own — a libSandy profile grants it, applied from every `%ctor` before
any message is sent. Without it every lookup is refused and the row has nothing to show
on any surface, which is exactly the shape of the first report.

The profile is applied through `dlopen` on libsandy, and when the plain name does not
resolve — a jailbreak whose root is a randomised directory — the fallback finds the root
from this dylib's own path. That fallback looked for `/usr/lib/`, because upstream stages
its dylib into `<jbroot>/usr/lib/TweakInject/`. **Theos stages this package into
`<jbroot>/Library/MobileSubstrate/DynamicLibraries/` instead**, where that substring does
not occur at all, so the fallback found nothing and returned quietly.

Nothing about that is device-specific and it needed no log to find: unpacking the
published `.deb` and reading the paths it actually installs is what showed it. Worth
naming, because the same file already contained the answer — `NULocalization.h` derives
the root from *both* staging shapes, and only this copy of the pattern was left with one.

## v0.1.1

Two reports from the first install. One confirms a large piece works, one is a real
mistake of this port's own.

**Everything defaulted to on, and that is wrong here.** Upstream fails open: no plist
means every switch reads YES, which is right for a tweak somebody installed deliberately
for one app. This repository abandoned that reading once already and wrote down why —
`SCIPanelGate.h` states that absence must read as *off*, because Albrhi installs across
apps nobody asked about. It applies harder here than where it was written: this one
injects into SpringBoard and five media apps and draws on the Lock Screen. Defaulting all
of that on the moment the package lands is the opposite of what this project promises.

The master switch is now opt-in. The surfaces and the per-app switches keep upstream's
YES, so turning that one switch on gives a working tweak rather than a hunt through nine
more — and turning it off still stops everything. The panel page reads *and publishes*
the same split, because a screen showing the master as on while the tweak reads it as off
would be worse than either default alone.

**The settings page appearing at all is the confirmation worth naming.** It means the
package installed, the dylib is where the filter says, and `SCIPanelScan` collapsed a
seven-process filter into one row that pushes to a real page. That whole path works.

**Logging is compiled in, deliberately, while this port is unproven.** Upstream strips
`NULog` from FINALPACKAGE builds — correct for a tweak that works, and it left this one
unable to say anything at all when the first install came back "it didn't work": no log,
no os_log line, nothing to read. `-DDEBUG=1` is now in the Makefile. It gates exactly two
things and neither changes behaviour: the log, and the interface drift probes in each
provider's constructor that name the private class or selector missing after an app
update. Logs land in `/var/mobile/nu/nextup3-<process>.log`, one per injected process.
To be removed once the tweak is confirmed on a device.

## v0.1.0 — packaging notes

The port compiles: ten thousand lines built clean for arm64 and arm64e, linked, signed,
packaged both flavours, and released. Getting there took four packaging failures, none
of them in the ported code and every one of them now a `tools/check.py` rule or a
documented rule in `CLAUDE.md`:

- **`shared/tweak.mk` was appending JGProgressHUD, `SCIPanelGate.m` and
  `SCISubstrateShim.m`** to a tweak that uses none of them, and compiling code written
  for a 15.0 deployment target at this tweak's 14.2. This is the only tweak here that
  does not include that file; the flags worth having are copied into its Makefile.
- **An unclosed parenthesis in `control`** — opened on one line of the Description and
  closed on the next. Theos reads that file line by line and refuses to package.
  check.py rule 20.
- **`layout/DEBIAN/postinst` was mode 644.** `chmod +x` is a no-op on Windows, so git
  stored a script CI would not run. check.py rule 21 reads the mode from the git index
  rather than the filesystem, for exactly that reason.
- **`build.sh`'s roothide identity swap assumed `Conflicts` named nothing but the other
  flavour.** NextUp also conflicts with `com.yves.nextup3`, and the second list entry
  made an anchored pattern match zero times. It now swaps the identifier as a list
  element; checked against all seven controls.

The generator registry also needed a `nextup` entry — the workflow was passing the
depiction *slug* where its *key* belongs. That step runs locally in seconds, and running
it once before pushing would have caught it; this project's own rule about testing
scripts before shipping them applies to more than shell one-liners.

## v0.1.0

**A port of [NextUp 3](https://github.com/Yves000/NextUp3) 1.1.2 by Yves, under the GNU
GPL v3.** This is not an original tweak and the changelog should not read like one: the
design, the private-API research and very nearly all of the implementation are Yves's
work. What made carrying the code over lawful — rather than reading it for architecture
the way this project treats the unlicensed TikTok references — is that upstream is
GPLv3, the same licence this repository ships under.

**What it does.** A row under the now-playing controls showing what plays next: title,
artist and cover, on the Lock Screen, in Control Center and in the Dynamic Island. Tap
the cover to play that track now, or skip it, without opening the app. Five apps —
Apple Music, Apple Podcasts, YouTube, YouTube Music and Spotify — each read through
that app's own playback queue, so the row shows what the app itself would play next.

**How it is built, because it is unlike every other tweak here.** Seven injected
processes doing two different jobs: five providers inside media apps that read the
queue, and a display side in SpringBoard and MediaRemoteUI that draws the row. They
cannot see each other's memory, so they talk over a LightMessaging mach service (with a
libSandy profile, since an app sandbox cannot register a bootstrap service on its own)
plus Darwin notifications for the change and skip signals. One binary serves all seven;
every hook is chosen at runtime from the host process and the iOS major version, which
is how iOS 14.2 through 26 are covered from a single build.

### What this port changed

**The Settings pane was replaced by a page in Albrhi Panel.** Upstream shipped its own
PreferenceLoader bundle; every Albrhi tweak is configured from one place instead, so the
filter plist declares `SCIPanelGroupIdentifier` / `SCIPanelDetailController` and
`SCIPanelScan` collapses the seven-process filter into a single row that pushes to
`SCINUSettingsController`. Exactly the arrangement CarPlay already uses, and for the same
reason: nine switches do not fit in one switch cell.

**What the port deliberately did *not* change is the mechanism underneath.** The new page
writes to upstream's own CFPreferences domain and publishes upstream's own
`notify_state` token, bit layout included, because the reader compiled into the tweak
(`NUPrefs.m`, unchanged) has those names built in. Rebranding the domain would have been
a silent disconnect — every switch writing somewhere the tweak never looks. Both channels
are still written: CFPreferences is the value that survives a reboot, the token is what
makes a switch take effect without a respring.

**The `.lproj` tree is kept and the Settings bundle became resources-only.**
`NULocalization.h` finds its strings by walking from the tweak's own dylib path to
`NUPrefs.bundle`, so that bundle's name and location are load-bearing and stayed
upstream's. Twenty-seven languages survive, Arabic among them — which is how this port
satisfies the repository's bilingual rule without a second string table that would
duplicate what upstream already ships.

**Five `%orig` sites were reformatted, and nothing else in the sources was touched.**
`@try { %orig; }` and two one-line method bodies are fine under upstream's build, but
this repository has a ground rule about `%orig` needing its own line — bought with real
failed builds — and `tools/check.py` enforces it. Whitespace only; the semantics are
identical.

**A `Conflicts` on `com.yves.nextup3`.** Both packages register the same mach service
names, so they can never be installed together.

### Not confirmed on a device

Nothing here has run on a phone yet, and this one injects into **SpringBoard**. The
package is deliberately not published: `buildnextup.yml` builds it and stops, the same
withholding CarPlay is under. A wrong hook in an ordinary app kills that app; a wrong
hook in SpringBoard takes the home screen with it.

### Two `tools/check.py` rules were narrowed, not worked around

Both fired on this port and both were wrong, and the fix went into the rule rather than
into the code being checked:

- **Duplicate `@interface`** reported twelve pairs that never share a translation unit —
  `NUMusicProvider.m` imports neither `NUPrivate.h` nor the header that does. The rule
  now resolves each compiled unit's transitive quoted-import closure and reports only
  what clang would actually reject. The Instagram bug it was written for is still caught.
- **"Both a property and a method"** flagged seven ordinary hand-written getters. Its own
  comment names the real failure — `- (void)close` cannot be a getter *because it returns
  void* — so it now fires only on a void return.

`CLAUDE.md` already says a check that cries wolf gets ignored, and that the other tweaks
are the oracle: all six still pass unchanged after both edits.
