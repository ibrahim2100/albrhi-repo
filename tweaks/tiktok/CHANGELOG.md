# Albrhi for TikTok — what changed

## v0.20.3

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

## v0.20.2

**"Free" is out of every description.** The tweak needs a licence; a package page saying it is
free was the first thing anybody read. The licence itself is unchanged and still named in full —
GPLv3 where it applies, MIT for the Watch pairing core — because dropping a word is not the same
as dropping an obligation, and the attribution those licences require is not negotiable.

## v0.20.1

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

## v0.20.0

**The settings screen, rebuilt from nothing.**

What was there was a grouped table: a header view, a footer view, and forty rows drawn with
`UITableViewCellStyleSubtitle` under seven titles. It was correct and it was shaped like a form
from 2013 — and because every row used the same cell style, a switch, a link and a heading all
looked like the same thing.

It is a collection view now with **a layout per section**, which is the part a table cannot
express: the identity card is full width and sized to its own contents, the categories are a
two-column grid, and an option is a full-width card that grows with its note.

Three cell shapes, because there are three kinds of thing on this screen:

- **The identity card** — the mark, the name, the version, how many switches are on out of how
  many, and a red banner when Albrhi is switched off for TikTok in the panel, because the gate has
  the last word over every switch above it.
- **A category card** — its icon in a tinted well of its own colour, its name, and how many of its
  options are on. It presses in when touched, so a card that opens a page says so.
- **An option card** — icon, name, what it does, and the switch that does it, with a chevron
  instead of a switch when the row opens something.

**The identity is kept and nothing borrowed.** The mark is still the download arrow on an accent
disc — the same arrow as the button in the feed and the icon on the saving banner: three places,
one identity, and deliberately not TikTok's own music note.

**Removed on request:** saving a comment's media, and copying a comment without its author's name.
Both shipped in 0.19.14 and both are gone — the preferences, the rows, the strings and the hooks.

## v0.19.14

**Two things a long press on a comment can do now, and both live on one class the binary named.**

Forty `AWE*Comment*` classes were searched and none of them owned the comment menu. It is
`TTKCommentAppReviewsLongPressHelper` — under `TTK`, where TikTok has been moving things — and it
holds `-buildActionSheetForModel:index:`, `-copyCommentContent:` and `-addCopyActionToSheet:content:`
between them.

**Save media from a comment.** When a comment carries a picture, a sticker or an animated one, a
*Save* row appears in **TikTok's own long-press sheet** — built as an `AWEUserSheetAction` and handed
to the sheet's own `-addAction:`. Presenting a sheet of our own would have covered theirs, and
replacing theirs would have taken away Copy, Delete and Translate: a correct feature applied one
step further than it was asked for, which this project has done once already.

**Copy a comment without the name in front of it.** `-copyCommentContent:` runs first and what it
left on the pasteboard is trimmed afterwards. **A post-condition holds whatever the implementation
does** — the safer half of the same idea as hooking a setter rather than a getter — and it avoids
guessing what a private method's argument is. It is conservative: a leading `@handle` or `Name:` is
removed only when something remains after it, so a comment that *is* a mention keeps its text.

Both halves check their own selector's type encoding before installing, and each installs alone.

## v0.19.13

**The settings screen is a list of sections you open, not one long scroll.**

0.19.12 reorganised the *source* into seven files and left the screen exactly as it was — which is
what a report of "the settings didn't become options?" was about, and it was right: the plumbing
changed and nothing visible did. This is the visible half.

The root now shows one row per section — icon, name, and how many options are inside it, so the
list says what it is offering before it is opened — and a tap pushes that section onto its own
page. Forty switches under seven headings in one scroll became seven rows.

**One controller does both jobs.** A second class would have been a second copy of the row drawing,
the switch handling and the tint, all of which are already here and correct — and this project has
spent enough of this week on things that existed twice. The status pills and the footer stay at the
root, because they answer *is this working* on arrival rather than above every section.

## v0.19.12

**The video still repeated, and 0.19.11 had hooked an announcement rather than a decision.**

`-playerWillLoopPlaying:` is how the player *tells* the app it is about to loop, and roughly twenty
classes implement it — caption managers, view-count managers, danmaku, preload, clear-mode records.
Refusing one listener's copy of the news changes nothing about the news, which is precisely what a
device showed within minutes.

The decision is on TikTok's playback engine. `TTVideoEnginePlayer`, `TTVideoEngineOwnPlayer` and
`TTVideoEngineSYSAVPlayer` each own `looping` (`B16@0:8`) with `-setLooping:` (`v20@0:8B16`), and
`TTVideoEngineAdapter` carries the setter too. **Both ends are answered**, for a reason written down
twice in this project already — once for `-bypassOnesie` in the YouTube tweak, once for TikTok's own
watermark: code that reads an ivar directly never passes through a getter hook, while a stored value
is true for every reader. Each class is asked for its own encoding and installed separately, because
a build may carry any subset.

**And the settings screen is seven files instead of one array.** Every row of every section lived in
a 220-line literal inside one method: adding a feature meant editing the middle of a list, removing
one meant counting braces, and reading the seventh section meant scrolling past six. Each section
now registers itself from its own file under `Settings/Sections/` — the same idea the Instagram
tweak has used since it had three pages. Delete a file and its section is gone with nothing else to
change. **No parallel list decides what exists**, which is the fault this project met three times in
one week.

The keys a section is written in moved out of `SCITTStatus.m` with them: they were file-local
`static`s, which is exactly why a section could not live anywhere else.

## v0.19.11

Two features, both confirmed against **this project's own 46.4.0 binary** before a hook was written
— not against the reference tweak they were found in.

**Never appear online.** Four chokepoints on `AWEIMActivityStatusReportManager`, each with its type
encoding read first: `-p_enableReportOnlineStatus` and `-canFetchAsReportCurrentUserActivityStatus`
(`B16@0:8`) decide whether a report is worth sending, and `-p_reportActivityStatusWithParams:` and
its if-needed sibling (`v24@0:8@16`) are where one actually leaves the phone. Refusing all four is
the difference between *a report was suppressed once* and *there is nothing left to suppress*. Same
shape as the three privacy switches beside it: **a report is withheld from leaving, and the server
is never told anything untrue** — nothing here claims to be offline, it stops announcing.

**Do not repeat a video.** `AWEFeedCellViewController -playerWillLoopPlaying:` (`v24@0:8@16`), on
the class this tweak already holds for the model behind the download button — confirmed twice over.
**Not calling through is the whole feature, and it deliberately does not advance to the next clip**:
those are different requests, and this project has recorded what happens when a correct principle is
applied one step further than it was asked for.

Both rows are in the settings screen under Privacy and Extras, reached the same way as before.

## v0.19.10

The publish date appears on photo posts.

**The same fault as 0.19.1, arriving through the second door.** That release fixed a pending date
written on one path and read on four, and the fix was applied to the function that records a
video -- while a photo post deliberately does *not* go through it, because a list of pictures and
a list of alternative links to one file mean different things. Different meaning, different door,
and the date was left at the first one: every photo post built an item with no date at all.

**And reading it exposed a worse one behind it.** `+captureModel:` -- the model's own `-init`
path -- builds photo posts too and never set the pending date, so a photo post arriving that way
would have taken whatever date the last settled *video* left behind. Not a missing date, a
confidently wrong one. Both entry points now call one reader that clears the value before asking,
so a model that cannot answer leaves nothing rather than the previous answer.

**A value set in one place and consumed in two is only fixed when both consumers are found.**

## v0.19.9

The date is in the same place on every video now, not on the ones that happened to be ready.

**A position computed once is a position computed too early**, and that is exactly what "some are
perfect and some go back to the old spot" was. The geometry reads the download button's frame and
the view's window, and neither is settled at the moment the model is bound: on the rail path the
button is an *arranged* subview, so its frame is empty until the stack lays out, and a cell being
configured on its way onto the screen is not always in a window yet -- which skips the on-screen
clamp entirely. Cells that had already laid out when they were bound came out right; the rest kept
the old wrong position.

This project had written the same lesson down once already, about a constraint built from `bounds`
at construction time. **A measurement taken before the thing exists is not a smaller error; it is a
different number.** The label carries the button it belongs to and re-measures whenever it is laid
out or enters a window -- precisely when those two values become true -- and refuses to place
against a button that has no size yet rather than inventing one.

## v0.19.8

The date is centred on the download button and no longer runs off the right edge of the screen.

**One clamp, in the one space where the screen exists.** The rail sits hard against the right edge
and this label is wider than the button it centres on, so its right half wanted to be off the
display. The earlier attempt clamped into the rail's own bounds -- about 44pt, which cannot contain
a 150pt label at all -- and so pinned it to the rail's left edge on every device. A clamp into a
box narrower than the thing being placed is not a safety net; it is a guarantee of the wrong
position. The frame is converted into the window, pushed back by however much it overhangs, and
converted home: centred wherever there is room, sliding only as far as it must, and left centred
rather than clamped against a guess when there is no window to measure.

## v0.19.7

The publish date was one long row; it is two now, the date above and the time below it with the
word that joins them.

**That word is not "at" everywhere, and the label follows the phone's own locale on purpose.**
Writing the break as a literal `at` would hard-code English into a line an Arabic device renders
in Arabic. So the separator is measured rather than named: the combined string minus the date half
and minus the time half is whatever this locale puts between them. A locale that does not
decompose that way keeps the single combined line, which is what shipped before and is merely
long -- never a wrong word.

## v0.19.6

**The lean had a cause, and 0.19.5 had not found it.** `button.frame` is expressed in the
coordinates of the button's *own* superview, and this function was handed a `host` that on two of
its three call sites is a different view. So the rectangle was read in one space and drawn in
another, and the label leaned by exactly the offset between them — small on one phone, enough to
put the day outside the app on another.

**A rectangle only means something in the space it was measured in.** The label is anchored to the
button's superview now, whatever the caller passes.

**And the format is back as it was: the day, the month named, the year, and the time beneath.**
0.19.5 shortened it while fixing a position and nobody had asked for that. Changing what was not
reported is its own kind of regression, and the width the long form needs is the placement's
problem to solve rather than the format's — which it now does, by measuring the text and centring
the result on the button.

## v0.19.5

**Two phones showed the same build differently: centred on one, leaning so far left on the other
that the day was outside the app.** That is not a nudge to correct — it is a clamp that could only
ever have been wrong.

The label was forced to a fixed 96pt and then clamped into `host.bounds`, and the host is the
interaction rail, which is about 44pt wide. So `hostWidth - 96 - 2` was **negative**, the right-hand
clamp never ran, and the `x < 2` line shoved the label onto the rail's left edge on every pass. A
rail a few points wider leans a few points less, which is exactly what one phone against another
showed.

**A clamp into a box narrower than the thing being placed is not a safety net; it is a guarantee of
the wrong position.** The label is sized to its own text now and centred on the button — the one
rectangle this code owns and the only one that means the same thing on every device — and the rail
is told not to clip, so a label wider than it can overhang instead of losing its digits.

The format is short and drops the time: the long form plus a clock needed more width than the rail
has, which is why what survived on the narrower phone was the month and the year.

## v0.19.4

**Confirmed on a device: the date appears.** It sat below the button and read as offset to the
right, which is what centring a fixed width on a button living at the right edge of the screen
does — half the label wants to be off-screen, so what is visible looks pushed sideways.

It is above the button now, centred on it, and clamped to the host's bounds so it can never hang
off an edge. **Two lines, because the frame is one this code owns** — the whole reason the label was
put on the same host as the button rather than handed to one of TikTok's rails.

## v0.19.3

**`0 call(s)` was the diagnostic lying, not the code failing — and the fault is one this project has
now met three times.** The guard sat above the counter:

```objc
if (!host || !button) return;   // returns silently
sciDateCalls++;                 // never reached
```

So a function being called on every video reported never being called at all. **Before believing a
zero, check that the counter sits on the path that executes** — the same family as the watermark
counter on a setter this build never calls, and as the last-event snapshot that read as fresh proof
three reports running. Counted first now, with a nil host counted as its own outcome instead of
vanishing.

**And the real cause underneath it: the label was placed while the button was still being built.**
On the rail path the item is attached during construction — no superview, no frame — so the label
was positioned from a rectangle that does not exist yet, which is exactly what a constraint built
from `bounds` at construction time already cost this file once. It is placed where the button is
actually in the hierarchy now, beside the counter that says it was placed.

The base path had its host in scope all along and was being asked for `button.superview` instead.

## v0.19.2

**`0 call(s)` was the truth, and it named the fault in one line.** The date label was hooked into
the *cell* placement path, and on a real device the button is placed by the **rail** path — which
binds its item somewhere else entirely. Three sites bind an item to a button; the label followed one
of them.

It follows all three now, from the binding itself, which is the only truthful signal that a button
belongs to a video. **This is the same fault as the previous release's**, one week apart and in the
same feature: a value read on one of four routes, then a view attached on one of three. **Attached
on one path out of several is attached on none of the others**, and this file has now paid for it
twice.

