# NA9 For TikTok 1.0.1 — a full read of a closed, obfuscated reference

**Read for features and architecture only; nothing is copied** (CLAUDE.md §2). NA9 is an unlicensed compiled tweak
(`RootHide_com.na9.tiktok_1.0.1_iphoneos-arm64e.deb`, received 2026-10-25) by "Nasser" (`na9.me`, a sideload store).
No licence, store, donation or "special build" code was examined or proposed. What follows is what its binary says
about *which app functions it needs* and *how it reaches them*, checked against TikTok 46.4.0 and 47.1.0 with this
repository's tools, so that each lead can be asked of the app's own binary before anything is written.

## What the binary is

One `NA9TikTok.dylib` (1.66 MB of code, 19,681 procedures) plus `NA9TikTok.bundle` (three localisations, a font and
an asset catalogue). Filter: `com.zhiliaoapp.musically` and `com.ss.iphone.ugc.Ame`.

- **37 Objective-C classes of its own** (`Downloader`, `DownloaderHelper`, `TTDVNApi`, `TTKMediaModel`, `TTKHelperTools`,
  `ProfileManager`, `NA9UserDefaults`, `DVNSheet*`, `SettingsViewController`, `SecurityViewController`, `ToastManager`, `YY*`)
  plus statically linked libcurl, libwebp, zlib and YYImage.
- **Obfuscated, deliberately.** Every class and selector name the hooks need is stored XOR-encoded and decoded
  into a data buffer the first time it is used; calls go through nested one-instruction trampolines
  (`stp; bl X; ldp; ret`, two or three deep) so no import has a direct caller; hook bodies are control-flow
  flattened behind computed jumps (`br x9` through a table whose entries are XORed with constants), which is why
  Ghidra's decompiler, driven through REA (`morluto/rea` 6.4.0, Ghidra 12.1.4), returns one indirect call per hook.
  `svc` instructions after calls are an indirect-syscall exit. The Logos symbol table is gone.
- **What does survive:** `__objc_methname` (every selector it sends, in the clear: the runtime must be asked by name),
  the `MSHookMessageEx` call sites, and the encoded buffers themselves.

## How the hook table was recovered

REA lists 113 references to `_MSHookMessageEx`, all inside trampolines, so it names no class and no selector. The
setup code before each call is plain arm64: `x0` = class (from `objc_getClass` of a decoded buffer, or its metaclass
from `object_getClass`), `x1` = a selector reference, `x2` = the replacement, `x3` = the original-IMP slot. A
partial emulator (`na9-scripts/emu.py`: `adrp`/`add`/`mov`/`eor`/`ldrb`/`strb`/`ldr`, linear, branches ignored)
executes the decoding blocks, follows the trampolines, and prints each install. **119 hook installs, 54 classes.**
A handful of class names carry a corrupted byte (the emulator takes a register constant from the wrong branch) and
were matched to the nearest real class name; entries it could not decode are marked `undecoded`. Each row below was then
looked up, through the superclass chain, in the `tools/objc-classes.py` dumps of both builds.

## The hooks, by feature

"own" = the class declares the selector; "inherited:X" = X above it does; "NOT DECLARED" = no class in the chain does
(Logos would *add* the method: the hook is dead, which is what happened to ours on the same selectors, see below).

### Confirmations (follow / like / comment like)

| class | selector | 46.4.0 | 47.1.0 |
|---|---|---|---|
| `AWEIMProfileRelationView` | `p_didTapFollowButton` | own | own |
| `TTKProfileNavbarFollowComponent` | `onFollowBtnClick` | own | own |
| `AWEPlayInteractionUserAvatarElement` | `onFollowViewClicked:` | own | own |
| `_TtC19TikTokPhotoModeImpl27PhotoModeFullPageAuthorView` | `actionButtonClicked:` | NOT DECLARED | NOT DECLARED |
| `TTKFeedInteractionLikeManager` | `onLikeButtonClicked` | own | own |
| `TTKFeedInteractionLikeManager` | `doubleTapLikeWithAnimation:` | own | own |
| `AWECommentPanelCell` | `onLikeAction:` | inherited:AWECommentPanelBaseCell | inherited:AWECommentPanelBaseCell |

