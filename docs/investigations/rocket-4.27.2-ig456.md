# Rocket for Instagram 4.27.2 on Instagram 456.0.0 — dissected without its source (2026-11-24)

**Same line as the earlier Rocket notes (`rocket-feature-map.md`): features and architecture only.** Rocket is closed, obfuscated and sold; its licence, store and
entitlement code was **not** examined, its string encryption was **not** defeated, and the file was **never executed** (static analysis only). Nothing was copied.
Everything below is what the binaries declare; **none of it has been seen working**, and "feature X" for a hashed class is an *inference from the Instagram
selectors it loads*, not a reading of its code.

## What was downloaded

`https://altstore.getrocketapp.io` is the vendor's own AltStore source (JSON, public). Its single app is **Rocket for Instagram 4.27.2 on Instagram 456.0.0**
(`versionDate` 2026-11-22; 4.27.1 on 2026-11-16 added "Choose download quality"; 4.27.2 fixed the quality picker "on new IG versions"; `minOSVersion` 16.0).
The download is a **complete decrypted Instagram 456.0.0 IPA, 306,519,178 bytes, with `Rocket.dylib` loaded from the executable** (`@executable_path/Rocket.dylib`),
`Rocket.bundle` beside it, and the vendor's own resources. SHA-256 of the IPA `ccb119261b69f0f326bb387ad9f18f556f973695b1c0401399a7c78f01431415`.

That also makes it **the newest Instagram binary this project has**: 52,806 classes in the main executable (450.1.0: 46,953) plus 5,593 in `FBSharedFramework`.

## What Rocket is made of

| | |
|---|---|
| `Rocket.dylib` | 5,095,504 bytes, 294 classes (289 hashed names, `z<24 hex>`), 4,800 own selectors; class **and** selector names of its own classes change every release |
| hooking | the Objective-C runtime (`class_replaceMethod`, `method_setImplementation`, `imp_implementationWithBlock`), no Substrate (as in 4.24.0) |
| strings | its own are encrypted; only third-party library messages are readable (SDWebImage, MBProgressHUD, FLAnimatedImage, MLLeftRight…). **Left that way.** |
| frameworks | AVFoundation/AVKit/VideoToolbox/CoreMedia/CoreVideo (downloads, quality, PiP, call recording), Photos, ImageIO, CoreImage, Accelerate, JavaScriptCore, sqlite3, MetricKit, UserNotifications, MapKit, WebKit, QuickLook, CoreText, Security |
| `Rocket.bundle` | `AppIcons/catalog.json` (8 icons: Ember, Ocean, Orchid, Evergreen, Rose, Slate, Sand, Midnight), `ThemePreviews/manifest.json` (**10 themes**: default, oled, ember, ocean, orchid, evergreen, rose, slate, sand, midnight; previews were captured from the **live tab bar** `IGLiquidGlassInteractiveTabBar` on Instagram 446.0.0 / iOS 26.6.1 / Rocket 4.15.0), four home-feed layout icons (grid, list, multi, video), `NYTPhotoViewer` (profile picture viewer), `cercube-icon.png`, `ra-store-*` (the paid store: not examined) |
| REA | `open_binary` works; `binary_overview` **timed out at 330 s** again (Ghidra analyses the whole 5 MB obfuscated `__text` first). Not used further |

### The method that did work (no decryption, no execution)

1. `tools/objc-classes.py --dump` of `Instagram` (456), `FBSharedFramework` (456) and `Rocket.dylib`; `tools/ref-leads.py` for the Instagram selectors Rocket names in the
   clear (**626**, of which **550** after property noise; **262 are declared by some class in 456**, 54 are already named in our sources).
