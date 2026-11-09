# VibeTok 1.77 (DeNsor, `com.den.vibett`) — what its dylib does

Read 2026-11-09 at the owner's request, with REA (Ghidra 12.1.4) and `nm`/`strings`. **Architecture and behaviour only; nothing copied.**
VibeTok is unlicensed (no licence file in the package; §2 of `CLAUDE.md` files it under "read for architecture"). The settings
UI, localisation and the "Logger" class scanner were not examined.

- Source: `https://6gr8.github.io/deno.io/files/VibeTokV1.77.deb` (258,790 bytes, SHA-256 `424d14cd…c453710`), a rootless
  (`/var/jb`) `+debug` build. Dylib SHA-256 `ed6a9224…319dea`, arm64 only, 1.5 MB, 1,729 procedures. Filter: TikTok
  (`com.zhiliaoapp.musically`), `com.ss.iphone.ugc.Ame`, `com.zhiliaoapp.musically.vibe`. Depends on `mobilesubstrate` only.
- **Not stripped.** The Logos symbols (`_logos_method$_ungrouped$Class$sel`) are all there: 208 replacement methods, 88 originals.
  Nothing is `%group`ed, so every hook installs at load and each one reads its own `NSUserDefaults` switch at call time.
- **Own classes:** `VibeTokTracker` (plist of recalled messages), `VibeTokSettingsController` & co. (Preferences-style UI),
  `DENSOLogger` (a runtime class/method scanner), `LocalizationHelper`. The `MSG*` classes are settings pages reused from the
  author's Messenger tweak.

## Hook table, by what it does (switch key in brackets, as stored)

**Decompiled and read:** keep-recalled, delete confirmation, undo, read-sync, story seen, profile visits, ads, jailbreak, multi-account, seek bar, history wipe, update check, the tracker. **Everything else in the table is inferred from the hooked selector and the strings beside it, not from its body** — marked *(named, not read)*.