### Remove live videos (model layer)

| class | selector | 46.4.0 | 47.1.0 |
|---|---|---|---|
| `AWEAwemeModel` | `initWithDictionary:error:` | inherited:MTLModel | inherited:MTLModel |
| `AWEAwemeModel` | `init` | own | own |
| `AWEAwemeModel` | `live_callInitWithDictyCategoryMethod:` | inherited:MTLModel | inherited:MTLModel |
| `+AWEAwemeModel` | `modelWithDictionary:error:` | inherited:MTLModel | inherited:MTLModel |
| `+AWEAwemeModel` | `liveStreamURLJSONTransformer` | own | own |
| `+AWEAwemeModel` | `relatedLiveJSONTransformer` | own | own |
| `+AWEAwemeModel` | `rawModelFromLiveRoomModel:` | own | own |
| `+AWEAwemeModel` | `aweLiveRoom_subModelPropertyKey` | own | own |

### Download button, date label, post sheet

| class | selector | 46.4.0 | 47.1.0 |
|---|---|---|---|
| `TTKFeedInteractionStackView` | `layoutSubviews` | inherited:TTKFeedPassthroughStackView | inherited:TTKFeedPassthroughStackView |
| `TTKPostModeFullPageInputView` | `configWithModel:` | own | own |
| `AWECommentPanelBaseCell` | `layoutSubviews` | own | own |
| `AWEAwemeDetailTableViewCell` | `play` | own | own |
| `AWEFeedViewTemplateCell` | `play` | own | own |
| `TTKProfileAvatarSectionView` | `None` | undecoded | undecoded |
| `AWEUserWorkCollectionViewCell` | `None` | undecoded | undecoded |
| `TTKProfileHeaderAdaptorView` | `initWithFrame:` | own | own |
| `TTKProfileHeaderAdaptorView` | `initWithFrame:inHomeVC:` | own | own |
| `_TtC21TikTokSocialImplSwift30Story2InteractionBottomBarView` | `layoutSubviews` | own | own |
| `_TtC21TikTokSocialImplSwift30Story2InteractionBottomBarView` | `layoutSubviews` | own | own |

### Playback / feed behaviour (progress bar, loop → scroll next, pull-to-refresh, pure mode)

| class | selector | 46.4.0 | 47.1.0 |
|---|---|---|---|
| `TUXSlider` | `setAlpha:` | NOT DECLARED | NOT DECLARED |
| `TTKTabBarButton` | `onTapWithSender:` | own | own |
| `AWENewFeedTableViewController` | `disablePullToRefreshGestureRecognizer` | own | own |
| `UILynxView` | `layoutSubviews` | NOT DECLARED | NOT DECLARED |
| `TTKMediaVideoPlayFinishTrackComponent` | `onPlayerWillLoopPlaying` | own | own |
| `TTKFeedDeeperCleanModeComponent` | `p_updateDeeperCleanModeUI:` | own | own |
| `TTKFeedDetailDeeperCleanModeComponent` | `p_updateDeeperCleanModeUI:` | own | own |
| `IESVideoPlayerGestureManager` | `_pinched:` | own | own |

### Sensitive-content blur, warnings, author label

| class | selector | 46.4.0 | 47.1.0 |
|---|---|---|---|
| `AWEPlayInteractionAuthorElement` | `updateAuthorLabel` | own | own |
| `AWEPlayInteractionAuthorElement` | `updateAuthorlabelLengthIfNeeded` | own | own |
| `AWEMaskInfoModel` | `showMask` | own | own |
| `AWEPlayInteractionWarningElementView` | `warningLabel` | own | own |
| `AWEPlayInteractionWarningElementView` | `warningImage` | own | own |

### Messages (read, typing, unsent, voice, send)

