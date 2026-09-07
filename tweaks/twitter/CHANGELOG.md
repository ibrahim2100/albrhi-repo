# Albrhi for X — what changed

## v0.18.5

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

## v0.18.4

**«إخفاء المساحات» كان يعطّلها لا يخفيها، وهذا بلاغ من جهاز.** فتح مساحة يرسلها أحدهم كان
يردّ «غير متوفرة».

**Hiding a section is not switching a capability off, and this feature was doing both.**
`voice_rooms_consumption_enabled: NO` tells X this account may not *listen* to a Space at all,
so a link somebody sends comes back "unavailable" — a broken app rather than a tidy timeline.
`audio_articles_enabled` is the same shape one surface over: an article that will not play.
Both keys are gone.

What actually hides the strip has never been a feature switch: `-_t1_initializeFleets` is
withheld, and the tab is removed by its own `audiospace` entry. Two surfaces, neither of which
decides whether Spaces work when you ask for one deliberately.

**Measured rather than reasoned about.** BHTwitter 4.5 hides the same strip through the same
selector and names the same `audiospace` tab, and carries **none** of these four keys anywhere
in its binary — a hide that has worked for years never touches the capability, which is the
whole finding. Read for architecture only, as every unlicensed reference here is.

The two keys kept are gates on *surfaces*: the button that starts a Space, and the avatar ring
that advertises one in the timeline. The row now says exactly that, in both languages, instead
of promising to remove spoken articles.

## v0.18.3

**"Free" is out of every description.** The tweak needs a licence; a package page saying it is
free was the first thing anybody read. The licence itself is unchanged and still named in full —
GPLv3 where it applies, MIT for the Watch pairing core — because dropping a word is not the same
as dropping an obligation, and the attribution those licences require is not negotiable.

## v0.18.2

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

`SCIPrefHidePromotedTrends` is deleted. Promoted trends are hidden by the main switch — the same
discovery on a sibling surface — and the key was defined here and read by nothing, which is the
shape this project already refuses: a key that decides nothing reads as a feature that broke.

## v0.18.1

**Two switches for one intention, twice over — and one pair was sitting next to itself on the same
page.**

*Who to follow* had two: `hide_suggested_accounts`, which hid **every** `T1UserRecommendationView`
in the app, and the timeline filter, which recognises the suggestion's own view model. The first
existed because nothing in a class dump says where X uses that class, so it could only hide all of
them or none — and the device reported `0 hidden` for it. It is gone; the filter does the same job
by knowing what it is looking at.

*The view count* had two as well, on different pages: a named feature answering
`view_counts_public_visibility_enabled` — a question X asks nearly four thousand times in a session
— and a switch that hid the analytics button after X had drawn it. The feature wins for a reason
beyond tidiness: `TTAStatusInlineActionsView` lays its buttons out by hand, so a hidden one can
leave its space behind, while a count that is never drawn leaves nothing.

Both removals take the preference with them, so nothing is left storing a value no code reads.

## v0.18.0

**Opening links in Safari is a feature switch, not a browser class — and the device report said so
after three releases of hooking the wrong thing.**

The sequence is worth keeping. 0.17.2 fixed how the URL was read from `SFSafariViewController`;
the feature still did nothing, because X names that class **once** in all its binaries. 0.17.5 moved
to `T1WebViewController`; still nothing, because what X presents is a preloaded sibling. 0.17.6
moved to their shared base and recorded every class it turned away — and the report came back
**`0 left to X`**. Not "the wrong class went past": *nothing* went past.
`-_t1_loadInitialURL` is never called at all.

The same report, further down, has `ios_in_app_article_webview_enabled` **asked 72 times and
answered on**. That is the decision, and X makes it long before any browser object exists to hook.
Answering it is what the switch layer in this tweak has done successfully for 422 keys across
217,869 questions on this very device.

So it is a named feature now, beside the others, and the standalone preference is gone — **one
answer to one question.** The browser hooks stay, asking the feature rather than a preference of
their own: they cost nothing and cover a build that starts routing links through a class after all.

**Three releases were spent on classes because the question looked like a class question.** The
recorder was built for exactly this, its report had the answer in it, and nobody read that far.

## v0.17.6

**Confirmed working: the post-as-a-picture is no longer mirrored.** The measured flip correction was
right, and that feature is done.

**Links still opened in the app, because the class X presents for a tapped link is not the one that
was hooked.** 0.17.5 hooked `T1WebViewController` and compared the exact class; what X actually
shows is a *preloaded* controller — a different class descending from the same base, so the compare
turned it away.

The hook is on `T1BaseWebViewController` now, which is where `-_t1_loadInitialURL` and `rootURL` are
declared and therefore the one place that sees every one of the twenty-six controllers descending
from it.

**Which of those are treated as links is an allow list, and that is the whole safety of the
feature.** Most of those classes are not links at all: the bouncer, the login challenge and the
password reset are sign-in; Stripe, payments and the one-dollar screen are billing; analytics,
Birdwatch, the business application, jobs settings and the bio editor are ordinary app screens that
happen to be drawn with a web view. **A deny list would send a class added by a future X update
straight to Safari** until somebody remembered to add it; an allow list leaves it alone until
somebody looks.

**And every class turned away is now recorded by name in the report** — the question two releases
have been spent guessing at. If a link still opens in the app, the report says which class opened
it.

## v0.17.5

**Opening links in Safari was hooking the wrong class entirely.**

