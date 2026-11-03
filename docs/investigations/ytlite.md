# YTLite 6.0 ("YouTube Plus") — read for architecture and its public feature list

2026-11-03. `com.dvntm.ytlite_6.0_iphoneos-arm64e.deb` (the roothide flavour: `arm64e`, `@loader_path/.jbroot/…`), by dvntm /
dayanch96. **Nothing was copied and nothing was built from this**; it is a map of where YouTube 21.41.5 can be hooked and a
list of what this project's YouTube tweak does not do yet.

## The boundary, and why it is where it is

- **No licence file in the package.** The public repository (`dayanch96/YTLite`) shows source for `YTLite.x`, `Settings.x` and
  the rest, **and no `LICENSE`** (GitHub reports none); its README names only the third-party libraries it uses. No licence is not
  permission, so this is read as CLAUDE.md §2 reads every unlicensed reference: **architecture only, nothing copied.** The repository
  was **not read** for this report: the 6.0 binary is ahead of it (a downloads tab, an own player, parental control) and what was
  asked was the binary.
- **6.0 has an access layer.** The changelog says "License status and date in the tweak's settings" and "Fixed random 'Access denied'
  errors"; the English strings carry `Access.*` (device limit, device not linked, account not found, insufficient plan) and donation
  rows; the binary imports `SecKeyVerifySignature`, `SecKeyCreateWithData`, `CCCryptorGCM`, `CC_SHA256`, the keychain and `sysctl`.
  **That is the whole of what was said about it: it exists.** Its strings were set aside before reading (25 of 983 matched
  licence/donation/subscription words and were not read), its code was not opened, and `ref-leads.py` listed two protection
  selectors apart and unread. Same line as OSTikTok (`docs/investigations/ostiktok.md`) and Legizmo.
- **Refused as a feature, as always (§2 Money):** "Fixed YouTube Premium downloads on sideloaded installs (requires a YouTube Premium
  subscription)" is Premium-gated and stays where it is.

## What was run, and what answered

| tool | result |
|---|---|
| `ar`/`tar`, `plutil` | the package: `YTLite.dylib` (39 MB, `arm64`), `YTLite.plist` (filter: `com.google.ios.youtube` **and** `com.dvntm.youtubeplus`), a resource bundle (`Assets.car`, two silent/sponsor audio files, 13 `.lproj`) |
| **REA** `open_binary` | opened (Mach-O, arm64). **`binary_overview` timed out at 330 s** — the whole 39 MB image is analysed before the first answer, the same wall OSTikTok hit. Nothing was decompiled |
| **REA** `inspect_macho` | answered (2.1 M characters of load commands, imports, exports; it does not need the decompiler). What it established: the hook engine and the access-layer imports above |
| `tools/objc-classes.py --dump` | 154 classes, 0.2 s. **All of them are this tweak's own**; none is a YouTube class |
| `tools/ref-leads.py --tweak tweaks/youtube` | 1,348 app-side selectors named, 76 already in our sources, 2 protection names set aside |
| pairing against the real app | the 1,348 were looked up in a dump of **YouTube 21.41.5** (`com.google.ios.youtube-21.41.5-eeveedecrypter.ipa`, 33,809 classes): **463 are declared by some YouTube class**; the rest are the reference's own ivars, UIKit and Apple names |

**The hook engine is `MSHookMessageEx` from `libsubstrate`** (`@loader_path/.jbroot/usr/lib/libsubstrate.dylib`), with `class_addMethod`,
`objc_getClass`, `dlopen`/`dlsym`. The `_logos_*` symbols are stripped, and **YouTube's class names are not in the string table in
the clear** (a handful of strings mention `YTPlayerViewController`, `YTPivotBarView`), so a *hook table* — which class, which selector,
what the replacement returns — was **not recovered**. What is known is the set of selector names it depends on and which YouTube
classes declare them. **A selector in that list says the reference names it, not that it hooks it, and not what it does with it.**

## What the tweak is made of (its own 154 classes)

- **An own player and an own downloader**, not hooks: `YTPPlayerEngine`/`YTPPlayerVC`/`YTPMiniPlayer`/`YTPSeekBar`/`YTPSleepTimer`/
  `YTPSpeedControlView`, `YTPDownloader`/`YTPDownloadTask`/`YTPDownloadsDB`/`YTPDownloadsVC`, an **embedded FFmpegKit** (`FFmpegKit`,
  `FFprobeKit`, `FFmpegSession`) for converting, `YTPMP4Box`, `SRTParser`, a metadata editor.
