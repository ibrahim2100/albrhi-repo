# Albrhi for YouTube Music — what changed

## v0.9.3

**مزوّد Anthropic كان يستلم «أريد JSON» ويرميه.** البروتوكول يمرّر `expectJSONMode`، وOpenAI
يترجمه إلى `json_object` وGemini إلى `responseMimeType` — أمّا Anthropic فيأخذه ولا يقرؤه، لأن
الـAPI لا يعرف «وضع JSON» بلا مخطّط. فتوحيد العنوان واستخراج الكلمات من الوصف كانا يمرّان عليه بلا
أي قيد على الشكل، ويعتمدان على الصياغة وعلى محلّل يُصلح ما يفلت.

صار كلٌّ من المستدعيَين يمرّر **مخطّط** ردّه، والترجمة نفسها تُرسل مخطّط `{"lines": [...]}`، عبر
`output_config.format` — فالردّ على خادم Anthropic مضمون الصحّة بدل أن يُرمَّم. **ويُرسَل للمضيف
الرسمي وحده**: عنوان Anthropic قابل للتعديل، ووسيطٌ لا يعرف الحقل قد يرفض طلباً يعمل اليوم؛ من
يستعمل وسيطاً يبقى على التعليمات والمحلّل المرن كما كان تماماً.

**والمخطّط ثابت عن قصد**: عدد الأسطر لا يدخله، لأن كل مخطّط جديد يدفع كلفة تجميع، ولأن قيود طول
المصفوفة غير مدعومة أصلاً. عدد الأسطر يبقى قاعدة في التعليمات تتحقّق منها خطوة المحاذاة.

**و`max_tokens` صار 32000 بدل 8192.** Claude Opus 5 يفكّر افتراضياً وClaude Opus 5.5 يفكّر دائماً،
والتفكير يُحسب من `max_tokens` حتى حين لا يعود نصّه — فالسقف القديم، المقيس من فاتورة بلا تفكير،
قد يقطع أغنية طويلة في منتصف المصفوفة على هذه النماذج. الفوترة على ما يُولَّد فعلاً، فالسقف لا
يكلّف شيئاً في أغنية عادية.

**وتعليمات الترجمة بنبرة عادية.** عشر علامات ضغط (`ONLY`، `MUST`، `Do NOT`، «no exceptions») في
عشرين سطراً صارت جُملاً عادية، وقاعدة عدد الأسطر المكتوبة أربع مرّات صارت جملة واحدة — **دون حذف
أي متطلّب**، لأن الوسيط وOpenAI وGemini ما زالوا يعتمدون عليها. و«Strict rules — non-negotiable»
في مستخرج الوصف صارت «Rules».

**وما بقي عن قصد:** المحلّل المرن (~250 سطراً) يخدم الوسيط والمزوّدَين الآخرين وحالات `refusal`
و`max_tokens`؛ وقاعدة «لا تكتب ولا تُكمل الكلمات» في مستخرج الوصف فشلٌ حقيقي في النماذج الحالية.

## v0.9.2

**A regression from the audit pass, found on a device and fixed: some version numbers and
protobuf fields read as empty.**

`SCISafeValueForKey` — the guarded accessor that replaced `-valueForKey:` everywhere — checked a
getter's return type by reading its `Method`. **`class_getInstanceMethod` returning NULL does not
mean the object cannot answer.** A class may resolve a selector dynamically
(`+resolveInstanceMethod:`) or forward it: `-respondsToSelector:` says YES and there is no method
to read an encoding from. The check treated that missing encoding as "not an object" and returned
nil.

Two whole families of class do exactly this. `LSApplicationProxy`, which is where the panel reads
every installed app's version from — so rows showed no version. And every protobuf class, which
is what YouTube's renderers are (`YTIPivotBarItemRenderer` and the rest), read for tab
identifiers and item lists.

`-methodSignatureForSelector:` is the fix: it is what the forwarding machinery itself consults, so
it answers precisely where the method list does not. Proved against a class with a dynamically
resolved accessor before shipping — it now returns what `-valueForKey:` returned, which is the
whole bar this replacement has to clear.

Also corrected in the same file: KVC tries `getKey` **first**, not last. It shipped last, on a
comment asserting Foundation does the same. It changes nothing unless a class declares two of
them and they disagree — but a replacement for KVC has to match KVC, and an order asserted from
memory is not a match.