0.17.2 fixed *how* the URL was read from `SFSafariViewController`, and the feature still did nothing
— because X barely uses that class. The name appears **once** across its binaries. Fixing the read
was fixing a detail of a hook that was never going to fire, which is what happens when a fault is
repaired without first checking that the thing being repaired is the thing being used.

X's own browser is `T1WebViewController`, and `-_t1_loadInitialURL` on its base is the moment before
the page is fetched, with the address already in `rootURL`. That is the hook now: the link goes to
Safari and the browser is taken off screen without loading anything. Presented and pushed are both
undone, because a link from the timeline is presented and one from a profile is pushed.

**Only the plain browser, never a subclass.** `T1BouncerWebViewController`,
`T1LoginChallengeWebViewController`, `T1MonetizationWebViewController` and the rest descend from the
same base and are sign-in, verification and billing flows, each carrying session state. Sending
those to Safari would not be this feature, it would be breaking the ability to log in — so the exact
class is compared rather than `-isKindOfClass:`, and the report counts how many were deliberately
left to X.

The `SFSafariViewController` hook stays. It costs nothing and covers a build that starts using it.

## v0.17.4

**It was a mirror after all, and the emblem in the picture is what proved it.**

0.17.3 read the description — the share button on the wrong side, Arabic reading from the wrong
end — as a re-layout, and argued that a mirrored image would have mirrored the glyphs. The picture
itself settled it: the post's own photograph was mirrored, `@SaudiDCD` came out as `DCDibuaS@` with
the letters reversed, and **re-layout cannot reverse a bitmap.** A description of a fault is
evidence; a picture of it is proof, and the two disagreed.

**UIKit mirrors right-to-left content with a transform, and `-renderInContext:` does not apply the
receiver's own.** On screen the subtree is laid out one way and flipped by a transform above it,
which reads correctly. Rendered without that transform it is the raw, unflipped arrangement —
mirrored — with the bitmaps included, because they are stored pre-mirrored to survive the flip.

**The correction is measured, not assumed.** Two points of the subject's own bounds are converted
into window coordinates: if its left edge lands to the right of its right edge, everything between
it and the window is mirrored — whatever applied the flip and wherever it sits in the ancestry. The
context is flipped to match before anything is drawn. A build that stops mirroring this way measures
as not mirrored, nothing is applied, and the correction cannot become the next bug. The report counts
how many pictures needed it.

## v0.17.3

**The post-as-a-picture came out laid out left-to-right, and the description of the fault is what
solved it.**

Reported precisely: the share button sits at the bottom **left** on screen and appeared at the
bottom **right** in the picture, and the letters were the right way round but read from the wrong
end — «تابع» starting at its last letter. That rules out a mirror in one line: a mirrored image
mirrors the glyphs too, and these were correct. What moved was the *layout*.

**UIKit implements right-to-left as mirrored layout, decided at layout time from the view's trait
environment.** An image context has no window and no traits, so a hierarchy asked to draw itself
there resolves as left-to-right and rebuilds the entire subtree the other way round — the button
included. The text follows: re-laid-out runs are given an LTR base direction, so a word reads from
its last letter.

`-drawViewHierarchyInRect:afterScreenUpdates:YES` asks for exactly that re-layout, and 0.17.2
switched it on for a real and unrelated reason. **The answer is not to re-lay-out at all.**
`-renderInContext:` walks the layer tree and draws what each layer already holds — text rasterised
while the view was on screen, in the order it was drawn there. There is no layout pass to get the
direction wrong and nothing for the bidirectional algorithm to redo.

The hierarchy call stays as a fallback for a layer tree that renders nothing — a visual effect view
is the usual reason — and uses `NO`, which does not re-lay-out either. Whether the fallback ran is
decided by sampling nine points of the result for a non-zero alpha rather than by scanning every
pixel, since this runs on the main thread while a finger is held down. The report says which path
drew each picture.

## v0.17.2

**Opening links in Safari did nothing, every time, and said nothing about it.**

The hook asked `SFSafariViewController` for `initialURL` with KVC. That is not a name the
class exposes, so the answer was always nil — and a missing URL was treated as "leave this one
alone", which is the branch that ran for every link ever opened. **A fallback for an unlikely case
was the code path for the only case**, and the report had no line that would have shown it.

The URL is taken from the initialiser now, where it is certainly in hand: both `-initWithURL:` and
`-initWithURL:configuration:` are hooked, because X may call either, and the URL is kept on the
controller itself. The report counts links opened *and* controllers that arrived with no URL, so
that state can never be silent again.

**And the post-as-a-picture renderer was making the same class of mistake one level down.**
`-drawViewHierarchyInRect:afterScreenUpdates:NO` does not copy what is on screen — it asks the
render server for whatever it last held for those layers, which for a view not composited in its
current state is stale or incomplete. It is also the call every tweak offering this feature uses.
It is `YES` now, after an explicit layout pass, and **its BOOL return is checked** rather than
discarded: a failed draw falls back to rendering the layer, which copies each layer's own
rasterised contents and cannot re-lay-out anything.

**Whether that fixes Arabic coming out reversed is not claimed.** Two different faults produce that
complaint and they need opposite repairs — a *mirrored* image, where the avatar and icons are
flipped as well, versus *reordered* text, where the pictures are fine and only the letters are out
of order. The report now names which path drew the picture, so the next round starts from a fact
rather than from a guess.

## v0.17.1

**The settings are pages now, the way the YouTube tweak's are** — a first screen listing eight
categories, each opening its own screen, each built by its own file.