- **SponsorBlock with submission** (`SBManager`, `SBSubmitter`, `SBSubmitVC`, `SBSegment`, `SbWhitelistVC`) and `YTPSegmentSkipper`.
- **Parental control** (`ParentalManager`, `…History…`, `…Channels…`, `…Limit…`, `…Links…`, `ParentalLockVC`): a screen-time and passcode
  product of its own, with a channel allow/blocklist.
- **Discord RPC** (`YTPDiscordRPC`: the watching status is sent to **a desktop server whose address the person types in**).
- Interface: `YTPLiquidGlass`, `TabEditorVC`/`TabbarVC`, `YTPButtonsOrderView` (reorder the tweak's overlay buttons), `DVNSheet*`.
- `DownloadMenuHelper`, `ShortsManager`, `FeedManager`, `PlayerManager`, `YTLHelper` — the glue where the hooks call in.

## The hook surface on YouTube 21.41.5 — selectors named by the reference, confirmed to exist, with their encodings

These are **leads**: each was asked of the 21.41.5 binary and answers with the encoding shown. None has been run.

**Experiment flags** (`YTColdConfig`, `YTHotConfig` — client experiment gates the app asks and a tweak can answer; `B16@0:8`):
`mediaEngineClientForceSoftwareDecoderOnDecoderRetry` · `homeClientIosEnableUnmutedImpOnVolumeUp` · `iosEnableVideoPlayerScrubber` ·
`disablePlaybackLockScreenController` · `isPersistentCastIconEnabled` · `enableShortsVideoQualityPicker` (`YTHotConfig`, also
`YTReelExperimentConfig`) · `enableHideChipsInTheCommentsHeaderOnScrollIos` · `enableSwipeToRemoveInPlaylistWatchEp` ·
`removeNextPaddleForSingletonVideos`/`removePreviousPaddleForSingletonVideos`/`replaceNextPaddleWithFastForwardButtonForSingletonVods`/
`replacePreviousPaddleWithRewindButtonForSingletonVods` · `queueClientGlobalConfigEnableFloatingPlaylistMinibar` ·
`enableYouthereCommandsOnIos` · `mainAppCoreClientIosEnableStartupAnimation`.

**Decisions and gestures** (the surfaces a feature would answer):

| area | class → selector (encoding) |
|---|---|
| hold to speed, speed label | `YTSpeedmasterController -speedmasterDidLongPressWithRecognizer:` (`v24@0:8@16`) · `YTActivePlaybackRateModel -activeRate` · `YTVarispeedSwitchControllerImpl -selectedVarispeedLabelText` |
| seek anywhere, double tap | `YTMainAppVideoPlayerOverlayView -setSeekAnywherePanGestureRecognizer:` (`v24@0:8@16` — **YouTube has its own seek-anywhere gesture**) · `YTMainAppVideoPlayerOverlayViewController -allowDoubleTapToSeekGestureRecognizer` / `-allowTwoFingerDoubleTapGestureRecognizer` (`B16@0:8`) |
| loop | `YTPlayerViewController -setLoopingEnabled:` (`v20@0:8B16`), also on `YTLocalPlaybackController`/`MDXPlaybackController` |
| fullscreen | `YTWatchFlowController -shouldExitFullScreenOnFinish` (`B16@0:8`) · `YTWatchViewController -preferredFullscreenOrientations` (`Q16@0:8`) |
| stable volume | `MLPlayerStickySettings -DRCEnabled` (`B16@0:8`) · `MLAudioFormatConstraint -initWithAudioTrack:audioQualityConfig:formatSelectionReason:DRCEnabled:` (`@44@0:8@16@24q32B40`) |
| audio track and captions | `YTIPlayerCaptionsTrackListRenderer -ml_defaultAudioTrackData` · `MLInnerTubeCaptionController -loadUserCaptionsBasedOnPastUserSelectionWithSelectionReason:` (`v24@0:8q16`) · `YTAudioTrackSwitchControllerImpl`/`YTVideoQualitySwitchRedesignedController -setUserSelectableFormats:` (`v24@0:8@16`) · `MLHAMMultiPlayerItem -playerItem:hasSelectableAudioFormats:` |
| **one door for menu items** | `YTMenuItemVisibilityHandlerImpl -shouldShowServiceItemRenderer:` (`B24@0:8@16`) |
| under-player sections | `YTWatchNextResultsViewController -setVisibleSections:` (`v24@0:8q16`) · `YTWatchStateController`/`YTFullscreenEngagementOverlayController -setRelatedVideosVisible:` (`v20@0:8B16`) |
| nags and promotions | `YTYouThereControllerImpl -shouldShowYouTherePrompt` · `YTPromoThrottleControllerImpl -canShowThrottledPromo` · `YTIShowFullscreenInterstitialCommand -shouldThrottleInterstitial` (all `B16@0:8`) · `YTSurveyController -showSurveyWithRenderer:surveyParentResponder:` (`v32@0:8@16@24`) · `YTInlineSignInController -didTapShowAddAccount` (`v16@0:8`) |
| Shorts | `YTReelPlayerViewController -reelContentViewRequestsAdvanceToNextVideo:` · `-handleLoopBehavior` · `-shouldAlwaysEnablePlayerBar` |
| header | `YTHeaderView -stickyNavHeaderEnabled` (`B16@0:8`) · `YTHeaderViewController -updateHeaderWithButtonsToDisplay:` (`v24@0:8@16`) · `YTRightNavigationButtons` (`searchButton`, `notificationButton`, `connectionsInboxButton`) |
| theme | `+[YTColor blackPure]` · `+[YTTokenColors blackPure]` |
| lock screen / MDX | `YTWatchPlaybackController`/`YTAppWatchControllerImpl -handleRemoteControlEvent:withInterval:` · `MDXLocalNetworkPermissionsImpl -verifyAccessWithCompletion:` |

## The 6.0 feature list against this tweak

The pasted changelog plus the English strings (958 of 983, protection set aside). **Ours already**: ad hiding, SponsorBlock (without
submitting or voting), the tab bar arranger, PiP, background playback, quality ceilings and the picker, downloads (own route, not
FFmpeg), fullscreen button direction, hide Ambient, hide endscreen/cards/paid promotion/Cast/Search/Create.

**Not ours, ranked by value to this owner and by how plainly the surface above answers it** (a *surface* is not a *design*; each
would still start with the encoding check and the "who calls it" scan):

1. **Software decoder on retry** — `YTColdConfig -mediaEngineClientForceSoftwareDecoderOnDecoderRetry`. The owner's iOS 16 episode
   (`docs/investigations/youtube-ios16-playback.md`) was a stuck hardware decoder (`-12913`) and the cure was a restart; this is the
   app's own flag for what to do *when the decoder fails and the player retries*. **The lesson of that investigation applies in full**:
   a switch that rewrites what the app does to cure a guessed cause is a second fault, so it would be off, limited to the retry
   path, counted, and its effect unknown until a device says.
2. **Stable volume** (`MLPlayerStickySettings -DRCEnabled`): YouTube's own loudness normalisation, answered YES.
3. **Preferred audio language / ignore auto-dubbed tracks / captions when the audio is not preferred**
   (`ml_defaultAudioTrackData`, `setUserSelectableFormats:`, `loadUserCaptionsBasedOnPastUserSelection…`): auto-dub is a common annoyance.
4. **Menu clean-up through one door** (`shouldShowServiceItemRenderer:`): Report, Play on different device, Save to playlist, Share…,
   by the renderer's identity, not by hiding views.
5. **Player gestures**: hold-to-speed (`YTSpeedmasterController`), seek anywhere (the app has the gesture; a flag may enable it), a
   loop button (`setLoopingEnabled:`), exit fullscreen at the end, portrait fullscreen.
6. **Nags**: "are you there?" prompt, throttled promos, fullscreen interstitials, the survey, the login reminder (all single-gate booleans).
7. Feed videos kept muted on volume keys, sticky navigation bar, hiding the right-hand navigation buttons, Shorts auto-skip.

**Not taken, and why:** the Premium-download fix (§2 Money); **Discord RPC** (it sends what is being watched to an address the person
enters — §2's rule is that such a feature is off until turned on and says so on its own row, and whether it is wanted at all is the
owner's call); **parental control** (a screen-time/passcode product of its own, with a different set of risks — a lock that a bug
makes permanent); **the own player and the FFmpeg conversion** (an engine, not a hook; the Download Centre already plays what it
saves); the access layer, donation rows and "supporters" screens.

## What this report does not say

It does not say what any of these hooks *return*, or which of the 463 names are hooked rather than called, or how YTLite behaves on a
device; **the binary was never run**. The count of *app-side* names is an over-count (ivars, UIKit). YouTube 21.41.5 is the build
asked; the changelog says 6.0 was adapted for 21.43, so a name absent from 21.41.5 may exist there. Nothing in this report has been
tried in this repository's own code.