2. **A new step: who loads each selector.** An Objective-C method's `__objc_selrefs` slot is loaded by `adrp`+`ldr` in the code that uses it, so scanning Rocket's `__text`
   for those loads and naming the nearest preceding method (`docs/investigations/na9-scripts/objc_allimps.py` + a 60-line scan) gives **which Rocket class touches which
   Instagram selector** without decompiling or decrypting anything (1,580 uses across 169 Rocket classes). Hashed names stay hashed; the Instagram selectors do not.

## Rocket's components, from the Instagram selectors each one uses (all present in 456)

| Rocket class (hash) | Instagram classes and selectors it loads (456) | What that most likely is |
|---|---|---|
| `zb28ef544b5b` (16) | `IGStoryViewSessionSeenStateManager hasSeenMediaId:forReelPK:`, `IGStorySeenState initWithReelSeenDictionary:liveSeenDictionary:reelSkippedDictionary:liveSkippedDictionary:containerModule:pushCategory:forceSeenIds:`, `IGStoryViewerItemSeenHandler handleItem:sectionController:focusedModelItem:`, `IGBaseReel _private_seen`, `IGStoryTrayViewModel isCurrentUserReel`, `…StoryTrayCellViewModel isPartiallySeen/numStoryItems` | private story viewing / mark-seen control |
| `zbb6d348f75c` | `IGStoryMediaSeenStateStore setSeenMediaId:forReelPK:`, `IGStoryTraySectionController reloadSectionAnimated:`, `dataSourceDidUpdate`, `IGListAdapter performUpdatesAnimated:` | writing "seen" locally and refreshing the tray |
| `z49c2063b725`, `z3b5d44b99a6` | `IGDirectLastSeenMessageInfo (shhMessageSeenInfo, afterViewDisappearingMessageSeenInfo)`, `IGDirectThreadViewFeatureManager markLastMessageAsSeen`, `…ListAdapterDataSource shouldUpdateLastSeenMessage`, `IGDirectPublishedThread publishedMessagesInCurrentThreadRange`, `IGDirectAfterViewDisappearingMessage… sendDisappearingMessagesAfterViewSeenState` | DM read receipts / "typing" / seen control |
| `zcd2b3745685`, `z3ca2b82845d`, `zc7e12354863`, `RATabBarLayout*Cell` | `IGTabBarController _installOrUpdateNativeTabBarController, allTabBarSurfaces, setSelectedTabBarSurface:animated:, tabBar:didInternallySelectItemAtIndex:`, `IGTabBarControllerSwipeCoordinator initWithSurfaces:parentViewController:enableHaptics:launcherSet:`, **`IGLiquidGlassInteractiveTabBar setSelectedTabBarItemIndex:animateIndicator:, buttonContainerView, synchronizeSelectedIndexAfterReorder, _updateBarAppearanceAnimated:`**, `IGLiquidGlassTabBarButtonContainer tabButtons, visualEffectView` | its **custom tab bar** (the only feature whose classes are readable: `RATabBarLayoutBarCell/EmptyCell/HiddenCell`) built on Instagram's **Liquid Glass** bar |
| `z3a36c587628` | `IGMainFeedDataController feedSessionNeedsToRefresh:withReason:cancelOngoingFetch:extraParams:`, `IGHomeFeedHeader feedPickerEntryPointView`, `IGMainFeedViewModel isSecondaryFeed`, `IGMainFeedNetworkSource initWithPosts:nextMaxID:…`, `IGExploreNetworkerRequestConfig isHeadLoad` | **Following as the default Home feed** |
| `z6c0aae2a5ff` (41 selectors) | builds `IGMainFeedNetworkSourceSessionDeps`, `IGFeedNetworkSourceAnnouncers`, `IGStoryDataControllerSessionDeps` (dependency objects), `IGListSectionController`/`IGFlowLayout` spacing | its own feed controller: **List / Grid home feed** |
| `z6da25be4e94` | `IGFeedItemInfoCardInteractiveView _onDoubleTap:`, `IGLiveContentView _handleDoubleTapGesture:`, comment `contentViewDoubleTapped:` / `likeButtonTapped:`, `IGCoreTextView _findClosestIndexForURLOrTapActionForAttributedString:nearPoint:constrainedSize:` | like confirmations and **clickable web addresses** |
| `z8b8804b406a` | `IGUFIButtonBarView repostButton, colorType` | adds buttons to the action bar (download / repost) |
| `zd86742c9682` | `IGFeedItemUFICellConfigurableDelegateImpl feedItemUFICellDidTapSaveButton:` | **save without the collection picker** |
| `zee302a052f0` | `IGVideoCallManager _handleCallEndedForSession:callEndedModel:, videoCallController:didAddParticipant:, videoCallControllerDidEnd:reason:wasConnected:` | **call recording** (listed by the vendor; not proposed here, per CLAUDE.md §2) |
| `ze1e9ded238b`, `z594c9bc31de`, `z71c8bc65487` | `IGAssetPlayerView setActionAtItemEnd:, setAudiovisualBackgroundPlaybackPolicy:, setAutomaticallyWaitsToMinimizeStalling:`, `IGSundialViewerVideoCell sundialVideoPlaybackViewDidStartPlaying:`, `IGListAdapter scrollToSectionController:atIndex:scrollPosition:animated:` | Reels PiP / background playback, no-doomscroll and auto-scroll |
| `z2daa1b4f500` | **`IGScreenCaptureProtectionViewProvider initWithIsProtected: / setIsProtected:`**, `IGQuickSnapUploadListenerImpl quickSnapUploadDidBeginUpload:audience:` | **Discreet mode** (its buttons hidden from screenshots) and Instants upload |
| `z4fe5ea794c9` | `IGQuickSnapService syncSeenSnapsWithServerWithDirectSessionId:onSuccess:onFailure:`, `IGQuickSnapImmersiveViewerSnapSt… didPressWithGestureRecognizer:` | replaying Instants without the limit |
| `z821c5f788f2` | `IGDirectVisualMessageViewerEventHandler visualMessageViewerController:didBeginPlaybackForVisualMessage:atIndex:` | DM visual messages (download / replay) |
| `z263f1b7e424` | `IGStoryViewerViewController focusedCell, sectionControllerForCell:, currentViewModel, focusedModelItem` | story download |
| `z9fac19ca453` | `IGProfileViewController profileAvatarActionsController:showExpandedProfilePicFrom:isLongPress:, navigationItemsControllerDidTapSideTray:`, `IGProfilePhotoView/IGProfileAvatarView _profilePictureLongPress…` | **enlarge profile pictures** |
| `z35f780c916e` | `IGAPIUserDict followingCount`, `IGFollowListIntentTarget followListType` | follow-back status, local profile stats |
| `zc634f23e165`, `z78bef3c6012` | `IGActiveUserSessions presentedUserSession`, `IGSessionManagerInitContext sessionManager`; `IGAuthHeaderStore reloadAuthHeadersData` | account-aware settings profiles (**the auth-header store is an account-credential object: not examined further**) |