0.17.0 split the screen into a file per section, which was half the job: the files were separate
and the *screen* was not. Nine sections and something over thirty rows in one table meant finding
the link cleaner took scrolling past the save button, the timeline filters, the feature list and the
diagnostics. Every one of those is now a row that opens onto its own page.

**One class draws every row, on both screens.** `SCITWTable` holds the rendering and the first
screen and every page inherit it, differing only in what `-buildSections` returns — drawing a switch
in two places is how one of them ends up with a font the other has not got.

**A page with nothing in it is not listed at all.** That is how the feature page disappears when the
switch layer is off, rather than offering a screen of switches that decide nothing, and how a page
for a class this build does not carry never opens onto an empty table. Both screens rebuild on
appearing, so a count on a diagnostics row is current and a page that stopped applying while it was
closed is gone when you come back.

The switch layer stays on the first screen, above the list, drawn as the heading it is.

## v0.17.0

**Fifteen features, and a settings screen rebuilt from scratch around them.**

Every one was read out of BHTwitter's own source for *where* it lives — that repository ships
**no LICENCE file**, so it is architecture only, copied from in no part. The same line this project
draws at carsurf, NA9 and VibeTok, and the opposite of what GPLv3 allowed for NextUp.

**Links and privacy.** Copied `x.com` links have `s` and `t` stripped — the two parameters that name
the account a link was shared from. A `t.co` can be shown as where it actually goes. Links can open
in Safari instead of X's own browser. The search box can stop offering what was typed before,
withheld at `-setRecentQueries:` so nothing is drawn and then un-drawn. And the app can be put behind
Face ID: **the cover goes up before the prompt**, so nothing is on screen while the question is
asked, and a device that can evaluate neither biometry nor a passcode is let straight through rather
than left staring at a cover it cannot dismiss.

**Between the posts.** Who to follow, topics and trend videos, refused at
`TFNItemsDataViewController -tableViewCellForItem:atIndexPath:` — one hook for every list X draws,
matching the *class of the view model* rather than reaching into a view hierarchy. Cells are shown
as well as hidden on each pass, because they are reused and writing only the hiding branch is how a
working filter starts eating the timeline.

**On a post.** The view count and the bookmark button can be hidden, and a long press on share
renders the post as an image. A confirmation can be asked before a like and before a follow —
**never before an unlike or an unfollow**, since nobody asked to be protected from taking something
back.

**Extras.** The undo-post toast forced on, bio translation always offered, X's own high-quality
upload setting shown, and a single photo drawn whole instead of cropped — gated on attachment type 2
so videos and grids are untouched. Left-to-right text is there as asked for, marked cautious and
last: the working language here is Arabic and it changes the direction of everything X draws.

**Four of BHTwitter's are deliberately absent, and that is a finding rather than an omission.**
`_t1_showPremiumUpsellIfNeeded`, `-isVODCaptionsEnabled` and
`TFNTableView -setShowsVerticalScrollIndicator:` are not in X 12.20 at all — checked against the
app's own class metadata. Clearing the cache at launch was left out rather than shipped as something
that deletes files to no measured benefit. **A switch that decides nothing is worse than a missing
one**: it reads as a feature that does not work.

Two class names had moved and were caught the same way: the upload configuration is
`TTMUploadConfiguration` here, not `TFNTwitterMediaUploadConfiguration`, and the typeahead is
`TTSSearchTypeaheadViewController`, not `T1SearchTypeaheadViewController`.

**The settings screen is a registry now, one file per section.** What it replaces addressed its rows
by index — five section constants, seven row constants, a hand-written row count and a `switch` per
section deciding what each number meant. Three lists of one truth, which is the exact shape that
crashed the YouTube Music settings screen. A row now carries its own title, preference key and
action; a section's length is `rows.count`; and a section registers itself in `+load`, so adding a
feature adds a file and deleting the file deletes the section. A builder returning no rows is not
drawn, which is how the feature list disappears when the switch layer is off rather than sitting
there deciding nothing.

**And the switch layer heads the screen instead of ending it.** It was the last row under Advanced,
which was the wrong way round: every other section is a thing you choose, while this one decides
whether a section of the screen exists at all. It is drawn as the heading it is — a larger badge, a
bold title, a tinted panel — through a `prominent` flag on the row model rather than a design
special-cased for one switch, so a later row that governs what is under it can be raised the same
way.

## v0.16.2

**"Hide Spaces" was aiming at the wrong surface for two releases, and the surface was never a
tab.** 0.16.0 excluded the Spaces tab entry, 0.16.1 filtered the tab bar itself; both do exactly
what they say, and neither touches the row of live audio rooms above the Home timeline, which is
what the switch was always about.

That strip is set up by **`-_t1_initializeFleets`** — named for Fleets, the feature that once
occupied it — and refusing to make the call means the bar is never built. Withheld rather than
emptied: nothing downstream is handed a half-built bar, which is the distinction between refusing a
delivery and feeding nil into a state machine that expects one.

Confirmed against X 12.20 rather than carried over: the method is `v16@0:8` on
`THFHomeTimelineItemsViewController`, in the **main executable** and not in `T1Twitter.framework`.
Its older sibling `T1HomeTimelineItemsViewController` is not in this build at all; it is hooked
anyway for older versions, and each class is checked with `class_getInstanceMethod` before its group
is initialised — because a `%hook` on a method a class does not declare **adds** it, which would
invent an API X never calls.

The tab work from the two previous releases stays. It is correct, it is what put Communities and
Profile in the bar, and it is a second surface rather than a mistake to undo.

## v0.16.1