## v0.9.1

**A repository-wide audit pass. No feature changed; what changed is that three rules this
project already had in writing are now enforced by the tools instead of remembered.**

**`-valueForKey:` is gone from this tweak.** It is not a probe — it runs the receiver's own
getter, and reads the ivar directly when there is none, so `@catch` protects nothing: it catches
`NSException`, while a Swift getter that traps or a half-built object ends the process with no
handler running. It was documented as this project's most expensive habit for a year and used
108 times across the repository regardless, because nobody greps a design document before
writing a hook. Every call now goes through `shared/src/SCIKVC.h`, which resolves a key the same
four ways KVC does — `-key`, `-isKey`, `-getKey`, then the ivar — but checks each getter with
`-respondsToSelector:`, reads it through a cast taken from its own type encoding, and touches
the ivar only when the runtime says it holds an object. **And `tools/check.py` rule 23 refuses
the old form**, so it cannot come back.

**The localization orphan count is trustworthy for the first time.** It counted a key as used
only inside `SCILocalized(@"…")`, so keys handed to something that localizes them later read as
dead — 54 reported in X where 5 were real. A warning wrong five times in six is a warning nobody
reads, and the real ones sat in that noise for releases. Dead strings removed with it.

`YTMUKVC` is gone with it. Its whole body was the banned pattern in a helper — a `-valueForKey:`
inside an `@try` — so the fifteen call sites that went through it now go through the shared
accessor instead, and the file that made the unsafe thing look handled is deleted rather than
rewritten.

## v0.9.0

**Downloading works, and the reason it never had is worth more than the feature.**

The installer had been **commented out since 0.8.4** — stood down as a suspect while a crash was
investigated, cleared in 0.8.5 when the real cause was found elsewhere, and never returned to duty.
Every round of work on downloading after that was on code that could not run, and the reports were
honest the whole time: they said no class had been found, which was true, because nothing had ever
asked. A commented-out call is invisible to every diagnostic there is. What exposed it was counting
the *install attempts* and seeing zero on a build whose report was otherwise healthy.

Two more faults were underneath it. `NSClassFromString` in a `%ctor` answers nil for a class the app
certainly has — the constructor runs before the app's own Objective-C metadata is registered — so
the install is retried when the app finishes launching and once more after that. And the badge asked
the now-playing controller for `playerViewController`, which its **parent** declares; the long press
walked to the parent and worked, the badge did not, and reported *this track carries no stream*, a
sentence about the content when the fault was the lookup.

**What downloading now is.** A confirmation card of Albrhi's own — the mark, the red, a name filled
in from the track, and a section to keep it in, with the sections that already exist offered as taps
because a folder is easier to choose than to spell. Sections are folders read off disk, so one made
in the Files app appears and one deleted there stops being offered. A second way in, a long press
anywhere on the now-playing screen, which depends on no server-generated name at all. And a banner
in place of the modal alert that used to ask for a tap to acknowledge something that had gone right.

**A transport of our own.** "I cannot pause or skip" had one cause and it was not interference: a
file of ours plays through our own player while every control on screen belonged to YouTube Music's.
The Downloads screen has play and pause, previous and next, and a scrubber with elapsed and total —
and the audio session is re-asserted on resume, because the app takes it back whenever its own
player starts.

**And the page finally sits where it should.** Seven attempts, seven different causes: the inset
measured from a parent that hands children a zero safe area; applied without moving the existing
offset; read from a view whose window was nil; undone by `-reloadData`; read from whichever window
happened to be key, which can be a keyboard overlay reporting zero; the transport placed above the
tab bar and under the app's own mini player; and finally the safe area itself, which describes the
device and knows nothing about the header the app draws below it. The list is given a *frame* now,
below whichever of the two ends lower, with the app's chrome measured off its own views by shape
rather than by name.

The Downloads tab has its artwork, painted onto the button rather than asked for through a renderer
— an icon type the app has no case for is what stopped it opening in 0.8.1.

## v0.8.7

**The download diagnosis is on the first settings screen now, under the master switch.**

0.8.6 put it on the Downloads tab's empty state, which is right for somebody staring at an empty
library and wrong for somebody whose complaint is *the button asks me to subscribe* — that person
never gets as far as a library. It is a subtitle on the row everybody sees first.

