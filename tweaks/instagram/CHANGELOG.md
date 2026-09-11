# Albrhi Changelog

**Tested on Instagram 410, 439 and 441.** All three are supported from the same build.
Other versions should work too — the tweak looks for what it needs while the app runs
rather than expecting a particular version number.

## v4.1.21

**ستوري الصورة ذات الموسيقى كان يُحفظ صامتاً، وهو عطب «الكائن أجوف والقاموس يحمله» للمرة الثالثة.**

`+getAudioUrlForMedia:` يحلّ `sundialOriginalAudioAsset` و`sundialMusicAsset` — وهما مسمّيان
للريلز والخلاصة لا يجيب عليهما عنصر الستوري. ففرع الصورة لم يجد صوتاً، ولم يعرض الخيار، وحفظ
صورة صامتة. آلة «صورة + صوت ← مقطع» موجودة أصلاً منذ إصدارات (`SCIPhotoVideo`)؛ كان ينقصها
الصوت وحده.

**والحالة اسمٌ عند إنستغرام نفسه، لا استنتاج منّي:** `is_story_image_with_music` و
`story_music_stickers` و`story_music_lyric_stickers` و`music_metadata` و`original_audio` كلها
سلاسل حقيقية في ثنائيّ مرجعٍ من نفس الجيل.

**لكن الفرع مؤكَّد والورقة ليست، فالورقة تُبحث لا تُسمّى.** لا شيء في ذلك المرجع يسمّي مفتاح
الرابط المتداخل، وهذا المشروع خسر ثلاثة إصدارات على تخمين حلقةٍ لم يقرأها — فيُمشى في شجرة
الموسيقى بحثاً عن الرابط الذي تحمله فعلاً، وهو ما ينجو أيضاً من إعادة تسميةٍ لا ينجو منها مسار
مكتوب بالاسم. ومسار المفتاح الذي أجاب يُسجَّل في صفحة التشخيص.

**وصورة الغلاف تسكن الشجرة نفسها**، فالمرشّح يُرفض بامتداد صورة أو باسم مفتاح يوحي بغلاف أو
صورة شخصية، لا يُقبل لمجرّد أنه رابط.

**وزرّ العين صار يُبلّغ عمّا يتابع به.** كان يكتب في السجل وحده أنه لم يجد متحكّم مقطع — والسجل
لم يحمله تقرير قط. صار سطراً في صفحة التشخيص، لأن «الإيصال خرج ولم ينتقل الستوري» و«لم يعمل
الزر» شكويان مختلفتان بإصلاحين مختلفين.

## v4.1.20

**التقرير قال إن التحميل لم يبدأ أصلاً، فالإصلاح السابق كان على المرحلة الخطأ.**

سطر «آخر تنزيل عومل كـ» رجع فارغاً، و`downloadMedia:` يسجّل نوعاً في **كل** فرع من فروعه —
فلو دخلها لقال شيئاً. أي أن البحث عن الستوري رجع لا شيء، والرسالة «لم يتم العثور على المحتوى»
صدرت قبل الوصول إلى قاموس العنصر الذي أُضيف في 4.1.19. ذلك القاموس صحيح ولم يتغيّر؛ ببساطة
لم يكن يُسأل.

**وسيط دالّة مربوطة لا يمكن إعادة تسميته من تحت الخطّاف، بخلاف قائمة أسماء أصناف.** البحث كان
يربط `IGStoryModernVideoView` و`IGStoryPhotoView` بالاسم فلم يطابق شيئاً على إنستغرام 439.
و`-fullscreenSectionController:willDisplayStoryModel:` مربوطة أصلاً لأجل زرّ «شوهد»، وتُسلّم
الكائنين مجاناً — فصار العنصر يُؤخذ منهما أولاً، عبر سلّم مسمّيات كلٌّ منها خلف
`-respondsToSelector:`، ويُسجَّل أيّها أجاب.

**ولا يُسلَّم مرشّح لم يثبت أنه عنصر.** النموذج المُسلَّم قد يكون الحكاية كاملة لا العنصر الظاهر،
وتمريره بلا تحقّق يحفظ غلاف الحكاية — وهو عطب غلاف إعادة النشر للمرة الثالثة. فالمرشّح يجب أن
يجيب على أحد الأسئلة الثلاثة التي يسألها المُنزِّل نفسه، وإلا سقط.

**والبحث في العروض صار يُبلّغ بدل أن يفشل صامتاً.** أي عرض يغطّي منتصف الشاشة ويحمل «Story» في
اسمه — بما في ذلك اسم Swift المُشفّر `_TtC…Story…` — يُسأل ويُسجَّل اسمه في صفحة التشخيص، سواء
أجاب أو لا. فالتقرير القادم يسمّي الصنف الحقيقي بدل أن يكلّف جولة تخمين أخرى، وصفحة التشخيص
تفرّق بين «لم يخبرنا العارض بستوري قط» و«أخبرنا ولم يجب شيء».

## v4.1.19

**زر الستوري كان يحمّل صورة الفيديو بدل الفيديو، وهو نفس عطب إعادة النشر بثوبٍ آخر.**

ستوري الفيديو يحمل `IGVideo` **فارغاً** — تماماً كما يفعل منشور الصورة وإعادة النشر — فـ
`+hasPlayableVideo:` يجيب لا بحق، والتحميل يسقط إلى فرع الصورة ويحفظ إطار الغلاف. البيانات ليست
ضائعة: فيديو الستوري الحقيقي في **قاموس** العنصر تحت `video_versions` و`video_dash_manifest`، لا
على كائن `IGVideo` الذي كنا نسأله.

الحل يقرأ العنصر كما تقرؤه الأداة المرجعية: يسأل العنصر عن قاموسه (`dictionaryRepresentation` /
`igMedia`) بدل أن يسأل الكائن الخطأ عن رابط. DASH أولاً عبر نفس محلّل السلّم الموجود (فستوري AV1
يُرفض هنا كما يُرفض منشور AV1، ويبقى التحويل مالكاً لتلك الحالة)، ثم السلّم التدرّجي، الأكبر مساحةً
يفوز. **إضافي بحت**: لا يُستشار إلا بعد أن يفشل مسار الكائن أصلاً، فما يُحمَّل اليوم لا يتغيّر، وسطر
التشخيص يقول «video (from item dictionary)» حين يفوز.