| class | selector | 46.4.0 | 47.1.0 |
|---|---|---|---|
| `AWEIMMessageReadComponent` | `p_markMessageRead` | own | own |
| `AWEIMMessageReadComponent` | `p_markMessageAsReadLocally:` | own | own |
| `AWEIMMessageReadComponent` | `p_markReadSyncToServerWithMessage:` | own | own |
| `AWEIMMessageReadComponent` | `p_debounceMarkReadSyncToServer` | own | own |
| `AWEIMMessageBaseViewController` | `viewDidLoad` | own | own |
| `AWEIMChatRoomMessageSender` | `sendMessage:` | NOT DECLARED | NOT DECLARED |
| `AWEIMChatRoomMessageSender` | `sendMessage:completion:` | NOT DECLARED | NOT DECLARED |
| `AWEIMSendMessageController` | `sendMessage:conversation:` | own | own |
| `AWEIMSendMessageController` | `sendMessage:conversation:completion:` | NOT DECLARED | NOT DECLARED |
| `AWEIMSendMessageController` | `sendMessage:conversation:progress:completion:` | NOT DECLARED | NOT DECLARED |
| `TIMInputStatusManager` | `sendInputStatusWithConversationID:inputStatus:` | own | own |
| `_TtC17TikTokIMImplSwift32ChatInputVoiceMessageFeaturePack` | `handleRecordingButtonBeingTapped:` | own | own |
| `TIMCommandActorRecallMessage` | `performRecallMessageWithServerMessageID:recallUID:context:` | own | own |
| `AWEIMTextMessageCellView` | `layoutSubviews` | own | own |

### Upload in HD, open links in Safari

| class | selector | 46.4.0 | 47.1.0 |
|---|---|---|---|
| `ACCCreationPublishAction` | `is_open_hd` | own | own |
| `ACCCreationPublishAction` | `setIs_open_hd:` | own | own |
| `ACCCreationPublishAction` | `is_have_hd` | own | own |
| `ACCCreationPublishAction` | `setIs_have_hd:` | own | own |
| `PumbaaHybridWebContainer` | `initWithURL:dataflow:configuration:` | own | own |
| `PumbaaHybridWebContainer` | `initWithURL:dataflow:` | own | own |

### App lock

| class | selector | 46.4.0 | 47.1.0 |
|---|---|---|---|
| `AppDelegate` | `applicationWillResignActive:` | own | own |
| `AppDelegate` | `applicationDidEnterBackground:` | own | own |
| `AppDelegate` | `applicationDidBecomeActive:` | own | own |
| `AppDelegate` | `applicationWillEnterForeground:` | own | own |

### Profile visits, relationship text, post count

| class | selector | 46.4.0 | 47.1.0 |
|---|---|---|---|
| `TTKProfileViewsVisitor` | `reportProfileView` | own | own |
| `TTKProfileViewsVisitor` | `visit:` | own | own |
| `TTKProfileViewsVisitor` | `p_shouldReportProfileView` | own | own |
| `TTKProfileViewsVisitor` | `p_shouldReportHasVeiwedProfileForUser:` | own | own |
| `TTKProfileUserRelationInfoComponent` | `p_layoutComponents` | own | own |
| `TTKProfileUserRelationInfoComponent` | `p_adjustItemComponent` | own | own |
| `TTKProfileUserRelationInfoComponent` | `p_estimatedTotalWidth` | NOT DECLARED | own |

### Settings integration

| class | selector | 46.4.0 | 47.1.0 |
|---|---|---|---|
| `TTKSettingsViewController` | `sectionViewModels` | inherited:AWEBaseListViewController | inherited:AWEBaseListViewController |
| `TTKSettingsViewController` | `collectionView:didSelectItemAtIndexPath:` | own | own |

### Tab bar / toast obstruction

| class | selector | 46.4.0 | 47.1.0 |
|---|---|---|---|
| `TTKTabBarController` | `px_isTabBarHidden` | NOT DECLARED | NOT DECLARED |
| `TTKTabBarController` | `_isBarHidden` | NOT DECLARED | NOT DECLARED |
| `TTKTabBarController` | `_isBarEffectivelyHidden` | NOT DECLARED | NOT DECLARED |
| `TUXActionSheetController` | `viewDidLoad` | own | own |
| `TUXActionSheetController` | `None` | undecoded | undecoded |

### Story privacy

| class | selector | 46.4.0 | 47.1.0 |
|---|---|---|---|
| `TTKStoryMarkReadService` | `markAsRead:` | NOT DECLARED | NOT DECLARED |

