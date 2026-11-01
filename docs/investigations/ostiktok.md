# OSTikTok 1.3.1 (TikTok 47.4.0) — what it is, what it does, what we have and lack

Written 2026-11-01. `~/Downloads/TikTok_v47.4.0_OSTikTok_1.3.1.ipa` (483 MB): the app with one tweak injected at
`Frameworks/OSTikTok.dylib` (1.9 MB, arm64), a resource bundle `OSTikTok.bundle` (English and Arabic string tables, five images)
and `Frameworks/OSTikTok.integrity`. Nothing here has run on a device, and nothing was run at all: it is what the files say.

## The boundary, stated first (CLAUDE.md §2)

**OSTikTok is a closed, licensed, protected product.** Its own strings say so: a *License* page ("Activation, subscription, device"),
67 `settings.license.*` keys, `license.transfer`, `license.store_cert_reason`, `license.integrity`, a portal and a store prompt, a privacy
policy that names "managing licensing" and a Device ID. The package carries a signed `OSTikTok.integrity` (`{payload, signature}`), the
dylib imports Secure Enclave key creation, ECDSA/ECDH, `CCCrypt`, HMAC and SHA-256 from `Security`/`libSystem`, and imports `sysctl`,
`stat`/`lstat` and `_dyld_register_func_for_add_image` (what they are used for was not read). Its 53 classes are named `OS_<random>` and most of its selectors are
short codes (`_g7a1h`, `o_5j9VhA6LZd`, `_dl_prf_fc:`).

Same rule as Rocket and Legizmo: **read for architecture and the public feature list; the licence, activation, integrity, device-binding
and anti-tamper code was not examined and nothing was copied.** `OSTikTok.integrity` was opened only far enough to see that it has two
keys. A paid tweak's entitlement is also the "Money" line (§2): this project does not hand anybody a subscription, so none of that is
a lead. There is no licence file in the IPA; whether the author's terms forbid reverse engineering is **not known** (the RyukGram lesson:
ask before reading, not after) — the owner supplied the file and asked for the study.

## What was done, in order, and with what

| step | command / tool | result |
|---|---|---|
| 1 | `unzip -Z1 <ipa>` → 3,702 members; `grep -E '\.dylib$'` | exactly one injected library, `Frameworks/OSTikTok.dylib`, beside `.integrity` and `OSTikTok.bundle/` |
| 2 | extract only those files into a fresh directory; `plutil -p Info.plist` | host app `com.zhiliaoapp.musically` 47.4.0 (build 474032), `MinimumOSVersion` 15.0 |
| 3 | `otool -L` | links only Apple frameworks and `libz`; **no Substrate, no `libroot`, no `libsubstitute`** — it carries its own hooking |
| 4 | `en.json` / `ar.json` (636 keys each, in parity) | the public feature list (below) |
| 5 | `tools/objc-classes.py --dump` | 53 classes, **all `OS_…`**, none with a TikTok name; one has 135 methods (comment search), one 113 |
| 6 | `strings -a` | 119 TikTok class names in the clear (the classes it hooks must be asked for by name) |
| 7 | `xcrun dyld_info -imports` | hooking primitives: `class_copyMethodList`, `class_getInstanceMethod`, `class_addMethod`, `method_setImplementation`, `objc_lookUpClass` ×115 and `objc_getClass` ×94 call sites, `sel_registerName` ×22, `dlsym` ×8 |
| 8 | `objdump -d --arch=arm64` (339,755 lines) + a stub→GOT map | the swizzle helper (below) |
| 9 | `tools/ref-leads.py <dylib> --tweak tweaks/tiktok` | 717 app-side selectors named, 46 already in our sources; licence/store selectors bucketed apart and not read |
| 10 | extract `MusicallyCore` (881 MB) from the same IPA; `objc-classes.py --dump` | 110,907 classes in 68 s |
| 11 | pair the 119 class names with the selectors it names, against 47.4.0's own class table | 116 of the 119 exist in `MusicallyCore`; **605 (class, selector) pairs** where the reference names both and the app declares the selector there |

**REA (Ghidra) did not finish.** `open_binary` succeeded (sha256 `a6d4cbf7…987a`) and then `binary_overview`, `search_strings` (twice)
and `search_procedures` each stopped at the 330 s provider timeout — four timeouts, about 22 minutes, nothing decompiled. The same
tool opened ASJTok (§2) without this. The likely cause is the same kind of flattened control flow that stopped NA9's decompiler, but
that is a guess; the measured fact is the timeouts. Steps 7–8 are what replaced it.