A subtitle rather than a new section, deliberately: this screen's row counts are a hand-written
`switch`, and adding a section to it without updating that is exactly what crashed it once already.

**Also confirmed by reading the reference tweak's source rather than guessing:** YTMusicUltimate
does not unlock Premium, does not fake an entitlement and does not hide the prompt. It intercepts
the same tap this does and offers its own download beside a third action that calls `%orig` and
takes you to YouTube Music's own subscribe screen. There is no hidden trick being missed here — and
its interception is *narrower* than this one, requiring the exact node key `music_download_badge_1`
and the now-playing screen as an ancestor, both of which this build dropped after that literal key
failed to match on a device.

## v0.8.6

**The download button still shows the Premium prompt, and the empty Downloads screen could not say
why.**

Three completely different failures wear that same face: the interception never installing, the
class it hooks never being called for that tap, and being called on every tap but never recognising
the badge. Each needs a different next step, and until now the screen showed only the node keys it
had seen — which is blank in the first two cases and blank in the third if no tap ever carried a
key.

Each is counted separately now, and the Downloads screen says which one happened in one line: the
class not being in the build, the hook never reached, taps seen but none naming a download, or the
badge recognised with a count of what came of it.

Nothing about the Premium gate itself changed, and nothing will: this intercepts the tap and runs
Albrhi's own downloader instead. It does not unlock YouTube Music's offline library, which is a paid
feature and the same line this project drew at Locket's entitlement patch and at Spotify's Premium
spoof.

## v0.8.5

**The crash was a number.**

0.8.1 gave the new tab an icon type of **9931** — a value chosen precisely because the app has no
meaning for it, so a drawing hook could recognise it. **The app draws the tab bar at launch**,
reached a type it has no case for, and stopped opening.

Three releases went past it. The download interception was removed, and two real but unrelated
faults were found and fixed, and the crash survived all of them — because none of them was a number
in a renderer. **Each fix made the tweak better and none of them made the app open**, which is the
signature of a diagnosis aimed at the wrong change.

The type is back to `1`, which is what 0.8.0 shipped and what opened. The custom drawing hook is
gone with it: at type 1 it could not tell our tab from the app's own, and a tab that needs no hook
is a tab that cannot crash. **The glyph is given up rather than paid for a fourth time.**

**A value an app has never seen is not an identifier, it is an input** — the same rule this project
already keeps in another form when it reads a method's type encoding from the runtime instead of
assuming one.

## v0.8.4

**The download interception is stood down until a crash log names its cause.**

Three releases in a row crashed, and **two of my diagnoses were wrong**: the icon hook fixed in
0.8.2 and the private ancestor call fixed in 0.8.3 were both real faults, and neither was *the*
fault. Guessing a third time would cost another install of an app that does not open.

The only behaviour separating 0.8.0 — which showed the page and did not crash — from every version
since is this hook running on taps it previously skipped. So that is the one thing removed. **The
tab, the downloads screen, the player and the upsell hiding all stay**; this release is 0.8.0's
behaviour with 0.8.2's and 0.8.3's guards kept, since both fixed genuine faults on the way past.

**A crash is worse than the thing it prevents**, and three installs of a crashing app is already
more than that rule allows.

What settles it is one file: **Settings → Privacy & Security → Analytics & Improvements → Analytics
Data**, the newest entry beginning `YouTubeMusic`. Its first two lines name the thread and the
selector, which ends this in one reading rather than a fourth guess.

## v0.8.3

**The crash, actually found — and 0.8.2 had fixed the wrong thing.**

The evidence was in the order of two reports. 0.8.0 did not crash and its download button showed the
Premium prompt; 0.8.1 crashed. What 0.8.1 changed was the key match — and the old condition read
`key is "music_download_badge_1" || view._viewControllerForAncestor is not now-playing`. **The first
half never matched, so short-circuit evaluation meant the second half was never reached.** The
moment the match widened, a tap arrived at `-_viewControllerForAncestor` for the first time, and
that private `UIView` method is not on this build: an unrecognised selector, which is a crash.

**A crash that appears when a feature starts working was not introduced by the change that exposed
it.** 0.8.2 guarded the icon hook — a real fault, and not this one.

