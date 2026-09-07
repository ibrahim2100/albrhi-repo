# Albrhi Changelog

## v1.77.0

**صفحة الترخيص في كل أداة صارت واحدة، بهوية البرهي — وسؤال الخادم صار مرّة في اليوم.**

علامة خضراء أو حمراء أعلى الصفحة تجيب «هل هي مفعّلة؟» قبل أي قراءة، وتاريخ الانتهاء ظاهر ومعه
عدد الأيام الباقية، والتفعيل فوري: المفتاح يُتحقّق منه على الجهاز بلا شبكة، والكود يُسأل عنه
الخادم والزرّ يدور أثناء ذلك. وجملة «أغلق التطبيق وافتحه» لم تعد تُقال للجميع — تُقال لمن يحتاجها
فعلاً وحده.

وسؤال الخادم انتقل من كل ٦ ساعات إلى مرّة في اليوم، لأن وقت آخر فحص كان محفوظاً في نطاق كل تطبيق
على حدة بينما التوكن مشترك: هاتف بأربع أدوات كان يسأل ١٦ مرّة يومياً ويجدّد التوكن نفسه ١٦ مرّة.
الفاصل الآن مبنيّ على مدّة الترخيص — ثماني ساعات في الأيام الأخيرة وبعد الانتهاء حيث يكون التجديد
في الطريق، ونصف ساعة إن قارب التوكن على الموت.

## v1.76.5

**X 0.18.4 — «إخفاء المساحات» يخفي فقط.** كان يضبط `voice_rooms_consumption_enabled` إلى NO،
وهو أن يُقال لتويتر إن هذا الحساب لا يجوز له سماع أي مساحة — ففتح مساحة يرسلها أحدهم يردّ «غير
متوفرة». الإخفاء نفسه لم يكن من هذا المفتاح أصلاً: الشريط يُخفى بحجب `-_t1_initializeFleets`
والتبويب بمدخله `audiospace`. مقيس على BHTwitter 4.5، الذي يخفي بنفس المُحدِّد ولا يحمل أياً من
تلك المفاتيح في ثنائيّه.

## v1.76.4

**The licence check-in no longer starts during a launch.** It waits a minute after the app is
active. Nothing proves it was behind the YouTube launches that hung — the build that launched
cleanly differs from the one that hung by diagnostic marks alone, so what is known is that the
fault is intermittent — but a licence good for seven days has no business being asked about while
an app is still starting.

## v1.76.3

**YouTube launches again.** The hook responsible ran for every view in the app: `_ASDisplayView` is
AsyncDisplayKit's own view class and YouTube's interface is built out of it, so a hook written to
catch one ad card fired thousands of times before the first frame. It waits for the app to be
active now, and so do the two ad-request hooks.

It was found rather than guessed: the launch leaves a trail of milestones in the report, so a
launch that dies says where it stopped.

**And the save button in the player is placed correctly in Arabic** — by leading and trailing
rather than by left and right, which is the same thing only in English.

## v1.76.2

**A licence entered inside an app changed nothing until the app was killed.** The gate that decides
whether a tweak may install anything cached its answer for the life of the process — correct on a
jailbreak, where the panel is set before the app opens, and exactly wrong in a tweak installed on
its own: the app is opened first, unlicensed, and that "no" was frozen. Reported as "I activate it
and then no setting applies", which is precisely what it was.

It is dropped now whenever a licence is entered or removed, and the licence screen says to reopen
the app — the hooks a launch did not install cannot appear retroactively, and a screen claiming
otherwise would be lying.

**And two guards on YouTube's tab bar**, after it stopped launching again on a device where
clearing the app's data cured it.

## v1.76.1

**Each social tweak is now available on its own, licensed on its own.**

Somebody who wants one tweak and not the whole of Albrhi installs the individual package instead
of `com.albrhi` — the suite declares `Conflicts` and `Replaces` on all of them, so the same dylib
can never be injected twice. Instagram, YouTube, X and TikTok; Spotify and YouTube Music stay
inside Albrhi, because neither has a settings screen to enter a key in.

**Each also ships as a standalone dylib**, for injecting into an IPA on a phone with no jailbreak
at all — no CydiaSubstrate, no PreferenceLoader, no panel. Proved rather than claimed: the build
refuses a dylib that still links Substrate, one that still expects an `MS` symbol at load time,
or one without the licence check compiled in.

**And the licence moved into the apps.** Albrhi Panel's licence page exists only where
PreferenceLoader does, so a tweak on its own had nowhere to enter a key — which is why a
self-contained build used to run ungated. Every tweak now carries the same screen in its own
settings: status, device code, key or code entry, and removal.

Licences come in three kinds now, in a field that already existed, so nothing already issued
changes: the jailbreak licence covers everything, a shared code covers the separate tweaks, and an
app licence covers one. **On a jailbreak nothing about activation changes** — one activation in
Settings › Albrhi still licenses every tweak on the phone.

The panel gained a page per licence: what it covers, the code as it was typed, and every app the
key is running in with its version and when it was last seen.

## v1.76.0

**YouTube's save button now sits in the player's own top row, beside the subtitles and settings
buttons** — white, built with YouTube's own button factory, sized and lined up from the controls
next to it, and anchored to the autoplay switch so it stays put when playback starts.

Eleven local builds and no releases went into it, which is the point: every one of them was a
measurement, and the three faults between them were a frame applied at the wrong moment, an anchor
that appears only during playback, and a size read from a container instead of a button.

## v1.75.4

**The YouTube screen scan now starts from the player's own view rather than from the key window**,
so it describes the watch page even while a settings screen is presented over it — which is what
made the last two scans describe a settings table, accurately.

## v1.75.3

**The YouTube screen scanner now runs from the player instead of from the settings screen** — a
full-screen presentation removes the page behind it, so the first scan described a navigation bar,
accurately. It also prints every YT… and ELM… class it finds rather than five hand-picked words.

## v1.75.2

**The YouTube report now prints the actions row's real method list, read from the runtime on the
device**, and counts the rows the app builds separately from the ones it hands us to fill. Those
two numbers separate "this build draws that row some other way" from "it uses a different
selector" — which one number could not.

## v1.75.1

**The Save button in YouTube's actions row did not appear, and the report could not say why.** It
can now — the row's own classes are audited, its state reaches the page, and a new scanner
(Settings › General, with a video open) writes down what YouTube actually built under the player.

## v1.75.0

**A Save button beside Like and Share in YouTube.** Added as one more renderer in YouTube's own
action row, so the app builds the button itself and it behaves like the ones next to it — the same
technique as the Download Centre tab, and every hop of the chain read from the app's own class
metadata.

## v1.74.5

**The YouTube Download Centre and History tabs are back**, applied a moment after the app opens
rather than while it is starting. That timing was the whole fault: the same change, made during
the bar's construction, is what kept the app from launching.

## v1.74.4

**YouTube's tab-bar changes are switched off until a device says otherwise.** They rewrite one of
YouTube's own model objects while it builds the tab bar during launch — and they had never once
run before: the helper they read that object through answered nil for every protobuf class until
the day before the app stopped launching. Everything else in the YouTube tweak is unchanged; the
Download Centre is still in its settings screen, and a switch there puts the tab back.

## v1.74.3

**YouTube still would not launch after 1.74.2.** The ad filter describes every feed section to
test it, and the diagnostics described them all again — tens of megabytes of string building on
the main thread while the app was still showing its logo. Described once now, with a time budget
past which the rest of the batch goes through unexamined.

**And a launch guard, so this cannot ship again**: if the app has not become active eight seconds
after the tweak loads, every expensive hook stands down for that session and the diagnostics page
says so. The app opens; the features are what is lost.

## v1.74.2

**YouTube would not start — it sat on its own logo — and three Albrhi hooks were asking for a
layout pass from inside one.** A view that reorders, repaints or re-measures itself during layout
asks for another layout, which does it again: the main thread never went idle and the app never
finished launching. Fixed in YouTube 1.29.0; nothing else was affected.

## v1.74.1

*Released on its own push again — the two standalone tweaks went out from the same commit and
the shared concurrency group drops whichever run is still queued.*

**"Free" is out of every description.** The tweak needs a licence; a package page saying it is
free was the first thing anybody read. The licence itself is unchanged and still named in full —
GPLv3 where it applies, MIT for the Watch pairing core — because dropping a word is not the same
as dropping an obligation, and the attribution those licences require is not negotiable.

## v1.74.0

*Released on its own push, after Albrhi NextUp 0.2.0 and Albrhi Watch 0.6.0 went out from the
same commit: three publishers share one concurrency group, and the queued one is dropped.*

**Albrhi is a tweak for social apps, and only that now.**

Albrhi NextUp and Albrhi Watch were always separate packages, but their settings pages shipped
inside Albrhi Panel — so each appeared as a row in Settings › Albrhi, and installing either one
without Albrhi installed a tweak with no way to configure it. Each carries its own preference
bundle and its own Settings row now: **Settings › Albrhi NextUp** and **Settings › Albrhi
Watch**, beside Albrhi rather than inside it.

Nothing moved on disk that a device will notice: both tweaks already kept their switches in
their own preference domains, so every setting is exactly where it was.

Also in this release: the panel says البرهي in Arabic, everywhere. It said البرهان in eighteen
places — a different word.

## v1.73.4

*Released on its own push: the fix lives in `tools/` and `server/`, which every publisher watches,
so the suite's run was dropped by the shared concurrency group.*

**Editing a licence's name in the panel looked like it never saved.** The table draws the licence's
`name`; the editor read and wrote `note`. So an edit to a licence that came from a request — which
carries a real name — was written into a field nothing displays, and the row came back saying
exactly what it said before. It had saved every time. One field on both sides now, and the phone
number is editable beside it.

## v1.73.3

*Released on its own push — the commit carrying the fix touched `tools/`, which all three
publishing workflows watch, so the suite's run was dropped by the concurrency group.*

**The panel counted lifetime licences as expired** — it said "0 valid of 3" while two of the three
never expire. Counted correctly now, and they sort to the top rather than the bottom.

## v1.73.2

**The licence panel shows the phone number and can be searched** — by device, name or number, and
a number matches however it was written. Nothing in the tweaks changed.

## v1.73.1

