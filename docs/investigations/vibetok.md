# VibeTok 1.77 (DeNsor, `com.den.vibett`) — read as if the source were in hand

Read 2026-11-09 at the owner's request. **Architecture and behaviour only; nothing was copied, and nothing here is meant to be pasted back into code.**
VibeTok has no licence file (§2 of `CLAUDE.md`: unlicensed reference). It was opened with REA, then **all 472 functions in its `__text` were decompiled in one
Ghidra 12.1.4 headless pass** (`DumpAll.java`, scratchpad only) and read from the compacted output. The package has no licence, activation, device-identity or
crypto code to set aside: `nm -u` shows no IOKit / `MGCopyAnswer` / Security / CommonCrypto / `ptrace` / `sysctl` import, and a search of every ASCII and UTF-16 string for
licence, activation, subscription, token, UDID, serial and analytics words found nothing relevant.

- **File:** `https://6gr8.github.io/deno.io/files/VibeTokV1.77.deb` (258,790 bytes, SHA-256 `424d14cd…c453710`), rootless (`/var/jb`), `1.77-1+debug`.
  Dylib SHA-256 `ed6a9224…319dea`, arm64, 1.5 MB, one source file (`Tweak.xm`). Filter: `com.zhiliaoapp.musically`, `com.ss.iphone.ugc.Ame`, `com.zhiliaoapp.musically.vibe`.
