#import <Foundation/Foundation.h>
#import "SCIYTLaunchGuard.h"
#import "shared/src/SCIPanelGate.h"

///
/// Every preference this tweak has, named once.
///
/// String keys spread across feature files is how a typo becomes a feature that
/// silently never turns on: nothing checks that the key a hook reads is the key the
/// settings screen writes. Here they are constants, so a mistake is a compile error.
///
#define SCIPrefHideAds          @"hide_ads"
#define SCIPrefBackgroundPlay   @"background_playback"
/// Recovers "an error occurred" playback errors by reloading the player -- on by default, and
/// capped at two attempts per video so a video that genuinely cannot play is not reloaded forever.
#define SCIPrefFixPlaybackErrors @"fix_playback_errors"
#define SCIPrefHidePaidPromo    @"hide_paid_promotion"
#define SCIPrefBlockUpdateNag   @"block_update_nag"
/// Unlocks native, system Picture-in-Picture -- forces the one property that gates it by
/// account plan rather than by the video itself. Read from `MLVideo`, the same class
/// `-playableInBackground` is already hooked on.
#define SCIPrefNativePIP        @"native_picture_in_picture"

/// Lets the player's own display link run at the screen's real refresh ceiling, on a
/// ProMotion phone where YouTube caps it under that on its own.
#define SCIPrefHighRefreshRate  @"high_refresh_rate"

#define SCIPrefVerboseLogging   @"verbose_logging"

/// Downloads.
///
/// `SCIPrefAutoPhotos` defaults to **off**, and that is the change 0.13.0 is about: a
/// download used to go to Photos and nowhere else, which meant the tweak decided where
/// someone's video lived. Now it stays in the Download Centre and going to Photos is a
/// swipe, or this switch for anyone who wants the old ending back.
#define SCIPrefAutoPhotos       @"auto_save_photos"

/// The tab bar's own arrangement. Two arrays of `pivotIdentifier` strings rather than one
/// switch per tab: an order and a visibility are a single decision, and storing them apart
/// is how a tab ends up hidden and first at the same time. Both empty means untouched, which
/// is what a fresh install has and what "reset" writes back.
#define SCIPrefTabOrder         @"tab_bar_order"
#define SCIPrefTabHidden        @"tab_bar_hidden"
/// How many segment downloads run at once, per host. Zero means "not set", which reads as the
/// tested default rather than as none -- see SCIYTParts.
#define SCIPrefParallel         @"download_parallel"

/// A save button in the Shorts action bar, beside like and share.
///
/// On by default, unlike most additions: Shorts has no long press to spare, so without this
/// there is no way at all to save one, and a feature nobody can reach is not a choice.
#define SCIPrefShortsButton     @"shorts_download_button"

/// YouTube's own download button, answered by us instead of by YouTube.
///
/// **On, and it is what replaces the hold below.** The hold was over the player's own
/// picture, which is exactly where YouTube puts its hold-to-speed-up — so the two were
/// competing for one gesture and ours won often enough that speeding a video up became
/// a download. A button that already means "save this video" cannot be confused with
/// anything else, and it costs no gesture at all.
#define SCIPrefNativeDownload   @"native_download_button"

/// Holding the picture to save it.
///
/// **Off, and that is the point of 1.26.0.** It stays because somebody may have learned it
/// and because a build where YouTube renames the action row still has a way in — but a
/// gesture laid over the app's own gesture is a cost paid on every long press, and it was
/// being paid by everybody to serve a feature the button now serves better.
#define SCIPrefHoldToSave       @"hold_to_save"

/// Writing the cover into the sound file itself.
///
/// **Off, and that is a retreat.** It shipped on in 0.22.0 and rewrote every saved song to
/// tag it -- unverified -- and left a library that would not play. 0.23.0 stopped it
/// producing broken files, but the trade was already wrong: what it buys is a picture when
/// a song is sent to someone else, and what it risks is the song. Anything that replaces a
/// file the user cannot get back again has to be asked for.
#define SCIPrefEmbedArtwork     @"embed_artwork"

/// Removing a save from the Centre once it has reached Photos.
///
/// Off. Photos is where a video goes to be kept and the Centre is where it goes to be
/// played, and deciding for someone that they wanted only one of those is not this tweak's
/// call -- particularly when the removal cannot be undone.
#define SCIPrefTidyAfterPhotos  @"tidy_after_photos"

/// A notification when a save finishes while you are elsewhere.
///
/// On. Transfers now continue with the app closed, so the moment a download ends is a moment
/// nobody is watching -- and a result delivered to an empty room is not a result.
#define SCIPrefFinishNotice     @"finish_notice"

/// Which pair of buttons the lock screen gets.
///
/// Off means next and previous, which is the default because a queue you cannot move
/// through is not a queue. iOS shows one pair or the other and never both, so this is a
/// choice and not two switches.
#define SCIPrefLockScreenSkip   @"lock_screen_skip"

/// The layer over the video inside YouTube's own player.
///
/// Both default off. Every other switch here acts on a class this project has confirmed;
/// these two act on leads read from YTVideoOverlay (MIT), and a surface nobody has yet seen
/// attach on a device should be asked for rather than assumed.
/// Whether this tweak may change YouTube's own tab bar at all -- the Download Centre tab, the
/// History tab and the stored order.
///
/// **Off until a device says otherwise, and that is a retreat rather than a design.** These
/// appends are made from `-setRenderer:` on `YTPivotBarView`, which YouTube calls while it is
/// building the bar during launch, and the bar is built before the app draws anything. A device
/// reported YouTube sitting on its logo and then being killed; the switch for the whole tweak
/// opened it instantly; three real faults were found and fixed and it still would not start.
///
/// This is the largest thing left that runs at launch and mutates one of YouTube's own model
/// objects — and it is newly live: it reads the items array through `SCISafeValueForKey`, which
/// answered nil for every protobuf class until the fix of 2026-09-03. Code that had been dead
/// since it was written started running on the release before the app stopped launching.
///
/// The Download Centre is still reachable from this tweak's own settings; what is off is the tab.
#define SCIPrefPivotBar         @"pivot_bar_changes"

