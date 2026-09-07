# Albrhi — working context

Read this before touching anything. It is the accumulated reasoning behind the
project: what things are, why they are that way, and which mistakes have already
been made so they are not made again.

Owner: **Ibrahim Ismail AL-Rahn** (`@ibrahim2100`). Arabic is the working language;
code, comments and user-facing strings are English + Arabic.

---

## What this is

Tweaks for jailbroken and sideloaded iOS. **Eight of them**, four in one package and
four standing on their own:

| directory | package | what it patches |
|---|---|---|
| `tweaks/instagram` | `com.albrhi.tweak` | Instagram, tested on **410.1.0** |
| `tweaks/youtube` | `com.albrhi.youtube` | YouTube, tested on **21.30.5** |
| `tweaks/twitter` | `com.albrhi.twitter` | X / Twitter, tested on **12.15** |
| `tweaks/tiktok` | `com.albrhi.tiktok` | TikTok, tested on **46.4.0** |
| `tweaks/spotify` | `com.albrhi.spotify` | Spotify — **Swift and Orion, the only one** |
| `tweaks/ytmusic` | `com.albrhi.ytmusic` | YouTube Music — ads and background playback |
| `tweaks/panel` | `com.albrhi.panel` | the Settings app — the per-app switches |
| `suite/` | **`com.albrhi`** | the five app tweaks and the panel, in one package |
| `tweaks/nextup` | `com.albrhi.nextup` | SpringBoard + 5 media apps — what plays next, **a GPLv3 port, released on its own** |
| `tweaks/watch` | `com.albrhi.watch` | SpringBoard — Apple Watch pairing, **an MIT port, released on its own** |