**The licence panel edits properly now** — name and duration together, with lifetime in the menu,
in a dialog of the page's own rather than a browser prompt. Nothing in the tweaks changed.

## v1.73.0

**Buying is one screen now.** Pick a plan, put in your name and number, and the request reaches
Albrhi before WhatsApp even opens — so it is not lost if you close the message.

And there is one **Enter a licence** row instead of two: paste whatever you were sent, short code
or long key, and Albrhi works out which it is.

## v1.72.3

**The plans screen was appearing as a small empty box.** It draws properly now — free week, month,
six months, year, lifetime.

## v1.72.2

**The "Request a licence" button opens the plans screen now.** It was doing nothing at all on some
devices — silently, which is why it read as broken rather than as missing.

The free week is also shown, greyed, when you already have a licence, instead of vanishing.

## v1.72.1

**Withdrawing a licence now stops the device at its next check instead of a week later**, and the
panel gained a proper delete — separate from revoke, because "taken away" and "never should have
existed" are different things to be able to tell apart later. The free weeks are listed too, and
one can be reset for a device that needs another.

## v1.72.0

**Try Albrhi free for a week, and buy from inside it.**

Settings › Albrhi › Licence now opens a proper screen: **a free week**, taken on the spot and good
once per device, then a month, six months, a year, or **lifetime**. Choosing a paid plan opens a
message to Albrhi with your device code already written in — nothing to copy by hand.

## v1.71.2

*Released on its own push: the commit that carried this fix also touched `tools/`, which all
three publishing workflows watch, so the suite's run was dropped by the concurrency group before
it could release.*

**Settings › Albrhi › Licence showed no state and no expiry date.** The rows were there and empty —
the one screen whose job is telling you whether Albrhi is licensed was answering with a blank.
Fixed, and the tooling now refuses the shape that caused it.

## v1.71.1

**Albrhi requires a licence, and nothing on the phone turns that off any more.**

Two controls that shipped in 1.70.0 reached every device: one that disabled licensing, and one that
pointed the tweak at a different server. Both are removed, and a device that already used them is
not exempt.

Settings › Albrhi › Licence now simply says whether Albrhi is running or stopped. Entering a
licence is always possible from that screen — it is never behind the gate.

## v1.71.0

**Ask for a licence from the phone and it reaches Albrhi directly.**

Settings › Albrhi › Licence › **Request a licence** — pick a duration, add your name, and that is
the whole of it. Nothing to copy, nothing to send, no address to type. The answer arrives on its
own the next time the tweak checks in.

Licences renew themselves in the background, so nothing breaks on a flight or behind a hotel's
wifi, and the screen shows the date your licence actually runs to rather than the date it next
renews.

Codes are redeemed the same way, and a code now belongs to the first device that uses it.

## v1.70.0

**Albrhi now requires a licence.**

Without a valid one the tweaks stand down — no hook is installed and every app behaves exactly as
if Albrhi were not there. Nothing crashes and nothing is half-patched.

If that happens to you, Settings › Albrhi says so at the top of the screen and taps straight
through to **Licence**, where you can **request a licence** — it makes a short text to send — or
**enter a code** you were given, which binds itself to your device on the spot.

The layer shipped switched off in 1.68.0 and 1.69.0 on purpose: it was introduced, then proved on
a real device, and only then turned on.

## v1.69.0

**Ask for a licence from the phone, and redeem a short code without asking anyone.**

Settings › Albrhi › Licence gains two things. **Request a licence** builds a short string with your
device, the duration you want and your name, and offers to share it — nothing is sent by the tweak,
you send it. **Enter a code** takes something like `ALB-4K7M-9QX2-P3RT` and binds it to the device
on the spot; it needs internet that once and never again.

Enforcement is still off. None of this withholds anything from anybody yet.

## v1.68.1

**A licence panel, served beside the source.** Issue keys, keep a ledger of what has been issued
and to whom, and build the revocation list — from a browser, on a phone as readily as on a Mac.

It is public and it does nothing until a signing key is pasted into it. Signing happens in the
browser; the file contains exactly one network call and it is a read of the published revocation
list. Nothing in the tweaks changed — this is a tool for the person issuing keys, not for the
person using them.

## v1.68.0

**A licence layer — and it is switched off.**

Settings › Albrhi › Licence now shows a device code, accepts a key, and carries the switch that
turns the gate on. **That switch ships off and nothing changes for anyone until it is turned on.**
The source has been free for as long as it has existed, and a release that both introduced this
and enforced it would stop every install already out there on the next update, before a single key
had been issued to fix them with.

A key is checked entirely on the device — ECDSA P-256 against a public key compiled into the
binary — so it works with no internet. The device is named by a one-way fingerprint of the serial
and model rather than by a UDID: it cannot be turned back into a serial number by whoever receives
it. A periodic call, at most once every six hours and never waited on, is what allows a key to be
withdrawn later; only a real answer counts, so a timeout or a captive portal never costs anybody
their features.

What this is not: unbreakable. No check running on the user's own device can be. It is said that
way in the code, in the docs and on the page itself.

## v1.67.2

**YouTube 1.28.2.** The save button inside the player overlapped the video's title in fullscreen.
It now sits below the app's own top control row, measured from that row rather than placed at a
fixed distance — so it is clear of whatever YouTube puts there in either layout.

## v1.67.1

**Fixes a regression 1.66.0 introduced: app versions were missing from the panel, and some of
YouTube's own renderer fields read as empty.**

The guarded accessor that replaced `-valueForKey:` decided whether a getter returns an object by
reading its method's type encoding — and a class that resolves a selector dynamically has no
method to read, while still answering `-respondsToSelector:` with YES. `LSApplicationProxy` (every
installed app's version) and every protobuf class (YouTube's renderers) are both exactly that
shape. It asks `-methodSignatureForSelector:` now, which is what the runtime's own forwarding
consults.

## v1.67.0

**YouTube 1.28.0.** The save button inside the player fades in and out with YouTube's own
controls now instead of sitting over the video permanently — driven by the two setters the app
already calls when the controls appear, rather than by watching a neighbour's alpha.

## v1.66.1

**1.66.0's packages were correct and the source stopped listing the rootless one.** A note
explaining the withheld-package list was written *between the quotes* of the shell assignment it
described, where `#` is not a comment but a word — so every word of that sentence became a
withheld package name, and one of them was the suite's own identity. The roothide flavour and
every other package stayed exactly where they were; `com.albrhi` vanished. Green build,
published release, a perfectly well-formed index of the wrong set of packages.

Caught by the workflow's own "does the source actually serve this version" step, which asks the
live URL rather than the build's output — the one check in the pipeline that could have seen it.

Nothing in the tweaks changed from 1.66.0. If Sileo already offered you 1.66.0, you have
everything this carries.

## v1.66.0

**An audit pass over the whole repository. Nothing a user can see changed; a great deal that
would eventually have been seen did.**

`-valueForKey:` — this project's most expensive habit, documented for a year and used 108 times
regardless — is gone from every tweak, replaced by a guarded accessor that checks each getter
before sending it and reads an ivar only when the runtime says it holds an object. It cannot
come back: `tools/check.py` refuses it now, which is the actual change. A rule that lives only
in a design document is a rule nobody greps before writing a hook.

Instagram's thirteen features that recognise a row by its English text now say so in Diagnostics
instead of looking broken on a phone that is not in English. The panel stopped linking two
frameworks for a picker that left with CarPlay. Twenty dead strings, one dead preference and one
dead shared header removed. And the localization orphan count, which reported 54 in X where 5
were real, is trustworthy for the first time — a warning wrong five times in six is a warning
nobody reads.

## v1.65.1

**YouTube 1.27.1.** The save button in the player was built and never added to a view — appending
it to YouTube's array of controls placed nothing. It is a real subview now, top left of the
player, and the report carries its frame. The feed ad that came back was the same layout name with
one word removed, so the filter now matches the server's own ad-serving marker instead of another
layout name.

## v1.65.0

**YouTube 1.27.0.** The report answered plainly: the row of buttons under a video is not drawn from
the class 1.26.0 moved the download onto — YouTube builds it from elements now. The save button
moves into the player's own controls instead, built with YouTube's own button factory and handed
to YouTube's own layout, and it is on by default. It had existed, off and unconfirmed, since
1.18.0 — unconfirmed because its only diagnostic was being written into the SponsorBlock line.

## v1.64.1

**YouTube 1.26.1.** The new download button's own report could not say whether it had attached —
it counted taps and only wrote the count out when a download button was answered, so an ordinary
tap on Like looked identical to a hook that never fired. The buttons are counted as they are
built now, which answers "is this class even drawn in your build" without anybody tapping
anything.

## v1.64.0

**YouTube 1.26.0.** Downloading moved off the long press and onto YouTube's own download button —
holding the video to speed it up had started saving it instead, because both gestures were on the
same picture. Which button is the download button is read from the app's own flag rather than
measured or matched by title, and a build that does not carry that flag is left alone. The hold is
still there, off, and the switch it always needed: it had been armed from inside the SponsorBlock
hook, so it was silently dead for anyone who turned SponsorBlock off.

## v1.63.0

**Albrhi for YouTube Music 0.9.0: downloading works.**

It never had, and the reason is the release's real finding: the installer had been commented out
since 0.8.4, stood down as a crash suspect, cleared in 0.8.5 and never switched back on. Every round
of work after that was on code that could not run, and the diagnostics said only that no class had
been found — which was true, because nothing had ever asked.

What is there now: a confirmation card in Albrhi's own colours that asks for a name and a section,
sections that are folders on disk, a long press on the now-playing screen as a second way in that
depends on no server-generated name, a banner instead of a modal alert, a transport of our own with
play, pause, previous, next and a scrubber, the tab's artwork, and a Downloads page that finally
clears both the device's safe area and the app's own header and bars — all of them measured off the
views themselves rather than written down.


## v1.62.2

Albrhi for YouTube Music 0.8.7: the download diagnosis moves to the first settings screen, under the
master switch — the Downloads tab's empty state is not where somebody whose button asks them to
subscribe ever looks.

## v1.62.1

Albrhi for YouTube Music 0.8.6: **the Downloads screen now says why a download did not happen.**
The Premium prompt appearing has three separate causes — the interception not installing, its class
never being called for that tap, or the badge not being recognised — and they were indistinguishable
until now. Each is counted, and the empty screen names the one that occurred.

