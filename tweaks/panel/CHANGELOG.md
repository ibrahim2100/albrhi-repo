# Albrhi Panel Changelog

## v0.9.38

**صفحة الترخيص صارت بهوية البرهي، وسؤال الخادم صار مرّة في اليوم.**

**علامة تجيب قبل القراءة.** «هل هي مفعّلة؟» هو أول سؤال في كل زيارة لهذه الشاشة، ودائرة خضراء
أو حمراء تجيبه أسرع من سطر نصّ — ويقرأها من يقف بعيداً بينما الهاتف بيد غيره. والكلمات تحتها،
لأن اللون وحده يقول «شيئاً» ولا يقول «انتهت في الرابع».

**وتاريخ الانتهاء ظاهر**، ومعه عدد الأيام: «حتى ١٦ سبتمبر ٢٠٢٦ — ٩ يوماً». التاريخ يجيب سؤالاً
وعدد الأيام يجيب سؤالاً آخر، ومن يقرّر التجديد يريد الثاني.

**والتفعيل فوري.** المفتاح يُتحقّق منه على الجهاز بلا شبكة، والكود يُسأل عنه الخادم والزرّ يدور
أثناء ذلك — وجملة «أغلق التطبيق وافتحه» **لم تعد تُقال للجميع**: من كانت خطّافاته مركّبة أصلاً
يعمل فوراً ويُقال له ذلك، ومن وقفت أداته عند الإقلاع وحده يُطلب منه إعادة الفتح. قولها للجميع
كذبة صغيرة تُعلّم الناس تجاهل النسخة الصادقة منها.

**وسؤال الخادم: من ٦ ساعات إلى مرّة في اليوم.** وقت آخر فحص محفوظ في نطاق كل تطبيق على حدة
بينما التوكن مشترك — فهاتف بأربع أدوات كان يسأل **١٦ مرّة في اليوم** ويجدّد التوكن نفسه ١٦ مرّة،
وكل واحدة كتابة على الخادم. حدّ Cloudflare المجاني ألف كتابة يومياً: ستّون هاتفاً وينفد بين
زبائنك أنفسهم، وبعدها يفشل التفعيل والتجديد للجميع. **السقف لم يكن مهاجماً.**

الفاصل الآن مبنيّ على **مدّة الترخيص** لا على عمر التوكن: يوم كامل في الحالة العادية، **ثماني
ساعات في الأيام الثلاثة الأخيرة وبعد الانتهاء** حيث يكون التجديد في الطريق، و**نصف ساعة** إذا
قارب التوكن على الموت — وهذه الأخيرة لم تُمسّ، فهي آخر حبل بين زبونٍ دافع وبوابة مغلقة بعد أيام
بلا شبكة. الثمن مذكور لا مخفيّ: السحب يصير خلال يوم بدل ست ساعات، والتصميم يَعِد أصلاً بأسبوع.

الجدول مُختبَر كدالّة خالصة — اثنتا عشرة حالة قبل أن يصل أي جهاز — والشاشة مقيسة في المحاكي
بالعربية في حالتيها، وهو ما كشف بطاقتين غير مرئيتين وتاريخاً بلغتين في سطر واحد.

## v0.9.37

**"Free" is out of every description.** The tweak needs a licence; a package page saying it is
free was the first thing anybody read. The licence itself is unchanged and still named in full —
GPLv3 where it applies, MIT for the Watch pairing core — because dropping a word is not the same
as dropping an obligation, and the attribution those licences require is not negotiable.

## v0.9.36

**Albrhi is the social-app tweak, and the panel now says only that.**

Albrhi NextUp and Albrhi Watch each ship their own Settings row and their own preference
bundle. Their pages, their strings and their rows are out of this package: what is left is
Instagram, YouTube, X, TikTok, YouTube Music, Spotify and the licence.

The furniture those pages shared — the header, the app cell, the badge art, the button
action — moved to `shared/src/Prefs/`, so three bundles draw the same thing from one place
rather than from a copy each.

## v0.9.35

**A purchase now leaves a record even when the conversation never happens.**

Choosing a paid plan asks for a name and a phone number, **files the request with the server, and
only then opens WhatsApp**. That order is the whole point: the other way round, closing WhatsApp
or never sending the message would leave nothing behind — no request in the panel, and the only
trace of somebody wanting to buy something sitting as a draft on their phone. Sending first
catches exactly the case worth catching, because that person meant to pay.

The message still opens either way. A request that did not reach the server is a reason to talk to
somebody, not a reason to stop them talking to you.

The name and number are remembered, so a second purchase does not ask again, and they travel with
the request — a panel showing nothing but device codes makes approving one an exercise in
remembering which conversation it belonged to, which is the bookkeeping the panel exists to
remove.

**And "Enter a key" and "Enter a code" are one row now.** They sat next to each other and read as
the same button written twice, which is how it was reported. They *are* two instruments, but that
is a fact about how a licence was issued, not a question the person holding one should have to
answer: they were sent a string and they want to put it in. A key announces itself with `ALB1.`;
anything else is treated as a code, which is also the path that can ask the server — so an
unrecognised string still gets a real answer instead of "that is not a key".