مقروء للمعمار فقط من RyukGram (مبنية على SCInsta؛ لا يُنسخ منها سطر). أسماء المفاتيح من واجهة
إنستغرام لا من صنفٍ، فهي ثابتة عبر الإصدارات؛ أصناف الستوري نفسها موجودة في 410 و446 على السواء.

## v4.1.18

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

## v4.1.17

**"Free" is out of every description.** The tweak needs a licence; a package page saying it is
free was the first thing anybody read. The licence itself is unchanged and still named in full —
GPLv3 where it applies, MIT for the Watch pairing core — because dropping a word is not the same
as dropping an obligation, and the attribution those licences require is not negotiable.

## v4.1.16

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

## v4.1.15

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

**Thirteen features here recognise a row by the English words printed on it** — `Ask Meta AI`,
`Suggested for you`, `Meta AI` — inherited from SCInsta. Instagram translates those titles, so
on a phone that is not in English none of them can ever match, and the switch looks broken
rather than inapplicable. There is no identifier on those view models this project has
confirmed, so rather than guess one or delete a feature that works for somebody, every
comparison now goes through `SCIMatchesEnglishTitle`: it matches exactly as before and counts
what it saw, and Diagnostics gained a section reading `12 seen, 0 matched` under a line naming
the language Instagram is actually showing. A zero there is the evidence needed to replace the
comparison properly.

## v4.1.14

**Two diagnostics that were saying untrue things, and the AV1 transcode switched on.**

*The timestamp scanner did not recognise this tweak's own output.* A report listed
`1mo – 01:04:39 AM` and `6d – 06:16:07 PM` among the labels it had found, with 330 exact date swaps
counted above them, and still concluded **no match**. The pattern was anchored after the unit —
written for Instagram's bare `1mo`, never revisited when the custom-format feature began appending
a time. The one screen meant to prove that feature works was the one screen that could not see it
working. It still refuses `12.2K`, `185` and `5/6`, because none is a number followed by a time unit.

*The story line named the chokepoint that is missing and not the one doing the work.* The receipt is
withheld at `IGStorySeenStateUploader -networker`, which both tested builds have, and at
`IGStoryPendingSeenStateStore -_uploadSeenState:`, which only the newer Swift build has — so a
healthy 410 reported an absence and read as a fault. Both are named now, and the row is green when
either is installed.

*And `distinct` counted one ladder while the screen implied two.* It is filled below the saveable
test, so an AV1-only ladder scores zero **by construction** — read beside nine AV1 rungs up to 1440p
as "nothing to choose between", when it meant "nothing without transcoding". The funnel carries a
`transcodable` count now.

**The AV1 transcode is on by default.** It shipped off because it is heavy, which was right while
most reels arrived in a codec iOS could save. `saveable 0` ended that: the download button was
failing silently on most of the feed, with nothing on screen saying why. A costly feature that works
beats a free one that does nothing, and it announces itself with a progress banner while it runs.
**Anyone who turned it off keeps it off** — `registerDefaults` never overwrites a value somebody set.

## v4.1.13

**A saved AV1 reel keeps its HDR.** The device report that confirmed 4.1.11's fix also answered the
question behind it, from the manifest rather than by inference: Instagram's reels ladder is
`av01.0.12M.10.0.111.09.18.09.0` — ten-bit, `ColourPrimaries=9` (BT.2020),
`TransferCharacteristics=18` (**HLG**), with `dav1.10.07` beside it, which is Dolby Vision profile
10. That is genuine HDR, not a ten-bit SDR clip.

**The wash-out had two independent causes, and one fix would have left the other.**

*The depth.* 4.1.11 shifted every ten-bit sample down to eight so the H.264 encoder would take it —
which is what made these reels saveable at all, and threw away two bits doing it. A ten-bit source
now gets an **HEVC Main10** session and `x420` buffers, whose ten bits sit in the *most significant*
bits of a sixteen-bit container, as the SDK header states outright. **The fallback is tried rather
than assumed**: the session is created, the profile is set, and only a session that came back is
used — a device without Main10 encoding takes the eight-bit path, which is what shipped before and
works. A session that accepts creation but refuses Main10 is torn down rather than left to encode
ten-bit buffers as eight in silence.

*The description.* Even with every bit kept, a file that does not **say** it is HLG in BT.2020 is
played as BT.709 SDR, because a player has no other way to know. The colour description is now read
from dav1d's own sequence header — never assumed — and attached twice: to each pixel buffer, which
governs the frame, and to the compression session, which governs the track's format description. A
file where those two disagree is a file two players will disagree about.

The status line names which encoder actually ran, so the next report says `HEVC Main10, 10-bit kept`
or `H.264, 8-bit` rather than leaving it to be guessed at.

## v4.1.12

Two changes to the AV1 transcode, both measured out of the code rather than guessed at.

**Film grain synthesis is off, which saves twice.** AV1 does not store grain, it stores a recipe for
it, and dav1d re-synthesises it onto every frame -- `apply_grain` defaults to on. That is decode
time on every frame, and then it is paid for again at the other end: synthetic noise is the most
expensive thing an H.264 encoder can be asked to carry, being high-entropy by construction, so the
bits preserving it are bits not spent on the picture. Right for a player, wrong for a transcoder
whose output is a fixed-bitrate file.

**The encoder now hands back its own pixel buffers.** The session was created with no source
attributes, so it had no pool to offer and the loop allocated a fresh CVPixelBuffer -- an allocation
and an IOSurface mapping -- for every frame of the clip. Declaring the format makes
`VTCompressionSessionGetPixelBufferPool` return a real pool, and a pooled buffer is a recycled one.
The plain allocation stays as the path for the first frame, before the session exists, which is the
one time it is reachable.