**Hiding Spaces at the tab entry failed for the same reason the feature switch did, one layer
down.** Communities and Profile appeared on a device in 0.16.0 and Spaces did not, which is the
part worth explaining: `-isExcludedFromTabBar` is consulted while X composes the set of tabs it
*could* show. An account that already has a saved bar keeps the bar it saved — so excluding an
entry changes what a **new** account would be given and nothing else, exactly as
`ios_tab_bar_default_show_communities` did. Adding to the set works; removing from it does not.

So the final array is filtered too. `-setTabViews:` on `T1TabBarViewController` is the last point
at which the bar is told what to draw, after any saved configuration, and each `T1TabView` carries
`scribePage` — the tab's own stable name. The Spaces tab is **`audiospace`**, a token X itself
carries rather than a name invented here.

**The filter refuses to hand back an empty bar.** A wrong token would otherwise leave the app with
no navigation at all, which is the same rule that keeps the download button visible when a lookup
fails: refusing belongs at the irreversible action, never where it can remove the way out.

**And the report now prints every tab name the bar actually carried.** If a build calls the Spaces
tab something else, one report says so — instead of another round of guessing at tokens.


## v0.16.0

**Hide Spaces and More tabs were pulling the wrong lever, and 0.15.0's report is what said so.**

Both were built entirely as feature-switch overrides, and the per-key evidence added last release
showed neither switch was failing to apply:

- `voice_rooms_consumption_enabled` was asked **784 times** and answered `NO` every time, and the
  Spaces tab stayed exactly where it was. A key X consults constantly and still ignores for this
  surface is not the gate.
- `ios_tab_bar_default_show_communities` was asked **twice**, and its own name carries `default`:
  it seeds the bar a new account starts with. A saved tab configuration wins ever after, which is
  why the switch did nothing on an account that has one — that is to say, on every real account.

**X 12.20's own class metadata names the real decision.** Every tab in the bottom bar is an
`…AppNavigationTabEntry` — Home, Communities, Profile, Voice, Grok, fifteen more — and each answers
`-isExcludedFromTabBar` (`B16@0:8`) and `-isTabViewSideBarOnly`. One BOOL per tab, asked by X
itself. So the two switches are enforced there instead: **Hide Spaces** excludes the Voice entry,
**More tabs** includes Communities and Profile. Their feature-switch keys are untouched and still
apply, since they cover surfaces beyond the tab bar.

Both getters are forced together on purpose. `-isTabViewSideBarOnly` is the iPad half of the same
decision, and a tab admitted to the bar while still marked sidebar-only appears on one device and
not the other.

**And the report separates the three ways this can come back empty**, because they need three
different answers: the class not being in this build, the hook attaching and X never consulting it,
and the getter being asked and answered. Silence meaning any of the three is what cost the previous
two releases.


## v0.15.0

**The report now says what a switched-on feature actually did, key by key** — because *the option
does not work* has three causes and nothing here could tell them apart.

For every feature that is on, each of its keys is listed with how often X asked for it, what the app
answered, and what Albrhi answers instead. That separates:

- **the feature is off** — it says so;
- **it is on and X never asks that key** — `never asked`, so the key is inert on this build and a
  different one is needed;
- **it is on, X asks, and we answer** — the key works and *the thing on screen is not decided by
  it*. Only this third case justifies a new hook, and only this case was indistinguishable before.

Two features were reported as not working, and the measurement already narrows them.
`voice_rooms_consumption_enabled` is asked **784 times** in a session, so *Hide Spaces* is being
applied and whatever remains on screen comes from somewhere else — a module the server injects,
not a client switch. And `ios_tab_bar_default_show_communities` is asked **twice**, with `default`
in its name: it seeds the tab bar's initial state, so flipping it after first launch cannot add a
tab. **Neither is fixed by a better key**, and this release does not pretend otherwise.

This project has recorded the same rule twice — a diagnostic that logged the last event instead of a
tally, and a counter sitting off the path that runs. **A report that cannot separate causes sends
the next release at the wrong one**, which cost the TikTok download button three of them.

## v0.14.0

**Three of the four save-button surfaces, removed.** Reported from a device: the save
button was appearing twice on an ordinary post — once on the corner of the media itself,
once after X's own share button in the action row — and a third and fourth surface could
join them inside the immersive video player. All four were installed at once, each one
built as a fallback in case a previous surface stopped working after an X update, and the
result read as broken rather than thorough.

Removed: the corner-of-the-picture overlay (`SCITWStatusButton`/`SCITWInlineButton`, on
every video and photo view X draws) and the action-row button after share
(`SCITWActionBarButton`). **Kept, unchanged: the button inside the video** — the immersive
player's own control surface, the one that was actually asked for originally, pinned
inside the picture and staying with it while you swipe to the next clip. It is now the
only surface this tweak installs, so it is also the only place a save button appears —
open a video full-screen to save it, rather than from the timeline directly.

## v0.13.0

Four more, out of six that were looked into -- and two honest no's, said plainly rather
than shipped as guesses.

**Confirm before Retweet.** Off by default. One more tap before a repost goes out, the
same reasoning behind every confirmation this project has already shipped: a mis-tap here
reaches every follower, and there is no undo that un-notifies whoever already saw it.

**Save a profile photo.** Tap someone's avatar to open it, the same as always, and this
now also offers to save it. On by default -- it only asks, it never saves without a
second tap.

**"Who to follow" cards can be hidden -- and it says plainly that it is blunt.** The class
that draws one is confirmed real; where X actually uses it is not, so this hides every
card it draws rather than only the unwanted kind. Off by default, named as experimental,
and the settings row says exactly what it cannot yet tell apart.