## v1.62.0

Albrhi for X 0.18.1: **two switches for one intention, removed.** Hiding suggested accounts had a
blunt switch that hid every instance of a class and a filter that recognises the suggestion itself;
the view count had a named feature and a button-hider on another page. The better half of each pair
stays, and the preferences go with the rows.

## v1.61.9

Albrhi for X 0.18.0: **opening links in Safari turned out to be a feature switch, not a browser
class.** Three releases hooked browser classes and the device report finally said `0 left to X` —
nothing was going through any of them. The same report showed
`ios_in_app_article_webview_enabled` asked 72 times and answered on, which is the decision X
actually makes. It is a named feature now, answered by the switch layer.

## v1.61.8

Albrhi for X 0.17.6: **the post-as-a-picture is confirmed fixed**, and open-in-Safari moves to
`T1BaseWebViewController` — what X presents for a tapped link is a preloaded controller, not the
class 0.17.5 compared against. Which controllers count as links is an allow list, because most of
the twenty-six descending from that base are sign-in, billing or ordinary app screens drawn with a
web view. Every class turned away is named in the diagnostics report.

## v1.61.7

Albrhi for X 0.17.5: **links now really do open in Safari.** The hook was on
`SFSafariViewController`, a class X names once across all its binaries — X's own browser is
`T1WebViewController`, and that is what is hooked now, at the moment before the page is fetched.
Sign-in, verification and billing browsers descend from the same base and are deliberately left
alone: sending those to Safari would break logging in.

## v1.61.6

Albrhi for X 0.17.4: **the post-as-a-picture was mirrored, and now is not.** UIKit mirrors
right-to-left content with a transform and `-renderInContext:` does not apply the receiver's own, so
the picture came out as the raw unflipped arrangement — bitmaps included. Whether a subtree is
mirrored is now measured by converting two of its own points into window coordinates, and the
context is flipped to match.

## v1.61.5

Albrhi for X 0.17.3: **the post-as-a-picture no longer comes out laid out left-to-right.** UIKit
implements right-to-left as mirrored layout decided from the view's traits, and an image context
has none — so drawing the hierarchy there rebuilt the whole cell the other way round, button and
all, and gave the text an LTR base direction. It renders the layer tree instead, which draws what
each layer already holds and never lays anything out again.

## v1.61.4

Albrhi for X 0.17.2: **opening links in Safari never worked** — the hook asked
`SFSafariViewController` for a property name it does not expose, got nil, and treated that as
"leave this link alone", which was every link. The URL comes from the initialiser now. The
post-as-a-picture renderer had the same shape of fault one level down and now forces a real render
pass and checks whether it succeeded.

## v1.61.3

Albrhi for X 0.17.1: **the settings are pages now**, the way the YouTube tweak's are — a first
screen listing eight categories, each opening its own screen built by its own file. One class draws
every row on both screens, and a page with nothing in it is not listed at all, which is how the
feature page disappears with the switch layer rather than offering switches that decide nothing.

## v1.61.2

Albrhi for X 0.17.0: **fifteen new features and a settings screen rebuilt around them.** Copied
links cleaned of the two parameters that name who shared them, `t.co` expanded, links opened in
Safari, search history withheld, the app behind Face ID, who-to-follow and topics and trend videos
refused at the one hook every list X draws goes through, the view count and bookmark button
hideable, a post rendered as an image, confirmations before a like and a follow, and five smaller
answers. Four of the reference tweak's switches are deliberately absent because their targets are
not in X 12.20 at all — a switch that decides nothing is worse than a missing one.

The settings screen is a registry of self-registering sections now, one file each, replacing five
section constants and seven row constants that had to be kept in step by hand. The switch layer
heads it rather than ending it, drawn as the heading it is: turning it off does not disable the
feature list, it removes it.

## v1.61.1

Albrhi for YouTube 1.25.1: **an ad showing at launch and gone after a refresh was a filter watching
one door out of three.** `YTInnerTubeCollectionViewController` fills its section list through
`-addSectionsFromArray:` and two `-insertSections:` methods; only the first was filtered, so a feed
built through an insert path went past untouched and the refresh afterwards looked like a fix. All
three are filtered now, and the diagnostics tally each door separately.

## v1.61.0

Albrhi for YouTube 1.25.0: **the floating download button is gone and the tab bar can never hold
more than six.** The floating button was a fallback that appeared whenever the real tab failed —
including when the failure was a bug of ours — so a fault arrived looking like a cosmetic
complaint. The Download Centre is a tab or it is nothing. Its own switch is gone as well: the
arranging screen already asks that question, so switching it off is dragging it to the inactive
list, like every other tab.

## v1.60.9

Albrhi for YouTube 1.24.1: **hiding the `+` now makes room.** With the create button off and History
on, the bar came back with five tabs and the Download Centre reverted to its floating button: the
six-tab limit was being applied by each append and again by the arranger, so History took the last
slot while the create button was still there and the Centre was refused as "full" — moments before
the create button was removed. The limit lives in the arranger alone now, which is the only code
that also removes anything.

## v1.60.8

Albrhi for YouTube 1.24.0: **the `+` create button can be switched off**, and the arranging screen
now draws the bar it is editing. The `+` had been invisible to that screen because
`YTIPivotBarSupportedRenderers` carries two kinds of item and this tweak read only one of them —
the create button is the other, so it came back with no identifier and could not be named, listed
or moved.

## v1.60.7

Albrhi for YouTube 1.23.2: **the History switch is gone and History is a row in the arranging
screen.** A switch that adds a tab and a screen that arranges tabs are two answers to one question,
and the bar holds six — so switching it on added a seventh rather than replacing anything. Drag it
up to switch it on, drag something else down to make room.

## v1.60.6

Albrhi for YouTube 1.23.1: **History can be one of the bottom bar's tabs**, off by default, beside
the arranging added in 1.60.5. `FEhistory` is a browse endpoint YouTube already resolves, so the tab
carries a real `navigationEndpoint` and the page, its loading and its back behaviour are YouTube's
own — nothing of it is handled here. The field chain was read hop by hop off the app's own class
metadata rather than guessed, and each step failing is reported by name.

## v1.60.5

Albrhi for X 0.16.2: **"Hide Spaces" now hides the Spaces bar above the Home timeline**, which is
the surface it was always about. Two releases moved tabs instead — correctly, and to no effect
here. The strip is set up by `-_t1_initializeFleets` on `THFHomeTimelineItemsViewController`, and
the call is withheld rather than the bar emptied.

Albrhi for YouTube 1.23.0: **the bottom tab bar can be arranged** — drag to reorder, drag across to
switch a tab off, in Settings › Interface › Tab bar. It rides the same path the Download Centre tab
already proved: YouTube hands its bar a protobuf and the array is rewritten on the way through, so
YouTube still draws every tab itself. Decisions are made on each tab's `pivotIdentifier` rather
than its position, and the list offered is what the device's own bar reported rather than a table
copied from elsewhere.


## v1.60.4

Albrhi for X 0.16.1: **Hide Spaces now filters the tab bar itself.** Excluding the tab entry was
enough to *add* Communities and Profile in 0.16.0 and not enough to *remove* Spaces, because an
account with a saved tab bar keeps it. The final `-setTabViews:` array is filtered instead, on the
tab's own `scribePage` name, and the report prints every name the bar carried.


## v1.60.3

Albrhi for X 0.16.0: **Hide Spaces and More tabs are enforced where X decides, not through a
feature switch it ignores.** The per-key report added in 0.15.0 showed
`voice_rooms_consumption_enabled` answered 784 times with the Spaces tab still in place, and
`ios_tab_bar_default_show_communities` asked twice — a key whose own name says it only seeds the
bar a new account starts with. Every tab in the bottom bar answers `-isExcludedFromTabBar`, so
that is what the two switches now move.


## v1.60.2

**The source address is lower case now, and the old one stops working.**

Sileo on the rootless device could not read the source at all — not "would not install", but never
found a `Release` file. The address was correct and GitHub Pages answered 404 anyway, because Pages
paths are case sensitive and the request arriving there was lower case while the repository was
named `Albrhi-Repo`. Re-adding it with the exact capitals changed nothing, and roothide reading the
very same address ruled out a fault in the index itself, which was measured end to end and is sound.

The repository is renamed to `albrhi-repo`, so **the source is now**:

`https://ibrahim2100.github.io/albrhi-repo/`

Anyone who added the old capitalised address must remove it and add this one; GitHub does not
redirect Pages paths after a rename. Every URL in this repository moved with it — the package
metadata, the update check in the panel, the about footers and the readme — and the workflow needed
no edit, because it builds the address from the repository's own name rather than writing it down.

Packages published *before* this release still carry the old address in their own `Icon` and
`Depiction` fields, so their pages will not draw in Sileo until each is published again. Installing
is unaffected: the index addresses its `.deb` files relatively.


## v1.60.1

Albrhi for X 0.15.0: the diagnostics report says, for every feature that is on, which of its keys X
actually asks for and what each was answered.

## v1.60.0

**The source would not install on a rootless Sileo, and the cause was one line.**

`com.albrhi` declared `Depends: … dev.theos.orion (>= 1.0.0)`. That is a real dependency — Albrhi
for Spotify is the only tweak here written in Swift with Orion, and its dylib genuinely links
`@rpath/Orion.framework/Orion`, confirmed by reading the published package rather than assumed. But
**`dev.theos.orion` is not in the default repositories of a rootless jailbreak**, so Sileo could not
resolve it and refused the whole package. Everything else in the suite was fine and none of it could
be installed.

**The front door has to open for everyone.** Spotify leaves the suite — it now carries a `.no-suite`
marker like NextUp and Watch, is excluded from this workflow's trigger, and its identities are out of
the suite's `Conflicts`/`Replaces` so the two can sit side by side. `com.albrhi` depends on
`mobilesubstrate` and `preferenceloader` and nothing else.

Verified on the built package rather than intended: the Depends line is two names, and no
`AlbrhiSpotify.dylib` is inside.

## v1.59.11

Albrhi for YouTube Music 0.8.5: the crash was an icon type the app has no case for, reached while
drawing the tab bar at launch. Back to the value 0.8.0 shipped.

## v1.59.10

Albrhi for YouTube Music 0.8.4: the download interception stands down until a crash log names the
cause. The tab, the downloads screen and the player are unchanged.