The controller behind a view is found with `-respondsToSelector:` first and the **responder chain**
otherwise, which is public API and always answers. And the same private call in the account-menu
settings button — carried over later and never guarded — is fixed in the same pass, before it fails
the first time somebody opens that menu.

## v0.8.2

**0.8.1 crashed, and it crashed on a rule this project had already written down.**

The glyph came from a `%hook` on `YTMPivotBarItemStyle`'s drawing method — **and a `%hook` on a
method a class does not declare does not politely do nothing: Logos adds it.** The `%orig` inside
then jumps to an implementation that was never there. The rule is in CLAUDE.md in the Watch tweak's
own words — *a hook on a method a class does not declare is inventing an API Apple never calls* —
and it was written for exactly this shape.

The icon now lives in a group of its own, installed only when the runtime confirms the class really
declares that selector. **Without the glyph the tab still works**, which is why this is a check
rather than a fallback.

Two more of the same family, hardened in the same pass: a class method is asked for with
`+respondsToSelector:` before being sent, because an unrecognised class method is a crash and not a
nil; and the node behind a tap is asked whether it answers `-key` at all — that hook runs on **every
tap in the app**, so an object of an unexpected type reaching it is not a rare case.

## v0.8.1

Two reports from a device, and the second is this project's oldest mistake arriving again.

**The tab had no glyph.** 0.8.0 asked for icon type 1 and got whatever the app draws for 1, which on
this build is nothing. The type is only a number handed to the style object; the picture comes from
a hook, and it needs a number the app has no meaning for. The tab now asks for a type of its own and
draws `icons/downloads` from the bundle this package already ships — the same artwork the app's four
other tabs are drawn in, rather than an SF Symbol sitting differently beside them. A missing image
falls through to whatever the app would have drawn, so the tab works either way.

**The download button showed the Premium prompt**, which means the interception never fired. It
demanded the node key `music_download_badge_1` — **a constant copied from a reference tweak**, and
this repository's oldest and most expensive lesson is that a reference's constant is its build and
not yours: `bestURLtoDownload`, `downloadAddr` and `bitRate` each cost releases for the same reason.

Any node whose key names a download is taken now, and **every key seen is remembered and shown on
the Downloads screen while nothing has been saved** — which is exactly when somebody is asking what
their build calls that button. The ancestor-class check went with it: it was a second way to miss
for no second reason.

And a badge that is ours with no stream behind it now says so instead of falling through to the
Premium prompt. **Those are two different failures** — the hook never ran, or it ran and found
nothing — and this project has spent releases on reports that could not tell them apart.

## v0.8.0

**A Downloads tab where the Upgrade tab used to be, and a player that behaves like the app's.**

The Upgrade item is **replaced in place** rather than removed: taking it out left four tabs and a
gap where a fifth had been laid out for. The slot now carries the app's own download glyph, the
word Downloads in your language, and a browse id of ours — and if any of the renderer classes it is
built from is missing on a build, the item is removed exactly as 0.6.1 did. **Either way the bar
works**, which is the only acceptable shape for a change to somebody's tab bar.

**The screen is files, not a database.** A track is an `.m4a` in `Documents/Albrhi` and its name is
its metadata — delete one in the Files app and it is gone from here, with no code involved. Tap to
play, swipe to share or delete, and deleting asks first because it is the one thing on the screen
that cannot be taken back.

**Playing uses `AVPlayer`, and the Lock Screen does not care.** What makes a track behave like the
app's own is `MPNowPlayingInfoCenter` and the remote command centre: title, artist and duration on
the Lock Screen, headphone buttons, Control Centre, and next/previous walking the list you started
from. The audio session is deliberately left as YouTube Music configured it — a second opinion about
the session is how two players end up fighting over the route.

**One limit, stated rather than discovered:** whoever registers the remote commands last owns them,
so when this stops playing the app takes them back the next time it starts something. Handing them
over by hand is a race over state neither side owns, and losing it quietly would be worse.

## v0.7.0

**Saving a track — through the download button YouTube Music already draws, and without FFmpeg.**

Measured before it was built, and the measurement settled two questions that had been argued about
for days:

- **The stream is `streamingData.hlsManifestURL`** — the same source the YouTube tweak here already
  reads. There is no SABR wall in this app and no client to impersonate.