## v0.9.34

**The card appeared small and empty, and the reason is that a scroll view has no height of its
own.**

Pinning the content to the scroller's edges sets its *contentSize*. It says nothing about how tall
the scroller should be — so nothing in the whole chain gave the card a height. It collapsed to
whatever the solver picked and `clipsToBounds` hid everything inside it. Every row was built and
every label had its text; none of it had anywhere to be drawn.

The scroller now asks to be as tall as its content, at less than required priority so it still
yields to the two constraints keeping the card on screen. A tall phone gets a card exactly as tall
as its content; a short one stops at the screen and scrolls, which is what the scroll view was for.

**And this was looked at rather than reasoned about.** Three releases were aimed at this one screen
blind — nothing, then a small empty box. It was built as a throwaway iOS app, run in the simulator,
and photographed: five rows, header, footer. That took one build and settled what three rounds of
description could not.

## v0.9.33

**"Request a licence" did nothing at all, and doing nothing was the bug.**

The card searched `UIApplication.windows` for a key window and returned quietly when it found
none — which is what happens inside a preference bundle, where `keyWindow` is deprecated and
unreliable. **A silent nothing is the worst outcome available to a button somebody presses in
order to buy something**, and it was reported exactly as it looked: the button does not work.

Four surfaces now, in order of how well each works — the controller's own window, then any window
the scenes offer without asking for the key flag, then the navigation controller, then the
controller's view — and an alert saying *this is a fault* if all four fail. Nothing silent is left.

**The first fallback was itself weak and is fixed here too.** It attached the overlay with an
autoresizing mask, which measures against the superview's bounds — and the last of those four
surfaces is a table view whose bounds move as it scrolls, so the card would have slid off the
screen at the first touch. Pinned with constraints on all four edges, it stays put on every one.

**And the free week is shown rather than hidden when it cannot be taken.** It used to disappear
once a device had a licence, on the reasoning that a row which can only be refused teaches people
the screen is broken. The opposite happened: somebody with a licence looked for the free week,
found no row, and concluded the button was broken. An absence answers nothing — "why is there no
trial here" is a real question, and the row is the only place to answer it. It is greyed, and it
says why.

## v0.9.32

**Revoking a licence did not stop the device, and that was a weakness rather than a wait.**

The token on the phone stays valid by signature for a week, and the renewal call reported the
withdrawal without acting on it — so a revoked licence went on working until that week ran out.
Reported as exactly that: revoked it, still running.

**A definite answer is now acted on; only an absent one is ignored.** A `200` carrying `revoked` is
the server *deciding*, and a timeout or a captive portal is the server saying nothing — and the
code already separated those, because everything in this layer is built on that distinction. Only
the first reaches the branch that drops the stored token, so a café's wifi still cannot take a
paying user's licence away.

The effect: a withdrawal lands at the device's next check — within six hours normally, and
instantly with **Ask the server now**. Confirmed end to end: free week taken, revoked from the
panel, one sync, and the gate closed.

## v0.9.31

**A free week, a lifetime licence, and a screen worth deciding on.**

**The free week** is taken from the licence screen itself, once per device, and it starts the
moment it is taken. The server remembers that the week was spent in a record it never deletes —
the licence it created expires and can be replaced, but that marker has to outlive everything or
the trial is once a week rather than once a device. It also refuses a device that already holds a
licence: somebody who has paid pressing the free button by accident must not end up with seven
days.

**What the trial cannot promise, and the code says so where it is written:** the device id is a
random value the panel writes once, so wiping Albrhi's preferences produces a new id and a second
trial. There is no fix that does not involve a real device identifier — deliberately not used here,
for privacy and because it is not readable from every process. It is a convenience for honest
people, not a lock, and it is worth having as long as nobody mistakes it for one.

**Lifetime** is `until = 0`. Every date comparison in the licence layer was already written as
`until > 0 && …`, because a licence with no end was always a shape it had to survive — so this is
that shape given a name rather than a new branch through every check. The screen shows the word,
not a blank where a date would go.

**And the request screen is a card of ours, not an alert.** The `UIAlertController` it replaces
asked for a number of days in a grey box with Albrhi's name nowhere on it — the wrong shape twice
over, since an alert is for a decision and this is a choice between priced things, and it made the
one screen where somebody decides whether to pay look like an error dialog. The card prices five
choices, takes the free week in place, and writes the device code into the message itself: asking a
person to copy sixteen hex characters from one screen into another is where a purchase is lost.

A plan that cannot be reached is not drawn. The free week disappears once there is a licence, and
the paid rows do not appear at all in a build with no contact number — a button that opens nothing
is worse than no button, because the person has already decided to pay by the time they press it.

## v0.9.30

**The licence state and the term were blank on the device. The getter is not optional.**

A `PSTitleValueCell` asks its specifier for the value *through the get selector*. Setting the
`value` property and passing `get:NULL` reads like it should work and draws the title with an empty
space after it — so the row that says whether Albrhi is licensed said nothing at all, which on a
page whose whole job is answering that question is the worst possible row to lose.

