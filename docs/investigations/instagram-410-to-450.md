# Instagram 410.1.0 -> 450.1.0, compared class by class (2026-11-24)

Method: `tools/objc-classes.py --dump` of both main binaries (410: 35,954 classes; 450: 46,953), `tools/objc-diff.py <410> <450> --tweak tweaks/instagram`
(34 selectors we name that changed, 31 classes we name that are gone) and `--check <450>`. **Nothing here has run signed in**: the simulator cannot
sign in, so it is what the binaries declare. On the simulator, 450.1.0 + the tweak launches on iOS 26.5 and iOS 27.0 and shows our welcome screen
and the "newer than tested" notice (the stock app needs a stand-in for `_MXSignpostMetricsSnapshot`, which the simulator's MetricKit lacks; that is the
simulator, not iOS 27 and not the tweak).

## Fixed on branch `instagram-450` (not published)

| feature | what 450 changed | hook added |
|---|---|---|
| confirm before liking a post | `IGUFIButtonBarView -_onLikeButtonPressed:` lost its sender (`v16@0:8`) | no-argument variant |
| hide call buttons | `IGDirectThreadCallButtonsCoordinator -_didTapAudioButton:` / `-_didTapVideoButton:` lost their sender | no-argument variants |
| confirm shh mode | `-swipeableScrollManagerDidEndDraggingAboveSwipeThreshold:` and `-messageListViewControllerDidToggleShhMode:` moved off `IGDirectThreadViewController` to `IGDirectThreadViewBottomSwipeFeatureController` / `IGDirectThreadViewMessageListFeatureController` (same encodings); `-shhModeTransitionButtonDidTap:` exists on no class | hooks on the two new classes |
| disable feed autoplay | `IGFeedPlaybackStrategy -initWithShouldDisableAutoplay:` is gone; three longer initialisers carry the flag first | all three hooked |
| no recent searches (DM recipients) | `IGDirectRecipientRecentSearchStorage` init is now `-initWithDiskManager:directRepo:launcherSet:` | group installed only where the class declares it |
| keep deleted messages | `IGDirectRealtimeIrisDeltaApplicator -_applyThreadUpdates:` is now `-_applyThreadUpdates:appliedInMemoryBlock:` (the cache applicator's `…completion:userAccess:` was already covered) | new selector hooked |
| reels auto-next | the feed lost every `_…AutoScroll…` method; the engine `IGSundialAutoScroll` answers `-isEnabled`; the feed has `-autoScrollBlockedByIncorrectLoopCount` | two more guarded gates (a guess from names, **not seen working**) |

## Not fixed, and why

- **Reels: confirm before refreshing** (`IGSundialFeedViewController -_refreshReelsWithParamsForNetworkRequest:userDidPullToRefresh:`) and the story "advance" hooks on the feed
  controller: the methods are gone from the class and no obvious successor exists (the feed controller gained 493 methods, lost 564). Needs a decompiler pass.
- **Disable instants (QuickSnap)**: `IGQuickSnapExperimentationHelper` kept `+isQuicksnapEnabled:` and `+isQuicksnapEnabledInInbox:` (still hooked) and lost the
  Feed / Stories / NotesTray ones; no replacement selector found.
- The five classes still unresolved from the 2026-11-01 check (`IGDirectMessageCell`, `IGDirectVisualMessageReplayService`, `IGDirectVisualMessageViewerSession`,
  `IGFollowController`, `IGStoryAdsOptInTextView`) have the class but not the selector we hook.
- Anything drawn by the glass tab bar of iOS 26/27 (the Instagram tab bar and our buttons placed against it) could not be looked at without an account.