**Picture-in-picture could not honestly ship as a working switch, so it did not.** The
setting exists -- `nativePictureInPictureBehavior` -- but it is a private numeric code with
no meaning named anywhere in this class dump, set through a fifteen-argument initialiser.
Forcing a guessed number into it risks disabling the player instead of turning PIP on, which
is not a risk worth a silent toggle. What shipped instead is a recorder: it counts every
value X sets on its own, so a real switch can be built from what a report says rather than
from a guess -- the same discipline the switch layer itself was built on.

**And two were looked into and not shipped.** Extending the promoted-tweet filter to
trends found the right classes -- `TwitterURT.PromotableTrend` really does carry
`-isPromoted` -- but neither `TrendView` nor `URTTimelineTrendCell` exposes any way to
reach it from this class dump; nothing here says how. Hooking `TFNTwitterAccount`'s own
boolean methods (`isPremiumTierUser`, `isTweetPromoteButtonEnabled`, and a dozen more) was
raised only as a research question, not a feature -- forcing any of them without knowing
what reads the answer risks breaking premium-gated screens this project has no way to
audit without a device, and that is not a trade made blind.

## v0.12.0

**"Hide ads" was never going to touch a real Promoted Tweet, and now something does.**

The seventeen named features include one called Hide ads, and what it turns off is a set of
`ssp_ads_*` switches — third-party ad-SDK integration points, asked a handful of times a
session, the shape of a check made once per screen rather than once per post. **None of them
gate a Promoted Tweet in the timeline.** That is an ordinary post, the same class every tweet
is, carrying `-isPromoted` = YES straight from the server as part of the timeline response.
No client switch can make the server stop sending it.

**A new, separate, experimental switch hides it where it is drawn instead** — Settings ›
Hide Promoted Tweets, off by default. It can leave an empty gap where the post was rather
than closing the row, and it has not been confirmed on a device: the class names and the
property are read from a real class dump, whether X actually routes a promoted status
through them on 12.15 is what the next report answers. The diagnostics page counts both how
many statuses were checked and how many were hidden, so the report says plainly whether it
attached to anything rather than staying silent either way.

**And the raw switch list moved to its own page.** Three hundred and fifty-plus monospaced
rows used to be the last section of this screen, in full, every time it opened — a wall
past the six things anyone actually came to change. It is one tap away now, from a single
row that just says how many there are, and the search box and the All/Changed filter moved
with it rather than being lost.

## v0.11.0

**The settings screen, redrawn with an icon beside every row — the way iOS's own Settings
app draws its rows.** Each control, feature and status line now carries a small coloured
badge rather than plain text alone, which is the single biggest thing that made past
versions of this screen look like a debug page rather than part of the phone.

**Saved media moved up**, right under the three quick switches and ahead of the seventeen
named features. Saving a video or a photo is the reason this tweak exists in the first
place, and a screen that made that scroll past a wall of switch names first was arranging
itself around what was easy to list rather than around what someone opened it to do.

**Pull to refresh** re-reads what has been seen and saved since the screen opened — nothing
here reaches a network, so the spinner is brief and honest rather than theatre over a wait.

The raw switch list at the bottom keeps its plain, dense rows on purpose: it is a search
tool over 350-plus entries, and an icon repeated that many times would be noise, not polish.

## v0.10.1

**The in-video button jumped back to its old place after the first swipe**, and the cause
was mine: two surfaces were adding a button under the *same tag*. The card placed one 72
points down, and `ImmersiveVideoPageView` placed another at the original spot behind X's
back chevron. The first video showed the card's; swiping brought the page's forward.

The page surface is removed outright rather than realigned. It was never seen — 0.9.0 added
seven buttons there and showed none, because it sits underneath the whole plugin stack —
so it was contributing nothing but a misplaced duplicate. `ImmersiveCardView` is the surface
that works, and it is now the only one.

## v0.10.0

**The settings screen, redesigned.**

It opened onto a search field and a segmented control stacked in a plain header — two
controls, and no answer to the first question anyone opening it has: *is this thing even
attached?*

**A status card at the top now answers it.** The tweak's mark, its version beside X's own,
and three pills — Switches, Recording, Media — each green or red. Never grey: "unknown" is
not a state this screen can honestly report. They are read from the data the screen has
already loaded, so the card can never disagree with the list beneath it, which is how every
status display that keeps its own copy eventually lies.

**Search moved to the navigation bar**, where iOS puts it. It used to sit in the table
header and scroll away with the content — taking the only way of finding one key among 355
with it. It is pinned under the title now and reachable at any scroll position.

**The All/Changed filter is kept**, as the search bar's own scopes rather than a second
control. Same two choices, on the control iOS provides for exactly this, appearing with the
keyboard instead of taking a row of the screen from everyone who is not searching.

The card is built from stack views inside one rounded container, with no constraint between
siblings that a stack does not own — the arrangement that has taken this project's settings
screens down twice.

## v0.9.2

**The in-video button appeared — and landed behind X's back chevron.** The top-left corner
belongs to X, so the save button was only reachable when the chevron happened to be hidden,
which is what "its position is wrong while swiping" was describing.

It sits 72 points lower now: enough to clear a 44-point control and its inset, measured from
the safe area rather than the top of the view so it lands in the same place on a device with
a notch and one without.

## v0.9.1

**The button goes on `ImmersiveCardView` — the surface TWIGalaxy actually uses.**