**And the marker's key is confirmed rather than matched by shape.** The report came back reading
`marked: 1 via key text`, so `text` is tried first and the name-shape rule stays underneath as the
fallback for a build that renames it. A measurement that arrives and is not used is a round trip
spent for nothing.

## v0.19.1

**The date did not appear, and the cause was a pending value written on one path and read on four.**

`SCITTAddResolvedList` builds the item, and **four routes call it** — the settled-model video path,
the photo path, and two others. The publish date was set beside the item id inside one of them, so
every item built by the other three carried no date at all, and nothing was drawn. Worse, nothing
cleared it: a date read for one video could have arrived on an unrelated one.

It is read once now, at the single entry that holds the model, and **cleared first** so it cannot
leak. That is what this file already does correctly for the item id, and copying that shape rather
than inventing a second one is the whole fix.

**And "it did not appear" was true four ways**, which is why the report now counts each stage
separately: the placer not reached, the switch off, the item carrying no date, or the label drawn.
One number could not say which — the lesson the Watch tweak's stamp counters cost, and one this
file had already learned once as `raw → parsed → deduped`.

Two rows join the report: the publish date's stages, and the extras. A feature whose diagnostics are
computed and shown nowhere is one this project has shipped before.

## v0.19.0

**The publish date, under Albrhi's own button.** `AWEAwemeModel.createTime` is an `NSNumber` on
46.4.0 — confirmed against the real binary, not assumed — and the model is already in this tweak's
hands once per video, so the date is read there and carried on the item rather than fetched again
when a label is drawn.

**It is placed in a frame this code owns, which is the only reason it can be drawn at all.**
TikTok's rails rebuild their arranged subviews and sweep guests out; that is written down here at
the cost of a release. The label sits on the same host as the button, at a frame computed from the
button's, and is never handed to a stack. It is refreshed rather than recreated, because
`-configWithModel:` fires on every reuse and a label added each time is a pile of labels on one
cell — the recycled-cell lesson, applied before it could cost anything.

The date is formatted in the phone's own locale, so an Arabic device reads an Arabic date without
this file deciding what a date looks like.

**And the first attempt put the read in the wrong function.** `SCITTAddResolvedList` builds the item
and has no model in scope; this file already hands such values over as pending statics, the way the
item id and the origins are. The compiler said so immediately — what would have been worth avoiding
is inventing a second route for one value.

## v0.18.0

**Three features, and every class behind them confirmed against the real 46.4.0 binary before a
hook was written.**

- **More logged-in accounts.** `AWEUserService -maxLoginedAccounts` (`Q16@0:8`). Raised rather than
  removed: the app asks how many are allowed and something downstream sizes a list from the answer.
- **Messages the sender took back stay visible.** `TIMOMessage -recalled` (`B16@0:8`). TikTok had
  already delivered the message and then received an instruction to hide it; hiding is the client's
  own doing, and this refuses that instruction. Nothing is fetched back from a server.
- **A record of profile visitors**, kept as TikTok delivers them, so a block afterwards does not
  erase what already arrived. `TTKProfileViewsPresenter -model` (`@16@0:8`).

**The reference was read for architecture and immediately corrected by the binary.** VibeTok — read
for where to look, never for code, the line this project keeps for every unlicensed TikTok reference
— hooks `-isRecalled` on `TIMOMessage`. **That selector does not exist in 46.4.0 at all**: the
property is `recalled` and its getter is `-recalled`. A reference's selector is what worked for its
author, which is the same lesson `downloadAddr` and `bestURLtoDownload` already cost this tweak
twice. Every encoding here was also checked against 45.7.0, so these are stable across two builds
rather than true of one.

**TikTok's own visitor list is never modified, and that is a deliberate difference from the
reference.** It merges its cache back into the array the app is about to render, which is what makes
a blocked visitor appear in TikTok's own screen. Feeding objects the app did not create into a list
it is about to draw is the shape of thing that crashed the Watch app. Albrhi keeps its own record,
bounded at 200 entries, and shows it on its own screen — and the effect asked for survives, because
a visitor seen once is remembered.

**And a message that was taken back says so, rather than quietly staying.** The hook that hides the
recall is the only thing that knows one happened — `%orig` answers YES a moment before Albrhi
answers NO — so the fact is kept instead of swallowed, and the message is *marked* rather than
restored as though nothing occurred. A tweak that leaves no trace of what it decided is deciding on
the reader's behalf without saying so, which is the same objection this project raised about a watch
being told it was up to date.

`TIMOMessage -content` is `@16@0:8` and its declared type is `NSDictionary`. **Which key inside it
holds the visible text is documented nowhere this project can read**, and guessing at a name is what
`downloadAddr` and `bestURLtoDownload` already cost this tweak — so the rule is narrow and visible:
the first key whose own name contains "text", carrying a string. If nothing matches, **nothing is
marked**, and the report carries every key there was, so the next release can name it exactly. A
copy of the dictionary is returned; TikTok's own is never written through.

Each of the four installs on its own: a build missing one class must not cost the others.

## v0.17.7

**Measuring alone brought the watermark back, and the rule against that is already written in this
project's own notes.**

0.17.6 sorted every variant by measured bytes and downloaded the largest. The next report:
`userWatermarkedPhotoURL 1170×2080` — the watermark, at the identical size, because a watermarked
copy is the same picture re-encoded with something painted on it, and that is usually the **larger**
file. The measurement was correct and the outcome was worse.

CLAUDE.md says this about the video path, in these words: **size answers "which is bigger", never
"which is right"** — and every wrong-file report there has been a different property that size
cannot see: the audio track, the watermark, the codec. This is the fourth, one layer down, made by
the same hand that wrote the rule down.

**Kind decides first; bytes settle ties inside a kind.** Clean variants are ordered largest-first
among themselves, watermarked ones the same among themselves, and the clean list is walked first
whatever the sizes say. Only the accessor's name knows which is which — nothing measurable about
the bytes says whether a watermark is painted into them.

## v0.17.6

**A clean save at full size — and a report that could not prove it was the biggest one.**

The picture came back clean at 1170×2080, and the winning variant was named `thumbnailPhotoURL`.
That name is misleading here (TikTok's photo-mode "thumbnail" is a screen-sized render, not a
preview), but it is also not proof that nothing larger was readable: **the walk takes the first
variant that decodes, and "first" is a position in a list, not a size.**

The video side settled this same argument long ago by measuring rather than ranking names, and the
answer is the same here. For a single picture, every variant is `HEAD`-ed, the list is sorted
largest-first, and the download proceeds in that order. A link that refuses to be measured keeps
its place rather than sinking — refusing to answer is not evidence of being small, and this project
has already disabled a working feature by treating it as such.

**Only for a single picture.** An album of twenty-one at ten links each would be two hundred round
trips before the first byte is saved, and somebody who asked for all of them asked for all of them,
not for the best possible version of all of them.