## Where Rocket's targets and ours differ on 456 (the useful half)

Rocket 4.27.2 is built **for 456**, so every selector above is a hook point that exists there. Against it, the Instagram tweak (4.8.3, tested on 410/439/441) has these gaps on
456, found by `tools/objc-diff.py` (410 -> 450 and `--check` on 456, main binary and `FBSharedFramework` merged):

- **12 classes we hook exist only as Swift-mangled names and were never bound** (`SCIResolveClass` only for 25 others). Nine are missing the selector we hook; **three have it and
  were silently inert**: `IGDirectThreadViewListAdapterDataSource` (hide DM "seen": `shouldUpdateLastSeenMessage` — also in Rocket's DM-seen component), `IGCommentCell`
  (copy a comment), `IGDirectInboxViewController` (ask before refreshing). **Fixed on branch `instagram-450`.**
- **Renamed or re-typed selectors**, fixed on the branch: `-_onLikeButtonPressed` lost its sender, the two call-button taps lost theirs, the three feed-playback initialisers, the DM
  recipient search storage init, `IGDirectRealtimeIrisDeltaApplicator -_applyThreadUpdates:appliedInMemoryBlock:`, the story-ad opt-in init (3 arguments), the screenshot callback now on
  `IGDirectVisualMessageViewerEventHandler`, the Shh toggle on `IGDirectThreadViewMessageListFeatureController`, and `IGFollowController` (Swift; two new entry points).
- **Still open**: reels "ask before refresh" and the story "advance" hooks (the feed controller lost 564 methods); the three Instants-disabling gates; `IGDirectMessageCell
  configureWithViewModel:…` (the deleted-message mark); `IGProfileActionBarViewModel`'s initialiser; the Reels like/repost taps on `IGSundialViewerVerticalUFI` (Swift class has `didLongPressLikeButton:`
  and not the `_didTap…` ones).