0.9.0 added seven buttons to `ImmersiveVideoPageView` and showed none, which is the same
shape of failure as the rail's eleven. Rather than reason about the hierarchy a fourth time,
TWIGalaxy's own package was unpacked and read: every X class its binary names is in
`__cstring`, and of the immersive family there are exactly **two** —
`ImmersiveInlinePlaybackButtonsStackView`, which is not in X 12.15, and **`ImmersiveCardView`,
which is.** So its working in-video button can only be on the card.

That explains what three of our surfaces could not. The card is the *container* for one
video — `-playerView`, `-status`, `-playerSessionProducer`, `-handleSingleTap:` — and the
plugin overlays are **its own children**. A button added to the card and raised each layout
pass sits above them. `ImmersiveVideoPageView` sits underneath that whole stack, so a button
there is behind `ImmersiveProfileSwipePluginView` and its 390×844 of full-screen gesture
layer, where it can be neither seen nor tapped.

It needs no walk either: the card answers `-status`, so it is its own model — the fix 0.7.1
already made to the shared lookup pays for itself here.

Diagnostics reports the card and the page separately, so if this is still wrong the next
report says which of the two attached and how many each placed.

## v0.9.0

**A save button pinned inside the video, that stays with that video while you swipe.**

0.8.0 put a button on X's own action row, and that one is reliable — but the action row
belongs to the *screen*, not to the clip. What was asked for is a button in the picture,
travelling with the video it belongs to. That is a third surface, not a nicer version of the
second.

`ImmersiveVideoPageView` is the per-video page in the immersive pager: one instance per clip,
carrying that clip's player. A subview added there is inside the video's own frame and moves
with the page when you swipe, because the page *is* what swipes. Confirmed in a class dump
of this build — `-layoutSubviews`, `-initWithFrame:`, `-player:didUpdatePlaybackState:` —
and bound by its mangled Swift name.

Two things learned the hard way are built into it:

- **It is not a stack view**, so nothing rebuilds its children out from under the button.
  That is exactly what made the action rail report eleven buttons added and show none.
- **It is brought to the front on every layout pass.** The immersive player stacks
  full-screen plugin views over the video as it plays — `ImmersiveProfileSwipePluginView` is
  the full 390×844 on a real device — and a button added once sinks underneath the next one
  to arrive, where nothing can tap it.

Drawn white with a shadow rather than on a plate: the picture underneath is arbitrary, and a
shadow keeps the glyph readable over a bright frame without a box competing with X's own
controls.

The action-row button stays, and Diagnostics now reports both separately — one surface can
be present while the other is not, and a single yes/no could never say which.

## v0.8.0

**The button is on X's own action row now — the one with reply, repost, like and share.**

`11 buttons added` and no button on screen were never in conflict: the immersive rail is a
Swift `UIStackView` whose arranged subviews X rebuilds, so ours went in, was swept out, was
re-added on the next layout pass, eleven times over one session, and was never visible. **A
rising add-count with nothing on screen is the signature of that, not evidence of success**
— and it was read here as success for a release, which is the mistake worth remembering.

**TWIGalaxy never used that rail.** Its binary names exactly two immersive Swift classes,
`ImmersiveCardView` and the long-gone `ImmersiveInlinePlaybackButtonsStackView`, so its
immersive path is as dead on X 12.15 as ours was. What it actually hooks is this bar —
`TTAStatusInlineShareButton`, `…FavoriteButton`, `…RetweetButton`, `…BookmarkButton`, and a
selector called `eleventhButtonTapped:`, which is a tweak adding an eleventh button to a row
of ten.

X draws that row **under a timeline post and over a playing video alike**, so one surface
answers both places — which is why the button appears "inside the video" without anything
being placed inside the video at all. Three surfaces were being maintained for a job with
one.

Why this one holds where the rail did not:

- It is not a stack view. It positions its buttons itself, so a subview is not swept away
  by an arranged-subview rebuild; ours is placed after X has placed its own.
- It answers `-viewModel`, so the media lookup that already works elsewhere needed no new
  path.
- `-setViewModel:options:displayType:displayTextOptions:account:` is a real bind point,
  firing on first use and every reuse — the lesson `-didMoveToWindow` already cost this
  tweak once.
- X extends this row itself (`TTAStatusInlineGrokButton`, `…AnalyticsButton`,
  `…DownvoteButton` are all in the class dump), so it takes another button by design.

The three older surfaces stay for now and the report names all four, so nothing is removed
on the strength of one device until this one is confirmed.

## v0.7.2

**Diagnostics now prints the view chain above the rail when no button is added.**

Two releases have been spent on `0 buttons added`, a sentence that names a symptom and no
cause: first the rail was the wrong class, then the right class answered `-status` where the
lookup asked for `-viewModel`. If it is still zero, one unknown is left, and it is the one
nobody here can see — **whether the walk upward from the rail passes `ImmersiveCardView` at
all.** The immersive player is built of plugin views, and if the rail's plugin is a *sibling*
of the card rather than a descendant, no upward walk will ever reach the model and the fix is
a different search, not a different getter.

So the report answers it. `immersive button: ImmersiveActionsStackView — 0 buttons added;
above it: A < B < C …` — the actual superview chain, recorded once rather than on every
layout pass, since that hook runs continuously while a video plays.

Nothing else changed. This is instrumentation, and it is here because guessing at a
hierarchy from a class dump has now been wrong twice in a row about this one surface.

## v0.7.1

**The rail was found and the button still never appeared.** A device report on X 12.15
said it in one line: `immersive button: ImmersiveActionsStackView — 0 buttons added`. The
class 0.7.0 identified is right and the hook attaches; every placement then bailed at the
first line of the media lookup.