## v1.59.9

Albrhi for YouTube Music 0.8.3: the real cause of the crash — a private UIView method reached for
the first time when the download match widened, now guarded with a responder-chain fallback.

## v1.59.8

Albrhi for YouTube Music 0.8.2: fixes the crash 0.8.1 introduced — a hook on a method the class does
not declare, which Logos adds rather than skips.

## v1.59.7

Albrhi for YouTube Music 0.8.1: the Downloads tab gets its glyph, and the download button is matched
by what its key means rather than by a constant copied from another tweak.

## v1.59.6

Albrhi for YouTube Music 0.8.0: the Upgrade tab becomes a Downloads tab, with a player that puts
what you saved on the Lock Screen.

## v1.59.5

Albrhi for YouTube Music 0.7.0: save a track through the app's own download button — no FFmpeg, and
no Premium page involved.

## v1.59.4

Albrhi for YouTube Music 0.6.1: the Upgrade tab is removed from the tab bar, which 0.6.0 missed.

## v1.59.3

Albrhi for YouTube Music 0.6.0: the upgrade page and the recurring subscribe prompt are hidden —
the advertisement, not the subscription.

## v1.59.2

Albrhi for YouTube Music 0.5.0: choose whether a track plays as audio or as video, with the switch
opened on tracks that hide it — the setting existed since 0.4.0 and nothing read it until now.

## v1.59.1

Albrhi for YouTube 1.22.0: a SponsorBlock marker is tied to the bar it belongs to, so a second
progress bar no longer suppresses or fights the first.

## v1.59.0

Albrhi for TikTok 0.20.0: the settings screen rebuilt from nothing — an identity card, a grid of
categories, and option cards — and the two comment features removed on request.

## v1.58.23

Albrhi for TikTok 0.19.14: save a comment's picture from TikTok's own long-press menu, and copy a
comment without its author's name in front of the words.

## v1.58.22

Albrhi for TikTok 0.19.13: the settings screen is a list of sections you open, each on its own page.

## v1.58.21

Albrhi for TikTok 0.19.12: videos really do not repeat now — the first attempt hooked the
announcement instead of the decision — and the settings screen is seven self-registering files
rather than one long array.

## v1.58.20

Albrhi for TikTok 0.19.11: never appear online, and videos that do not repeat.

## v1.58.19

Albrhi for YouTube Music 0.4.1: the settings screen no longer crashes on open — a row count that
was not edited with the two arrays beside it — and its links point at this project's source rather
than upstream's.

## v1.58.18

Albrhi for Instagram 4.1.14: two diagnostics corrected — one could not recognise the tweak's own
date format, the other named a missing hook and not the working one — and the AV1 transcode is on by
default, because without it the download button fails silently on most of the feed.

Albrhi for YouTube 1.21.0: simultaneous downloads are a setting, and the MPEG-TS demuxer has tests
that run on the build machine.

## v1.58.17

Albrhi for YouTube Music 0.4.0: the settings screen — reached from the account menu — which the last
two releases shipped ten features without.

## v1.58.16

Albrhi for Instagram 4.1.13: a saved AV1 reel keeps its ten bits and its HLG/BT.2020 description,
so it no longer plays flat next to the app.

## v1.58.15

Albrhi for Instagram 4.1.12: the AV1 transcode stops synthesising film grain it is about to
re-encode, and reuses the encoder's own pixel buffers instead of allocating one per frame.

## v1.58.14

Albrhi for YouTube Music 0.3.0: synced lyrics with romanisation and a source picker, carried over
from YTMEnhanced under GPLv3 and verified by a 29-test suite that runs on the build machine.

## v1.58.13

Albrhi for YouTube Music 0.2.0: the speed control, seek buttons, no autoplay radio, casting, hidden
navigation buttons, an OLED theme and SponsorBlock -- carried over from YTMEnhanced under GPLv3,
without its Premium claim.

## v1.58.12

Albrhi Panel 0.9.22: a master switch above every tweak, a guide page with each tweak's verified
app version, settings backup and restore through the share sheet, and an update check that runs
only when asked.

## v1.58.11

Albrhi for Instagram 4.1.11: AV1 reels transcode again -- their ladder is 10-bit, and every frame
was being refused on the way to the encoder.

## v1.58.10

Albrhi for TikTok 0.19.10: the publish date appears on photo posts, and the date read for one is
that post's own rather than the last video's.

## v1.58.9

Albrhi for TikTok 0.19.9: the publish date is measured when the layout is real, so it sits in the
same place on every video rather than only on the ones already laid out when they were bound.

## v1.58.8

Albrhi for TikTok 0.19.8: the publish date lines up with the download button and stays on screen.

## v1.58.7

Albrhi for TikTok 0.19.7: the publish date breaks into two lines, the time and its joining word
beneath the date, with that word read from the locale rather than written into the source.

## v1.58.6

Albrhi for TikTok 0.19.6: the publish date is placed in the same coordinate space it is measured
in, which is what the lean actually was, and its original format is restored.

## v1.58.5

Albrhi for TikTok 0.19.5: the publish date sits over the download button on every device. It was
being clamped into a container narrower than itself, so it leaned left by however much that
container's width differed between phones.

## v1.58.4

Albrhi for TikTok 0.19.4: the publish date sits above the download button instead of below and to
one side.

## v1.58.3

Albrhi for TikTok 0.19.3: the publish date is drawn once the button is really on screen, and its
diagnostic counts calls rather than successes — it was reporting zero while running constantly.

## v1.58.2

Albrhi for TikTok 0.19.2: the publish date follows the button wherever it is placed, and the
recalled-message marker uses the key a device confirmed.

## v1.58.1

Albrhi for TikTok 0.19.1: the publish date now actually appears — it was being read on one of the
four paths that build an item — and the report says which stage stopped when it does not.

## v1.58.0

Albrhi for TikTok 0.19.0: the video's publish date, shown under Albrhi's own button.

## v1.57.0

Albrhi for TikTok 0.18.0: more logged-in accounts, messages the sender took back stay visible and are marked as taken back, and a
record of profile visitors that a later block cannot erase.

## v1.56.1

Albrhi for YouTube Music 0.1.1 — 1.56.0 never published: its rootless build failed on a `%orig`
that the two Theos installs disagree about.

## v1.56.0

**Albrhi for YouTube Music 0.1.0 joins the package** — seven tweaks in one install now. No ads, and
background playback without the upsell notification that interrupts it.

**It does not unlock Premium.** The tweak its hooks are carried from answers `-isPremiumSubscriber`
with YES on six classes; that is the one thing not carried over, the same line drawn for Locket and
Spotify. The two files taken never ask what the account is — measured before a line was copied.

## v1.55.3

Albrhi for Spotify 0.2.3 — the crash on roothide is fixed. A build flag was missing, and it chose a
code path that hooks classes without checking each one is there.

**This is the release that carries Albrhi for Spotify** — six tweaks in one package now, and the
first one written in Swift. Spotify's ads and Premium popups are blocked, and sponsored podcast
segments can be skipped; **it does not unlock Premium**, and its page says so above its switches.

## v1.55.2

Albrhi for Spotify 0.2.2: the Spotify crash is fixed. A hook group was being activated without
first checking that the class it hooks exists in your version of the app.

## v1.55.1

**1.55.0 crashed Spotify — install this one.** The clean-share-links hooks were the only ungrouped
ones in Albrhi for Spotify, so they installed at startup regardless of the master switch. The
feature is removed; the ad blocking, the Premium popups and SponsorBlock are unaffected and remain
gated.

## v1.55.0

**Albrhi for Spotify 0.2.0** — ads and Premium popups blocked, sponsored podcast segments skipped
(off until you turn it on: it asks a third-party server what is playing), and share links stripped
of their tracking parameters. Still no Premium unlock, and the page says so above its switches.

## v1.54.4

Albrhi for Spotify 0.1.2 — **1.54.3 and earlier blocked nothing.** The tweak loaded and installed no
hooks at all, because Orion's runtime was never started. Install this one.

## v1.54.3

Albrhi Panel 0.9.19: Albrhi for Spotify sits with the apps, under Spotify's own icon, and opens its
page from there.

## v1.54.2

Albrhi Panel 0.9.18: the Albrhi for Spotify row carries Spotify's own icon rather than a drawn
music note.

## v1.54.1

Albrhi for Spotify 0.1.1 — the version the merged package carries.

## v1.54.0

**Albrhi for Spotify is in the package now, not a second download.** Ads, sponsored rows and the
Premium popups, alongside Instagram, YouTube, X and TikTok — one install, one update.

**It brings a dependency with it, and that is the honest cost:** `com.albrhi` now requires
`dev.theos.orion`, because this is the first Swift tweak here and Orion is its runtime. Package
managers fetch it on their own; it is stated rather than left to be discovered.

**It does not unlock Premium.** The ad blocking is carried over from EeveeSpotify under GPLv3 — the
same licence Albrhi ships under — and its subscription unlock is deliberately not included. The
settings page says so above its own switches.

## v1.53.3

Albrhi Panel 0.9.17: a settings page for Albrhi for Spotify, which is published as its own package.

## v1.53.2

**1.53.1 could put SpringBoard into safe mode — install this one.** Albrhi Watch 0.5.2 fixes the
missing type check that caused it, and the diagnostic responsible is now off unless it is switched
on. Everything else is unchanged.

## v1.53.1

Albrhi Watch 0.5.1: the diagnostics no longer discard domain names that look like bundle
identifiers, and each domain is read both with and without the paired watch so the two can be
compared.

## v1.53.0

Albrhi Watch 0.5.0: the diagnostics report reads the watch's real preference-domain names off the
device and asks each one what it holds — the groundwork the photo, music, apps and Maps features get
written from.

## v1.52.4

Albrhi Watch 0.4.4: the "Albrhi is holding this update" notice reaches the up-to-date page, which
carries no footer of its own and was therefore never stamped.

## v1.52.3

Albrhi Watch 0.4.3: the "Albrhi is holding this update" notice survives the page settling into its
up-to-date state instead of flashing and disappearing.

## v1.52.2

Albrhi Watch 0.4.2: while watchOS 26 is held, the update page's install row is disabled and says so
rather than offering an update nothing can start.

## v1.52.1