## How it hooks (measured)

A single helper at `0x508a0` has the shape `(Class, SEL, IMP, IMP *orig)`: it returns if any of the three is nil; walks the class and
then each superclass with `class_copyMethodList`, comparing `method_getName`; when the method is declared **on the class itself** it
calls `method_setImplementation` and stores the old IMP through the fourth argument; when it is **inherited** it calls
`class_addMethod` on the class with the superclass's implementation and encoding. That is the same behaviour as `MSHookMessageEx`
(and as ASJTok's shim), without Substrate. Consequences worth knowing: it survives rootless, roothide and sideload alike (nothing to
link); it hooks the first declaring class only; **no encoding check is made**, so the §4.2 hazard (a hook on a selector whose type is
not what was assumed) applies to it as to the old Instagram tweak.

**Not established:** the full hook table. The helper has no direct callers (`bl 0x508a0` appears nowhere), so the hook sites reach it
through function pointers or a table, and the 209 class lookups and 33 `class_getInstanceMethod` calls were not paired with their
selectors one by one. What follows is therefore the *surface* (classes and selectors it names), not a list of what each replacement does.

## Feature list, from the tweak's own English table

Nine settings pages: License (not read), Ads & Customization, Feed & Playback, Profile, Downloads, Menu, Privacy & Texts, Tools &
About, Live. Features marked **have** exist in this project; **lack** do not; the right-hand column is the hook surface the reference
names that 47.4.0 declares (inferred from the pairing, not read from a replacement).

