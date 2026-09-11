#import "YouTubeHeaders.h"
#import "Tweak.h"
#import "UI/SCIYTWelcome.h"
#import "SCILog.h"
#import "Prefs.h"
#import "SCIYTLaunchGuard.h"
#import "Diagnostics/SCIYTDiagnostics.h"
#import "Features/Display/SCIYTDimmer.h"

NSString *SCIVersionString = @"v1.31.5";  // AlbrhiYT

///
/// Capture, so the diagnostics page has something true to report.
///
/// Two hooks rather than one, because they see different things and the difference
/// is the whole point:
///
///   the player response is what YouTube *offered* for this video
///   MLVideo's streaming data is what the player is *using*
///
/// If those ever disagree -- an offered quality that never becomes a stream in use --
/// the report shows both and the disagreement is visible instead of being averaged
/// into one misleading answer. Measuring each stage separately is the lesson the
/// Instagram quality picker cost three attempts to learn.
///

%hook YTPlayerOverlayWrapper

- (void)setPlayerResponse:(id)playerResponse {
    SCIYTLaunchMark(@"overlay wrapper: setPlayerResponse");

    %orig;
    [SCIYTDiagnostics recordPlayerResponse:playerResponse];
}

%end


%hook MLVideo

// All three initialisers this class declares, not just the widest one.
//
// Which of them the player actually uses is not knowable from the binary, and
// hooking one would leave the streams section blank whenever a different one was
// taken -- a blank that looks identical to "the hook did not attach" and would cost
// a round trip on a device to tell apart. Three small hooks are cheaper than that
// ambiguity.
- (id)initWithVideoDetails:(id)videoDetails
             streamingData:(id)streamingData
       clickTrackingParams:(id)clickTrackingParams
              threedLayout:(id)threedLayout
            playerCaptions:(id)playerCaptions
           hasOfflineState:(BOOL)hasOfflineState
      playableInBackground:(BOOL)playableInBackground {
    id video = %orig;
    [SCIYTDiagnostics recordVideo:video];
    return video;
}

- (id)initWithVideoDetails:(id)videoDetails
             streamingData:(id)streamingData
              threedLayout:(id)threedLayout
            playerCaptions:(id)playerCaptions {
    id video = %orig;
    [SCIYTDiagnostics recordVideo:video];
    return video;
}

- (id)initWithVideoDetails:(id)videoDetails
             streamingData:(id)streamingData
              threedLayout:(id)threedLayout {
    id video = %orig;
    [SCIYTDiagnostics recordVideo:video];
    return video;
}

%end