### Detection bypass (jailbreak, store, receipts, debug, assertions, request headers)

| class | selector | 46.4.0 | 47.1.0 |
|---|---|---|---|
| `+TTInstallSandBoxHelper` | `bundleIdentifier` | own | own |
| `+TTInstallSandBoxHelper` | `isAppStoreChannel` | own | own |
| `+GULAppEnvironmentUtil` | `isFromAppStore` | own | own |
| `+GULAppEnvironmentUtil` | `isAppStoreReceiptSandbox` | own | own |
| `+GULAppEnvironmentUtil` | `isAppExtension` | own | own |
| `+FBSDKAppEventsUtility` | `isDebugBuild` | NOT DECLARED | NOT DECLARED |
| `+AWEAPMManager` | `signInfo` | own | own |
| `VKBundle` | `pathForResource:ofType:` | NOT DECLARED | NOT DECLARED |
| `VKBundle` | `bundleIdentifier` | NOT DECLARED | NOT DECLARED |
| `VKBundle` | `objectForInfoDictionaryKey:` | NOT DECLARED | NOT DECLARED |
| `VKBundle` | `infoDictionary` | NOT DECLARED | NOT DECLARED |
| `VKBundle` | `appStoreReceiptURL` | NOT DECLARED | NOT DECLARED |
| `VKBundle` | `pathForResource:ofType:` | NOT DECLARED | NOT DECLARED |
| `VKBundle` | `URLForResource:withExtension:` | NOT DECLARED | NOT DECLARED |
| `AWESecurity` | `resetCollectMode` | own | own |
| `MSManagerOV` | `setMode` | own | own |
| `MSConfigOV` | `setMode` | own | own |
| `+BÓAssert` | `assertFailed:` | class absent/system | class absent/system |
| `+BÓAssert` | `assertFailed:format:` | class absent/system | class absent/system |
| `+BÓAssert` | `assertFailed:file:line:` | class absent/system | class absent/system |
| `+BÓAssert` | `assertFailed:reason:` | class absent/system | class absent/system |
| `+NSURLRequeÂt` | `requestWithURL:` | class absent/system | class absent/system |
| `+NSURLRequeÂt` | `requestWithURL:cachePolicy:timeoutInterval:` | class absent/system | class absent/system |
| `NSURLRequeÂt` | `initWithURL:` | class absent/system | class absent/system |
| `NSURLRequeÂt` | `initWithURL:cachePolicy:timeoutInterval:` | class absent/system | class absent/system |
| `+NSMutableURLRequest` | `requestWithURL:` | class absent/system | class absent/system |
| `+NSMutableURLRequest` | `requestWithURL:cachePolicy:timeoutInterval:` | class absent/system | class absent/system |
| `NSMutableURLRequest` | `initWithURL:` | class absent/system | class absent/system |
| `NSMutableURLRequest` | `initWithURL:cachePolicy:timeoutInterval:` | class absent/system | class absent/system |
| `NSMutableURLRequest` | `setValue:forHTTPHeaderField:` | class absent/system | class absent/system |
| `NLEFileManager` | `fileExistsAtPath:` | NOT DECLARED | NOT DECLARED |
| `NLEFileManager` | `fileExistsAtPath:isDirectory:` | NOT DECLARED | NOT DECLARED |
| `+BDADeviceHelper` | `isJailBroken` | own | own |
| `+UIDevice` | `btd_isJailBroken` | class absent/system | class absent/system |
| `+TTInstallUtil` | `isJailBroken` | own | own |
| `+AppsFlyerUtils` | `isJailbrokenWithSkipAdvancedJailbreakValidation:` | own | own |
| `PIPONewIAPStoreManager` | `_pipo_isJailBrokenDeviceWithProductID:orderID:` | NOT DECLARED | NOT DECLARED |
| `+IESLiveDeviceInfo` | `isJailBroken` | own | own |
| `PIPOStoreKitHelper` | `isJailBroken` | NOT DECLARED | NOT DECLARED |
| `+BDInstallNetworkUtility` | `isJailBroken` | own | own |
| `+TTAdSplashDeviceHelper` | `isJailBroken` | own | own |