- **Not stripped.** Logos names survive, so the table below is exact for the hooks; what a body does was read, not guessed, except where marked *(named, not read)*.
- **Not read in full:** the settings UI (`VibeTokSettingsController`, `MSG*` pages reused from the author's Messenger tweak, `VibeTokInfoCardController`, `VibeTokLinkCell`),
  `DENSOLogger` (a runtime class/method scanner: type a class name, get its methods, copy), `LocalizationHelper` (English/Spanish tables) and `+[VibeTokTracker]`'s plist plumbing beyond its API.

## 1. How it is built

- **One ungrouped Logos file.** `_logosLocalInit` runs from the constructor and installs **90 `MSHookMessageEx` replacements and 34 `class_addMethod` additions in one go**, on 52 class names
  looked up with `objc_getClass`. **There is no gate of any kind**: no check that a class or selector exists on this TikTok build, no type-encoding check, no launch guard, no panel, no
  master switch. A missing class turns the call into `MSHookMessageEx(NULL, …)`; a selector the class lacks is *added* (the fault §4.2 describes). It is written for one TikTok build.
- **Switches are read at call time from `NSUserDefaults.standardUserDefaults` of TikTok itself**, one `boolForKey:` per hook, so every row works without a restart and nothing is shared
  with a panel. The only key the tweak writes by itself is `readchats2` (the eye button, §2.3). Two caches are stored the same way (`vt_visitor_cache`, `vt_visitor_order`).
- **`NSLog` is unconditional** on several paths (profile visits, name colour, `[VibeTok] Tweak Loaded`).
- **Settings entry** reuses TikTok's native list: `TTKSettingsViewController -sectionViewModels` appends a section of three `AWESettingItemModel` rows (VibeTok, Help, Check for update) and
  `TTKSettingsBaseCellPlugin -didSelectItemAtIndex:` dispatches on the row's identifier (`VibeTok`, `VibeTok_Dev` → opens `t.me/DENS0R`, `VibeTok_repo` → the update check). It also *adds*
  `-version:isLowerThan:` to that class with a hand-built type string. This is the same recipe as our §5.4 (0.24.0), reached independently. A second entry is an eye button in the DM
  navigation bar (§2.3) and a bolt button on `AWENavigationBar` (`vibeButtonTapped:`).
- **Helper functions in the same file:** `confirm(block)` and `Likeconfirm(block)` (an `AWEUIAlertView` with two `AWEUIAlertAction`s built through KVC, `setValue:forKey:@"title"/"style"/"handler"`),
  `customalert(msg, button)`, `showToast`/`hideToast` (a `TUXBottomToast` with a bolt icon), `download_HD_Video`, `downloadPhoto`, `downloadAllPhotos`, and `VibeTok_Developer(bytes, n)`, a
  **XOR-0x55 string decoder** used in exactly one place (§2.6).

## 2. What each feature does (key in brackets is the `NSUserDefaults` key)

### 2.1 Messages
- **Keep recalled messages `[delgemes]`.** `TIMOMessage -setRecalled:` with YES does **not** call the original: it builds the string `serverMessageID` and, when both it and `-content` are non-empty,
  tells `VibeTokTracker` to store `{date: [NSDate date].description, content}` under the id. `-isRecalled` then answers **NO** whenever the id is tracked, and `-content` answers the stored
  content (the app's own when nothing is stored). So the message stays exactly as the person last saw it. **Marked, unlike what the first reading of this file said:**
  `AWEIMTextMessageTableViewCell -layoutSubviews` looks the cell's message id up and, when tracked, sets the bubble's background to a fixed colour (`bubbleView`). Content that is not an
  `NSString`/`NSNumber`/`NSData`/`NSDictionary`/`NSArray` is archived with `NSKeyedArchiver` first. The tracker's other methods (`isMessageTracked:`, `contentForMessageID:`,
  `trackedDateForMessageID:`, `deleteMessageID:`, `loadTrackingData`/`saveTrackingData:`) read and write one plist under the app's container; **no size ceiling was seen**.
- **Confirm before deleting `[deletemessage_conf]`.** `AWEIMMessageDataController -recallMessage:completion:` shows an alert (Delete / Cancel) built with TikTok's own `AWEUIAlertView`; Delete replays the original.
- **Undo `[undomessage]`.** `AWEIMMessageListViewController -willDeleteMessage:` shows an alert quoting `message.text` (read with `valueForKey:@"text"`) with Undo / Cancel; Undo runs a block that restores it.
- **No read receipts `[readchats2]`.** Nine methods of `AWEIMMessageReadComponent` are replaced: `p_markReadSyncToServerWithMessage:`, `p_debounceMarkReadSyncToServer`, `p_markMessageRead`,
  `p_markMessageAsReadLocally:`, `participantReadIndexDidUpdate`, `chatRoomDidAppear:`/`WillDisappear`/`DidBecomeActive`, `willDisplayCell:` and `messageListComponent:willDeleteMessage:` — each does
  nothing when the switch is on (the local mark included, which this project deliberately leaves alone, §5.4). **The switch has a button:** when `[readChats_V1]` is on,
  `AWENavigationBar -layoutSubviews` walks the responder chain to an `AWEIMMessageBaseViewController`, looks in the right-hand `rightBtnsContainerView` stack for a button tagged 666 and adds
  one if absent — an `eye` / `eye.slash` SF Symbol, white — whose tap (`vibeButtonTapped:`) flips `readchats2` and the icon.
- **No typing indicator `[ghostTYping]`.** `TIMInputStatusManager -sendInputStatusWithConversationID:inputStatus:` is skipped entirely when on.
- **Chat lock `[lockchats111111]`.** `AWEIMMessageListViewController -viewDidLoad` presents a full-screen blurred cover (a plain `UIViewController`, label «Authenticate or you can't view this chat», a Try Again
  button) and immediately runs `LAContext evaluatePolicy:` **policy 2 (device owner authentication, passcode allowed)**; success dismisses the cover on the main queue. The cover is presented
  *after* the original `viewDidLoad`, so the chat is built underneath it.
- **Voice message from a video `[upload_voice_msg]`, `[upload_voice_msg_VIDEOS]`.** `ChatInputVoiceMessageFeaturePack -handleRecordingButtonBeingTapped:` presents an action sheet ("Upload voice message — upload video as
  voice message") instead of recording; the choice opens a document/photo picker (`CommentAudioRecorderViewController` has the same on the comment side, with its own `UIImagePickerController` /
  `UIDocumentPicker` delegates). A picked video is read with `AVAsset`, **refused when longer than a constant (not resolved here, `DAT_000654a8`) or when it has no audio track**, exported on a
  background queue with `AVAssetExportSession` preset **AppleM4A** to `Documents/VibeTokVid.m4a` (an old copy is deleted first). Then `AVAudioRecorder -stop` is replaced: the original runs, and when
  the switch is on the file at the recorder's `url` (the selector name comes from the XOR decoder, §2.6) is **deleted and replaced by a copy of `VibeTokVid.m4a`**, so TikTok uploads the chosen audio as if it had been recorded.

### 2.2 Privacy
- **Hide story views `[StoriesVie…]`.** `TTKStoryMarkReadService -markAsRead:` logs `[VibeTok] Story…` and returns when on. **This selector is not in the class's runtime method list**
  (`TTKStoryMarkReadService` is Swift; §5.4) — on the build this was written for it may have been, on 47.x the hook adds a method nobody sends. Not checked against 1.77's target build.
- **Hide profile visits `[vistiPROF]`.** `TTKProfileViewsVisitor`: `-visit:` shows a toast («This profile has not been marked as visited») and does not call the original; `-p_shouldReportHasVeiwedProfileForUser:`
  and `-p_shouldReportProfileView` answer NO; `-reportProfileView` returns 0. Four doors, the same selectors as ours.
- **Visitor history.** `TTKProfileViewsPresenter -model` runs the original, and when the result is an array **merges every entry into a persisted cache**: key = the entry's `user.socialName` (a nil or empty
  name is skipped), value = the entry, plus an ordering array (new names go to the front); both are kept in `NSUserDefaults` (`vt_visitor_cache`, `vt_visitor_order`) and the **method returns the accumulated list**
  — people who visited on earlier days stay in it. The string in the UI says «even if they blocked you»; the code does not do anything about blocking (it only remembers what the server once sent).