- **The upstream port's entire use of FFmpeg is `-i <hls> -c copy out.m4a`** — a stream copy, not a
  re-encode. That is `AVAssetExportPresetPassthrough`, which is how every download in this
  repository is already joined. **Sixteen megabytes of dependency for one remux** was the thing
  worth measuring, and it buys nothing here.

The button is the app's own download badge. YouTube Music draws it and gates it behind Premium; the
tap is intercepted before that gate rather than a second button being placed beside it — so it is
where somebody already looks for it, and the app's Premium page is never involved.

Three things carried over from what the YouTube tweak learned the hard way, rather than rediscovered:
**segments are packed ADTS behind one ID3 tag each** (join them naively and the file has twenty-odd
tags buried in it, which is what "the download had no audio" was); a raw AAC file has no index, so
its duration is waited for before an export range is built from it; and the audio group id is a
name, so `234` and `233` are tried and then **any** `TYPE=AUDIO` line is accepted.

The file lands in Files, under Albrhi, as `Artist - Title.m4a`.

**What this is not: it does not appear in YouTube Music's own Downloads page.** That page is the
Premium-gated offline library, and putting files into its store would be claiming an entitlement —
the same line refused in 0.6.0 by name. A page of our own with the app's playback behaviour is the
next release, not this one.

## v0.6.1

**The Upgrade tab is gone too** — it was still there in 0.6.0, and the reason is a rule this project
keeps and I broke while extracting.

The hook that removes it lives on `YTPivotBarView`, and I excluded that class from the extraction on
the strength of its **name**: the downloads feature hooks the same class, in a different file, for a
different purpose, and that file was not carried over. **The same class serving two features is not
two copies of one feature.** Judging by the class name instead of by what the method does is exactly
the mistake the rule is about, and it cost a release.

It removes one entry from the tab bar's own renderer list — the one whose pivot identifier is
`SPunlimited` — and leaves everything else in the list untouched.

## v0.6.0

**The advertisement for Premium is hidden. The subscription is still not claimed.**

The upgrade page, the periodic *subscribe* prompt, the upsell dialogs, the promo sheets and
interstitials, the memento promotions, the side-panel upgrade entry, the offline and background
upsell renderers, and the throttle that decides when to show the next one — all refused.

**This required reading upstream's file method by method rather than judging it whole.** 0.2.0
refused `PremiumStatus.x` entirely, which was right at the time and too blunt: it is two different
things in one file. Hooks that answer *is this account paying* with YES are taking money from the
app's developers. Hooks that stop the app **asking you to pay** are closing an advertisement, and
the app behaves for a free account exactly as it did before.

**What did not come, named rather than implied:** `-isPremiumSubscriber` and its setter on five
classes; `isCurrentUserPremium`, `isMobileAudioTier` and the queue's version of it; the flags that
pretend the build is internal or under test; and a `-init` that wrote `_isMobileAudioTierMode` into
a private ivar by KVC — the same claim, written by hand.

Forty-six one-line `if (…) %orig;` bodies were opened out for the Logos this repository pins, which
check.py caught before the compiler did.

## v0.5.0

**Audio or video, and a default between them** — the one feature of the upstream port whose
neighbours were carried over and which was left behind.

YouTube Music decides for itself whether a track plays as audio or as its video, and hides the
switch on most of them. These hooks open it everywhere — the mode controller, the queue config, the
quality pickers, the playability renderer — and honour a stored default.

**And the settings row for it was already here, writing a key nobody read.** `Player settings`
carried the audio/video segmented control from the moment the settings screen was ported in 0.4.0:
it stored `audioVideoMode` faithfully, and nothing in the tweak ever looked at it. A control that
saves a value no code consults is the same lie as a switch that changes nothing, and it shipped for
two releases.

Audio is the default, which is what a music app is for and what upstream chose too. It is written
only when unset, so a choice made on that screen survives an update.

## v0.4.1

**The settings screen crashed the moment it opened, and the cause is one this project had already
written down — twice, in this very file.**

The pages it offers were three parallel things: a title array, a destination array, and a row
*count*. Removing the Premium and scrobbling rows meant editing all three. Two were edited. The
count still said seven for five entries, so the table asked for row 5 of a five-item array and threw
before anything was drawn.