**Not changed, deliberately:** dav1d's thread count. `0` already means one thread per logical core,
which is what this wants; it is written down here so it is not "fixed" into a constant later.

## v4.1.11

AV1 reels transcode again. **Instagram's AV1 ladder is 10-bit, and one line refused every frame of
it.**

A device report showed the whole picture at once: twelve DASH representations, eight of them video,
every one AV1, `saveable 0` -- so nothing on that reel could be saved without the transcoder. The
transcoder then downloaded, demuxed 2.8 MB cleanly, and reported `frames=0 samples=0`. The decoder
was never the problem. `pixelBufferFromPicture:` began `bpc != 8 → return NULL`, written when the
only clip tested was 8-bit, so dav1d decoded perfectly and every frame was refused on the way to
the encoder.

High-depth pictures are converted rather than refused: dav1d holds the sample in a 16-bit
container, and the extra bits are shifted off to make the 8-bit NV12 the H.264 encoder takes.
**Plainly, that is not a tone map** -- a genuinely HDR source (PQ or HLG transfer) will read flat.
Which kind of 10-bit this was is now recorded rather than argued about.

**And a count of zero is the one number that cannot say why it is zero.** The failure line named
the stage and nothing else, while the fault was a stage later than the one it accused. It now
carries the picture's depth, layout and transfer characteristic.

## v4.1.10

4.1.9 stopped the repost saving its cover image and made it say what it was instead —
`video — declared but no rendition resolved`, with `-needsFetch` answering **NO**. So it
is not a stub waiting to be fetched: the media is complete, says it is a video, and has
no rendition the download path could find. That pointed at something else entirely.

**The gate was narrower than the thing it gates.** `+hasPlayableVideo:` decided whether
to take the video path at all, and it asked `+getVideoUrl:` — `videoVersions`,
`sortedVideoURLsBySize`, `allVideoURLs`. But the downloader standing behind it,
`+downloadVideo:`, asks `+getBestVideoUrl:`, which *also parses the DASH manifest*. A
video whose only rendition lives in that manifest was therefore refused by a test the
actual download would have passed — the parser was already written, already correct, and
simply never reached. `-dashManifestData` is declared on `IGVideo` in the tested build.
The gate now asks the same question the capability answers.

**And the diagnostic names which signal fired.** "Declared but no rendition resolved"
was one sentence covering three different causes — a duration with no renditions, a
manifest that would not parse, a media type that says video while nothing else does —
and each needs a different fix. The line now reads `video (dash manifest) — …` and the
three probes live in one implementation rather than two that can drift.

## v4.1.9

**Saving a video from a repost saved its cover image instead.** Reported from a device,
and the cause is a distinction the download path never drew.

Instagram models a repost as `IGRepostModel`, which carries a **`mediaId` string and no
media object at all** — so the `IGMedia` behind it is built with `-initWithPk:` and is a
stub until fetched. `-needsFetch`, `-needsMediaFetch` and `-coverPhotoDidPartiallyLoad`
are all its own declared accessors on the tested build: the cover photo arrives first,
the video renditions later. Read from a class dump of 410.1.0 rather than guessed.

So `+hasPlayableVideo:` answered NO — **correctly**, there was no playable rendition at
that moment — and the code below it read that NO as "therefore a photo", found the cover,
and saved it. The function was right; its answer was being used for a question it never
asked. "Can I play one right now" is not "is this a video".

Two changes, and neither can make an ordinary post behave differently:

**The kind is now asked separately.** `+mediaDeclaresVideo:` uses three independent
signals — a positive `-videoDuration`, a non-nil `-dashManifestData`, or `-mediaTypeEnum`
being Instagram's video constant — any one of which is enough, and a photo post satisfies
none of them. A media that declares itself a video and cannot resolve one now says so
instead of quietly handing back a different file than the one asked for.

**And the button's media search prefers one that can actually resolve a video.** Every
owner in the delegate and view chain can hold *a* media, and the old walk took the first
whose `photo` was non-nil — which a repost's stub always satisfies. It now keeps walking
when the first match is a declared video it cannot resolve, and returns the first match
unchanged when nothing better exists. It can only find something the old walk skipped.

## v4.1.8

**4.1.6 fixed a crash on Instagram 439 and may have quietly broken the follow badge on
410.** This restores it, without undoing the fix.

The class dump that fix was built from was never dated. It has been now, using the markers
this project already records: `-autoScrollState` (410-only) is **absent** from it and
`IGSundialAutoScroll` (439-only) is **present**. So it is a 439 dump — and the lookup was
narrowed to a single accessor confirmed on 439 alone, on a tweak that serves 410, 439 and
441 from one build. If 410 spells that accessor differently, the badge stops appearing there
and says nothing about why.

`-user` is tried after `-userGQL` again. That is **not** a return to the twelve-key KVC
probe that caused the crash: `-respondsToSelector:` asks whether a real method exists, and
sending it calls that method and nothing else, where `-valueForKey:` falls back to reading
ivars and interrogates objects that have no such concept. Two named accessors on a view
already known to be an avatar is a different thing from guessing at everything up the
responder chain.

## v4.1.7

**On a multi-photo post, "Save this one" saved the first photo whatever you were looking
at.** Not an edge case — it did it every time, by design rather than by accident.

The line responsible assumed that if the media it resolved was not itself the carousel,
then it must be the slide on screen. On this build the action row resolves to the **post**,
so that test always failed and the code took its documented fallback: `children.firstObject`.
The first photo, always.

Nothing in the media model says which slide is visible, so it is now asked of the view that
knows. The dots under a carousel are `IGFeedItemPageControlMediaOverlay` and it answers
`-pageControlCurrentPage` — both confirmed in a class dump of this build rather than
guessed. The post's own view tree is searched for that overlay, and the slide at that index
is what gets saved.

A post with no page control to ask keeps the old behaviour rather than being handed an
invented index: something is still saved, which is better than nothing being saved.