`SCITWFirstSaveableInStatusView` starts by asking the view for `-viewModel`. Walking up
from the rail reaches `ImmersiveCardView`, and **that class has no `-viewModel`** — its
whole interface is `-status`, `-playerView`, `-playerSessionProducer` and gesture plumbing,
confirmed in the class dump rather than guessed. So the lookup returned nil before it read
anything, on a hierarchy that was carrying exactly the object it wanted.

A view that answers `-status` is now treated as its own model. Everything after that hop
already knew how to go from a status to entities to media; only the top step was missing.
Surfaces that do answer `-viewModel` are untouched — it is still tried first.

The same report is why this was findable at all: `0 buttons added` and "the class is not
here" are different sentences, and 0.7.0 made the report say which.

## v0.7.0

**The save button did not appear inside the video, and a class dump answered why in one
line: the class it was being added to is not in this build at all.**

`ImmersiveInlinePlaybackButtonsStackView` — the rail 0.6.0 was written against, and which
TWIGalaxy's binary still names — is gone. Its sibling `ImmersiveCardView` is present, so the
dump does carry Swift classes and the absence is real rather than an artefact of how it was
taken. Five releases had been spent on button placement and none of them could have worked,
because nothing was there to attach to.

X rebuilt the immersive player around plugin views — `ImmersiveEngagementActionsPluginView`,
`ImmersivePlayPauseButtonPluginView`, `ImmersiveTopRightActionsPluginsView` and thirty-odd
more — and the rail of action buttons is now **`ImmersiveActionsStackView`**, whose members
are `ImmersiveActionButton`. It is the same shape as the old one: a stack of buttons with
`-layoutSubviews`, `-hitTest:withEvent:` and `-initWithFrame:`. Only the name moved, so the
placement itself did not need rethinking — the button is still an *arranged* subview, which
is what puts it in the rail beside like and share instead of fighting layout as a floating
one.

**Both names are hooked.** A `%hook` on an absent class never attaches, so naming the old
one costs nothing and covers builds that still carry it. The diagnostics report now names
which rail attached rather than answering yes or no — after an X update the useful question
is not whether a button appeared but which surface is left.

## v0.6.2

**Diagnostics now says whether the button actually landed on the video, or on the tweet
as a fallback.** The placement logic already prefers the video view -- it searches for it
by name and size before falling back to the tweet's own view -- but that was a claim about
what the code intends, not a measurement of what happens on a real timeline. The report
now reads it from the live view hierarchy at the moment each button is shown: how many
buttons landed on the video itself, and how many fell back to the tweet.

## v0.6.1

**The timeline button showed on the first screenful of a scroll and nowhere after.** It
was placed the moment the video view first appeared in a window, which happens once for a
genuinely new view — and a timeline cell that scrolls out and back in is not a new view,
it is the same one reused with new content. So the button from the top of the feed stayed
exactly there while every recycled cell below it got nothing, and opening a tweet worked
only because that builds a fresh view. The reels-style player added in 0.6.0 never had
this problem and needs no change.

It is placed from the video's own bind point now, on the tweet's view and the video view
alike, which fires on first appearance and on every reuse — the same one Diagnostics had
already been counting correctly the whole time, from asking it the wrong question.

## v0.6.0

**The save button is inside the video now, in the full-screen player — the reels-style feed.**

The earlier button was on the wrong view. Reading the reference tweak's binary settled it:
the class the old button attached to does not exist in it at all, and the button it does
show inside a video goes into the row of playback controls in X's immersive, swipe-up video
player — as a real member of that row, not a floating badge. So the stack lays it out beside
like, reply and share on its own, which is exactly why it appears where the floating one
never did.

The two older buttons stay for now, and the report under the two-finger hold names which of
the three attached — so a phone can say plainly where the button is and is not, instead of
four silent reasons for the same blank.

## v0.5.3

**The save button lands inside the video now, every time — not just on a recycled cell.**

0.5.1 put the button on the video, but the search for the video ran too early: the
moment it looked, the timeline had not yet sized anything, so the search found nothing
and the button fell back to the corner of the tweet — the exact placement it was meant
to replace. The search now runs after layout, once the video has its real size, so it
lands in the frame and stays there while you swipe between videos, the same as
Instagram's reel download button.

## v0.5.2

Fixes the build. 0.5.1 did not compile.

# Albrhi for X — what changed

## v0.5.1

**The button is inside the video now, and stays there while you swipe between videos.**

X draws every video and photo in one kind of view — in the timeline, in a post you opened,
in the fullscreen viewer, in a quoted post, in a message — and the button goes on that view
rather than on the corner of a timeline cell. So it is inside the picture wherever the
picture is.

That view had a button of its own since the first release and it never appeared, and the
report from a phone said exactly why: it was asking the video for what to save, and the
video does not know. The post does. It now looks upward until something answers.

# Albrhi for X — what changed

## v0.5.0

**The save button has moved off the share button.** It was in the bottom corner of the
post, which is exactly where X puts share — two small targets in the same place, so some
taps saved and some shared. It now sits in the top corner of the video or photo itself,
where nothing of X's competes for the tap, and it is bigger.

The device report is what made that possible: it said the media view is there to be found,
and said the other button had seen twenty-five posts and found media in none of them. That
second one is why nothing appeared for so long.

**And the settings page has the tweak's own settings on it.** All three of them were
missing entirely — the save button, the feature switches, and the detailed log had no row
anywhere, on the only screen this tweak has, with no way to turn any of them off. They are
the first section now.