- **Tab hiding on the glass bar**: our `IGTabBarController _buttonForTabBarSurface:` / `_layoutTabBar` / `IGTabBarControllerSwipeCoordinator` hooks all exist in 456, but on iOS 26/27 the bar
  Instagram draws is `IGLiquidGlassInteractiveTabBar` (button container + `tabButtons`), which is what Rocket's tab-bar component loads. **Whether our hiding reaches it is not known without an
  account**; Rocket's selectors above are the lead.

## What is worth taking (nothing copied; ideas and hook points only)

1. **Discreet mode** — mark our own buttons and overlays with `IGScreenCaptureProtectionViewProvider` / protected layers so they are not in screenshots or recordings. Cheap, and Rocket ships it.
2. **Following as the default Home feed** — the three selectors on `IGMainFeedDataController` / `IGHomeFeedHeader` / `IGMainFeedViewModel` above (already on our "Instagram features whose selectors are confirmed" list).
3. **Hooks on the glass tab bar** — Rocket's custom tab bar and themes are built on `IGLiquidGlassInteractiveTabBar`; Instagram 456 also has its **own** tab reorder and theme entry
   (`IGTabBarController presentYourInstagramTabReorderEntry`, `isAppThemeCustomizeEntryEnabled`, `customizeCoordinator:didReorderFromIndex:toIndex:`, `customGlassTintColor`): a tweak that
   *forces those on* may deliver tab reorder and colours with Instagram's own UI instead of a second tab bar.
4. **Save without the collection picker** (`feedItemUFICellDidTapSaveButton:`) and **clickable addresses** (`IGCoreTextView` link lookup) — one selector each.
5. **Story and DM seen control** — Rocket's selector set is the most complete list of the doors (`hasSeenMediaId:forReelPK:`, `setSeenMediaId:forReelPK:`, `IGStorySeenState … forceSeenIds:`, `markLastMessageAsSeen`,
   `IGDirectLastSeenMessageInfo`). Our hooks use other doors (`IGStoryPendingSeenStateStore`, the network layer); compare before changing.
6. **Download-quality choice** (4.27.1/4.27.2): the vendor says it "selects an available resolution"; how it lists renditions is in its hashed code, not in the clear — our downloader already reads
   Instagram's rendition list (`SCIMediaDownloader`), so a picker is a UI task, not a research one.
7. Not proposed: **call recording** (CLAUDE.md §2), the **paid store**, anything touching **account credentials** (`IGAuthHeaderStore`).

## Limits, stated

Class and string names are hashed and encrypted; a feature is named from the Instagram selectors it loads, so two features that share selectors look alike. Nothing was run: not Rocket, and
Instagram 456 only after its Rocket load command was redirected to a harmless system library (so only Instagram and our tweak ran), in the iOS 26.5 and 27.0 simulators, where it reaches the login
screen and shows our welcome and "newer than tested" notice. No account was signed in, so no feature was exercised.
