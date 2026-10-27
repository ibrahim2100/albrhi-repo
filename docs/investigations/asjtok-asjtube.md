# ASJTok 1.3 (TikTok 47.0.0) and ASJTube 1.4 (YouTube) — what they do, what we took, what we refused

Written 2026-10-27. Both are **closed, unlicensed** dylibs (the repository has no source and no licence file), so the rule in
CLAUDE.md §2 applies: **architecture only, nothing copied, licence/store/DRM code not examined.** They were opened with REA
(Ghidra 12.1.4) for two questions only: *which classes and selectors do they hook*, and *what does each replacement return*.
Every selector below was then checked against the app's own binary (TikTok `MusicallyCore` 47.1.0, `tools/objc-classes.py`),
and who asks each one was measured with `docs/investigations/na9-scripts/callers.py`. A reference tweak's selector is a lead,
never evidence.

## How they are built

Both carry their own `MSHookMessageEx` shim (`class_getInstanceMethod` + `class_replaceMethod`), not Logos. ASJTok's hook table is
plain text in the installer procedure (541 calls); ASJTube's is the same shape, about ninety. Neither encrypts its selector names.

## ASJTok → TikTok 0.26.0

| feature | what the reference does (read) | what this project does | measured here |
|---|---|---|---|
| jailbreak bypass | not in its table; `+[BDADeviceHelper isJailBroken]` is a lead from the selector list | hooked under the existing bypass switch | class and `B16@0:8` in 47.1.0 |
| links in Safari | `shouldOpenURLInIAB:` → NO; `tryOpenURL:dataflowId:` opens http(s) with `openURL` and returns YES; also redirects `WKWebView loadRequest:` and four `GBLRouterImpl openURLString:` doors | the first two only, and only for an address `-isThirdHttpURL:` calls third-party | callers: `PHFDfidRouterServiceImpl` and the class itself; the string door calls the URL door |
| hide warning label | `AWEPlayInteractionWarningElementView -updateContent:` → orig, then `setHidden:YES` | same decision, own code | present, `v24@0:8@16` |
| hide TikBot | its hook for it is not in the main installer (its names sit in a table read elsewhere) | `-p_shouldShowtikBotButton` and `-p_shouldShowTikbotButtonStatic` → NO | read by `containerDidFullyDisplayWithReason:` and `…WithCompletion:` — a decision, not a view |
| sound on muted videos | `TTKMediaMusicComponent -muteMusicIfNeeded` raises a thread-local flag; `TTKMediaPlayerRuntime -setMute:` passes `mute & ~flag` | same shape | `muteMusicIfNeeded` is read by `-didPrepareForDisplay` |
| scroll at the end | `playerWillLoopPlaying:` → `-scrollToNextVideo` on the feed controller it tracked | same, plus a 1.2 s debounce and "feed on screen" | `scrollToNextVideo` `v16@0:8` on `AWENewFeedTableViewController` |
| start on Following | `segmentControlInitialIndex` replaced with the index of a tab typed 2; item type found by `valueForKey:` against a key list and by title strings | the tab is found **by class** (`TikTokFeedTabItemFollowControl`), applied once per launch, with a "did not finish" flag | `segmentControlInitialIndex` is read by `_generateSegmentControlByReason:` and `p_onFinishLogin` |
| longer bio | `TTKEditProfileBioStrategy -maxTextLength` → `NSIntegerMax` | 500 | **also** `AWEProfileEditTextViewController -maxTextLength` exists and reads it for nickname and username as well — left alone |
| longer comments | hooks `…CommentInputCoreAreaTextComponent growingTextView:shouldChangeTextInRange:replacementText:` → YES | **not taken**: that Swift class declares no such selector in the 47.1.0 metadata (it may arrive through a category the tool does not read); ours (`long_comments`) stays on `AWETextInputController -maxLength` | unverified either way |
| copy bio / username / music link / video info | adds items to a menu from a string table (`Copy Introduction`, …) | **our own sheet** on a hold of the download button, from the model's fields — TikTok's long-press panel was not read | `author.uniqueIDForShow`, `signature`, `music.shareInfo.shareUrl`, `shareURL`, `descriptionString` (all `@`) |
| save profile picture | adds a Save button to `TTKEnlargeAvatarViewController` and fetches from the user model | same screen, own button, the four `AWEUserModel` avatar sizes as one picture with fallbacks | `configWithUserModel:`, `viewDidAppear:`, `avatarLarger/300/Medium/Thumb` |

**Not taken, on purpose** (CLAUDE.md §2): saving every story somebody opens automatically (holds others' temporary content without
their knowledge); an auto-like button in LIVE; `PIPOStoreKitHelper -isJailBroken` (inside the in-app-purchase surface); anything in
its store or entitlement area (not examined); the story and rich-content auto-advance family (`scrollToNext`, `autoClose`,
`autoCloseAfterLastItem` — a later pass if wanted).

**Unverified on a device:** all nine switches. The Status screen's counters say whether each one's hook is on a path the app takes
("installed" beside zero is a finding, §4.2).

## ASJTube → nothing taken yet

Read only for what its table does with the *server-facing* flags, because that is where the Money rule bites:

* `YTColdConfig` / `YTHotConfig` — **twelve attestation getters return a constant 0**:
  `premiumClientSharedConfigEnableAttestationFor{GetPremium, GetDownloadAction, GetOfflineUpsell, YpcGetCart, YpcHandleIap,
  YpcHandleTransaction}OnClient`, `creatorClientConfigEnableAttestation`, `creatorClientConfigEnableIpcaAttestation`,
  `enableVisitorDataStoreMigrationAttestationClient`, `shouldSendAttestationPingForEarlyTerminatedVideos`,
  `clientInfraClientConfigIosPreloadAttestationChallenge`. That is the same shape as X's `app_attest_*`: telling the server the
  device does not attest. **Not taken** (§2).
* `isPlayableInBackground`, `playableInBackground`, `hasPlayableInBackground` → YES (background play and PiP for everyone). A Premium
  feature; our YouTube tweak does not do it (YouTube Music's "background playback without the upsell" is a different, documented
  case). Left to the owner.
* Ads (`adPlacementsArray`, `adSlotsArray`, `interstitialPodsArray`, `adParams`, …), promos (`canShowThrottledPromoWithFrequencyCap(s):`
  → NO), surveys, "are you still watching" (`enableYouthereCommandsOnIos` → NO): the first is what we already do in three places; the
  others are candidates for a later release.
* No Premium-subscription spoof was found in its table, but the background-play functions were not read to the end: absence of a
  finding, not a clean bill.