**The save note now carries the pixels**, because that is the question a person actually has about
a saved picture, and a variant's name only answers it sideways: `originPhotoURL 1170×2080 · as
posted`.

## v0.17.5

**It saved — with a watermark — and the order asked for exactly that.**

The variant list read origin, owner-watermarked, user-watermarked, dynamic, … which was written
when only the *first* entry was ever used: whatever came second was a fallback nobody reached. Now
that the saver walks the list until something decodes, **the order is the decision** — and a post
whose original is an undecodable VVIC still fell straight through to the watermarked copy.

Every clean variant now comes before either watermarked one, the thumbnail included. A thumbnail is
small and this project's own rule says a preview is not a photo — but a watermark cannot be undone,
and a small clean copy is the one a person can still use.

**And a variant nobody was asking for.** `AWEPhotoAlbumPhoto` declares
`photoRankedURLModels : NSArray` — TikTok's own ranked list of the ways the picture is available,
read from the class's declared type rather than guessed. It is an array of URL models where every
other accessor answers with one, so both are walked the same way, and it sits second: a ranking the
app publishes is worth more than the order guessed here, while first place stays with the picture as
posted.

**The save now names the variant it used**, not just the method. "saved (as posted)" was equally
true of the watermarked copy, which is why a report saying "it saves, but with a watermark" had
nothing in it to confirm that. The accessor's name is the only thing that knows, and it travels in a
dictionary keyed by the link rather than a second array walked alongside — the parallel-array
mistake this project has already shipped once, when every label named the previous link's accessor.

**And the picture count read zero on a post that had just saved one.** It came from a KVC collection
operator over an array of arrays; it is `groups.count` now. Third time a diagnostic here has
disagreed with the thing it describes, and the rule keeps being the same one: read the number off
the object that holds it.

## v0.17.4

**TikTok has its own answer to the unreadable picture format, and it is a property on the very
object this tweak already holds.**

`AWEURLModel` declares `needReplaceVVICFormat` (`B16@0:8`) with `-setNeedReplaceVVICFormat:`
(`v20@0:8B16`), and the app carries a whole machinery around it — `p_shouldReplaceVVICFormat:`,
a `photomode_download_vvic_format_opt` setting, `public.vvic` and `video/vvic` types. Whatever a
guessed URL template might achieve, **this is the mechanism the app itself uses**, which makes it
the one to ask first. So each picture's URL model is asked with the flag set, and any links that
come back differ from the ones it gave before are added as candidates ahead of the guessed rewrites.

**The flag is put back before returning.** The model belongs to TikTok and drives what the app
requests for its own display; a borrowed value that is never given back is a change to the app's
behaviour outliving the save it was borrowed for.

Found by reading the app rather than the network: `MusicallyCore` also ships `libttheif` with a
`bytevc2_decoder`, which is how TikTok displays these stills at all — the decoder is inside the
process this tweak is injected into. That is worth knowing before anyone proposes shipping a VVC
decoder of our own: it would be several megabytes of C++ parsing network bytes inside TikTok, when
the app already has one and its own way of avoiding the format entirely.

The photo-chain row now says whether the replacement flag was there to ask.

## v0.17.3

**Photo saving broke on a format iOS cannot read, and the new diagnostic named it in one report:**

```
ISO media (vvic), 35059 bytes,
named …_photomode_vvic_vqe2_cae_v1~tplv-photomode-offline.image
tried: as posted only — nothing could decode it
```

`vvic` is a **VVC (H.266) still**. The phone has no decoder for it, so `UIImage` and `ImageIO` both
returned nothing and Photos refused the resource with `3302`. Nothing was wrong with the download,
the file name or the library: **that variant of the picture is unreadable here** — and the model
offers the same picture several other ways, which the resolver was throwing away.

**It kept the first link that answered and stopped.** `AWEPhotoAlbumPhoto` carries the picture as
posted, two watermarked copies, a dynamic one and a thumbnail; the loop took whichever answered
first and moved to the next picture. So a post whose first variant is VVC had nothing behind it.

Every variant is collected now, in preference order — as posted, then the watermarked copies, then
the thumbnail last, because saving a preview instead of a photo is the same class of mistake as
saving SD. The save fetches candidates in turn, **reads the bytes before offering them to Photos**,
and takes the first that decodes. A format with no decoder is the next link's turn, not an error to
stop on, and the report names every variant it tried and why each failed.

**And a rewrite of the CDN's own template, appended last.** Everything after `~` in a ByteDance
image URL is a processing template applied on the way out, so the same object can be asked for a
JPEG. That is a guess — so it sits after every link the model itself offered, it is decoded like
any other candidate before Photos sees it, and it costs nothing in privacy: same host, same object,
one suffix away. If the server ignores it, the attempt is a wasted request and the report says so.

The clip path (a picture plus the post's sound) walks the same list for the same reason.

The photo-chain row now reports how many links each picture has, which is the number that says
whether a failed save had anywhere left to go.

## v0.17.2

**The status report had become too heavy to read, which means it had stopped being a report.**
Three device reports in a row arrived as walls of text: two rows dump a whole class's method list
— several thousand characters each — and the four lines that mattered were buried inside them.

Both had already answered their question and kept answering it. The feed cell's list is what
proved that cell has no aweme accessor at all; `AWEVideoModel`'s is where `downloadNoWatermarkURL`
was found. So they are marked heavy: the screen shows how many entries each holds, the ordinary
**Copy** leaves them out and says how many it left out, and a second **Copy everything** sends the
lot for the day a class list is the question again.

Two texts, one list of rows — neither can miss a row the other has, which is the rule this screen
was built on.

## v0.17.1

**A first-run screen.** Everything this tweak adds is either invisible until you look for it — the
two-finger hold that opens the settings — or easy to mistake for TikTok's own, like the download
button in the rail. So it says both once, in the same dark blurred card the rest of the tweak is
drawn in, and then never again.

**Once ever, not once per version.** The stored value is the version that showed it, so a later
release *can* decide to say something if it genuinely needs to — but an ordinary update stays
silent. A screen that returns after every update is one people learn to dismiss without reading,
which costs the one time it mattered. Settings › Advanced has a row that brings it back.

It also says the one thing that otherwise reads as "the tweak is broken": when Albrhi's own panel
switch is off for TikTok, nothing here is patched, and the screen says so in orange rather than
leaving a fresh install looking dead. Shown only when it is actually off.

## v0.17.0

Confirmed on a device: the button sits above the profile picture on every video, photo posts save
the picture you are actually looking at, and a picture can now be saved as a short video with the
post's own sound over it.

**The button's position was three positions.** It was inserted "straight after the last interaction
view", with two fallbacks under that — and the rails genuinely differ from video to video (a like
counter, a live badge, a music disc each change how many `PlayInteraction*` views and anonymous
`TTKRightInteractionAreaBackgroundView` wrappers a rail holds), so those three code paths named
three different heights. It goes at index 0 now: the top of the stack is the one position that
needs nothing to be true about what is in it, and TikTok's own order puts the avatar first, so
index 0 is above the profile picture on every video. The anchor search and its fallback are deleted
rather than kept — a fallback here is a second position, and a second position was the bug.

Nudged five points right by a transform rather than a constraint, so the slot the stack measured
stays the size it measured. The press animation returns to that offset instead of to identity,
which would have quietly undone the nudge on the first tap.

**A new look for the button, shared with everything else this tweak draws:** a 38-point blurred
disc with a hairline edge and a bold `arrow.down`. The filled-circle glyph was TikTok's own idiom,
which made ours indistinguishable from like and share.

**Ask before liking, ask before following.** Two switches, both off by default, each hooking the
selectors both reference tweaks hook — with the type encodings read from *this* build's class
metadata rather than assumed: `-onLikeButtonClicked` (`v16@0:8`),
`-doubleTapLikeWithAnimation:` (`v24@0:8@16`), `-onFollowViewClicked:` (`v24@0:8@16`),
`-p_didTapFollowButton` (`v16@0:8`). `%orig` is never captured in a block: the confirmed action is
*replayed* — a flag is raised and the same selector re-sent — which also makes nesting safe, since
an inner call sees the flag and asks nothing. When there is nowhere to present the question, the
action happens: a confirmation that cannot be shown must not become a silent refusal.

**The tweak's own dialog, replacing `UIAlertController` everywhere it asks something.** Dark blurred
card, accent icon disc, 52-point rows, the answer filled in the accent colour. It is a view in the
key window rather than a presented view controller, so TikTok already having something on screen
cannot make a question fail.

**The settings screen was two screens interleaved.** Fourteen of its rows were diagnostics sitting
as peers of the six switches somebody opened it to change. The diagnostics moved to their own screen
under Advanced, and what is left is grouped by the question a person arrives with: Download,
Watching, Confirmations, Privacy, Protection. A row's preference key now travels on its own switch
instead of being mapped back by a second `if` ladder, and every row is described once rather than in
a row count plus two branches. The panel switch, when it is off, is a red banner at the top instead
of the first line of a section nobody scrolls to — it is the one fact that explains why nothing else
on the screen is doing anything.

**Photo posts: the picture you are on.** `AWEPhotoAlbumModel.currentIndex` is not the live index —
the class declares `initialIndex` beside it, which is the shape of a value set once. The paging
controller is what knows: `AWEPlayPhotoAlbumViewController -currentIndex` (`Q16@0:8`), reached
through the feed cell controller's `activePhotoAlbumController`. And it is read at the moment of the
tap rather than when the button was made, which also fixes a recycled cell handing over a video ago's
item.

**A picture plus the post's sound, saved as a video.** `AWEAwemeModel.music` → `AWEMusicModel.playURL`,
both read from class metadata. Written in two steps because neither API does both halves:
`AVAssetWriter` draws the still into a video track, then a composition lays the trimmed sound over it
and exports. The sound is optional in the export — a post whose music could not be fetched still
produces a saveable clip. A file's extension is how AVFoundation picks a parser, and TikTok's music
links carry none, so the first bytes name the container.

**Photos saving worked for the first time, and the fix was the file name.** A data resource carries
no type, so Photos infers one from the name — and the name came from the URL's last path component
with `.jpg` bolted on, which announced a WebP as a JPEG and earned `PHPhotosErrorDomain 3302`. The
bytes name themselves now. Pictures are also fetched through `NSURLSession` with browser headers
instead of `+dataWithContentsOfURL:`, which cannot report an HTTP status at all — a 403 page and a
photograph were both "some bytes".

**Diagnostics that describe one call.** The photo chain's report is committed only on a successful
extraction: it was being written by every model the resolver walks, so a single line was assembled
from several different calls and described nothing that ever happened. The page index is read off the
saved item rather than off a static that is reset constantly — the last report said "index unknown"
and "via activePhotoAlbumController.currentIndex" in the same sentence, which is a report disagreeing
with itself.

**The reference credits left the settings screen, on request.** TikTok's four references carry no
licence and nothing was copied from them; they are named in the repository and the changelog, which
is where that belongs. The Instagram tweak is the opposite case — its credit is a term of GPLv3 and
is not going anywhere.

Also: the seconds offered for a clip read "0 seconds" because `%.0f` reads a `double` and `5` written
as a literal is an `int` — the same family as the `objc_msgSend` casts that once crashed the app,
since a format string is a callee with types of its own.

## v0.16.2

**0.16.0's quality fix did not work, and the report says so plainly.** Reading `__playBSModel`
and its three siblings off the video model returned **one object each**, at the same low bitrate
`bitrateModels` already carries — `331,128`, not the `1,512,265` the player was offered. Each
deduplicated straight back into the existing ladder. The high-bitrate models are simply not on
the object this tweak holds, so there was nothing there to find and no third accessor to guess
at next.

The only place they have ever been observed is the argument of the player's own selection
method — the method whose hook crashed the app in 0.15.1, because its signature was invented
from its name.

**So this release takes the step that was skipped, on its own, with no hook and therefore no way
to crash:** `method_getTypeEncoding` on the real method, printed in Settings › Status. A hook can
then declare exactly that and stand down on any mismatch. `class_getInstanceMethod` returning
non-NULL proves a selector exists and says nothing about its types; that distinction is what
0.15.1 cost.

Nothing else changed. The reading is a single runtime query at launch.

## v0.16.1

**0.15.1's probe crashed TikTok repeatedly. The hook is gone.**

It hooked the player's selection method with a signature written from the selector name alone —
`(double)duration`, `(NSInteger)trategyType`, returning `id` — and none of that was read from the
runtime. A `%hook` whose argument types do not match the real method does not fail politely: the
arguments arrive in the wrong registers and of the wrong widths, and the process dies. It is the
same mistake as the guessed `long long` cast on `-bitRate` that crashed 0.12.0, made again in the
one file whose entire purpose was to stop guessing.

Nothing is lost by removing it. **The probe already answered its question** — `bitrateModels`
carries the same gear names at a quarter of the player's bitrate — and 0.16.0 acts on that by
reading `__playBSModel` from the video model this tweak already holds, which needs no hook at
all. The measurement was worth it; shipping it without checking the signature was not.

## v0.16.0

**The probe found it, and it is one cause for both complaints.** Put side by side on your
device, the ladder this tweak reads and the ladder TikTok hands its own player carry **the same
gear names at four times the bitrate**:

| gear | what `bitrateModels` says | what the player is offered |
|---|---|---|
| `adapt_lower_720_1` | 373,349 | **1,512,265** |
| `adapt_540_1` | 308,455 | **1,015,884** |
| `lower_540_1` | 197,536 | **584,415** |

So every download has been taking a *reduced copy of the correct gear* — a 720 at a quarter of
the bitrate the app plays. That is the picture and the sound at once, and it also disproves the
theory in 0.15.1: none of the player's gears carries a `selectedAudio`, so the audio is muxed
there too and simply follows the bitrate. The separate-audio-stream idea was wrong, and the
probe is what showed it rather than another release built on it.

The player's models live on `__playBSModel` and its siblings on the same video model this tweak
already holds, so they are now read first — from the same object, with no cross-video risk.
Each is a method rather than a declared property, so nothing states its type: every one is asked
behind `-respondsToSelector:` and accepted only if it looks like a gear list, meaning an array
whose members answer `playAddr`. If none does, the old ladder is used exactly as before.

## v0.15.1

**A measurement, not a fix — deliberately.** The report says the audio and the picture are both
noticeably worse than what the app plays, and there are two candidate explanations that would
lead to opposite changes. Two releases have already been spent acting on an inference a single
measurement would have settled, so this one only measures.

Two facts are behind it. Every gear this tweak has ever seen, across every report, is named
`lower` or `lowest` — not one `normal_720`, not one `adapt_higher_` — which is either the whole
ladder or a filtered subset. And each gear carries `selectedAudio`, a pointer to a *separate*
audio stream with its own bitrate and its own links, which is not the audio baked into the muxed
file the download takes.

So Settings › Status gains one line: what TikTok's own picker
(`AWEVideoPlayBitrateControler`) is handed, and which entry it chooses, with each gear's audio
bitrate beside it. If that list is larger than the one the download reads, the difference is the
answer. Nothing about downloading changed in this release.

Also confirmed again, from your own report: the outside service and `bitrateModels` resolved to the
*same file name*. That is the third independent confirmation that the external service returns
the file this tweak already downloads.

## v0.15.0

**The external HD service was being asked the wrong way, and the answer changes what the feature
is worth.**

`…/video/media/hdplay/<id>.mp4` is not an endpoint on its own — it answers 400 for an id the
service has not been asked about, which is exactly why it measured 0.0 MB in two reports and why
no `User-Agent` fixed it. It is an API: one JSON request names the links, and the shortcut only
works afterwards. That is what NA9's JSON parsing was for, and it was read here as decoration
first. The switch now makes the real request.

**And for the video from your own report, the external HD file is byte for byte the file this
tweak already downloads.** Queried directly: `wm_size` 8,399,664 — the watermarked copy this
build correctly refuses; `size` 4,567,673; and `hd_size` **3,786,622**, which is precisely the
3,786,622 bytes the tweak saved through `bitrateModels`. So for that video the external route is
not a better file. It is the same file, fetched by a route that also tells a third party what is
being watched.

The switch stays, off by default, because it was asked for and because other videos may differ —
but it is no longer sold as the thing that unlocks quality. When 720 is the ceiling, it is the
upload's ceiling.

## v0.14.5

**Ranking works — your report proved it.** The links measured 3.6, 3.0, 8.0 and 4.4 MB, and the
one taken was the 3.6 MB clean copy over the 8.0 MB watermarked one, saved at exactly 3,786,622
bytes. That is the intended behaviour and it is now confirmed rather than assumed.

**The external HD service refuses a request that does not look like a browser.** It answered
neither `HEAD` nor a range `GET` and measured 0.0 MB twice over, while the same address works in
a browser — and NA9 sets request headers and installs a redirect handler for the very same call,
which is evidence, not decoration. Measurements now carry a normal `User-Agent`.

**And switching that source on is a request for it, not a hint.** It was being outvoted by
whichever internal link happened to measure larger. When it answers at all it now ranks above
them; when it does not, it keeps its ordinary rank and loses on the merits, so a service that is
down costs the download nothing.

**"0 cleared" was a counter that did not count the path that runs.** Only the watermark setter
incremented, and on this build TikTok never calls it — the getter, which does the work, answered
silently. Working code reported as not working, which is the same failure as a tally that records
only the last event.

## v0.14.4

**A refused `HEAD` was sinking the very link you asked for.** Servers that will not answer a
`HEAD` scored zero and dropped to the bottom — which included the outside service, so switching the
external HD option on changed nothing, and included the quality ladder's own address. The size
is now asked a second way when the first fails: a one-byte range request is an ordinary `GET`,
so any server that serves the file answers it, and `Content-Range` carries the total.

**Every link was labelled with the previous link's accessor.** The origins list was searched by
value instead of walked in step, so inserting the external HD address at the front shifted every
label by one — the report stayed plausible while naming the wrong thing. The two arrays are now
grown, shrunk and read together.

**Photos: `UIImage` was the only decoder, and its failure disabled the fallback that existed for
exactly that case.** When it returns nil, the JPEG re-encode and the plain-image paths were both
skipped and only the untouched bytes were offered — which is why 3302 came back after "three"
attempts. `CGImageSourceCreateWithData` reads formats `UIImage` declines, so the re-encode is now
reachable whenever anything can read the file at all. And the error line names which attempts
actually ran instead of implying all of them did.

## v0.14.3

**Read both reference tweaks' actual hook tables and closed what they cover and we did not.**

The watermark is answered at **both** ends now — the setter and the getter — which is what NA9
does, and the reason holds: the setter covers every reader of a stored value, but a value TikTok
never sets keeps whatever it decoded from the response.

TikTok's own two download-permission flags are forced open. NA9 hooks `-canDownload` and
`-isPreventDownload`; **neither exists on this build**. The real names here are `preventDownload`
and `disableDownload`, read from the app's own class metadata — the fourth time in this tweak
that a working reference's selectors turned out not to be ours.

## v0.14.2

**"Largest wins" was stamping a watermark on every download, and no measurement could have
caught it.** `downloadURL` and `h264DownloadURL` are TikTok's *watermarked* save copies and are
usually the biggest files on offer, while `downloadNoWatermarkURL` and the quality ladder's own
address are clean. Nothing in the HTTP response says which is which — only the accessor the link
came from knows, so that name now travels with the link. A clean video outranks a watermarked
one whatever the sizes say; size still decides between equals, and a watermarked video still
beats a link that would not identify itself.

**And the watermark decision is answered at its source.** `AWEAwemeACLItem.watermarkType` — the
property TikTok itself consults, confirmed in this build's own class metadata — is forced to
zero at its setter rather than at a getter, because the app reads that value by more than one
path and a stored zero is true for all of them. Settings › Status reports whether it attached
and how many decisions it cleared.

**The music is no longer a candidate.** One report recorded the resolved link as an `.mp3` from
TikTok's music CDN. Ordering by type kept it out of the actual save, but it should never have
been on the list: it made the diagnostics describe the wrong file, and a URL that says `.mp3` in
its own address needs no request to disprove.

## v0.14.1

**Two faults, both introduced by 0.14.0 itself, both caught by its own new report.**

**The measurement picked the music.** One video offered an `.mp4` whose server refused `HEAD`
(measured 0.0 MB) and an `.mp3` of 0.9 MB — and "largest wins" took the audio. The type was in
the same response the size came from and was thrown away. Kind now decides before size: a link
that answers as audio never wins however much bigger it is, one that answers as video wins over
one that will not say, and size only settles ties between videos. Refusing to answer `HEAD` is
not evidence of being the wrong thing, so an unmeasurable link still outranks a known audio one.

**A photo post saved a video.** TikTok renders a photo slideshow as a video too, so the video
links resolved first and the tap never reached the picture branch. Pictures are checked first
now, the same order the other entry point already used: a post that has pictures is a photo
post, whatever else it also carries.

## v0.14.0

**Quality stops being a guess about names and becomes a measurement.** Your report showed the
ladder holding a single `comet_lowest_540_1` where an earlier one held five gears up to 720 —
TikTok only populates the gears it is currently streaming, so preferring the ladder takes the
worse file exactly when the app has not fetched the better one. Preferring
`downloadNoWatermarkURL` instead would be the same mistake pointing the other way. Every link
the video model offers is now collected — the best gear, the two download copies, the play
URL — and each is measured with a `HEAD` request before saving. The largest file wins, and
Settings › Status prints what each one measured and which was taken. A link that will not
answer scores zero and sinks to the bottom rather than being dropped: a server that refuses
`HEAD` still serves `GET`.

**And an optional HD path through an outside service, off by default.** NA9's HD button has
been reliable for years for a reason that is not cleverness — it never touches TikTok's model
chain at all, so there was never an internal accessor in that path to break. It asks
an outside service, keyed by the post id.

That is a real trade and it is written into the switch's own row: turning it on tells a service
unrelated to TikTok and unrelated to this tweak which video you are watching, which is the exact
thing the three privacy switches beside it exist to stop. It is off unless you turn it on, it is
never the quiet default, and with it on the external link is measured against the internal ones
like any other candidate rather than being trusted because it is external.

## v0.13.5

**`PHPhotosErrorDomain 3302` is Photos refusing the format, not the download.** It arrived for
two pictures that `UIImage` had already decoded perfectly well, which rules out bad bytes — and
the cause is that data handed to Photos carries no file name, so the library has to guess the
type, and TikTok serves these as WebP, which it will not take. That is also why one post saved
and another did not: the criterion was never how the post was found, only what format its
pictures happened to be in.

A picture is now tried three ways and the report names the one that worked:

1. **the original bytes, with their own file name** — the only path that saves the picture
   exactly as posted, with no re-encoding;
2. **re-encoded as JPEG**, if Photos refuses the format — a real loss in quality, and worth
   taking over saving nothing;
3. the plain image request, which is what worked before any of this.

## v0.13.4

**A photo post asks which picture you meant.** A post of sixteen saved all sixteen without a
word, which is not what tapping a download button on one picture means. Tapping now offers the
picture on screen or the whole post — and which one is on screen is read from
`AWEPhotoAlbumModel.currentIndex`, the app's own record of the swipe, not guessed from the view.
With nothing to present the question from, it saves the one on screen: a whole post arriving
unasked is the complaint, and the rest is one more tap away.

**And it shows the same progress the video save does.** Photos were saving correctly with
nothing on screen to say so — which looks exactly like a button that does nothing. The pie HUD
now advances per picture and ends with "Saved N of M".

**720 was TikTok's ceiling, not a bad pick — and the ladder proved it.** A device report listed
`adapt_lower_720_1` as the top of five gears, so the picker was already taking the best on
offer. The same report showed the three quality lists are identical on this build, printing the
same five gears three times; they are still all read, but the ladder is deduplicated so the row
can be read at a glance.

## v0.13.3

**The report and the settings table were built from two separate lists, and the row asked for
by name was in only one of them.** The gear ladder added in 0.13.2 appeared in the table and
never in the copyable report — so a report sent to be read for it could not contain it. Both
new rows are in both places now.

**Photo posts resolve; the save was failing silently.** "saved 0 of 1" collapsed three
unrelated causes into one number: the download failing, the bytes arriving and not decoding,
and Photos refusing the write. Each is counted separately now and the first real error message
is kept. TikTok serves these as WebP and HEIC, so when `UIImage` cannot decode the bytes they
are handed to Photos as the original resource instead — which also keeps the file exactly as
posted rather than re-encoding it.

**Quality compares three ladders, not one.** `AWEVideoModel` declares `bitrateModels`,
`SDRBitrateModels` and `HDRBitrateModels`; only the first was ever read. A gear missing from one
list is not a gear the app does not have. All three are gathered and compared together, and the
report names which list the winner came from.

## v0.13.2

**Photo posts: the wrapper was right and the list accessor was not.** A photo post in this build
is an `AWEPhotoAlbumModel` reached through `-photoAlbum`, and its list is called `photos` —
0.13.1 reached the album correctly and then asked it for `images`, which is the *other*
container's name, so every post read as empty for a second release. The elements are
`AWEPhotoAlbumPhoto`, whose picture-as-posted is `originPhotoURL`; the thumbnail is tried last,
because saving a preview instead of a photo is the same mistake as saving SD.

**Quality now reports the whole ladder, not just the pick.** A download coming out at 720 has
two completely different causes — the picker chose wrong, or 720 was everything TikTok offered
for that video — and the saved file looks identical either way. Settings › Status now lists
every gear the app was handed, each with its own `gearName` and bitrate, and marks the one
taken. That is a fact about one video on one account, so it is reported rather than reasoned
about.

## v0.13.1

**Both new features in 0.13.0 were one wrong name each, and the binary settled both.**

HD never ran. The entries in `-bitrateModels` are `AWEVideoBSModel`, and that class calls its
rate **`bitrate`**, all lowercase — 0.13.0 asked for `bitRate`, every entry answered
`-respondsToSelector:` with NO, every one scored zero, and the comparison fell through to the
ordinary chain. `bitRate` is a real name in this binary; it belongs to `TTKECVideoBitModel`,
which is nowhere near the feed. A name existing and a name being answered are different facts,
and this is the third release in this project to pay for confusing them.

Photo posts found nothing. `AWEAwemeModel` has no `imagePostInfo` at all in this build — it
answers `-images` itself — and its entries are `AWEImageModel`, which is not a URL model and
has no `displayImage`. The links are one level further in, under `lightURLModel` /
`localURLModel` / `darkURLModel`, each an `AWEURLModel` with `originURLList`.

Neither was guessed at this time. `tools/objc-classes.py` reads the class metadata out of
MusicallyCore and prints what a class actually answers, so "is this selector on this class" is
a question the binary answers in one command instead of a release.

## v0.13.0

Three things asked for by name: the progress bar, HD, and photo posts.

**A seek bar under every video.** TikTok has one — `AWEFeedPlayerBottomProgressBar` — and
hides it, showing it only while you are dragging. The switch keeps it on screen: `-setHidden:`
is answered with `NO` and `-setAlpha:` refuses to fade it to nothing, so nothing has to be
drawn and nothing has to be positioned. On by default, with its own switch under Controls
and its own line in Status — which distinguishes "not in this build" from "switched off"
from "working", since only the first is a reason to change any code.

**Photo posts save as photos.** They were being ignored entirely: a photo post has no
`-video`, so every download chain here reported failure and the button had nothing to offer.
The images come from `imagePostInfo` → `images`/`imageList` → `displayImage` →
`originURLList`/`urlList`, and they are saved one at a time, each as its own entry in Photos,
with the result reported as "saved N of M" rather than as a single yes or no — a post of
twelve images where two fail is not a failed download.

**HD, and why it took two attempts.** Downloads were SD because `downloadNoWatermarkURL` is
one link and `bitrateModels` is a list of alternatives — the right one is *chosen* by
comparing them, and nothing here had ever compared anything. 0.12.0 tried and crashed the app.
Both of that release's mistakes are fixed as measurements rather than as guesses:

- **The type of `-bitRate` is asked for, not assumed.** `property_getAttributes` returns the
  real encoding — `q`, `d`, `@"NSNumber"` — and the value is read through a cast that matches
  it. An encoding this does not recognise scores zero instead of being guessed at, so an
  unreadable variant simply loses and the download still happens.
- **The ladder is read when the model is finished, not while it is being built.** There are
  two entry points now: `+captureModel:`, called from the aweme model's own `-init` hooks
  where `-video` is half-built and only the shallow chains are safe, and
  `+captureSettledModel:`, called by the feed cell's button for a model the app has finished
  with and is currently showing. "Is this object safe to walk" is a fact about the caller, so
  it is a second entry point and not a flag a future caller could answer wrongly.

If the ladder gives nothing, the ordinary chain runs exactly as it did in 0.12.1. A crash is
worse than SD; that rule has not moved.

## v0.12.1

**0.12.0 crashed TikTok. Reverted.**

The HD picker is gone entirely rather than patched, and the tweak is back to 0.11.0's
behaviour: the button appears on every video, in place, and saves the clip you are watching —
at whatever quality `downloadNoWatermarkURL` gives.

Two things in that reader could crash and I did not guard either properly:

- `-bitRate`'s **return type was assumed.** It was read through `objc_msgSend` cast to
  `long long`. If that property is a `double`, a `float` or an `NSNumber *`, the cast is
  undefined behaviour — the value arrives in a different register or is a pointer read as an
  integer. Nothing in the binary told me which it was, and I did not check.
- It ran during **model construction**. Resolution is driven from the aweme model's own
  `-init`, where `-video` is a half-built object. This repository's own rule says a `@try`
  does not make that safe, and reading a list of sub-objects off a partially initialised
  model is exactly the case that rule is about.

**A crash is worse than SD**, and shipping the fix for a quality complaint at the cost of the
app opening is not a trade worth making. HD comes back when the type is confirmed and the read
happens somewhere the model is finished — not before.

## v0.12.0

**HD: the best gear is chosen by comparing bitrates, not by taking the first one listed.**

0.11.0 fixed the last correctness problem — `AWEFeedCellViewController.model` gives the video
you are actually watching, and downloads are real videos of the right clip. What was left was
quality, and `bitrateModels` had been sitting in the video model's accessor list untouched
through four releases of chasing single URLs.

**A chain of named accessors cannot answer this question.** Every other step in the resolver
walks a path and takes the first thing it finds. `bitrateModels` is a *list of alternatives*
and the right one is chosen by **comparing** them — taking `.firstObject`, which is what the
generic walker does, yields whichever gear TikTok happened to list first, and that is the SD
copy as often as not. So it gets its own reader.

Each entry carries `-bitRate`, `-gearName`, `-qualityType` and its own `-playAddr`, all four
confirmed in TikTok 46.4.0's binary. The highest `-bitRate` wins and its address is read the
same way every other URL model is.

It is tried **ahead of** `downloadNoWatermarkURL`, which 0.11.0 settled on: that one is correct
about the *watermark* and says nothing about the size. And it goes into the same candidate list
as everything else rather than short-circuiting, so the downloader can still reject it if the
file turns out not to be a video — being the highest bitrate on offer is not a promise about
what is inside.

The report names the winner with its bitrate, so the next one says outright whether HD was
found and at what rate — and the byte count says whether it mattered.

## v0.11.0

**The cell is a container. The model belongs to the view controller it hosts.**

Unfiltering the accessor dump answered it in its first line:
`viewController, feedTableViewCellMaskView, interactionConfigClass, pageContext, parentVC,
… setupViewController, layoutViewController, _addChildVC, vcContainerView`.

`AWEFeedViewTemplateCell` has **no aweme accessor of its own** — which is why every name tried
on it answered nothing, through two releases of trying more names. The video is the
controller's, not the cell's.

And this is what NA9 had been saying from the first symbol dump: it hooks
`AWEAwemeBaseViewController$viewDidLoad` and `$viewDidAppear`, **not** the cell. Its button
lives on the cell and its model comes from the controller — two facts that only made sense
together, and I had been reading them apart.

The model is now looked for on the cell first and then on whatever controller it hosts, and the
report names which object and which accessor answered.

**One thing this does not fix, and the report already names it:**
`Photos refused: PHPhotosErrorDomain error 3302`. The link resolves and the file downloads;
Photos then rejects it. That is a different failure from the earlier ones and worth its own
look — `isCDNURLExpired` and `cdnURLExpiredTime` sit on the video model, so an expired CDN link
returning an error page rather than a video is the first thing to rule out.

## v0.10.1

**0.10.0 hid the button. That was mine, and it is restored.**

0.10.0 refused to fall back to the most recent capture, on the reasoning that saving the wrong
video is worse than saving none. That reasoning is sound about the *save*. It was applied to the
*button*: no accessor answered on this build, so the item was nil on every layout pass and
`hidden` was set on every pass. **A correct principle enforced in the wrong place removed a
working feature outright** — 0.9.0's button was visible and saved a real video, just not always
the right one, and 0.10.0 traded that for nothing at all.

The button is always visible now. The cell's own model is used when it can be found and the most
recent capture stands in when it cannot, and **the report says which of the two supplied it**, so
"saved the wrong clip" and "saved nothing" never look the same again.

**And the accessor dump could not have answered the question it was asked.** Unfiltering it
exposed a second bug: the match loop added a name only from *inside* the keyword loop, so an
empty keyword list meant the body never ran and every class came back empty. Asking for "no
filter" produced "no results" — the opposite of what it reads as. An empty filter now means
everything, and a class with nothing to show says so plainly.

That matters because the filtered list had already told us something and it was missed: it
returned UIKit and accessibility categories containing "item" or "data" and **nothing about a
video at all.** `AWEFeedViewTemplateCell` has no aweme accessor of its own. The model is reached
another way, and the next report — unfiltered, for real this time — is what will show which.

## v0.10.0

**Downloads work, and now they save the video you are actually watching.**

0.9.0's report was the first to say `saved to Photos — 1 video / 1 audio track(s), 1561847
bytes`. A real video, with a real audio track, after five releases of saving 972 KB of sound.
`downloadNoWatermarkURL` was the answer.

But it saved the *same* clip three times while something else was on screen, because the button
took `[SCITTMedia recent].firstObject` — whatever model TikTok had most recently built. During a
scroll that is a video being **preloaded**, not the one under your finger. The button was
correct about *a* video and wrong about *which*, which is exactly the Instagram carousel bug
fixed earlier the same day: assuming instead of asking.

The cell is the thing that knows. It is asked for its own model now, through whichever of
`awemeModel` / `aweme` / `model` / `currentAweme` / `itemModel` / `cellModel` it answers —
each behind `-respondsToSelector:`, and **the one that answered is printed in the report**, so
it never has to be guessed at again. A candidate that does not answer `-video` is rejected: a
property sharing the name is not a model.

**There is no fallback to "the most recent anything".** Saving the wrong video is worse than
saving none — one is a missing feature, the other hands you someone else's clip and looks like
it worked.

**The button sits above the profile picture now**, clear of the whole rail rather than among
like and comment.

And the diagnostic was dumping the wrong class. It asked `AWEFeedViewCell` while the feed uses
`AWEFeedViewTemplateCell`, which is why that list came back full of accessibility and layout
internals with nothing resembling a model in it. Three reports printed it before anyone noticed
it described a different object.

## v0.9.0

**The button goes on the feed cell now, which is where the working tweak puts its own.**

Dumping NA9's Logos symbols named the technique outright:
`AWEFeedViewTemplateCell$na9AddDownloadButton`. **Not the interaction rail.** And every symptom
the rail placement produced follows from being a guest in someone else's stack:

- it appeared on some videos and not others, because TikTok rebuilds the rail's arranged
  subviews and sweeps a guest out;
- it drifted sideways, because a vertical stack positions each child by its own width;
- it needed its size copied from its neighbours — and those neighbours turned out to be
  invisible background containers, not icons.

A cell hook has none of those. `-layoutSubviews` on the cell fires for **every video the feed
shows**, so the button cannot be missing from some of them, and its frame is one this code owns
outright rather than a slot in someone else's arrangement.

`AWEFeedViewTemplateCell` was confirmed present in TikTok 46.4.0 from the app's own binary, not
taken on trust from NA9 — whose `AWEFeedViewTemplateNewCell` is **not** in this build. A
reference tweak's class list is a map, not a manifest.

**Both surfaces ship, and they cannot both draw.** The rail hooks stay so a build missing the
cell class still gets a button, but the rail stands down the moment a cell button exists — two
buttons on one video is worse than either alone. The report counts them separately, so the next
one says which surface is actually doing the work.

The frame is recomputed from the cell's bounds on every pass, never from its own previous
value. That is the drifting-title bug from the panel's new row, made earlier the same day, and
not worth making twice.

Nothing about the download changed. That is the next problem, and it has its own answer waiting
in the same symbol dump: NA9 does not resolve URLs at all — it calls TikTok's own
`downloadVideo` on the cell.

## v0.8.1

**Three releases were aimed at a line that had not changed because nothing had happened.**

"Last save attempt: no candidate was a video — audio only, 972317 bytes" appeared *identically*
— same byte count, same media id — in the v0.7.0, v0.7.1 and v0.8.0 reports. It was read each
time as fresh evidence that the newest chain had just saved audio. It was a **stale record**:
no new attempt had been made at all, because the button was in the wrong place to be tapped.

That record now states its own age. A line from before the current build was installed can no
longer be mistaken for the last thing that ran, and "nothing saved yet" says *this launch*.

**The button was still leaning right, and the reason was the fix.** 0.8.0 constrained its
width to `reference.bounds.size.width` — and **bounds are zero at that moment**: the button is
created and constrained before the rail has ever been laid out. The width fell through to its
fallback and came out a square narrower than every icon beside it. The height had the same bug,
hidden because its fallback of 44 happened to look deliberate.

Both dimensions are now tied to the sibling's **anchors**, which resolve at layout time
whatever the order of construction, so there is no moment at which a size can be read that
does not exist yet.

**And the rail report was conflating two stacks.** Both hooked stack views write into one
string, so "appended at end" and the rail contents printed beside it could come from different
objects — which is exactly how a report shows a rail containing `PlayInteractionLikeView`
while also saying the anchor search found nothing. The rail line now names which stack it
describes.

## v0.8.0

**The device printed `AWEVideoModel`'s own accessors, and that answered both open questions.**

`downloadAddr` — guessed at twice, once from NA9's binary and once from a framework-wide
selector dump — **is not on that class at all.** A selector list taken across 785 MB says a
name exists *somewhere*; it never says on what. One line from the device settled what two
rounds of reading binaries could not.

What is actually there:

```
downloadNoWatermarkURL   download quality, no watermark
downloadURL              download quality
h264DownloadURL          codec-named download
bitrateModels            the HD ladder (plus HDR/SDR variants)
audioBitrateModels       a separate audio ladder
playURL                  the streaming URL — what this tweak had been using
playLowBitURL            named for exactly what it is
```

`downloadNoWatermarkURL` and `downloadURL` now lead the chain. `playURL` stays as a
fallback, where it belongs: it is what the app *streams*.

And `audioBitrateModels` sitting right beside the video ones is the shape of the
"972317 bytes of `audio/mp4`" this kept saving — the model carries separate audio lists, so a
URL chosen without regard to which list it came from can easily be the sound.

**The button leaning far to the right was a sizing bug, not a placement one.** Only its
height was matched to the rail. A vertical stack whose alignment is not `.fill` positions each
arranged subview by its own width, so a button sized from its glyph sat at a different
horizontal offset from every icon around it. Both dimensions now come from a sibling, and the
glyph is centred inside them.

Still open: the button appearing on some videos and not others. `2 placed` against 164 feed
items seen, and the rail is rebuilt per cell — but that is being left to a measurement rather
than a third guess.

## v0.7.1

**The button was being placed between two background views.** A device report dumped what
the rail actually holds:

```
TTKRightInteractionAreaBackgroundView | TikTokFeedInteractionBiz.PlayInteractionLikeView
| TTKRightInteractionAreaBackgroundView x4
```

Most of that rail is **not buttons**. The interactive elements are `PlayInteraction*` views
(Swift, module `TikTokFeedInteractionBiz`); the rest are background containers. Inserting
"one before last" therefore dropped the save button between two backgrounds — which is
precisely the "not centred, not aligned with the icons" that was reported, and no amount of
sizing could have fixed it, because the neighbours it was sized against are not icons.

It is now inserted directly after the last view whose class names an interaction. A rail with
none keeps the old behaviour rather than getting a newly invented one.

**And the audio problem gets measured rather than guessed at a second time.** The report says
resolution succeeds via `AWEVideoModel.playURL.originURLList` *and* that the saved file is
972317 bytes of `audio/mp4`. Both are true, which means the link that resolves is not the
video. Every accessor list in this report so far belongs to the **aweme** model — the video
model's own has never been printed, and that is the list that would name the right URL.

TikTok 46.4.0's framework does contain `downloadAddr`, `playAddr`, `playAddrH264`,
`bitrateModels`, `HDRBitrateModels` and `SDRBitrateModels`; a selector dump is global, so it
cannot say which are on `AWEVideoModel`. Trying `downloadAddr` first was the obvious guess and
it did not win. So Diagnostics now prints `AWEVideoModel`'s own URL-bearing accessors, and the
next report answers it outright.

## v0.7.0

**The download chain was mostly dead, and the app's own binary said so.**

The owner supplied the full TikTok 46.4.0 IPA — decrypted, `cryptid 0`. TikTok's classes are
not in its executable (91 KB), the same way X's are not in X's: they live in
`MusicallyCore.framework`, 785 MB and **1,032,816 selectors**. Dumping `__objc_methname` out
of it settled in one pass what three releases of guessing could not.

**Three assumptions died:**

- **`bestURLtoDownload` is not in this build at all** — and it was the first choice of nearly
  every chain in this file. Seven chains have therefore been dead for as long as they have
  existed, skipped silently, because a chain whose selector is absent looks exactly like a
  chain that was tried and found nothing.
- **`bitratePlayURL` is not there either** — which 0.6.2 added an hour earlier as *the* HD
  fix, taken from NA9's binary. NA9 was built against an older TikTok. Reading a working
  tweak's selectors is not confirming they exist in your build; that is precisely the trap
  the X tweak's dead immersive class was, made twice in one day.
- `bestURLtoDownloadFormat` and `downloadHDVideo:`, from the same source, are absent too.

**What actually exists is a real quality ladder, and "it saves SD" was one word all along:**

```
video.downloadAddr    the DOWNLOAD address
video.playAddrH264    codec-named playback address
video.playAddr        generic playback address
```

`playAddr` is what the app *streams*, served at a bitrate chosen for smooth playback.
`downloadAddr` is what TikTok serves for saving. Nothing in this file had ever asked for it.
Each ends in a URL model whose confirmed accessors are `originURLList`, `urlList` and
`URLList` — never `bestURLtoDownload`.

Also confirmed present and worth a later release: `bitrateModels` (variants carrying
`-bitRate`, `-gearName`, `-qualityType` and their own `-playAddr`), `HDRBitrateModels`,
`SDRBitrateModels`, and `allowDownloadWithoutWatermark`.

Still **not** fixed, and named so they are not read as done: the button appearing on some
videos and not others, and the wrong video being saved.

## v0.6.2

**A one-letter bug, and the first real attempt at HD.**

A live property dump from a device settled both.

**`downloadInfoModel` has a capital I.** Two candidate chains have read
`downloadinfoModel` for as long as they have existed. Selectors are case-sensitive, so
`-respondsToSelector:` answered NO every time and the chain moved past the one object on the
model whose entire purpose is download information — silently, because a skipped chain looks
exactly like a chain that was tried and had nothing.

**`playURL` is the playback URL, which is why downloads came out SD.** It is what the app
streams from, served at a bitrate chosen for smooth playback rather than for the best copy.
NA9's binary carries `bitratePlayURL`, `bestURLtoDownloadFormat` and `downloadHDVideo:` —
**none of which this chain had ever asked for.** `bitratePlayURL` names a *set* of variants
rather than one stream, and is now tried ahead of `playURL`.

**Which entry of that set is the best one is not yet known.** The array picker takes the
first, as it does everywhere in this file, and the diagnostics line naming the resolved chain
is what will say whether this is the HD copy or just a different one. Measure, then choose.

Also corrected: a comment claiming `-playURIString` and `-URLList` are "gone". They are
not — the device dump lists both. They were dropped for resolving the song rather than the
video, which is a different fact and worth stating as the true one.

Two known problems are **not** addressed here and are named so they are not mistaken for
fixed: the button appearing on some videos and not others, which has the signature of the
arranged-subview rebuild that cost the X tweak five releases; and the wrong video being
saved, which is the same shape as the Instagram carousel bug — resolving from a remembered
model instead of asking which cell is on screen.

## v0.6.1

Asked directly how the two reference tweaks pin their own button. The answer is short
and it explains both remaining complaints.

**What they hook on the rail:**

| | NA9 | VibeTok |
|---|---|---|
| `-layoutSubviews` | yes | yes |
| `-didMoveToWindow` | yes | — |
| `-setHidden:` | **yes** | — |
| `-setAlpha:` | **yes** | — |

`-setHidden:` and `-setAlpha:` are the two this project never had, and a tweak has no
reason to hook them unless its button's visibility must be **kept in step with the
rail's own**. TikTok hides and fades that rail constantly — while a comment sheet is
open, during a long-press, whenever the UI gets out of the video's way. A button that
does not follow those transitions is one that is sometimes there and sometimes not for
no reason the user can see. That is the "doesn't show on every video" report: it was
never a placement failure, it was the app's own behaviour going unmirrored. Both are
hooked now, propagating hidden/alpha onto the button on every change.

**And the tilt was a sizing bug, not a centring one — which is why three attempts at
the centring never touched it.** v0.5.0 moved the glyph out of the button's own `image`
into a subview held only by `centerXAnchor`/`centerYAnchor`. That leaves the button with
**no intrinsic content size at all**, so in a stack whose alignment is not `fill` it is
laid out at zero width — and a glyph centred on a zero-width button hangs off the edge
of it. The glyph is now pinned to all four of the button's edges instead, which gives
the button the image's own intrinsic size and makes it measure correctly under any
alignment, with `UIViewContentModeCenter` keeping the artwork unstretched.

## v0.6.0

**The rail's own contents, printed by v0.5.3's new report, settled the placement
question by proving my own last fix impossible:**

```
TTKRightInteractionAreaBackgroundView | TikTokFeedInteractionBiz.PlayInteractionLikeView
| TTKRightInteractionAreaBackgroundView ×4
```

TikTok wraps every icon except like in the *same* generically-named background view. No
icon but like can be identified by class name at all, so v0.5.3's "find the one whose
name mentions share" always failed and always fell through to appending at the very end
— below the music disc, which is exactly what "way below the picture" was describing.
That was a regression this file introduced; the index arithmetic it replaced was closer
to right. Placement is one position before the end again, the button's height is now
matched to a sibling's own measured height rather than a number picked here, and the
assumption about rail order is printed in the report rather than buried in code.

**Audio is no longer an outcome — it is a rejected candidate.** This is the real fix for
"saved as audio". The resolver used to stop at the first chain that answered and keep
one URL; `originURLList` answers reliably and answers with the *sound's* link, so there
was nothing to fall back to and the same 972317-byte `audio/mp4` file was saved release
after release. Now **every** chain is run and every http(s) link it produces is kept on
the item. The downloader fetches them in turn and only accepts one whose downloaded file
actually carries a video track — the file itself deciding, the same standard v0.4.12
established. An audio-only file, a non-2xx status, an unplayable body, or a failed
transfer each mean "wrong candidate, try the next" instead of "done, here is a song".
Only when every candidate has been fetched and none had a video track does it give up,
naming every link it rejected and why.

**Also recorded, and still outstanding:** the button reads
`[SCITTMedia recent].firstObject` — the most recently resolved link, which during a
scroll belongs to a prefetched neighbour rather than the video on screen. `AWEFeedViewCell`
was dumped for a model accessor to fix this properly and came back with nothing usable —
only UIKit and framework-category internals (`_focusItemDeferralMode`, `nsli_superitem`,
`ttket_dataProvider`…), no `model`/`aweme`/`item` of TikTok's own. That cell holds its
model somewhere this dump does not reach, and the next attempt has to go at it from a
different angle rather than a fifth keyword guess.

## v0.5.3

`972317 bytes` — the *exact* same byte count as three releases ago, with the winning
chain now reported as `video.playURL.originURLList`. An identical file from a
differently-named chain means the chain name was never the useful fact, and this
release stops guessing on three separate fronts by recording what was actually
happening instead.

**The resolved link is now in the report.** Every version of this diagnostic named which
*selectors* answered and never once what they answered *with*. Host plus last path
component is enough to tell a music CDN from a video CDN at a glance — and truncated
deliberately, so a signed account-scoped URL does not end up in a pasted report.

**The button's real design flaw, stated plainly.** It saves
`[SCITTMedia recent].firstObject` — whichever URL was resolved *most recently*. During a
scroll that is a prefetched neighbour several videos ahead, not the video on screen.
That single fact explains both remaining complaints at once: it downloads the wrong
thing, and it appears unevenly because it appears only when *something* has resolved
recently. Fixing it needs the cell's own model accessor, which no reference tweak names
because neither hooks `AWEFeedViewCell` — so a new Status row dumps that class's own
`model`/`aweme`/`item`/`data` accessors from the live runtime, the same way the aweme
model's were found. The next report names the accessor; the release after this one binds
to it.

**The button is now placed by finding share, not by counting from the end.** "Second
from last" assumed TikTok's rail ends with its music disc — an assumption about a layout
this project had never actually read, and it put the button in the wrong place twice. The
siblings' class names were available the whole time: the one whose name mentions share is
the one to sit under. The rail's full contents are recorded in the report either way, so a
build whose naming does not match says so instead of landing somewhere odd.

## v0.5.2

**VibeTok does have a download feature, and reading only NA9 is what kept this
broken.** An earlier pass concluded VibeTok had none — it does: a whole
`MSGDownloadSettingsViewController`, "Download video", "Download audio",
`PHAssetCreationRequest`, a `download_HD_Video` preference. And crucially it reaches the
link through **different selector names than NA9 uses for the same job**:

| selector | NA9 sends | VibeTok sends |
|---|---|---|
| `playURL` | yes | — |
| `h264DownloadURL` | — | **yes** |
| `playURLList` | — | **yes** |
| `bestURLtoDownload` | yes | — |
| `originURL` | yes | — |
| `originUrl` | — | **yes** (note the casing) |
| `originURLList` | **yes** | **yes** |
| `urlList` | — | **yes** |

All of those are `_objc_msgSend$…` stub symbols — emitted only for a selector the
compiler saw actually being sent, which is a far higher bar than a name appearing
somewhere as a string. `originURLList` is the only one **both** tweaks send, so it is
now tried early on every container. `h264DownloadURL` is VibeTok's own path and its
name says exactly what this feature wants: a download link rather than a streaming
address.

**Two names this file had invented are gone.** `-h264URL` and `-downloadURL` were
guesses from an earlier release; neither tweak sends them and neither binary carries
them as strings at all. Same for the ranking of `-playAddr`/`-bitratePlayAddr` — strings
only, never sent, so they stay last rather than second.

## v0.5.1

**The Download list is gone from the settings screen, on request.** It was a list of
bare timestamps with a Save button each — a debugging aid wearing a feature's clothes.
Nobody picks a video out of thirty unlabelled rows they cannot see; the in-feed button
beside share is the whole interface, and a second, worse way to do the same thing only
made the screen look unfinished. `SCITTMedia` still keeps its recent list because the
button reads from it; it just has no UI of its own any more.

**Two more confirmed ways out of an `AWEURLModel`, from a third pass over NA9's binary.**
`_objc_msgSend$originURL` and `_objc_msgSend$originURLList` are both present as stub
symbols — which the compiler emits only for a selector it actually saw being sent — so
they meet exactly the same bar `-bestURLtoDownload` does, and all three are now tried
in turn. That same pass also settled something the other way: `-playAddr` and
`-bitratePlayAddr` are **not** sent anywhere in that binary. They appear only as plain
strings, which is dictionary-key territory, so they now sit after the three confirmed
selectors rather than in front of them.

**And a finding deliberately not built.** NA9's download does not resolve a link from
the app at all for its HD path — it fetches
an HD link from a third-party scraper service,
keyed by the video's own ID. That is why its button has worked unchanged for years: it
never depended on TikTok's internal model chain. It is not reproduced here, and the
reason is the same line this project already drew at `app_attest_*` in the X tweak and
at Check0verPlus in Locket: it would send what the user is watching to an unrelated
third party, inside a tweak whose neighbouring feature exists specifically to stop
watch activity being reported to servers. The owner can have it if they ask for it
knowing that; it will not arrive quietly.

## v0.5.0

**The 288 "successful" resolutions were all the song, not the video, and the file's own
track list is what finally said so.** `-URLList` on `AWEAwemeModel` resolved 288 times
out of 706 — and the file it produced was 972 KB of `audio/mp4` with no video track at
all. It is the *sound's* URL list. Every save reporting "sound saved" was that chain
being confidently, consistently wrong; v0.4.12's AVFoundation check is what turned an
invisible wrong answer into a measurable one. `-URLList` and `-playURIString` are both
removed rather than reordered: a chain that reliably resolves the wrong media is worse
than one that resolves nothing.

**The link comes from `AWEVideoModel`, caught at its own construction.** Every attempt
so far went through the aweme model, and `AWEAwemeModel -video` is nil for the
overwhelming majority of models at the moment they are built — a retry timer only
partly papered over that. `AWEVideoModel` is confirmed real by the reports themselves
(one said `"AWEVideoModel has no -playAddr"`, which only a real class can say; another
said `video.playURL` ended `"at AWEURLModel"`, one hop short of that class's own
doubly-confirmed `-bestURLtoDownload`). A new file, `SCITTCapture.x`, hooks
`AWEVideoModel -init`/`-initWithDictionary:error:` and resolves
`playURL.bestURLtoDownload` from it directly — by the time that object exists, the play
URL is what it was built to carry, so there is nothing to wait for. `%orig` runs first
and the return value is never altered; this reads, it does not filter.

**The button's glyph is no longer the button's image.** A plain image button was tried
three ways and read tilted every time: `contentEdgeInsets` and
`contentHorizontalAlignment` are reinterpreted by `UIButtonConfiguration` on iOS 15+
whether one was asked for or not, and a fixed width fought the stack's own fill
alignment. The glyph is now a separate `UIImageView` centred inside the button by this
file's own `centerXAnchor`/`centerYAnchor` constraints — which nothing in `UIButton`'s
internal layout or in the stack's alignment can reinterpret. It sits in the middle by
construction rather than by an alignment property holding.

## v0.4.12

**"Sound saved" was never a failure message — it was the audio branch succeeding on a
file that is actually a video.** Two releases guessed at a file's kind from its name:
first the response's MIME type, then the URL's own path extension. Both were wrong on a
real device, and both were guesses about a file that was already sitting on disk and
could simply have been asked.

`AVURLAsset` now reads the downloaded file's own track list, and *that* decides:
a video track present means Photos, no video track and an audio track present means
the Documents folder, and neither means the file is not playable media at all — an
error page, a truncated transfer, an HTML redirect that answered 200 — which is now
reported as such rather than handed to Photos to be refused for unrelated-sounding
reasons.

This is this project's own ground rule applied to a file instead of an object: *"a
non-nil object is not a working object; check that a thing can actually do its job, not
that it is non-null."* An extension on a URL that may carry query parameters, no path
segment at all, or a CDN's own naming scheme is exactly the kind of proxy that rule
exists to rule out. The "Last save attempt" row now reports the actual track counts and
byte size alongside the outcome, so the next report is a measurement rather than an
inference.

## v0.4.11

**Two releases were spent fixing the wrong thing because this tweak's own diagnostic
was actively misleading, and that is the real lesson here.** `+lastAttemptState`
recorded only the *last* resolution attempt, and the overwhelming majority of attempts
are brand-new models asked a moment after construction, before their video data is
populated. So the row read "every chain failed — -video answered nil" while the feed
button, which appears *only* when a URL has actually been resolved, was visibly
appearing and being reported as placed. The failing line was the last of two hundred
attempts, not the verdict on all of them; resolution has been working for at least two
releases. Successes are now counted separately, the winning chain is named, and the
last attempt's own detail is shown only while nothing has ever succeeded — a number
that climbs cannot be drowned out the way one overwritten string could.

The same pattern this project already documented for the YouTube tweak's SABR section
("a report showing no interceptions had two readings, and those need opposite fixes"),
repeated in a new place. A diagnostic that reports the last event rather than a tally
is not a diagnostic.

**The button's tilt was caused by v0.4.10's own fix.** A vertical `UIStackView` aligned
`fill` — the default, and what TikTok's rail evidently uses — gives every arranged
subview the stack's full width. Pinning this one to 34 points fought that: the
constraint and the fill cannot both hold, and the loser reads as a button sitting off
to one side of a column whose siblings are centred in full-width slots. The width
constraint is removed; only the height is fixed, and the glyph is centred inside
whatever width the stack gives it, exactly as every sibling icon already does.

**The download failure now says what refused it.** "Couldn't save it" is all a user
needs and nothing a fix can be built from: an HTTP 403 on the resolved link, a file
Photos will not decode, and a zero-byte download that answered 200 all look identical
from there. A non-2xx HTTP status is now caught before the file is ever handed to
Photos (`NSURLSession` treats an error page as a perfectly successful download, which
is how a 403 arrives as an unplayable `.mp4`), and the real reason — the status code,
Photos' own error, or which extension/MIME pair decided a file was audio — is recorded
and shown as its own "Last save attempt" Status row.

## v0.4.10

Three things reported against v0.4.9, all in one round this time.

**The button read tilted.** A plain `UIButtonTypeSystem` has no fixed size of its own
— its intrinsic content size comes from the glyph plus the system's own default
content insets, not necessarily the same width or centring TikTok's own icons use.
Given an explicit 34×34 square, centred content, and its default edge insets zeroed
out, it now sizes the same way its siblings in the rail do rather than however the
system decided to pad a bare image button.

**It still shows only sometimes.** This is not a new bug so much as the honest shape
of the current approach: the button only shows when `SCITTMedia` has actually
resolved something, and resolution itself is still inconsistent from one video to the
next — the same report that asked about this also showed every chain failing outright
for the video it was taken on. The retry window was widened (ten attempts over twenty
seconds rather than six over nine) on the chance some of that inconsistency is still
a timing question rather than a wrong name, but a resolver this unreliable will keep
producing a button that shows unevenly until a chain proves itself consistently
right.

**A downloaded video saved as "sound saved."** MIME-type sniffing alone decided
audio vs. video, and a server answering a missing or generic `Content-Type` for a
link whose own path plainly ends `.mp4` is exactly what that cannot tell apart from a
genuine audio-only link with the same gap. The URL's own path extension is now
checked first (`.mp4`/`.mov`/`.m4v`/`.webm` → video, `.m4a`/`.mp3`/`.aac`/`.wav` →
audio) and MIME type only decides when the extension itself is inconclusive.

## v0.4.9

The centering fix worked — one button, reported placed once, no more scatter. Two
things followed directly from the last full failure report.

**The resolution chain was one hop short of a real answer, named by its own failure.**
`-video` no longer answers nil (the retry timer's own doing) and returns a real
`AWEVideoModel`; `video.playURL` was already being tried, and the report said exactly
why it failed: `"chain ended at AWEURLModel, not a URL or string"` — `-playURL`
answers a real `AWEURLModel`, one hop short of that class's own doubly-confirmed
`-bestURLtoDownload`. `video.playURL.bestURLtoDownload` is now the first chain tried,
built from that failure rather than another guess.

**The button's position.** Reported as fixed under the wrong icon. TikTok's own rail
is avatar, like, comment, bookmark, share, then a spinning record/music-disc last —
not confirmed against a class dump the way this project holds every other hook target
to, but a layout consistent across TikTok's own app regardless of build. Appending at
the very end (what `-addArrangedSubview:` does) landed the button after that disc
rather than under share. It is now inserted one position before the end instead,
which puts it directly under share on that layout.

## v0.4.8

Both problems reported against v0.4.7 were real progress, not new failures: the button
attached and placed real instances on both surfaces (3 on the cell overlay, 9 on the
rail), and resolution succeeded for the first time (`playURIString`). Two bugs
followed directly from that success.

**Scattered, duplicate buttons.** TikTok keeps more than one cell alive at once for
smooth scrolling -- the one on screen and its prefetched neighbours -- and every alive
cell's own rail was showing a button regardless of whether that cell was actually the
one visible. Four to six buttons on screen at once was the two surfaces (cell overlay,
interaction rail) each placing one per alive cell. The cell-overlay surface is dropped
entirely -- it was a fallback for a build where the rail did not exist, and this
device's own report already proved it does, so keeping both only doubled the scatter.
The rail surface now checks whether its own view is actually centred in the window
before showing anything (`-convertRect:toView:` against the window's own bounds,
within a quarter of its height) and hides itself otherwise -- so of however many cells
are alive, only the one on screen shows a button.

**The download itself failed.** `playURIString` resolving to *something* was never the
same claim as that something being a fetchable link, and `NSURL URLWithString:` builds
a URL object out of almost any string without checking. The resolver now requires the
scheme to be `http` or `https` before accepting a chain's answer, treating anything
else (an internal resource identifier, most likely, on a property named this
generically) as a failed step and moving on to the next candidate rather than handing
the downloader something it can never fetch. Chain order was also reshuffled so paths
most likely to reach a real `AWEURLModel` -- and therefore `bestURLtoDownload`, the one
doubly-confirmed step in this whole file -- are tried before `playURIString`/`URLList`.

## v0.4.7

The full `+candidateAccessorsOnAwemeModel` dump, read this time from the live class on
a real device rather than from either reference tweak's own binary, settled the
`-video` question: it exists as a real property, and every attempt to read it so far
has answered nil. Two readings are possible -- the wrong candidate, or the right one
simply not populated yet at the moment a model is first built -- and this project has
no way to tell them apart from a class dump alone.

**So both are now covered.** Seven more candidate chains join the resolver, each read
directly off that same live property list rather than guessed: `downloadinfoModel`,
`urlHolder`, `playURIString`, `playItem`, `URLList` (now handled as a value that can
itself be a list — the first entry that converts to a URL wins). And a model whose
first resolution attempt finds nothing is no longer simply logged and discarded:
`+watchModel:` holds it *weakly* — nothing here extends how long a feed cell's own
model stays alive — and a repeating timer retries resolution on every pending model up
to six times, in case the answer was only ever a timing question. A model still
unresolved after six tries is assumed to genuinely have no video (a photo post, most
likely) and dropped rather than retried forever.

**A "copy report" button was asked for directly and added to the settings screen's
navigation bar.** The Status section's own rows can each run to a long, dynamically
built string — every candidate chain's own failure reason, every property name on the
live class — exactly the kind of thing a bug report needs pasted whole rather than
retyped from a screenshot. One tap copies gate state, ad filter counts, the button
report, the resolution state, the full candidate list, and both bypass and privacy
states to the pasteboard.

## v0.4.6

Rather than wait on another device report to try one more guessed selector, NA9's own
binary was read again -- not its `_ungrouped$` hook table this time, but its generic
`_objc_msgSend$…` message-send stub symbols, which name every selector the binary
actually sends anywhere, hook or not. Real candidates turned up: `-video` (no "Model"
suffix), `-playURL`, `-url`, alongside `-bestURLtoDownload` itself (the one step that
was always doubly confirmed). `awemeVideoModel` also appears as a plain string near
`_videoModel`/`bitratePlayAddr` in the same table that misled this project the first
time, and is deliberately not used here for that reason alone -- string proximity is
exactly the standard that already failed once on this same question.

`SCITTMedia.resolveURLForModel:` now tries seven candidate chains in order --
`videoModel.playAddr.bestURLtoDownload` (the original, kept in case some path still
uses it), `video.playAddr.bestURLtoDownload`, `video.bestURLtoDownload`,
`video.playURL`, `video.url`, `playURL`, `videoModel.playURL` -- each guarded by
`-respondsToSelector:` at every step, stopping at the first that resolves. When none
do, `+lastAttemptState` now reports every chain's own failure point in one line
instead of only the first, so the next report is decisive rather than another single
data point.

## v0.4.5

The answer came back: **"model has no -videoModel."** `-videoModel` was always this
tweak's own weakest link -- the header has said so since v0.2.0, marked circumstantial
because neither reference tweak's own hook table ever names it, only string-table
proximity to `playAddr`/`bitratePlayAddr` suggested it. A live device now says outright
it is wrong on this build.

Guessing a replacement name would repeat the exact mistake that produced the
`AWEFeedViewCell` bug two releases ago. Instead, `SCITTMedia` gained
`+candidateAccessorsOnAwemeModel`, a new Status row that reads `AWEAwemeModel`'s own
properties and no-argument methods straight off the *live runtime class on this exact
device* — walking up a few superclasses too, since the accessor may not sit on
`AWEAwemeModel` itself — and lists every one whose name contains "video", "play",
"url", "media", "cover", "download" or "aweme". Not a class dump taken somewhere else:
whatever this row lists is what the chain can actually be pointed at on the build that
matters, the same "ask the device, not the assumption" principle Diagnostics pages use
throughout this project.

## v0.4.4

Still 0 placed on both surfaces after v0.4.3, on a device where the ad filter's own
count (122 feed items seen, 10 dropped) proves `AWEAwemeModel` construction is being
reached. That count alone does not prove the *download* resolution chain succeeds for
any of those models — `-configWithModel:`'s replacement, reading
`[SCITTMedia recent].firstObject`, would show nothing whether the placement hooks
never fire *or* fire correctly and simply have nothing resolved to show. Those need
different fixes, and nothing on the report so far said which.

`SCITTMedia` has carried exactly the diagnostic for this since v0.2.0 —
`+lastAttemptState`, which records which step of `videoModel.playAddr.bestURLtoDownload`
the chain last reached — and it was never wired into the settings screen. It is now, as
its own Status row, separate from the button's own placement count. The next report
names which of "no -videoModel", "-videoModel nil", "no -playAddr", "-playAddr nil", "no
-bestURLtoDownload", a wrong return type, or "resolved a download URL" is actually
happening, rather than leaving "0 placed" to mean any of them.

## v0.4.3

**A real device report settled the button question outright.** The Status screen's
own "In-feed button" row, checked after v0.4.2, said: `cell overlay — 0 placed;
TTKFeedInteractionStackView + TTKFeedRightInteractionStackView — 0 placed; above it:
TTKFeedInteractionStackView < TTKFeedInteractionMainView < TTKFeedInteractionRootView
< UITableViewCellContentView < AWEFeedViewCell < AWENewFeedTableView < … <
AWEFeedSlidingScrollView`. The rail was attached and running — it is what walked that
chain — and the chain names the real cell: **`AWEFeedViewCell`**, not
`AWEFeedViewTemplateCell`, the class both NA9 and VibeTok's own symbol tables name and
the one every placement attempt through v0.4.2 hooked. `AWEFeedViewCell` is in neither
reference's own hook table at all; this build has moved past what either was written
against. `-configWithModel:`/`-configureWithModel:` were therefore never called on a
real cell, and the association they were meant to stash was never there for the rail
or the overlay to read — which is the entire reason both surfaces reported zero.

**The fix drops per-cell precision rather than guess at another bind method.** Nothing
in the walked chain says which selector actually sets `AWEFeedViewCell`'s model, and
guessing one is exactly what produced this bug the first time. `-layoutSubviews` needs
no such guess — inherited from `UIView`, it fires regardless of what TikTok calls its
own bind method. Both surfaces (the cell overlay and the rail) now show
`[SCITTMedia recent].firstObject` — the newest video this tweak has actually resolved
a link for — rather than a specific per-cell association. This is the same "download
the newest capture" shortcut Locket's own quick-save button already takes, for the
same reason: the ad filter's diagnostics already prove `SCITTMedia` is capturing real
items (the report that found this bug also showed 154 feed items seen, 6 dropped),
so the newest one is almost always the video just watched. `AWEFeedViewCell` is hooked
alongside the older `AWEFeedViewTemplateCell` rather than replacing it, at zero cost
if the older name never fires again on this build.

## v0.4.2

v0.4.1's own fixes did not hold, reported directly against a real build: the settings
text was still overlapping and the button still did not appear.

**The overlap had a second, more direct cause than the row height fix addressed.** The
Status section used `UITableViewCellStyleValue1` with a multi-line detail label —
Value1 lays its title and detail side by side on one line by design, and several of
these rows hold a long, dynamically-built diagnostic string (a comma list of hook
names, a whole superview chain). Forcing that onto two lines in a layout built for one
draws the wrapped text over the title beside it rather than under it. Switched to
`UITableViewCellStyleSubtitle`, the same style already used everywhere else on this
screen, which stacks a note under its title instead of beside it.

**The button gained a second, primary placement that does not depend on the interaction
rail at all.** Reported directly: NA9 For TikTok's own download button — its classic
surface, not the sidebar one — has worked without interruption for years, drawn
straight onto `AWEFeedViewTemplateCell` itself via `-layoutSubviews` calling its own
`na9AddDownloadButton`. That is now this tweak's primary surface too: a button added
as a direct subview of the cell, bottom-right, raised to the front on every layout
pass the same way the X tweak's own `ImmersiveCardView` surface does for the identical
reason (the video's own overlays are re-added as the cell renders, and a button under
one of them is a button nobody can tap). It needs only `AWEFeedViewTemplateCell` to
exist — nothing else has to be present for it to have a chance of showing. The
interaction-rail surface (`TTKFeedInteractionStackView`/`TTKFeedRightInteractionStackView`)
is kept as a second, optional surface exactly as NA9 also carries both. The Status
screen's own report now names both surfaces and how many buttons each has placed.

## v0.4.1

Three things reported directly after v0.4.0 shipped: the in-feed button still did not
appear, privacy was one switch for three different reports, and the settings screen's
own text overlapped itself.

**The overlap was a real, confirmable bug, independent of anything device-specific.**
Every Controls/Privacy row carries a wrapped, multi-line note under its title, and the
table never set an automatic row height -- every cell sat clamped to the fixed 44-point
default, so a two- or three-line note was drawn on top of the row underneath it rather
than pushing it down. `self.tableView.rowHeight = UITableViewAutomaticDimension` with an
estimated height fixes it outright.

**Privacy split into three separate switches**, each its own row in a new Privacy
section: story views, message read receipts, profile views. One switch bundling all
three could never be turned off for just one of them, which is what was asked for
directly. `SCIPrefPrivacy` is gone; `SCIPrefPrivacyStory`/`SCIPrefPrivacyMessages`/
`SCIPrefPrivacyProfile` gate their own hook in `SCITTPrivacy.x` independently.

**The in-feed button's placement no longer depends on the rail's own layout firing.**
`TTKFeedInteractionStackView`/`TTKFeedRightInteractionStackView -layoutSubviews` and
`-didMoveToWindow` are still hooked as a fallback, but this project's own CLAUDE.md
already documents why neither can be trusted alone on a *reused* cell -- the same
lesson a much earlier X-tweak bug cost a release to learn, and a UIStackView is not
guaranteed a fresh layout pass just because the cell holding it was rebound to a
different model. Placement is now driven directly from `AWEFeedViewTemplateCell`'s own
`-configWithModel:`/`-configureWithModel:` -- confirmed to fire on every reuse -- via a
depth-first search of the cell's own subview tree for the rail, immediately after the
resolved item is stashed on the cell. Whether this actually surfaces the button on a
real device is still unconfirmed; the Status section's own "In-feed button" row now
says exactly which of four states it is in (rail absent, cell hooked but no rail, rail
found with nothing resolved above it, or N buttons placed) rather than a bare yes/no,
so a report from here on names which one rather than only "no button."

## v0.4.0

A download button in the feed itself, and a real settings screen -- both asked for
directly after v0.3.0 shipped only a status-screen list.

**The button.** NA9 For TikTok's and VibeTok's own `_ungrouped$` hook tables were read
again, this time for where a *visible* button belongs rather than for a resolution
chain. NA9 places one on `AWEFeedViewTemplateCell` directly and, on a newer rail, on
`TTKFeedInteractionStackView` / `TTKFeedRightInteractionStackView` -- the vertical stack
of like/comment/bookmark/share icons beside the video. VibeTok, a tweak with no
download feature at all, independently hooks `TTKFeedInteractionStackView
-layoutSubviews` for its own unrelated reason, which is a second, unrelated confirmation
that class is real. Both stack names are confirmed present as literal strings in TikTok
46.4.0's own `MusicallyCore` binary, read directly the same no-`otool` way every class in
this tweak has been.

What is not carried over is how the reference tweaks find out which video to download --
that reads a model accessor on the stack view this project has not independently
confirmed. Instead, the model is caught where it needs no confirmation at all:
`AWEFeedViewTemplateCell -configWithModel:` / `-configureWithModel:` are two of NA9's own
hooked selectors, and a hooked method's own argument is simply what was passed, not a
guess. The resolved URL is stashed on the cell the moment its model is set, and the
button -- nested somewhere inside that cell -- reads it back by walking up its own
superview chain, the same upward search the X tweak's own immersive button already uses
to reach its card from its rail. `SCITTMedia`'s resolution chain was split out into its
own `+resolveURLForModel:`, callable without touching the status screen's recent list, so
there is exactly one resolution implementation behind both surfaces.

**The settings screen.** Replaced entirely -- a plain stack of three switches over one
text-view report is not what "detailed and organized like NA9 and VibeTok" asked for.
Rebuilt as a real grouped `UITableViewController`, in the shape the X tweak's own
settings screen (`SCITWSettings.m`) already settled on: a status card with pass/fail
pills at the top, a Controls section with a coloured icon and an explanation under every
switch, a Download section listing what has actually been resolved (tap a row to save
it, no confirmation sheet), and a Status section with live numbers -- the panel gate,
the ad filter's own count, which interaction rail the button attached to, and what the
bypass and privacy hooks have each answered. Privacy answers now record into their own
set (`SCITTDiagnostics recordPrivacyAnswer:`/`privacyState`) instead of sharing the
bypass tally, so the two numbers cannot be read as one.

**Privacy widened by two more confirmed selectors.** `TTKProfileViewsVisitor -visit:` and
`-p_shouldReportHasVeiwedProfileForUser:` turned up in the same NA9/VibeTok symbol tables
the other three privacy hooks came from, confirmed present in the real binary the same
way -- added alongside `-reportProfileView`/`-p_shouldReportProfileView` on the same
class, all four withheld together.

## v0.3.0

Two more references arrived — NA9 For TikTok's compiled `.deb` and VibeTok's compiled
`.dylib` — both read the same way every closed reference in this project is: with the
precise `_ungrouped$Class$selector` Logos debug-symbol table each carries (both are
unstripped debug builds), which names the exact class-and-selector pairs each one
actually hooks, not just what strings sit near each other. Read for where TikTok is
hookable only; no code is taken from either.

**Download.** `AWEAwemeModel.videoModel.playAddr.bestURLtoDownload` is the chain both
references resolve a video's URL through. `-bestURLtoDownload` is confirmed twice over —
present in this build's own binary and the exact selector NA9's own symbol table hooks.
`-videoModel` and `-playAddr` are not in either reference's own hook table (neither
overrides them, only calls them), so they are held to the lower, circumstantial bar this
project's other "not a hooked selector" findings are — `SCITTMedia.m` walks the chain
behind `-respondsToSelector:` at every step and records which one failed rather than
assuming it holds. A kept (non-ad) model is captured the moment `AWEAwemeModel` finishes
building, resolved synchronously, and only the resulting URL is kept — never the model
itself, so nothing here extends how long a feed cell's own object stays alive. The
status screen lists what has been captured with a Save button per item;
`SCITTDownload.m` fetches and writes it into Photos, or into the app's own Documents for
audio-only content Photos cannot hold, mirroring Locket's and X's own downloader almost
exactly (`JGProgressHUD`, `PHPhotoLibrary requestAuthorizationForAccessLevel:`,
`NSURLSessionDownloadDelegate`).

**Privacy.** Three points where the app reports what was watched back to TikTok's own
servers, cross-validated between both new references before being hooked:
`TTKStoryMarkReadService -markAsRead:` (a story was opened), `AWEIMMessageReadComponent
-p_markReadSyncToServerWithMessage:` (a DM was read — its sibling
`-p_markMessageAsReadLocally:` is deliberately untouched, so the conversation's own
unread badge keeps clearing normally on this device), and `TTKProfileViewsVisitor
-reportProfileView` / `-p_shouldReportProfileView` (a profile was visited). New switch,
off by nothing — on by default like the rest, in the status screen.

**Ad filter widened.** `isAd`, `isAdItem` and `isAdsOrPseudoAds` join `-isAds` as marks
`AWEAwemeModel` can carry — found sitting beside it in the same run of the binary's own
string table, the same circumstantial standard `-videoModel` was already held to.
`-respondsToSelector:` guards each independently; any one answering YES is enough to
drop the model. A separate splash/launch-ad surface is suppressed too — three plausible
manager class names (`AWESplashManager`, `BDASplashManager`, `TTAdSplashManager`) are
each hooked behind their own `NSClassFromString` guard, since the references disagree on
which name a given build actually ships and an absent class's hook simply never
attaches.

**Bypass widened.** Six more jailbreak-detection points, each confirmed present by class
name and cross-validated between both new references: `IOSSecuritySuite +amIJailbroken`,
`AppsFlyerUtils -isJailbrokenWithSkipAdvancedJailbreakValidation:`, `IESLiveDeviceInfo
-isJailBroken`, `TTInstallUtil -isJailBroken`, `UIDevice -btd_isJailBroken`, and a bare
`NSObject -jailbroken` category method. **`PIPOStoreKitHelper -isJailBroken`, also named
by a reference, is deliberately left unhooked** — v0.1.0's own reading already refused
`PIPOStoreKitHelper` and its sibling `PIPOIAPStoreManager` as sitting inside the
in-app-purchase surface, the same boundary Locket's Check0verPlus review drew, and one
confirmed method on that class is not reason enough to cross it. The other six checks
already answer the same underlying question.

## v0.2.0

The real IPA and a real class dump of TikTok 46.4.0 arrived, and every class this tweak
now hooks was confirmed against it directly — `MusicallyCore.framework` (810 MB, the app's
real logic; the main executable is a 92 KB stub) parsed by hand for its own class and
selector names, the same Mach-O-by-hand method this project already uses everywhere else
there is no `otool` available.

**No ads.** `AWEAwemeModel` — confirmed present — carries the server's own `-isAds` mark
on every feed item, confirmed as a real property name in this build's own strings. Refused
at `-init` and `-initWithDictionary:error:`, after `%orig` builds the object (the mark
cannot be read before then) and before anything downstream ever sees it. Not a view hidden
afterward; the object is never returned.

**Hides the jailbreak.** `TTAdSplashDeviceHelper -isJailBroken`, `GULAppEnvironmentUtil`'s
three environment questions, `FBSDKAppEventsUtility -isDebugBuild`, `AWEAPMManager
-signInfo`, `AWESecurity -resetCollectMode`, and `NSBundle` asked for a
`.mobileprovision` — six real checks, each answered the way an unmodified phone would.
Nothing here touches `PIPOIAPStoreManager`/`PIPOStoreKitHelper` or any purchase flag, and
nothing will.

**v0.1.0's own reading corrected itself here, not silently.** `AWEAPMManager` was filed
under "Ads" in that entry, going only by its name — reading BHTikTok's actual hook showed
it answers a signing-info question (`+signInfo` → `"AppStore"`), which is a jailbreak-
detection answer, not an ad control. It is filed correctly above. `AWEPlayVideoPlayerController`
and `TIKTOKProfileHeaderView`, both named in v0.1.0's list, do not exist as exact strings
in the 46.4.0 binary at all — plausible replacements were found
(`AWEPlayVideoPlayerControllerClass`, `AWEVideoPlayerController`; a `TTK`-prefixed profile
header family) but not yet confirmed enough to hook.

Settings: a two-finger hold opens a status screen with a switch for each feature above and
the same diagnostics report `SCITTDiagnostics` builds — how many feed items were seen and
how many dropped as ads, and which bypass hooks have actually answered a real caller.

Next: download. `AWEURLModel` is confirmed present; what shape it answers in — a direct
URL, or another indirection the way most of this project's other download features turned
out to need — is not yet measured.

## v0.1.0

Scaffold only. The tweak's structure exists — Makefile, control, filter plist, source
layout, bilingual localisation table, the panel gate — so `tools/check.py` and
`./build.sh tiktok rootless` both run against it while the real hooks are written. No
feature patches TikTok yet.

Two references were read for architecture, both by the same author family already
credited in the X tweak's own control file: BandarHL's original BHTikTok
(github.com/BandarHL/BHTikTok) and al3raQe's maintained fork
(github.com/al3raQe/BHTikTok). Neither carries a LICENSE file, so both are read the same
cautious way every other unlicensed reference in this project is — for *where* things are
hookable, never for the code itself. Their `Tweak.x` hooks 34 classes; the ones that
matter for what this project would actually build:

- **Ads**: `AWEAPMManager`, `TTAdSplashDeviceHelper`
- **Download / feed model**: `AWEAwemeModel`, `AWEURLModel`, `AWEPlayVideoPlayerController`,
  `AWEFeedVideoButton`, `AWEFeedViewTemplateCell`, `AWEAwemeDetailTableViewCell`
- **Profile**: `TIKTOKProfileHeaderView`, `AWEProfileImagePreviewView`,
  `AWEProfileEditTextViewController`, `AWEUserModel`
- **Confirmations / comments**: `AWECommentPanelCell`, `AWEPlayInteractionUserAvatarElement`
- **Device / jailbreak-detection evasion**: `BDADeviceHelper`, `BDInstallNetworkUtility`,
  `GULAppEnvironmentUtil`, `UIDevice`, `CTCarrier`, `NSFileManager` — the same class of
  check Locket's own bypass answers, not a paywall
- **Settings surface**: `TTKSettingsBaseCellPlugin`, `AWESettingsNormalSectionViewModel`,
  `SparkViewController` (built on Cephei/CepheiPrefs, an external dependency this project
  does not use — a native settings screen would be written instead, the way every other
  tweak here already does it)

**Deliberately not being built, regardless of what a class dump confirms**:
`PIPOIAPStoreManager` and `PIPOStoreKitHelper` — an in-app-purchase / StoreKit fake, the
same shape of thing `Check0verPlus.dylib` was for Locket and was reviewed and refused for
the same reason: that takes money from TikTok's own developers, it is not a device tweak.
Any "fake verified badge" / "fake follower count" cosmetic-spoofing features named in
BHTikTok's own README are being treated the same way as Locket's Check0verPlus review
until there is a reason to think otherwise — parked, not assumed safe.

Next: a real class dump and a real IPA of the current TikTok build, so every hook is
confirmed against what actually exists on this build rather than carried over from a
reference that may target a TikTok years older than today's.
