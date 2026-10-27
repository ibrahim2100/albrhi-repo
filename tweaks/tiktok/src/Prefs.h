#import <Foundation/Foundation.h>
#import "shared/src/SCIPanelGate.h"

///
/// Every preference this tweak has, named once.
///
/// String keys spread across feature files is how a typo becomes a feature that silently
/// never turns on. Here they are constants, so a mistake is a compile error.
///

/// Drops a feed item the server itself marked as an ad, before it is ever built into a
/// cell. On by default: it is why someone installs this.
#define SCIPrefHideAds          @"hide_ads"

/// A download button in the feed itself, beside like/comment/share, rather than only a
/// list to come back to on the status screen.
#define SCIPrefDownloadButton   @"download_button"

/// Whether the anti-tamper / jailbreak-detection cluster runs. Answers TikTok's own
/// checks the way an unmodified phone would; touches nothing about payment.
#define SCIPrefBypass           @"bypass"

/// Three separate switches, not one -- a story's seen mark, a message's read receipt
/// and a profile view are three different things reported to three different places,
/// and turning one off should not silently touch the other two. Never touches what
/// shows on this device's own screen -- only what gets reported back.
#define SCIPrefPrivacyStory     @"privacy_story"
#define SCIPrefPrivacyMessages  @"privacy_messages"
#define SCIPrefPrivacyProfile   @"privacy_profile"

/// The logged-in account limit TikTok enforces in the client. Raised, not removed.
#define SCIPrefUnlimitedAccounts @"unlimited_accounts"

/// A direct message the sender took back. TikTok received it and then received an instruction to
/// hide it; hiding is the client's own doing, and this refuses that instruction. Nothing is
/// fetched back from a server.
#define SCIPrefKeepRecalled     @"keep_recalled"

/// A local record of who opened your profile, kept as they arrive — so somebody who blocks you
/// afterwards does not erase what TikTok had already delivered. Albrhi keeps its own list and
/// shows it on its own screen; TikTok's list is never modified.
#define SCIPrefVisitorLog       @"visitor_log"

/// The publish date, drawn under Albrhi's own button.
#define SCIPrefVideoDate        @"video_date"

/// TikTok's own profile-background editor, which ships switched off by a server-side experiment. Turning this on tells TikTok
/// the device is on that experiment's allow list (the flag is sent with the profile request) and, only while the editor is
/// resolving its state, supplies an empty background component so its controls exist. Off by default: it says something untrue.
#define SCIPrefProfileBackground @"profile_background"

#define SCIPrefVerboseLogging   @"verbose_logging"