- **Fast logout `[fastLogout]`** (*named, not read*): `AWESettingLoginOrSwitchCellPlugin -didTapLogoutSettingItem` / `-didTapLogoutOneClickLogin`.

### 2.3 Feed and profile
- **Ads `[hideads]`.** `AWEAwemeModel -init` and `-initWithDictionary:error:` call the original and **return nil** when `-isAds` or `-withPromotionalMusic` is true; `-setIsAds:` passes NO instead of YES;
  `-setAdSource:` is also replaced. **Always on, no switch:** `AWEOriginalAdModel -disableAdShow` / `-disableShowAdMore`, `TTKPersonalAdsPopup` and `TTKPersonalAdsOptimizationPopup -canShow:context:`.
- **Seek bar `[progressBar]`.** `AWEFeedPlayerBottomProgressBar -setHidden:` and `-setAlpha:` (alpha is forced to 1.0 when on) and a `-layoutSubviews` hook.
- **Like / follow confirmations `[likeConfirmation]`, `[followConfirm]`.** `TTKFeedInteractionLikeManager -onLikeButtonClicked` and `-doubleTapLikeWithAnimation:`; `AWEIMProfileRelationView -p_didTapFollowButton`;
  `AWEPlayInteractionUserAvatarElement -onFollowViewClicked:`. Each runs the original inside the alert's confirm block (the replay pattern §4.2 describes; `%orig` is not captured in a block here — the original function
  pointer is).
- **Flag and username `[show_flag]`, `[show_username]`.** `AWEPlayInteractionAuthorUserNameButton -authorLabel` writes **`author.region` as a flag emoji** (two letters → two regional-indicator scalars,
  uppercased, letters only) into the author's name label (single line, no shrinking), and with `show_username` appends `author.socialName`. (`vibetok_flagEmojiForCountryCode:` is a `%new`.)
- **Counts `[followFormat]`, `[likesandposts]`, `[formatcount]`, `[formatRepost]`.** Follower count is re-rendered with an `NSNumberFormatter` (decimal, grouping size 3) from `currentPageUser.followerCount`;
  the "Likes" title becomes "Likes & Posts" and the number is rewritten from `userStaticsInfo.awemeCount`; grid cells format counts and show a repost date (`yyyy-MM-dd`).
- **"Follows you" colour `[followstatus]`.** `TTKProfileExternalInfoUserNameComponent -p_getNameLabelTextColor` returns a fixed green when `userRelationInfo.followerStatus == 1`
  (the same signal our 0.24.0 once used and removed, §5.4); an `NSLog` on both paths.