**`SCIPanelRoot.m` had already found this, fixed it, and written it down in those exact words.**
This file was written the same way anyway. That is rule 23's shape again — a rule that lives only
in prose is a rule broken by whoever did not happen to read that file — so `tools/check.py` now
refuses the combination: a PSTitleValueCell built with `get:NULL` that then sets a `value`. Proved
by reintroducing the bug and watching it fail, then removing it and watching it pass.

Narrow on purpose: a title-only PSTitleValueCell is an ordinary row and there are three on the root
page. Only setting a value and giving nothing that can return it is the mistake.

## v0.9.29

**Two switches removed, and their absence is the feature: enforcement, and the server address.**

Both shipped for one release so the licence layer could be introduced before it was enforced —
the right order, and it was proved on a device that way. What that missed is *where a preference
lives*: in the panel, which ships to everybody. So every user had a control reading "turn licensing
off", and another that pointed the tweak at whatever server they liked.

**A gate with an off switch on the far side of it is not a gate.** Both are gone, and a device that
had already used them is not exempt — the stored values are ignored rather than read. Checked with
enforcement explicitly set to NO *and* the server preference pointed somewhere else: the gate holds
and the built-in address is used.

Worth saying about the second one, because it is the less obvious of the two: a swapped address
could never actually mint a working licence, since every token is verified against the public key
compiled into this binary. The worst it achieved was no licence at all. It comes out anyway — a
control that cannot help a user and can only confuse one is not worth the row it occupies. A
staging deployment sets the address at build time, which is where that decision belongs.

What stands in their place is a statement: **Albrhi — running**, or **stopped — no licence**. A
tweak standing down is indistinguishable from a broken install, and somebody has to be told which.

**Nobody is locked out.** The panel is a Settings bundle and never asks the gate, so the screen that
enters a licence is always reachable, and an offline key issued by `tools/licence.py` verifies with
no server and no network at all. The way back in is entering a licence — the only way back in that
is not also a way around.

## v0.9.28

**Albrhi's licence server is compiled in, so a request is sent rather than carried.**

Open Settings › Albrhi › Licence on a phone that has never been configured, tap **Request a
licence**, and it arrives in the seller's panel by itself. Before this the address had to be typed
in first — which meant every buyer had to be told a URL and get it right before they could even
ask, and that is a support thread rather than a purchase.

The address can still be overridden, for testing, for a staging deployment, or for anybody who
would rather run their own; the row says which of the two is in use, because "the built-in one"
and "one I chose" are different facts and only one of them is worth checking when something stops
working.

**A licence now renews itself.** The server signs for seven days and the tweak renews in the
background, so a withdrawn licence stops that device within a week without it ever having to fetch
a list — and a flight, a captive portal or a bad minute at the host costs nobody anything, because
six days of slack sit behind every renewal.

**The term and the renewal date are two different dates, and the screen shows the term.** Telling
somebody who bought a year that their licence expires in seven days is a support message the code
would have written itself.

Short codes are redeemed through the server too, and a code now binds to the first device that
uses it: passing it to a friend does nothing. Without a server reachable, redemption falls back to
the published list exactly as before.

## v0.9.27

**Albrhi now requires a licence.** Without a valid one the tweaks stand down: no hook is installed
and every app behaves exactly as if Albrhi were not there.

It shipped off for two releases on purpose, and that order was the point — introduce the layer,
prove it end to end on a real device (issued, entered, accepted, and refused again when the key
was removed), and only then turn it on. Introducing a gate and enforcing it in the same release
would have stopped every existing install on the next update, before a single key had been issued
to fix them with.

**Absent now reads as *on*, which is the opposite of the per-app switch, and deliberately so.**
That one reads absence as off because installing the suite must not silently modify four apps
nobody asked about. This one reads absence as on because the question is whether the software may
be used at all, and silence is not a licence.

**And a stopped Albrhi says why.** Standing down is indistinguishable from a broken install from
the outside: somebody whose YouTube stopped hiding ads thinks the tweak broke, not that their
licence lapsed — and every switch below would be showing ON while nothing happened, which is a
screen actively lying. So a row at the very top of Settings › Albrhi states it and taps straight
through to Licence, and the app list's own footer says those switches are not deciding anything
at the moment.

**Nobody can be locked out of the way back in.** This page is a Settings bundle and never asks the
gate, so enforcement can always be switched off from the same screen that turned it on.

## v0.9.26

**Two ways to get a licence without reading a device code down a phone line.**

**Request a licence** makes a short string carrying this device, the duration wanted and a name,
with a share sheet to send it. Nothing is transmitted by the tweak — you send it. It is
deliberately **not signed**: there is nothing on a phone to sign it with and nothing in it worth
forging, since it is a question and the person answering decides. The four characters on the end
are a *check* for a typo in transit, and they are called a check everywhere they appear so nobody
comes to read them as a signature.

**Enter a code** takes a short one like `ALB-4K7M-9QX2-P3RT` and binds it to this device. A code
that short cannot carry a signature, so the device hashes what was typed and looks that hash up in
a list published beside the source — the list holds **hashes, never codes**, so reading it hands
nobody a working code. This is the one moment in the whole licence layer that needs the network,
and it needs it once; afterwards the licence is local.