Albrhi Watch 0.4.1: 1.52.0 could crash the Watch app on its update page. The two hooks responsible
are removed and the install actions are refused instead. Install this one.

## v1.52.0

Albrhi Watch 0.4.0 and Albrhi Panel 0.9.15: the watchOS hold is a version filter rather than a
blanket refusal — it holds watchOS 26 and newer and leaves older updates offered.

## v1.51.3

Albrhi Watch 0.3.3: the diagnostics report refreshes while the app is used instead of describing
only the moment it launched, and the nano-domain names are read off the device rather than guessed.

## v1.51.2

Albrhi Watch 0.3.2: two diagnostics that reported zero for several different reasons now say which,
so the next round of watch work is written from an answer rather than an absence.

## v1.51.1

Albrhi Watch 0.3.1: the watch's Software Update page no longer sits on "Checking for updates…" when
the hold is on, it says Albrhi is holding them, and the diagnostics report lists what
NanoPreferencesSync actually holds.

## v1.51.0

Albrhi Watch 0.3.0: while updates are held, the watch's Software Update page says Albrhi is holding
them instead of only saying the watch is up to date.

## v1.50.9

Albrhi Watch 0.2.9: the diagnostics report carries NanoPreferencesSync's real method lists, which is
what the photo, music, apps and Maps features get written from.

## v1.50.8

Albrhi Watch 0.2.8: the Watch app reads Albrhi's switches from the file when the preferences daemon
answers a sandboxed process with nothing — the reason its half of the tweak looked switched off
while SpringBoard's half was working.

## v1.50.7

Albrhi Panel 0.9.13: the Albrhi Watch page states whether the tweak is actually on, above its
switches instead of only inside the diagnostics report.

## v1.50.6

Albrhi Watch 0.2.7: the update hold replaces the scan's answer instead of refusing the scan, which
would have left the Software Update page waiting forever; the download and the install are refused
as well; and the report says whether the switches are on.

## v1.50.5

Albrhi Watch 0.2.6: the update hold installs what this build of the Watch app actually has rather
than refusing unless it has everything, its verdict reaches Settings, and the diagnostics print
whole method lists instead of counts.

## v1.50.4

Albrhi Watch 0.2.5 and Albrhi Panel 0.9.12. The Watch app's diagnostics report reaches Settings:
its preference write was being redirected into the app's own container rather than refused, so a
read-back confirmed a write that had gone nowhere useful. It travels as a file now, written where
a sandbox always allows and read by SpringBoard, which is not sandboxed.

## v1.50.3

Albrhi Watch 0.2.4 and Albrhi Panel 0.9.11. The tweak was gated on Albrhi's per-app switch, which
no switch anywhere sets for a tweak collapsed into one grouped row — so nothing installed at all.
Its own master switch is the gate now. The diagnostics report is merged from both processes, the
update hold's verdict travels with it, and the Watch app says whether it ran and whether it could
write, so an empty section stops meaning two different things at once. A restart button per
process, and an honest answer about what a full userspace restart needs.

## v1.49.3

**If a tweak is installed but Albrhi has not caught up with its settings page, the page's row now
says so** instead of not appearing at all. Installing Albrhi Watch before this update made the
tweak look as though it had not installed.

Includes Panel 0.9.7.

## v1.49.2

Albrhi Watch's settings page gains a switch that stops the Watch app looking for watchOS updates,
and a button that copies a diagnostic report from inside SpringBoard and the Watch app.

Includes Panel 0.9.6.

## v1.49.1

**A page for Albrhi Watch** — a new standalone tweak that pairs an Apple Watch running a watchOS
your iPhone does not officially support. The tweak is its own package; this release only adds its
settings page to Settings › Albrhi, with the master switch, what it answers, and a restart button.

Includes Panel 0.9.5.

## v1.49.0

**Albrhi CarPlay has been removed from this project.** It put an ordinary app on the car display,
and it never ran on a device across three releases; it is going to be rebuilt from scratch in a
repository of its own, where a tweak that can take the home screen with it does not share a source
with a download button. If you installed it from one of its releases it keeps working, and it will
not receive updates from this source.

The Albrhi page no longer shows a row for a tweak whose settings page is not installed.

Includes Panel 0.9.4.

## v1.48.4

**The watermark came back in 1.48.3 and is gone again.** Picking the largest version of a picture
picks the watermarked one, because a watermarked copy is the same image with something painted on
it and weighs more. Size now only decides between versions of the same kind: every clean version is
tried before any watermarked one.

Includes TikTok 0.17.7.

## v1.48.3

**TikTok now picks the largest readable version of a single saved picture** rather than the first
one that works, by measuring the alternatives before downloading. Saving a whole album is unchanged
— measuring every version of every picture would be hundreds of requests before anything is saved.

The save report also names the pixel size of what it saved.

Includes TikTok 0.17.6.

## v1.48.2

**TikTok photo saving no longer falls through to the watermarked copy.** When a post's original
picture is in a format iOS cannot decode, the tweak now tries every clean variant — including
TikTok's own ranked list of formats — before it will consider a watermarked one, and the report
names which variant was actually saved.

Includes TikTok 0.17.5.

## v1.48.1

TikTok photo saving now asks the app for a readable format the way the app itself does, before
falling back to anything this tweak guesses. Some photo posts are served in a format iOS cannot
decode at all; TikTok carries its own switch for replacing it, and that switch is now used.

Includes TikTok 0.17.4.

## v1.48.0

**TikTok photo saving works again on posts whose pictures are served in a format iOS cannot read.**
One report showed TikTok handing over a VVC still — a format the phone has no decoder for at all —
where the tweak kept only that one link and had nothing to fall back to. It now collects every way
the post offers each picture, reads the bytes before handing them to Photos, and saves the first
one that actually decodes.

Includes TikTok 0.17.3.

## v1.47.0

**TikTok's status report is readable again.** Two rows that dump a whole class's method list are
summarised on screen and left out of the ordinary Copy — a second **Copy everything** sends them
when a class list is actually the question. Sending a report no longer means sending a wall of
text.

**Albrhi NextUp's diagnostic log is off by default**, with a switch for it in Settings › Albrhi ›
Albrhi NextUp › Advanced. It used to write what every process was doing — including the titles of
what is playing — to disk on every install.

Includes TikTok 0.17.2 and Panel 0.9.3.

## v1.46.0

**Settings › Albrhi is tidier.** The tweaks that run across several processes — Albrhi NextUp and
Albrhi CarPlay — now sit in their own section under the apps, each with its own icon, instead of
being listed as though they were apps. The count at the top counts apps, which is what it sits
above.

**Albrhi NextUp's settings page was redesigned** in the same identity as the rest of Albrhi: a
header with the mark, a line saying what it does, and a pill showing whether it is on — plus an
icon on every switch.

Each app row also says which build of that app it was written against — YouTube 21.32.4, YouTube
Music 9.28.4, Spotify 9.1.62 — and the footer explains the one app that behaves differently:
YouTube has a real queue for a playlist or mix, but a standalone video has none, so its own
autoplay suggestion is shown instead.

Includes Panel 0.9.2.

## v1.45.0

**Albrhi NextUp's page no longer shows its main switch as on when it is off.** That tweak
now stays off until you turn it on — nothing it does happens until you ask — and this
update makes the settings page agree with it.

Includes Panel 0.9.1.

## v1.44.0

**Settings › Albrhi gained a page for Albrhi NextUp**, a new tweak released on its own that
shows what plays next on the Lock Screen. The row only appears if you have that tweak
installed, so nothing changes here otherwise.

Includes Panel 0.9.0.

## v1.43.1

**Saving a video from an Instagram repost now saves the video.** 1.43.0 stopped it saving the
cover picture; this one makes it actually download. The check that decided whether a video was
available looked in three places while the download itself looks in four — so a video whose only
copy was in the fourth was refused by a test the download would have passed.

Includes Instagram 4.1.10.

## v1.43.0

**A repost no longer saves as a picture.** Instagram stores a repost as a reference rather than
as the post itself, so its video is not ready at the moment you tap save — and the download read
"no video right now" as "this is a photo" and saved the cover image instead. It now tells the two
apart, and says so plainly when a video genuinely is not ready yet rather than handing back a
different file than the one you asked for.

Includes Instagram 4.1.9.

## v1.42.1

**TikTok now welcomes you once, after installing.** A short screen saying what was added and where
to find it — the download button, photo posts, and the two-finger hold that opens the settings. It
appears once, not after every update, and Settings › Advanced brings it back.

**Albrhi for Locket has been removed from this source.** It was separated from the package earlier
and is now separated entirely, on request: it is no longer built here and no longer served. If you
have it installed it keeps working, and it will not receive updates from this source.

Includes TikTok 0.17.1.

## v1.42.0

**TikTok, confirmed on a device.** The download button sits above the profile picture on every
video and no longer moves between videos; a photo post now saves the picture you are actually
looking at; and one picture can be saved as a short video with the post's own sound over it.

**Ask before liking, ask before following** — two new switches, both off unless you turn them on,
with the question drawn in Albrhi's own dialog rather than a system alert.

**The TikTok settings screen was rebuilt.** The diagnostics that made up two thirds of it moved to
their own screen under Advanced, and the switches are grouped by what they do: Download, Watching,
Confirmations, Privacy, Protection. When the Albrhi panel switch is off, the screen says so at the
top in red instead of burying it.

Saving pictures also works properly for the first time: Photos was refusing them because the file
was announced under the wrong name.

Includes TikTok 0.17.0.

## v1.41.2

**TikTok: the quality attempt in 1.41.0 did not work, and this release says why rather than
guessing again.** The higher-quality list is not reachable from where Albrhi was looking. This
adds one harmless reading needed to reach it safely next time, and changes nothing else.

Includes TikTok 0.16.2.

## v1.41.1

**TikTok crashed often on 1.40.1. Fixed by removing the cause.** That release added a diagnostic
that attached to one of TikTok's own methods incorrectly. It has been removed entirely — it had
already told us what we needed, and the quality fix in this release does not depend on it.

Includes TikTok 0.16.1.

## v1.41.0

**TikTok: downloads were taking a reduced copy of the right quality.** Measured on-device, the
quality list Albrhi was reading carries the same quality names as the one TikTok's own player
uses, at a quarter of the bitrate — so a "720" download was a 720 at a quarter of the detail the
app shows. Albrhi now reads the player's own list first. This is the cause of both the soft
picture and the poor sound.