Status has moved down. It is four lines of information about what attached, and opening a
settings screen with a report puts the reading above everything anyone came to change.

# Albrhi for X — what changed

## v0.4.4

Fixes the build. 0.4.3 did not compile: the new button read a setting through a helper
that belongs to the YouTube and Locket tweaks and has never existed in this one.

# Albrhi for X — what changed

## v0.4.3

**A save button on the tweet itself, beside reply and like.** The owner said plainly that
the tweak they use has a button you press for video, and a long press that saves images —
so the binary was read to find out where that button lives. It is not on the video view at
all: it goes on the tweet's own view, and the class our first button hooks appears nowhere
in a tweak that works.

So there are two now, and Diagnostics says which one your build of X actually supports.
The new one is on three of X's status views, added when the tweet comes on screen rather
than during a layout pass, and it finds the video the way the working tweak does — through
the tweet's own entities.

It is grey like X's own buttons rather than red. A fifth button in a different colour, in a
row of four, reads as an advert.

# Albrhi for X — what changed

## v0.4.2

**The save button still did not appear, and the page could not say why.** Four different
things produce exactly that — the view class not being in this build of X, the hook not
attaching, the video never reaching it, or the button being placed and covered — and
Diagnostics reported none of them. It now says which: whether the class is there, whether
the hook attached, how many videos it saw, how many held saveable media, and how many
buttons it placed.

**And the crash is most likely gone.** The button was being given Auto Layout constraints
from inside the layout pass it was created in, inside a view that lays its own overlay out
with plain frames. Asking for a new layout while one is running asks for another, and the
button was the only participant a solver had in a view that does not use one. It is a
plain rectangle in the corner now — the same 30 points, no solver involved.

# Albrhi for X — what changed

## v0.4.1

**The save button now appears on videos.** It never did. The button is built when the view
lays itself out, and the video it belongs to is handed over earlier than that — so the
button did not exist yet at the moment it was told what to save, and by the time it was
built there was nothing left to tell it. It hid itself, correctly, on the strength of a
question asked too early.

What to save is now kept on the view rather than on the button, so it does not matter which
of the two happens first.


## 0.4.0

**A download button on the video itself.** In the corner beside play and mute — tap it and
the video is in Photos, at the best quality X offers. No opening a menu first.

The list under the two-finger hold stays, and the two cover each other: the button is on
one of X's views and could break the day X renames it, while the list saves from the model
and does not. If the button ever goes missing after an X update, the list is still there.

## 0.3.0

**Saving videos.** Hold two fingers in X and everything it has shown you since you opened
it is at the top of the screen, newest first. Tap one and it is in Photos.

- **Videos at the best quality X offers** — the choice is made by X's own picker, not by us
  guessing at a URL.
- **Photos at full size.** A timeline photo is a smaller copy; what gets saved is the one
  that was uploaded.
- **GIFs too**, saved as the video files X actually serves — which is what they have been
  for years.
- Progress while it downloads, and a plain answer if it fails.

**No button is added to X**, and that is on purpose. A button has to live inside one of X's
views, and those get renamed — this project has lost the same button twice on Instagram for
exactly that reason. The list is in our own screen, so it keeps working when X moves things
around.

A live broadcast is the one thing that cannot be saved: X offers a stream for those and not
a file, so they are left out of the list rather than listed and failing after the tap.

## 0.2.0

**The features are here, and they are named after what they do.** 0.1.0 watched your phone
and wrote down every switch X asked about. This release turns what it saw into seventeen
switches in plain language:

- **Hide ads** — promoted posts in the timeline, before videos, on profiles and in search,
  and X's own rules that keep an ad out of the first slot are switched on.
- **Hide the Promote button**, **Hide Grok**, **Hide Premium ads**.
- **Stop X translating by itself** — the busiest switch on the whole phone, asked 32,844
  times in one session. The Translate button stays exactly where it is.
- **Send less about me** — the usage reports about your scrolling, storage, connection and
  crashes, and two outside services X carries. How X verifies your device is deliberately
  left alone: that one can get an account locked.
- **Clean up the interface**, **Hide view counts**, **Hide Spaces**.
- **Show sensitive posts directly**, **Do not play GIFs by themselves**, **Zoom without
  opening**, **More gestures**, **More tabs**, **Keep my likes private**, **Open faster**,
  and speed tweaks X ships switched off.

**Your own answer still wins.** Set a switch by hand and it beats whatever a feature wants,
and each row in the list now says which feature is behind its value. One button undoes
everything — features included.

Every switch a feature touches is one a real phone reported: 341 switches over 345,902
questions on X 12.14. What each one *does* is read from its name, so if something looks
wrong, turn the feature off and X goes straight back to normal.

## 0.1.0

The first release. It shows you the switches X uses to decide what your app can do,
and lets you answer them yourself.

- **Hold two fingers anywhere in X** to open it.
- **The list is real.** Every switch on the screen is one your copy of X actually asked
  about while you were using it — nothing is written in advance and nothing is guessed.
  Use the app for a while and the list grows.
- **Tap a switch to answer it.** On, off, or hand the decision back to X. Your answers
  are kept, and there is one button to undo all of them.
- **Search**, and a filter that shows only the ones you changed.
- **Save a report** to the Files app, so a problem can be described with the actual
  numbers instead of from memory.
- Arabic and English, and it appears in Settings › Albrhi with the rest.

This release deliberately reports more than it changes. Which switches are worth turning
on by name is decided by what real phones report, not by reading a binary — and that is
what this one is for.