The alphabet has no I, L, O or U, and what a person types is folded back before hashing: `ALB-OA82…`
and `ALB-0A82…` are the same code, whichever way it was heard. Checked against the panel's own
minting — the device and the issuer agree byte for byte, across dashes, spaces, lower case and a
missing prefix.

**The clock starts at redemption, not at minting**, or a code sold in January and used in March
would quietly be two months short.

And five refusals rather than one: wrong shape, no such code, window closed, list unreadable, or
done. **"The list could not be read" is never reported as "no such code"** — telling somebody
their code is wrong because a café's wifi asked them to sign in is exactly the support message
this design exists to avoid.

## v0.9.25

**A Licence page: the device code to send, the key to enter, and the switch that turns the gate
on — which ships off.**

The device is named by a **derived fingerprint**, sixteen hex characters of SHA-256 over the
serial, the model and a fixed salt. It is stable across reinstalls and tweak updates, needs
nothing written to disk to compute, and cannot be turned back into a serial number by whoever
receives it. That was chosen over sending a real UDID on purpose, and the page says so.

A key is `ALB1.<payload>.<signature>` — ECDSA P-256 over SHA-256, verified against a public key
compiled into the binary, so it works with no internet at all. The payload is readable: a licence
the buyer can inspect is one the buyer can check.

**Three refusals, three sentences.** "expired", "issued to another device" and "not a key" need
different things done about them, and a single "invalid" makes somebody holding a perfectly good
key for their other phone think they were sold nothing.

**Enforcement is off and stays off until it is switched on here.** The source has been free for as
long as it has existed; a release that both introduced this layer and enforced it would stop every
install already out there on the next update, before a single key had been issued to fix them
with. With it off, `SCILicenseAllows()` answers yes unconditionally — verified rather than
assumed, against a build with no key stored at all.

And the page states plainly what this is: no check running on the user's own device can be made
unbreakable. What it buys is that most people do not crack anything, that removing it is real work
rather than one `if`, and — the part no client-side trick provides — that a key which turns up on
a forum can be withdrawn.

## v0.9.24

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

## v0.9.23

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

The bundle no longer links `PhotosUI` and `UniformTypeIdentifiers`. They were there for
`PHPickerViewController` — CarPlay's wallpaper picker — and CarPlay left this repository some
time ago; there is no `PHPicker` anywhere in the panel today. `shared/src/SCICPPrefsKeys.h` went
with them: fifty-six lines of CarPlay preference keys that not one file in the repository
imported.

## v0.9.22

Four things the panel could not do before.

**A master switch, above everything it governs.** When an app update breaks something, the answer
until now was eight switches or removing the package -- and that is the worst possible moment to
be hunting through rows. It is one value, read inside the call every tweak already makes, so no
tweak needed changing to obey it. **It defaults to on, and that is not the opt-in reading being
reversed**: the per-app switch answers "did anyone ask for this app to be patched", where silence
must not mean yes; this answers "has the user pulled the handle", where an absent value that read
as off would have switched off every working install on the day it shipped. With it off, the apps
footer says so -- a row that cannot act must not look as though it does.

**A guide page**, built from the device rather than from a list written into it: every tweak on
this phone, one line on what it does, the app version it was verified against, and the version
actually installed. A hand-maintained list of eight tweaks goes stale the first time one is added
or renamed, which this project has already paid for twice.

**A copy of your settings, out of the phone and back.** It goes out through the share sheet on
purpose -- a rootless or roothide prefix is removed with the bootstrap, so a backup written beside
the preferences it copies would be destroyed by exactly the event it exists for. **What it holds
is stated rather than implied**: the panel's own domain, which is the master switch and the
per-app switches. Each tweak's sub-options live inside that app's container where the Settings app
may not read, and a backup claiming "all your settings" would be quietly wrong about most of them.
A file that is not one of ours is refused whole rather than half-applied.

**And an update check, on a tap and never on its own.** A page that phones home when it opens is a
page that decided for its user. It asks Albrhi's own source and nothing else, takes the highest
published version rather than the first listed (the index carries several on purpose), and treats
"the source could not be reached" as a different answer from "you are up to date". A device with no
package manager to compare against is told the published version rather than a guess.

## v0.9.21

The clean-share-links switch is gone with the feature it named.

## v0.9.20

The Spotify page gains podcast and sharing sections: skip sponsored segments, and clean share links.

## v0.9.19

**A page is not what decides the section; being about one app is.** The Tweaks section exists for a
tweak that runs *across* apps — NextUp reads five media apps, Watch answers inside SpringBoard and
the Watch app — where an app row would have to pick one of them to be about. A tweak that patches
exactly one app belongs with the apps, whether or not it also wants a page: Albrhi for Spotify is
collapsed into a group only so it can carry two switches, and that is a fact about its settings, not
about what it patches.

Such a row **pushes to its page instead of carrying a switch**. Giving it both would be two controls
for one thing — the master already lives on the page, and a switch here would write
`app_enabled_<bundleid>`, which a tweak gated on its own master never reads. A switch that moves and
changes nothing is a failure this project has shipped once and does not intend to again.