Includes TikTok 0.16.0.

## v1.40.1

**TikTok: a diagnostic for the quality complaint, and nothing else.** Downloads sound and look
worse than the app's own playback, and there are two possible causes that need opposite fixes —
so this release adds one line reporting what TikTok's own player is offered and what it picks,
and changes nothing about downloading until that says which cause it is.

Includes TikTok 0.15.1.

## v1.40.0

**TikTok: the optional external HD source is asked properly now — and measured against.** It
needed a real API request rather than a direct link, which is why it never worked. Measured on a
real video, the file it returns is byte for byte identical to the one Albrhi already downloads,
so the switch stays off by default and is no longer presented as a quality upgrade.

Includes TikTok 0.15.0.

## v1.39.5

**TikTok: the external HD source now actually answers.** It was declining requests that did not
look like they came from a browser, so it never won the comparison — and when it is switched on
it now takes precedence rather than competing on file size. Downloads without it are confirmed
working: the clean copy is chosen over the larger watermarked one.

Includes TikTok 0.14.5.

## v1.39.4

**TikTok: the HD switch actually does something now.** The external HD source refuses the quick
size check every other link answers, so it was being ranked last and never used — the size is now
asked a second way. Photo saving also gained a second decoder for the formats iOS declines, and
the diagnostics no longer mislabel which link came from where.

Includes TikTok 0.14.4.

## v1.39.3

**TikTok: the watermark is refused from both sides, and posts marked "no download" save anyway.**

Includes TikTok 0.14.3.

## v1.39.2

**TikTok: downloads without the watermark.** Picking the largest file was picking TikTok's
watermarked copy, which is usually the biggest one — the clean copy now wins regardless of size,
and the watermark is also switched off at the setting the app itself reads. Plus the video's
music track can no longer be mistaken for the video.

Includes TikTok 0.14.2.

## v1.39.1

**TikTok: two fixes to yesterday's download change.** Picking the largest file could pick the
music when the video's own link would not report its size — the file's type now decides before
its size, so audio never wins. And a photo post could save a video, because TikTok also renders
a slideshow as one; pictures are checked first now.

Includes TikTok 0.14.1.

## v1.39.0

**TikTok downloads now pick the biggest file, not the best-guessed name.** Every link TikTok
offers for a video is measured before saving and the largest one is taken — which ends the
guessing about which internal path gives the better quality, because the app only fills its
quality list with what it happens to be streaming at the time.

**New switch, off by default: HD from an outside service.** It fetches a 1080 copy from
an outside service. Turning it on tells a service outside TikTok which video you are watching — the same
kind of reporting the privacy switches beside it exist to stop — so it is off until you choose
it, and its row says so plainly.

Includes TikTok 0.14.0.

## v1.38.5

**TikTok: photos that Photos refused now save.** Some photo posts failed with an error that
looked like a broken download and was really the Photos library rejecting the file format —
TikTok serves some pictures as WebP, and nothing was telling Photos what it was being handed.
Pictures are now saved as posted where possible, and converted where the library insists.

Includes TikTok 0.13.5.

## v1.38.4

**TikTok: photo posts ask which picture, and show that they are saving.** A post of sixteen
used to save all sixteen silently; now tapping offers the picture you are looking at or the
whole post, and a progress indicator appears either way.

On quality: a device report settled it — 720 was the highest TikTok offered for that video, so
nothing was being chosen wrongly. The quality row now reads cleanly instead of repeating the
same gears three times.

Includes TikTok 0.13.4.

## v1.38.3

**TikTok: photo saving says why it failed, and quality looks at every list TikTok offers.**
Photo posts were being found and then failing to save with nothing explaining it — the three
different causes are now named, and images TikTok serves as WebP or HEIC are handed to Photos
as-is instead of being re-encoded. Quality now compares all three of the app's quality lists
rather than only the first. And the diagnostics report was missing two rows the settings screen
had, including the one for quality.

Includes TikTok 0.13.3.

## v1.38.2

**TikTok: photo posts save, and the quality report says what was on offer.** Photo posts were
being looked for under the wrong list name inside the right object. And when a download comes
out at 720, Settings › Status now shows every quality TikTok actually offered for that video
with the chosen one marked — so "the picker chose wrong" and "there was nothing better" stop
looking the same.

Includes TikTok 0.13.2.

## v1.38.1

**TikTok: photo posts and HD actually work now.** Both were shipped in 1.38.0 against one
misspelled accessor each — the quality list was asked for a property whose real name differs by
a single capital letter, and photo posts were looked for one level away from where they live.
Neither was guessed at this time: both names were read out of TikTok's own binary.

Includes TikTok 0.13.1.

## v1.38.0

**TikTok: a progress bar, photo posts, and HD.**

A seek bar stays under every video instead of appearing only while you drag, with its own
switch. Photo posts save as photos, every image in the post, each its own entry
in Photos; they used to be skipped entirely because they have no video to find. And downloads
pick the highest-quality copy TikTok offers rather than the first one it lists, which is what
"it saves SD" was.

HD crashed the app once, in 1.37.0. It is back because both reasons it crashed were settled by
measurement rather than patched: the bitrate value's type is read from the runtime instead of
assumed, and the quality list is only ever consulted for a video already on screen, never for a
model still being built. If anything about that fails, the download still happens at the old
quality.

Includes TikTok 0.13.0.

## v1.37.1

**TikTok crashed on 1.37.0. Fixed by reverting** the HD change that caused it. The button and
downloads work as they did in 1.36.0 — right video, right clip — at the quality that release
gave. HD returns when it can be done without risking the app.

Includes TikTok 0.12.1.

## v1.37.0

Includes TikTok 0.12.0 — **downloads go for the highest-quality gear TikTok offers.** The video
model carries a list of bitrate variants, and the tweak had been reading single URLs past it for
four releases. The best one is now chosen by comparing bitrates rather than by taking whichever
was listed first.

## v1.36.0

Includes TikTok 0.11.0 — the download button finally knows which video it belongs to. The feed
cell turned out to be a container that hosts a view controller, and the video model belongs to
that controller rather than to the cell, which is why two releases of trying accessor names on
the cell found nothing.

## v1.35.1

**TikTok: the download button was invisible in 1.35.0.** Restored. It also downloads again, and
the report now distinguishes "saved the wrong clip" from "saved nothing".

Includes TikTok 0.10.1.

## v1.35.0

Includes TikTok 0.10.0 — **saving works, and saves the right video.** Downloads are real videos
now rather than 972 KB of audio, and the button asks its own feed cell which clip it belongs to
instead of taking the last one TikTok happened to build — which during a scroll is one being
preloaded, not the one on screen. The button also moves above the profile picture.

## v1.34.0

Includes TikTok 0.9.0 — **the save button moves off TikTok's interaction rail and onto the feed
cell itself**, which is where the reference tweak puts its own. The rail was rebuilt by TikTok
between videos, which is why the button vanished on some of them and drifted sideways on the
rest. A cell hook fires once per video and the position is ours. Downloads are unchanged; that
is the next problem.

## v1.33.1

Includes TikTok 0.8.1 — the save button's size is finally tied to the icons beside it rather
than to sizes read before anything had been laid out, which is why it kept leaning to one
side. The report also stops presenting a stale save record as a fresh one, and names which of
the two rails it is describing.

## v1.33.0

Includes TikTok 0.8.0 — **downloads should finally be the video, at download quality, without
a watermark.** The video model's own accessor list, printed from a device, named
`downloadNoWatermarkURL` and `downloadURL` — and showed that the field guessed at twice
before was never on that class. The save button also no longer leans to one side: only its
height had been matched to the rail, never its width.

## v1.32.1

Includes TikTok 0.7.1 — the save button no longer lands between two invisible background
views, which is why it looked off-centre. And Diagnostics now prints the video model's own
URL accessors, which is the one list that has never been in the report and the reason the
"saves audio instead of video" problem is still open.

## v1.32.0

Includes TikTok 0.7.0 — **downloads should be the real quality now.** The app's own binary
showed that `playAddr` is the *streaming* address and `downloadAddr` is the one TikTok serves
for saving, and nothing in the tweak had ever asked for the latter. It also showed that
seven of the resolver's candidate chains were built on a selector this TikTok does not have,
so they had never run at all.

## v1.31.2

Includes TikTok 0.6.2 — a download chain that had been misspelled since it was written now
actually runs (`downloadInfoModel`, with a capital I), and the first real attempt at HD:
`playURL` is the *playback* stream, served at a bitrate chosen for smooth playback, so the
bitrate variants are tried ahead of it. The button's random appearance and the wrong-video
save are **not** fixed yet — see the TikTok changelog for why each is named rather than
guessed at.

> **Note on 1.28.0 – 1.31.1.** Those four releases moved `suite/control` without leaving
> notes here, and they are where **the TikTok tweak arrived in this package** — the only
> thing in it this file has never described. Its own history is in
> `tweaks/tiktok/CHANGELOG.md`. This file is what the release notes and the Sileo depiction
> are generated from, so the gap shows to anyone updating; it is named rather than filled
> in with suite-level descriptions written after the fact by someone who did not make those
> releases.

## v1.27.1

**Settings crashed when opening the Albrhi page.** Fixed — 1.27.0 registered its new row
type by name where Preferences expected the type itself. Includes Panel 0.8.1.

## v1.27.0

Includes Panel 0.8.0 — **Settings › Albrhi is one row per app now.** Each carries its icon,
its switch, and a line saying which version is on this phone and which the tweak was verified
against. The separate Versions section, which listed the same apps a second time, is gone.

## v1.26.0

Includes Panel 0.7.0 — Settings › Albrhi now says how much of the tweak is on at a glance
("2 of 5 on") instead of leaving it to be counted. Since the per-app switch became opt-in, a
fresh install is a page of switches that are all off, and nothing said so.

## v1.25.1

Includes Instagram 4.1.8 — the follow badge keeps a second way of finding the profile's
user, so the crash fix in 4.1.6 cannot cost the badge on Instagram 410. The class dump that
fix was built from turned out to be 439; this tweak serves 410, 439 and 441 from one build.
Still no KVC.

## v1.25.0