**Albrhi NextUp is a port, and that is the first thing to know about it.** It is
[NextUp 3](https://github.com/Yves000/NextUp3) by Yves, carried over under the GNU GPL
v3 — the same licence this repository ships under, which is precisely what separates it
from the unlicensed TikTok references that may only be read for architecture. Attribution
is a licence obligation here exactly as SCInsta's is for Instagram: it is in `control`,
in the changelog, in the panel page's own footer, and it does not come out. Nearly all of
the implementation is Yves's; what this project changed is the settings pane and the
package identity, and `tweaks/nextup/CHANGELOG.md` lists every change rather than letting
the port read like original work.

**Locket is gone from this repository entirely, and the removal has two halves for a reason
worth keeping.** It was first taken out of the suite on request (its own package, its own
`locket-v*` releases, its own workflow), and then out of the project altogether on the
instruction to isolate it completely: `tweaks/locket/` and `.github/workflows/buildlocket.yml`
are both deleted.

**Deleting a tweak does not stop the source serving it, and that is the trap this file already
warned about from the other side.** `fetch-published-debs.sh` builds the index from what is
*published*, so five `locket-v*` releases would go on being gathered and offered forever, at
0.4.1, from a tweak whose source is no longer in the tree to fix. So `com.albrhi.locket` and
`com.albrhi.locket.roothide` are named in `WITHHELD_PACKAGES` **as well as** the directory being
removed. Both flavours, because they are separate package identities. The releases stay as
history; the source stops mentioning them.

The reasoning Locket contributed to this project is kept where it is referenced below — the
bypass-versus-payment line, the `%ctor` gate for self-contained builds, the `SELFCONTAINED`
makefile lesson — because those were paid for once and apply to whatever comes next. What is
gone is the tweak, not what it taught.

**Albrhi CarPlay was removed from this repository**, to be rebuilt from scratch in one of its
own. It was never in `com.albrhi` — it patched SpringBoard and Camera for a car feature with no
relationship to the social apps — and it was withheld from the source as well, having never been
confirmed on a device. The removal is recorded in full further down; the mechanism half of it is
the same one Locket needed and is the reason `WITHHELD_PACKAGES` exists: **deleting a tweak
removes nothing from a source built out of published releases.** `com.albrhi.carplay` and
`com.albrhi.carplay.roothide` stay named there, both flavours, or the index goes on offering
0.4.1 forever from a tree that no longer holds its source.

`tools/make-suite.sh` skips any `tweaks/*/` directory carrying a `.no-suite` marker file, which is
the only thing that keeps a tweak out of the merge. **NextUp is the one that has it now**; CarPlay
was the first, and its marker left with it.

The Instagram tweak is derived from [SCInsta](https://github.com/SoCuul/SCInsta) by
SoCuul under GPLv3. Original authorship is credited in-app, in the README and in the
package metadata — that is a licence obligation, not a courtesy. Never remove it.

**A seventh tweak, for TikTok — `tweaks/tiktok`, package `com.albrhi.tiktok`, version
0.3.0.** Wired into `suite/control` and `suite/DEBIAN/preinst` the same as Instagram,
YouTube and X, on the owner's own instruction rather than waiting for a device report
the way CarPlay's own withholding did — `com.albrhi` now bundles four social-app
tweaks, `buildsuite.yml`'s own "holds every tweak" assertion checks for
`AlbrhiTT.dylib`/`.plist` alongside the rest, and Albrhi Panel needed no code change at
all for a TikTok row to appear: `SCIPanelScan` already draws every row from whichever
`Albrhi*.plist` filters actually sit beside a dylib on the device, so a row is a
consequence of `AlbrhiTT.plist` shipping, not a fact this panel had to be taught.
Architecture was read from four unlicensed references: BandarHL's original
[BHTikTok](https://github.com/BandarHL/BHTikTok) and al3raQe's maintained fork
([github.com/al3raQe/BHTikTok](https://github.com/al3raQe/BHTikTok)), both by the same
author family the X tweak's own control file already credits; and two compiled ones read
later, **NA9 For TikTok** (a `.deb`) and **VibeTok** (a `.dylib`), both unstripped debug
builds carrying the exact `_ungrouped$Class$selector` Logos symbol this project already
uses to confirm a hook target precisely rather than by string co-occurrence — the same
technique Locket's own bypass review first established. All four are read the same
cautious way every unlicensed reference here is, for where TikTok is hookable, never for
the code.

**Every class this tweak hooks is now confirmed against a real TikTok 46.4.0 IPA, not
carried over from a reference that turned out to target an older build.** The app's real
logic sits in `MusicallyCore.framework` — 810 MB; the main executable itself is a 92 KB
stub — parsed by hand for its own class and selector strings, the same no-`otool` method
this project already uses everywhere else. Two names in BHTikTok's own source,
`AWEPlayVideoPlayerController` and `TIKTOKProfileHeaderView`, do not exist as exact
strings in that binary at all; plausible replacements were found
(`AWEPlayVideoPlayerControllerClass`, a `TTK`-prefixed profile family) but are not yet
confirmed enough to hook. **`AWEAPMManager` was misfiled as an ad-related class on first
reading, going only by its name** — reading BHTikTok's own hook showed it answers a
signing-info question (`+signInfo` → `"AppStore"`), a jailbreak-detection answer, not an
ad control; corrected in the same changelog entry that found it rather than silently.

Shipped in v0.2.0: an ad filter (`AWEAwemeModel`'s own `-isAds` mark, refused at
`-init`/`-initWithDictionary:error:` after `%orig` builds the object, never as a view
hidden afterward) and a jailbreak-detection bypass across six confirmed checks.

**v0.3.0 added download and privacy, and widened both existing features, entirely from
reading NA9's and VibeTok's own confirmed hook tables.** Download resolves
`AWEAwemeModel.videoModel.playAddr.bestURLtoDownload` the moment a kept (non-ad) model
finishes building — `-bestURLtoDownload` is confirmed twice over (a real string in the
binary and NA9's own hooked selector), while `-videoModel`/`-playAddr` sit only in
circumstantial string-table proximity the same way this tweak's own header already
flagged, so `SCITTMedia.m` walks the chain behind `-respondsToSelector:` at each step
and records which one failed rather than assuming it holds. Only the resolved URL is
kept, never the model. Privacy stops three report-to-server calls cross-validated
between both new references: a story's seen mark, a message's read-sync (its sibling
local-only mark is deliberately left alone, the same local/receipt distinction
Instagram's own story-seen feature draws), and a profile view. The ad filter now also
checks `isAd`/`isAdItem`/`isAdsOrPseudoAds` alongside `-isAds`, plus a separate
splash/launch-ad surface. Bypass gained six more confirmed checks.

**Two reference tweaks doing the same job can use entirely different selector names for
it, and reading only one of them is how a feature stays broken for eight releases.**
VibeTok was first read as having no download feature at all — it has a whole
`MSGDownloadSettingsViewController` — and where NA9 sends `-playURL` /
`-bestURLtoDownload` / `-originURL`, VibeTok sends `-h264DownloadURL` / `-playURLList` /
`-urlList` / `-originUrl` (that casing) for the same purpose. `-originURLList` is the
only selector **both** send, which makes it the strongest single candidate in the whole
table. The technique that settles this is the `_objc_msgSend$<selector>` stub symbol:
the compiler emits one only for a selector it actually saw being sent, so its presence
is real evidence where a bare string in `__cstring` is not — and its *absence* is
evidence too, which is how `-playAddr` and `-bitratePlayAddr` were demoted to last
(strings only, never sent) and how `-h264URL`/`-downloadURL` were caught as names this
project had invented. Grep both binaries for the stub before ranking a candidate chain.

**NA9's own download button works because it does not use TikTok's model chain at all,
and that is deliberately not reproduced here.** Its HD path fetches
`https://tikwm.com/video/media/hdplay/<id>.mp4` — a third-party scraper service, keyed
by the video's own ID, found as a literal format string in its binary. That is why its
button has been reliable for years across TikTok updates while this tweak spent eight
releases chasing an internal accessor: there was never an internal accessor in that
path to break. It is not built here for the same reason `app_attest_*` is not offered
in the X tweak and `Check0verPlus` was refused for Locket: it would send what the user
is watching to an unrelated third party, from inside a tweak whose neighbouring feature
exists specifically to stop watch activity being reported to servers. **Worth knowing
rather than rediscovering** — if the owner asks for it knowing the trade, that is their
call, but it does not arrive quietly as "the fix".

**`PIPOStoreKitHelper -isJailBroken`, named by a reference alongside the rest, was found
and deliberately not hooked.** v0.1.0's own reading had already refused
`PIPOIAPStoreManager`/`PIPOStoreKitHelper` as sitting inside the in-app-purchase surface
— the same shape of thing `Check0verPlus.dylib` was for Locket, reviewed and refused
there for taking money from the app's own developers rather than being a device tweak.
One confirmed jailbreak-check method on that specific class was not treated as reason
enough to cross a boundary this project had already drawn on purpose; the same question
is already answered by the six other checks that are hooked.

**v0.4.0 put the download button in the feed itself and rebuilt the settings screen,
both directly requested after v0.3.0 shipped download as a status-screen list only.**
`AWEFeedViewTemplateCell -configWithModel:`/`-configureWithModel:` — two of NA9's own
hooked selectors — are hooked not to place anything but to catch the model a hooked
method's own argument already hands over with no guessing needed, and the resolved URL
is stashed on the cell via an associated object. The button itself lives on
`TTKFeedInteractionStackView`/`TTKFeedRightInteractionStackView` (both confirmed present
as literal strings in the real 46.4.0 binary; VibeTok independently hooks the first for
an unrelated reason, which counts as a second confirmation), added as an arranged
subview the same way the X tweak's own immersive button avoids fighting `layoutSubviews`
— and it reads its item by walking up from the rail to whichever ancestor cell holds the
association, the same upward-search shape `SCITWFirstSaveableInStatusView` already uses.
The settings screen was replaced with a real grouped `UITableViewController` — status
pills, a Controls section with an icon and an explanation per switch, a Download list,
and a Status section with live per-hook numbers — in the shape the X tweak's own
`SCITWSettings.m` had already settled on. Privacy diagnostics now record into their own
set rather than sharing the bypass tally, and gained two more confirmed
`TTKProfileViewsVisitor` selectors (`-visit:`, `-p_shouldReportHasVeiwedProfileForUser:`)
found in the same pass.

**v0.4.1 answered three reports against v0.4.0 directly: the button still did not
appear, privacy was one switch for three different things, and the settings screen's
own text overlapped.** The overlap was a genuine, device-independent bug — the table
never set `rowHeight = UITableViewAutomaticDimension`, so a wrapped multi-line note
under a switch row was drawn on top of the row below it rather than pushing it down.
Privacy split into three independent preferences (`SCIPrefPrivacyStory`/
`…Messages`/`…Profile`), each its own row in a new Privacy section, rather than one
switch bundling a story-seen mark, a message read receipt and a profile view together.
The button's placement was moved off the rail's own `-layoutSubviews`/`-didMoveToWindow`
— this file's own recycled-cell lesson already says why those cannot be trusted alone
on a *reused* cell — and onto `AWEFeedViewTemplateCell`'s confirmed-every-reuse config
hook instead, which now does a depth-first search of its own subview tree for the rail
immediately after stashing the resolved item. Whether this actually surfaces the button
is still unconfirmed; the Status section's own report was widened from a bare count to
four distinct states so the next report names which one instead of only "no button."

**`com.albrhi` is what people install for the social apps.** The individual packages are
still built and still published, but the suite is the front door for Instagram, YouTube,
X, TikTok and the panel: one thing to install, one thing to update, and a new social-app
tweak arrives inside it rather than as a second download. It declares `Conflicts` and
`Replaces` on all ten of those individual identities (rootless and roothide) — and
that is not enough on its own, see the ground rule below. Neither CarPlay nor Locket is among
them: its identities were taken out of `Conflicts`/`Replaces` when it
left the suite, and its removal from the repository does not put them back — the suite has no
business deleting a package it never carried.

The repository doubles as an **APT source**: it builds itself, publishes releases,
and serves a Sileo/Zebra repo from GitHub Pages.

- Repo: `github.com/ibrahim2100/albrhi-repo`
- Source: `https://ibrahim2100.github.io/albrhi-repo/`
- Control panel: `…/deb-edit/`
- The tested versions above are the newest builds the developer's phone accepts. Not a
  compatibility ceiling; nothing is pinned to a version number.

**The repository name is lower case, and that is load-bearing rather than a style choice.**
Sileo on a rootless device could not read the source at all — no `Release` file found — while
roothide read the identical address without complaint. GitHub Pages paths are **case sensitive**,
the repository was `Albrhi-Repo`, and the request arriving at Pages was lower case: 404, measured
directly (`/albrhi-repo/Release` 404 against `/Albrhi-Repo/Release` 200, before the rename). Adding
the source again with the exact capitals changed nothing, which is what ruled out a typo and pointed
at the client lower-casing the path. **A source that serves perfectly and a source nobody can read
are indistinguishable from this machine** — the index was measured end to end and was sound
throughout. The fix was renaming the repository; nothing in the index or the workflow was wrong.
Do not reintroduce capitals into the repository name or into any published path.

---

## Ground rules learned the hard way

Every line here comes from something that actually broke.

**A class dump is of one app version, and an undated dump is a trap.** The follow-badge
crash fix was built from a dump nobody had dated; it turned out to be **439**, while the
device reporting had none of that crash because it runs **410**. Narrowing a lookup to one
accessor confirmed on 439 alone, in a tweak that serves 410, 439 and 441 from one build, is
how a crash fix silently costs a feature on a version it was never tested against. Date the
dump before trusting it — this project's own markers do it in one grep: `-autoScrollState`
is 410-only, `IGSundialAutoScroll` is 439-only.

**Do not guess at Instagram class names.** Reading a class dump tells you what
*exists* in the binary, not what the app *renders*. Two features were "fixed"
repeatedly against classes that were never instantiated. The Diagnostics page
(Settings → Diagnostics) exists precisely for this: it reports what attached at
runtime, and its magnifier button scans the live view hierarchy. Use it before
writing a hook.

**`-valueForKey:` is not a safe probe — it runs the app's code.** It calls the real getter
when one exists and reads the ivar directly when one does not; raising is its last resort,
not its first. The follow-status badge probed twelve guessed keys with it — `user`,
`account`, `dataSource`, `viewModel` and more — on every object up the responder chain, two
deep, from inside `-layoutSubviews`, behind a comment asserting that a missing key "just
throws (caught)". It was executing Instagram's own code dozens of times a second, and
changing a profile picture crashed the app.

**And `@catch` does not make a probe safe.** It catches `NSException`. A Swift getter that
traps, a failed assertion, or a half-initialised object are none of those: they end the
process and no handler ever sees them. A `@try` around a speculative call buys far less
than it looks like it does — it is why that comment was believed for so long.

The replacement asks for **one selector confirmed in a class dump**, guarded by
`-respondsToSelector:`, and steps over anything that does not answer. Same rule as the
class-name one above, applied to accessors: read what exists, do not guess and catch.

**Measure each stage before changing a pipeline.** The quality picker was
"fixed" three times against the wrong stage. The bug only surfaced once the code
reported `raw → parsed → deduped` counts separately.

**A diagnostic that reports the last event instead of a tally is not a diagnostic, and
it will send you fixing what is not broken.** The TikTok tweak's own
`SCITTMedia +lastAttemptState` recorded only the *most recent* resolution attempt — and
resolution runs on every feed model, the overwhelming majority of which are asked a
moment after construction, before their video data is populated. So the status row read
`every chain failed — -video answered nil` for three releases while resolution was
actually **working**: the in-feed button appears only when a URL has genuinely been
resolved, and the same report said it had been placed. Two releases were spent chasing
selector names that were already right, because one overwritten string outvoted a
counter that did not exist yet. The fix is the same shape as the quality picker's above
— count successes and attempts separately, name the chain that won, and show the last
failure's own text only while nothing has ever succeeded. **When a report and an
observable behaviour disagree, suspect the report**; and read every number on a
diagnostic screen for whether it is a tally or a snapshot before believing what it
implies.

**A non-nil object is not a working object.** `IGMedia.video` returns a hollow
`IGVideo` for photo posts. Check that a thing can actually do its job, not that it
is non-null — see `hasPlayableVideo:` in `SCIMediaDownloader.m`.

**And "it cannot do its job" is not "it is the other kind" — the answer to a capability
question must not be spent on an identity question.** `hasPlayableVideo:`, written for
the rule above, is correct and stayed correct; what broke was reading its `NO` as
"therefore a photo" because the photo branch simply came next. Saving a **repost** then
saved its cover image: Instagram models one as `IGRepostModel`, which carries a
`mediaId` string and *no media object*, so the `IGMedia` behind it is built with
`-initWithPk:` and is a stub until fetched — `-needsFetch`, `-needsMediaFetch` and
`-coverPhotoDidPartiallyLoad` are its own declared accessors, and the cover arrives
before the renditions. A real video, no playable rendition yet, a perfectly resolvable
cover photo, and one branch that could not tell "photo" from "video, not loaded". The
kind is asked separately now (`mediaDeclaresVideo:` — duration, DASH manifest, or
`mediaTypeEnum`, any one sufficient, a photo post satisfying none), and the media search
prefers a candidate that can resolve a video over the first one merely carrying a photo.
**Two questions that sound alike: "can I do this now" and "what is this".** Whenever a
capability check gates a fallback, check that the fallback is not silently asserting an
identity the check never established.

**And a capability check must ask the same question the capability answers — a gate
narrower than what it guards refuses work that would have succeeded.** Fixing the above
made the repost report `video — declared but no rendition resolved` with `-needsFetch`
answering **NO**, which ruled out the stub theory and exposed a second, older bug behind
it: `hasPlayableVideo:` decided whether to take the video path by asking
`getVideoUrl:` (`videoVersions`, `sortedVideoURLsBySize`, `allVideoURLs`), while
`downloadVideo:` behind it asks `getBestVideoUrl:`, **which also parses the DASH
manifest**. A video whose only rendition lives in that manifest was refused by a test the
download itself would have passed — and this project had already written the DASH parser,
correctly, for the quality ladder; it was simply never reached from the gate. Nothing was
missing but the question. When a guard and the thing it guards resolve the same resource
by different routes, the guard is wrong by construction, and it fails silently in the
direction of doing less.

**One collection, three ways in, and a filter on one of them looks like a filter that sometimes
works.** YouTube's `YTInnerTubeCollectionViewController` fills `sectionRenderers` through
`-addSectionsFromArray:`, `-insertSections:byPosition:error:` and
`-insertSections:byRelativePositionInSectionList:error:`. Only the first was hooked, so an ad
arrived at launch and was gone after a pull to refresh — the refresh coming through the filtered
door and reading as a fix. **The reported symptom named the shape of the fault exactly and was
attributed to hook ordering**, which it was not: the filter installs from `%ctor`, long before the
first request. When a filter works intermittently and the intermittency tracks *how* the data
arrived rather than *when*, count the entry points before suspecting timing — and tally them
separately, since "it still shows ads" has one more cause than the two the counters already told
apart.

**A fallback that covers for a fault turns a bug into a cosmetic complaint.** YouTube's floating
download button existed for a pivot bar this tweak could not read, and it fired on *any* failure to
build the tab — including 1.24.0's own bug, where hiding the create button left no room. What
arrived was "the downloads became separate from the screen", not "the tab is missing", and the two
readings were both true. The button is deleted rather than narrowed: the Centre is a tab or it is
nothing, the diagnostics say which, and Settings is the way in that does not depend on the bar.
**Ask of any fallback what it would look like if the primary path had a bug** — if the answer is
"working, slightly differently", it is hiding the report you need.

**A limit enforced in two places is two limits, and they applied in the wrong order.** Both of the
tabs this tweak adds are appended before the arrangement runs, and each append refused at six — so
History took the sixth slot *while the create button was still in the array*, the Download Centre
was turned away as "already full", and the create button was then removed a moment later. Five tabs
and the old floating button back, from two pieces of code that were each individually right. The
cap belongs to whichever step also *removes* things, and every other step defers to it: here that
is the arranger, and an append may exceed six exactly when an arrangement is stored to bring it
back down. **Adding and removing in one pass means the intermediate count is not a real count**, and
nothing should refuse work based on it.

**One container, two payload kinds, and reading only the first makes a real item look like no item
at all.** YouTube's `YTIPivotBarSupportedRenderers` holds either a `pivotBarItemRenderer` or a
`pivotBarIconOnlyItemRenderer`; the `+` create button is the second. Asking only for the first
returned nil, which read as "this entry has no identifier" rather than as "this entry is the other
kind" — so the create button could not be listed, named or moved, and the six-tab limit looked
tighter than it is. YouTube's own `-yt_pivotBarItem` answers whichever kind an entry holds, and both
kinds carry `pivotIdentifier`. **A nil from a field lookup means the field is absent, never that
the object is empty** — the same shape as `IGMedia.video` returning a hollow object and as
`hasPlayableVideo:` being read as "therefore a photo".

**The pivot bar's six-tab limit is `YTPivotBarView`'s own structure, measured rather than
believed.** The class declares `itemView1` … `itemView6` as six separate properties, with
`itemViews` the array of them — so a seventh item renderer has no view to be drawn in, and the
limit is not a number this tweak chose. It had been asserted in a comment for several releases
before anyone checked, which is the same shape as every other inherited assertion here.

**A feature that adds an item to a fixed-size list belongs in whatever screen manages that list,
not in a switch beside it.** The History tab shipped with its own switch for one release: the bar
holds six tabs, so switching it on added a *seventh* rather than replacing anything, and there was
nowhere to say what it should replace. A switch that adds a tab and a screen that arranges tabs are
two answers to one question — the same shape as X's named features versus hand-set keys, where
keeping two maps of one decision was where the bugs lived. History is a row in the arranging screen
now, starting inactive, and one screen enforces the limit for every tab at once.

**A chain confirmed hop by hop is the only kind that has worked here, and YouTube's History tab is
the fourth instance.** The tab needed a navigation endpoint, and the fields were read from the app's
own class metadata rather than from any tweak's strings: `YTIPivotBarItemRenderer` declares
`navigationEndpoint : YTICommand`, `YTICommand` declares `browseEndpoint : YTIBrowseEndpoint`, and
that declares `browseId : NSString` — three hops, each naming the next class in its declared
property *type*, which is exactly what `tools/objc-classes.py` prints and why it prints it. The tab
is then YouTube's own: `FEhistory` is a browse id the app already resolves, so there is no tap
handling here at all, no loading state and no back behaviour of ours to keep in sync. **The icon is
still painted onto the button afterwards**, because `YTIIcon`'s `iconType` is an enum whose values
are not readable from the binary — the same refusal the Download Centre tab already made, unchanged
by having read more of the app.

**SABR cannot be turned off from inside the app. This was measured to the end — do not
try again without new evidence.** Every format on YouTube 21.30.5 answers with an empty
`?cpn=` URL, because the client asks a server-side controller for byte ranges instead of
fetching files. The binary carries two gates that look like the answer, and neither is:

- `MLPlayerReloadContext -disableSABR` is **never consulted on a first load**. It belongs
  to the reload path.
- `MLOnesieRequestContext -bypassOnesie` *is* consulted, three to four times per playback.
  Forcing the getter changed nothing. That proved less than it appeared — code reading the
  ivar directly never passes through a getter hook — so the stored value was then written
  through the class's own `-setBypassOnesie:` until the getter answered YES on its own
  account. Twenty-two formats, still no URLs. **And the HLS manifest stopped arriving**,
  which is the one thing the downloader actually uses.

The metadata settles it: `content_length`, `init_range` and `index_range` all arrive
complete and the URL alone is withheld. That is a server-side decision about which clients
get plain files. Download sites get URLs because they ask as a television or an old web
player — clients Google has not migrated — which means impersonating a different client,
signed requests, and the `n`-signature, from inside the official app while signed in to a
real account. The counting hooks stay in `SCIYTSabr.x`; the switch was removed in 1.12.0.

**The TikTok downloader is built on the wrong architecture, and the reference tweaks say so
plainly once their *hooks* are read instead of their strings.** Five releases went into a
500-line URL resolver that walks candidate accessor chains looking for a link. NA9 does not
resolve anything. Its Logos symbols name exactly what it does:

```
AWEFeedViewTemplateCell$na9AddDownloadButton     the button goes on the FEED CELL
AWEFeedViewTemplateCell$downloadVideo            it calls TikTok's own download
AWEFeedViewTemplateCell$downloadProgress         and hooks the progress/finish callbacks
AWEAwemeACLItem$setWatermarkType                 forcing the watermark off
AWEAwemeModel$canDownload / isPreventDownload    forcing the permission
```

**It asks the app to download its own video.** That is why it gets the right clip at the right
quality without a resolver: TikTok already knows which video is on screen and which URL is the
download copy. Confirmed in 46.4.0: `AWEFeedViewTemplateCell`, `AWEAwemeACLItem`,
`AWEAwemeBaseViewController`, `downloadVideo`, `downloadProgress` and `watermarkType` are all
present; `downloadHDVideo`, `canDownload`, `isPreventDownload` and `AWEFeedViewTemplateNewCell`
are **not** — NA9 was built against an older TikTok, so its list is a map, not a manifest.

**And the button belongs on the cell, not on the interaction rail.** A cell hook fires once per
video, so the button cannot be missing on some of them; its position is a frame this code owns
rather than a slot in a stack whose arranged subviews TikTok rebuilds. Every symptom the rail
placement produced -- appearing on some videos, drifting sideways, needing its size copied from
neighbours -- is a consequence of being a guest in someone else's stack.

**Reading a reference tweak's strings is not reading its technique.** Three releases were spent
comparing selector *names* against ours before anyone dumped its Logos symbols, which took one
command and answered the architecture question outright.

**A correct principle enforced in the wrong place removes working features.** "Saving the wrong
video is worse than saving none" is right about the *save*. Applied to the *button* -- hiding it
whenever the preferred model lookup returned nil -- it shipped a TikTok build with no download
button at all, replacing a button that worked and was merely sometimes wrong about which clip.
Refusing a fallback belongs at the point of the irreversible action, never at the point that
decides whether the user can reach it.

**And a filter loop that only adds from inside itself cannot be asked for "everything".** The
accessor dumper matched names from within its keyword loop, so an empty keyword list meant the
body never ran: asking for an unfiltered dump returned nothing, which reads as "this class has
no accessors" and is the opposite of the truth. Any predicate offered as optional needs the
empty case written deliberately.

**A diagnostic that does not date itself will be read as current, and three releases were
aimed at one that was not.** TikTok's "last save attempt" line carried the identical byte
count and media id across three reports; each was read as fresh proof that the newest download
chain had just saved audio. Nothing had happened at all -- the button was in the wrong place to
be tapped, so no new attempt existed and the old string simply persisted. Any recorded state a
report prints should say when it was recorded, or say plainly that it is from this launch;
otherwise the absence of change is indistinguishable from a change that failed.

**And a constraint built from `bounds` at construction time is built from zero.** The same
button was sized from `reference.bounds` while being created -- before the rail had ever laid
out -- so it came out a square narrower than its neighbours and drifted to one side. Anchor
constraints resolve at layout time and cannot read a size that does not exist yet; a constant
copied out of `bounds` in an initialiser always can.

**A framework-wide selector dump says a name exists; it never says on what class.** This
cost two rounds on TikTok's downloader. `downloadAddr` appears in MusicallyCore's
`__objc_methname` and in NA9's binary, so it was tried first -- twice -- and it is **not on
`AWEVideoModel`**. The class's own accessors, printed from the device in one line, are
`downloadNoWatermarkURL`, `downloadURL`, `h264DownloadURL`, `bitrateModels`,
`audioBitrateModels`, `playURL`, `playLowBitURL`. Reaching for the binary was right; treating
a global name list as class membership was not. When the question is "does *this* class answer
*this* selector", the device answers it and a 785 MB dump does not.

**A framework-wide selector dump says a name exists; only class metadata says who answers
it — and `tools/objc-classes.py` reads that in one command.** This project has now lost three
releases to the same gap: `downloadAddr` (a real name, on no class here), `bestURLtoDownload`
(real in a reference tweak's older build, absent in ours), and — in 0.13.0, after both of those
were already written down — `bitRate`, which is a real name in MusicallyCore belonging to
`TTKECVideoBitModel`, while the feed's own `AWEVideoBSModel` calls it **`bitrate`**. Every
bitrate entry answered `-respondsToSelector:` with NO, scored zero, and the whole HD comparison
fell through silently to the SD chain. In the same release photo posts found nothing because
`AWEAwemeModel` has no `imagePostInfo` in this build (it answers `-images` itself) and
`AWEImageModel` has no `displayImage` (the links sit under `lightURLModel`/`localURLModel`/
`darkURLModel`, each an `AWEURLModel` with `originURLList`).

**And the same tool then found the same mistake one level deeper, twice in two releases.** A
photo post is an `AWEPhotoAlbumModel` under `-photoAlbum` whose list is `photos` — 0.13.1 fixed
the *wrapper* and kept asking it for `images`, so the post still read as empty. Elements are
`AWEPhotoAlbumPhoto` (`originPhotoURL` as posted, `thumbnailPhotoURL` a preview), not
`AWEImageModel`. Reading declared property *types* is what settles a chain rather than a single
hop, which is why the tool prints them: `photoAlbum : @"AWEPhotoAlbumModel"` names the next
class to ask about, and a chain confirmed hop by hop is the only kind that has ever worked here.

**A copyable report and the screen it mirrors are two lists, and a row added to one is
silently absent from the other.** `SCITTStatus` builds its report text in one method and its
table in another. The gear ladder went into the table, the user was asked to send that row, and
the report they sent had never contained it — a whole round trip spent on a row that did not
exist where it was being looked for. Anything added to one belongs in both, and this is the
same shape as the depiction that was written only into a Pages artifact.

**"saved 0 of 1" is a count, not a cause.** Photo saving fails three unrelated ways — the
download, the decode, the library refusing the write — and one number cannot say which, so
nothing could be fixed from it. Counted separately with the first real error kept. The decode
one had a real fix behind it: TikTok serves photos as WebP and HEIC, and bytes `UIImage` will
not decode can still be handed to Photos as the original resource, which also stops the save
re-encoding a file that was already fine.

**A Photos error is not a download error, and 3302 says which.** `PHPhotosErrorDomain 3302`
came back for pictures `UIImage` had already decoded, which rules out the bytes — it is the
library refusing the *format*. Data handed to Photos carries no file name, so it has to guess
the type, and TikTok serves some pictures as WebP. `PHAssetResourceCreationOptions.originalFilename`
is what tells it, and the save now falls back to a JPEG re-encode when the format is still
refused. Two posts behaving differently had nothing to do with where they were found, which is
what the user's own "what is the criterion" was asking — the answer was in the error code.

**Saving the whole post is a decision, and it was being made silently.** A photo post of
sixteen saved all sixteen on one tap. The fix is not a guess about intent: `AWEPhotoAlbumModel`
tracks the swipe in `currentIndex`, so the app already knows which picture is on screen — ask,
and default to that one when there is nowhere to present the question. **And a save with no
indicator is indistinguishable from a button that does nothing**, which is how "it saves
correctly" and "nothing happens" were reported about the same working code.

**A quality number on its own is not a diagnosis.** "It saves 720" has two causes that produce
an identical file — the picker chose wrong, or 720 was the whole ladder — so the Status screen
reports every gear offered with the chosen one marked. Same shape as the `raw → parsed →
deduped` counts the quality picker needed, and as the tally-versus-snapshot rule above.

The tool walks `__objc_classlist` and prints a class's real method list, so it answers class
membership rather than name existence, and it needs no `class-dump`. **Its one non-obvious
mechanic is worth knowing before trusting any similar script: in a modern arm64 image the
quadwords in `__DATA`/`__DATA_CONST` are not pointers** — chained fixups put the target in the
low 36 bits and the fixup's own metadata in the high bits. Unmasked, the class list parses as a
single entry and every lookup reports "not in this binary", which is a confidently *wrong*
answer rather than a visible failure. `otool -s` has a matching trap: it prints little-endian
words, so piping its hex through a naive decoder yields scrambled text that greps as clean
absence.

**TikTok's classes are not in TikTok's binary either, and a competitor's selectors are not
your build's.** `com.zhiliaoapp.musically` 46.4.0 ships a 91 KB executable and puts everything
in `MusicallyCore.framework` — 785 MB, **1,032,816 selectors** in `__objc_methname`. Dumping
that framework with `otool` (which *is* installed, contrary to what this file said for a
while) settled in one pass what three releases of guessing could not: `bestURLtoDownload`,
the first choice of seven candidate chains in the download resolver, **is not in this build at
all** — so those chains had never once run. Nor is `bitratePlayURL`, which had been added an
hour earlier as the HD fix on the strength of appearing in NA9's binary. NA9 was built
against an older TikTok. **Reading a working tweak's selectors tells you what worked for its
author, not what is in front of you** — the same mistake the X tweak's dead immersive class
was, repeated in one day on a different app.

**And "it saves SD" was one word.** `playAddr`/`playURL` is what the app *streams*, served at
a bitrate chosen for smooth playback; `downloadAddr` is what TikTok serves for saving, and
nothing in the tweak had ever asked for it. Confirmed alongside it, for later: `bitrateModels`
(variants with `-bitRate`, `-gearName`, `-qualityType`, each with its own `-playAddr`),
`HDRBitrateModels`, `SDRBitrateModels`, `allowDownloadWithoutWatermark`.

**X's classes are not in X's binary, and a hook table built by scanning it is empty.**
`com.atebits.Tweetie2` is 10,827 classes across 58 Mach-O images: the interface classes
live in `T1Twitter.framework`, and `TFS*`/`TAE*`/`TFN*` in `TwitterSPMMigration` and
`TwitterAppSPMMigration`. Reading only the executable finds none of them and concludes the
build has no switch layer. `NSClassFromString` asks every loaded image, which is why the
Twitter tweak binds that way and not by scanning.

**"A button was added" is not "a button appeared", and a rising add-count with nothing on
screen is the signature of an arranged-subview rebuild.** `ImmersiveActionsStackView` is a
Swift `UIStackView` whose arranged subviews X rebuilds; a button added to it is swept out,
found missing by tag on the next layout pass, and added again — eleven times in one session,
never visible. The counter was read here as success for a whole release. When an add-count
climbs and the screen stays empty, suspect the container is rebuilding its children, not
that placement is nearly working.

**The bar X actually extends is `TTAStatusInlineActionsView`, and it is drawn under a
timeline post *and* over a playing video.** One surface for both, which is what the three
earlier surfaces were each reaching for separately. It is not a stack view — it lays its
buttons out by hand in `-_t1_layoutInlineActionButtons`, so a subview survives; it answers
`-viewModel` directly; `-setViewModel:options:displayType:displayTextOptions:account:` is
its bind point, firing on reuse as well as first use; and X adds its own buttons to it
(`TTAStatusInlineGrokButton`, `…AnalyticsButton`, `…DownvoteButton`), so it takes another by
design. **TWIGalaxy hooks this, not the rail** — its binary names only `ImmersiveCardView`
and the dead `ImmersiveInlinePlaybackButtonsStackView`, plus `TTAStatusInline*Button` and a
selector `eleventhButtonTapped:`. Reading a competitor's binary for *which class* was right;
assuming its immersive references were live was not.

**And that class is gone. `ImmersiveInlinePlaybackButtonsStackView` is not in X 12.15 at
all** — established from a class dump of `com.atebits.Tweetie2`, not guessed: its sibling
`T1TwitterSwift.ImmersiveCardView` *is* in the same dump, so Swift classes are covered and
the absence is real. Five releases of button-placement work could not have worked, because
nothing was there to attach to. X rebuilt the immersive player around plugin views
(`ImmersiveEngagementActionsPluginView`, `ImmersivePlayPauseButtonPluginView`,
`ImmersiveTopRightActionsPluginsView`, ~30 more) and the action rail is now
**`ImmersiveActionsStackView`**, members `ImmersiveActionButton`. Same shape, new name — the
arranged-subview placement below was right and did not change. Both names are hooked now,
since a `%hook` on an absent class never attaches, and the report names *which* rail
attached rather than answering yes or no. **TWIGalaxy's binary still references the old
name, which is the trap**: a working competitor naming a class is not evidence the class is
in *your* build, and the dump is what settles it.

**The in-video save button goes on the immersive player's control stack, not on an inline
media view.** Four X releases put a floating button on `T1InlineMediaView` and it never
appeared inside the video — and reading TWIGalaxy's binary said why: that class is not in it
at all. What a working tweak hooks for an in-video button is one Swift class,
`_TtC14T1TwitterSwift39ImmersiveInlinePlaybackButtonsStackView` — the row of playback
controls in X's immersive (swipe-up, reels-style) player — and it adds the button there as an
**arranged subview**, so the stack lays it out beside like and share on its own. A floating
button fought `layoutSubviews`; an arranged one in a `UIStackView` is inside the picture by
construction. The media is reached by walking up to `ImmersiveCardView`, whose model knows
what is playing. The two older button surfaces are kept and the diagnostics report names
which of the three attached, so "no button" is never four silent reasons at once.

**A recycled table or collection view cell is never removed from its window, so
`-didMoveToWindow` fires once for its whole life and never again on reuse.** The inline and
status buttons were both triggered from `-didMoveToWindow` alone, and both appeared on the
first screenful of a fresh scroll and nowhere after — every cell recycled after that got a
new post and no signal to add or refresh a button for it. Opening a tweet worked regardless,
because a push builds genuinely new views, which do enter a window for the first time.
`-setViewModel:` is the actual bind point: it fires on first appearance and on every reuse
alike, and it was already being hooked on all four classes to count models for the
diagnostics report — the fix was asking it to trigger placement too, not only count.
`-didMoveToWindow` stays as a fallback for a view windowed before its model is ever set.

**And X answers its own feature questions in one place.** `-boolForKey:` on
`TFSFeatureSwitches`, `TFSCachingFeatureSwitchProvider` and `TPSTwitterFeatureSwitches`
(`B24@0:8@16` on all three) gates a large share of what the app does — so the tweak hooks
the decision rather than the fifty-one views that read it, which is the same lesson
Instagram's reels button cost twice. `-unsafePeekBoolForKey:` is hooked beside it: it is
the same question asked without the cache, and missing it means one screen obeying an
override while the screen beside it does not.

**What each of those keys *means* is not knowable from the binary.** X carries thousands
of lowercase underscored strings and only some are switches; the intersection with what
BHTwitter and TWIGalaxy carry is 260 strings, most of them OpenSSL symbols and image
names. So 0.1.0 shipped the recorder, not a table — and **the device answered**: 341 keys
over 345,902 questions on X 12.14, which is what 0.2.0's seventeen named features are built
from. Every key in that table was observed being asked; what each one *means* is still read
from its name, and the screen says so rather than implying more certainty than there is.

**Two switches for one intention is a bug even when both work, and adding features in bulk is how
it happens.** X 0.17.0 brought fifteen features in one pass and two of them duplicated something
already there: hiding suggested accounts had a blunt switch that hid *every*
`T1UserRecommendationView` alongside a timeline filter that recognises the suggestion's own view
model, and those two sat next to each other on one page; the view count had a named feature
answering `view_counts_public_visibility_enabled` and, on another page, a switch that hid the button
after X had drawn it. **Keep the half that knows what it is looking at**, and prefer answering the
app's own question over hiding a view — `TTAStatusInlineActionsView` lays its buttons out by hand,
so a hidden one leaves its space behind while a count never drawn leaves nothing. Delete the
preference with the row, or a value nothing reads outlives the feature.

**Three releases hooked browser classes for a decision that was a feature switch, and the report
had said so all along.** X's open-in-Safari went through `SFSafariViewController` (a name X uses
once in all its binaries), then `T1WebViewController`, then their shared base with every rejected
class recorded — and the device answered **`0 left to X`**: not the wrong class, *no* class.
`-_t1_loadInitialURL` is never called. The same report listed
`ios_in_app_article_webview_enabled` asked **72 times** and answered on, which is where X decides,
long before a browser object exists to hook. **A count of zero on a "how many did we turn away"
line is not a near miss — it says the hook is on a path nothing takes**, and that is the moment to
stop refining the hook. The recorder in this tweak exists for exactly this question and its report
already held the answer.

**When a family of classes shares a base, hook the base and allow-list the members.** X's
open-in-Safari was hooked on `T1WebViewController` with an exact-class compare, and links still
opened in the app: what X presents for a tapped link is a *preloaded* controller, a sibling
descending from the same `T1BaseWebViewController`. Twenty-six classes descend from that base and
most are not links -- sign-in, billing, analytics, and settings screens that merely happen to be
drawn with a web view -- so the members that count are listed **by inclusion**. A deny list would
send whatever X adds next straight out of the app until somebody remembered it; an allow list
leaves it alone until somebody looks. **And record the names that are turned away**: two releases
were spent guessing which class opens a link, and one line in a report answers it.

**Repairing a hook without checking the class is used is repairing a detail of something that was
never going to run.** X's open-in-Safari feature was hooked on `SFSafariViewController`; 0.17.2
found a real bug in how it read the URL, fixed it, and the feature still did nothing — because that
class is named **once** across all of X's binaries. The browser is `T1WebViewController`, whose base
declares `rootURL` and `-_t1_loadInitialURL`. **One grep for the class name would have come before
two releases of fixing its contents.** And the fix has a boundary worth keeping: the bouncer, login
challenge, monetization and password-reset browsers all descend from the same base, so the *exact*
class is compared rather than `-isKindOfClass:` — sending a sign-in flow to Safari is not this
feature, it is breaking the ability to log in.

**A description of a fault is evidence; a picture of it is proof — and here they disagreed.** X's
post-to-image came out reversed, described as the share button changing sides and Arabic reading
from the wrong end. That reads as re-layout, and one release was spent on that reading, reasoning
that a mirror would have reversed the glyphs too. The screenshot ended it in a glance: the post's
own *photograph* was mirrored and `@SaudiDCD` read `DCDibuaS@`. **Re-layout cannot reverse a
bitmap.** The cause is that UIKit mirrors right-to-left content with a transform and
`-renderInContext:` does not apply the receiver's own, so the render is the raw unflipped
arrangement, with bitmaps that are stored pre-mirrored to survive the flip. **Ask for the artefact
before theorising about the report** — and the correction is measured, not assumed: convert two of
the subject's own bounds points into window coordinates and see whether left lands right of right,
so a build that stops mirroring this way needs no correction and gets none.

**Rendering a view into an image context re-lays it out, and RTL is layout.** X's post-to-image
feature produced a cell laid out left-to-right: the share button moved from the bottom left of the
screen to the bottom right of the picture, and Arabic words read from their last letter. **The
report ruled out the obvious answer by itself** — a mirrored image mirrors the glyphs, and these
were the right way round, so nothing had been flipped; the layout had been rebuilt. UIKit
implements right-to-left as *mirrored layout*, resolved at layout time from the view's trait
environment, and an image context has no window and no traits, so it resolves left-to-right and
re-lays out the whole subtree — text runs included, which then get an LTR base direction.
`-drawViewHierarchyInRect:afterScreenUpdates:YES` asks for that re-layout by definition;
`-renderInContext:` does not, because it draws what each layer already holds. **When a snapshot
comes out differently from the screen, ask whether the snapshot path lays out again** — and note
that this is a right-to-left bug that would never be seen in an English-only test.

**A fallback for an unlikely case became the code path for the only case, and nothing said so.**
X's open-in-Safari hook read the URL with `[self valueForKey:@"initialURL"]` — a name
`SFSafariViewController` does not expose — so it was nil every time, and the branch written for
"we could not tell where this link goes, leave it alone" ran for every link ever opened. The
feature did nothing, and the report had no line that would have shown it. **Take the value from the
initialiser, where the caller certainly had it**, and count the failing branch: a fallback with no
counter is indistinguishable from a feature that works. The same shape sat one level down in the
post-to-image renderer, where `-drawViewHierarchyInRect:afterScreenUpdates:NO` returns a BOOL that
was being discarded.

### Licensing, and what it is honest about

**Albrhi has a licence layer as of Panel 0.9.25, and it has been enforced since 0.9.27.**

**The two-release gap was the design, not a delay.** Introduce the layer, prove it end to end on a
real device — issued, entered, accepted, and refused again once the key was removed — and only
then turn it on. A gate introduced and enforced in one release stops every existing install on the
next update, before a key exists to fix them with. **And the two defaults point opposite ways on
purpose**: the per-app switch reads absence as *off*, because installing the suite must not
silently patch four apps nobody asked about; the licence reads absence as *on*, because the
question is whether the software may be used at all and silence is not a licence.

**A tweak standing down is indistinguishable from a broken install**, so the panel says why:
switches showing ON while nothing happens is a screen actively lying, and somebody whose ad
blocking stopped concludes the tweak broke, not that their licence lapsed. The panel itself is
never behind the gate — it is a Settings bundle and does not ask — so nobody can be locked out of
the screen that would let them back in. The whole of it is
`shared/src/SCILicense.{h,m}`, `tools/licence.py`, `docs/LICENCE-KEYS.md` and one page in the
panel. Read the doc before touching any of it.

**No check that runs on the user's own device can be made unbreakable, and this one is not sold
as such.** The tweak is a dylib on a jailbroken phone; whoever holds the phone holds the file.
What a licence layer actually buys is that most people do not crack anything, that removing it is
real work rather than one `if`, and — the part no client-side trick provides — **revocation**: a
key that turns up on a forum is named in a list and stops working on every device that reaches
the file. Building as though it bought certainty is how a licence layer ends up breaking things
for paying users while the crack circulates anyway.

**ECDSA P-256, not Ed25519, and the reason is this repository's own history.** Ed25519 on iOS
means CryptoKit (Swift-only) or a vendored crypto library, and the one Swift tweak here cost
three separate things Logos does not. `Security.framework` verifies P-256 from plain
Objective-C with `SecKeyVerifySignature`, with no dependency at all.
`kSecKeyAlgorithmECDSASignatureMessageX962SHA256` consumes exactly what `openssl dgst -sha256
-sign` produces — the two sides were chosen together rather than made to meet afterwards, and the
round trip was proved on this machine before either shipped.

**The gate is one line in `SCIPanelAllowsThisApp()`**, which every tweak already calls before
installing a hook — the same reason the master switch went there rather than into eight `%ctor`s.
No tweak needed a change. `SCILicenseAllows()` answers YES whenever enforcement is off, so the
line changes nothing until a key exists to enter.

**Signature first, contents afterwards.** Reading a device id or an expiry out of a payload
nobody has authenticated is reading whatever the person holding the file decided to put there.

**Three refusals need three sentences.** "expired", "issued to another device" and "not a key"
are different problems, and `SCILicenseDescribeState` exists because asking for the *stored*
key's status after a rejection describes the wrong key entirely — the rejected one was never
stored.

**Only a 200 with real JSON counts as "revoked".** A timeout, a 500 or a captive portal's login
page must never withdraw a paying user's features because a coffee shop asked them to sign in.
The check-in never blocks and is never waited on: a licence check that can hold up a launch will
one day hold up every launch.

**The grace period is one day, which is short, and that is the owner's decision recorded rather
than argued.** A phone in airplane mode for two days stops being licensed. `SCILicenseGraceSeconds`
is the single place it lives.

**A placement written as "left" and "right" is a placement that is wrong in Arabic, and only in
Arabic.** The save button in YouTube's top row was measured as "the leftmost control on the right
half, one gap to its left" — every word correct in English. UIKit mirrors that row in a
right-to-left interface: the cast, subtitles and gear group moves to the left and the collapse
chevron to the right, so the old rule measured the chevron and placed the button by arithmetic on
it. Written as **leading and trailing** now, with the side taken from
`effectiveUserInterfaceLayoutDirection` — the same answer UIKit uses to mirror, asked of the very
view being measured, rather than a language check or a guess.

**A button placed beside somebody else's is placed by their numbers, and every one of those
numbers is a way to be wrong.** YouTube's save button moved into the player's top row and took
three device reports to settle, each a different measurement error, none of them a placement
error: it was written only on the fade signals while the overlay re-lays out on every resize
(so it drifted); it was anchored to "the leftmost control on the right", which is a different
button before playback starts and after, because the autoplay switch is hidden until then (so it
jumped); and its *size* came from the leftmost thing found there, which was a **container 96
points wide**, while the placement puts the button its own width plus a gap to the left of the
anchor (so it flew off, and "it goes far away" was arithmetic, not flight). What holds: anchor to
the control that *changes*, take size only from a real `UIButton` of plausible size, and convert
every frame into the coordinate space you are placing in.

**And writing a frame from `-layoutSubviews` is not what made the app unlaunchable — writing a
constraint constant was.** A constant measured from the row a view sits in invalidates the
constraint system upward, so the parent lays out again and the measurement moves again; setting a
*child's* frame asks the parent for nothing and settles in one pass. The distinction is worth
keeping precisely because the earlier rule, applied without it, leaves a button that cannot be
kept in place at all.

**A view-hierarchy scan asks the window what is on screen, and the window is the wrong question
whenever anything is presented over what you want to see.** UIKit
removes the presenting hierarchy from the window once a full-screen transition finishes, so the
watch page this was built to describe was not there — the report listed a navigation bar's buttons
and every line of it was true. The request is remembered and the scan is taken from the player's
own overlay now — **and from that view's own root rather than from the window**, which is the half
that took a second release: moving *when* the scan runs did not change *what* it walked, so it
described our settings table twice, accurately, and the second report looked exactly like the
first. A view that is off the window still has a root, and that root is the page being asked
about. **And its filter was five hand-picked words** (Action, Slim, Metadata, ELM,
Button) for a class whose name carries none of them, which is why it was being looked for at all:
a filter built from the names you expect cannot show you the name you did not. Every `YT…` and
`ELM…` class is printed now.

**That pair settled the actions row for good.** The live class dump showed
`-createActionViewsFromSupportedRenderers:` really is declared on 21.30.5 — the selector was never
the problem — while the construction count read **zero**: the app builds none of those rows. So
the row under a video in that build is a different class entirely and no renderer handed to this
one can become a button. Two numbers, one release, and an approach closed on evidence instead of
on a fourth attempt.

**`tools/objc-classes.py` reads a binary somebody downloaded; the device is the only thing that
knows what *this* build declares — and `class_copyMethodList` in a diagnostics page is that tool
run where it matters.** Three features here have been written against selectors confirmed in one
YouTube build and absent from another, each costing a release:
`-createActionViewsFromSupportedRenderers:` is real in 21.34.3 and was never once asked of the
21.30.5 in the reporter's hand. The YouTube report prints the actions row's own method list now.

**And "the class exists" plus "our method was never called" is still two faults, not one.** A row
class that is `[found]` and a hook that never fires means either the app never builds one — the
row is composed some other way and no renderer can help — or it builds them and fills them through
a selector this build names differently. Counting the *constructions* separately from the *calls*
is what separates them, which is this file's own "count the attempt, not only the result" rule
applied to a class rather than to a feature.

**Setting a state variable is not reporting it, and one sentence covered three investigations.**
The action-row feature recorded its state into a static at load and never wrote it to the
diagnostics page, so the report printed the empty-slot line — "no action row has been built" —
whether the class was absent, present and never called, or hooked and waiting. The same mistake
this file already records for the overlay button (written into SponsorBlock's slot) and for the
TikTok tally that reported the last event: **a diagnostic is not what a variable holds, it is what
reaches the page.**

**And the report already answered the question the feature was built to ask.** It says *"not one
of these buttons has been built"* about `YTSlimVideoDetailsActionView` — the class every action in
that row is drawn with — which is the same zero-construction finding recorded here for 21.32.4,
now confirmed on 21.30.5. A build that constructs none of them composes that row from elements,
and no renderer appended to it can become a button. **A class dump says what is in the binary and
has never once said what the app builds**, which is why the YouTube tweak now has the live
hierarchy scanner Instagram has had for a year: Settings › General, with a video open.

**Adding a button to somebody else's row means adding a renderer, not a view — and YouTube's
action row is the third place this has now been the answer.** The row under a video is
`YTSlimVideoScrollableDetailsActionsView`, handed its buttons through
`-createActionViewsFromSupportedRenderers:`; one more entry in that array and the app builds the
button with its own metrics, label, collapse behaviour and scrolling, so there is nothing of ours
to keep in sync. The chain was read hop by hop out of the app's own class metadata —
`YTISlimMetadataButtonSupportedRenderers.slimMetadataButtonRenderer` → `.button` →
`.buttonRenderer` → `YTIButtonRenderer{text, targetId, icon}` — and **`targetId` is what makes the
tap unambiguous**: a string this project wrote, rather than an accessibility label compared against
an English word on an Arabic phone. The icon is still painted on afterwards, because `YTIIcon`'s
enum is not readable from the binary; that refusal is older than the feature and unchanged by it.

**The launch is the one part of a process a tweak must not be inside, and the fix for anything
that must touch it is a moment rather than a rewrite.** YouTube's tab bar is changed from
`YTPivotBarView -setRenderer:`, which the app calls while building the bar — before it has drawn
anything, with iOS's watchdog counting. Switching that off made the app launch, which is how the
fault was finally located after three releases of reading. The change was then put back
**unaltered**, applied on the first `didBecomeActive` by calling the same method again with the
renderer it was handed. What that buys is not correctness, it is *recoverability*: the same bug,
a second later, costs a tab in front of somebody who can switch it off, instead of an app that
cannot be repaired from a settings screen nobody can reach.

**And the last thing changed is the first thing suspected, which here was wrong.** The in-player
save button was the newest work and the owner's own suspicion; it was on throughout the release
that launched cleanly, so it was innocent, and the culprit was months-old code that had never once
run. A suspicion ordered by recency is a heuristic, not evidence — the switch that isolates it is.

**Fixing a helper turns dead code live, and nothing in the tweak that owns that code says so.**
YouTube would not launch — logo, then killed — and three releases of reading found three real
faults, none of them the whole of it. The thing that had actually changed was one directory away:
`SCISafeValueForKey` answered **nil for every protobuf class** until the `-methodSignatureForSelector:`
fix, and `YTPivotBarView -setRenderer:` reads YouTube's own items array through it to append the
Download Centre tab, append History and apply a stored order — **while YouTube builds the bar
during launch, before the app has drawn anything.** That block had been dead since it was written.
The release before the app stopped launching is the release that woke it up, and this tweak's own
history contains no line saying the tab bar changed, because as far as it knew nothing had.

**So the question after fixing shared code is not "does it still compile" but "what starts running
that was not running before".** A `nil` that a caller reads as "not on this build" is a feature
that has been silently absent, and un-silencing it is a behaviour change in every tweak that calls
it. Grep the callers, not just the tests.

**`-description` on a protobuf is the whole subtree as text, and testing a feed with it is a cost
that grows on somebody else's side of the network.** YouTube's ad filter decides whether a section
is promoted by matching identifiers against `[section description]`, and the diagnostics sample
then described every *kept* section a second time and ran case-insensitive searches over those
strings. Tens of megabytes of string building on the main thread, on the first home response —
which is while the app is still showing its logo. **Nothing of ours had to change for that to stop
being survivable: the responses come from Google and they grew.** That is the shape worth keeping —
a cost proportional to data you do not control is a fault waiting for a quiet day. Described once
now and carried to the diagnostics, with a 120 ms budget per batch past which the rest goes through
unexamined and the report names how many.

**And a tweak may cost a feature; it may not cost the app.** Two releases were spent reading code
for the cause of a hang, each finding something real and none of them the whole of it, which is the
point at which the shape matters more than the identity. The launch guard watches for the app
becoming active and, eight seconds after the tweak loads, stands every expensive hook down for that
session and says so on the diagnostics page. **Its timer is on a background queue**, because a
main-queue one cannot fire while the main thread is the thing that is stuck — the failure it exists
for is exactly the failure that would silence it.

**A view that changes itself during layout asks for another layout, and three hooks doing it at
once is an app that never finishes launching.** YouTube sat on its own logo; turning Albrhi's
YouTube switch off opened it instantly. The code had not changed in a day, which is exactly why
reading it beat bisecting: what was new was two releases nobody had run on a device. All three
faults are the same shape — **work done on a layout path must be free the second time**:

- `-topControls` is a *getter YouTube calls while laying out*, and it carried
  `-bringSubviewToFront:`, two localised `stringWithFormat:` calls and a diagnostics write **per
  call**. Reordering subviews invalidates layout, layout asks for `-topControls`, and round it
  goes. It builds the button once now and returns `%orig` untouched afterwards.
- A constraint constant was written from `-layoutSubviews`, measured from `-topControlsHeight` —
  the height of the row the button is *inside*, so our own change moved the measurement. Applied
  on the visibility signals instead, only past a half-point threshold, and capped per player.
- Tab icons were repainted every pass. **`-setImage:forState:` invalidates a button's layout even
  when the image is identical**, and the pivot bar is built while the splash is up. The guard
  compares against images held in statics rather than fetched from an `NSCache`, because an
  eviction would hand back an equal image at a new address and quietly restore the loop.

`setNeedsLayout` inside `layoutSubviews` does not recurse immediately — it schedules the next
pass — so the symptom is not a stack overflow but a main thread that never goes idle, which is
indistinguishable from a hang and survives every crash log. **A launch that hangs with no crash
is the signature of work that re-arms itself**, and the first question to ask of any hook on
`-layoutSubviews`, `-didMoveToWindow` or a getter used by layout is what it does on the *second*
call.

### Separate tweaks, licensed on their own

**Each social tweak ships three ways now, and the licence is what made that possible rather than
the packaging.** Instagram, YouTube, X and TikTok are built as individual `.deb`s and as
**standalone dylibs** for injecting into an IPA, alongside `com.albrhi` itself — which declares
`Conflicts`/`Replaces` on all of them, so somebody who wants one tweak installs it *instead of*
the suite and the same dylib can never be injected twice. Spotify and YouTube Music are
deliberately not in that set: neither has a settings screen, so neither has anywhere to enter a
key, and a tweak that cannot be licensed is not one to sell on its own.

**The gap this closed is the one nobody would have reported.** `SCIPanelAllowsThisApp()` answered
`YES` **unconditionally** under `SCI_SELFCONTAINED` — written when Albrhi Panel was a jailbreak
package that could never be installed beside a sideloaded tweak, and correct about the *switch*
while being wrong about the *licence*. Every self-contained build was therefore ungated. The fix
is not in that branch alone: it needed somewhere to say no *from*, which is
`shared/src/SCILicenseUI` — the panel's licence page rewritten in UIKit, one file, presented from
a row in each of the four tweaks' own settings.

**Three kinds of licence, carried in a field that already existed.** `tier` has been on every
token since the server was written, defaulting to `suite`; reading it as a *scope* costs no new
field and leaves every licence already issued working exactly as before — absent or `suite` means
everything. `apps` is the shared code across the separate tweaks; `app:<name>` is one tweak alone.
**The device answers an unrecognised scope as "everything"** — an old build meeting a newer server
must not refuse a licence somebody paid for — while the *server* refuses an unknown value at the
point of writing, so a typo in the panel is caught where it is made.

**A scope picker in two of the three places that set one is a scope nobody can issue.** The
codes card and the edit dialog got the list and the *issue by hand* card kept "suite or trial" —
so the one route that mints a licence directly could not mint an app-scoped one at all, which is
exactly the licence somebody buying a single tweak needs. Three selects, one list, checked
together: any place that writes `tier` offers every value the server accepts.

**And "lifetime" came out of that field**, where it had been sitting as though it were a scope:
the term lives in `until`, and conflating the two is how a lifetime licence for one app becomes a
lifetime licence for everything.

**On a jailbreak the panel owns the identity, and asking "did my write come back" is not enough
to decide that.** One activation in Settings › Albrhi is meant to license every tweak on the
phone, and that only holds while they share one identity — so a tweak must never provision one of
its own where a panel exists. The obvious test fails: a sandboxed write to `com.albrhi.panel` is
**redirected into the app's own container and reads back perfectly from there**, so an app that
provisioned before the panel did would take a second identity, appear to succeed, and quietly stop
sharing the phone's licence. `SCIPanelIsInstalled()` reads the panel's own preference *file*
instead, and where it is found the tweak waits.

**Identity falls back to the app itself, and the test is a read after the write.** On a jailbreak
every tweak reads `com.albrhi.panel` through `SCIPanelGate`'s file fallback, so one identity serves
the install and one licence covers the phone — that behaviour is kept. A dylib injected into an IPA
has no such file, and a sandboxed write to that domain is *redirected* rather than refused, which
cost the Watch tweak a release: so the write is read back, and only a failure sends the identity to
the app's own defaults.

**The check-in says which tweak is asking and at what version**, and the panel has a page per
licence: device, scope, term, source, the code as it was typed, and every app the key runs in with
its version and when it was last seen. Bounded to eight products and written at most hourly per
product — a record that grows with every launch costs money to store and says nothing its last line
did not.

**One publisher, still.** The individual packages and the dylibs are built by the *suite's* own
workflow and attached to the same release: a fourth publisher would race the three that already
exist for `gh-pages`, and that race has served an index a version behind a release once already.
The job compiles all four tweaks anyway, so a tweak that will not build already fails it.

**A build that launches once has not fixed an intermittent fault, and the diff says which it is.**
YouTube hung on two builds and launched on a third — and the third differed from the second by
*diagnostic marks alone*, no functional line between them. So the honest reading is not "fixed" but
"intermittent", and the five reports narrow it usefully: **in every failed launch not one hook of
ours fired**, not even the request decorator that runs at +0.2s in a healthy one. The app stops
before its own first request and before reaching anything of ours, which is also why standing the
hooks down rescued nothing. `make NOHOOKS=1` builds a YouTube dylib with no hooks at all, for the
next occurrence: it separates a hook's *installation* from the dylib's mere presence, which no
amount of reading can.

**`_ASDisplayView` is not a class, it is every view in the app — and a hook on it runs before the
first frame, thousands of times.** YouTube's whole interface is AsyncDisplayKit, so a
`-didMoveToWindow` hook written to catch one ad card fires for every view the app ever puts in a
window. Each call read a preference and then asked the view for `accessibilityIdentifier`, which
on a node-backed view is not a field lookup: it can make the node materialise, scheduling work on
top of the work a launch is already doing. The trail a device left behind has exactly that shape —
a preference read at +0.0s and then nothing at all for the eight seconds until the guard gave up.
It stands aside until the app is active now, which costs nothing: a Shorts ad cannot be on screen
before the app is.

**And a diagnostic must be free on the path it is watching.** The first version of the launch trail
took a lock and searched an array on *every* mark — on that hook, that is the main thread
contending with itself, added to the launch it was meant to measure. It is one atomic read after
the first call now, with the milestone folded into a bit; a hash collision costs a missing line in
a report and can cost nothing else.

**`git checkout -- <file>` to strip a local version suffix threw away the day's work in that
file.** The marks that made the trail readable were added and committed in one round — except the
commit came *after* a checkout meant to remove only a `+N`, and the file went back to HEAD with
the marks in it. Two builds later the trail was missing its first two lines and the source no
longer had them. Strip the suffix the same way it was added: by editing the three values back.

**A gate answered once is a gate that cannot be answered again, and on a standalone build the
first answer is always "no".** `SCIPanelAllowsThisApp()` cached its result in a `dispatch_once`,
which is right on a jailbreak — the switch and the licence are set in the panel, before the app is
opened — and exactly wrong for a tweak installed on its own or injected into an IPA: **the app is
opened first, unlicensed, and that answer was then frozen for the life of the process.** Entering a
key changed nothing until the app was killed. From the outside it is reported as "I activated it,
then toggling any setting does nothing", which is precisely what it is: Instagram and YouTube ask
this gate inside *every* preference read, so every setting reads as off, and TikTok and X ask it
once in `%ctor` and install no hooks at all.

The answer is cached rather than frozen now, and `SCIPanelGateInvalidate()` drops it wherever a
licence is entered or removed. **What that cannot fix is the hooks a `%ctor` did not install** — so
the licence screen says to reopen the app rather than claiming everything is live, which is the
same honesty a switch that decides nothing fails at.

**The licence panel is pages now, and the tabs carry the same attribute the cards do.** Six cards
on one scroll meant "where is the thing I came for" was a scroll rather than a click, and which
card mattered changed by the day — which is exactly what a fixed order cannot serve. Every card
kept its element and its id; each gained the page it belongs to, and the tabs hide the rest.

**The one thing that had to be got right is the selector.** `document.querySelectorAll("[data-page]")`
also matches the tabs, so the first version hid the navigation along with the page and left no way
back to any other. `section[data-page]`. Proved in node against a small DOM rather than by looking:
switching pages shows only that page's sections, hides no tab, and marks exactly one.

### The panel as an app

**`app/` is the licence panel on the owner's own phone — a Theos application, no Xcode project,
fake-signed for TrollStore.** What it adds is exactly what a web page cannot have, and each is the
reason it exists rather than a nicety: the admin token in the **Keychain** instead of a browser's
storage (that one string can revoke every licence sold), **Face ID** in front of it, and an icon on
a home screen rather than a URL to find.

**The screen is the published panel loaded over https, deliberately.** Six tables, the dialog, the
digit-folding search and three signers that must agree byte for byte all exist and are used daily;
a second implementation in UIKit would be two of everything to keep in step, which is the failure
this file already records about maps, lists, and a screen and the report that mirrors it.

**The screen is native now, seven UIKit pages over the same admin API, and the web panel stays
where it is.** The reasoning above — that a second implementation of six tables is two things to
keep in step — is still true of the *tables*, and what changed is what the app adds that a page
cannot: a badge on the tab of requests still waiting, a background refresh that notices one while
the app is closed, and a notification about it. Neither is a copy of the other's screens; they are
one server seen from a desk and from a pocket.

**Five tabs, because a sixth is not a tab.** A `UITabBarController` on an iPhone shows five items
and folds every one after them into a "More" list — so the first build's seven put Stores, Codes
and Settings behind a grey table nobody would think to open. Codes moved onto Licences (a code is
a licence nobody has redeemed yet) and Settings onto the front page as a gear.

**A page inside a navigation controller does not own the tab bar's item.** The badge was written
to `self.tabBarItem` and never appeared: the tab bar holds the *navigation controller*, so the
count went onto an item nothing displays. And it cannot wait for the page's own fetch either — a
tab's page is not built until somebody taps it, which is exactly when the badge stops being
useful. `SCINotify` posts the count and the delegate puts it on the tab.

**A title set in `-viewDidLoad` is a title the tab bar asks for too early.** Every unvisited tab
showed an icon and no word. It is set in `-init` now.

**A dictionary of actions is a sheet in no particular order.** The approve sheet came out «ستّة
أشهر · رفض · مدى الحياة · شهر · سنة» — terms out of sequence with the destructive one in the
middle of them, which is where a mis-tap costs somebody a licence. `SCIChoice` in an array; the
red one is last by construction.

**A Latin run and a date on one Arabic line merge into nonsense.** «متجر na9 · 15/09/2026»
rendered as «متجر 15 · 2026/09/na9»: bidi reads the id and the digits as one left-to-right run
because the separator between them is neutral. `SCIRun()` wraps a run in FSI…PDI, which is the
fact the algorithm was missing. Same family as the post-to-image mirroring — **a bug that only
exists on an Arabic phone**, and one nobody would find by reading the format string.

**Zero means two different things and only one of them is ∞.** A licence's `until` of zero is
lifetime; a device's last-seen of zero is *never seen*, and the shared date formatter printed ∞
for both — a screen saying a device that has never once reported in is reporting in forever.

**What the app is for decides what belongs in it, and the web panel is not the specification.**
1.0.2 closed the parity gaps that were real work — issuing by hand, editing a name, a number or a
scope, deleting as distinct from withdrawing, the free-weeks record, and search — and added the
two things only a phone can do: **WhatsApp with the message already written**, since every licence
sold ends in one and the number is already on the record, and **copy** on anything anyone would
otherwise transcribe by eye.

**Nothing here had a second copy, and that was the largest risk in the whole project.** Every
licence sold, every code, every trial record lives in one KV namespace with no export and no
history: an account locked, a namespace deleted, or one wrong `delete` in that file, and there
is not even a list of who the customers are. `/admin/export` returns the raw records — the shape
whoever is putting it back together actually wants — and the app hands the file to the share
sheet, dated in its name, because a backup nobody can put anywhere is a screenful of text.

**Undo, not a second confirmation.** A second «are you sure» is dismissed unread by the third
day; a strip that says what just happened is read *because* something already happened. And it is
a real five-second delay rather than a pretend one — nothing is sent until it elapses, so calling
it back leaves no trace on a server that has no undo of its own. Leaving the screen sends it:
the row is already gone as far as the reader is concerned, and a destructive action that quietly
did not happen is worse than one that did.

**A cached answer is offered and its age is said.** Opening with no signal used to be an error
and an empty screen, while the answer from an hour ago covers every question except "has anything
changed". Showing it silently would have been worse than the error: every screen plausible, some
of it wrong, nothing saying so. The navigation prompt carries «بلا اتّصال — آخر تحديث قبل ساعة»,
and the copy lives in Caches, because a customer list has no business in a backed-up directory
when the server is its home.

**Two things were already in the records and nobody was reading them.** The server keeps the last
ten changes to every licence — which answers "when was this extended, and by how much", asked
constantly and until now only from memory — and every tweak writes its product and version on
check-in, which answers "which of these is worth my week". Both are screens, not features: the
data had been arriving for months.

**Editing a name was refused by the server, and the refusal was arithmetic.** An approval with no
`days` fell into the extend branch, where a missing number reads as zero and zero is answered
«no change asked for» — so changing a name, a number or a scope on its own earned a 400, which
from the app is a save that silently refuses. **Absent keeps** — the rule this very record already
followed for `name`, `contact` and `note`, applied to the one field that had been left out of it.
A device with no licence yet is refused in different words, because issuing one with no term is
not something to guess at. Proved in node against a fake KV before it went anywhere: renaming
keeps the term, an empty contact still clears, an explicit `days: 0` is still refused, and
extending still extends.

**A number worth acting on has somewhere to go.** The summary cards counted and then stopped:
«ends within a fortnight: 1» was the most important line on the screen and a dead end. Each card
now opens the list it counted *with the filter it counted by* — the search bar's own scope bar,
pinned open, because a filter applied while its control is off screen is a list that looks wrong
for no visible reason.

**The message is a template, not a string in the code.** Every licence sold ends in a WhatsApp
message, and the wording of a renewal reminder is exactly the thing that gets changed after the
third person misreads it. Four of them, editable, filled from the licence — and *which* one is
chosen follows from the licence's own state, because a renewal reminder sent to somebody who
lapsed last month reads as a shop that does not know its customers.

**The expiry notice names the person and says it once a day.** "Three licences end this week" is
a number to go and look up; a name is the next action. Once per licence per day, because the
background refresh runs whenever iOS feels like it and a reminder arriving six times gets the
notifications switched off — and the record of who has been told is pruned to who is still
expiring, or a renewed licence could never be reminded about again.

**A swipe never performs its first action on a full swipe.** The first one here withdraws a
licence or refuses a request, and a gesture that fires it without stopping costs somebody a
licence on a bumpy car ride.

**The widget is a second binary, and it is never given the token.** An extension is a process iOS
launches on its own schedule; a token that can revoke every licence sold has no business being
reachable from one. The app writes three numbers into the shared container and the widget reads
them — so a widget with nothing to show says the app has not been opened yet, which is what is
true, rather than a zero, which would be a fact about the licences. It is Swift against Xcode's
own SDK while the app is Objective-C against the pinned 16.2 one, so it is **built apart and
folded in afterwards, and a failure to build it is printed rather than fatal**: it is an extra on
a home screen, and the app is the thing somebody is waiting for.

**A phone number is searched as digits or it is not searched at all** — the panel's own rule,
carried over rather than rediscovered: Arabic-Indic numerals folded, everything but digits thrown
away, matched on the last nine, so `+966 50 000 0000` finds a licence stored as `0500000000`. And
the digit path only runs when the query really is a number, or three digits inside a name would
match every phone on the screen.

**A search that found nothing and a list with nothing in it are different sentences.** The second
sends somebody looking for a fault that is not there. The requests badge counts what is waiting
and never what the search left of it, for the same reason.

**A lock that fires on every switch is a lock that gets turned off.** The shield goes up whenever
the app leaves the foreground — that is what keeps a customer list out of the app switcher — but
the face is asked for only after a minute away, because leaving to WhatsApp and coming straight
back is the normal path through this app rather than an interruption to it.

**The address is compiled in, and the app asks for the token alone.** 1.0.0 required both, which
put a URL in front of somebody before anything had been tried — and one wrong character answers
«no such route on the server», a sentence about the server that is really about the typing. It is
the same decision the tweaks made when the licence layer shipped, arriving late here only because
the app was a web view first. A stored address still wins, empty clears it, and the row says which
of the two is in use. The 404 now names the URL it asked.

**A Latin field on an Arabic phone is laid out right-to-left, and a pasted token reads back
reversed.** Which is worse than it sounds: a token that *looks* wrong gets retyped by hand, so a
correct paste becomes a wrong one. Every field but a name forces left-to-right now.

**Declaring `CFBundleLocalizations` as `ar, en` made an English phone lay the whole app out
left-to-right** — title on the left, tabs reversed — while every string on it stayed Arabic. The
screens are written in one language and are laid out in that language's direction whatever the
phone is set to, so the array names Arabic alone. **A localization list is a layout decision**,
which is not what it looks like.

Every one of those was found by compiling the pages into a simulator app and looking, in one
sitting: an admin API stub outside the repository, seven screens, six faults. **The simulator is
still the cheapest tool here for anything drawn on a screen**, and this is the second feature to
prove it.

**`file://` was the obvious way to bundle the page and is the wrong one.** `crypto.subtle` exists
only in a secure context, so a page loaded from a file silently loses the signing path — and
*silently* is the word that matters. https keeps the page exactly what it is on a desktop.

Two details worth keeping: the shield goes up **before** the load, not after (a panel that appears
for a moment has already shown a customer list to whoever was looking), and the token is
**injected** rather than typed — a sixty-character admin token typed on a phone keyboard in public
is the one thing a screen lock does not help with.

**Sixteen asks a day for one token, and the ceiling was never an attacker.** The check-in ran
every six hours, and the last-check time lives in `[NSUserDefaults standardUserDefaults]` — *each
app's own* domain — while the token it renews lives in the shared one. A phone with four patched
apps therefore asked sixteen times a day and renewed the same token sixteen times, and every ask
is a write on the server's side. Cloudflare KV's free allowance is a thousand writes a day: sixty
phones and ordinary customers exhaust it between them, after which activation and renewal fail
for everybody until midnight.

The cadence is driven by the **licence's own end date** now rather than the token's: a day in the
ordinary case, eight hours in the last three days and after it has ended (where a payment is most
likely to be in flight), and the thirty-minute last-chance rule untouched for a token about to die
after days offline — the two combined by taking whichever is shorter. **The cost is stated rather
than hidden**: a withdrawn licence dies within a day instead of within six hours, and the design
already promises only "within a week". The table is a pure function of two numbers for one reason:
it can then be driven directly, which is how twelve cases were checked before any device saw it.

**"Close the app and open it again" was being said to everybody, and it is only true for some.**
A process allowed when it started has its hooks in place and comes to life the moment the gate is
invalidated; one refused at `%ctor` installed nothing, and no licence entered later can put a hook
in retroactively. `SCIPanelGateWasAllowedAtLaunch()` keeps the first answer apart from the cache so
the screen can tell those apart — **a relaunch demanded from somebody who does not need one is a
small untruth that teaches people to ignore the true version of the sentence.**

**And two faults in the redesigned licence screen were invisible until it was looked at.** The
cards were drawn in `secondarySystemGroupedBackground` on a `systemBackground` view — the same
white in light mode, so they were perfectly present and completely invisible. And the date came
out «Until 16 9 — 2026 سبتمبر days left», because `NSDateFormatter` follows the *system locale*
while this screen chooses its language from `preferredLanguages`: two settings, not one. The
formatter is told which language the sentence is in, the date and the day count are wrapped in
FSI…PDI, and the count goes through the same locale as the date — «١٦ سبتمبر ٢٠٢٦ — ٩ يوماً» rather
than one line carrying two numbering systems. Third feature running to the simulator, third time
it answered in one look.

### Store copies

**A build for one shop: one code, any number of devices, three months — and it is a different
product from the licence layer beside it.** Everything else here is device-bound, signed and
revocable. A store copy is none of those by request: a shop sells copies, and asking its customers
for a device code each turns the shop into a support desk. `tools/build-store.sh` makes them.

**What it is worth, said plainly rather than glossed.** The code is in a dylib the shop hands out,
so anyone holding it can read it — a credential that works on any device has nothing to check
against. What it does buy is that it works on *those* builds and nowhere else: an ordinary Albrhi
does not refuse a store token, it has no store id, so `store:<id>` matches nothing and the licence
is void. Exclusivity expressed where it can be checked rather than promised.

**And the shop's window lives on the server rather than in the dylib, which is the whole of what
the first version could not do.** A date compiled in cannot be extended without rebuilding, cannot
be withdrawn at all, and tells the shop nothing about how far its copies have spread — which is
the question asked before renewing. So the code goes to `/v1/store`, the server answers with an
ordinary signed token (`tier: store:<id>`), and every later renewal, grace period and revocation
runs through the machinery that already existed rather than a second one kept in step by hand.
Unlimited devices is the **server's** rule now, not an absence of one: it counts them, and the
panel shows both numbers — how many ever activated, and how many were seen this week, which are
different questions and only the second answers "is this worth renewing".

The compiled date stays as a backstop for a copy that can never reach a server at all, and it is
deliberately the *second* answer.

**`-D` with a quoted string survives make and the shell only as `'"$(VAR)"'`.** Written `\"…\"`
the backslashes are stripped on the way through and the compiler is handed a bare word — which
fails as a stray identifier if it is used, and silently defines nothing if it is not. The build
looked perfectly successful and carried no store code at all.

**And `strings` answers "no" about a three-character string.** Its default minimum length is four,
so a code like `na9` is invisible to it — and with `-n 3` it still did not report a string
`otool -s __TEXT __cstring` finds in the same file. Two confident wrong answers from one tool.
The check searches the file's bytes for `na9\0` now: unambiguous, and not confusable with
`na9.me`.

**A step copied between workflows brings its `if:` with it, and a condition naming a step that
does not exist is silently false.** The two new steps carried `steps.release_check.outputs.needed`
from `buildtweak.yml` into `buildsuite.yml`, whose gate is `steps.gate.outputs.release` — so they
were **skipped**, and the release step that lists their output failed on the missing files. GitHub
does not warn about a condition referring to a step id that is not in the job; it evaluates to
false and the step quietly does not run. Grep the workflow's own ids after pasting a step into it.

**Re-signing an injected app with `ldid -S` alone erases its entitlements**, and nothing says
so: the binary signs, the IPA builds, and the app is missing its keychain groups, its app groups
and its associated domains. TikTok carries twenty of them. They are read out of the *original*
binary with `ldid -e` **before anything is modified** and handed back with `ldid -S<file>` — read
first, because the moment a load command is added the signature is gone and with it any chance of
asking the file what it was allowed to do.

**`otool -L` prints the file's own install name before its dependencies, and every tweak here
installs under `/Library/MobileSubstrate/`.** A standalone check grepping that output for
"substrate" matches the file describing itself and calls a standalone build linked; skipping one
line is not enough, because the echoed filename comes first. `tail -n +3`. Both mistakes were made
in turn and both were caught by running the check on this machine before it ever ran in CI.

**"Free and open source" came out of every description, and the licence statement did not.**
The software needs a licence to run, and the first line of every package page said it was free —
one word, in eight `control` files, the source's own landing page and three in-app credit strings,
in both languages. What stayed is every word the licences actually oblige: GPLv3 named in full
where it applies, MIT for the Watch pairing core, and SCInsta's, EeveeSpotify's, NextUp 3's and
watched's authorship exactly as before. **Dropping a word is not dropping an obligation** — and
the free trial is untouched, because that is a feature somebody asked for rather than a claim
about the price.

**A page that ships in another package is a page that is missing whenever that package is
not.** Albrhi NextUp and Albrhi Watch were separate packages whose settings screens were built
into Albrhi Panel — so each drew a row inside Settings › Albrhi, a panel for Instagram, YouTube,
X and TikTok, and installing either tweak on its own installed something with no way to
configure it. Each ships its own preference bundle and its own Settings row now, as a Theos
`SUBPROJECTS` bundle beside the dylib (a space-separated `TWEAK_NAME` builds two dylibs, which is
not what a bundle is), with `src/Settings` pruned from the dylib's own `find` so one file belongs
to exactly one binary. **Nothing had to be migrated, because both tweaks already wrote into their
own preference domains** — `com.yves.nextup3` and `com.albrhi.watch` — which is worth checking
before any separation like this: the coupling was the *bundle*, not the data.

Two things generalise. **The shared furniture belongs in `shared/src/Prefs/`, not in a copy per
bundle** — the header view, the app cell, the badge art and the button action are compiled by
every preference bundle from one place now, and the kit declares `SCILocalized` in a header of its
own rather than importing a table by a relative path that resolves differently per include order.
And **removing a page from the panel is not the same as removing the tweak from the panel**: with
the `SCIPanelGroup*` keys gone, `SCIPanelScan` would have found those filters and drawn *a row per
process* — “SpringBoard”, “Music”, “Spotify” — which is precisely the mistake the grouped row was
built to prevent, arriving from the far side. `SCIPanelHidden` in each filter is what says "this
tweak is not Albrhi's".

**And the Arabic name is البرهي, never البرهان.** Eighteen strings across the panel, the YouTube
tweak and the licence site said the second, which is a different word.

**A screen that reads one field and an editor that writes another is a save that works and looks
discarded.** The licence table drew `name || note`; the edit dialog was written when only `note`
existed and never moved. Editing a licence approved from a request — which carries a real `name` —
wrote the new text into `note`, where nothing displays it while a name exists, so the row came back
unchanged after every single edit. Nothing failed, nothing warned, and the round trip was perfect;
the reported symptom, "it goes back to how it was", describes a write being ignored and was in fact
a read looking somewhere else. **When a field appears twice, the editor and the display are one
change, not two** — and the save now folds the old field into the new one so there is no second
place for the same fact to hide in. The absent-keeps/empty-clears rule below had already been
applied to `name` and `contact` and left `note` behind, which is the same omission one layer down.

**A sentinel value needs one function that understands it, not a rule remembered at each place
that compares it.** `until = 0` means a lifetime licence. The row's badge was taught that; the
counter above it was not, and neither was the sort — so a panel holding two lifetime licences and
one dated one announced **"0 valid of 3"**, which is a screen telling somebody their paying
customers have all lapsed, and put the lifetime rows at the bottom because zero sorts below every
date. Three places compared the same field and one of them had been fixed. `isLive`, `isLifetime`
and `termOrder` are the fix; the arithmetic was never the hard part.

**A phone number is searched as digits or it is not searched at all.** Nobody writes one the same
way twice — `0593010901`, `+966 59 301 0901` and `966593010901` are one number — so matching the
characters somebody typed misses the row nine times out of ten. The panel compares the last nine
digits of each, folds Arabic-Indic numerals first, and keeps `name` and `contact` as separate
fields rather than flattening them into a sentence, because a number buried in prose cannot be
compared to anything.

**`|| existing` cannot tell "absent" from "empty", and that makes a field uncorrectable.** The
licence's name fell back to its old value whenever a blank one arrived — so a name could be
changed and never removed. `body.x === undefined ? existing : clean(body.x)` is the distinction
that was missing: absent keeps, empty clears.

**`prompt()` cannot offer a choice, so a control built on one silently narrows what is
possible.** Editing a licence asked for a number of days in a browser prompt — which meant
"lifetime" could not be expressed at all, the name could not be touched in the same breath, and
deleting needed two stacked confirms whose *wording* carried the option a pair of buttons should
have. Replaced by one dialog belonging to the page, used for editing and for anything
destructive. **The tell is worth remembering: when an action has more than a yes and a string in
it, a browser box is not a small compromise — it is the reason half the action is missing.**

**File the record before handing the user to another app.** The plans card sends the licence
request to the server and *then* opens WhatsApp. The other order loses the case worth keeping:
somebody who closes the message, or never sends it, leaves no request in the panel and no trace
anywhere except a draft on their own phone — and that person meant to pay. The message opens
whether or not the request landed, because a failed request is a reason to talk to somebody, not
a reason to stop them talking to you.

**Two instruments are not two questions.** «Enter a key» and «Enter a code» sat side by side and
were reported as the same button twice. Which one a person holds is a fact about how their licence
was issued, not something they should have to classify — one row decides by shape, and routes an
unrecognised string down the path that can ask the server, so it still gets a real answer.

**A scroll view has no height of its own, and pinning its content to its edges does not give it
one.** That sets `contentSize`. The plans card had a scroller pinned to it and content pinned to
the scroller, and nothing in the chain said how tall anything should be — so the card collapsed
and `clipsToBounds` hid five perfectly-built rows. It appeared as a small empty box. The scroller
asks to match its content at less-than-required priority now, so it yields to the constraints
keeping the card on screen.

**And the thing that ended it was looking.** Three releases were aimed at this screen from
descriptions — "nothing appears", then "a small empty page". It was compiled into a throwaway iOS
app, launched in the simulator and photographed, and the answer was immediate. **A UI bug reported
in words is a UI bug being guessed at**; the simulator is available, the harness took one file, and
it is the cheapest tool in this repository for anything drawn on a screen.

**`keyWindow` is not a thing to look for inside a preference bundle, and a lookup that fails
quietly is worse than one that throws.** The plans card searched `UIApplication.windows` for a key
window and returned when it found none — in Settings, where this runs. The button did nothing, said
nothing, and was reported as broken, which it was. **Take the surface you already have** — the
presenting controller — and fall back down a named list, with an alert at the bottom of it rather
than a `return`.

**And an autoresizing mask measures against the superview's bounds, which move on a scroll view.**
The last fallback surface is a `PSListController`'s view, and a `PSListController`'s view *is* its
table — so the overlay would have slid off screen at the first touch. Constraints on four edges
work on every surface; a mask works on the one it was tried against.

**An absence answers nothing.** The free week row was hidden once a device had a licence, on the
reasoning that a row which can only be refused reads as broken. The opposite happened — somebody
went looking for it, found nothing, and concluded the *button* was broken. "Why is there no trial
here" is a real question and the row is the only place to answer it: greyed, with the reason on it.

**Reporting a refusal is not acting on it, and a licence layer that only reports keeps working.**
The renewal call received `revoked` from the server, handed that up to the caller, and left the
signed token in place — valid for its remaining week — so withdrawing a licence changed nothing on
the device for up to seven days. **The fix was already latent in the design**: everything here
turns on the difference between the server *deciding* and the server *saying nothing*, and a 200
carrying `revoked` is unambiguously the first. Acting on that one alone drops the token at the
next check while a timeout still cannot cost a paying user anything.

**Revoking and deleting are different acts and a panel needs both.** Revoke marks the licence
withdrawn and keeps it, so "was this taken away or did I never issue it" is answerable six months
later; delete is for a test, a duplicate or a mistake. The trial marker is only removed when
explicitly asked for, because it is the one record meant to outlive everything else — clearing it
hands that device another free week, which is a decision rather than a side effect.

**A trial is a convenience for honest people, not a lock, and it is worth building only if
nobody mistakes it for one.** The free week is once per device, marked by a KV record that is
never deleted — the licence it creates expires and can be replaced, so anything shorter-lived
would make it once a *week*. But the device id is a random value the panel writes once, so wiping
Albrhi's preferences earns a second trial, and there is no fix that does not reintroduce a real
device identifier — refused here for privacy and because it is not readable from every process.
**Written down at the function, not only here**, so the next person to tighten it knows what they
would be trading.

**"Lifetime" is `until = 0`, and it cost one line because the shape already existed.** Every date
comparison in this layer was written `until > 0 && …` from the start, since a licence with no end
was always something it had to survive. A feature that fits an existing shape is a feature that
needs a name, not a branch through every check — and the screen shows the word rather than a blank
where a date would be, which is the same bug as the empty value row one release earlier.

**A control that cannot do anything is not drawn.** The paid rows do not exist in a build with no
contact number, and the free week disappears once there is a licence. A button that opens nothing
is worse than no button on this screen in particular: the person has already decided to pay by the
time they press it.

**A `PSTitleValueCell` asks for its value through the get selector, and this was found twice.**
Setting the `value` property with `get:NULL` draws the title and an empty space. `SCIPanelRoot.m`
found it, fixed it and wrote it down in exactly those words — and `SCIPanelLicence.m` was then
written the same way, so the licence state and the licence term were both blank on the one page
whose job is answering that question. **Rule 23's shape again: a rule that lives only in prose is
a rule broken by whoever did not read that file**, so it is rule 24 now, narrowed to the real
mistake — a title-only cell of that kind is an ordinary row and there are three on the root page.

**A key that `list()` returns is not a key that still has a value, and spreading the `null` it
answers with makes a record out of nothing.** Approving a request in the panel deleted `req:<dev>`
and the very next `/admin/state` still listed it — Cloudflare KV's list index lags a delete by up
to about a minute — so `{ key, ...null }` produced a row carrying an id and no fields at all. The
panel drew a blank row whose approve button then posted `dev: undefined`, which the server
correctly refused. **From the outside that is a button that does nothing**, and it was reported as
exactly that.

Three fixes, because it was three faults stacked: the server drops entries whose value is gone
(a record that is gone is gone, and the honest answer is that there is nothing there); the panel
removes a row it has already acted on rather than re-asking an index that lags — believing the
answer you were just given is not optimism, it is declining to prefer the staler of two answers;
and a button now re-enables in a `finally` and says why it failed, because the version that
disabled itself and waited for a redraw is what turned a 400 into "it hangs".

**And eventual consistency is not a footnote you write down once.** It was already stated on the
panel's own face, and it still produced a bug — because knowing a store is eventually consistent
is not the same as handling every shape that inconsistency arrives in.

**A licence gate with a user-visible off switch is not a gate, and one shipped for a release —
along with a settable server address, which is the same hole wearing a different hat.** Enforcement
was a preference so the layer could be introduced before it was enforced, which was the right
order. What it missed is *where a preference lives*: in the panel, which ships to everybody, so
every user had a control reading "turn licensing off". Both are unconditional now, and a device
that already used them is not grandfathered — the stored values are ignored rather than read,
verified with enforcement set to NO and the server pointed elsewhere.

**The address one is worth keeping for its shape rather than its severity.** A swapped server could
never mint a working licence, because every token is verified against the compiled-in public key —
the worst it achieved was no licence at all. It came out anyway: **a control that cannot help a
user and can only confuse one is not worth the row it occupies**, and the next reader should not
have to work out which of the two it was. A staging address is a build-time define, which is where
a decision made by whoever builds the package belongs.

**And the escape hatch has to be one that is not also a way around.** The panel never asks the gate,
so the screen that enters a licence is always reachable, and an offline key verifies with no
network. Entering a licence is the way back in; disabling the check never can be.

**There is a licence server as of Panel 0.9.28 — a Cloudflare Worker in `server/` — and the
offline path is kept deliberately, not by inertia.** With a server configured, requests arrive on
their own and the device renews a **seven-day** signed licence in the background. With none, a key
issued by `tools/licence.py` verifies with no network at all. The second is the way back in when
the first is unreachable, which is the only thing that makes "the server holds the only signing
key" a decision rather than a single point of total failure.

**Seven days is the whole live-control design, and both halves matter.** Revocation becomes real —
withdraw a licence and the device stops within a week, with no list for it to decline to fetch —
while a flight or a captive portal costs nobody anything, because six days of slack sit behind
every renewal. Asking the server per launch would revoke faster and make every customer's tweaks
dead the minute the network is. **A failed check is reported as "nothing was decided", never as a
licence problem.**

**The server decides; it is never trusted.** A token that does not verify against the compiled
public key, or is not for this device, is dropped — so pointing the address at something hostile
earns a refusal and nothing else. https is required, because a licence over plain http can be
swapped in flight and the signature still checks out.

**The term and the renewal date are two dates, and the screen must show the term.** The token
carries `until` alongside `exp` for exactly this: telling somebody who bought a year that their
licence expires in seven days is a support message the code wrote itself.

**And the whole loop was proved before it shipped, in one harness rather than on a device.** The
Worker was driven in node with a fake KV, the *panel's own script block* was pointed at it, and
the token that came out of pressing «موافقة» was handed to the real Objective-C verifier, which
accepted it. Three separate signers now exist — `licence.py`, the Worker, and the browser panel
that preceded it — and all three had to agree byte for byte on sorted-key JSON and on P1363→DER,
which is exactly the kind of agreement that fails silently and mints keys no phone will take.

**Three ways in, and they are different instruments.** A device-bound key is the strong one. A
*request* (`ALBREQ1.…`) is the phone asking for one: unsigned on purpose — nothing on a phone can
sign it and nothing in it is worth forging, because it is a question and the panel's operator
answers it. A *short code* (`ALB-4K7M-9QX2-P3RT`) is for selling without a conversation.

**A twelve-character code cannot carry a signature, so it is looked up instead.** The device
hashes the normalised code and finds that hash in `licence/codes.json`, published beside the
source — **hashes, never codes**, so publishing it hands nobody a working code. Redemption is the
one moment in this layer that touches the network and it touches it once. **A code is not bound
to a device until redeemed**, so one code works for everybody who gets it until its hash is
removed: that is the trade for being typeable, and it is why keys remain the instrument for
anything that matters.

**The clock starts at redemption**, or a code sold in January and used in March is two months
short. And the device and the issuer must agree on the hash byte for byte — including how a
person's typing is folded (no I, L, O or U; `O`→`0`, `I`/`L`→`1`, `U`→`V`), which was checked
across dashes, spaces, lower case and a missing prefix rather than assumed.

**Keys are issued from `tools/licence-panel.html`**, deployed to `…/licence-panel/`, which also
keeps the ledger of who has what and builds `revoked.json`. It is public and inert until a signing
key is pasted in; signing is WebCrypto, in the browser, and the file has exactly one network call
— a relative read of the revocation list.

**WebCrypto signs P1363 and `Security.framework` verifies DER, and getting that conversion wrong
does not fail loudly** — it mints keys that look perfectly well-formed and are refused by every
device, which is the worst shape a bug can take in a licence issuer. So the page's *own* script
block was extracted and run in node against the real Objective-C verifier before it shipped, in
both directions and against `licence.py` as well. **A signer that cannot verify its own output is
a signer nobody can trust the day something disagrees**, which is also why the page proves a
freshly loaded key against the public half compiled into the tweak and refuses to issue at all
when they do not match.

**The private key lives in `~/.albrhi/` and never enters this repository** — not in a build, not
in CI, not in a message. `.gitignore` carries the pattern as a second line of defence, not as the
arrangement.

**Seven days is the whole live-control design, and both halves matter.** Revocation becomes real —
withdraw a licence and the device stops within a week, with no list for it to decline to fetch —
while a flight or a captive portal costs nobody anything, because six days of slack sit behind
every renewal. Asking the server per launch would revoke faster and make every customer's tweaks
dead the minute the network is. **A failed check is reported as "nothing was decided", never as a
licence problem.**

**The server address is compiled in, and that is not a convenience.** Without it every buyer has
to be told a URL and type it correctly before they can even ask for a licence. The preference
still overrides it, and the panel names which of the two is in use — "the built-in one" and "one I
chose" are different facts, and only one of them is worth checking when something stops working.

**The server decides; it is never trusted.** A token that does not verify against the compiled
public key, or is not for this device, is dropped — so pointing the address at something hostile
earns a refusal and nothing else. https is required, because a licence over plain http can be
swapped in flight and the signature still checks out.

**The term and the renewal date are two dates, and the screen must show the term.** The token
carries `until` alongside `exp` for exactly this: telling somebody who bought a year that their
licence expires in seven days is a support message the code wrote itself.

**And the whole loop was proved before it shipped, in one harness rather than on a device.** The
Worker was driven in node with a fake KV, the *panel's own script block* was pointed at it, and
the token that came out of pressing «موافقة» was handed to the real Objective-C verifier, which
accepted it. Three separate signers now exist — `licence.py`, the Worker, and the browser panel
that preceded it — and all three had to agree byte for byte on sorted-key JSON and on P1363→DER,
which is exactly the kind of agreement that fails silently and mints keys no phone will take.

**`class_getInstanceMethod` returning NULL does not mean the object cannot answer — and reading
that as "no" broke two whole families of class at once.** `SCISafeValueForKey`, written to retire
`-valueForKey:`, decided whether a getter returns an object by reading its `Method`'s type
encoding. A class that resolves a selector with `+resolveInstanceMethod:` or forwards it has no
`Method` at all while `-respondsToSelector:` still answers YES, so the check read the absence as
"not an object" and returned nil. **`LSApplicationProxy`** is such a class — the panel stopped
showing any app's version — and so is **every protobuf class**, which is what YouTube's `YTI*`
renderers are. `-methodSignatureForSelector:` is what the forwarding machinery itself consults,
so it answers exactly where the method list does not.

The shape is the one this file already names for `respondsToSelector:` versus what
`-valueForKey:` could reach: **a runtime query that comes back empty is not the same as a fact
about the object**, and a replacement for a Foundation behaviour has to be tested against the
behaviour it replaces rather than reasoned into. A twenty-line harness with a dynamically
resolved accessor would have caught it before the release did.

**A `#` inside a quoted shell string is not a comment — it is a word, and one of those words
was `com.albrhi`.** A note explaining `WITHHELD_PACKAGES` was written *between the quotes* of
that very assignment, so every word of the prose became a withheld package name. The suite's own
identity appeared in the sentence, so **the rootless `com.albrhi` vanished from the source
entirely** while the roothide flavour and every other package stayed exactly where they were:
the build was green, the release was published, and the index was simply missing the package
most people install. It is the same family as the heredoc `\n` this file already records five
instances of — a comment convention that does not hold inside the construct it was written into.

**And the step that caught it is the one that asks the live URL.** `buildsuite.yml`'s "does the
source actually serve this version" check failed while everything upstream of it passed, which
is exactly what it is for and exactly why it must never be relaxed to test the build's own
output instead. Nothing else in the pipeline could have noticed: the workflow had faithfully
built, released and deployed a correct index of the wrong set of packages.

**A rule that lives only in this file is a rule that gets broken — `-valueForKey:` was
documented here for a year and used 108 times.** Two paragraphs above explain that it runs the
receiver's own code and that `@catch` does not protect it, and neither stopped thirty-three
files from carrying the exact banned shape, `@try { [obj valueForKey:@"x"]; } @catch {}`.
Nobody greps a design document before writing a hook. **A rule worth keeping belongs in
`tools/check.py`**, where it is checked every time rather than remembered — that is now rule 23,
and `shared/src/SCIKVC.h` is what it points at.

**And retiring KVC is not "call the getter instead" — KVC resolves a key four ways.**
`-key`, `-isKey`, `-getKey`, then the `_key`/`key` ivar. A replacement that checks one selector
silently stops finding values that were being found, and a `BOOL` property (`-isFoo`) is the
first thing to break. `SCISafeValueForKey` tries all four; every getter is read through a cast
taken from **its own type encoding** — the `-bitRate` lesson, applied where it belongs — and the
ivar is read with `object_getIvar` only when the runtime says it holds an object, which executes
nothing at all. That last branch is why the replacement is *safer* than KVC rather than merely
equivalent.

**A scalar getter is a real answer of the wrong kind, and folding it in would hide that.**
`SCISafeValueForKey` returns nil for one, and a caller that genuinely wants the number asks
`SCISafeNumberForKey`. Four call sites in the sweep were reading a boxed scalar through KVC —
`type`, `_subtype`, `followsCurrentUser`, `isCarousel` — and each would have silently become nil
if the two questions shared a name. **Find those before the sweep, not after**: grep the
converted sites for `boolValue`, `integerValue` and `isEqual:@(`.

**`extern "C"` is needed in `shared/` too, and rule 15 was not looking there.** It scans a
tweak's own `src/`, so a C function declared in `shared/src/` and imported from a `.xm` linked
fine in eight tweaks and failed in the one with Objective-C++ — after every source had compiled.
The header carries the guard now; the rule's blind spot is worth remembering for the next shared
header.

**An orphan count that is wrong five times in six is a count nobody reads.** `check.py` counted a
localization key as used only when it appeared inside `SCILocalized(@"…")`, so keys handed to
something that localizes them later — `Feature(@"spaces", @"f_spaces", …)` — read as dead: **54
reported in X where 5 were real**, and those five sat in the noise for releases. Accepting a bare
quoted occurrence anywhere fixed it, and the first attempt then reported *zero* everywhere,
because the table file counts as a file and every key appears in it. **A zero is worse than an
over-count** — it reads as checked and clean.

**Matching a row by the English words printed on it is a feature that only works in English, and
this repository ships to an Arabic phone.** Thirteen comparisons inherited from SCInsta test a
view model's title against `@"Ask Meta AI"`, `@"Suggested for you"`, `@"Meta AI"`. Instagram
translates those. The rule was already written down here for the Watch tweak; what was missing
was noticing it applied to inherited code too. **Where there is no confirmed identifier to match
instead, say so rather than guessing one or deleting the feature**: every one of those now goes
through `SCIMatchesEnglishTitle`, which matches exactly as before and counts what it saw, so the
report reads `12 seen, 0 matched` under a line naming the app's own language.

**A view in an array is not a view in a hierarchy — and the report said "made and handed to its
layout" while the screen was empty.** YouTube's in-player save button was built with the app's own
factory and appended to the array `-topControls` returns, on the reasoning that the player would
then position it. It had no superview: nothing laid it out, nothing drew it. Every word of the
report was accurate and it measured the wrong half. **Counting that a thing was created is not
counting that it was placed**, which is this file's own "count the attempt, not only the result"
rule failing one step later than it was written for — so a placement record now carries the
resolved frame and whether the view is in a window.

**A list of layout names is a list of the ads that already got through.** YouTube's feed filter had
`video_display_carousel_button_group_layout`, added from a device report; the ad returned as
`video_display_button_group_layout` — the same name with one word removed. The list's own comment
had predicted this about itself two entries earlier. What generalises is the marking the *server*
attaches to something it charges for: `ad_slot_logging_data`, beside a
`slot_data { type: SLOT_TYPE_IN_FEED }`. **And it was measured before being trusted**, because
0.20.1 emptied the home feed with a substring that was too broad — the diagnostics page already
flags on that marker and matched exactly one section in sixty-six. A general marker earns its place
by being narrow in measurement, not by sounding general.

**A diagnostic written into another feature's slot is worse than no diagnostic, and it hid a
whole surface for eight releases.** YouTube's in-player save button recorded itself through
`-recordMarkerBar:` — the SponsorBlock progress-bar line — so the one piece of evidence about an
off-by-default, unconfirmed feature was filed under an unrelated heading and no report ever
mentioned it. It could not be confirmed, so it stayed off; it stayed off, so nobody looked. **Check
that a new record has its own slot and reaches the report**, the same way this file already
demands that a row added to a screen is added to the copyable report as well.

**And a class present in the binary is not a class the app draws — asked here only because the
count made it cheap to ask.** `YTSlimVideoDetailsActionView` has real metadata in 21.34.3 and
built exactly zero instances over a whole session on 21.32.4: YouTube composes that row from
elements now. This is X's dead immersive rail again, one app over, and the thing that settled it
in one report rather than one release was counting constructions rather than outcomes.

**A counter that is only written out on the success branch is not a counter, and this one was
written one branch away from the paragraph explaining why.** YouTube's new download-button hook
counted taps on the action row and recorded the tally *only* where a download button was
answered — so a tap on Like moved a number nobody could read, and the report went on printing
"no tap has reached this hook". The release's own changelog had claimed to remove that exact
ambiguity. **Incrementing and reporting are two separate acts**, and a count that exists in memory
and never reaches the report is worth less than no count at all, because it reads as evidence.

**And one number cannot separate four faults.** Not drawn in this build, drawn but carrying no
download button, carrying one and never pressed, pressed and failed downstream — four different
investigations. The fix is the one this file already names for install attempts: **count the thing
that is supposed to have happened, not only its result.** Views counted as they are constructed
answer "is the class live" with nobody tapping anything.

**A view is not configured when its initialiser returns.** Asking `-hasOfflineButton` at
construction would answer NO for a button that becomes the download button at
`-setOfflineStatus:offlineability:` a moment later, reporting `0 of 6` on a build where the
feature works perfectly — the same "asked too early" trap that had YouTube Music calling a class
missing from a build that certainly had it. `-didMoveToWindow`, once per instance, is where a
configured view can be asked about itself.

**A gesture cannot go missing, and it can still be in the way — this project optimised for the
first and never asked the second.** YouTube's hold-to-save was deliberately put on
`YTPlayerViewController`'s own `view` rather than on any YouTube view class, and the reasoning was
right: a controller's `view` cannot be renamed out from under a hook. What it never asked is what
*else* is already listening there. YouTube puts hold-to-speed-up on that same picture, ours
answered YES to simultaneous recognition to win contention at all, and the result was two long
presses on one surface with ours arriving first often enough that a habit built around the app's
own feature started producing a download sheet. **Placement robustness and placement correctness
are different questions**, and a hook that cannot break is not thereby a hook that belongs.

**And the replacement is the shape to reach for first: ask the class which button it is.**
`YTSlimVideoDetailsActionView` — the row under a video — declares `-hasOfflineButton` (`B16@0:8`)
beside the `-didTapButton:` it answers. Every previous attempt in this repository at "which of
these is the download button" on any app has been a frame, a subview index, an icon enum or a
localised title, and each has been wrong on some build; a BOOL the app maintains for its own layout
cannot be. Behind `-respondsToSelector:`, so a build that does not answer it is left alone — **a
gate that cannot identify its target must fail toward not intercepting**, which is the same
direction the TikTok download button's own refusal gets wrong when it is put at the wrong step.

**Two unrelated gates on one feature is a feature switched off by things it has nothing to do
with, and it hid for eleven releases.** That same hold-to-save was armed from inside the
SponsorBlock hook, below SponsorBlock's own preference check *and* below a `return` taken whenever
a video id could not be read — so it was silently dead for anyone who turned SponsorBlock off, and
for any video whose id the segment lookup could not resolve. Neither condition is about saving a
file. **Where a feature is armed from is part of its gate**, and a convenient hook is not a free
one; check what returns above the line you are adding.

**The safe area describes the device, never the app's own bars — and a screen placed inside
somebody else's controller has to clear both.** YouTube Music's Downloads page cleared the status
bar correctly and its heading still vanished, under the app's own header with the logo in it. The
safe area knows about the notch, the clock and the home indicator; it knows nothing about a bar the
app drew for itself directly beneath them. The same is true at the bottom, where the tab bar and
the docked mini player sit *inside* the safe area. **Measure the app's chrome off the views
themselves and take whichever ends lower** — by shape rather than by one class name, so a renamed
header keeps working and a build without one contributes nothing.

**Five fixes for one symptom, all of them correct, all of them undone — because the wrong thing
was being adjusted.** YouTube Music's Downloads list kept starting under the status bar, and every
attempt moved `contentInset`: measured from the parent (a parent hosting content in its own chrome
hands children a zero safe area), then applied without moving the existing `contentOffset`, then
read from a view whose `window` was nil on the first layout pass, then guarded by an early return
that a `-reloadData` walked straight past. A `UITableViewController`'s view **is** its table, so
inset was the only lever there was. Making it a plain controller with a table inside gave a
*frame* to place, and a frame that starts below the safe area cannot be argued with by a reload, an
offset or a parent. **When the third fix for one symptom is still the same kind of fix, change what
you are adjusting rather than how.**

**`UITableViewAutomaticDimension` does nothing without `estimatedRowHeight`, and the failure looks
like the row's second line not existing.** YouTube Music's settings screen returned automatic
dimension from `-heightForRowAtIndexPath:` and set no estimate; every row was one line, so it looked
right for as long as nothing needed two. A diagnosis line added under the master switch simply never
appeared — not clipped in a visible way, not overlapping, just absent, which reads as the code that
writes it never running. This is the TikTok settings overlap from the other side: same missing
property, opposite symptom, and neither is a hint that the text is wrong.

**A settings screen addressed by index is three lists of one truth, and a control that governs
what is below it belongs above it.** X's screen had five section constants, seven row constants, a
hand-written row count and a `switch` per section deciding what each number meant — the exact shape
that crashed the YouTube Music settings screen when a fourth list was added and one was not updated.
It is a registry now: a row carries its own title, preference key and action, a section's length is
`rows.count`, and each section registers itself in `+load` from its own file. **A builder returning
no rows is not drawn**, which is how the feature list *disappears* when the switch layer is off
rather than sitting there as switches that decide nothing — and that same fact is why the layer's
own switch moved from the last row of Advanced to the head of the screen.

**And BHTwitter's list is a map of BHTwitter's build, which cost nothing this time because it was
checked first.** Four of its switches have no target in X 12.20 (`_t1_showPremiumUpsellIfNeeded`,
`-isVODCaptionsEnabled`, `TFNTableView -setShowsVerticalScrollIndicator:`, and the cache clear), and
two classes had simply been renamed — `TTMUploadConfiguration` for
`TFNTwitterMediaUploadConfiguration`, `TTSSearchTypeaheadViewController` for
`T1SearchTypeaheadViewController`. Every one was settled by reading the app's own class metadata
before a hook was written, which is the discipline three earlier releases on three different apps
paid for. **A switch that decides nothing is worse than a missing one**: it reads as a feature that
does not work, and it is indistinguishable from one that broke.

**And hiding a section is not switching a capability off — "Hide Spaces" was doing both, and
the second half is what broke.** The feature set `voice_rooms_consumption_enabled: NO`, which is
X being told this account may not *listen* to a Space at all, so a link somebody sent came back
"unavailable": a broken app rather than a tidy timeline, reported in exactly those words.
`audio_articles_enabled` was the same shape one surface over. **Neither key was ever what hid
anything** — the strip is hidden by withholding `-_t1_initializeFleets` and the tab by its own
`audiospace` entry, and both kept working with the keys removed.

**Confirmed on a device in 0.18.4: the strip and the tab are still hidden, and a Space opens.**
Settled by measurement rather than reasoning: **BHTwitter 4.5 hides the same strip through the
same selector, names the same `audiospace` tab, and carries none of the four voice-room keys
anywhere in its binary.** A hide that has worked for years never touches the capability. What
stays are the two keys that gate *surfaces* — the button that starts a Space, the avatar ring
that advertises one — and the row now says that in both languages instead of promising to remove
spoken articles. **Ask of any feature-switch override whether it hides a thing or forbids it**;
the name of the switch on the screen is the promise, and «إخفاء» is not «تعطيل».

**And "Hide Spaces" was aiming at the wrong surface the whole time — it was never a tab.** Two
releases moved tabs, correctly, while the thing being complained about was the row of live audio
rooms above the Home timeline. That strip is set up by `-_t1_initializeFleets` (named for Fleets,
which once occupied it) on `THFHomeTimelineItemsViewController` — `v16@0:8`, in the **main
executable**, not in `T1Twitter.framework`, which is why a framework-only search would miss it.
The call is withheld rather than the bar emptied. **The lesson is about the question, not the
class:** "the switch does not work" was answered three times without once establishing *which
surface* the user was looking at, and the fix arrived only after the reference tweak's own source
named the method. Ask which surface before choosing a lever.

**Adding a tab and removing one are not the same operation, and 0.16.0 proved it by doing one and
not the other.** The identical hook that put Communities and Profile in the bar failed to take
Spaces out, on the same device, in the same release. `-isExcludedFromTabBar` is consulted while X
composes the set of tabs it *could* show — so an account with a saved bar keeps what it saved, and
an exclusion only changes what a **new** account is handed. That is `ios_tab_bar_default_show_communities`
again, one layer down, and it was not visible until a feature pointed the other way was tried.
Removal has to happen at `-setTabViews:` on `T1TabBarViewController`, the last point before the bar
draws, matching each `T1TabView` on its own `scribePage` (`audiospace` for Spaces, a token X itself
carries). **A hook that works is evidence about the direction it was tested in and nothing more.**

**Confirmed on a device in 0.16.0: Communities and Profile now appear in the bottom bar.** The
`…AppNavigationTabEntry` route is therefore the real one and the feature-switch route never was,
which settles four releases of switch work. The Spaces half rides the identical mechanism pointed
the other way and is not separately confirmed yet.

**A feature switch answered 784 times and still ignored is not the gate, and only a per-key
tally could say so.** Two X switches were reported as doing nothing. `voice_rooms_consumption_enabled`
was asked 784 times and answered `NO` on every one, with the Spaces tab exactly where it was;
`ios_tab_bar_default_show_communities` was asked **twice**, and `default` in its own name is the
tell — it seeds the bar a *new* account starts with, so a saved tab configuration wins ever after.
Neither override was failing to apply, which is the one thing four releases of switch work could
not distinguish from the switch being wrong. **The bottom bar's own entries answer the question
instead**: every tab is an `…AppNavigationTabEntry` — Home, Communities, Profile, Voice, Grok,
fifteen more — and each declares `-isExcludedFromTabBar` (`B16@0:8`) and `-isTabViewSideBarOnly`,
read out of 12.20's class metadata rather than guessed. Force both together: the second is the iPad
half of the same decision, and a tab admitted to the bar while still marked sidebar-only appears on
one device and not the other. And the report separates *not in this build* from *hooked, never
asked* from *asked and answered*, because those need three different investigations and silence
looks identical in all three.

**`app_attest_*` is not offered, rather than offered with a warning.** Those keys are how X
proves to its servers that the device is unmodified. Switching them off is not a privacy
setting — it is telling the server something it will not believe, on an account that can be
locked for it. Four of them were in the report and none are in the table.

**Named features and hand-set keys are two maps, not one.** The first version merged them,
and turning a feature off then meant removing its keys — but only the ones no other enabled
feature wanted, and only where the user had not since set one by hand. That bookkeeping is
where the bugs live. Features contribute a map recomputed from scratch on every change; the
hand-set map always wins; turning a feature off is a recompute, with nothing to get wrong.

**A jailbreak-detection bypass hides the jailbreak; it never touches payment.** Locket does
not block a jailbroken phone, it *reports* it — to OneSignal, to AppsFlyer, and from its own
Flutter code — where the flag can count against an account. The tweak answers those checks
as an unmodified phone would, and that is all it does. The `Check0verPlus.dylib` the owner
sent alongside the app is a different thing: it fakes RevenueCat entitlements to unlock the
paid "Locket Gold" subscription, which is taking money from the app's developers, not a
device tweak. It was reviewed and deliberately not reproduced. The same line the rest of the
project keeps — credit SCInsta, do not lift code, keep `app_attest_*` out of the X tweak —
puts subscription cracking on the wrong side.

**Hook the primitives a detector calls, not the detector.** Three SDKs check for a jailbreak
in Locket and only one (OneSignal) exposes a single BOOL to override; AppsFlyer and the
Flutter layer read the filesystem directly. So the bypass is Shadow-shaped: `%hookf` on
`stat`/`lstat`/`access`/`fopen`, plus `-[NSFileManager fileExistsAtPath:]`, `-canOpenURL:`
and `getenv`, each asking `SCILKShield` whether the path/scheme/var is a jailbreak probe and
lying **only** then. Everything else passes through — the one rule that keeps a bypass from
becoming a crash, which is why the path list is anchored at the start and never a substring
match on "cydia" that a sandbox file could contain. `open` is left unhooked on purpose: it is
variadic, and a two-arg hook drops the mode on every real `O_CREAT`, so `stat`+`fopen` carry
it. Every hook is grouped and `%init`-ed from the `%ctor` after the panel gate, so "off"
really means no hooks — a top-level ungrouped `%hookf` would install before the gate runs.

**The owner's phone is roothide, not rootless, and the local setup needs a second Theos for
it.** The two flavours are not interchangeable — a rootless package carries everything under
`var/jb` and a roothide one does not, because roothide decides its prefix on the device — and
**Theos settles that when it stages, so the flavour is chosen by which Theos builds it**, never
by the control file. The `roothide` package scheme exists only in the roothide fork
(`vendor/mod/roothide`), so stock Theos answers `'roothide' package scheme does not exist`:

```bash
git clone --recursive https://github.com/roothide/theos.git ~/theos-roothide
cp -R ~/theos/sdks/. ~/theos-roothide/sdks/        # same SDK, not fetched twice
```

`tools/build-local.sh` builds roothide by default for that reason, points `THEOS` at the fork
itself, and then **proves the flavour from the staged paths rather than the filename** — 1.0.2
shipped a "roothide" package built from a rootless tree and it installed as rootless, because
that is what it was. It refuses to copy a mismatch out.

**Two doors resolving the same thing two ways is two chances to be wrong, and only one of them
was.** YouTube Music's download works from a long press and failed from the badge with *the badge
was found, but this track carries no stream* — a message about the track when the fault was the
lookup. `YTMNowPlayingViewController` does not declare `playerViewController`; its parent
`YTMWatchViewController` does. The long press walked to the parent; the badge asked the
now-playing controller directly and got nil. **A wrong lookup that has a sentence prepared for its
own failure reads as a fact about the content**, which is how it survived a round. One resolver
now serves both doors.

**A commented-out call is invisible to every diagnostic that exists, and a feature suspended as a
crash suspect must be returned to duty when it is cleared.** YouTube Music's download installer was
commented out in 0.8.4 while a crash was investigated; 0.8.5 found the real cause elsewhere — an
`iconType` the app has no case for, hit while drawing the tab bar — and fixed it. **Nobody
un-commented the suspect.** Every round of work on downloading afterwards was on code that could
not run, and the reports were internally consistent the whole time: they said no class had been
found, which was true, because nothing had ever asked. What exposed it was counting the *install
attempts* and seeing **zero** on a build whose report was otherwise healthy. **Count the thing that
is supposed to have happened, not only its result** — a result has many explanations and an attempt
count has one.

**`NSClassFromString` inside a `%ctor` can answer nil for a class the app certainly has, and the
report then says "not in this build".** YouTube Music's download badge handler and its now-playing
controller are both in the app's own binary — read out of it directly — and both were reported
absent on a device running that very build. A tweak's constructor runs before the app's own
Objective-C metadata is registered, so the class exists a moment later and the question was simply
asked too early. **"The class is missing" and "you asked too early" are the same answer from a
single call**, which is what made this cost two rounds. Ask again on
`UIApplicationDidFinishLaunchingNotification`, and once more on a short delay for a class that
arrives with a lazily loaded framework — and **count the attempts in the report**, because "worked
on the second try" and "worked immediately" are different facts about a build and only one of them
means the constructor is the right place.

**One non-ASCII character moves a string literal out of `__cstring`, and `strings` then reports it
missing.** A report line beginning `@" \u00b7 long press: …"` was nowhere in the built object under
`strings` or `grep`, while the Logos symbols for the same code were plainly there -- so a build that
was entirely correct read as a build that had silently dropped half a function. Clang stores a
CFString literal containing any non-ASCII character as **UTF-16 in `__TEXT,__ustring`**; the ASCII
tools cannot see it and answer zero *confidently*, which is the same shape as the `otool`
little-endian trap already recorded for `tools/objc-classes.py`. **Verify a string's presence by
dumping both sections, or verify with a symbol instead** -- `_logos_orig$Group$Class$selector` is
ASCII whatever the strings around it are, and it is what settled this one.

**Holding the version while the content changes makes a local build indistinguishable from the one
already installed, and the device is the thing that cannot tell.** The publish pause below says
version numbers do not move — which is right for the *changelog*, and wrong for the `.deb` somebody
is about to install over a package of the same name. Two rounds were spent on a diagnosis line and
a new download surface that were never on the phone: the package manager saw `1.62.2` sitting on
`1.62.2` and did nothing, correctly. **Local builds carry a `+N` suffix** — `1.62.2+1`, `+2` — which
dpkg sorts above `1.62.2` and below `1.62.3`, so the published number space is untouched and every
local build still installs. Bump it on every local build during a measurement loop, exactly as a
released build bumps its own.

**Publishing was paused on 2026-09-03 and resumed the same day, and what the pause bought is worth
keeping.** 1.70.0 turned enforcement on while the device fingerprint was computed from a value only
*some* processes can read — so the panel said `licensed` and every tweak stood down. **A value that
is not readable from every process is not an identity**: `MGCopyAnswer("SerialNumber")` is
entitlement-gated per process, so Settings sees it and a sandboxed app does not, and one phone
computed two different fingerprints. Proved on this machine by forcing the fallback, not inferred
from the report. The identity is a random value the panel provisions once into the domain every
tweak already reads — no entitlement, identical everywhere by construction, and derived from
nothing about the phone or its owner.

The pause also had a second use: the licence layer got a real server behind it before anything
went out. **A `+N` suffix is for this machine and must never be pushed.** Committed to main it becomes the
version CI reads, so the workflow tries to cut a release tagged `v1.76.0+1` and the publish step
refuses it — a red run for a build that was never meant to leave the Desktop. Bump it, build, and
leave it out of the commit.

**Local builds during a pause are roothide only, go to `~/Desktop/Albrhi/`, and carry a
`+N` suffix** — dpkg sorts `1.70.0+1` above `1.70.0` and below `1.70.1`, so the published number
space is untouched and every local build still installs over the last one. While a pause is on,
nothing is pushed and no release is cut: a version that goes out is a version strangers update to
without knowing what changed.

**While the source is paused, builds go to `~/Desktop/Albrhi-TikTok` and versions do not move.**
A version number means something was published; nothing is being published during a measurement
loop, and bumping one per attempt turns the changelog into a list of guesses.

**Build locally before pushing — the CI round trip is five minutes and the local one is
under a minute.** This is set up on the owner's Mac and is **per machine**, so a different
computer needs it again:

```bash
brew install ldid make dpkg          # dpkg is for dpkg-deb only; it cannot install here
git clone --recursive https://github.com/theos/theos.git ~/theos
# then the iPhoneOS16.2.sdk from xybp888/iOS-SDKs into ~/theos/sdks/ — the same SDK CI uses
export THEOS=$HOME/theos
export PATH="/opt/homebrew/opt/make/libexec/gnubin:$PATH"   # GNU make; Apple's fails Theos
```

Both exports belong in `~/.zshrc`, and `build.sh` may need `chmod +x`. Then the cycle is:

```bash
python3 tools/check.py && bash build.sh <tweak> rootless
```

**What it catches and what it does not, measured over one long session.** It caught a
duplicated method, a missing header import, a stale reference to a class not yet written, a
flag used above its own definition, and a hooked class needing a real `@interface` — every
one of which would otherwise have been a five-minute CI failure. It caught **none** of:
`cellClass` set to a string where Preferences wants a Class (crashed Settings), a
constraint built from `bounds` at construction time, a `%new` parameter attribute, or a
`objc_msgSend` cast to the wrong return type (crashed TikTok). Those compile perfectly.
Compilation is the second of three gates; the third is a device, and there is no substitute
for it — which is what the Diagnostics pages are for.

**Run scripts before shipping them.** Three CI failures in a row came from shell
one-liners that were never executed once locally. `tools/check.py` and a stubbed
run of `tools/make-repo.sh` cost seconds.

**Never write shell/Python heredocs containing `\n` inside string literals.** This
corrupted source files three separate times — the escape becomes a real newline and
Objective-C has no multi-line strings. Write a script file instead. **It happened a
fourth time in 1.0.4**, in a commit that was fixing something else, by an author who had
read this paragraph. Treat it as a thing to check for after writing a heredoc, not as a
thing to remember while writing one.

**A fifth time, in the commit adding the rule that exists because of a half-applied
script.** A `.replace()` with no `assert` matched nothing, half the change landed, the
script printed its success line anyway, and CI found the unused variable it left behind.
The repair was then written into a heredoc whose `\n` became a real newline and broke
`check.py` itself — and in the same session an `assert` failing partway through a script
left `CLAUDE.md` untouched while the commit went out claiming it had been updated.

Use the editing tools for source. If a script must do it, `assert` every substitution
**and** re-read the file: a script that prints a confirmation it did not earn is the
failure, not the symptom.

**`Conflicts` and `Replaces` are a request to a package manager, not to dpkg.** Sileo and
Zebra honour them when installing from a source. `dpkg -i` on a downloaded file does not:
it is handed one file and told to unpack it, and the old package stays exactly where it
is — so both dylibs end up in `DynamicLibraries` under two package names and both get
injected. `suite/DEBIAN/preinst` removes them itself for that reason. Declaring a
relationship and hoping is not the same as performing it.

**What makes a package roothide is its paths, not its control file.** A rootless `.deb`
carries everything under `var/jb` and a roothide one does not, because roothide's prefix
is decided on the device. Theos settles that when it *stages*, long before any packaging
script runs — so 1.0.2 shipped a "roothide" package built from a rootless staging tree
and it installed as rootless, because that is what it was. `make-suite.sh` now checks the
staged tree against the scheme it was asked for and refuses a mismatch, naming which
`THEOS` it used. Two releases were spent on a control-file theory that was never the bug.

**Keep the fields a tool computed; override only your own.** `make-suite.sh` used to
replace `DEBIAN/control` wholesale and threw away what Theos had written into it. The
merge now wins field by field. The general direction matters more than this instance:
discarding information you did not know you had is the failure mode, and it is silent.

**The per-app switch is opt-in now: absence reads as *off*, and that reverses what this
file used to argue.** The old reading — nothing written means on — was right while a package
meant one tweak for one app: somebody who installed it deliberately should not have it
silently disabled. `com.albrhi` ended that. One install carries Instagram, YouTube, X and
TikTok (Locket has since left the suite, but the reasoning does not change with the
count), so reading silence as consent modifies apps the install never asked about.
Nothing is patched until it is asked for, and the panel's footer says so in both languages
rather than leaving a fresh install looking broken.

**One question, three answers, in three processes — and two of them agreeing is not
enough.** `SCIPanelGate` decides whether the dylib acts; `SCIPanelRoot -isOnForSpecifier:`
draws the row in Settings; `SCICPSettingsController -enabledForSpecifier:` draws the same
row on a tweak's own detail page. All three read `app_enabled_<bundleid>` from separate code, and
the first sweep found only the first two. Leaving the third at YES would have drawn
a tweak's switch on while the gate held it off — a screen actively lying, which is worse
than one that merely surprises. Grep `app_enabled_` before changing this default again;
sub-feature keys (a tweak's own sub-options) are a different question and stay defaulted on,
because they sit *inside* a tweak already opted into.

**Persistence needed no code.** The value lives in the panel's plist, which dpkg leaves
alone on upgrade and `suite/DEBIAN/preinst` does not remove — checked, not assumed. On stays
on across updates; a deliberate off stays off just as firmly.

**A sandboxed app asking cfprefsd for another application's domain is answered with
nothing, not with an error.** The panel writes the per-app switch from inside Settings;
Instagram and YouTube read it from inside their own sandboxes and saw an absence — which
this code deliberately reads as "on", so a device that never opened the panel keeps
working. The switch moved and nothing happened. The plist is read directly now, with
CFPreferences tried first because where the sandbox permits it it is cheaper and it sees
a value written but not yet flushed. **The jailbreak prefix comes from `dladdr` on this
code's own address** — the only way to get it right on roothide, where it is a different
random directory on every device.

**The opt-in panel gate is right for `com.albrhi` and wrong for every self-contained
sideload build, and this went unnoticed until Locket's own report said "nothing works,
not even the welcome screen."** `SCIPanelAllowsThisApp()` reading absence as *off* exists
because installing the suite patches four apps at once, and silence should not read as
consent for all of them — but a `SELFCONTAINED` build is one tweak, chosen and installed
deliberately, for one app, quite possibly on a device with no jailbreak on it at all.
Albrhi Panel is itself a jailbreak package (a `PreferenceLoader` bundle, no sideloaded
equivalent exists), so on such a device it can *never* be installed, the switch can never
be turned on, and the opt-in gate refuses forever — every hook in the tweak standing down
on every launch, silently, because the gate sits before all of them in `%ctor`. Fixed once,
in `SCIPanelGate.m` itself rather than per tweak: `SCIPanelAllowsThisApp()` answers `YES`
unconditionally under `#ifdef SCI_SELFCONTAINED`, restoring the older "installed it
deliberately" reading for the one case that is still true of. Every tweak's own `%ctor`
needed no change, because every tweak already asks this one function and nothing else.

**A path derived from where a file *used to* be installed is a guess, and the package
itself is the thing that answers it.** Albrhi NextUp came back "it didn't work at all",
and the cause was readable from this machine with no device and no log: unpack the
published `.deb` and look at the paths. Five of its seven processes are sandboxed apps
that must register a mach service, which needs a libSandy profile applied from `%ctor`;
the profile is found by `dlopen`, and the fallback for a randomised jbroot derived the
root by searching this dylib's own path for `/usr/lib/`, because upstream stages into
`<jbroot>/usr/lib/TweakInject/`. Theos stages *this* package into
`<jbroot>/Library/MobileSubstrate/DynamicLibraries/`. The substring is simply not there,
the fallback returned quietly, every lookup was denied, and the row was dead everywhere.

Two things generalise. **A ported tweak inherits its upstream's assumptions about its own
installed layout, and packaging is exactly what a port changes** — so any path built from
`dladdr` on the tweak's own address is worth re-reading against the staged tree the first
time it is packaged here. And **the same derivation existed twice in that tweak and only
one copy was wrong**: `NULocalization.h` handled both staging shapes, `NUShared.h` handled
one, and the file with the bug carried a comment saying it used the same pattern as the
file without it. A comment claiming two things match is not a check that they do.

**A sleep is a guess about how long something takes.** Three releases went into a Pages
deploy that "hung", and each time the fix was to ask the thing itself instead: which mode
Pages is in, whether the build is `built` or `errored`, whether the live URL is serving
the version just built. Every time a sleep was replaced with a question, the answer came
back immediately and was right. See the CI section for what that turned into.

**Albrhi CarPlay is gone from this repository, and what it learned is kept in one place rather
than in the eight sections it used to occupy.** It patched SpringBoard and Camera to put an
ordinary app on the car display, plus a dashboard wallpaper and a recording-audio fix. **It never
ran on a device**: 0.3.0 and 0.4.0 each looked finished and were not, and 0.4.1's fixes for what a
real iOS 16.1 report found missing were themselves never observed. The owner's decision is to
rebuild it from scratch in a repository of its own — which is the right shape for it, because a
wrong hook there takes the home screen with it and that risk has no business riding along with a
source that updates for a download button.

**What it established, for whoever builds the next one:**

- **The display mechanism is the app patching itself, not SpringBoard reaching into another app.**
  A dylib in the target app rewrites its own incoming CarPlay scene role to the ordinary
  `UIWindowSceneSessionRoleApplication`; UIKit then resolves the app's real Info.plist scene
  configuration. A bug crashes that one app rather than SpringBoard. `carplay-cast`'s
  `SBSceneManagerCoordinator` scene-hosting path is the *old* CarBridge-era mechanism, abandoned
  once CarPlay's UI moved out of SpringBoard.
- **Admission is decided by LaunchServices on iOS 15–17 and by CarKit on 18+**, and one build must
  gate on the version: running the 16/17 LaunchServices hooks on 18 puts SpringBoard into safe
  mode. On 15–17 the answer is the typed entitlement getters plus `-entitlementValuesForKeys:`,
  whose result is a private `LSBundleInfoCachedValues` — **tag that object, never replace it**, and
  the tag set must hold weak references.
- **An app that ships its own CarPlay interface must be left alone.** Rewriting a template scene
  after CarPlay has built one throws inside `+[UIScene _sceneForFBSScene:…]` and kills the app on
  every launch.
- **`carsurf` by pavunato is the current reference and carries a "do not retry" table**, every row
  of which cost a device recovery: no global `LSBundleInfoCachedValues` swizzle, nothing hooked in
  `carkitd`, no fabricated entitlement dictionaries, no forcing `launchUsingTemplateUI = NO` on a
  genuinely native template app — and a visible icon is never proof, a real `UIWindowScene` is. It
  has **no LICENSE file**, so it is read for architecture only, the same line this project keeps
  for the unlicensed TikTok references and the opposite of what GPLv3 allowed for NextUp.
- Two lessons from it are general and stay below in their own sections: **an XML comment cannot
  contain `--`** (check.py rule 18), and **a space-separated `TWEAK_NAME` builds two binaries**
  (`shared/tweak.mk`).


**Albrhi Panel assumed one filter names one app, and CarPlay is the counterexample.**
`SCIPanelScan` turned every `Bundles` entry in a filter plist into its own row, so
CarPlay's two-process filter (SpringBoard, Camera) showed up as two rows reading
"Camera" and "SpringBoard" — as if Albrhi patched Apple's own apps rather than hooking
two processes for one feature. A filter can now declare `SCIPanelGroupIdentifier` /
`SCIPanelGroupName` / `SCIPanelDetailController` to collapse to a single named row that
pushes to a real settings page (`SCICPSettingsController`) instead of showing a plain
switch — the master on/off, the audio-fix toggle and the microphone choice do not fit
one switch cell between them. And that page's own preferences could not have worked
before this: 0.1.0 stored them in `NSUserDefaults standardUserDefaults`, which is local
to whichever of the two processes loaded the dylib and unreachable from Settings either
way. `SCIPanelGate`'s cross-sandbox reader — built and proved for the per-app switch —
was generalized from a bool-only, switch-only helper (`SCIPanelReadBool`/
`SCIPanelReadString`, plus `SCIPanelAllowsApp` for an identity other than the calling
process's own) rather than giving CarPlay a second, unproven cross-sandbox path of its
own. Mic choice is three `PSSwitchCell` rows acting as a radio group, not a
`PSListItemsController` picker — the private list-picker class was never confirmed to
compile against the SDK this repository pins, and this project does not ship a guess
at private API it has not built once.

**An XML comment cannot contain `--`.** `AlbrhiCP.plist` failed to parse — silently, as
far as `check.py` is concerned, since nothing here parses filter plists — because a
comment explaining the grouped-row keys used `--` the way this file's own prose does
everywhere else. `plistlib` catches it; `dpkg-deb` and MobileSubstrate might not agree
on how, which is worse. Worth checking with a real plist parser after editing a `.plist`
comment, the same discipline this project already applies to shell heredocs.

---

## Layout

The repository holds **one tweak per directory under `tweaks/`**. Each is a
complete Theos project — its own `Makefile`, `control`, filter plist and `src/` —
and nothing outside it knows which app it patches. Everything above that level is
shared: the build script, the checks, the APT index, `modules/`, `vendor/`.

```
tweaks/
  instagram/               Albrhi for Instagram — com.albrhi.tweak
    Makefile               its identity: target process, frameworks, dav1d
    Albrhi.plist           injection filter (com.burbn.instagram)
    control                package metadata; Version drives the release
    CHANGELOG.md           release notes and the Sileo depiction come from here
    src/
      Tweak.x              entry point, NSUserDefaults defaults registration
      SCIProject.h         repo owner/name — rename the repo, edit only here
      SCILog.h             SCILogV, gated on the verbose_logging preference
      Utils.m/.h           shared helpers, media URL resolution, colours
      InstagramHeaders.h   every Instagram class the tweak touches
      Localization/        bilingual string tables (AR/EN must stay in parity)
      Settings/
        SCISettingsRegistry  features register their own pages in +load
        Pages/             one file per settings page; delete a file, page is gone
        SCIDiagnosticsViewController   runtime truth + one-tap issue reporting
      Downloader/
        SCIMediaDownloader THE single entry point for every download
        Queue/             background queue, history, Download Center UI
      Features/<Category>/ one file per feature
      Onboarding/          welcome / what's-new screen
  youtube/                 Albrhi for YouTube — com.albrhi.youtube
    src/Features/Download/   the HLS pipeline; Center/ is the library, player and tabs
  twitter/                 Albrhi for X — com.albrhi.twitter
    src/Features/Switches/   the one place X decides what the app may do; the tweak
                             records every question and lets the user answer any of them
    src/Features/Media/      downloads: captured at TFSTwitterMediaInfo, the model every
                             surface builds, so one hook serves timeline, full screen,
                             quoted posts and DMs
    src/Settings/            reached by a two-finger hold on X's own window, not by
                             hooking one of X's screens
  tiktok/                  Albrhi for TikTok — com.albrhi.tiktok, in the suite
    src/TikTokHeaders.h      every class this tweak touches, with which confirmation
                             bar each one meets — a hooked-selector symbol table beats
                             string-table proximity, and the header says which is which
    src/Features/Download/   SCITTCapture hooks AWEVideoModel's own construction, which
                             is the only point a real play URL exists; SCITTMedia
                             resolves and holds only a URL, never the model; SCITTButton
                             puts one button in the centred cell's rail; SCITTDownload
                             saves it and asks AVFoundation what the file actually is
    src/Features/Privacy/    three report-to-server calls withheld, local state untouched
    src/Settings/            a two-finger hold shows switches and what has been captured
  panel/                   Albrhi Panel — com.albrhi.panel
                           an Albrhi page in the Settings app, one switch per patched
                           app. It writes; the tweaks read — and how they read it is a
                           ground rule above, not a detail.
    src/NextUp/              Albrhi NextUp's own settings page, pushed to from the one row
                             the panel collapses its seven-process filter down to — see
                             SCIPanelScan's SCIPanelGroupIdentifier handling
  nextup/                  Albrhi NextUp — com.albrhi.nextup, a GPLv3 port of
                           NextUp 3 by Yves. Kept as a near-verbatim copy on purpose,
                           NU* prefix and all, so it can still be diffed against
                           upstream; the port's own additions live in one file
    src/                     the providers (one per media app, each reading that app's
                             own queue) and the display side, in one binary gated at
                             runtime on host process and iOS major
    src/hooks/               eight display-side files covering iOS 14.2 through 26 —
                             the version spread is why they are split by surface
    src/NUAlbrhi.m           everything this port adds, in one place, so the rest of
                             the tree stays a clean copy
    bundle/                  NUPrefs.bundle: resources only. Upstream's Settings pane
                             is gone (the page lives in the panel now) but the name and
                             path are load-bearing — NULocalization.h compiles them in
                             — and 27 .lproj tables including Arabic ride on it
    layout/                  the libSandy profile that lets a sandboxed app register
                             the mach service the display side looks up
suite/
  control                  com.albrhi — the combined package everyone installs
  DEBIAN/preinst           removes the individual packages, because dpkg will not
  CHANGELOG.md             the suite's own notes and depiction
shared/
  tweak.mk                 the Theos flags, modules and build modes every tweak shares
build.sh                   ./build.sh <tweak> <mode> — reads the tweak's own control
build-dev.sh               a local build that skips packaging
tools/                     repo, depiction, logo, deb editing — see below
modules/  vendor/          third-party code, shared across tweaks
extra-debs/                drop third-party .deb files here to publish them
```

### Adding a tweak

Create `tweaks/<name>/` with a `Makefile` (ending in
`include $(ROOT)/shared/tweak.mk`), a `control`, a filter plist named after
`TWEAK_NAME`, and `src/` containing at minimum a `Localization/SCILocalize.m` and
a `SCIVersionString` matching `control`. `tools/check.py` finds it automatically
and checks it like the others; `./build.sh <name> rootless` builds it.

Most new tweaks belong inside `com.albrhi`, and need no workflow of their own at all:
`make-suite.sh` picks up any `tweaks/*/control` automatically, so joining the suite is
the default and costs nothing but a version bump in `suite/control`.

A tweak only earns its **own publishing workflow** when it has nothing to do with what
the suite bundles — NextUp is the one that has. `buildnextup.yml` is the shape to copy, and two
more sit in git history: `buildlocket.yml` as of the commit before it was deleted, and
`buildcarplay.yml` as of the same for CarPlay. What that shape is: its own version gate, its own tag namespace
(`carplay-v*`, `locket-v*` — so two packages' versions can never be confused on one releases
page), its own assets including a self-contained sideload dylib, and a `.no-suite` marker file
in the tweak's directory so `make-suite.sh` does not also pull it into the combined package.
Separate workflows rather than one job per tweak, so a tweak that will not compile can
never block another tweak's release.

**And it does not keep `buildsuite.yml` from *demanding* that tweak either — taking a tweak out
of the suite touches three places, not two.** Spotify left the package with a `.no-suite` marker
and a trigger exclusion, both correct, and the next suite release failed outright: the workflow's
own "holds every tweak" assertion still listed `AlbrhiSpotify.dylib` and `.plist`, so it demanded a
file `make-suite.sh` had just been told to skip. The build was fine; the check was wrong, and it
failed *after* compiling everything. That assertion exists to catch a tweak silently dropping out
of the package, which makes it exactly the thing that must move when one is dropped on purpose —
the marker, the trigger's `paths:` list, and the assertion, checked together.

**The `.no-suite` marker keeps a tweak out of the package; it does not keep
`buildsuite.yml` from running on that tweak's commits, and those are two different
things.** `buildsuite.yml`'s own trigger watched `tweaks/**`, which matches
`tweaks/carplay/**` (and, while it existed, `tweaks/locket/**`) just as much as any bundled
tweak's directory — so a commit touching only a standalone tweak rebuilt Instagram, YouTube, X
and the panel anyway,
every single time, for a package that commit could never change. Reported plainly as
confusion ("ليش بعد كل تحديث يتم اعادة بناء البانل؟"), and it was worth taking at face
value: the workflow really was doing something it had no reason to do. Fixed with `!`
exclusion patterns for both standalone tweaks in the trigger's `paths:` list, kept next
to `make-suite.sh`'s own skip list so the two are checked together. A third standalone
tweak needs a line in both places, not just the marker file.

**The one thing two publishers cannot help sharing is the APT index, and that was the
trap.** `make-repo.sh` wipes `debs/` and rebuilds it on purpose, so an index built from
one tweak's build output would erase the other tweak from the source. Both `buildsuite.yml`
and any second publisher therefore build the index from what is **published** —
`tools/fetch-published-debs.sh` gathers the newest three versions of every package from
the releases — and both take the `albrhi-pages` concurrency group. Two workflows publish
today, genuinely racing for `gh-pages` rather than hypothetically; every word below is
what that costs, and CarPlay will be a third if it is ever un-withheld.

**And a package can be removed from the source by *someone else* releasing, which is the same
failure arriving from the opposite direction.** The gather looked at the newest 40 releases
outright, and the suite publishes constantly — so `locket-v0.4.1`, still Locket's current release
and perfectly healthy, was pushed to position 66 by the suite's own version history and stopped
being gathered. **The source served no Locket at all, and nothing failed**: no red build, no
warning, just a package that quietly stopped being mentioned. One global window means the fastest
publisher starves every slower one, invisibly. The window is per *tag namespace* now (`v*`,
`locket-v*`, and whatever a future tweak adds) — which is exactly the boundary a separate publisher
already has, so it needed no new bookkeeping. Worth checking after adding a third publisher, and
worth remembering as the general shape: **a bounded scan shared between producers is a starvation
bug waiting for one of them to speed up.**

**That same design is why a package is not removed from the source by not releasing it.**
Building the index from the releases means the releases *are* the source: a workflow that
goes quiet keeps being gathered from what it published before, at the last version it
shipped, indefinitely. Withholding is therefore an explicit list —
`WITHHELD_PACKAGES` in `fetch-published-debs.sh` — and never an absence of action.

Two publishers also means the order they run in is not automatically safe.
**This file used to say a shared gather made the order irrelevant, and the correction is
worth keeping.** That only holds if both gathers see the same set of releases, and a
release published *between* them breaks it: both runs started at 11:53:02, YouTube
published 0.10.1 at 11:54:36 back when it still published, and the run that had already
gathered deployed an index without it — last. Nothing failed. The release was fine, the
packages were fine, and the source served a version older than both.

So the gather **states what the index must contain and checks**: `suite/control`, and the
running workflow's own tweak if it has one, each name a package and a version that has to
be present. Missing means the listing was read
too early — worth one more look after a pause, then worth failing the run. A red build is
recoverable in a minute; a source quietly a version behind is not noticed until someone
asks why the tweak did not update.

**And an index built from the releases API misses the release the same run just made.**
YouTube 0.5.0 was published at 17:05:28; the run that published it finished at 17:06:41
having built an index that stopped at the previous version. The listing is eventually
consistent and the gather step is inside the "eventually". Each workflow therefore also
copies its own freshly built `.deb` into the gathered set — the same package that was
just uploaded, taken from the machine that built it rather than from a listing that has
not caught up.

**That only holds for what lives on `gh-pages`.** The index does, because both
workflows rebuild it from the published releases. A depiction does not build itself:
it is generated, and the YouTube one was generated only into that workflow's Pages
*artifact*. The Instagram workflow builds its deployment from the **branch**, so it
deployed a site without it — and the page 404'd a minute after publishing, the two
runs being a minute apart. Anything generated must be written to `gh-pages`, not just
handed to the artifact, or the other tweak's next release quietly deletes it.

That change also closed a gap that existed with one tweak: when a build was skipped
because the version was already released, the index depended on a separate download
step succeeding. Now there is a single source of truth for what the source serves.

### Settings are self-registering

`SCISettingsRegistry` composes the settings tree from pages that register
themselves in `+load`. Adding a feature means adding one file under
`Settings/Pages/` — no shared file to edit, no merge conflicts. A page whose
builder returns an empty array simply does not appear.

### One download path

Every surface — inline button, story button, DM viewer, profile picture — goes
through `SCIMediaDownloader`. Before this existed, each surface built its own
download call and settings applied to only one of them. Do not add a second path.

---

## Toolchain gotchas

**Logos `%orig` is fragile in this version.** It expands with `#line` directives.
It must sit alone on its own line inside a full block. This breaks:

```objc
if (x) { %orig; return; }        // "%end does not make sense inside a block"
```

**A `%new` method's parameter type is pasted into `@encode()`, so an attribute there is a
build failure.** Logos generates the method's Objective-C type encoding from what the
parameter is *written* as, verbatim. `- (void)sciSaveTapped:(__unused UIButton *)sender`
becomes `@encode(__unused UIButton *)`, clang answers `'__unused__' attribute ignored when
parsing type`, and `-Werror` turns that into three fatal errors inside one generated line
that exists in no source file, pointing at a column in the middle of it. The habit that
causes it is a good one everywhere else in this project — `__unused` on a parameter a hook
does not read is correct in `%hook`, and appears throughout. It is only `%new` that
encodes. Every other `%new` here writes a plain typed parameter, which is also the fix:
an unused parameter is not warned about in an Objective-C method the way it is in a C
function, so the attribute buys nothing. Rule 19 catches it now.

**A hooked class needs an `@interface` if you touch its properties.** Otherwise
Logos emits only a forward declaration and `self.view` fails to compile.

**A `PSListController` subclass that overrides `-specifiers` must assign the result
to the `_specifiers` ivar itself, not just return it.** CarPlay's detail page
(`SCICPSettingsController`, gone with the tweak — the panel's three surviving detail pages
under `tweaks/panel/src/{NextUp,Spotify,Watch}/` all follow the pattern it cost) built its row list
correctly and returned it, and the page opened to a black screen with nothing on it
— reported on-device. `PSListController`'s own machinery reads `_specifiers`
directly in places an override's return value never reaches; `SCIPanelRoot.m`'s root
page had always done `_specifiers = specifiers; return _specifiers;` and worked, and
the new page skipped the ivar assignment and did not. Confirmed by matching the
already-working pattern rather than guessing at why a black screen specifically
means this.

**`FINALPACKAGE=1` is set in `build.sh`** for all packaging modes. Without it every
published build carried debug symbols and a `-1+debug` version suffix.

**Rootless and roothide packages have separate identities** — `com.albrhi.tweak`
and `com.albrhi.tweak.roothide`, each declaring `Conflicts`/`Replaces` on the
other. `build.sh <tweak> roothide` swaps the fields in `control` and restores them
via a `trap` on exit, including on failure. The new id and name are **derived from
that tweak's own `control`**, not written out in the script: the earlier version
matched literal package ids with `sed`, which would silently do nothing for a
second tweak — and doing nothing there means shipping a roothide build wearing the
rootless identity.

**A space-separated `TWEAK_NAME` builds two binaries; `$(TWEAK_NAME)_FILES +=` builds
one badly-named variable.** CarPlay is the first tweak here with two dylibs
(`AlbrhiCP AlbrhiCPApp`), and `shared/tweak.mk` had always written
`$(TWEAK_NAME)_FILES += ...` on the assumption of exactly one name — Make does not
split a variable-name substitution on spaces, so that line silently built a single
variable named `AlbrhiCP AlbrhiCPApp_FILES` instead of setting `AlbrhiCP_FILES` and
`AlbrhiCPApp_FILES` separately. Fixed with `$(foreach T,$(TWEAK_NAME),$(eval $(T)_FILES
+= ...))`, which degrades to exactly the old behaviour when a tweak names only one
binary, so every other tweak here is unaffected. **And the fix broke all six tweaks at
once on the first attempt**, for an unrelated reason: `tools/check.py`'s rule 9 finds
include roots by scanning this file's raw text for `-I(\S+)`, and `-I$(ROOT))` with no
separating space reads as one token — the `$(eval ...)`'s own closing paren swallowed
into the path, turning `../..))` into every "shared/src/..." import's include root and
failing every one of them. The fix is a literal trailing space before the paren, now
commented so nobody reads it as stray formatting and removes it.

**A tab in column one of a makefile is never indentation — it is always an attempted
recipe, and a bare `$(eval)`-as-statement line is not a rule.** That same CarPlay commit
indented the `ifdef SIDELOAD` and `ifdef SELFCONTAINED` blocks' own `$(foreach ...)` lines
with a tab, to show they belonged inside their `ifdef` — which reads as correct and is
the opposite of correct. Make decides "is this a recipe" purely from the first character,
before any macro expansion, so a tab there demands a preceding target and finds none:
`shared/tweak.mk:73: *** recipe commences before first target. Stop.` It went unnoticed
for as long as it did because neither `SIDELOAD` nor `SELFCONTAINED` is ever set by an
ordinary build — normal builds skip both blocks entirely, and skipping still requires
Make to scan every line for the matching `endif`, so the broken line was there to trip
over the first time anything actually set either flag. That was Locket's own
sideload-dylib CI step, the first in a long while (maybe ever, since the conversion) to
pass `SELFCONTAINED=1`. The unconditional `$(foreach ...)` above both blocks (for
JGProgressHUD, `SCIPanelGate` and the rest) was never touched by that commit and sits at
column one, which is exactly why it kept working while its neighbours silently did not.

---

## Verification

`python tools/check.py` — runs in CI before Theos, so a typo fails in seconds
rather than after a five-minute compile. Twenty-four rules, every one of them derived
from a real build failure:

1. duplicate `@interface` definitions
2. brace balance and `%hook`/`%end` pairing
3. hooked class that touches `self` — a property, a message send, *or* `self` as a
   ternary operand — but is never declared, since Logos leaves it a forward declaration
   and all three need a complete type; `@interface`s are read from sources too, and
   Apple-prefixed classes are skipped. Three builds have gone to this in three different
   shapes, the last being `SCITWMediaSubview(self) ?: self` under `-Werror`
4. fragile `%orig` placement
5. unterminated string literals (comment-aware, so `https://` is not a false hit)
6. localization parity and undefined keys — and a missing table at all
7. version match between `control` and whichever source declares `SCIVersionString`
8. project symbols used without their header, resolved transitively — the class
   half of that table builds itself from every `@interface` in the tweak's own
   headers, matched on a word boundary
9. quoted imports that resolve to nothing, checked against the `-I` flags in the makefiles
10. a header promising a method its `@implementation` never defines
11. a block variable that calls itself — ARC rejects the retain cycle, so it is a
    build failure and not a leak
12. a `%hook` whose class name is never bound anywhere
13. an untyped `NSDictionary`/`NSArray` subscripted for a property — the subscript is
    `id` and will not compile
14. `self.<property>` inside a `%group` whose `%init` names its class at runtime, where
    `self` is `id`
15. a C function in a header imported by `.xm`/`.mm` without `extern "C"`
16. a local assigned and never mentioned again — the build runs with `-Werror`
17. an `SCI…()` call whose name is defined in no header this tweak can reach. Five
    tweaks share a layout, a naming scheme and whole paragraphs of idiom, and they do
    **not** share their helpers: `SCIPrefEnabled(...)` is YouTube's and Locket's, was
    written into the X tweak by muscle memory, and killed a runner after every source
    in that tweak had already compiled. Casts and message sends cannot be mistaken for
    calls, but `@interface SCIFoo ()` can — twenty-four false positives on the first
    run, which is why the rule skips Objective-C directives by name
18. `--` inside a `.plist` XML comment — illegal XML, and this project's own prose
    uses `--` constantly. Nothing else here parses filter plists, so this broke
    `AlbrhiCP.plist` silently three times in one afternoon before earning a rule;
    caught only by running the file through `plistlib` by hand each time until then
19. a `%new` method parameter written with an attribute — `(__unused UIButton *)` and the
    like. Logos pastes the written type into `@encode()`, where an attribute is a
    `-Wignored-attributes` error under `-Werror`, reported against a generated line no
    source file contains. Only the parameter list is examined: `__unused` on a *local*
    inside a `%new` body is fine, and matching the whole method would flag those. Cost a
    full CI run, which is exactly the five minutes this file exists to save

A check that cries wolf gets ignored. Four of these produced false positives on
first writing and were tightened before landing. If you add a rule, prove it fails
when it should by reintroducing the bug.

**Two more were narrowed when Albrhi NextUp arrived, and the shape of both mistakes is
the same: a rule that tested a proxy instead of the condition.** A port of an
outside tweak is the hardest thing this file has ever been run against, because it was
written entirely against code that grew up under it — nineteen findings, every one of
them wrong, on sources that build clean upstream.

- **Rule 1 compared files, when the compiler compares translation units.** Twelve
  duplicate-`@interface` reports for classes declared in two files that never meet:
  `NUMusicProvider.m` imports neither `NUPrivate.h` nor the header that does. It now
  resolves each compiled unit's transitive quoted-import closure and reports only a pair
  that actually lands in one of them — which still catches the Instagram bug it was
  written for, where the redeclaring `.xm` imports the header that also declares it.
- **Rule 13's sibling asked "same name", when the bug was "wrong type".** Seven ordinary
  hand-written getters (`- (UIFont *)font` for a `UIFont *font` property) reported as
  fatal. Its own comment already named the real failure — `- (void)close` could not be
  `close`'s getter *because a getter cannot return void* — so it now fires on a void
  return and leaves a normal custom accessor alone.

Both were fixed in the rule, never in the code being checked, and the six pre-existing
tweaks were re-run as the oracle after each edit. **When a rule fires on imported code
that demonstrably builds, suspect the rule** — and read the provenance comment, which in
both of these already described a narrower condition than the code was testing.

**Rule 16 is the clearest instance of both halves of that, and of the oracle worth
reusing.** Its first pattern put a non-greedy `[\w\s*<>,]*?` before the capture, which
ate into the name itself: `NSString *page = …` was reported as `age`, matched nothing
else in the file, and "failed" — 180 findings across four tweaks that all compile clean.
Rewritten to take the last identifier before the `=` rather than guess where the type
ends. **And the other tweaks are the oracle:** they build under `-Werror` today, so any
finding in them is by definition a false positive. That turns "does this rule cry wolf"
from a judgement into something a command answers.

Rule 16 sees only indented locals, and that gap cost the Locket build a run: a file-scope
`static const NSInteger SCILKSectionRecent = 2;` at column 0 went unused when the section
it named was reached as a fall-through, and `-Wunused-const-variable` — a different warning
from the local one — stopped the build. **Rule 16b** covers the column-0 `static const`
case, narrow (only when the name appears nowhere else in its file) and checked the same way
against the oracle. The lesson under the lesson: a rule written for one shape of a mistake
does not cover the others, and `-Werror` has more than one warning that fails a release.

**Rules 8 and 10 exist because one process failure cost two builds in a row, and
then a third edit in the very commit that documented it.** A script with several
`assert`s raises partway through: part of the change is on disk, part is not, and
nothing says so — a half-applied script is indistinguishable from one that worked.
Once the header was written without the implementation; once an `#import` was
dropped; once this paragraph itself failed to land while the commit went out anyway.

Either make the whole change in one edit, or re-read the file afterwards. And when a
script prints nothing where it should have printed a confirmation, that *is* the
failure — do not carry on to the commit.

**The rules are written against one tweak** and use paths relative to it (`src/**`,
`control`). Run from the repository root, `check.py` re-executes itself once per
directory under `tweaks/`, with the working directory moved there. Generalising the
rules in place would have meant rewriting the part of that file most expensive to
get wrong; a ten-line driver leaves every one of them untouched. A failing tweak is named,
and the others still run.

---

## CI, releases and the repo

**A release that fails while "finalizing" leaves a worse state than one that fails outright,
and this happened during a GitHub outage.** `softprops/action-gh-release` creates the release
as a **draft**, uploads the assets, then publishes it. v1.36.0's upload succeeded and the
publish step 503'd, which left: the tag pushed, both `.deb`s attached, and the release still a
draft. Both halves of this repository's own machinery then work against recovery —
`fetch-published-debs.sh` selects `.draft == false`, so the index cannot see it, and
`buildsuite.yml` finds the tag already on the remote and prints "already released — building,
not releasing", so a re-run never publishes it either. **The fix is to publish the draft by
hand from the Releases page, then re-run so the index gathers it.** Worth guarding one day:
the version gate could ask whether a *draft* of the same tag exists before concluding the
release is done.

**And the `deploy` failures in that same outage were not from these workflows.** `deploy-pages`
was deliberately removed from all of them (see below); the failing job was GitHub's own
auto-generated `pages-build-deployment`, which runs because Pages serves from a branch. Nothing
was lost — the finished index is pushed to `gh-pages` before any of that, which is the whole
reason the arrangement is shaped this way.

**Ten workflows, one per thing that ships.**

| workflow | builds | tags | publishes? |
|---|---|---|---|
| `buildtweak.yml` | Instagram | `v*` | manual build only |
| `buildyoutube.yml` | YouTube | `youtube-v*` | manual build only |
| `buildtwitter.yml` | X | `twitter-v*` | manual build only |
| `buildtiktok.yml` | TikTok | — | manual build only |
| `buildnextup.yml` | `com.albrhi.nextup` | — | manual build only — withheld |
| `buildpanel.yml` | the Settings panel | its own namespace | manual build only |
| `buildsuite.yml` | **`com.albrhi`**, the combined package | `v${SUITE_VERSION}` | yes |
| `build-dav1d.yml` | the AV1 decoder Instagram links | on demand | — |

**One workflow publishes: `buildsuite.yml`.** The four per-tweak workflows for what the suite
bundles (Instagram, X, YouTube's own, and TikTok's) were reduced to — or, for TikTok, started as
— manual, non-publishing builds once the suite became the front door: a tweak that will not
compile can block only its own build, never another tweak's release, but nothing short of the
suite's own run ships anything they carry.

CarPlay is the one exception that still has a publishing workflow at all, and it is withheld
until its app bridging is confirmed on a device — see the top of this file for what that took and
how to undo it. **Locket was the second real publisher and is gone**: removed from the repository
outright, with its package names in `WITHHELD_PACKAGES` so the index stops offering the releases
it already made.

**Keep the `albrhi-pages` concurrency group on every workflow that publishes anyway.** It is the
one thing that stops two runs writing `gh-pages` at once, and the arrangement below — a shared
gather, a stated-and-checked index, a run folding in its own build — exists because two
publishers really did race. Albrhi NextUp made that current again rather than historical: there
are **three** publishers today — the suite, NextUp and Watch. `buildsuite.yml`'s own comment
has said three for longer than this line said two, which is the shape a stale line here always
takes: the file that is read first is the file that is believed first.

**And a shared concurrency group cancels a *pending* run, which `cancel-in-progress: false`
does not prevent.** That flag protects a run already executing; a run still queued behind it is
simply dropped when a newer run joins the group, because GitHub keeps only the most recent
pending member. So a commit touching a path both publishers watch — `tools/**` and `shared/**`
are in both trigger lists — starts two runs, and whichever queues *second* cancels the first.
It shows up as `cancelled`, not `failure`, with no error anywhere and no index update, which is
the one outcome this whole section exists to prevent and the easiest to mistake for "it ran".

The practical rule: **when only the second publisher's run matters, push a commit that touches
only that tweak's own directory.** `tweaks/nextup/**` is excluded from `buildsuite.yml`'s
trigger, so a change confined there starts exactly one run and nothing can cancel it. Editing a
shared tool and expecting both publishers to complete in one push is the thing that does not
work — do the shared edit, let the suite take it, then push the tweak-local change separately.

### Publishing Pages: what three releases established

**A repository serves Pages either from a branch or from a workflow artifact, and which
one is a setting no file in the repository can read.** `deploy-pages` only works in the
second; in the first it creates a deployment nothing ever picks up and polls
`deployment_queued` forever. Two releases were spent trying to make it work before the
third removed it — an APT source does not need it, since the `gh-pages` push above it
already holds the finished index and serving that branch has no queue to sit in.

`GITHUB_TOKEN` **may deploy to Pages and may not reconfigure it.** The run still asks the
API to point Pages at `gh-pages` and to build, because both are idempotent and both work
on a repository whose token has the rights — but nothing depends on them, and the failure
message names the one setting a human has to change rather than the symptom.

**What decides success is the live URL.** A step asks it whether the source is serving the
version just built, with `always()`, because the case where that matters most is the one
where the deploy failed. And it polls `/pages/builds/latest` until `built` rather than
sleeping — a build still in progress and a build that will never finish look identical to
a sleep, and 1.0.10 exists because one was reported as the other.

### The per-tweak job

`.github/workflows/buildtweak.yml`, one job:

```
checks → version → decide → [build ×2 + dylib] → release → repo index → Pages
                      ↓ already released
                   reuse published assets, skip the build
```

- **Builds only when the version is new.** Reads `Version:` from `control`; if that
  release exists it downloads the published assets instead of recompiling. Manual
  runs accept `force_rebuild`.
- **Releases publish themselves** when the version is new — no tagging by hand.
  Three assets: rootless `.deb`, roothide `.deb`, and a `.dylib` for sideloading.
- **The repo index rebuilds on every main push**, so adding or removing a package in
  `extra-debs/` takes effect without touching Albrhi's version.
- `debs/` on `gh-pages` is **rebuilt from scratch** each run. It used to be copied
  over, which meant deleted packages lingered in Sileo forever.
- **The last three releases of Albrhi are re-fetched into the index** so a bad build
  can be rolled back from Sileo rather than by hunting for an asset on the releases
  page. They come from the published releases, not from what the previous run left
  behind — keeping the old files in place would preserve deleted extras too, which
  is the exact bug the wipe above exists to prevent. `dpkg-scanpackages -m` already
  indexes several versions of one package; `repo-index.html` shows each package
  once, at its newest, since the landing page is a shop window and not a package
  manager.
- URLs in `control` are rewritten from the repository the build runs in, so renaming
  the repo needs no edit there.
- **dpkg is installed on every run, not only on build runs.** The repo index needs
  `dpkg-deb` and `dpkg-scanpackages` even when the tweak build is skipped; gating
  the whole dependency step behind the build broke exactly that. `ldid` and `make`
  stay gated — only compiling needs them.

### tools/

| file | purpose |
|---|---|
| `check.py` | pre-build source checks (above) |
| `objc-classes.py` | prints a class's real method list out of a Mach-O binary's ObjC metadata — the answer to "does *this* class answer *this* selector", which a selector dump cannot give |
| `make-repo.sh` | builds the APT index from one or more package directories (space-separated, one per tweak); guards against two packages sharing name+version+architecture, and labels each package rootful/rootless/roothide |
| `make-depiction.py` | Sileo native depiction + HTML fallback, generated from the changelog so it cannot go stale |
| `make-logo.py` | repo icon, rasterised in pure Python; drop `tools/logo.png` in to override |
| `deb-edit.py` | edit .deb metadata from a terminal; interactive when double-clicked on Windows |
| `deb-edit.html` | browser control panel: list/remove packages, edit metadata, publish |
| `repo-index.html` | the source landing page; builds its package list from the live index |

**Packages are published under `package_version_architecture.deb`,** not under the
name of the file that was uploaded. A converted package keeps its original filename,
so two flavours of one tweak collided on the same path and the second replaced the
first without a word. The Debian convention encodes exactly what distinguishes them.

**Added packages are prepared by CI, not by hand.** A workflow step runs over
`extra-debs/` on every main push and commits the result with `[skip ci]`:

- `deb-edit.py label` appends `(rootless)` / `(roothide)` / `(rootful)` to the
  display name, read from the package's own `Architecture`. Several flavours of one
  tweak otherwise appear in Sileo under identical names and the wrong one gets
  installed. Idempotent, and a package already carrying a flavour is left alone.
- `deb-edit.py normalize` converts an xz control archive to gzip.

Converting a rootless package *into* a roothide one was considered and rejected:
metadata and paths can be rewritten mechanically, but whether the binary hardcodes
jailbreak paths cannot be determined from outside, so the result would install
cleanly and then fail on the user's device. Build both flavours from source, or use
the jailbreak's own converter.

**Packages with `control.tar.xz` are normalised to gzip by CI**, not decoded in the
browser. An LZMA decoder is a large amount of exacting code whose failure mode is
silent corruption; converting the container costs nothing and the payload is copied
byte for byte. `tools/deb-edit.py normalize` does the work, and a workflow step runs
it over `extra-debs/` and commits the result with `[skip ci]`.

The browser tools carry a **hand-written DEFLATE decoder**. `DecompressionStream`
only arrived in iOS 16.4 and every iOS browser is WebKit, so on the developer's
16.1 phone no browser had it. Writing gzip uses stored blocks — valid DEFLATE, and
far less surface area than a real compressor for a few-kilobyte archive.

---

## Conventions

- Bilingual: never hard-code user-facing text. Add to both tables in
  `SCILocalize.m`; `check.py` enforces parity.
- Logging goes through `SCILogV`, off unless `verbose_logging` is on.
- Comments explain **why**, especially where the code looks odd — most odd-looking
  code here is working around something real and documented above.
- Bump the version in the tweak's `control` **and** its `SCIVersionString` together, and add a changelog
  entry — the release notes and the Sileo depiction are generated from it.
- **And bump `suite/control` as well, or nothing ships.** `com.albrhi` is what people
  install, `make-suite.sh` rebuilds it from *every* tweak, and its version is its own —
  a tweak going from 0.5.0 to 0.6.0 does not change it. `buildsuite.yml` asks the remote
  whether `v${SUITE_VERSION}` is tagged and, finding it, prints "already released —
  building, not releasing": the work is compiled and thrown away, no release, no update
  offered, and a green run. Four version numbers move together, and the fourth is the
  only one a device ever sees.

---

## Known state

Instagram **4.1.18** · YouTube **1.31.4** · X **0.18.5** · Panel **0.9.38** · Watch **0.6.1** · TikTok **0.20.3** ·
Spotify **0.2.4** · YT Music **0.9.2** ·
NextUp **0.2.1** · suite **1.77.0**. **CarPlay is gone** — removed from this repository, to be
rebuilt from scratch in one of its own.

**This line is read first in every session, so it being out of date costs more than it being
absent.** It said Panel 0.9.1 and suite 1.45.0 while the source served 0.9.2 and 1.46.0, and
called NextUp unproven after it had been confirmed on a device. Move it with the four version
numbers, not after them.

**NextUp is confirmed working on iOS 16.1** — the row draws and the queue is read, on Music,
Podcasts, YouTube, YouTube Music and Spotify. The first "it didn't work" was a jailbreak with
per-app tweak injection and the media apps not enabled in it: the display side was up and no
provider answered, which the log named exactly (`kr=1102`, `BOOTSTRAP_UNKNOWN_SERVICE`, defined
in `vendor/LightMessaging/bootstrap.h`). Worth keeping as the first question for any tweak that
spans a system process and App Store apps.

**Its log is compiled in and switched off** (0.1.4), rather than either always-on or compiled
out: an always-on log writes the titles of what is playing into `/var/mobile/nu/` forever, from
a package whose neighbour in this source exists to stop watching being reported at all — and
compiling it out is what left the first install undiagnosable. `NULogEnabled()` reads a
preference, off by default, in Settings › Albrhi › Albrhi NextUp › Advanced.

### Spotify, and what a Swift/Orion tweak costs

**The ad blocking is carried over from EeveeSpotify under GPLv3** — the same licence this repository
ships under, which is what made carrying code over lawful rather than merely possible, exactly as
with Albrhi NextUp. **Its Premium unlock is deliberately not here**, which is the same line this
project drew at Locket's `Check0verPlus`: a tweak that hands somebody a paid subscription is taking
money from the app's developers, not modifying a device. The owner asked for it three times and the
answer did not change; what did change is that the *reason* is now recorded next to the code.

**Why those files could be taken and the rest could not is a fact, not a judgement.** The ad
blockers never consult the subscription state — measured in the upstream sources before a line was
copied. The files that mention Premium are the subscription path and the ad blockers are not among
them. The same reading settled the audio-quality question for good: `high-bitrate`,
`very-high-bitrate` and `audio-quality` are **account attributes** the server sends, rewritten only
by the Premium spoof. There is no 320 kbps hidden on the device to unlock, which is why "block the
ads" is possible and "raise the quality" is not.

**Three things a Swift/Orion tweak needs that a Logos one does not**, each found by asking the built
artefact rather than trusting the build, and none of which produced a warning:

- **`orion_init()` is not called for you.** Logos writes its own `%ctor`; Theos's Orion generator
  emits `@_cdecl("orion_init")` and nothing invokes it. The first build linked, installed, loaded,
  logged its version, read its switches and installed **zero hooks**. Proved by building it both
  ways: without a constructor the dylib has **no `__init_offsets` section at all**.
- **`-runtime-compatibility-version none`, or it does not link.** Swift emits a force-load reference
  to `swiftCompatibility56` that the pinned iPhoneOS 16.2 SDK does not carry. Ruled out as a crash
  cause later by comparing against upstream's own package: neither build carries those shims.
- **SwiftUI cannot be compiled against that SDK at all.** Its `.swiftinterface` was built by Swift
  5.7.1 and the toolchain here is 6.3.3, which refuses to rebuild the module. Any ported file
  importing SwiftUI is out — for SponsorBlock that is the submit-and-report screens, which
  *contribute* segments rather than skip them.

**Two crashes, and both were the same mistake in different clothes: a hook installed before its
target was confirmed.**

- `AdBlockerGroup().activate()` was copied without the `if NSClassFromString("HUB…") != nil` that
  upstream wraps it in. **Activating an Orion group whose target class is absent does not fail
  politely** — and Logos's own answer to this (a `%hook` on a missing class simply never attaches)
  has no equivalent here, so the caller must check.
- **A missing `-D ROOTHIDE` was choosing a different code path.** The ported ad blocker activates
  one guarded group *per class* under that define, and one group covering all five otherwise. The
  port built for roothide and never defined it, so a roothide device silently took the branch
  written for everything else. **A conditional compiled out is not a conditional you can see**;
  upstream's own makefile is where it was finally read from.

**And the fastest diagnosis in this tweak's history was counting.** Clean share links crashed
Spotify because its three hooks named no group — Orion activates ungrouped hooks at startup, before
any gate is consulted, so they installed themselves whatever Albrhi's master switch said. Eleven of
fourteen hooks named a group; the three that did not were the whole fault. **Count the hooks against
the groups**: a file with hooks and no group runs regardless of what was decided.

**Every ported file is kept diffable against upstream** — one line in one file is the only edit, and
it says so where it is. Upstream's `writeDebugLog` wrote every message to a file forever; it goes to
`NSLog` here for the reason NextUp's log was switched off.

### Apple Watch, where it actually stands

**Confirmed on a device: pairing works, and the update hold is installed on all five of its
selectors** — `-manager:scanRequestDidLocateUpdate:error:` on `COSSoftwareUpdateController`, plus
`-startDownload:`, `-startDownload:passcode:`, `-installUpdate:` and `-installUpdate:passcode:` on
`SUBManager`. Every encoding was read off the device before a hook was written against it.

Getting there cost seven releases, and every one of them was a rule this file already contained,
arriving in a place nobody had checked it against:

**The panel gate refused forever, because the question had no answer.** `SCIPanelAllowsThisApp()`
asks whether `app_enabled_<bundleid>` is set; the panel only ever draws that switch on an *app's*
own row, and this tweak is deliberately collapsed into one grouped row. Nothing installed, the probe
never ran, and the report was empty — indistinguishable from a broken tweak. A tweak's own master
switch is the gate when its shape is not one-tweak-one-app.

**A sandboxed process's preference write is redirected, not refused — and reading it back proves
nothing.** The Watch app wrote its report into the shared domain, read it back, found it, and
announced success while Settings saw nothing: cfprefsd had put it in that app's own container,
where the read-back looked. **A self-verifying write verifies the wrong thing when the failure is
redirection.** The report travels as a file now, in the one direction needing no permission either
side lacks — the sandboxed app writes inside its own container, and SpringBoard, unsandboxed, reads
it and copies it into the shared domain.

**And the same redirection made the master switch read as off.** The report said `master OFF, hold
updates ON`, which is *precisely* the two defaults — the signature of an empty domain, not of a
switch. `SCIPanelGate.m`'s daemon-then-file lookup exists for exactly this and was left out of this
tweak on a comment reasoning that SpringBoard is not sandboxed. True of SpringBoard; this tweak
stopped being only SpringBoard three releases earlier. **A comment that was right when written is
not a check that it is still right.** The file answered from
`…/.jbroot-<random>/var/mobile/Library/Preferences/…`, so the `dladdr`-derived prefix was not
belt-and-braces — the plain `/` candidate never answered at all.

**Refusing an asynchronous call is not withholding its answer.** The first hold swallowed
`-scanForUpdates`. The device's own method list said why that was wrong before it shipped: the page
tracks its wait in `-isExpectingScanResult` and `-hasReceivedValidFirstScanResult`, so a swallowed
scan is a spinner that never stops. The answer is replaced instead — `%orig` with a nil update,
which is the path `-noUpdateFoundOrIsComplete` exists for.

**A gate narrower than what it guards fails silently toward doing less.** The hold demanded
`-scanForUpdates` *and* `-checkForSoftwareUpdate:` and installed neither; the second is not on
`SUBManager` in this build at all. Each selector decides for itself now, in its own `%group` —
which matters beyond tidiness, because **a `%hook` on a method a class does not declare does not
politely do nothing: Logos adds it**, and the tweak would be inventing an API Apple never calls.

**Two ambiguous diagnostics, both fixed by saying which.** `not reached` meant either "the app has
not run this build" or "the tweak is switched off"; `OFF` meant either off or unreadable. The switch
values and the source they were read from travel with the report now, and the settings page states
its own gate above the switches rather than only inside a report somebody must think to copy.

**The hold is finished and confirmed on a device: watchOS 26.6 is refused, 11.x would still be
offered, and the page says Albrhi is the reason.** Five more releases, and the lessons are worth
more than the feature:

**A version filter needs a version, and the device is what named it.** `SUBDescriptor`,
`-humanReadableUpdateName = watchOS 26.6`, `-productVersion = 26.6`, `-productBuildVersion = 23U67`,
`-downloadSize = 1879048192` — read by describing the first descriptor the hook ever saw, behind
`-respondsToSelector:`, taking object accessors and then the `q` scalar once its encoding was known.
The comparison is on the **major** alone; a string compare would put `26.6` before `9.5`. **An
update whose version cannot be read is let through**: a hold that fires when it cannot tell what it
is holding is the coarse behaviour wearing a filter's name.

**Feeding nil into a state machine crashed the app.** `-setUpdate:` and
`-handleManagerState:update:error:` were hooked to pass nil while the state still said an update had
been found. Nil-messaging is safe in Objective-C, **which is exactly what made it look safe** — what
is not safe is the code after the message, told a descriptor exists and reading something out of it.
**Refusing a delivery is not the same as never having had one.** Removed the same day, for the rule
TikTok 0.12.1 already established: a crash is worse than the thing being prevented. What replaced
them refuses `-downloadAndInstall:` and `-install:` — the irreversible action, never the machinery
leading to it.

**A specifier list is edited, never rebuilt or removed from.** `-reloadSpecifiers` asks the
controller to build its rows again and discards the edit in the same breath as making it;
`-removeSpecifier:` changes the list the controller is iterating. `-setProperty:forKey:` plus
`-reloadSpecifier:` is what a device has proven here. Rows are found **by structure** — the ones
after the group whose identifier is `INSTALL_BUTTON_GROUP` — because matching "Download and Install"
is matching a localised string, right in English and wrong everywhere else.

**And the page has two shapes, which four releases of diagnostics never said.** Six rows while it
offers an update; **two rows, and no footer anywhere**, once it settles into "your Apple Watch is up
to date". The notice was being stamped onto rows about to be thrown away. Three timed passes did not
help, because the problem was never timing — `2 row(s), 4 with a footer → 1 stamped — last stop: no
row on this page carries footer text` is what said so, and only because each stage counts itself.
The fix is that `footerText` is a property: a group that had no footer draws one when given it. The
report keeps **both** shapes now, since keeping only the first is how the settled page went four
releases undescribed.

**Two diagnostics lied by omission, and each cost a full round trip.** The report is written from
`%ctor`, so every counter in it was a launch-time counter and nothing that happened while the app was
*used* was ever in it — rewritten after anything worth reporting now, throttled to once every two
seconds. And `master OFF, hold updates ON` was *precisely the two defaults*, the signature of an
empty domain rather than of a switch: the Watch app is sandboxed, cfprefsd answered it with nothing,
and `SCIPanelGate.m`'s daemon-then-file lookup had been left out of this tweak on a comment reasoning
that SpringBoard is not sandboxed. True of SpringBoard; this tweak had stopped being only SpringBoard
three releases earlier.

**The four sync features are not being built, and the reason is not a technical failure.** The
owner's own device settled it: **photo sync and notifications already work automatically** on a
watch this tweak has paired, so the feature had no user left. Recorded rather than deleted, because
"we could not" and "there was nothing to fix" are different conclusions and only one of them is a
reason to try again.

**And the reading that led there cost a safe mode, which is the more important half.** The domain
probe sends messages to private classes **inside SpringBoard**, and one branch trusted
`-copyKeyList` to return an array on the strength of its name while the branch ten lines above it
asked `isKindOfClass:` first. An unrecognised selector there is not a failed diagnostic, it is a
phone that will not boot to a home screen. **A feature that fails takes its feature down; a
diagnostic that fails in SpringBoard takes the device down** — so it is off unless somebody switches
it on, and it does not switch itself back off, because a switch that resets itself is a switch that
lies.

**What was learned about NanoPreferencesSync, for whoever needs it later.** They go through **NanoPreferencesSync** —
`NPSManager` offers `-synchronizeNanoDomain:keys:` and
`-synchronizeUserDefaultsDomain:keys:container:appGroupContainer:cloudEnabled:`; `NPSDomainAccessor`
offers typed getters and setters plus `-copyKeyList` and `-domainSize`; both are confirmed in
SpringBoard, where this tweak already works. Nothing has been written yet, deliberately: a
`-setObject:forKey:` on a domain that syncs to a watch is not a diagnostic, it is a change to a
paired device.

**Sixteen guessed domain names all answered `0 byte(s), no keys` while the accessor reported itself
bound with a real pairing ID** — a uniform zero across unrelated things is a broken measurement, not
an empty world, the same shape as every bitrate entry scoring zero for one wrong selector name. The
real names came from listing the device's own registry:
`/var/mobile/Library/DeviceRegistry/<pairingID>/` holds `NanoPhotos`, `NanoMaps`, `NanoAppRegistry`,
`NanoSystemSettings`, `NanoMail`, `NanoPasses`, `com.apple.carousel`, `com.apple.shortcuts`,
`AppConduit`, `CompanionSync`, `PairedSync` and more — **and none of the sixteen guesses was among
them in that form.** Under it, `NanoPreferencesSync/` holds `NanoDomains` and a `database.db`, so a
synced domain is a row in a database rather than a file named after itself. That is where the next
round of reading starts.

### Apple Watch, and what Legizmo settled

**Legizmo Moonstone 6.3 contains no dylib and no MobileSubstrate filter — it injects into
nothing.** That one fact, read from the package in a minute, ended a plan that had already cost
several releases. The tweak this project was writing hooks `SUBManager` inside the Watch app
(`com.apple.Bridge`) to hold watchOS updates; the developer with a year of watchOS work behind him
does not hook that class, or any class, in any process. `SUBManager`,
`SoftwareUpdateBridge`, `COSSoftwareUpdate*`, `NPSManager`, `NPSDomainAccessor` and
`NRPairingCompatibilityVersionInfo` appear **nowhere** in any of its binaries.

What it is instead: a jailbreak **app** in `/Applications`, a `mobile` **LaunchDaemon**
(`legizmoappd`, started by a `com.apple.nanoregistry.devicedidpair` launch event), and a set of
`.lgzfix` plugin bundles loaded into its **own** app. The app links `NanoRegistry`,
`PBBridgeSupport`, `ProtocolBuffer`, `VisualPairing`, `OnBoardingKit` — the pairing and setup
stack. It does its work by *being a second thing that drives pairing*, not by patching the first.

**`LGZHephaestusScopeIdentifier` is a label, not an injection target, and reading it as one is the
exact mistake this file already records about selector dumps.** Each fix declares a scope —
`com.apple.Bridge`, `com.apple.Music`, `com.apple.Maps`, `com.apple.mobileslideshow`,
`com.apple.AppStore` — which reads like a filter list and is not: with no dylib in the package,
nothing of Legizmo can run in those processes. It names the app the fix is *about*, for its own UI.

**The update mechanism, from `BSUCommander.lgzsvc`:** it links `IDS.framework`, `IDSFoundation`,
`ProtocolBuffer` and `NanoRegistry`, speaks a service named `BSU-IDS`, and carries
`BSUChangeEnrolmentRequest`/`Response`, `BSUEnrolmentStatusResponse`, `assetAudience`,
`assetBrain`, `assetUpdate`, `DeveloperSeed`/`CustomerSeed`/`PublicSeed`. So watchOS updates are
controlled **on the watch**, by changing its asset-audience enrolment, over IDS. Not on the phone,
not in the phone's UI, and not by refusing a method call. Its own strings say as much to the user:
"Once configuration completes, check for updates in the Apple Watch app."

**And the screen the owner saw is Legizmo's own.** "Its name appears and it says unsupported" is
`BSU_CURRENT_SEED_CELL_UNSUPPORTED` on Legizmo's Beta Update Support page, whose footer reads that
the watch "is not currently compatible with this method of beta updates." It is not injected UI in
the Watch app, because there is no injection. A screenshot of a screen is not evidence of where
that screen lives, and the package answers it where the screen cannot.

Read for architecture only, on the owner's instruction: a paid commercial tweak, copied from in no
part. `LegizmoThemis` and `LegizmoThanos` are its licence and DRM components and were deliberately
not examined, the same line this project drew at `Check0verPlus`.

**What it means for this tweak, stated plainly rather than optimistically.** Holding a watchOS
update from inside `com.apple.Bridge` is not disproven — it is simply not what the reference does,
and no device has yet confirmed `SUBManager` is even in that process, because the probe has never
run there. The route with evidence behind it runs through **NanoPreferencesSync**, which is
`NPSManager` (17 methods) and `NPSDomainAccessor` (54) — both confirmed present **in SpringBoard**,
where this tweak already runs and already works. That is the phone's supported way of pushing a
preference domain to the watch, and it needs no IDS, no injection into a system app, and no
component on the watch.

### TikTok, where it actually stands

**0.17.0, confirmed on a device: the button, photo posts and the picture-plus-sound clip all
work.** What that release cost is six lessons, and every one is a shape this file already knew in
another form:

**A position chosen by searching the container is as many positions as the container has shapes.**
The button was inserted "after the last interaction view", with two fallbacks under it — three code
paths — and TikTok's rails genuinely differ per video (a like counter, a live badge, a music disc).
So it landed under the like icon on one video and above the avatar on the next, and the search was
not failing. **Index 0 is the one position that requires nothing to be true about the contents**,
and both fallbacks were deleted rather than kept: a fallback here is a second position, and a
second position was the bug.

**A live index read at construction time is a stale index.** `AWEPhotoAlbumModel.currentIndex` is
not what the swipe updates — the class declares `initialIndex` beside it, which is the shape of a
value set once — and the paging controller is what knows
(`AWEPlayPhotoAlbumViewController -currentIndex`, `Q16@0:8`, via the cell controller's
`activePhotoAlbumController`). The deeper fix was *when*: the item is re-resolved in the tap handler
now, not read from what was stashed when the button was made, which also stops a recycled cell
handing over a video ago's item.

**A format string is a callee with types.** Every clip length read `0 seconds`, because `%.0f` reads
a `double` and `5` written as a literal is an `int`. Nothing warns — a variadic argument has no
declared type to check — and it is the same family as the `objc_msgSend` casts that crashed this app
twice, at a smaller scale.

**A data resource has no type, so Photos infers one from the file name — and the name was a
guess.** It came from the URL's last path component with `.jpg` appended, which announced a WebP as
a JPEG and earned `PHPhotosErrorDomain 3302` for releases. **The first four bytes are a fact**;
naming the file from them is what made photo saving work at all. Alongside it, `+dataWithContentsOfURL:`
was replaced with `NSURLSession` — not for the headers, but because **it cannot report an HTTP
status**, so a 403 page and a photograph were both "some bytes".

**A diagnostic written by every call describes no call.** The photo-chain row was set on every model
the resolver walks — overwhelmingly ordinary videos — so one report read
`AWEAwemeModel → photos ×0 (empty) → 6 link(s)`, three fragments of three different calls. It is
committed only on a successful extraction now. The same release then shipped a second instance of
it: the row said `index unknown via activePhotoAlbumController.currentIndex (Q)` — one sentence
disagreeing with itself — because the index was printed from a static that is reset constantly while
the saved item held the real one. **Print state from the object that kept it, not from the last
thing that touched a global.**

**`%orig` is never captured in a block, and the replacement is a replay.** A confirmation answers
after the hooked method has returned, so the obvious shape is calling `%orig` from the alert handler
— the fragile Logos construct this file warns about. Instead a flag is raised and the same selector
re-sent to the same object; the hook passes it through. Nesting becomes safe by construction, since
an inner call sees the flag. And **a confirmation that cannot be presented lets the action
through** — refusing instead would turn "ask me first" into "liking is broken", the same
right-principle-wrong-place mistake as hiding the download button when a lookup failed.

**And two rules about screens, both learned by shipping the opposite.** A settings screen with
fourteen diagnostic rows among six switches is two screens interleaved, not one long screen — the
diagnostics now sit one row away under Advanced. And a system `UIAlertController` over TikTok's feed
reads as an error from the app: the tweak's own sheet (`SCITTSheet`, a view in the key window, so no
presentation state can conflict) is what makes a question look deliberate.

**Working, and confirmed on a device:** the ad filter, the three privacy switches, the
jailbreak bypass, and the in-feed download button — which appears on every video, sits above
the profile picture, and saves the clip actually being watched, as a real video file.

Getting there took twelve releases and the errors are worth more than the result:

- **The button belongs on `AWEFeedViewTemplateCell`, not on the interaction rails.**
  `TTKFeedInteractionStackView` and `TTKFeedRightInteractionStackView` are stack views whose
  arranged subviews TikTok rebuilds; a guest is swept out. Both rail hooks remain but stand
  down whenever a cell button exists, and the report counts the two separately.
- **The cell is a container, and the model belongs to the controller it hosts.**
  `AWEFeedCellViewController.model`, reached through the cell's `-viewController`. The cell
  has no aweme accessor of its own — which is why two releases of trying more names on it
  found nothing, and why NA9 hooks `AWEAwemeBaseViewController` while putting its button on
  the cell. Those are two halves of one design and I read them apart for four releases.
- **The link comes from `AWEVideoModel.downloadNoWatermarkURL.originURLList`.** Confirmed
  from the class's own accessor list printed by the device, after `downloadAddr` was guessed
  at twice — from NA9's binary and from a framework-wide selector dump — and is on no class
  here at all.

**Quality: settled in 0.13.0, and the fix is the two measurements this file had already
written down rather than a new idea.** `bitrateModels` is a *list of alternatives* and the
right one is chosen by comparing them — every other resolver here walks a path and takes what
it finds, which is why "it saves SD" survived every chain reporting success. 0.12.0 tried and
crashed the app; 0.13.0 does it with both of that release's mistakes answered:

1. **`-bitRate`'s type is read from the runtime, never assumed.**
   `property_getAttributes(class_getProperty(cls, "bitRate"))` gives the real encoding and the
   value is read through a matching cast — `q`/`l`, `i`/`s`, `Q`/`L`/`I`, `d`, `f`, `@`. An
   encoding not in that list scores **zero** rather than being guessed at, so an unreadable
   variant loses a comparison instead of crashing a process. A framework dump gives names, not
   signatures; the runtime gives signatures.
2. **The ladder is only read for a settled model, and that is a second entry point, not a
   flag.** `+captureModel:` is called from the aweme model's own `-init` hooks, where `-video`
   is half-built — the exact object 0.12.0 walked. `+captureSettledModel:` is called only by
   the feed cell's button, holding `AWEFeedCellViewController.model`: an object the app has
   finished with and is showing on screen. "Is this safe to walk" is a fact about the *caller*,
   so it is expressed as which function the caller may call. A parameter would let a future
   caller answer it wrongly, and that is precisely the mistake being guarded against.

Failure at any step falls through to the ordinary chains, which already produce a working file.

**Photo posts were never downloadable at all, and nothing said so.** A photo post has no
`-video`, so every chain reported failure and the button had nothing to offer — indistinguishable
from a broken resolver, and read as one for a while. Images come from `imagePostInfo` →
`images`/`imageList` → `displayImage` → `originURLList`/`urlList`, saved one at a time with the
result reported as "saved N of M": a post of twelve where two fail is not a failed download, and
a single yes/no would have called it one.

**The seek bar needed no drawing.** TikTok already has `AWEFeedPlayerBottomProgressBar` and
merely hides it outside a drag, so the feature is refusing the hide — `-setHidden:` answered
`NO`, `-setAlpha:` refusing zero. Nothing positioned, nothing added to a view hierarchy, so none
of this file's placement lessons apply. Worth noticing before building a bar: the app often
already has the view and is only choosing not to show it.

**The quality ladder is not stable between videos, and that killed the "prefer the ladder"
design.** One report showed five gears topping out at 720; the next showed a single
`comet_lowest_540_1`. TikTok populates only the gears it is streaming, so preferring the ladder
takes the worse file precisely when the app has not fetched the better one — and preferring
`downloadNoWatermarkURL` instead is the same mistake pointing the other way. **No name is
reliable, so 0.14.0 stopped comparing names and started comparing bytes**: every link is
collected and `HEAD`-ed, and the largest wins. Every earlier quality attempt here argued about
which accessor was better; `Content-Length` ends the argument, and a link that refuses `HEAD`
scores zero and sinks rather than being dropped, because a server that refuses `HEAD` still
serves `GET`.

**Both reference tweaks fetch HD from `tikwm.com`, and reading their binaries settled that it
is not one author's shortcut.** `https://tikwm.com/video/media/hdplay/%@.mp4` is a literal
string in NA9 *and* in VibeTok, and NA9 carries the non-HD `…/play/%@.mp4` beside it — so the
reliability people attribute to those buttons is the external service, not a better internal
chain. Recorded so the question is not reopened as if an undiscovered accessor exists.

**What the same read confirmed about our own chains, which is the more useful half.** VibeTok
sends exactly `photoAlbum` → `photos` → `originPhotoURL` → `originURLList`, and NA9 sends both
that and the `imagePostInfo`/`images`/`displayImage` family — which is what this tweak settled
on in 0.13.2 after two wrong releases. Both also *ask* which picture (`na9ShowPhotoDownloadSheet:`),
which 0.14.0 arrived at independently. And NA9's `downloadMusic:` shows the `.mp3` is a
deliberate separate feature there, not the accident it was here.

**A counter that does not count the path that runs reports working code as broken.** The
watermark hook incremented only at the setter, which this build never calls; the getter — the
one doing the work — answered silently, so the screen read `0 cleared` for two releases. Third
instance of this family here, after the last-event snapshot and the mislabelled parallel array:
**before believing a zero, check that the counter sits on the path that executes.**

**`__playBSModel` is not the player's ladder either — it is one gear at the same low bitrate.**
0.16.0 tried to reach the high-bitrate models without a hook by reading `__playBSModel`,
`__playBSModelV2`, `awe_playBSModel` and `ttk_playBSModel` off the video model. The device
answered `×1` for each, at `331,128` — the same number `bitrateModels` already carried, so every
one deduplicated back into the existing ladder. **The four-times-larger list is not on the object
this tweak holds at all**, which closes that line of attack rather than suggesting a fifth
accessor to try. The only place it has ever been observed is the argument of the player's own
selection method.

**`%hook` on a method the class does not declare, fired at a rate nobody measured, crashes it
too.** The universal button surface hooked `-viewDidLayoutSubviews` on
`AWEAwemeBaseViewController` — whose own method list is `loadView`, `setModel:`, `viewDidLoad`
and nothing else — and did a full quality-ladder walk inside it, on the main thread, on every
layout pass while scrolling. **Two unchecked assumptions, one crash**: that the method was there,
and that running it was cheap. `-setModel:` is declared on the class, fires once per video, and
is the bind point anyway.

The general rule now has two halves: before hooking, ask what the class *actually declares*
(`tools/objc-classes.py`) **and how often the method runs**. Frequency is part of a hook's cost
and has never been checked here until it cost something.

**A `%hook` with a guessed method signature crashes the process, and it is the same mistake as
a guessed cast.** 0.15.1's probe declared `willSelectBitrateFromModels:duration:trategyType:
autoBitrateModel:` as `(double)`, `(NSInteger)`, returning `id`, none of it read from the
runtime — arguments then arrive in the wrong registers and of the wrong widths, and TikTok died
repeatedly. **This project had already written down the identical lesson for `-bitRate`'s cast
in 0.12.0**, and it was repeated in the one file whose whole purpose was to stop guessing.

**The real encoding, once the device was asked:
`v48@0:8@16d24^q32@40`** — returning `void`, and `trategyType` is **`^q`, a pointer to a long
long**, an out-parameter. 0.15.1 declared `id` and `NSInteger`: a wrong return type, and a value
written where a pointer belongs, which writes through whatever integer happened to be in that
register. That is not a subtle mismatch, and one runtime query would have shown it.

Before hooking a method whose signature is not documented: `method_getTypeEncoding` on the real
method, compare it against what is about to be declared, and stand down on any mismatch —
`class_getInstanceMethod` returning non-NULL proves the selector exists and says nothing about
its types. And note what made this expensive rather than merely wrong: the probe was shipped to
a device before its own preconditions were checked, so **the cost of a bad measurement is paid by
the person running it.**

**Correction: `bitrateModels` is not a reduced *copy* — it is the same list read at a different
*time*, and the numbers arrive later.** The paragraph below was written from one report where the
two lists were printed side by side, and it was stated as structure. A later report on the same
build disproved it: `bitrateModels` came back reading `adapt_lower_720_1 @ 1,448,977` — the
million-scale figure, from `bitrateModels` itself, with no probe involved. So the ladder is
populated progressively, and a read that happens before the app has fetched the real gears sees
placeholder numbers. **"Two different lists" and "one list, read too early" produce identical
evidence in a single snapshot**, which is the tally-versus-snapshot trap again, one level up: a
claim about structure needs the same value observed twice at different moments before it is a
structure at all.

What follows is kept because the *comparison* was real and worth recording, with that correction
standing in front of it:

**`bitrateModels` looked like a reduced copy of the playback ladder — same gear names, a quarter
of the bitrate — and that single fact seemed to explain every quality complaint in this tweak's
history.** The
0.15.1 probe printed both lists on one screen: `adapt_lower_720_1` reads **373,349** through
`bitrateModels` and **1,512,265** in what TikTok hands its own picker; `adapt_540_1`, 308,455
against 1,015,884. So "it saves 720 and it looks worse than the app" was true in both halves at
once — the right gear, a quarter of the data. The player's models live on `__playBSModel` and
siblings on the *same* video model, which is why 0.16.0 reads them from that object rather than
from the probe's arguments: no cross-video risk.

**And the probe disproved the theory it was built to test, which is the point of a probe.** Not
one of the player's gears carries a `selectedAudio`, so audio is muxed there too and simply
follows the bitrate. The paragraph below was the standing hypothesis and is kept as a record of
what the structure *permits* rather than what this build *does* — a distinction worth keeping,
since the class declarations really do describe two streams:

**The download takes a muxed streaming copy; the app plays video and audio as two streams, and
that is why the saved audio sounds worse.** `AWEVideoBSModel` — the gear entry — declares
`selectedAudio : AWEAudioBSModel`, whose `audioMeta` carries its own `bitrate`, `codecType`,
`quality` and `urlMap`. So a gear *points at* an audio track rather than containing one, and
`playAddr` is a prepared fallback whose audio is whatever was baked in. The arithmetic agrees: a
top gear of ~550 kbps is the total for both tracks.

**And every gear ever seen here is named `lower` or `lowest`** — never `normal_720`, never
`adapt_higher_` — across every device report, while `AWEVideoModel` declares
`_HDRBitrateFilterGears` and `bitrateFilterList` and `AWEVideoPlayBitrateControler` has
`willSelectBitrateFromModels:duration:trategyType:autoBitrateModel:`. Either that is the whole
ladder or `bitrateModels` is a filtered subset and the player is handed more. **0.15.1 answers
that by probing the player's own picker instead of inferring**, which is the discipline this file
demands and which the previous two releases skipped.

**Confirmed on a device: the tweak now saves 1080 at 60 fps — the quality this whole line of
work was about.** It comes from the external switch, which means it comes with the privacy cost
stated on its own row; **internal-only downloads remain 720 at 30 fps**, because that is what
TikTok streams to the app and no accessor here was ever hiding anything better. Both halves
matter when describing this feature: the quality is real, and so is where it comes from.

**Corrected twice, and the second correction reverses the first: the external service returns
the *original upload*, and on some videos that is dramatically better.** A later device report
took tikwm's file at **13.9 MB against `bitrateModels`' 4.5**, and the saved clip came out at
**60 fps while every gear in TikTok's own ladder reported 30**. So TikTok streams a re-encoded
30 fps copy and the service hands back what the creator uploaded — which explains the size, the
frame rate, and NA9's "1080 60fps" in one stroke.

**The paragraph below is still true of the video it was measured on, and that is exactly the
problem with it.** One sample where `hd_size` matched our bytes became "the external route adds
nothing", stated as a general fact. That is the same error as calling `bitrateModels` a reduced
copy from one snapshot — **twice in one session, generalising a behaviour from n=1**. Keep both
findings side by side: sometimes identical, sometimes three times the file and double the frame
rate, and nothing observed so far says which video will be which.

**On one video the tikwm "HD" file was byte for byte the file this tweak already downloads, and
that was measured, not argued.** Querying the service for a video taken from a real device report:
`wm_size` 8,399,664 (the watermarked copy the ranking already refuses), `size` 4,567,673, and
`hd_size` **3,786,622** — precisely the 3,786,622 bytes the tweak had saved through
`bitrateModels`. **So "NA9 gets 1080 60fps" is not a better pipeline; when the ladder tops out at
720 that is the upload's ceiling and no service invents pixels.** The switch stays because it was
asked for and other videos may differ, but it is not the answer to quality and must not be
described as one.

**And `…/video/media/hdplay/<id>.mp4` is not an endpoint** — it answers 400 for an id the service
has not been asked about. It is an API: one JSON request names the links and the shortcut works
only afterwards. NA9 parses JSON for exactly this call, which its binary showed plainly and which
was read here as decoration for two releases. **A reference's request shape is part of its
technique, not incidental.**

**A `User-Agent` was the wrong diagnosis, and testing it took one command.** The theory was that
`tikwm.com` only answers browsers; a direct `curl` with and without a browser `User-Agent`
returned 400 both times. Sending a real `User-Agent` is kept (it costs nothing and is correct on
its own terms) but it fixed nothing, and **the fix was to test the hypothesis from this machine
before shipping a release built on it** — the same discipline this file already demands of
shell scripts.

**A switch the user turned on is a decision, not an input to a ranking.** The external HD link
was competing on measured size and losing to internal links; it now takes precedence when it
answers, and keeps its ordinary rank when it does not, so an unavailable service costs nothing.

**"Unmeasurable" is not "worst", and treating it as worst disabled a feature the user had
switched on.** `tikwm.com` refuses `HEAD`, so the external HD link scored zero and sank below
every internal one — the switch was on and changed nothing. A one-byte range request is a plain
`GET` and any server that serves the file answers it, with the total in `Content-Range`. **Ask
the same question a second way before concluding the answer is no.**

**A parallel array must be walked in lockstep, never re-found by value.** The origins list was
indexed with `-indexOfObject:` while the links list had the external address inserted at the
front, so every label named the *previous* link's accessor — a report that stayed entirely
plausible while being wrong throughout. Worse than no labels, and the same shape as the tally
that reported the last event.

**A fallback that is only reachable when the primary succeeds is not a fallback.** Photo saving
re-encoded to JPEG when Photos refused the format — but the re-encode needed `UIImage` to have
decoded the bytes, and the case it existed for is exactly when `UIImage` returns nil. `ImageIO`
decodes what `UIImage` declines. Check what a fallback *depends on*, not just when it fires.

**A bigger file is a worse file when the codec differs, and this is the third time size answered
the wrong question.** `h264DownloadURL` was demoted on a guess from its name, then promoted to
test that guess — the honest experiment — and the device answered plainly: it won at 7.2 MB
against 5.3 and 2.9, saved 7,561,985 bytes, and the owner reported the picture as *worse than
before*. `AWEVideoBSModel` declares `codec` and `isBytevc1`, so TikTok's modern stream is HEVC and
`h264DownloadURL` is the compatibility re-encode; H.264 needs far more bits for the same picture,
so a larger H.264 file and a smaller HEVC one are not comparable quantities at all.

First audio, then the watermark, now the codec: **bytes compare two encodings of the same thing,
and never say which thing or which encoder.** The demotion is back, under a name that says what
it means (`SCITTOriginIsDemoted`) and with both reasons written down — one guessed and confirmed,
one guessed, tested, and found true for a completely different reason than the one assumed.

**And the same mistake was made a fourth time, in photos, by the hand that wrote this
paragraph.** TikTok photo variants were sorted by measured bytes and the largest downloaded —
which is `userWatermarkedPhotoURL`, at the identical 1170×2080, because a watermarked copy is the
same picture re-encoded with something painted on it. The measurement was right and the outcome
was worse. **Kind decides first; bytes settle ties inside a kind** — clean variants ordered by size
among themselves, watermarked ones among themselves, and the clean list walked first whatever the
sizes say. Reading a rule is not the same as applying it in a new place.

**A measurement can only rank what it can see, and "which copy is watermarked" is not in the
response.** Ranking candidates by size took `downloadURL` — TikTok's *watermarked* save copy,
and reliably the largest file — so every download came out stamped. No amount of measuring fixes
that: the only thing that knows is the accessor name the link came from, so the origin now
travels beside each URL and clean beats watermarked before size is consulted at all. Pair this
with the audio lesson above: **size answers "which is bigger", never "which is right"**, and
each new wrong-file report has been a different property that size cannot see.

Separately, `AWEAwemeACLItem.watermarkType` is forced to zero **at its setter**, not at a getter
— the same reason `-bypassOnesie` failed in the YouTube tweak: code that reads the ivar directly
never passes through a getter hook, while a stored value is true for every reader.

**Measuring by size alone reintroduced the audio bug this project had already paid for once.**
0.14.0's `HEAD` gave both `Content-Length` and `Content-Type`, and only the first was kept —
so a 0.9 MB `audio/mpeg` beat an `.mp4` whose server answered 400, and the save was the music.
**A measurement is only better than a guess when it measures the right quantity**: kind decides
first, size settles ties between videos, and a link that refuses `HEAD` still outranks a known
audio one, because refusing to answer is not evidence of being the wrong thing.

**And a photo post carries a video model too.** TikTok renders a slideshow as a video, so
putting the video branch first in `+captureSettledModel:` meant a photo post always saved a
video — the picture branch was never reached. The rule is an ordering, not a test: a post that
has pictures is a photo post whatever else it carries, and both entry points must ask in that
order. Worth noting both faults were found by the diagnostics added in the same release that
caused them; a report that names what it chose is what makes a regression visible in one round.

**The tikwm.com path is now shipped, as a switch, off by default — and this file's earlier
refusal was not wrong, it was a different question.** It was refused as *the fix*, arriving
quietly; the owner then asked for it knowing the trade, which is exactly the case the refusal
reserved. It stays off unless someone turns it on, its own row states that enabling it tells an
unrelated service what they are watching, and with it on the external link is measured against
the internal ones rather than trusted for being external. The line this project keeps is not
"never touch a third party" — it is that a privacy cost is never paid on the user's behalf
without them being told.

**The ladder answered the quality question, and the answer was that nothing was wrong.** A
device report listed five gears topping out at `adapt_lower_720_1` — so 720 was TikTok's own
ceiling for that video and the picker was already taking the best. It also showed
`bitrateModels`, `SDRBitrateModels` and `HDRBitrateModels` are the *same five gears* on this
build, printed three times: gathering all three costs nothing and stays, but the report
deduplicates. Worth noting what the row bought — it ended a line of inquiry rather than opening
one, which is what a good diagnostic does.

**A crash is worse than SD** — that is why 0.12.1 exists, and it is the rule to keep if the
HD attempt goes wrong again.

- **CarPlay is built but not served.** The code is complete and compiles; the package is
  kept out of the APT index until its app bridging is confirmed on a device. Install it
  by hand from `buildcarplay.yml`'s artifact in the meantime. See the top of this file.

- **Working, Instagram:** inline download button (posts + reels), Download Center queue,
  story seen-receipt control, per-message mark-as-seen in DMs, follow-back badge, feed and
  reels cleanup, confirmations, bilingual UI, diagnostics, auto-release, APT source.
- **Working, YouTube:** downloads with their own Download Centre tab and player, ad
  blocking at three layers, SponsorBlock with per-category switches and progress-bar
  markers, background playback, diagnostics.
- **Working, Panel:** Settings › Albrhi, one switch per patched app. Turning one off
  leaves the package installed and the settings intact. The app must be reopened for a
  change to take effect, and **how the tweak reads that switch is a ground rule above** —
  it was written correctly and read nothing for a release.
- **The reels download button broke in 4.1.0 and shipped broken.** Binding by the exact
  Swift runtime name worked and was replaced with a search over `objc_copyClassList`;
  inside a `%ctor` that search does not find what `objc_getClass` still finds by name. A
  search is a fallback for when the name is unknown, never a replacement for a known one.
- **Reels auto-advance** (`reels_auto_next`) works again, under Reels settings, on
  both 410 and 439 from one build. It was hidden for a long time because it never
  fired: the old hook forced `-autoScrollState` (a 410-only getter, gone in 439) and
  left `-isAutoAdvanceEnabled` — the one gate present on both — untouched. The gates
  differ by version: `-isAutoAdvanceEnabled` and `-autoAdvanceToNextItem` on both,
  `-shouldForceEnableAutoScroll` (the server-flag override) on the Swift
  `IGSundialAutoScroll` engine in 439 only, `-autoScrollState` in 410 only. The hook
  forces every one that exists, on whichever class owns it, each behind a
  `class_getInstanceMethod` guard so a selector a build lacks is skipped rather than
  added as a dead method. Established by counting the Sundial selectors in the real
  410 and 439 binaries, not by guessing — the point of keeping both IPAs around.
- **Removed in 3.1.4:** liquid glass, teen icons, doom-scrolling limits, per-surface
  download toggles, long-press tuning, keep-deleted-messages, quality picker. They
  were broken or made redundant by the inline button. Do not reintroduce without a
  reason.

## When something does not work on device

1. Settings → Diagnostics → read what actually attached
2. Magnifier button scans the live view hierarchy and names the real classes
3. Speech-bubble button files a GitHub issue with the whole report attached

That loop replaced several rounds of guessing. Use it first.
