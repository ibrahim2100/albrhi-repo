# Instagram 450.1.0 against the Instagram tweak (4.7.0)

`com.burbn.instagram_450.1.0_und3fined.ipa` (Downloads, 2026-10-08, decrypted), main binary 352 MB, **46,953 classes**; `FBSharedFramework` 5,588. `tools/objc-classes.py --dump` took 18 s; `tools/objc-diff.py --check <dump> --tweak tweaks/instagram` examined **148 hooked classes and 147 hooked selectors**. **Nothing here has run on a device**: it is what the binary says.

## What the check found

- **59 distinct hooked classes (65 hook sites) are not in the main binary.** 5 are UIKit (system classes, expected). **11** live in `FBSharedFramework` (found: `NSClassFromString` asks every image). **31** exist under a **Swift-mangled name** (`_TtC<n><Module><n><Class>`): the Objective-C name the tweak hooks no longer resolves, so each of those hooks is unbound on 450 until it also tries the mangled one. **12** have no counterpart under that rule (listed last).
- 18 hooked selectors are declared by no class in the chain (the check's first group); several were already per-version signatures on 410 (see CLAUDE.md §5.1) and are not new.

## Hooked classes renamed to a Swift name in 450.1.0

| tweak hooks | exists in 450.1.0 as | file |
|---|---|---|
| `IGBadgedNavigationButton` | `_TtC19IGProfileNavigation24IGBadgedNavigationButton` | `src/Features/General/SCSettingsMenuEntry.x` |
| `IGChainingFeedViewController` | `_TtC18IGPostChainingFeed28IGChainingFeedViewController` | `src/Features/Feed/HideFeedItems.xm` |
| `IGContextualFeedViewController` | `_TtC30IGContextualFeedViewController30IGContextualFeedViewController` | `src/Features/Feed/HideFeedItems.xm` |
| `IGCreationTextToolView` | `_TtC30IGStoryPostCaptureTextControls22IGCreationTextToolView` | `src/Features/General/HideMetaAI.xm` |
| `IGDirectComposer` | `_TtC16IGDirectComposer16IGDirectComposer` | `src/Features/General/HideMetaAI.xm` |
| `IGDirectInboxHeaderSectionController` | `_TtC32IGDirectInboxViewControllerSwift36IGDirectInboxHeaderSectionController` | `src/Features/General/NoSuggestedChats.x` |
| `IGDirectInboxListAdapterDataSource` | `_TtC34IGDirectInboxListAdapterDataSource34IGDirectInboxListAdapterDataSource` | `src/Tweak.x` |
| `IGDirectInboxNavigationHeaderView` | `_TtC33IGDirectInboxNavigationHeaderView33IGDirectInboxNavigationHeaderView` | `src/Features/General/HideMetaAI.xm` |
| `IGDirectMediaViewerViewController` | `_TtC27IGDirectMediaViewerKitSwift33IGDirectMediaViewerViewController` | `src/Tweak.x` |
| `IGDirectMessageCell` | `_TtC19IGDirectMessageCell19IGDirectMessageCell` | `src/Features/StoriesAndMessages/UnsentMarker.x` |
| `IGDirectMessageMenuConfiguration` | `_TtC32IGDirectMessageMenuConfiguration32IGDirectMessageMenuConfiguration` | `src/Features/StoriesAndMessages/DownloadAudioMessage.xm` |
| `IGDirectNotesBubbleEditorColorPaletteView` | `_TtC26IGNotesBubbleCreationSwift41IGDirectNotesBubbleEditorColorPaletteView` | `src/Features/General/NotesCustomization.x` |
| `IGDirectNotesCreationView` | `_TtC25IGDirectNotesCreationView25IGDirectNotesCreationView` | `src/Features/General/NotesCustomization.x` |
| `IGDirectNotesTrayRowCell` | `_TtC24IGDirectNotesTrayUISwift24IGDirectNotesTrayRowCell` | `src/Features/General/HideFriendsMap.x` |
| `IGDirectThreadViewMetaAISummaryFeatureController` | `_TtC48IGDirectThreadViewMetaAISummaryFeatureController48IGDirectThreadViewMetaAISummaryFeatureController` | `src/Features/General/HideMetaAI.xm` |
| `IGDirectVisualMessageReplayService` | `_TtC31IGDirectVisualMessageServiceKit34IGDirectVisualMessageReplayService` | `src/Tweak.x` |
| `IGDirectVisualMessageViewerSession` | `_TtC34IGDirectVisualMessageViewerSession34IGDirectVisualMessageViewerSession` | `src/Tweak.x` |
| `IGExploreListKitDataSource` | `_TtC28IGExploreViewControllerSwift26IGExploreListKitDataSource` | `src/Features/Feed/HideFeedItems.xm` |
| `IGFollowController` | `_TtC11IGFollowing18IGFollowController` | `src/Features/Confirm/FollowConfirm.x` |
| `IGMainStoryTrayDataSource` | `_TtC25IGMainStoryTrayDataSource25IGMainStoryTrayDataSource` | `src/Tweak.x` |
| `IGProfileHeaderView` | `_TtC15IGProfileHeader19IGProfileHeaderView` | `src/Features/General/NoSuggestedUsers.x` |
| `IGRecentSearchStore` | `_TtC19IGRecentSearchStore19IGRecentSearchStore` | `src/Features/General/NoRecentSearches.x` |
| `IGSearchEntityRouter` | `_TtC20IGSearchEntityRouter20IGSearchEntityRouter` | `src/Features/General/NoRecentSearches.x` |
| `IGSearchListKitDataSource` | `_TtC15IGGenericSearch25IGSearchListKitDataSource` | `src/Tweak.x` |
| `IGStoryAdsManager` | `_TtC17IGStoryAdsManager17IGStoryAdsManager` | `src/Features/Feed/HideFeedItems.xm` |
| `IGStoryAdsOptInTextView` | `_TtC12IGStoryAdsUI23IGStoryAdsOptInTextView` | `src/Features/Feed/HideFeedItems.xm` |
| `IGStoryFullscreenDefaultFooterView` | `_TtC20IGStoryDefaultFooter34IGStoryFullscreenDefaultFooterView` | `src/Features/Confirm/LikeConfirm.x` |
| `IGSuggestionsUnitViewModel` | `_TtC17IGSuggestionsUnit26IGSuggestionsUnitViewModel` | `src/Features/General/NoSuggestedUsers.x` |
| `IGSundialFeedDataSource` | `_TtC23IGSundialFeedDataSource23IGSundialFeedDataSource` | `src/Features/Feed/HideFeedItems.xm` |
| `IGSundialViewerVerticalUFI` | `_TtC26IGSundialViewerVerticalUFI26IGSundialViewerVerticalUFI` | `src/Tweak.x` |
| `IGVideoPlayerOverlayContainerView` | `_TtC25IGModernFeedVideoOverlays33IGVideoPlayerOverlayContainerView` | `src/Features/Confirm/LikeConfirm.x` |

## Hooked classes in `FBSharedFramework` (found, nothing to do)

`IGAudioStatusAnnouncer`, `IGCoreTextView`, `IGDSMenu`, `IGDSSegmentedPillBarView`, `IGNetworkDispatcher`, `IGProfilePictureImageView`, `IGScreenshotObserver`, `IGTabBarButton`, `IGTallNavigationBarView`, `IGTapButton`, `_TtC18IGNavConfiguration18IGNavConfiguration`

## No counterpart found by the naming rule

| class | file |
|---|---|
| `IGCommentComposer` | `src/Features/Confirm/PostCommentConfirm.x` |
| `IGCommentThreadAICarousel` | `src/Features/General/HideMetaAI.xm` |
| `IGDirectThreadThemeKitSwift` | `src/Features/Confirm/ChangeThemeConfirm.x` |
| `IGDirectVisualMessageReportService` | `src/Tweak.x` |
| `IGFloatingActionButton` | `src/Features/General/HideMetaAI.xm` |
| `IGProfileHeaderIdentity` | `src/Features/General/FollowStatusBadge.xm` |
| `IGScreenshotObserverDelegate` | `src/Tweak.x` |
| `IGStoryAdPool` | `src/Features/Feed/HideFeedItems.xm` |
| `IGStoryAdsFetcher` | `src/Features/Feed/HideFeedItems.xm` |
| `IGSuggestedUnitViewModel` | `src/Features/General/NoSuggestedUsers.x` |
| `IGSundialViewerNavigationBarOld` | `src/Features/Reels/HideReelsHeader.x` |
| `IGVideoFeedViewController` | `src/Features/Feed/HideFeedItems.xm` |

## What it means, and what it does not

- **It says the hooks cannot attach**, not that the features are broken: the same method may be hooked on a sibling class, and a renamed class still needs its selectors checked (`objc-diff --check` again with the new names).
- The mangled names are stable per module, so a fix is a lookup that tries `NSClassFromString(@"IGFollowController")` and then the mangled form, behind the same encoding checks the newer tweaks use; the Instagram tweak is the one still written the old way (hooks installed whether or not the method exists).
- Which Instagram the owner's phone runs is not recorded here; the tweak's tested set remains 410, 439 and 441.