## v0.9.18

**A grouped row that names exactly one app now carries that app's own icon.** The drawn badge exists
because a filter naming SpringBoard and Camera is one feature rather than two apps, and no icon can
be resolved from a tweak's group identifier. A filter naming one real app is the opposite case:
Albrhi for Spotify is collapsed only because it wants a page, and a music-note glyph where
Spotify's own mark belongs makes it the odd row in a list that is read by eye rather than by name.

Iconless and *no app to take an icon from* are two different conditions, and they are asked
separately now.

## v0.9.17

A page for Albrhi for Spotify: the master, the two ad switches, and — above them — what the tweak
does **not** do. The ad blocking is carried over from a tweak known for unlocking a paid
subscription, and somebody who installs this expecting that should read it on the page rather than
find out by trying to skip a track.

## v0.9.16

A switch for the watch's domain reading, off by default: it is a diagnostic that runs inside
SpringBoard, and the release that added it put a phone into safe mode.

## v0.9.15

The watchOS update row says what the hold actually does: watchOS 26 and newer, with the version read
from the update itself, older updates still offered, and an unreadable version let through.

## v0.9.14

The Watch report carries a nano-domains section: what NanoPreferencesSync actually holds on this
device, which is what the photo, music, apps and Maps features get written from. It is read on a
delay from a background queue, so its absence means "not yet" and the section says so.

## v0.9.13

**The Watch page says whether it is on, above the switches rather than only inside a report.**
Every row below the master is inert while it is off — no pairing answers, no update hold — and the
only place that said so was a diagnostics line at the bottom of a report somebody had to think to
copy. A page whose switches look live while nothing is installed costs a round trip to a device to
explain, and this one did.

The line is rebuilt when the master moves, since it states the value that just changed.

## v0.9.12

The Watch report no longer prints each process's header twice: the probe writes its own, and this
page was adding a second.

## v0.9.11

A restart button for the Watch app beside the one for SpringBoard: they are two processes, they
load Albrhi Watch separately, and the update hold lives entirely in the second — so a respring
reloads half of it. The footer now says what a device proved: a full userspace restart is what
applies a pairing change, and these buttons are the lesser version.

The Watch report is merged from both processes rather than one shared key, carries the update
hold's own verdict, and leads with what the Watch app announced about itself — whether it ran there
at all, and whether its own report survived being written from inside a sandbox.

## v0.9.7

**A tweak whose settings page is missing is now shown and explained, not hidden.**

0.9.4 skipped those rows outright, which was right for one of the two situations that produce them
and badly wrong for the other:

- The tweak is **gone** and its filter plist outlived the package — Albrhi CarPlay, removed from
  this repository, whose `AlbrhiCP.plist` still sits beside a dylib for anyone who installed it. A
  row there is a door drawn on a wall.
- The tweak is **newer than the panel**. Albrhi Watch ships as its own package while its page lives
  in this bundle, so installing the tweak before the suite update that carries the page is an
  ordinary sequence — **and hiding the row then tells somebody who just installed a tweak that it
  did not install.** Reported exactly that way, within an hour of the first release.

The second is the one people meet, and silence is the worst available answer to it. The row is
drawn, dimmed, and carries the reason: *installed, but its settings page is not — update Albrhi
from Sileo*. That sentence is also true of the first case, and costs nothing there.

## v0.9.6

**Albrhi Watch's page gains the update hold and the report.** The hold is a switch like the others;
the report is a button that copies what the tweak found inside SpringBoard and the Watch app —
which classes are present on this build and what their methods really look like. Those classes live
in the shared cache, which iOS 16 does not expose as a file, so asking them at runtime and copying
the answer out is the only way to read them.

## v0.9.5

**Albrhi Watch's settings page**, reached from its own row under the Tweaks section: the master
switch, the three answers it gives while pairing, and a restart button directly under them —
because those answers are installed while SpringBoard starts, so a switch moved here does nothing
until it restarts, and a page that hides that reports success while nothing has changed.

Its switches are written to `com.albrhi.watch`, the domain the tweak itself reads, rather than to
the panel's own. The panel's domain answers "may Albrhi act in this process at all"; a tweak's
switches belong where that tweak looks.

## v0.9.4

**Albrhi CarPlay's page left with the tweak**, which was removed from this repository to be rebuilt
in one of its own.

**And a row whose page is not in this build is no longer drawn.** The panel finds these rows from
filter plists on disk, and a filter outlives the package that installed it: anyone who installed
CarPlay from one of its old releases still has `AlbrhiCP.plist` beside a dylib, while the page it
names is gone. A `PSLinkCell` with a nil detail class is a row that answers a tap by doing nothing
— a door drawn on a wall. Asking the runtime whether the class exists costs one lookup and is the
only thing that knows.

## v0.9.3

**A diagnostic-log switch for Albrhi NextUp**, under a new Advanced section, off by default. The
tweak's own log stopped writing unless it is turned on (NextUp 0.1.4); this is where it is turned
on, with the path and the "turn it off afterwards" written on the row.