**A rule written beside two of three copies is not a check.** The comment restating "a parallel
array must be walked in lockstep" was added to this file in the same commit, ten lines above the
number that was wrong. There is one array now — `+settingsPages` — and the count, the cell and the
destination all read it, so a row cannot exist without somewhere to go.

**Two links repointed while fixing it, and the first is close to a licence matter.** *Source code*
pointed at upstream's repository; this binary is a modified GPLv3 work, so that has to mean *this*
source — sending someone to upstream hands them code that is not what they are running. The Telegram
row was upstream's support channel, where a person with a problem in Albrhi's build would have been
sent to a project that never shipped it; it is now a credit row naming YTMEnhanced and its licence.

## v0.4.0

**The settings screen, which ten features were shipped without.**

0.2.0 and 0.3.0 carried the hooks and not the page that controls them. The report was exactly that
— *no settings, no options, nothing, and I never saw the lyrics* — and it was right: there was no
way to reach a single switch, no source picker, no romanisation toggle, and nothing to confirm that
lyrics were even turned on. A tweak whose options cannot be reached is a tweak with no options.

It is carried over from YTMEnhanced under GPLv3 like the rest: a row in YouTube Music's own account
menu that opens the page, with Player, Theme, Navigation bar, Tab bar and Translation inside it.

**Two rows deliberately did not come.** *Premium* drives `-isPremiumSubscriber`, which this project
refused by name for Locket and again for Spotify — and keeping a switch for hooks that were refused
would be a screen that lies. *Scrobbling* configures code that is not here at all, which is the same
lie pointing the other way. The destination list was edited in lockstep with the row list, because
two parallel arrays edited apart is a fault this project has already paid for once, and it stays
plausible while being wrong throughout.

## v0.3.0

**Synced lyrics**, carried over from YTMEnhanced under GPLv3: a panel on the now-playing screen fed
by six providers -- LRCLib, Genius, MusixMatch, NetEase, the video description, and YouTube Music's
own lyrics where it has them -- with romanisation, a source picker, a timing offset, and selectable
text. It ships **on**, because that is what was asked for; upstream leaves it off.

**What that costs is in the package description rather than left to be found.** A lyrics feature
asks outside services what is playing. There is no version of it that does not. Translating those
lyrics is a separate switch, off, and inert without a key the user supplies.

**And this release is the first here that was verified rather than only compiled.**

`tests/host/run.sh` builds the pure modules -- the LRC parser, the matching pipeline, the caches,
the romaniser, the description extractor -- against the macOS SDK's iOSSupport frameworks and runs
them on the Mac. **29 tests, 0 failures**, in about a second. The arrangement is upstream's; what is
ours is the source list and the resource bundle.

This matters beyond one feature. CLAUDE.md has always said compilation is the second of three gates
and the third is a device -- **true of every hook, and never true of everything**. Three of this
project's most expensive bugs lived in exactly this layer: a quality ladder that needed
`raw → parsed → deduped` counted separately, a parallel array walked by value instead of in
lockstep, and a date label measured in one coordinate space and drawn in another. All three are pure
functions of their input. All three could have failed on this Mac in a second.

Two of the three findings came from the tests themselves rather than from the compiler: a paths test
that fails unless the run script sets `YTMU_CACHES_ROOT` (trimmed out of the first draft), and a
localization test asserting a resource bundle this package did not ship. The second one was fixed by
**shipping the bundle** -- 27 languages including Arabic -- rather than by deleting the test, which
is the difference between a suite that proves something and one that agrees with you.

check.py also gained a fix rather than a rule: `'"'` is a character literal, not the start of a
string, and three lines of a hand-written parser in the carried-over module were being reported as
unterminated. The oracle settled it in one command, as it has every time.

## v0.2.0

Seven more features, carried over from **YTMEnhanced** by py233 (github.com/py233/YTMEnhanced) under
GPLv3 -- itself derived from YTMusicUltimate, which this tweak was already built from. The
attribution ships in `control`, here, and in the package notice.

- **The speed control YouTube Music already has and hides**, on the player.
- **Seek buttons**: previous and next become back and forward, with the original behaviour still
  there on a long press.
- **No autoplay radio** after the queue ends, refused on every class that decides it.
- **Casting**, enabled where the app gates it.
- **The history, cast and filter buttons** in the navigation bar, hidden on request.
- **A true-black theme**, keyboard included.
- **SponsorBlock**, for the one category a music app has: `music_offtopic`.

