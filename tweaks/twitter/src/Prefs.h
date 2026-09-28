#import <Foundation/Foundation.h>
#import "shared/src/SCIPanelGate.h"

///
/// Every preference this tweak has, named once.
///
/// String keys spread across feature files is how a typo becomes a feature that
/// silently never turns on: nothing checks that the key a hook reads is the key the
/// settings screen writes. Here they are constants, so a mistake is a compile error.
///

/// Whether the switch layer is hooked at all.
///
/// On, because with it off this release does nothing whatsoever -- there is no second
/// feature to fall back to. It exists so that a build of X where the hook causes trouble
/// can be made ordinary again from the settings screen rather than by uninstalling.
#define SCIPrefSwitchLayer      @"switch_layer"

/// The user's own answers, key to boolean. Written by the settings screen and read once
/// at launch; the shape is a dictionary rather than one preference per key because the
/// key names come from X and there is no list of them to declare in advance.
#define SCIPrefOverrides        @"switch_overrides"

/// One preference per named feature, so each is a plain boolean somebody could set from
/// anywhere -- rather than a second dictionary that only this code knows how to read.
///
/// The identifier after the prefix is fixed for life. Renaming one turns that feature off
/// on every device that had it on, silently, which is the kind of change that arrives as
/// "the update broke it" three weeks later.
#define SCIPrefFeaturePrefix    @"feature_"

/// Hiding the real Promoted Tweet -- an ordinary status the server marks `-isPromoted`,
/// unrelated to every `ssp_ads_*` switch "Hide ads" already turns off.
///
/// **Off by default, and marked experimental on the settings screen.** Read from a real
/// class dump, never confirmed on a phone: the class names and the property exist, whether
/// X's home timeline actually routes a promoted status through them on 12.15 is the one
/// thing only a device can answer. Shipped to be tried, not shipped as fixed.
#define SCIPrefHidePromoted     @"hide_promoted_tweets"

/// There is deliberately no preference for the two-finger hold.
///
/// It is the only way into this tweak's own screen, and a switch that can make the only
/// way in disappear is a switch that strands people -- the panel in Settings offers "off
/// for this app" and nothing finer, so there would be nowhere to turn it back on from.
/// Two fingers held for two thirds of a second is rare enough in a scrolling app to not
/// need one.

/// The download button drawn on the video itself, in X's own media chrome.
///
/// On by default: it is the thing people ask for by name, and a download button that ships
/// off is a feature nobody finds. The list under the two-finger hold is the fallback for a
/// build where X has renamed the view this rides on -- so turning this off leaves saving
/// working, which is why it is safe to default on.
#define SCIPrefInlineButton     @"inline_download_button"

/// Moving the in-video save button, and where it was put.
///
/// The switch is a mode, not a setting that stays on: with it on the button can be dragged and a
/// tap pins it (which turns the switch back off), so a button that moves never also downloads.
/// The place is stored as a fraction of the room the button has on the video card -- two numbers
/// from 0 to 1 -- and never as points, which are a different spot on every other card and are
/// how a user-placed button walks off. Absent means the original spot under X's back button.
#define SCIPrefMoveSaveButton   @"move_save_button"
#define SCIPrefSaveButtonPlace  @"save_button_place"

// Promoted trends are hidden by the switch above rather than by a key of their own: it is
// the same discovery on a sibling surface -- `-isPromoted` reachable from the
// server-populated model, on `TwitterURT.PromotableTrend` instead of `TFNTwitterStatus`.
// `SCIPrefHidePromotedTrends` used to be defined here for it and was read by nothing, which
// is the shape this project already refuses elsewhere: a key that decides nothing reads as
// a feature that broke.