%ctor {
    // Defaults registered rather than assumed: reading a key that was never written
    // returns NO, which happens to be right for verbose logging and would be wrong
    // for the next setting added here. Registering makes the intended default
    // explicit at the one place it can be seen.
    // Ad hiding and background playback default to on: they are why someone installs
    // this, and shipping them off would mean a tweak that appears to do nothing until
    // its settings are found. The paid-promotion overlay defaults to *off* on purpose --
    // it is a disclosure, and removing one for everybody is not this tweak's call.
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        SCIPrefHideAds: @YES,
        SCIPrefBackgroundPlay: @YES,
        SCIPrefBlockUpdateNag: @YES,
        SCIPrefHidePaidPromo: @NO,

        // Both pure upside with nothing to weigh against: real PIP is a system window
        // this app already knows how to fill once permitted, and a display link asking
        // for less than the screen already gives for free is not a trade anyone wants.
        SCIPrefNativePIP: @YES,
        SCIPrefHighRefreshRate: @YES,

        SCIPrefVerboseLogging: @NO,

        // The button beside You is on: a Download Centre nobody can find is a Download
        // Centre that does not exist. Saving to Photos automatically is off, which is
        // the whole point of having somewhere else to put a download.
        SCIPrefShortsButton: @YES,
        SCIPrefAutoPhotos: @NO,

        // Saving from YouTube's own download button, on -- and holding the picture, off.
        // 1.26.0 moves one to the other rather than adding a second way in: the hold was
        // laid over the app's own hold-to-speed-up, so the two were competing for one
        // gesture and speeding a video up had started producing a download sheet.
        SCIPrefNativeDownload: @YES,
        SCIPrefHoldToSave: @NO,

        // SponsorBlock on, and its three least arguable categories with it: a paid
        // plug, the creator's own promotion, and a subscribe reminder are what people
        // mean by "skip the sponsor".
        //
        // Intros, endcards, recaps, tangents and non-music sections stay off. Each of
        // those is content somebody chose to make, and deciding for every user that it
        // is worthless is not this tweak's call — the switches are right there.
        SCIPrefSponsorBlock: @YES,
        SCIPrefSBNotice: @YES,

        // The coloured markers on the progress bar. On, but it is the one switch here
        // that turns off view work rather than a feature -- so if a future YouTube
        // rewrites the bar, there is something to turn off that leaves skipping alone.
        SCIPrefSBMarkers: @YES,
        SCIPrefSBSponsor: @YES,
        SCIPrefSBSelfPromo: @YES,
        SCIPrefSBInteraction: @YES,
        SCIPrefSBIntro: @NO,
        SCIPrefSBOutro: @NO,
        SCIPrefSBPreview: @NO,
        SCIPrefSBFiller: @NO,
        SCIPrefSBMusicOffTopic: @NO,

        // Zero means "whatever YouTube does", which for the double-tap jump is ten seconds.
        // Registered anyway rather than left absent, so the settings row has a value to show
        // on a fresh install instead of reading a key nobody wrote.
        SCIPrefSeekSeconds: @0,
        SCIPrefExtraSpeeds: @NO,

        // Every one of the hide switches. Each removes a part of YouTube that works, and a
        // tweak that decides for everybody which parts of an app are worth having is a tweak
        // nobody agreed to install.
        SCIPrefHideAmbient: @NO,
        SCIPrefHideEndscreen: @NO,
        SCIPrefHideInfoCards: @NO,
        SCIPrefHideNotifyButton: @NO,
        SCIPrefHideCreateButton: @NO,
        SCIPrefHideCastButton: @NO,
        SCIPrefHideSearchButton: @NO,
        SCIPrefHideSharePromo: @NO,

        // The two additions to YouTube's own player layer. Off, and for a different reason
        // from the hide switches above: those remove something that works, these act on two
        // classes read from YTVideoOverlay's source rather than confirmed on a device. A
        // surface nobody has yet seen attach should be asked for, not assumed.
        // On since 1.27.0. It was off because it was unconfirmed, and it stayed unconfirmed
        // because its only diagnostic was written into the SponsorBlock marker slot -- so no
        // report has ever mentioned it and nobody could confirm anything. It is now the way a
        // video is saved from the player, since YTSlimVideoDetailsActionView -- the row this
        // tweak moved the download onto in 1.26.0 -- is not drawn in 21.32.4 at all.
        // On again, because the work no longer happens during the launch: the bar is left as
        // YouTube built it until the app is active, and the same change is applied a moment
        // later. A fault there costs a tab and can be switched off from inside a running app,
        // which is the whole difference from what 1.29.2 shipped.
        SCIPrefPivotBar: @YES,

        // The row with Like and Share: **off, and the switch is kept rather than the code
        // deleted.** Three classes were hooked for that row and this build constructs none of
        // them, so what is left is a placement found by shape -- correct in principle, never
        // confirmed on a device, and it would be putting a button into a row somebody is using.
        // The request moved to the player's own top row, which is confirmed and on.
        SCIPrefActionRowButton: @NO,

        SCIPrefOverlayButton: @YES,
        SCIPrefOverlayEndTime: @NO,

        // Fullscreen direction: off, meaning YouTube keeps deciding from how the phone is
        // held. Forcing a side for everybody would be wrong for anybody who holds it the
        // other way, which is half of everybody.
        SCIPrefFullscreenButton: @0,
        SCIPrefFullscreenSwipe: @0,

        // Dimming off, at a level that is dark without being unusable, from ten at night
        // until seven. The times are registered even though the schedule is off, so the two
        // rows show real times on a fresh install rather than midnight to midnight -- which
        // would read as a range of no length and is the one value that means nothing.
        SCIPrefDimEnabled: @NO,
        SCIPrefDimLevel: @40,
        SCIPrefNightSchedule: @NO,
        SCIPrefNightStart: @1320,   // 22:00
        SCIPrefNightEnd: @420,      // 07:00
    }];

    // Before anything else, because what it guards against is this launch not finishing.
    SCIYTLaunchGuardStart();
    SCIYTLaunchMark(@"ctor entered");

    // Unconditional, and the only line here that is.
    //
    // 0.1.0 shipped with every way of telling whether the tweak had loaded sitting
    // behind a settings section that did not appear. One line at launch costs nothing
    // and means "is it even in there" is never a question again.
    NSLog(@"[AlbrhiYT] %@ loaded into %@", SCIVersionString,
          [[NSBundle mainBundle] bundleIdentifier]);

    // Watches the clock and the brightness settings from here on. Cheap when the feature is
    // off -- one observer and a timer with a minute of tolerance, and no window at all until
    // there is something to dim.
    [SCIYTDimmer start];

    // Said once, on the first launch after installing. Deliberately after everything else
    // in here: a greeting must never be the reason a hook did not get installed.
    [SCIYTWelcome showIfFirstRun];

    // Written once at launch and refreshed whenever a video is captured, so the
    // report is retrievable from the app's container even if no hook attached.
    SCIYTLaunchMark(@"ctor finished");
    [SCIYTDiagnostics writeReportToFile];
}