/// Albrhi Panel's per-app switch, asked first. Every feature here reads its setting
/// through this one function, so turning the app off in the panel stands all of them
/// down at once -- the hooks stay installed and answer %orig, which is the only stop
/// that cannot leave the app half-patched.
static inline BOOL SCIPrefEnabled(NSString *key) {
    if (!SCIPanelAllowsThisApp()) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

/// The playback progress bar, kept visible.
///
/// TikTok fades its own bar out a moment after a video starts and only brings it back while
/// you are scrubbing, so there is normally no way to see how far through a clip you are.
/// NA9 keeps it up by answering `-setHidden:` and `-setAlpha:` on
/// `AWEFeedPlayerBottomProgressBar`, which is the same shape of fix as this project's other
/// "answer the question rather than fight the view" hooks.
#define SCIPrefProgressBar      @"show_progress_bar"

/// Saving the pictures from a photo post, not just video.
///
/// A TikTok photo post carries `imagePostInfo` / `imageList` / `images`, each confirmed in
/// the app's own binary. The download button already knows which model it belongs to, so
/// this is about what it does with a model whose media is pictures.
#define SCIPrefPhotoDownload    @"photo_download"

/// Fetch HD from tikwm.com, a third-party service, instead of from TikTok.
///
/// **Off by default and it stays off unless a person turns it on, deliberately.** This is the
/// one feature here that sends anything about what you are watching outside the app: the video
/// id goes to a service with no relationship to TikTok or to this tweak. That is the exact
/// thing the three privacy switches next to it exist to prevent, which is why it is a separate
/// switch with the trade written into its own row rather than a quiet quality improvement.
#define SCIPrefExternalHD       @"external_hd"

/// Offer to lay the post's sound over a single saved picture and write it as a short video.
///
/// On by default, and it is an *offer* rather than a behaviour: the question only appears when the
/// post actually has a resolvable sound and only for a single picture, so nothing about saving a
/// whole album changes. Off means one picture saves as one picture, with no question.
#define SCIPrefPhotoAudio       @"photo_audio"

/// The edition of the welcome screen this phone has seen (an integer, zero when none). The screen belongs to an *update*, not
/// to an install: it carries what that update changed, and it appears once, on the first launch after that update is
/// installed. `kSCIWelcomeEdition` in SCITTWelcome.m is raised by hand when a release has something worth saying, so an
/// ordinary patch release stays silent. (It replaced `welcome_seen_version`, a string that only ever recorded the first
/// install; that key is no longer read.)
#define SCIPrefWelcomeEdition   @"welcome_edition_seen"

/// Ask before a like, and ask before a follow.
///
/// **Two switches rather than one, for the same reason privacy is three.** A like is a public act
/// on a video and a follow is a lasting relationship with an account; somebody who keeps
/// mis-tapping the heart while scrolling has no reason to be asked about the other.
///
/// Off by default, both: a confirmation changes what a tap does, and a tweak that silently puts a
/// dialog in front of TikTok's own like button is a tweak that broke liking as far as anybody who
/// did not ask for it is concerned.
#define SCIPrefConfirmLike      @"confirm_like"
#define SCIPrefConfirmFollow    @"confirm_follow"

/// Place the download button from `AWEAwemeBaseViewController` instead of the feed cell.
///
/// **Off, and it has no row in Settings on purpose: it crashed TikTok three times.** It is the
/// only surface that reaches direct messages and search, and the inheritance that makes it
/// attractive is real — the feed, direct messages and photo albums are three subclasses of that
/// one base. What has never held is placing a button from inside its `-setModel:` on this build.
///
/// Kept as a flag rather than deleted for two reasons: the code and its reasoning are worth more
/// than the space they cost, and a flag can be turned on from the plist to test a fix on a device
/// without shipping it to anyone. `%group`s that are never `%init`-ed do not compile, so the
/// installation reads this key — which also means the compiler cannot fold the branch away and
/// call it unreachable.
#define SCIPrefBaseSurface      @"base_button_surface"

/// Never tell TikTok's servers you are online.
///
/// Confirmed on 46.4.0 against `AWEIMActivityStatusReportManager`: `-p_enableReportOnlineStatus`
/// (`B16@0:8`), `-canFetchAsReportCurrentUserActivityStatus` (`B16@0:8`) and the two report calls
/// `-p_reportActivityStatusIfNeededWithParams:` / `-p_reportActivityStatusWithParams:`
/// (`v24@0:8@16`). Four chokepoints on one class, which is what the report layer actually is.
#define SCIPrefHideOnline       @"hide_online"

/// Stop a video restarting when it reaches the end.
///
/// `AWEFeedCellViewController -playerWillLoopPlaying:` (`v24@0:8@16`) beside `loopTimes` (`q`),
/// on the class this tweak already holds for the model behind the download button.
#define SCIPrefNoLoop           @"no_video_loop"

/// The country TikTok is told this phone is in. **Absent or empty means the real one**: nothing is rewritten until
/// somebody picks a country, and picking "real" again puts everything back (only what the app asks is answered
/// differently; nothing TikTok stored is ever written to).
///
/// Answers the region questions TikTok asks about itself and its carrier -- `TTKStoreRegionService -storeRegion`,
/// `TIKTOKRegionManager +region` and its siblings, `ATSRegionCacheManager -region`, the install-id classes'
/// `-currentAppRegion` and `CTCarrier`'s country and network codes -- each installed only where the build declares the
/// selector with the encoding it was written against.
#define SCIPrefRegionCode       @"region_code"

/// The speed a video plays at when TikTok itself asks for normal (1.0). Absent, or 1, means TikTok's own.
/// A rate TikTok asks for on purpose (its hold-to-speed-up) is left alone.
///
/// `TTKMediaSpeedControlService -setPlaybackRate:` (`v24@0:8d16`), `-changeToSpeed:` (`v24@0:8d16`) and
/// `-changeSpeed:logExtraDict:` (`v32@0:8d16@24`), confirmed on 46.4.0.
#define SCIPrefSpeedRate        @"playback_rate"

/// Ask for Face ID, Touch ID or the passcode when the app comes back from the background. Built from
/// notifications and LocalAuthentication alone, so it depends on no TikTok class at all.
/// Two fingers held anywhere in TikTok open the tweak's settings. Off by default: the row in TikTok's own Settings is the
/// way in, and a gesture that watches every touch on every window is there only for whoever asks for it.
#define SCIPrefGestureOpen      @"settings_gesture"

#define SCIPrefAppLock          @"app_lock"

/// Drop a LIVE item from the feed where the model is built, the same gate and the same moment as the ad filter: `AWEAwemeModel -isLive`
/// (`B16@0:8`, confirmed on 46.4.0). Off by default: it removes something that works.
#define SCIPrefHideLive         @"hide_live"

/// Stop TikTok putting suggested accounts into the feed. Refused at the decision, not hidden after: `TTKFeedUserRecommendManager`'s five
/// `can…RecommendedUsers…` gates answer NO, and a recommend-user card that is built anyway (`-isRecommendUserCard`, `-isUserRecommendBigCard`)
/// is dropped like an ad. Off by default.
#define SCIPrefSkipSuggested    @"skip_suggested"

/// A banner when somebody opens a message you sent. TikTok keeps the other side's read position per conversation
/// (`AWEIMMessageConversation -uidParticipantReadIndexDict`) and announces a change through `-p_notifyParticipantReadIndexDidUpdate`; this compares
/// each person's position with the one it saw before and tells you when one moved forward. The first sight of a conversation is a baseline and
/// says nothing, so opening an old chat never fires it. Off by default.
#define SCIPrefReadAlert        @"read_alert"


/// Likes and country under the publish date: `AWEAwemeModel -statistics` -> `-diggCount`, and `-region`. Drawn in the label the date already
/// owns, so there is no new view to place. Off by default.
#define SCIPrefVideoStats       @"video_stats"

/// Lift a comment box's length limit to 500 where it was 100 or more (`AWETextInputController -maxLength`, `Q16@0:8`). The server has the last
/// word: a comment it refuses is refused. Off by default.
#define SCIPrefLongComments     @"long_comments"

/// Open the comment sheet on a video whose comments are closed (`AWEAwemeModel -isForbidComment` answered NO). **Experimental**: the app opens
/// the sheet, and whether the server then returns comments is not known; the report counts how often the answer was changed. Off by default.
#define SCIPrefDisabledComments @"disabled_comments"

/// Offer the profile's sort menu (latest, popular, oldest) on every profile. TikTok decides per profile whether the menu exists:
/// `TTKProfileTabBarSortManager -shouldShowSort` and `-canRespondSortMethod` (both `B16@0:8`, confirmed on 46.4.0). Both answered YES.
/// **Whether the server sorts another person's videos is not known**; the report counts the answers. Off by default.
#define SCIPrefSortAnyProfile   @"sort_any_profile"

/// A banner with the number of videos when a profile opens: `TTKProfileTabBarSortManager -initWithUserID:awemeCount:` is built with exactly
/// that number when a profile's tab bar is made. Once per account per ten minutes. Off by default.
#define SCIPrefVideoCount       @"video_count"

/// Open a link to a site that is not TikTok's in Safari instead of TikTok's own in-app browser, at every door the app is known to use (the router,
/// the web container service, the two browser-or-system services, the Safari-view wrapper, and a web view in a browser asked to load a foreign host),
/// unwrapping TikTok's link-safety redirect first. TikTok's own addresses stay inside TikTok. See SCITTLinks.x. Off by default.
#define SCIPrefOpenInSafari     @"open_links_safari"

/// Hide the warning label TikTok draws over a video (`AWEPlayInteractionWarningElementView -updateContent:`, `v24@0:8@16`). It is hidden after
/// TikTok has filled it, never emptied: the video, and whatever the label was about, is untouched. Off by default.
#define SCIPrefHideWarnings     @"hide_warnings"

/// Remove the TikBot (AI chat) button from the feed's right rail. Refused at the decision, not hidden after:
/// `TTKPlayInteractionTikBotElement -p_shouldShowtikBotButton` and `-p_shouldShowTikbotButtonStatic` (`B16@0:8`) answer NO. Off by default.
#define SCIPrefHideTikBot       @"hide_tikbot"

/// Play a video's own sound when TikTok would have muted it: `TTKMediaMusicComponent -muteMusicIfNeeded` runs, and a mute asked of
/// `TTKMediaPlayerRuntime -setMute:` while it runs is answered NO. Off by default.
#define SCIPrefUnmute           @"unmute_videos"

/// Scroll to the next video when this one reaches its end instead of starting it again: `TTKMediaPlayerRuntime -playerWillLoopPlaying:` while
/// the feed (`AWENewFeedTableViewController`) is on screen calls its own `-scrollToNextVideo`. Needs the video to be allowed to end, so it does
/// not work together with "do not repeat a video". Off by default.
#define SCIPrefAutoAdvance      @"auto_advance"

/// Start on the Following tab. The tab is found by its class (`TikTokFeedTabItemFollowControl`) in the tab control's item list, its index is
/// remembered, and it is applied once per launch at `AWEFeedContainerViewController -createTabItemsWithSelectedIndex:`. A launch that did not
/// reach the feed after applying it is not applied again. Off by default.
#define SCIPrefOpenFollowing    @"open_following"

/// Lift the profile bio's length limit (`TTKEditProfileBioStrategy -maxTextLength`, `q16@0:8`) to 500. TikTok's server has the last word: a bio
/// it refuses is refused. Off by default.
#define SCIPrefLongBio          @"long_bio"

/// Hold the download button to copy something about the video: the account's name, its bio, the sound's link or the post's link and text.
/// Reads only what the model already holds. Off by default.
#define SCIPrefCopyMenu         @"copy_menu"

/// A Save button on the enlarged profile picture (`TTKEnlargeAvatarViewController`). Off by default.
#define SCIPrefSaveAvatar       @"save_avatar"