/// Save in the row with Like and Share -- YouTube's own action row, with one more renderer in it.
#define SCIPrefActionRowButton  @"action_row_save"

#define SCIPrefOverlayButton    @"overlay_save_button"
#define SCIPrefOverlayEndTime   @"overlay_end_time"


/// Quality.
///
/// The two caps are resolutions, not menu positions -- 1080 means 1080, and 0 means leave
/// it alone. A stored index would be a number whose meaning lives in whatever order the
/// picker happened to list things in, and reordering the list would silently change
/// everyone's setting.
#define SCIPrefClassicQuality   @"classic_quality_menu"
#define SCIPrefCapWiFi          @"quality_cap_wifi"
#define SCIPrefCapCellular      @"quality_cap_cellular"


/// How far a double tap jumps, in seconds. Zero means leave YouTube's own ten alone.
///
/// A number and not an index, for the reason the quality caps are: 30 means thirty seconds
/// whatever order the picker happens to list things in.
#define SCIPrefSeekSeconds      @"seek_seconds"

/// Rates past 2× in the speed menu. Off — the menu is YouTube's and lengthening it is a
/// change to a screen nobody asked us to touch.
#define SCIPrefExtraSpeeds      @"extra_speeds"

/// Parts of YouTube's own screen that can be answered away. All off: removing pieces of
/// somebody else's app is a choice, and choosing it for everyone is not this tweak's call.
#define SCIPrefHideAmbient      @"hide_ambient_glow"
#define SCIPrefHideEndscreen    @"hide_endscreen"
#define SCIPrefHideInfoCards    @"hide_info_cards"
#define SCIPrefHideNotifyButton @"hide_notify_button"
#define SCIPrefHideCreateButton @"hide_create_button"
#define SCIPrefHideCastButton   @"hide_cast_button"
#define SCIPrefHideSearchButton @"hide_search_button"
#define SCIPrefHideSharePromo   @"hide_share_promo"


/// Which way round the video goes when it fills the screen.
///
/// 0 off, 1 left, 2 right, 3 portrait — and the button and the swipe are separate keys
/// because they are separate habits. The button is deliberate; the swipe is often not.
#define SCIPrefFullscreenButton @"fullscreen_button_direction"
#define SCIPrefFullscreenSwipe  @"fullscreen_swipe_direction"

/// Screen dimming below what iOS allows, and the hours it applies.
///
/// The level is a percentage and the two times are minutes since midnight — numbers with
/// meanings of their own, so no picker's ordering can change what somebody chose. The end
/// being earlier than the start is not an error: that is a range across midnight, which is
/// what a night schedule usually is.
#define SCIPrefDimEnabled       @"fake_brightness"
#define SCIPrefDimLevel         @"fake_brightness_level"
#define SCIPrefNightSchedule    @"night_schedule"
#define SCIPrefNightStart       @"night_start_minute"
#define SCIPrefNightEnd         @"night_end_minute"


/// SponsorBlock. One key for the feature, one per category.
///
/// Per-category rather than a single switch, because these are not the same request of
/// the video: skipping a paid advertisement is not the same decision as skipping the
/// creator's own intro, and a user who wants one may well not want the other.
#define SCIPrefSponsorBlock     @"sponsorblock"
#define SCIPrefSBNotice         @"sponsorblock_notice"
#define SCIPrefSBMarkers        @"sponsorblock_markers"

#define SCIPrefSBSponsor        @"sb_sponsor"
#define SCIPrefSBSelfPromo      @"sb_selfpromo"
#define SCIPrefSBInteraction    @"sb_interaction"
#define SCIPrefSBIntro          @"sb_intro"
#define SCIPrefSBOutro          @"sb_outro"
#define SCIPrefSBPreview        @"sb_preview"
#define SCIPrefSBFiller         @"sb_filler"
#define SCIPrefSBMusicOffTopic  @"sb_music_offtopic"

/// Read on every hook call, so it has to be cheap.
///
/// NSUserDefaults caches in memory after the first read, and these hooks run on the
/// main thread during layout and playback where a lock would show. Instagram's side of
/// this repository memoises the same call behind a lock because it has 227 call sites;
/// this has a handful, and measuring before adding that machinery is the rule here.
static inline BOOL SCIPrefEnabled(NSString *key) {
    // Albrhi Panel's per-app switch, asked first. Every feature here reads its setting
    // through this one function, so turning the app off in the panel stands all of them
    // down at once -- the hooks stay installed and answer %orig, which is the only way to
    // stop that cannot leave the app half-patched.
    // Marked once: this is the first thing a preference read does, and a launch that never
    // reaches it is a launch that died before any feature asked anything.
    // Marked, and the mark is a single atomic read after the first time -- this function is
    // called from a hook that fires for every view in the app, so anything here that takes a
    // lock is a lock the main thread contends with itself for, during the launch it is meant to
    // be measuring.
    SCIYTLaunchMark(@"first preference read");

    if (!SCIPanelAllowsThisApp()) return NO;
    SCIYTLaunchMark(@"gate allowed");

    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

/// For the settings that are a number rather than a switch. Absent reads as 0, which is
/// what every one of them uses to mean "do nothing".
static inline NSInteger SCIPrefNumber(NSString *key) {
    return [[NSUserDefaults standardUserDefaults] integerForKey:key];
}