**And a row's default now travels on the row.** The page inferred it from the key —
`[key isEqualToString:@"Enabled"]` — which is a list of opt-in keys written as a comparison:
correct while there was one, and wrong the moment a second arrived. The log switch would have
defaulted *on*, which is the exact failure that switch exists to prevent.

## v0.9.2

**A section of its own for the tweaks that are not apps, each with a mark.**

The list mixed two kinds of row. An app row is a switch — "does Albrhi touch Instagram". A row for
Albrhi NextUp or Albrhi CarPlay pushes to a page and is not about an app at all: those run across
SpringBoard and five media apps, or SpringBoard and Camera. Sorted in among the apps they read as
apps this project patches, which is the same misreading `SCIPanelGroupIdentifier` was added to fix
one level down — it collapsed seven rows into one, and the one was still in the wrong list. They
now sit under the apps, under their own heading, and the split is made from what each entry
declares rather than from a list of names here, so the next tweak with a page lands correctly
without this file being edited.

**And those rows had no icon at all**, because the scan finds an app icon by bundle identifier and
a group identifier names a tweak rather than an app. They are drawn here now — an SF Symbol on a
coloured badge, keyed on the identifier the filter plist already declares rather than on the
displayed name, which is translated and would lose its icon in Arabic.

**The count above the list was wrong in both halves.** It read "N of M on" over a list of app
switches while counting rows that are not app switches: NextUp keeps its state in its own
preference domain and never touches the panel's key, so it counted as off forever *and* inflated
the total it was measured against. It counts apps now, which is what it sits above.

**Albrhi NextUp's page was rebuilt in this project's own identity.** A page reached from a list
has to say what it is for: it opens with the accent disc and the mark the tweaks use in their own
screens, the name, a line saying what the tweak does, and a pill stating whether it is doing
anything — which nine switches cannot say at a glance. Every switch carries its own badge, so the
row wanted is found before the reading starts. The pill is rebuilt when the master moves rather
than only when the page is reopened; a header that kept saying "On" over a switch that had just
been turned off is the screen-disagreeing-with-itself failure this page was fixed for once already.

**And each app row now says which build of that app it was written against** — YouTube 21.32.4,
YouTube Music 9.28.4, Spotify 9.1.62 — in the row it is about, on the same cell the root list uses
for exactly this. A provider reads one app version's private classes, so that number is not trivia:
it is what somebody checks first when a row goes blank after an app update. The section's footer
carries the one real difference between the apps, which no version number can state — YouTube has a
queue for a playlist or a mix, and for a standalone video it has none, so what is shown is YouTube's
own autoplay suggestion: playable, not skippable, and 16:9 rather than square.

The apps carry a symbol for what they play rather than a brand glyph: an app's own icon is not
this bundle's to draw, and an imitation that looks nearly right is worse than an honest symbol.

## v0.9.1

**The NextUp page showed its master switch as on while the tweak read it as off.**
Albrhi NextUp 0.1.1 made that switch opt-in — this repository's own rule that absence
reads as *off*, applied to a tweak that injects into SpringBoard and five media apps.
The page still defaulted it to on, which is worse than either default on its own: a
screen stating the opposite of what is happening.

Both halves of the page now use the same split — the master reads and publishes NO when
nothing is stored, every other switch keeps YES — because this page writes the live
notify token as well as the stored value, and publishing a different default than the
rows display would have put the two in disagreement before any value was ever saved.

## v0.9.0

**A settings page for Albrhi NextUp**, reached from the single row `SCIPanelScan`
collapses that tweak's seven-process filter down to — the second tweak to use the
grouped-row mechanism CarPlay introduced, and the first time it has served a tweak with
more than three switches: a master, three surfaces (Lock Screen, Dynamic Island, Control
Center) and five apps.

**It writes to the ported tweak's own preference domain, not the panel's.** Every other
page here writes to `com.albrhi.panel`; this one writes to `com.yves.nextup3` and
publishes that tweak's own `notify_state` token, because the reader compiled into
Albrhi NextUp has those names built in and is upstream's code kept unchanged. Rebranding
the domain would have produced a page whose switches all appear to work and change
nothing — the exact failure `SCIPanelGate.h` already documents from the other direction.

Both channels are written on every toggle: CFPreferences for the value that survives a
reboot, the notify token for the one that takes effect without a respring.

**A row's preference key travels on its own specifier.** Fifteen switches mapped back to
keys by a second `if` ladder is how a switch ends up writing the wrong preference; here
adding a row costs one line and nothing anywhere else.

## v0.8.1

**Settings crashed the moment the Albrhi page was opened.** 0.8.0's fault, and the fix is
one word.

The new row was registered by setting `cellClass` to the string `@"SCIPanelAppCell"`.
Preferences takes that property as a **Class** and sends class messages to it — so it sent
`+alloc` to an `NSString` instance, which does not answer it, and Settings died. The name
reads identically in the source and is a completely different kind of object.

Two more things went with it, both found by reading the file back rather than by anyone
hitting them:

- The cell forced `UITableViewCellStyleSubtitle` on its superclass to get
  `-detailTextLabel`, which it never used — it draws its own label. Overriding the style a
  `PSControlTableCell` was constructed with, for nothing.
- `-layoutSubviews` moved the title up by half the subtitle's height **relative to where the
  title already was**. That is only correct if it runs once; a visible row is laid out
  repeatedly, so it read a value it had written and moved it again, and the title would
  creep upward for as long as the row stayed on screen. Both frames are computed from the
  row's own centre now, which gives the same answer however many times it runs.

## v0.8.0

**One row per app, carrying everything.**

The page listed every app twice: once as a switch, and again in a Versions section stating
two version numbers. Two passes down the same list to answer one question about one app —
and the switch was in the first pass while the reason you might want to move it was in the
second.

Each app is one row now, with its icon, its name, and a line underneath saying which version
is on this phone and which one that tweak was last verified against. The Versions section is
gone; its explanation moved into the footer above, where it now describes something visible.

**Amber, not red**, when the app is newer than the tested build. That is a caution, not a
fault — the tested numbers are the newest builds the developer's own phone accepts, never a
compatibility ceiling, and colouring it red would claim a problem where there is only an
unknown. An app that is not installed says so on its own row instead of showing a dead
switch with no explanation.

The row is a `PSSwitchTableCell` subclass. Theos ships headers for both that and
`PSTableCell`, so the switch, its wiring and its enabled state keep working exactly as the
plain cell's did, and **no private property is guessed at** — the rule that keeps CarPlay's
microphone choice three switch cells instead of a private list picker.

Two things the layout had to be careful about, both recorded in the cell itself: the second
line is positioned against the title frame Preferences has already set rather than the
content view, because the title inset changes with the icon, the switch and the iOS version;
and the subtitle is the cell's own label rather than `-detailTextLabel`, which `PSTableCell`
restyles on every refresh.

## v0.7.0

**The panel says how much of Albrhi is actually on, before anything is read.**

The list already shows a switch per app, but knowing how much is patched meant counting
them — and since the switch became opt-in, a fresh install is a page of switches that are
all off with nothing saying so plainly. A pill beside the version now reads "2 of 5 on".

Green when anything is patched, plain grey when nothing is. **Not red**: none-on is a
deliberate and valid state here, not a fault, and colour is kept for what is actually wrong.

The count is taken when the header is built rather than cached, so it cannot disagree with
the switches under it — the page reloads its rows on every return, and a header holding its
own tally would show yesterday's answer. It reads through one shared accessor with the rows,
for the reason this project already learned the hard way: the same question is answered in
three places across two processes, and the third one was missed once.

## v0.6.7

**The CarPlay page now says to respring, not just reopen the app, after editing the
bridged-apps list or the master switch** — SpringBoard's own app-library cache is
what CarPlay 0.4.1 actually fixed, and it does not always re-evaluate an app just
because that app relaunched. The bridged-apps footer also names the exact identifier
format expected and the known "car or phone, not both" limitation for an app that
has not opted into running two windows at once.

## v0.6.6

**The CarPlay page can set a custom dashboard wallpaper.** A photo picker
(`PHPickerViewController` — no photo-library permission prompt needed, the modern
picker Apple built for exactly that) saves the chosen image for Albrhi CarPlay's new
wallpaper hook to pick up. Not validated on-device.

## v0.6.5

**The CarPlay settings page opened to a black screen.** Reported on-device: tapping
"Albrhi CarPlay" pushed a page with nothing on it. `-specifiers` was building the row
list and returning it, but never assigning it to the `_specifiers` ivar the way
`SCIPanelRoot.m`'s own root page already does — `PSListController`'s own plumbing
reads that ivar directly in places an override's return value never reaches, so a
subclass that only returns the array renders nothing. Assigned now, matching the
pattern the root page has used since it first worked.

## v0.6.4

**Albrhi CarPlay's settings page now has the app-bridging list.** A second dylib the
tweak gained in 0.3.0 has no row of its own — `SCIPanelHidden` in a filter plist now
tells the scan to skip it entirely rather than turning its framework-identity filter
into rows of its own, the same class of mistake `SCIPanelGroupIdentifier` fixed for a
different shape of it last release.

## v0.6.3

**A tweak can now declare a real settings page of its own, and CarPlay is the first
to.** Any filter that names a `SCIPanelDetailController` collapses to one row and pushes
to it instead of showing a switch — built because CarPlay's filter names two processes,
SpringBoard and Camera, which was showing up as two confusing rows, "Camera" and
"SpringBoard", as if they were separate apps this project patches. It is one "Albrhi
CarPlay" row now, and it opens the master switch, the recording-audio fix, a
microphone choice and verbose logging, all in one page.

## v0.6.2

Three faults found by reading 0.6.1 back rather than by anyone hitting them.

**The header could have laid itself out wrongly.** The logo and the version pill were
given sizes while they still carried their own automatic ones — a conflict that only went
unnoticed because the container happened to clear it two lines later. Depending on the
order of two lines to avoid a broken layout is exactly how this project's other settings
page died twice.

**The mark existed at one size only**, so a phone that is not the highest resolution had
nothing exact to draw. All three are there now.