### Reading the table

- **Eighteen of NA9's hooks name a selector that no class in the chain declares, in both builds** (the `NOT DECLARED` rows).
  Logos/MobileSubstrate would *add* such a method, so the hook cannot intercept a call the app makes through its declared methods.
  What is established: the declaration is absent from both dumps. What is **not** established: whether the feature behind
  it works for NA9 some other way. The owner reports that NA9 works on 47.1.0 (taken from him, not observed here), so a
  feature built on a `NOT DECLARED` row may reach the app through another route; for `TTKStoryMarkReadService -markAsRead:` a scan
  of `MusicallyCore` found three sends of a `markAsRead:` selector (inside `TTKRichContentMarkReadService` code) to a receiver
  no class declares it on, which is how a hook on a non-declaring class could still matter and is why it is left open.
  **A selector named by a reference tweak is a lead, never evidence that the app has it or that the hook is live.**
- **`TTKProfileUserRelationInfoComponent -p_estimatedTotalWidth` exists only from 47.1.0** (`p_calculateTotalWidth` is
  its older sibling): NA9 hooks the three layout methods (`p_layoutComponents`, `p_adjustItemComponent`, the width one)
  to add a "posts" statistic and a relationship word to the profile's followers/following/likes row.

## How NA9 puts its screen in TikTok's Settings (the part we wanted)

Disassembled and annotated (`annot.py`, range `0x8e404`–`0x8f010`), the replacement for
`-[TTKSettingsViewController sectionViewModels]` does, in order: call the original and `mutableCopy` the array; make an
`AWESettingItemModel` and send `setTitle:`, `setIdentifier:`, `setType:1`, `setCellType:4`, `setIconImage:`; make a
`TTKSettingsBaseCellPlugin` and give it the item with `setItemModel:`; build an `AWESettingsNormalSectionViewModel` with
`initWithModelsArray:@[plugin]` and send `setSectionIdentifier:`, `setSectionHeaderTitle:`, `setSectionHeaderHeight:`;
find an index with `indexOfObjectPassingTest:` (the predicate is a block whose body was not read) and
`insertObject:atIndex:`; return a `copy`. Its second hook, `-collectionView:didSelectItemAtIndexPath:`, takes
`[collectionView cellForItemAtIndexPath:]`, reads `cell.itemModel.identifier`, and pushes its own controller when it is
its own. **Every message in that recipe exists with the same encoding in both builds** (checked for all fifteen). Our
0.24.0 uses it as the preferred path, with the earlier inset row as the fallback when any prerequisite is missing; the
report names which one ran. Not copied: the order of messages is the API's, and the code, the predicate and the strings
are NA9's own.

## Downloading: NA9 against ours, beyond how the bytes are fetched

| | NA9 | Albrhi TikTok 0.24.0 |
|---|---|---|
| Where the media model comes from | the same `AWEAwemeBaseViewController` it hooks for `-viewDidLoad`; button on `AWEFeedViewTemplateCell` (`-play` adds it) | the cell's controller, **re-resolved at tap**; button on the interaction rail |
| Which link | `videoURL` / `musicURL` / `imageURL` / `livePhotoURL` fields of its own `TTKMediaModel`; `/aweme/v1/play/` fetched **with TikTok's own session cookies** (`DownloaderHelper -tiktokSession`, `downloadFile:…usingTikTokSession:`) | ranked by kind first (clean beats watermarked, video beats audio, demoted H.264 copy last), bytes second; measured by `HEAD` or a one-byte range `GET` |
| HD | tikwm: `GET /api/` (post info), then `POST /api/video/task/submit` and polling `/api/video/task` with a deadline (`fetchOriginalSource`, `pollSourceTask:deadline:`) and a source cache; a Firefox user-agent | tikwm JSON API, the `hdplay` link, off by default and says it sends the id outside; **no task-submit path** |
| Fetch | chunked ranged requests (`bytes=%lu-%lu`), a temp directory, per-chunk progress | one request per link, size compared with the declared length before writing |
| Photo posts | `downloadImages:withAudio:title:`, **slideshow video with crossfades** (`createCrossfadePixelBufferFrom:to:progress:`), `img_%ld.heic`, `tikwmImagesForAwemeID:` as a fallback source | one picture or all, **10/30/60-second clip** with the post's sound trimmed to fit |
| After saving | `saveItems:model:` into Photos on a group/queue (`com.app.saveQue`), `shareMedia:`, a configurable "after download" action, **free-space check** (`hasEnoughSpaceFor:freeSpace:requiredSpace:`) | Photos (refusal written on the row), no share/after action, no space check |
| What else it can save | **stories** (hook on `Story2InteractionBottomBarView`), **profile picture** (`avatarLarger`, long-press on the header), comment **sticker** and comment **image** (`saveStickerImage:`, `saveCommentImage:style:`), copy video/image/sticker link, bio, username, nickname | comment media only |
| Sheet | its own `DVNSheet` (title, country flag emoji from `codeToEmoji:`, date, file size from `fetchPost:`) | a banner and the tweak's own sheet |

