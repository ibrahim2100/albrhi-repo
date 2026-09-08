#import "Tweak.h"
#import "Prefs.h"
#import "SCILog.h"
#import "Features/Switches/SCITWSwitchHooks.h"
#import "Features/Switches/SCITWFeatures.h"
#import "Settings/SCITWGesture.h"
#import "Features/Media/SCITWMediaHooks.h"
#import "Features/Media/SCITWImmersiveButton.h"
#import "Features/Ads/SCITWPromotedFilter.h"
#import "Features/Confirm/SCITWRepostConfirm.h"
#import "Features/Media/SCITWAvatarSave.h"
#import "Features/Playback/SCITWPictureInPicture.h"
#import "Features/Tabs/SCITWTabEntries.h"
#import "Features/Spaces/SCITWSpacesBar.h"
#import "Features/Links/SCITWLinks.h"
#import "Features/Timeline/SCITWTimelineFilter.h"
#import "Features/Actions/SCITWActionRow.h"
#import "Features/Extras/SCITWExtras.h"
#import "Features/Profile/SCITWProfileCopy.h"
#import "Features/Lock/SCITWAppLock.h"

NSString *SCIVersionString = @"v0.18.6";  // AlbrhiTW

%ctor {
    // Defaults registered rather than assumed: reading a key that was never written
    // returns NO, which would leave the switch layer off on a fresh install -- and with
    // it off this release does nothing at all, so the tweak would appear not to have
    // installed. Registering makes the intended default explicit in one place.
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        SCIPrefSwitchLayer: @YES,
        SCIPrefInlineButton: @YES,
        SCIPrefHidePromoted: @NO,
        SCIPrefConfirmRepost: @NO,
        SCIPrefSaveAvatar: @YES,
        SCIPrefVerboseLogging: @NO,
    }];

    // Unconditional, and the only line here that is.
    //
    // Both other tweaks in this repository shipped a first release where every way of
    // telling whether the dylib had loaded was behind something that had not loaded. One
    // line at launch costs nothing and means "is it even in there" is never a question.
    NSLog(@"[AlbrhiTW] %@ loaded into %@", SCIVersionString,
          [[NSBundle mainBundle] bundleIdentifier]);

    // The panel switch, before anything else. Settings › Albrhi can turn this tweak off
    // for X without uninstalling it, and off has to mean X behaves exactly as it would
    // with nothing installed -- so nothing below this line runs.
    if (!SCIPanelAllowsThisApp()) {
        SCILogV(@"switched off for this app: %@", SCIPanelGateReport());
        return;
    }

    // The gesture goes on even when the switch layer is off, and that is deliberate: it is
    // the only door to the screen that explains why nothing is happening. A tweak whose
    // diagnostics are behind the feature being diagnosed has already been shipped twice
    // here and cost a device round trip each time.
    SCITWInstallGesture();

    // Independent of the switch layer on purpose. Saving a video and answering X's own
    // feature switches are two different things, and someone who turned the switch layer
    // off to rule it out of a problem should not lose their downloads with it.
    SCITWInstallMediaHooks();

    // The button inside the video, in the immersive player's own control stack -- the one
    // place reading TWIGalaxy's binary proved it puts an in-video button, and an arranged
    // subview rather than a floating one, which is why this appears where the others did
    // not.
    //
    // The only surface installed now. Three others existed alongside it at one point -- a
    // corner overlay on the media view, the same overlay triggered from the tweet's own
    // status classes, and a button on X's action row after its own share button -- kept as
    // redundant fallbacks in case X moved the immersive classes again. All four running at
    // once meant a video could show the save button four times over, which read as broken
    // rather than thorough. The immersive surface is the one that was actually asked for --
    // a button that stays inside the video while swiping -- so it is the one that stays.
    SCITWInstallImmersiveButton();

    // Unrelated to the switch layer and unrelated to "Hide ads": neither touches a real
    // Promoted Tweet, which is an ordinary status the server marks rather than a client
    // switch. Its own hook, on the same three classes the save button already found, and
    // off by default until a device confirms it.
    SCITWInstallPromotedFilter();

    // A confirmation before a repost goes out -- off by default, since X's own button
    // already costs one tap and a second is a real cost to weigh, not a free safety net.
    SCITWInstallRepostConfirm();

    // Offers to save a profile photo from the same tap that already opens it full screen.
    SCITWInstallAvatarSave();

    // Not a feature -- a recorder. What was asked for could not honestly ship as a working
    // toggle: the real API takes an enum this class dump names no values for, and forcing
    // a guessed number into it risks disabling playback rather than enabling
    // picture-in-picture. This counts the values X sets on its own instead, so a real
    // toggle can be built from what a report says rather than from a guess.
    SCITWInstallPictureInPictureRecorder();

    // Two feature switches that were reported as doing nothing, enforced where X actually
    // decides instead. This is installed unconditionally, and each hook asks its own
    // feature before answering, so the tab bar is untouched until a switch is turned on --
    // and it is deliberately outside the switch-layer gate below, because it is not a
    // switch answer. It is the decision the switch was supposed to reach.
    SCITWInstallTabEntries();

    // The Spaces bar above the timeline, which is what "Hide Spaces" is actually about.
    // Two releases moved tabs instead, correctly and to no effect on this surface.
    SCITWInstallSpacesBar();

    // Everything below is installed unconditionally and gated inside, one preference each.
    // None of them answers a feature switch, so none belongs behind the switch layer -- and
    // a person who turned that layer off to rule it out of a problem should not lose the
    // link cleaner with it.
    SCITWInstallLinks();
    SCITWInstallTimelineFilter();
    SCITWInstallActionRow();
    SCITWInstallExtras();
    SCITWInstallProfileCopy();

    // Last, and after everything else has attached: it puts a cover over the app, and a
    // failure here should not be able to stop a hook that was going to install after it.
    SCITWInstallAppLock();

    if ([[NSUserDefaults standardUserDefaults] boolForKey:SCIPrefSwitchLayer]) {
        // Before the hooks, not after. X asks its first questions while the app is still
        // launching, and a feature applied a moment later would miss them -- which is how
        // a setting comes to work everywhere except on the screen you opened the app to.
        [SCITWFeatures apply];
        SCITWInstallSwitchHooks();
    } else {
        SCILogV(@"switch layer turned off in settings");
    }
}