**And the version could have read as unknown on some devices.** The installed version is
found by its stanza in dpkg's records, and the first stanza in that file has no line
break in front of it — so a device where Albrhi happened to be the first package
installed would never have been found, and would have shown the fallback instead. That
file is also a few megabytes, and it was being read twice every time the page laid itself
out; it is read once now.


## v0.6.1

**Four things reported from a phone, all of them real.**

**"Made by" was blank, and so was every other value on the page.** A row that shows a
fixed value still has to be *asked* for it — the value was set and no getter was given,
so Settings had nothing to ask and drew nothing. That is why the Versions rows looked
empty too.

**The version shown was the wrong number.** Someone who installed Albrhi 1.0.11 was
being told "v0.6.0" — the panel component's own version, which nothing on the device or
on the source ever called it. It now reads what dpkg records as installed, so the page
quotes the number you would quote back.

**The Versions section could disappear entirely.** It skipped any app whose version it
could not read, so a failed lookup produced no section at all — indistinguishable from
the feature not being there. Every installed app has a row now, reading "not known" when
it is not known, and the version is asked for under more than one name before giving up.

**A Respring button**, at the bottom, behind a confirmation. It asks the system for a
relaunch the way Settings itself does rather than trying to signal SpringBoard, and if
the device refuses it says so instead of appearing to do nothing.


## v0.6.0

**The page has a face now.** A header with the Albrhi mark, the name and the version
sits above the list, and the row in Settings carries the same icon — so the page is
recognisable from the moment you scroll past it rather than being an unlabelled list of
switches.

**Each app is shown with its own icon.** Instagram and YouTube are told apart before
their names are read, which is the whole job of an icon in a list.

**A Versions section.** Every tweak now declares, in its own filter file, the app
versions it was last verified against — and this shows that beside the version actually
on the phone. "410.1.0 · tested" when they agree, "412.0.0 · tested on 410, 439, 441"
when they do not.

Nothing is disabled on a mismatch and nothing here is pinned to a version number. A
newer app usually works fine; this exists so that when something *does* break, the one
fact that explains it is already on screen instead of taking a report to establish.

The declaration lives with each tweak rather than in a table here, because the tweak is
the only thing that knows what it was built against — a list in this panel would go
stale the first time one was retested and nobody came back to update it.

**The credit is at the bottom of the page**, with the licence and SoCuul's authorship of
SCInsta, which is a condition of using it rather than a courtesy.

## v0.5.0

Released without a changelog entry. It is the release that fixed the switch being
written correctly and read as nothing — see the suite's own notes for that.

## v0.4.0

**Rebuilt around what it is for.** The panel is Albrhi's own settings page and
nothing else.

- Every app Albrhi patches, with a switch each. Turn one off and Albrhi does nothing
  in that app, without uninstalling anything.
- Your settings are kept and come back when you turn it on again.
- Close and reopen the app for a change to take effect.
- An app you do not have installed is shown greyed rather than hidden, so it is
  clear why nothing is happening.
- The list is built from the tweaks actually installed, so a new Albrhi tweak shows
  up here without this page being changed.

**Removed:** listing other developers' tweaks, and the root helper that edited their
filter files. That was a different tool answering a question nobody asked, and a
setuid root program on your device for a feature nobody wanted is a risk with no
return. It is gone rather than switched off.

## v0.3.0

**Real per-app control.** Tap a tweak, see the apps it loads into, and switch it on
or off for each one. Switched off, the tweak is not loaded into that app at all —
this is the filter itself changing, not a setting being ignored.

- Works for **any** tweak on the device, not only Albrhi's.
- Only apps the tweak actually names are listed, so a tweak for social apps does not
  ask you about sixty apps it has nothing to do with.
- An app you switch off stays on the list, so you can switch it back on.
- The original list is copied aside before the first change is made.
- Respring for a change to take effect.
- If the switches are greyed out, the helper did not install correctly — reinstalling
  Albrhi Panel usually fixes it, and the page says so instead of failing quietly.

**Note:** reinstalling or updating a tweak restores its own list, so a change you
made here goes back. That is the package doing its job, not a fault.

## v0.2.0

**The switch.** 0.1.0 described your device and did nothing else.

- **Tap an app** to see what is loaded into it.
- **Turn Albrhi off for one app** without uninstalling anything. Your settings are
  kept and come back when you turn it on again.
- Close and reopen the app for a change to take effect. The panel says so when you
  flip the switch rather than leaving you to wonder.
- Tweaks by other developers are listed, and cannot be switched from here yet —
  that needs a part of the system this version does not touch.

## v0.1.0

**The first build. It reads only — it changes nothing on your device.**

- Adds a page to the iOS Settings app: **Settings › Albrhi Panel**.
- Lists every app a tweak is changing, and how many tweaks are in each.
- Lists every tweak on the device, and how many apps it reaches.
- Reads this from each tweak's own filter file, so it shows what really loads —
  not what a package says it does.
- Arabic and English.

Turning injection on and off per app, and importing tweaks from a file, come after
this one has been shown to describe a real device correctly.