| feature (its wording) | here | surface in 47.4.0 |
|---|---|---|
| Start up on Following | have (0.26.0) | `AWEFeedContainerViewController segmentControlInitialIndex`, `tabIndexForType:` |
| Hide TikTok ads; block app-download / local-places / movie ads; rewards campaigns; commercial sponsored; product videos (yellow cart) | partly (ad filter on `-isAds`) | `AWEAwemeModel` `isAds`, `originAdInfo`, `commerceModel`, `feedBannerItem`, `isLive`; `TTKPendantView` / `TTKNormalPendantView` (floating promotion icons) |
| Hide suggested accounts / feed suggestions / inbox suggestions / inbox Shop | partly (`skip_suggested`) | `TTKUserRecommendListFrequencyController needEnterCooldownWithScene:`, `TTKFeedInteractionCardInsertUserRecommendElement`, `TTKInboxShopModel`, `TTKProfileRecommend(Card)Component`, `AWEAwemeModel isUserRecommendBigCard` |
| Hide Following LIVE bar | **lack** (§5.4 says no safe gate was found) | `TTKFeedSkylightComponent` (`componentMount`, `disablePullToRefreshGestureRecognizer`), `AWEFeedSkylightLiveView` |
| Hide board invites | **lack** | `TTKBulletinBoardDataService preloadItemsForBulletinBoards:`, `TTKInboxBulletinBoard*` |
| Hide live broadcasts | have | `AWEFeedContainerViewController MTLiveEntranceView`, `IESLiveMTAudienceViewController` |
| Hide TikTok AI (Tako) | **lack** | `TTKTakoEntranceButton`, `TTKFeedDetailTakoButton`, `TTKSearch…TakoEntranceView`, `TTKSearchTabBar p_isTakoAllow` / `takoEntrance` |
| Block AI-generated posts | **lack** | `AWEAwemeModel aigcInfoModel` → `TTKAIGCInfoModel` (`aigcLabelType`, `createByAI`) |
| Disable survey | **lack** | `TIKTOKFeedSurveyManager canShowSurvey…` (four), `TTKFeedSurvey{Base,Feed,Multi}Config`, `TTKCommerceSurveyService` |
| Hide search history | **lack** | `TTKSearchHistoryManager` (a dozen `fetchHistory…`), `AWEIMSearchHistoryDataManager`, `TTKECSearchHistoryManager`, `TTKInboxSearchHistoryDataManager`, `TTKProfileSearchHistoryManager` |
| Hide Find Similar; disable pull to refresh; stop looping; always show progress bar; force unmute; warnings; sensitive-content mask | partly (progress bar, unmute, warnings, TikBot have) | `AWEFeedContainerViewController`/`AWENewFeedTableViewController disablePullToRefreshGestureRecognizer`; `playerWillLoopPlaying:`; `AWEMaskInfoModel showMask`; `AWEPlayInteractionWarningElementView`; `AWEPlayInteractionProgressManager isShowStableProgressSlider` (progress bar); `AWEAwesomeSplashManager shouldShowAwesomeSplash` (a splash decider we do not hook, §5.4) |
| Auto Play, auto-skip photo posts | have (auto-advance) | `scrollToNextVideo` on the feed controller; `AWEPlayPhotoAlbumViewController currentIndex` |
| Car & headset buttons (next/previous post) | **lack** | not paired: `MPNowPlayingInfoCenter`/remote-command calls are Apple's and the wiring is not read; `TTKFeedPictureInPictureComponent playNextControlByAuto` / `autoPlayNext:` are a different (PiP) path |
| Floating window (PiP) | **lack** | `TTKFeedPictureInPictureManager` (`isPipInAb`, `isPipHitAbWithOpenStatus`, `ttkFeedPictureInPictureSettings`), `TTKPictureInPictureModuleService`, `TTKFeedPictureInPictureComponent`, `TTKSettingsPlaybackViewModel switchFeedPip:` |
| Clear display (hide icons across videos), exit button | **lack** | `TTKFeedExitClearModeButton` (only its hit-testing is named; the mode itself is not located) |
| Show FYP upload time | have (date beside the name, 0.26.7) | `AWEPlayInteractionAuthorElement shouldShowTimeStampLabel`, `layoutTimeStampLabel`, `updateTimeStampLabel` — **TikTok has its own timestamp label behind a flag; a read of why we draw our own is worth doing** |
| Upload region flag | have | `AWEUser` is named; the request it uses is not located |
| Ghost mode (no profile-visit alert) | have | `TTKProfileViewsVisitor p_shouldReportProfileView`, `reportProfileView`, `visit:` |
| Clean copied links; always open in Safari | have | `AWEThirdWebModuleServiceImpl tryOpenURL:dataflowId:`, `isThirdURLString:` |
| Download video/HD/music/photos/slideshow/stories; custom Photos album; share mode | have video, HD, photos one by one, a picture as a 10/30/60 s clip; **lack** a whole post as one slideshow video with seconds-per-photo and music-length timing, a named Photos album, animated (live) photos | `AWEMusicModel`, `TTKStory…PlayerController`, `TTKPhotoModeLivePhotoModel video` (animated photos) |
| Download comment stickers (long-press) | **lack** | `TTKCommentStickerInteractionHandler +stickerItemFromCommentModel:` |
| Comment search with batch loading; translate comments | **lack** | its own 135-method class; `TTKCommentListControllerComponent`, `TTKCommentPanelViewController` |
| Like / dislike comment confirmation | **lack** (we confirm video like and follow) | `AWECommentPanelBaseCell onLikeAction:` / `onDislikeAction:` |
| Bypass bio (222) and comment (500) limits | have (bio); comment limit not taken (§2 ASJTok) | `AWETextInputController maxLength` / `textField:shouldChangeCharactersInRange:replacementString:` |
| Profile: copy summary, save picture, country flag, like count, upload date on tiles, video count | have except tile date/like count on profile grids | `AWEUserWorkCollectionViewCell configWithModel:isMine:`, `updateBottomInfo`, `topLabel` |
| Backup / restore (encrypted), clear cache | have (cache; backup is the panel's) | — |
| Auto-click button in LIVE | **declined** (§2: counterfeit engagement) | `GBLDiggStore`, `IESLiveMTDiggStoreAffair diggClicked:touchPoint:gapTime:` |

**Not taken on principle, regardless of effort:** anything in the licence, activation, device-binding, integrity or store area; LIVE
auto-click. **Needs the owner's call:** "Disable Sensitive Content Mask" (it removes TikTok's own overlay on content the platform marked
sensitive).

## What to do next, if anything, in order of value and safety

1. **Survey, Tako/AI, pendants, bulletin board, search history** are the cheapest: each is a decision gate with a declared selector in
   47.4.0 (list above), the same shape as the splash and TikBot gates already built. Each needs the §4.2 routine first (who calls it,
   encoding from the binary, a counter on the path) and a switch that is off by default.
2. **Clear display** and **PiP** are the two with a real interface; both need their callers measured before a hook is chosen.
3. **Comment features** (search, translate, sticker download, like confirmation) are a project of their own.
4. The unanswered question that would decide how much of the above can be trusted: what each replacement *returns*. That needs the
   decompiler, which needs a Ghidra run that finishes (headless, with `Decompiler Switch Analysis` and `Decompiler Parameter ID` off,
   as noted in §7) or a hook table recovered the way NA9's was (§5.4). Both would read protected code and should be asked about first.