"Save all" was never affected — it always took every child.

## v4.1.6

**Changing your profile picture crashed the app.** Reported from a device, and the cause was
the follow-status badge — a feature that never touches the profile picture at all.

Its user lookup probed twelve speculative keys with `-valueForKey:` — `user`,
`currentUser`, `displayedUser`, `profileUser`, `owner`, `account`, `viewModel`, `model`,
`dataSource` and more — on **every object up the responder chain**, two levels deep, from
inside `-layoutSubviews`. The comment above it claimed that was safe because a missing key
"just throws (caught)".

**That is not what `-valueForKey:` does.** It calls the real getter when one exists and
reads the ivar directly when one does not; raising is the last resort, not the first. So
every one of those keys was *executing Instagram's own code* — `dataSource` on a collection
view and `account` on Instagram's objects being the two worth naming — dozens of times a
second while the screen rebuilt. And `@catch` catches `NSException`; a Swift getter that
traps, a failed assertion or a half-initialised model are none of those, and end the
process with no handler involved. Changing a profile picture is exactly when those models
are mid-replacement.

There is now **no KVC in that lookup at all.** It asks for one selector, `-userGQL`, which a
class dump of this build confirms is on `IGProfilePictureImageView`, and only after
`-respondsToSelector:` says so; objects that do not answer it are stepped over rather than
interrogated. The responder walk stays, so the badge still follows the profile you are
actually looking at — only what it asks for changed.

Two things found alongside it:

- The avatar capture also asked for a key named `user`, which **is not on that class** —
  confirmed absent in the dump. It raised an exception on every layout pass and could never
  have returned anything.
- The profile picture's long-press recogniser was added in `-didMoveToSuperview` with no
  check, so re-parenting the avatar stacked another one each time. It is marked with an
  associated flag now — not by scanning for a long press, since Instagram attaches its own.

The badge, profile-picture saving and account-info copy all behave exactly as before.

## v4.1.5

- The tweak now states, in its own filter file, which Instagram versions it was last
  verified against — 410, 439 and 441. Albrhi Panel reads that and shows it beside the
  version on your phone, so a mismatch is visible before it becomes a question.


## v4.1.4

- **The switch in Settings actually works now.** Turning Albrhi off for an app moved
  the switch and changed nothing in the app: the tweak was asking the system for that
  setting and, from inside a sandboxed app, being told there was none — which it read
  as "leave everything on". It reads the setting itself now.
- Diagnostics shows what the switch is set to and where that was read from, so if it
  still does not take effect the page says why instead of leaving you guessing.

## v4.1.3

- **Brings back the reels download button**, and the reels progress bar with it. Both
  stopped working in 4.1.0 on the newer Instagram versions. The tweak was told to go
  looking for a part of Instagram by name instead of using the address it already
  had, and the search did not find it. It uses the address it has first now, and only
  searches if that stops working one day.
- Nothing was wrong on Instagram 410, which is why this was not caught sooner.

## v4.1.2

- Fixes the build again. 4.1.1 compiled but would not link, for a different reason
  than 4.1.0 failed. Neither reached anyone.
- The checks now catch this one too. Three build failures in a row came from the same
  change, and each time the check that would have caught it in a second did not exist
  yet. It does now.

## v4.1.1

- Fixes the build. 4.1.0 did not compile, so it never reached anyone — three of the
  files changed in it needed one more adjustment that the rest did not.
- The checks that run before every build now catch that particular mistake in a
  second, instead of five minutes into a compile.

## v4.1.0

- **Twenty-six features work again.** Instagram 439 rewrote a large part of the app in
  another language. Nothing was renamed and nothing was removed, but the tweak could
  no longer find those parts, so the features attached to them quietly stopped. There
  was no error and no crash — they simply did nothing, on 439 and on 441.
- Among them: hiding suggested accounts and suggested chats, clearing recent searches,
  hiding the stories tray, hiding Meta AI, note colours, the friends map, saving DM
  media, the settings shortcut, and confirmation prompts on likes.
- One more was broken and nobody knew: the note colour palette had been off since 439
  for the same reason.
- The tweak now finds these parts by name while the app runs instead of expecting them
  in a fixed place, so a future Instagram update is far less likely to switch features
  off without anyone noticing.

## v4.0.0

**The first stable release.** No longer a beta.

- **Instagram 441 is supported.** Checked feature by feature against 441 rather than
  assumed: the parts that matter were compared against 410 and 439 as well, so nothing
  was fixed for the new version by breaking it on the older ones.
- **Watching stories quietly is more dependable.** The part of Instagram that reports
  what you have seen was being found by a name that only matched the exact versions it
  was written for. It is now looked up properly, so an Instagram update is far less
  likely to switch this off without telling you.
- **Diagnostics now says whether that is switched on.** Before, "nothing blocked" could
  mean it was working and had nothing to block, or that it was not running at all.
  Those needed opposite fixes and looked identical. The page now says which.

## v3.8.2

- **Nothing changed in the app.** Every feature, setting and button is exactly where
  it was. This release only reorganises how the project is stored, so the same source
  can hold a second tweak for another app later on — a YouTube one is being started.
- If anything at all behaves differently from 3.8.1, that is a bug and not a change.
  Settings › Diagnostics writes the report.

## v3.8.1

- **Downloads survive losing signal.** A transfer cut off by the network now retries
  on its own and carries on from where it stopped, instead of failing outright. Up to
  three tries, spaced out. A download the server actually refuses still fails at once.

## v3.8.0

- **Settings search understands what you meant.** Type "حفظ" and the download settings
  come up; type "ads" with the tweak in Arabic and the ad settings come up. It works
  in either language and while you are still typing.

## v3.7.6

- Fixes the 3.7.5 build, which did not compile and so never shipped.

## v3.7.5

- Keeping unsent messages: the update Instagram sends keeps its contents behind
  getters rather than plain fields, so it is read that way now.

## v3.7.4

- Another go at keeping unsent messages: it was looking for the wrong field name
  inside the update Instagram sends. It now finds it by what it holds instead.