/// Asks before a repost goes out, the way this project already asks before a DM's seen
/// receipt or an Instagram like -- a mis-tap on Retweet is a mis-tap that reaches every
/// follower, and undoing it does not un-notify anyone who already saw it.
///
/// Off by default. X's own retweet button costs one tap already; this adds a second, and
/// that is a real cost to weigh against the mis-tap it prevents, not a free safety net --
/// so the choice is left to whoever actually wants it rather than assumed for everyone.
#define SCIPrefConfirmRepost     @"confirm_repost"

/// Whether the download button also offers to save a profile photo, from the profile
/// screen's own avatar-tap gesture.
#define SCIPrefSaveAvatar        @"save_avatar"

// `hide_suggested_accounts` is gone. It hid every T1UserRecommendationView blindly, which
// is what "nothing says where X uses this class" leaves you with, and the timeline filter
// does the same job by matching the view model -- so the two were one intention with two
// switches, next to each other on one page.


#define SCIPrefVerboseLogging   @"verbose_logging"

// MARK: - Links and privacy
//
// Read from BHTwitter's own source for *where* each of these lives, never for its code:
// that repository ships no LICENCE file, so it is architecture only -- the same line this
// project draws at carsurf, NA9 and VibeTok, and the opposite of what GPLv3 allowed for
// NextUp and EeveeSpotify.

/// Strips `s` and `t` from an x.com/twitter.com link the moment it is copied. Those two
/// parameters identify the account that shared it, which is a thing a link should not carry
/// into somebody else's inbox.
#define SCIPrefStripTracking     @"strip_tracking_params"

/// Shows where a link actually goes instead of the `t.co` wrapper.
#define SCIPrefExpandLinks       @"expand_links"

/// Stops the search box offering what was typed before.
#define SCIPrefNoSearchHistory   @"no_search_history"

// Opening links in Safari is a named feature rather than a preference here: the decision X
// actually makes is a feature switch (`ios_in_app_article_webview_enabled`), found in a
// device report after two releases spent hooking browser classes. See SCITWFeatures.m.

/// Face ID or a passcode before X will show anything.
#define SCIPrefAppLock           @"app_lock"

// MARK: - Timeline clutter

#define SCIPrefHideWhoToFollow   @"hide_who_to_follow"
#define SCIPrefHideTopics        @"hide_topics"
#define SCIPrefHideTrendVideos   @"hide_trend_videos"

// MARK: - The row of buttons under a post

// `hide_view_count` is gone as well: the named feature answers
// `view_counts_public_visibility_enabled` instead, so the count is never drawn rather
// than drawn and covered over.
#define SCIPrefHideBookmark      @"hide_bookmark_button"

/// A long press on share renders the post as an image.
#define SCIPrefTweetToImage      @"tweet_to_image"

// Four of BHTwitter's switches have no target in X 12.20 and are deliberately not defined:
// `_t1_showPremiumUpsellIfNeeded`, `-isVODCaptionsEnabled` and
// `TFNTableView -setShowsVerticalScrollIndicator:` are not in the app's class metadata at
// all, and clearing the app's cache at launch was left out rather than shipped as something
// that deletes files to no measured benefit. A switch that decides nothing is worse than a
// missing one: it reads as a feature that does not work.

// MARK: - Extras

#define SCIPrefUndoPost          @"undo_post"
#define SCIPrefCopyProfileInfo   @"copy_profile_info"
#define SCIPrefBioTranslate      @"bio_translate"
#define SCIPrefHighQualityUpload @"high_quality_upload"
#define SCIPrefFullFrameImages   @"full_frame_images"

/// Forces left-to-right text direction throughout the app.
///
/// **Off, and it stays off unless somebody asks for it.** The working language of this
/// project is Arabic; forcing LTR on `NSParagraphStyle` changes the direction of every
/// piece of text X draws, not only the one somebody was annoyed by.
#define SCIPrefDisableRTL        @"disable_rtl"

// MARK: - Confirmations

#define SCIPrefConfirmLike       @"confirm_like"
#define SCIPrefConfirmFollow     @"confirm_follow"