- **Story rings `[vibeTokGradientStyle]`, `[vibeTokGRa]`** (`TTKStoryGradientBorderView -colors`, `-layoutSubviews`, `-getGradientForStyle:` with named styles such as blue and green) and an
  **OLED keyboard `[oled_keyboard]`** (`UIKBBackdropView -setBackgroundColor:`; the colour comes from `dataForKey:@"IGFormat_keyboard_color"` — the same key name as the author's Instagram tweak).
- **Liquid Glass `[liquid_glass_controls]`, `[liquid_glass_notices]`, `[liquid_glass_overlays]`.** Fourteen getters of `TUXExperiments` (`isLiquidGlass{Button,Menu,IntroPanel,Toast,CenterToast,BottomToast,FloatingNotice,InAppPush,Modal,Popover,Sheet,Dialog}Enabled`)
  plus `TUXLiquidGlassConfiguration -isInteractive`, grouped into three switches.
- **Favourites lock `[lockFavS]`.** `AWEFavoriteAwemeViewController -viewDidLoad` covers the screen the same way as the chat lock («Unlock to view your favorites»).
- **Many accounts `[VTUnlockMultiAccountCap]`.** `AWEUserService -maxLoginedAccounts` answers 100. **Always on:** `-canShowThirdPartyPhoneBindingPopup` (NO).
- **Clear search history `[ClearHistory]`.** `AppDelegate -application:didFinishLaunchingWithOptions:` calls the original, then `[[TTKSearchHistoryManager new] deleteAllSearchWord]` and returns 1.
- **Always on, no switch:** `NSObject -jailbroken` → 0 (on `NSObject`, so every object answers it), `+[IOSSecuritySuite amIJailbroken]` → 0 (a third-party detector library bundled in TikTok),
  `+[TTKABTest profileBgInAllowList]` → 1, and the profile-background pair: `TIKTOKProfileEditMainViewController -p_resolveProfileBackgroundSnapshot` sets a flag around the original, and
  `TTKProfileComponentResponseModel -profileBackground` returns, **only while that flag is set and the original returned nil**, an empty `TTKProfileBaseComponentModel` with `bizData = @{}` (it checks that the class
  answers `setBizData:`). **This is the recipe of our 0.25.0 exactly** — `ProfileBanner` was the reference there (§2) — except that VibeTok has no switch and tells the server nothing
  on the row.

### 2.4 Downloads (switches `[Downloadvideos]`, `[DownloadAv]`, `[downloadStory]`, `[download_stickers]`, `[downloadMemes]`, `[copyAnyText]`, `[opencommentsfeed]`, `[viewsCountS]`)
- **Where the button goes.** On the feed rail: `TTKFeedInteractionStackView -mewobutton:` (an 18 KB method and about thirty blocks: the choice sheet, the sub-actions and the HD path), with
  `-buttonTouchDown:`/`-buttonTouchUp:` for the pressed look; on photo/story detail: `TTKRichContentDetailViewController -viewDidLoad` adds an `arrow.down.circle.fill` button and `-mewobutton:`;
  username long-press (`AWEUserNameLabel -longpreSE:`) downloads the avatar; `TTKProfileTabLikeButton -longpreSE:` *(named, not read)*.
- **Where links come from.** The chosen model is the one of `AWEFeedCellViewController` / `AWEAwemeDetailCellViewController` / `TTKPhotoAlbum…CellController` (`model`), `currentPlayingStory`, `itemID`, then
  `video.filteredVideoBSModels`, **`h264DownloadURL`**, `playURLList`, `originURLList`; photos: `photoAlbum.photos[i].originPhotoURL` (the index from `currentIndex`). The choice sheet offers
  *Download video*, *Download audio* (video saved to a temp `VibeTokVidForAudio.mp4`, then exported to `VibeTokAudio.m4a`), *Download this image*, *Save current image to Photos*, *Save all images from this post*.
- **HD through `tikwm.com`.** `download_HD_Video(itemID)` formats `https://tikwm.com/video/media/hdplay/<id>.mp4`, issues a **plain GET** (UA `Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 …)`,
  `Accept: video/mp4`, no cache), and on 200 writes the body to `tmp/VibeTok_<…>.mp4` and into Photos with `PHPhotoLibrary performChanges`. No JSON step, no fallback. **No setting, warning
  or disclosure was seen for the third-party call** (our rule: off by default, said on the row, §2).
- **Comments.** `TTKCommentPhotoSlideDetailViewController -handleLongPress:` (action sheet: Download image / Copy link), `CommentStickerPreviewPanelView -longpreSE:` (Download image / Copy image; with the
  switch off it only says «Enable 'Download stickers' in VibeTok settings»), `AWECommentPanelCell -handleLongPress:` (copies the comment's text with a toast when `copyAnyText`; with
  `opencommentsfeed` it opens a link in the comment instead, or tells the person it cannot).
- **Copy any text.** `TTTAttributedLabel -layoutSubviews` (arms a long-press) and `-copyText:` (puts the label's text on the pasteboard, toast «Text copied»).
- **Play count on photo posts `[viewsCountS]`.** KVO on `model.currentPlayingStory` and `model.currentPlayingStory.statistics.playCount` (observed in `-viewDidLoad`, removed in `-viewDidDisappear:`) feeds a label via `mewo_updatePlayCount`.

### 2.5 The network
Exactly **two** kinds of request, both plain `GET`s: `tikwm.com/video/media/hdplay/<id>.mp4` and `https://raw.githubusercontent.com/6gr8/VibeTok/refs/heads/main/version.json`.
The second is fetched from `AWENewFeedTableViewController -viewDidLoad → -checkForUpdate` (a guard flag stops overlap), parsed as JSON for `latest_version`, and compared with `-version:isLowerThan:` (dotted
numbers, missing parts read as 0). A newer version shows a full-screen blurred sheet («New Version Available», **a message that asks the person not to post about it on Reddit if they cancel**, Update / Cancel);
Update opens `t.me/DENS0R`. **It runs on every feed controller load, not once per launch**, and the Settings «Check for update» row runs the same request. Nothing else is sent: no identifiers, no usage report.

### 2.6 The one obfuscated spot
`VibeTok_Developer` XOR-decodes three strings and nothing else: `upload_voice_msg`, `url` (sent as a selector with `objc_msgSend` to read the recorder's `url`), and `VibeTokVid.m4a`. It hides the
voice-message feature's key and file name from `strings`, not anything about licensing; it is the only place the author does.

## 3. What this says about the build it targets
- **Selectors it assumes**, checkable against 47.x with `tools/objc-classes.py` before anything is borrowed: `TIMOMessage` (`setRecalled:`, `content`, `isRecalled`, `serverMessageID`), `AWEIMMessageReadComponent` (nine
  `p_…` and `chatRoom…` methods), `TIMInputStatusManager`, `AWEAwemeModel` (`isAds`, `withPromotionalMusic`, `setAdSource:`), `AWEUserService maxLoginedAccounts`, `TTKProfileViewsPresenter model`,
  `AWEPlayInteractionAuthorUserNameButton authorLabel` (+ `nameLabel`), `AWEIMMessageBaseViewController` + `AWENavigationBar rightBtnsContainerView`, `IOSSecuritySuite +amIJailbroken`.
- **It does not feature-detect, so a hook that attaches is not a hook that works** (§4.2). Which of its 90 hooks do anything on the owner's 47.x is **unknown**: the dylib was not run.
- The class names `TIMOMessage`, `TIMInputStatusManager`, `AWEIMMessageReadComponent` are the IM (messaging) side, which our TikTok tweak touches only for read-sync (§5.4).

## 4. Against this project
**Same shape as ours already:** native settings section (0.24.0), profile background (0.25.0, identical allow-flag + empty `bizData` recipe), four-door profile-visit block, `isAds`-based ad filter, seek bar,
like/follow confirmations, multi-account cap, jailbreak answers, history wipe at launch (ours is a size-threshold cache clean, and never a search-history wipe).
**What it has that we do not:** keep recalled messages in TikTok DMs *with a coloured bubble*, a read-receipt switch with an **eye button in the chat bar**, typing-indicator off, chat and favourites lock behind
`LAContext` (ours: `app lock` only, §5.4), turning a video into a voice message, a flag next to the author's name, exact follower/like/post counts, a persisted visitor history, fast logout, OLED
keyboard, story-ring styles, liquid-glass switches.
**What it does worse:** no gate or encoding check on any hook (one missing class takes the whole `%ctor` path with it); `NSObject -jailbroken` on every object; story hook on a method the Swift class does not list;
launch-time search-history wipe; ads removed by returning nil from `-init`; four always-on server-facing lies (`profileBgInAllowList`, `amIJailbroken`, `jailbroken`) with no row or warning; a third-party call with no disclosure; an
update nag on every feed load; no ceiling on the recalled-message plist; `NSLog` on hot paths.
**If the owner asks for any of it** (each needs its selector asked of the 47.x binary first, §4.1, and every one belongs behind our usual switch-off-by-default and the encoding check):
1. typing-indicator off (`TIMInputStatusManager`; one hook),
2. keep recalled TikTok messages with a marked bubble — the Instagram design (§2 "never leave no trace"), with a ceiling,
3. chat / favourites lock by `LAContext` (the app-lock code already exists),
4. exact counts and the flag by the author (cosmetic, no server cost),
5. audio-file voice messages (the most work: picker, export, recorder swap; the author's version replaces the recorded file after `-stop`).
Not taken on purpose: anything that tells the server something untrue without a row saying so (§2), and the ad filter's `-init → nil`.