## v3.7.3

- Fixes the 3.7.2 build, which did not compile and so never shipped.

## v3.7.2

- The refresh warning now works on both Instagram versions.
- Diagnostics reports what an unsend update actually contained, so the last piece of
  keeping unsent messages can be finished.

## v3.7.1

- Ships the refresh warning that missed the 3.7.0 release.

## v3.7.0

- **Keeping unsent messages should finally work.** It had been watching the wrong
  channel: a message someone unsends arrives on Instagram's live connection, not
  through the part we were listening to. Beta, off by default, under Stories &
  messages — and Diagnostics now shows which channel it saw.
- **You're told when a refresh clears them.** Pulling to refresh reloads the chat from
  Instagram, which wipes anything kept only on your phone. It used to happen without
  a word.

## v3.6.2

- **The story eye now moves to the next story of the same person** instead of jumping
  to another account.
- **It turns green properly** once the view has been sent.
- **The reel's date is no longer cut off,** and sits beside the account name.

## v3.6.1

- Fixes the 3.6.0 build, which did not compile and so never shipped.

## v3.6.0

- **See when a reel was posted.** Instagram shows a date on posts but never on reels.
  Turn it on under Reels and it appears under the download button.
- **The eye button on stories now skips to the next one,** and turns green once the
  view has actually been sent — so you can tell it worked.
- **The quality list shows frame rate too**, so you can spot the 60 fps one.

## v3.5.2

- **The download button is back on reels** for the newer Instagram, where the sidebar
  it attaches to had been rewritten and Albrhi could no longer find it. The older
  version is unaffected.

## v3.5.1

- Fixes the 3.5.0 build, which did not compile and so never shipped.

## v3.5.0

- **Choose the video quality (beta).** Reels carry up to 2K, and Albrhi still takes
  the best automatically — that has not changed. Turn this on under Downloads and it
  asks instead, listing every resolution with its size, so you can take 1080p when 2K
  is more waiting and storage than you wanted.

## v3.4.2

- Diagnostics now reports how many video qualities a post really offers, and how many
  of them iPhone can actually save. Groundwork for bringing back the quality picker.

## v3.4.1

- **Confirmations appear straight away again.** Asking twice in a row could leave the
  second one waiting, and what you confirmed only started once the card had finished
  animating away. Both are fixed, and the card arrives quicker.
- The reels refresh confirmation is finally in your language.

## v3.4.0

- **The shortcuts show how things actually stand.** Each switch opens at what it is
  really set to, so you can turn things on *and* off from there, any time — not just
  switch them on once. There's a "turn all on" if you just want the lot.
- **The settings are in a more useful order:** downloads and privacy near the top,
  looks and behaviour further down.

## v3.3.9

- **The shortcuts now open a page you can edit.** Tapping one shows the handful of
  settings it covers, each with its own switch — turn them on or off as you like,
  then apply. Nothing outside that list is touched.
- The settings header no longer sits under the search bar.

## v3.3.8

- **A proper header at the top of the settings,** and four shortcuts under it:
  Private, Clean feed, Downloads, No prompts. One tap sets the handful of switches
  that case is about — and nothing else, so it is never a reset.

## v3.3.7

- **Check every feature at once.** Settings → Diagnostics → the checklist icon.
  It tells you which features still work on your Instagram version and which an
  update has broken — instead of you finding out days later.
- The what's-new page icons match what it says again.

## v3.3.6

- **Reels can scroll themselves.** When a reel ends, the next one comes up. There's a
  button on the reel screen to turn it on and off.
- **Choose your app icon** from the ones Instagram keeps for paid subscribers.
  Under Appearance.
- **Save a photo with its music** as a short video — pick the length, 5 seconds up
  to 90. Works on single photos and albums.
- **Keep messages people unsend** so they stay in the chat. Beta, off by default.
- **Watch stories invisibly without them repeating.** Your phone remembers what you
  watched; the author still sees nothing. The eye button marks one as seen and moves
  on.
- **Every "are you sure" looks better** and finally speaks your language.
- **Lighter and faster while scrolling.**
- Fixed a crash when using GIFs.

## v3.2.8

- **Save photos with their music as a video (beta).** Instagram plays audio over
  still photos in reels and in the feed, but saving one only ever gave you the
  picture. Now saving asks first — the photo on its own, or a clip with the sound
  at a length you pick, 5 seconds up to 90. Under Downloads, off by default.
- **Save voice messages (beta).** Long-press one and Albrhi asks whether to save
  it — it never saves without asking. Off by default, under Stories & messages.
- **Send any file in a DM (beta).** Adds "Send file" to the composer's plus
  button, so a PDF or a zip goes through like any other message. Off by default,
  under Stories & messages.

## v3.2.6

- **The sideload dylib now stands on its own.** It no longer needs CydiaSubstrate
  installed beside it, so it can be injected by TrollStore, SideStore, a
  certificate, LiveContainer or anything else — on its own. Jailbreak packages are
  unchanged.

## v3.2.5

- Fixed "couldn't check right now" when looking for updates.
- **Compatibility notice.** If your Instagram is newer than the version Albrhi was
  tested on, you'll be told once — nothing is disabled, but if something misbehaves
  you'll know why and how to report it.

## v3.2.4

- **Update notifications.** Albrhi now tells you when a newer version is out, and
  there's a "Check for updates" button in the settings. Jailbroken installs are
  pointed at the source, sideloaded ones at the new dylib. It contacts GitHub once
  a day and sends nothing about you — turn it off under Credits if you'd rather.

## v3.2.3

- **New Privacy page** — seen receipts, typing, screenshots and searches gathered in one place.
- **First-launch intro** — a quick "how to open the settings" welcome before the what's-new page.
- **Brand header** at the top of the settings.

## v3.2.2

- Album download choice can be turned off under Downloads.
- Transcode banner shows the full resolution and frame rate it's saving, e.g. "1440 × 2560 @ 60".

## v3.2.1 — a real leap