What is ours and not NA9's: the wrong-video guard (it records no model identity at tap), the per-gear report, the
size-versus-declared check, the kind ranking, and the diagnostics.

## Features it has that we do not (kept in memory, not built)

Stories download; profile picture download; comment sticker/image download and share-as-image; copy links, bio,
username; manual image selection; after-download action; space check; slideshow video; hide typing indicator
(`TIMInputStatusManager -sendInputStatusWithConversationID:inputStatus:`); keep unsent (`TIMCommandActorRecallMessage`);
sensitive-content blur (`AWEMaskInfoModel -showMask`); warnings under videos (`AWEPlayInteractionWarningElementView
-warningLabel/-warningImage`); transparent comment panel; disable pull-to-refresh (`AWENewFeedTableViewController
-disablePullToRefreshGestureRecognizer`); open links in Safari (`PumbaaHybridWebContainer -initWithURL:…`); upload in HD
(`ACCCreationPublishAction -is_open_hd` / `-is_have_hd` and setters); loop → scroll to next (`TTKMediaVideoPlayFinishTrackComponent
-onPlayerWillLoopPlaying`); pinch → pure mode (`IESVideoPlayerGestureManager -_pinched:` + `setPureMode:animated:`); show @username
(`AWEPlayInteractionAuthorElement -updateAuthorLabel`); voice messages (`ChatInputVoiceMessageFeaturePack`); mark read after
sending (the `sendMessage:` hooks call `p_markMessageRead`); profile visit marking; app lock (`AppDelegate` lifecycle +
`SecurityViewController`, with a blur on resign). Every selector above is in the dumps with the encoding shown
in the table; **none is verified to do what the name says.**

## Detection bypass: what it covers beyond ours

Its own jailbreak path list (about 60 paths decoded from the buffers: `/Applications/Cydia.app`, `/jb/libjailbreak.dylib`,
`/etc/apt/sources.list.d/sileo.sources`, `/usr/sbin/frida-server`, `/.installed_unc0ver`, …) is applied through hooks on
`NLEFileManager -fileExistsAtPath:`(`isDirectory:`) and a bundle class, plus request-header hooks on `NSURLRequest`/`NSMutableURLRequest`
(`setValue:forHTTPHeaderField:`) and bundle receipts/Info.plist (`appStoreReceiptURL`, `infoDictionary`,
`bundleIdentifier`, `objectForInfoDictionaryKey:`), `MSManagerOV`/`MSConfigOV -setMode`, `AWESecurity -resetCollectMode`,
`BDAssert`. Ours covers the class-level answers and `NSBundle` provisioning only. **Not proposed here**: that surface
reaches the store-receipt and request-signing layers, which §2 treats separately from detection.

## Limits

- Replacement bodies are flattened; behaviours above are inferred from the selectors and strings each body names, not from
  a recovered control flow. Constants such as the section header height and the insertion predicate were not read.
- Entries marked `undecoded` (three) and the system-class names with a corrupted byte (`NSURLRequest…`, `BDAssert`, `VKBundle`)
  come from the emulator following one branch only.
- The owner reports NA9 1.0.1 works on TikTok 47.1.0 (the build analysed here). That is his observation; nothing in this document was run.
