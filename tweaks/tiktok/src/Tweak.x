#import "Tweak.h"
#import "Prefs.h"
#import "SCILog.h"
#import "Features/Ads/SCITTAdBlock.h"
#import "Features/Bypass/SCITTBypass.h"
#import "Features/Privacy/SCITTPrivacy.h"
#import "Features/Download/SCITTButton.h"
#import "Features/Interface/SCITTProgressBar.h"
#import "Features/Download/SCITTCapture.h"
#import "Features/Download/SCITTWatermark.h"
#import "Features/Confirm/SCITTConfirm.h"
#import "Features/Download/SCITTPlaybackProbe.h"
#import "Features/Extras/SCITTExtras.h"
#import "Settings/SCITTGesture.h"

NSString *SCIVersionString = @"v0.20.3";  // AlbrhiTT

///
/// TESTED ON TikTok 46.4.0. Every class here was confirmed present in that build's own
/// MusicallyCore.framework binary before being hooked -- read directly, not carried
/// over from BHTikTok's own source, which this was read for architecture only. See
/// CLAUDE.md and this tweak's own CHANGELOG.md for what that reading found.
///

%ctor {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        SCIPrefHideAds: @YES,
        SCIPrefDownloadButton: @YES,

        // The progress bar and photo saving, both on.
        //
        // Unlike the two YouTube overlay switches, these act on classes confirmed in TikTok
        // 46.4.0's own binary rather than on names read from another tweak, so there is no
        // "ask before assuming" reason to default them off -- and a progress bar nobody can
        // find is a feature nobody has.
        SCIPrefProgressBar: @YES,
        SCIPrefPhotoDownload: @YES,
        SCIPrefPhotoAudio: @YES,
        // Off, and it is the one default here that is a decision rather than a taste: turning
        // it on sends the post id to a service outside TikTok.
        SCIPrefExternalHD: @NO,
        // Off because it crashed the app three times. No row in Settings either -- this one is a
        // flag for testing a fix on a device, not a choice to offer anybody.
        SCIPrefBaseSurface: @NO,
        // Off, both: a confirmation changes what a tap does, and nobody asked for a dialog in
        // front of TikTok's own like button until they turn one on.
        SCIPrefConfirmLike: @NO,
        SCIPrefConfirmFollow: @NO,
        SCIPrefBypass: @YES,
        SCIPrefPrivacyStory: @YES,
        SCIPrefPrivacyMessages: @YES,
        SCIPrefPrivacyProfile: @YES,
        SCIPrefVerboseLogging: @NO,
    }];

    NSLog(@"[AlbrhiTT] %@ loaded into %@", SCIVersionString,
          [[NSBundle mainBundle] bundleIdentifier]);

    // The gesture goes on even when every feature below it is off, so the status
    // screen that explains why nothing is happening is always reachable -- the same
    // rule the other tweaks in this repository follow.
    SCITTInstallGesture();

    if (!SCIPanelAllowsThisApp()) {
        SCILogV(@"switched off for this app: %@", SCIPanelGateReport());
        return;
    }

    SCITTInstallAdBlock();
    SCITTInstallBypass();
    SCITTInstallPrivacy();
    SCITTInstallCapture();
    SCITTInstallButton();
    SCITTInstallProgressBar();
    SCITTInstallConfirm();
    SCITTInstallWatermarkHooks();
    SCITTInstallPlaybackProbe();
    SCITTInstallExtras();
}