- **1080p downloads on device** — AV1 decoded with dav1d, re-encoded to H.264 with a live progress banner. Optional.
- **Full DASH quality ladder** — best saveable H.264/HEVC taken automatically.
- **Custom date & time formats** everywhere, incl. numeric relative times ("Active 4h ago").
- **OLED black theme.**
- **Full last-active time**, and **hide the voice / video call buttons** independently.
- **Backup & restore** all Albrhi settings to a file.
- **Search the settings** — find any toggle instantly.
- **Download whole albums** — pick this slide or all of them; **copy any text** (caption, comment, bio) by long-press.
- **Tidier settings** — grouped headers, search bar, language above the developer links, accent under Appearance.

_DM & date hook points from RyukGram (github.com/faroukbmiled/RyukGram, GPLv3)._

## v3.1.9.8

- **Full last-active now reads numeric relative times too.** "Active an hour ago"
  (and the Arabic "نشط منذ ساعة/ساعتين/٣ ساعات") used to be left untouched — only
  worded forms like "Yesterday" converted. It now parses Arabic units, dual forms and
  Arabic-Indic digits, and searches within the label instead of requiring an exact match.
- **Tidier settings.** Downloads and Stories & messages are grouped under clear
  headers (Downloading / Where files are saved / Video quality / Profile pictures;
  Messages / Last active & calls / Visual messages), and a dead empty section is gone.

## v3.1.9.7

- "Active yesterday" now becomes a real date too. Worded times carry no number,
  so the parser passed over them.

## v3.1.9.6

**New — Messages**
- **Keep deleted messages.** Preserves what others unsend. Pull-to-refresh in the
  inbox clears them.
- **Full last-active time.** A real date instead of "Active 2h ago", in whichever
  format you chose under Appearance.
- **Hide the voice and video call buttons** in a chat header, separately.

## v3.1.9.5

**New**
- **Custom date and time formats.** A real time instead of "2h" — presets, your
  own pattern, a time-only option, and a 12 or 24 hour clock. Under Appearance.
- **OLED black theme.** Turns Instagram's dark grey into true black.

## v3.1.8.8

- When Instagram offers the same resolution at both 30 and 60 fps, the transcode
  now picks 60 — it followed the source before but kept whichever the manifest
  listed first, so a 60 fps version could be missed. Output frame rate still
  matches the video; most clips are simply 30 fps at the source.

## v3.1.8.7

- The AV1 transcode now shows a modern floating banner at the top of the screen
  with a live progress bar, instead of a blocking centre spinner — you can keep
  scrolling reels while a clip transcodes behind it.

## v3.1.8.6

- Fixed the AV1 transcode hanging at "finishing". Video and audio are now written
  in parallel; feeding all the video first deadlocked the muxer, which will not
  drain video until audio covers the same span. Still experimental, off by default.

## v3.1.8.5

- The AV1 transcode from 3.1.8.4 could sit on "processing" indefinitely. It now
  shows a live frame count so progress is visible, cannot hang (every wait is
  bounded and the muxer bails the moment its writer fails), and reports the
  failing stage on the Diagnostics page. Still experimental and off by default.

## v3.1.8.4

- **Experimental: 1080p downloads via on-device transcoding.** Instagram serves
  its high-quality video as AV1, which iOS cannot save. Turn on "Transcode AV1 to
  1080p" in Downloads and Albrhi re-encodes it to H.264 on the device — no server,
  nothing sent anywhere. It is heavier on battery and slower, so it is off by
  default; when off, or if a transcode fails, downloads behave exactly as before.

## v3.1.8.3

- Video downloads now read Instagram's full DASH quality ladder, not just the
  single ready-made rendition. When a higher H.264/HEVC version is available it
  is taken automatically; otherwise nothing changes. Groundwork for saving the
  AV1-only qualities is in place but not yet switched on.

## v3.1.8.2

- The DASH diagnostic from 3.1.8.1 came back empty because it questioned only
  the video object, and because the names it looked for were guesses. It now
  asks the media object too, and asks the runtime which names exist instead of
  assuming. Diagnostics only — nothing else changes.

## v3.1.8.1

- Diagnostics now reports the DASH manifest Instagram serves for a video, and
  how many renditions it lists. Groundwork for improving download quality —
  nothing else changes.

## v3.1.8

No changes to the tweak. Published during work on the source repository.

## v3.1.7

No changes to the tweak. Published during work on the source repository.

## v3.1.6