| Feature | Hooks and what the replacement does |
|---|---|
| **Keep recalled messages** `[delgemes]` | `TIMOMessage -setRecalled:` when set to YES stores `serverMessageID → content` in `VibeTokTracker` (plist, keyed by id, with `NSDate description`), `-content` answers the stored text, `-isRecalled` answers NO while tracked. Shows nothing marking the message. |
| Confirm before deleting a message `[deletemessage_conf]` | `AWEIMMessageDataController -recallMessage:completion:` shows `AWEUIAlertView` (Delete/Cancel) and replays on Delete. |
| "Undo" a message you deleted `[undomessage]` | `AWEIMMessageListViewController -willDeleteMessage:` shows an alert with the message `text` (read by `valueForKey:`) and an Undo action. |
| No read receipts in chats `[readchats2]` | `AWEIMMessageReadComponent` — `-p_markReadSyncToServerWithMessage:` is swallowed; also hooked: `p_markMessageRead`, `p_markMessageAsReadLocally:`, `p_debounceMarkReadSyncToServer`, `participantReadIndexDidUpdate`, `chatRoomDidAppear:`/`WillDisappear`/`DidBecomeActive`, `willDisplayCell:`, `messageListComponent:willDeleteMessage:`. The local-only ones are hooked as well (ours leaves the local sibling alone, §5.4). |
| No typing indicator *(named, not read)* | `TIMInputStatusManager -sendInputStatusWithConversationID:inputStatus:` |
| No story seen mark `[StoriesVie…]` | `TTKStoryMarkReadService -markAsRead:` → `NSLog` and nothing else (**the Swift-class trap in §5.4: the method is not in the runtime list**, so this hook adds a method nobody sends). |
| Hidden profile visits `[vistiPROF]` | `TTKProfileViewsVisitor`: `-visit:` (shows a "not marked as visited" toast instead), `-p_shouldReportHasVeiwedProfileForUser:` and `-p_shouldReportProfileView` → NO, `-reportProfileView` → nothing. |
| Profile-visitors list incl. blockers *(named, not read; the string says "even if they blocked you")* | `TTKProfileViewsPresenter -model` plus own `vt_visitorCache` / `vt_orderKeys` / `vt_persistCache` (a cache of who visited, kept on the device). |
| Hide ads `[hideads]` | `AWEAwemeModel -init` and `-initWithDictionary:error:` return **nil** when `isAds` or `withPromotionalMusic`; `-setIsAds:` forces NO; `-setAdSource:`, `AWEOriginalAdModel -disableAdShow` / `-disableShowAdMore`, `TTKPersonalAdsPopup` / `TTKPersonalAdsOptimizationPopup -canShow:context:`. |
| Jailbreak detection | `NSObject -jailbroken` → NO, **on `NSObject`** (every object then answers `respondsToSelector:` YES for it — the fault §5.4 records for NA9's list). |
| More accounts `[VTUnlockMultiAccountCap]` | `AWEUserService -maxLoginedAccounts` → 100; `canShowThirdPartyPhoneBindingPopup`. |
| Seek bar always shown `[progressBar]` | `AWEFeedPlayerBottomProgressBar -setHidden:` and `-setAlpha:` (forces 1.0). |
| Like / follow confirmation *(named, not read)* | `TTKFeedInteractionLikeManager -onLikeButtonClicked`, `-doubleTapLikeWithAnimation:`; `AWEIMProfileRelationView -p_didTapFollowButton`, `AWEPlayInteractionUserAvatarElement -onFollowViewClicked:`. |
| Clear search history at launch `[ClearHistory]` | `AppDelegate -application:didFinishLaunchingWithOptions:` → `TTKSearchHistoryManager -deleteAllSearchWord` (erases what the person already had, on switch alone; §2 "never erase"). |
| Download media *(named, not read)* | Buttons added to `TTKFeedInteractionStackView` (`mewobutton:`), `TTKRichContentDetailViewController` (photo posts); long-press on the username (`AWEUserNameLabel`), on comment photos (`TTKCommentPhotoSlideDetailViewController`), on stickers (`CommentStickerPreviewPanelView`, saved through `UIImageWriteToSavedPhotosAlbum`). **HD through `https://tikwm.com/video/media/hdplay/%@.mp4`** — the third-party route §5.4 already records, with no off-by-default or disclosure found. Audio extraction through `AVAssetExportSession` to M4A. |
| Send an audio file as a voice message *(named, not read; the strings say "Done, now record a voice message" and "Audio extraction failed")* | `CommentAudioRecorderViewController` (`documentPicker…`, `vt_processVideoURL:`) and `ChatInputVoiceMessageFeaturePack -handleRecordingButtonBeingTapped:`, `AVAudioRecorder -stop` (swaps in the picked file). |
| Copy any text *(named, not read)* | Long-press on `TTTAttributedLabel` (`copyText:`), `AWECommentPanelCell -handleLongPress:`. |
| Chat / favourites lock *(named, not read)* | `LocalAuthentication`: `AWEIMMessageListViewController -VibeTokLock`, `AWEFavoriteAwemeViewController -VibeTokLock1` ("Authenticate to view chats / favorites"). |
| Profile background | `TIKTOKProfileEditMainViewController -p_resolveProfileBackgroundSnapshot`, `TTKProfileComponentResponseModel -profileBackground` — the same two places our 0.25.0 uses. |
| Cosmetics *(named, not read)* | Country flag next to the author name (`AWEPlayInteractionAuthorUserNameButton -authorLabel`, own `vibetok_flagEmojiForCountryCode:`), follower/like counts exact or formatted (`TTKProfileExternalUserRelationInfo*Component -updateUI`), "follows you" green name (`p_getNameLabelTextColor`), story-ring gradients (`TTKStoryGradientBorderView -colors`), dark keyboard (`UIKBBackdropView`), the whole Liquid Glass family of `TUXExperiments -isLiquidGlass*Enabled` and `TUXLiquidGlassConfiguration -isInteractive`. |
| Settings entry | `TTKSettingsViewController -sectionViewModels` + `TTKSettingsBaseCellPlugin -didSelectItemAtIndex:` (the native-section route our 0.24.0 uses), `AWENavigationBar -vibeButtonTapped:` (a button in the top bar), `AWESettingLoginOrSwitchCellPlugin -didTapLogout…` (named, not read). |

## What it sends out

- **Update check:** `AWENewFeedTableViewController -checkForUpdate` (the feed controller also hooks `-viewDidLoad`; that it is called from there was not read), a plain GET of
  `https://raw.githubusercontent.com/6gr8/VibeTok/refs/heads/main/version.json`, key `latest_version`, compared with a baked-in
  string (`version:isLowerThan:`); if newer, a full-screen blurred "New Version Available" sheet with Update/Cancel. A guard flag stops
  repeats within a run. No identifiers are attached beyond what `NSURLSession` always sends.
- `tikwm.com` for HD downloads (above). Social links in the About page only (Telegram, X, Instagram, GitHub).
- No licence, activation or entitlement code was seen in the hooks or classes listed (not examined further, by decision).
- `NSLog` calls on the profile-visit and story paths run unconditionally.

## Measured against this project

- **Same ideas we already have, same places:** profile background, native settings section, jailbreak, multi-account cap, ads
  (`isAds`), seek bar, profile-visit report. Four of VibeTok's choices are the ones §5.4 records as mistakes: `NSObject -jailbroken`
  (unguarded), `TTKStoryMarkReadService -markAsRead:` (added method, never called), message-read hooks that also swallow the local
  mark, and a launch-time history wipe.
- **What it has that we do not:** keep-recalled messages (we have it in Instagram, not TikTok), a lock on chats/favourites,
  sending an audio file as a voice message, exact follower/like counts, a country flag by the author name, chat typing-indicator off,
  fast logout. None has been checked against 47.x; the selectors are VibeTok 1.77's list for its own TikTok build.
- **What it does worse:** nothing marks a kept recalled message; the ad filter returns nil from `-init` (a nil model in a feed
  is a crash risk the §4.3 rules warn about); everything hooks at load with no encoding check.
- Candidates only if the owner asks (each needs its selector asked of the 47.x binary with `tools/objc-classes.py` first, §4.1):
  typing-indicator off (`TIMInputStatusManager`), a marked "recalled" badge, the chat/favourites lock, exact counts.