**Locket has left the suite.** It is no longer bundled in `com.albrhi`, no longer
declared in Conflicts or Replaces, and no longer removed by the suite's own preinst — it
publishes independently now, as its own package (`com.albrhi.locket`), with its own
releases and its own self-contained sideload dylib. See tweaks/locket/CHANGELOG.md v0.3.0
for what changed in Locket itself, including a new welcome screen. This package now
bundles Instagram, YouTube and X.

## v1.24.0

Includes YouTube 1.20.0 — **the scattered ad on Home, found and fixed.** A real in-feed
ad slot was carrying a layout identifier, `video_display_carousel_button_group_layout`,
that had no "ad" anywhere in its name and was not yet on the feed filter's list. Found
from a device report, confirmed as a real ad slot rather than guessed, and added.

## v1.23.1

Includes YouTube 1.19.1 — the feed diagnostic widened after its own first report showed
it cutting a promising section off mid-word. A flagged section now reads up to 1800
characters instead of 150; nothing is dropped differently, only more is kept to read.

## v1.23.0

Includes YouTube 1.19.0 — the ad measurement retargeted to where the ads actually were:
the Home feed while scrolling, not the player. Every batch of Home sections the ad
filter lets through is now sampled in Settings › Diagnostics › "Home feed → kept
sections" — scroll until an ad shows, stop, and send that section so the real fix can
target the exact identifier that slipped past.

## v1.22.0

Includes YouTube 1.18.0 — a measurement for "ads still get through sometimes," not a
fix yet. Two reference tweaks were read for architecture and confirmed this tweak
already hooks the same core ad gates they do; they also touch a cluster of ad-slot
selectors this one does not, every one confirmed real on this build but of unknown
class and shape. A new diagnostic probes them safely and reports what it finds — a real
hook follows once a device report says which class answers.

## v1.21.0

Includes YouTube 1.17.0 — **the Download Centre redrawn to look native**, not like a
skin borrowed from a music player. A real large title, a flat dark background matching
the app's own, filter chips styled exactly like the app's own filter row, and rows
without floating cards or per-item colour tinting — a picture, two lines of text, a thin
hairline, edge to edge.

## v1.20.0

Includes YouTube 1.16.0 — **the Download Centre split into three: Video, Shorts, Audio.**
A Short now gets its own section and its own tall thumbnail shape instead of being
stretched into a video row it never fit. Also: a real diagnostic for the "sound does not
show on the lock screen" report, in place of a guessed fix — the code treats video and
sound identically end to end, so a fourth blind guess would very likely have been wrong
the way two of the last three guesses at its sibling bug were.

## v1.19.0

Includes X 0.14.0 — **the save button, down to one surface.** It was showing twice on an
ordinary post — once on the media's own corner, once after the share button — because
four separate placements ran at once as fallbacks for each other. Three are gone; the one
kept is the button inside the video itself, which stays with it while you swipe.

## v1.18.0

Includes YouTube 1.15.0 — **the saved-media player, polished to feel like the rest of
the system.** Drag down anywhere to close, the way every full-screen player on the
platform already works. A spinner while a file is genuinely buffering rather than while
it merely has not started. A light haptic tap on play, pause, skip and track change.

## v1.17.0

Includes YouTube 1.14.0 — **real, system Picture-in-Picture**, unlocked rather than built:
the app's own player already has the whole thing, gated by one property this tweak now
forces. And **smoother motion on a ProMotion phone** — the player's own redraw rate is
raised to the screen's real ceiling rather than a lower one YouTube sets on its own.

## v1.16.0

Includes X 0.13.0 — **four more features, and two honest declines.** A confirmation
before Retweet (off by default), an offer to save a profile photo when you open one (on
by default), an experimental and openly blunt "who to follow" card hider, and a
picture-in-picture *recorder* rather than a switch — the real API takes a private numeric
code this class dump names no meaning for, and a guessed number was not worth the risk of
silently breaking video playback instead of turning PIP on. Extending the promoted-tweet
filter to trends, and touching account-level premium flags directly, were both looked
into and left alone: neither could be done without a guess this project does not ship.

## v1.15.0

Includes X 0.12.0 — **a new, experimental switch that hides real Promoted Tweets**, which
"Hide ads" never touched: those are ordinary posts the server marks, not something a client
switch can suppress. Off by default until a device confirms it, with its own counter on the
diagnostics page. And **the raw switch list moved to its own page**, one tap from a single
row instead of the last, long section of the main screen every time it opened.

## v1.14.0

Includes X 0.11.0 — **the settings screen carries an icon beside every row now**, the way
iOS's own Settings app draws its own. Saved media moved up, right under the quick switches
and ahead of the seventeen named features, since saving a video or a photo is the reason
this tweak exists in the first place. Pull to refresh re-reads what has been seen and saved.

## v1.13.1

Includes X 0.10.1 — the in-video save button no longer jumps back to the wrong place after
the first swipe. Two surfaces were adding a button under the same tag; the one that was never
visible has been removed.

## v1.13.0

Includes X 0.10.0 — **the X settings screen is redesigned.** A status card at the top says
whether the tweak is attached at a glance, search moved to the navigation bar where it stays
reachable, and the All/Changed filter became the search bar's own scopes.

## v1.12.2

Includes X 0.9.2 — the in-video save button moves clear of X's back chevron, which it was
landing behind.

## v1.12.1

Includes X 0.9.1 — the in-video button moves to `ImmersiveCardView`, which is the container
the video's overlays are children of, so the button can finally sit above them. 0.9.0 put it
on the page underneath that stack: seven added, none visible. Settled by unpacking TWIGalaxy
and reading which classes it actually names.

## v1.12.0

Includes X 0.9.0 — **a save button pinned inside the video itself**, which stays with that
video as you swipe between clips. It goes on the per-video page rather than on the action
row, so it belongs to the clip and not to the screen, and it is raised above the full-screen
gesture layers X stacks over the video. The action-row button from 1.11.0 stays.

## v1.11.2

**Instagram: on a multi-photo post, "Save this one" saved the first photo no matter which
one you were on.** It now asks the page-control dots which slide is showing and saves that
one. "Save all" was never affected.

Includes Instagram 4.1.7.

## v1.11.1

**Instagram: changing your profile picture crashed the app.** Fixed. The cause was the
follow-status badge, which searched for the profile's user by probing a dozen guessed keys
with `-valueForKey:` on everything up the responder chain, from inside layout — and
`-valueForKey:` runs the app's real getters rather than politely failing. It now asks for
one confirmed accessor and nothing else. Nothing about the badge or any other feature
changes.

Includes Instagram 4.1.6.

## v1.11.0

Includes X 0.8.0 — **the save button is on X's own action row now**, beside reply, repost,
like and share. X draws that row under a timeline post and over a playing video alike, so
one surface answers both. The earlier in-video attempt was adding a button to a stack X
rebuilds, which removed it every time; the report said "11 buttons added" and meant the
opposite.

## v1.10.3

Includes X 0.7.2 — if the in-video button is still missing, Diagnostics now prints the view
chain above the rail, which is the one thing that separates "wrong getter" from "the model
is not up there at all". Instrumentation only.

## v1.10.2

Includes X 0.7.1 — the in-video save button now actually appears. 0.7.0 found the right
rail; the media lookup behind it asked every view for `-viewModel`, and the immersive
card answers `-status` instead, so it gave up holding the object it needed.

## v1.10.1

Includes X 0.7.0 — **the save button inside a video finally has something to attach to.** A
class dump of X showed the rail it was being added to no longer exists; the immersive player
was rebuilt around plugin views and its action rail is now `ImmersiveActionsStackView`. Both
names are hooked, and diagnostics names which one attached.

## v1.10.0

Includes YouTube 1.13.0 — a save button and an end-time inside YouTube's own player, a cover
section in the download sheet, and a saved-media player restyled to read as iOS's own. Also
carries 1.12.5's background-playback scoping, which was never released on its own.

The two player-layer additions **default off**: they act on classes read from YTVideoOverlay's
source (MIT) rather than confirmed on a device, and the diagnostics page reports which
attached. Turn them on in Albrhi › YouTube › Interface.

## v1.9.7

Includes YouTube 1.12.5 — an attempt at the lock screen showing a different video from the
one playing. Background playback told the app that *every* video it built was fit to carry
on in the background, including ones it was only preloading; it now answers for the video
being watched. **Shipped to be tried, not confirmed fixed** — see the YouTube changelog for
what was ruled out, what is still unscoped, and how to tell if this was not it.

## v1.9.6

Includes Panel 0.6.7 — clearer guidance on the CarPlay page (its own separate
package, not part of this one) after a real device report showed app bridging
needed a respring, not just reopening the app, and was missing most of its
admission mechanism. Nothing else in this package changed.

## v1.9.5

Includes Panel 0.6.6 — a photo picker for Albrhi CarPlay's new dashboard-wallpaper
feature (its own separate package, not part of this one). Nothing else in this
package changed.

## v1.9.4

**Settings › Albrhi CarPlay opened to a black screen.** Fixed — the page was building
itself correctly and simply never handing the result to the part of PSListController
that draws it. Includes Panel 0.6.5.

## v1.9.3

Includes Panel 0.6.4 — a filter plist can now tell the panel to skip it entirely, which
CarPlay's second dylib (its own separate package, not part of this one) needed once it
gained a second binary. Nothing else in this package changed.

## v1.9.2

**Settings › Albrhi no longer lists "Camera" and "SpringBoard"** as if they were two
apps this package patches, on a device that also has Albrhi CarPlay installed — the
panel scans every Albrhi filter on the phone, suite or not, and CarPlay's names two
system processes for one feature, not two apps. The panel can now give a tweak a full
settings page of its own instead of a plain switch, and shows one "Albrhi CarPlay" row
that opens it.

Includes Panel 0.6.3.

## v1.9.1

**CarPlay is out of this package.** 1.9.0 folded it in for a day; it does not touch any
of the apps this suite patches and has nothing to do with them, so it now ships and
updates on its own — `com.albrhi.carplay`, its own release, its own source entry. Nothing
else changed.

## v1.9.0

A fifth tweak, Albrhi CarPlay, was briefly included in this release. It has since moved
to its own package — see v1.9.1 and `com.albrhi.carplay`.

## v1.8.2