- **The source address changed** to
  [ibrahim2100.github.io/albrhi-repo](https://ibrahim2100.github.io/albrhi-repo/).
  If you added the old one, add this instead.
- Albrhi now has a proper package page in Sileo, with the feature list, what
  changed, and version details.

## v3.1.5

**Fixed**
- **Smaller, faster builds.** Every release until now shipped as a debug build,
  carrying debug symbols and a `-1+debug` version suffix.

**New**
- Albrhi has its own source: add
  [ibrahim2100.github.io/albrhi-repo](https://ibrahim2100.github.io/albrhi-repo/)
  in Sileo or Zebra and updates arrive on their own.

## v3.1.4 — First public beta

**Fixed**
- **Mark-as-seen in DMs now actually sends the receipt.** One press marks the message
  you are looking at, and only that one — five view-once messages in a row stay
  unseen until you press each. It previously showed a green tick and sent nothing.
- Photo posts no longer fail with "could not extract URL": a photo still hands back
  an empty video object, and the download button was taking the video path.
- The inline download button appears on reels, above the like button.

**Removed**
Thirteen settings that were broken or pointless, rather than left to disappoint:
liquid glass buttons and surfaces, teen app icons, disable scrolling reels, doom
scrolling limits, the per-surface download toggles (the inline button replaces
them), long-press tuning, keep deleted messages, and the quality picker. Videos now
always download at the highest quality available.

**New**
- **Diagnostics page**, at the top level of settings. Reports which Instagram
  classes the tweak actually attached to on your build, and files a pre-filled
  GitHub issue in one tap.
- **Releases publish automatically** with both a `.deb` for jailbroken devices and a
  `.dylib` for sideloading, from a single build.
- Redesigned welcome screen, shown on first install and after each update.
- Verbose logging is now off by default and toggleable in Debug.

**Housekeeping**
- 92 orphaned translation keys removed; Arabic and English are at full parity.
- `tools/check.py` runs before every build: brace balance, duplicate interfaces,
  fragile `%orig` placement, multi-line string literals, missing imports,
  translation drift and version mismatch. Every rule exists because that exact
  mistake broke a build.

**Tested on Instagram 410.1.0** — the newest build the developer's phone will still
accept. Newer versions should work; reports from them are especially welcome.

## v3.0.28

**Changes**
- **Removed the on-screen ∞ auto-next button** from the reels action bar — the reels
  bar and its download button are back exactly as Instagram lays them out. Auto-advance
  is still toggleable from Reels settings.
- Follow-back badge now resolves the profile user via safe KVC (no crash), and shows
  correctly on the profile.

## v3.0.27

**New**
- **Auto-advance to the next reel.** When on, a finished reel scrolls to the next by
  itself (drives Instagram's own auto-scroll). Toggle in Reels settings, or with the
  ∞ button on the reels action bar, above the download button.

## v3.0.26

**Changes**
- **Quality picker removed; always downloads the highest quality automatically.** No
  more picker or toggles — every video download takes the best ready-to-play (muxed
  H.264 + audio) rendition Instagram offers. The higher DASH ladder is skipped for
  downloads because it's video-only/VP9-AV1 and won't save on iOS.

## v3.0.25

**Fixes**
- **Fixed a crash when opening a profile.** Removed the reflective ivar search that
  read arbitrary Swift ivars via `object_getIvar`. The follow badge now relies solely
  on the avatar's `-userGQL`, which is safe.

## v3.0.24

**Fixes**
- **Follow badge shows on the profile page itself** (under the followers count), no
  longer only when the profile picture is opened. The profile owner is captured from
  the header avatar's `-userGQL`, and the badge is placed on the Swift stats row.

## v3.0.23

**Fixes**
- **View-once "seen" eye is now per-message.** Marking one view-once message as seen
  no longer leaks to the next: each message opens unmarked, tapping the eye sends the
  seen receipt for that message only (on close), then resets.

## v3.0.22

**Fixes**
- **Picked-quality downloads no longer fail.** IG serves its high-res DASH ladder in
  VP9/AV1, which iOS can't save (the file opened as an image). Albrhi now keeps only
  H.264/HEVC renditions, so a picked quality actually downloads.
- **Zoom now enlarges properly.** Long-press floats an enlarged preview of the media
  over a dimmed backdrop (in-place scaling was clipped by the cell and looked wrong).
- **Long-press "download" option fully removed** — any leftover value migrates to Zoom.
- **Follow badge rebuilt for IG 410's Swift profile.** It hooks the Swift stats
  container and finds the profile user via the responder chain, then places the pill
  under the followers count (the old hook never fired on the new profile header).

## v3.0.21

**Fixes**
- **DASH quality labels were wrong** (e.g. "1421375×2560"): `width="…"` was matching
  inside `bandwidth="…"`. Added a word boundary so width/height parse correctly.

**Diagnostics**
- New "Last download URL" line records the exact URL a pick was downloaded from, to
  debug the "download failed" on picked qualities.

## v3.0.20

**Changes**
- **Removed download-by-long-press from settings.** Long-press action is now Zoom or
  Off only — downloads happen via the inline button (crash-prone press-save is gone).
- **View-once eye is now a "seen" action, not a feature switch** — clearer toasts.

**Fixes**
- **Follow badge no longer vanishes.** It anchors under the followers count when found
  and otherwise falls back to just below the avatar, and disables clipping so a tight
  stats container can't hide it.
- **DM save "could not find media"** — view-once save now routes through the shared
  coordinator (`downloadMedia`), and the permanent-media viewer reads the media off
  itself if the init capture missed.

## v3.0.19

**Fixes**
- Build fix: braced the zoom `switch` cases (blocks in a case need their own scope),
  which broke the v3.0.18 build.

## v3.0.18

**New**
- **Save button for view-once DM media.** The one-time photo/video viewer now has a
  save button (trailing) next to the mark-as-read eye — captures the media from the
  opened message and downloads it through the normal pipeline.

## v3.0.17

**Changes**
- **Follow-back badge now sits under the Followers count.** It anchors to the
  `user-detail-header-followers` stat button (found by accessibility id) instead of
  the avatar, and only appears on a real profile page — no more badge over the photo.

## v3.0.16

**New**
- **Mark-as-read eye in the view-once viewer.** Opening a view-once photo/video in
  DMs now shows an eye toggle: off = watch without registering as seen, on = mark it
  read. "Unlimited replay of visual messages" now defaults on so this works out of
  the box.

**Fixes**
- The visual-message hooks no longer swallow playback events when the feature is off.

## v3.0.15

**Changes**
- **Long-press is now Zoom by default.** Holding a post/reel/story peeks (zooms) it
  instead of downloading — download-by-press was crash-prone. New setting under
  Downloads → Long-press action: Zoom / Download / Off.

**Fixes**
- Quality downloads that resolve an extension-less URL (DASH BaseURLs) now default to
  `.mp4`/`.jpg`, fixing the save error after picking a resolution.
- DM save button is re-asserted on layout so the viewer's media can't bury it.

## v3.0.14

**New**
- **Save DM photos & videos.** Opening a photo or video in DMs now shows a Save
  button (and always allows saving, even when the sender disabled it). Saves route
  through the normal downloader, so the quality picker applies. Toggle under
  Stories & messages.

## v3.0.13

**Fixes**
- **Quality picker actually works now.** IG 410 keeps the resolution ladder in
  `-[IGVideo dashManifestData]`, which returns the manifest as **NSData**; Albrhi
  now decodes it and lists every resolution (1080p, etc.). Confirmed against the
  410 class dump.

**Changes**
- Follow-back badge moved to the right of the avatar, by the stats row (near the
  followers count).

## v3.0.12

**New**
- **Story download button.** A visible download button now sits in the story viewer
  (bottom-trailing) so stories save without needing the long-press gesture. Toggle
  under Stories & messages.

**Changes**
- Follow-back badge moved to sit below the avatar (near the stats), not on it.

**Quality picker / diagnostics**
- The DASH manifest is now located by reflection instead of guessed selector names,
  and the "DASH manifest" diagnostics line reports the candidate selectors a build
  actually exposes — so the real accessor can be pinned down on IG 410.

## v3.0.11

**Fixes**
- Build fix: declared the follow-badge helper selectors on `IGProfilePictureImageView`
  so the tweak compiles (v3.0.10 failed to build).

## v3.0.10

**Diagnostics**
- New "DASH manifest" line under Last video download: reports whether the manifest
  is reachable on this build and how many video resolutions it yields.

**New**
- **Follow-back badge on profiles.** A colored pill now sits on the profile-header
  avatar — green "Follows you" or red "Doesn't follow you" — visible directly on the
  profile, no long-press needed, and suppressed on your own profile.

**Fixes**
- **Quality picker — the real fix.** On Instagram 410 `videoVersions` returns a
  single progressive rendition (e.g. 720p), so the picker had nothing to offer. The
  higher resolutions live in the **DASH manifest**; Albrhi now parses it and lists
  every real quality (1080p, etc.). When a video genuinely has one quality, no
  picker appears — by design.

## v3.0.8

**Localization**
- Full Arabic pass: every settings page, section header, dropdown menu, stepper
  label and DM seen/replay toast is now localized — no hard-coded English left in
  the settings UI.

**New**
- **Follow-back status.** Long-press a profile picture to see whether that account
  follows you ("Follows you" / "Doesn't follow you"), and it's added to the copied
  account info. Toggle under Downloads → Show follow-back status.

**Fixes**
- Quality picker now applies to **story videos** too. They previously resolved a
  single URL directly and skipped the picker; they now route through the same
  coordinator as feed and reels.
- More robust rendition extraction: broader set of URL accessors, and a last-resort
  picker built from `allVideoURLs` when a build exposes no resolution metadata.

## v3.0.1

**Fixes**
- **Quality picker now actually runs.** `show_quality_picker` was never registered as a
  default, so it sat off for everyone regardless of the toggle. It now defaults on.
- Every download path — feed, reels, stories and the inline button — routes through one
  coordinator, so the picker applies everywhere instead of feed videos only.
- Quality list falls back to `sortedVideoURLsBySize` on builds without `videoVersions`, and
  duplicate renditions served from different CDNs are collapsed.

**New**
- **Welcome / What's New screen** on first install and after every update.
- **Mark-as-seen button** — an eye toggle in the story viewer. Off means invisible viewing as
  before; on means the story you're watching registers as seen.
- **Diagnostics page** (Settings → Debug) reporting which action-row classes exist in your
  Instagram build, where the download button attached, how many renditions the last video
  offered, and how many seen receipts were blocked. Copyable as a report.

**Known issues**
- The inline download button still does not appear on some builds. The diagnostics page exists
  to identify which class the action row uses on the affected device.

## v3.0.0 — Foundation rebuild

**Download Center**
- Full download queue on a background `NSURLSession` — transfers continue after you leave the app.
- Real pause and resume via resume data: a paused transfer continues where it stopped.
- Retry, cancel, concurrency limit (`dl_max_concurrent`), duplicate detection and a persistent
  history of the last 250 downloads.
- New Download Center screen: live progress rings, search, filter by media kind, sorting, swipe
  actions, context menus and bulk controls.

**Inline download button**
- A native download icon in the post action row, next to save (`inline_download_button`,
  on by default). One tap replaces the long press.
- Routes into the queue when `dl_use_queue` is on, otherwise uses the original HUD flow.

**Architecture**
- Settings are now self-registering: each page lives in its own file under `Settings/Pages/` and
  declares itself through `SCISettingsRegistry`. `TweakSettings.m` dropped from 550 lines to a thin
  composer, and adding or deleting a feature no longer touches shared files.
- Removed the leftover example section and demo menu from the upstream project.

**Identity**
- Developer links — Instagram, Snapchat and Telegram accounts open directly from Settings.
- Credits attribute Ibrahim Ismail AL-Rahn and link to this repository; SCInsta remains credited
  as the upstream project under GPLv3.
- Professional package description for Sileo, and a fully rewritten README.

**Fixes**
- Fixed a race where pausing a download recorded it as cancelled and lost the transfer.
- Fixed the CI version parser, which could pick up any line containing `Version:` from the new
  multi-line package description.

## v2.3.0
- Initial inline download and identity work, superseded by v3.0.0.

## v2.2.0
New features (all verified against the class-dump of Instagram 409):
- **Choose quality before download** — pick from available resolutions (`show_quality_picker`).
- **Reel audio download** — choose video or audio-only when saving a reel (`dw_reel_audio`).
- **Silent video** — strip the audio track from downloaded videos via AVFoundation (`dw_silent_video`).
- **Copy account info** — long-press a profile picture to copy username, name, and verified status (`copy_account_info`).
- **Custom "Albrhi" album** — organize saved media into a dedicated Photos album (`custom_album`).
- **Custom accent color** — system color picker + reset; persists as hex (`albrhi_accent_hex`).
- **Real verified detection** — uses `computedIsVerified`.

## v2.1.0
- Correct video-quality selection using `IGAPIVideoVersion` (width/height/bandwidth).
- HD profile pictures via `HDMultipleProfilePicURLs` / `HDProfilePicURL`.
- Save directly to Photos option.

## v2.0.0
- Rebranded SCInsta → **Albrhi** (burnt-orange accent, credits, version).
- Full bilingual (Arabic/English) UI with automatic RTL.
- Reorganized settings; Language + Appearance sections.

Based on SCInsta by SoCuul — GPLv3.