**Three of them are off until switched on, each for its own reason.** SponsorBlock sends the track's
id to sponsor.ajay.app, which is a third party learning what is being played -- the same cost
tikwm.com carries in the TikTok tweak, and the same answer: a switch that starts off and a row that
says what turning it on does. The theme and the hidden buttons are appearance, and changing how
somebody's app looks on the day they update is not a default anyone asked for.

**`PremiumStatus.x` is not here, and that is the fourth time this project has said so.** It answers
`-isPremiumSubscriber` with YES on six classes. The same shape was refused by name for Locket's
`Check0verPlus` and again for Spotify. Nothing carried over here ever asks what the account is.

Four edits were needed to make the carried-over files build, and each is a rule this repository
already had:

- One-line `%orig` bodies opened out, and `cond ? %orig(NO) : %orig;` split -- the Logos pinned here
  needs `%orig` alone in a full block and refuses two of them in one expression.
- **`%orig` as the middle operand of a ternary** does not compile, while `? nil : %orig` and
  `%orig ?: fallback()` do. check.py grew a rule for it, narrowed twice against the other tweaks
  before it landed.
- `NavBar` renamed from `.xm` to `.x`: nothing in it is C++, and in a `.xm` its installer is emitted
  with C++ mangling while the header declares it plainly, so the link fails on a symbol that is
  there under another name.
- The seek buttons' `-valueForKey:` on `_nowPlayingView` is now guarded by a real runtime question.
  `-valueForKey:` runs the app's own code; this project crashed Instagram once by trusting it.

## v0.1.1

**The rootless build failed and every local build had passed, because every local build was
roothide.** Upstream writes one method body as a ternary whose branches are `%orig(YES)` and
`%orig` — two different argument structures in one expression. The Logos in the roothide Theos
accepts it; the Logos in stock Theos answers `Invalid argument structure in %orig` and stops.

`%orig` must sit alone on its own line inside a full block, which this repository already knew and
had written down. What it did not have written down is the reason it went unnoticed: **the two
Theos installs here carry different versions of Logos, so a local build proves one flavour and
guesses at the other.** CI builds rootless first, which is why it was the one to say so.

Fixed as a plain `if`/`return`, and both flavours now build locally before anything is pushed.

## v0.1.0

**No ads, and background playback left alone — and no Premium.** Two files carried over from
YTMusicUltimate under GPLv3: the advertising hooks (`YTAdsInnerTubeContextDecorator`, `YTDataUtils`,
`YTAdShieldUtils`, and the monetisation flags on `YTIPlayerResponse`) and the background-playback
ones, including the upsell notification that interrupts it.

**This tweak does not unlock a paid subscription.** The tweak these files come from answers
`-isPremiumSubscriber` with YES on six classes, which tells YouTube Music the account is a paying
one. That is the same line this project drew for Locket's `Check0verPlus` and again for Spotify, and
it is the one thing not carried over.

**Why these two files could be taken and that one could not is a fact, not a judgement:** neither of
them ever asks what the account is. `RemoveAds.x` does not contain the word. That was measured in
the upstream sources before a line was copied.

**Three edits, all about who decides**, and each written where it is rather than left to a diff:

- Each file's hooks are wrapped in a `%group`. Logos installs an ungrouped `%hook` from its own
  constructor, **before Albrhi's gate is consulted** — so "off" would still mean hooks in the
  process. The Spotify port learned this the expensive way, where three ungrouped hooks crashed the
  app whatever the switch said.
- Each file gains a one-line installer, because a Logos group's `%init` is file-scoped and cannot be
  reached from another file. Albrhi Watch does the same.
- Upstream's own `%ctor` is removed. It seeded five keys to 1 whenever they were missing, turning
  every feature on at load no matter what anyone had decided. Albrhi's switch composes that
  dictionary now — **two switches for one feature is one switch too many.**

It patches one app, so it takes an ordinary row on Albrhi's app list rather than a page of its own.

> **The hooks are not this project's work.** They are
> [YTMusicUltimate](https://github.com/dayanch96/YTMusicUltimate) by **dayanch96**, under GPLv3 —
> the same licence Albrhi ships under, which is what makes carrying them over lawful. Albrhi adds
> the gate and the packaging.