**X: Diagnostics now says whether the save button is really on the video**, or fell back
to the tweet's own view -- read from the device rather than assumed from the code.

Includes X 0.6.2.

## v1.8.1

**X: the timeline save button shows while scrolling now, not only after opening a post.**
It was placed once, the first time a video's view was ever created, and a timeline reuses
that same view for every post scrolled past — so it stayed on whatever was first on
screen and never reached anything scrolled to afterward. It is placed on every post now,
the moment X hands that view its content.

Includes X 0.6.1.

## v1.8.0

**X: the save button is now inside the full-screen video — the swipe-up reels feed.** It
joins the row of playback controls beside like, reply and share, placed by that row itself
rather than floated over the corner, which is why it lands where the earlier one did not.
Learned from reading the reference tweak's binary — the class the old button used is not in
it; this one is.

Includes X 0.6.0.

## v1.7.3

**X: the save button lands inside the video every time now**, not just on a recycled
cell — the search for the video was running before the timeline had sized anything, and
now runs after.

Includes X 0.5.3.

## v1.7.2

Fixes the build 1.7.1 broke before it produced anything.

Includes X 0.5.2.


## v1.7.1

**X: the save button is inside the video, and stays there while you swipe between videos.**
It goes on the view X draws every video in — timeline, opened post, fullscreen, quoted
post, message — instead of on the corner of a cell.

Includes X 0.5.1.


## v1.7.0

**X: the save button is on the video now, not on top of the share button** — and it is
bigger, so it can actually be pressed.

**And X's settings page finally has Albrhi's own settings on it.** The save button, the
feature switches and the detailed log had no row anywhere and could not be turned off at
all. They are the first section; the status report has moved below them, where reading
matter belongs.

Includes X 0.5.0.


## v1.6.5

Fixes the build 1.6.4 broke before it produced anything.

Includes X 0.4.4.


## v1.6.4

**X: a save button on the tweet.** The one we had was on a view that a working tweak never
touches, which is why it never appeared. This one goes where that tweak puts it — on the
tweet itself — and Diagnostics now says which of the two your build of X supports.

Includes X 0.4.3.


## v1.6.3

**X: the save button, and the crash.** The button is placed with a plain frame now instead
of asking for a fresh layout from inside the one it was created in, which is the likeliest
cause of the crashing. And Diagnostics finally says what the button did — whether the
class X uses is even in your build, whether the hook attached, and how many videos it
saw — so a report about it can be acted on instead of guessed at.

Includes X 0.4.2.


## v1.6.2

**Locket no longer crashes.** The jailbreak bypass was hiding a folder that iPhone keeps
its own system files in, so the app was being told parts of iOS do not exist. The
jailbreak is still hidden — by the marker it actually leaves — and there is now a short
list of paths the bypass will never lie about, so nothing can do this again.

**The save button appears on X videos.** It never did: the button was being told what to
save before it existed, and hid itself because it had nothing.

Includes Locket 0.2.1 and X 0.4.1.


## v1.6.1

Three faults in the Settings page, found by reading it back rather than by anyone hitting
them: a header that could have laid out wrongly, the Albrhi mark existing at one
resolution only, and the installed version reading as unknown on a device where Albrhi
happened to be the first package installed. Details in the panel's own notes.

Includes Panel 0.6.2.


## v1.6.0

**The Locket tweak saves moments now.** Hold two fingers anywhere in Locket and every moment
it has loaded is listed, newest first — tap one to keep a friend’s photo or video to your
Photos at full size, the one they sent rather than a screenshot. Locket is a Swift app, so
the list is built from what it fetches over the network, filtered to real moments and away
from the app’s own artwork.

The jailbreak-hiding from 1.5.0 stays. And the X download button fix from this release rides
along.

It saves what is already on your phone and does not touch anything you would pay Locket for.

Includes the Locket tweak 0.2.0 and the X tweak 0.4.0.

## v1.5.0

**A fourth app: Locket.** Albrhi now keeps Locket from reporting your phone as jailbroken —
to its analytics, its ad-attribution SDK and its own code, all three of which check on a
modified phone and send the answer home, where it can count against your account. They now
come back clean.

It answers only the jailbreak questions — is this file here, can this app be opened, is this
folder writable — and only for the handful of paths a check looks at; everything else the app
asks the system passes straight through. Hold two fingers anywhere in Locket to see how many
checks were answered.

It does not touch payments or subscriptions, on purpose.

Includes the Locket tweak 0.1.0.

## v1.4.0

**The X tweak puts the download button on the video.** In the corner beside play and mute,
where you would reach for it — tap and the video is in Photos at the best quality X offers.
The list under the two-finger hold stays as a fallback, so saving keeps working even on a
build where X has renamed the video view.

Includes the X tweak 0.4.0.

## v1.3.0

**The X tweak saves videos now.** Hold two fingers anywhere in X and everything it has shown
you since you opened it is listed, newest first. Tap one and it is in Photos — videos at the
best quality X offers, photos at the size they were uploaded rather than the smaller copy the
timeline was showing, and GIFs as the video files X actually serves.

There is no button added to X, and that is deliberate: a button lives inside one of X's own
views, and those get renamed. The list is in our own screen, so it keeps working when X moves
things around.

Includes the X tweak 0.3.0.

## v1.2.0

**The X tweak has its features.** Seventeen switches in plain language: hide ads, hide the
Promote button, hide Grok, stop X translating by itself, hide Premium ads, send less about
you, clean up the interface, hide view counts, hide Spaces, show sensitive posts directly,
stop GIFs playing alone, pinch to zoom in the timeline, more gestures, more tabs, keep your
likes private, open faster, and X's own speed work that it ships switched off.

Each one sets a group of X's own switches at once and says what it does before you turn it
on. The full list of switches is still there underneath, and your own answer always beats a
feature.

Nothing here was guessed: every switch a feature touches is one a real phone reported —
341 of them over 345,902 questions on X 12.14.

Includes the X tweak 0.2.0.

## v1.1.0

**A third app: X.** Albrhi now patches X too, and it arrived the way this package was
built to let things arrive — inside it. Nothing extra to install, and it is already in
the list in Settings › Albrhi with its own switch.

**What the X tweak does.** X decides what your app is allowed to show from one place: a
list of switches every part of the app asks before doing anything. This tweak sits at
that one place. It shows you every switch your copy of X really asked about while you
were using it, what X answered, and how often it asked — and lets you answer any of them
yourself.

**Hold two fingers anywhere in X** to open it. There is a search box, a filter for the
ones you changed, one button to undo all your answers, and a report you can save to the
Files app.

Nothing on that list is guessed. It is what your own phone saw, which is the point: what
it reports is what decides which switches the next release turns on by name.

Includes the X tweak 0.1.0.


## v1.0.12

**Settings › Albrhi: the blanks are filled in.** "Made by" and every other value on the
page were empty, the version shown was the panel component's number rather than the
Albrhi you installed, and the Versions section could vanish instead of admitting it did
not know. All three are fixed.

**And a Respring button**, at the bottom of the page, behind a confirmation.

Includes Panel 0.6.1.


## v1.0.11

**Settings › Albrhi has a face.** The Albrhi mark, the name and the version above the
list, the same icon on the row itself, and each app shown with its own icon — Instagram
and YouTube are now told apart before their names are read.

**And a Versions section.** Every tweak states the app versions it was last verified
against, and the page shows that beside the version actually on your phone: "410.1.0 ·
tested" when they agree, "412.0.0 · tested on 410, 439, 441" when they do not. Nothing
is switched off on a mismatch — a newer app usually works fine. It is there so that when
something does break, the fact that explains it is already on screen.

Includes Panel 0.6.0, Instagram 4.1.5 and YouTube 1.12.4.

## v1.0.10

- The source updates properly now. It had started working already — the site was
  serving an older Albrhi rather than none — but the build was still finishing when
  the run checked, so a working publish was reported as a failure. The run now waits
  for the build to actually finish before looking.

## v1.0.9

- **Settings › Albrhi now really turns a tweak off.** The switch moved but the app
  carried on as before; the setting is read directly now. Close and reopen the app for
  a change to take effect, as before.

## v1.0.8

- The source updates again. The step that published it had been getting stuck every
  run, holding the whole thing for as long as it was allowed to. It is gone, and the
  package list is now served straight from the branch it was already being written
  to — the simpler arrangement, with nothing to wait on.

## v1.0.7

- Fixes the source not updating. Publishing now works with how the repository is
  actually set up instead of assuming one particular setting, so the package list
  is refreshed either way, and the run checks the live source afterwards rather
  than reporting that a step finished.

## v1.0.6

- The package page in Sileo now describes this package rather than the old separate
  Instagram one, and is generated from this changelog so it cannot go stale.

## v1.0.5

- The roothide package is now checked properly before it is built, by reading the
  libraries each part links against rather than only where the files sit. A package
  can look right and still be built the wrong way, and that is what Sileo was
  refusing.

## v1.0.4

- Fixes the build, which 1.0.3 broke before it produced anything.
- The roothide package is now checked to actually be one before it is built, instead
  of being found out after installing it.

## v1.0.3

- Fixes the roothide package installing as a rootless one. The combined package was
  built with its own description, which threw away the details the build tool fills
  in to say which kind of jailbreak a package is for.

## v1.0.2

- Includes the Instagram fix that brings back the reels download button.
- **Now really builds both flavours.** 1.0.0 and 1.0.1 produced a rootless package
  only — the roothide one was never built, and nothing was counting.

## v1.0.1

- **Now really removes the old separate packages.** 1.0.0 declared that it replaced
  them, which a package manager honours when installing from a source but which is
  ignored when you install a .deb by hand — so both copies stayed and both were
  loaded. It removes them itself now, however you install it.

## v1.0.0

**Everything Albrhi makes, in one package.**

- Install one thing. You get the Instagram tweak, the YouTube tweak and the settings page.
- Update one thing. Every tweak updates together.
- **Settings › Albrhi** lists every app Albrhi patches, with a switch each. Turn one off
  and Albrhi does nothing inside that app, without uninstalling anything and without
  losing your settings. Close and reopen the app for the change to take effect.
- New Albrhi tweaks will arrive in this same package and appear in the same list, so
  there is never a second thing to install.

Installing this removes the separate Instagram, YouTube and Panel packages. Your settings
live inside each app and are not touched.
