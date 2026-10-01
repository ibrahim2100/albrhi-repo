#import "../../YouTubeHeaders.h"
#import "../../SCILog.h"
#import "../../Prefs.h"
#import "../Download/Center/SCIYTHostPlayer.h"

///
/// Keep playing with the screen off.
///
/// The permission is a server decision, not a client one: the player response carries a
/// playability status, and that status says whether this video may continue in the
/// background. Everything downstream -- the audio session, the now-playing controls,
/// the lock screen -- follows from that one answer.
///
/// So this is two hooks on two model classes, and nothing else. No audio session to
/// configure, no notification to observe, no view to find. The reference tweak that
/// does only this and ad hiding is 68 KB in total, and this is why.
///
/// YTIPlayabilityStatus answers for the response; MLVideo answers for the video the
/// media layer is actually playing. Both are asked, at different moments, and forcing
/// one while leaving the other means playback that stops depending on which path the
/// app happened to take.
///

%hook YTIPlayabilityStatus

- (BOOL)isPlayableInBackground {
    if (!SCIPrefEnabled(SCIPrefBackgroundPlay)) {
        return %orig;
    }
    return YES;
}

%end


///
/// Scoped to the video being watched, and this is the one of the three that could be.
///
/// The lock screen showed a different video from the one playing. Nothing in this tweak
/// writes a now-playing entry for an ordinary YouTube video -- the only code that touches
/// MPNowPlayingInfoCenter is the saved-downloads player -- so the tweak was not writing the
/// wrong entry. What it could do is change *which video the app itself considers the one
/// playing*, and this file is where it does it: the comment at the top of this file says
/// outright that the audio session, the now-playing controls and the lock screen all follow
/// from this one answer.
///
/// The app builds an MLVideo for videos it is only preloading -- Tweak.x hooks three of its
/// initialisers precisely because so many are made -- and answering YES for every instance
/// tells the app a video nobody is watching is fit to carry on in the background. So the
/// answer is now given for the one being watched and left to the app for the rest.
///
/// Two things this deliberately does not do:
///
///   - It does not answer NO. Falling back to %orig means an unmatched video gets YouTube's
///     own answer, which is the behaviour without this tweak at all; inventing a NO for a
///     video that really is background-playable would be a new bug wearing a fix's clothes.
///   - It does not scope on a missing id. No active id yet is the ordinary state for the
///     first video of a session, asked before -play has ever fired, and refusing it there
///     would break the feature outright for exactly the case it is most wanted in.
///
/// **The other two hooks in this file are not scoped, because they cannot be.** Neither
/// YTIPlayabilityStatus nor YTPlaybackData carries a video id to compare, and inventing a
/// way to attribute one to a video is guesswork of exactly the kind this project's first
/// ground rule forbids. If the lock screen still disagrees with the sound after this, those
/// two are where to look next, and they will need a different handle than an id.
///
%hook MLVideo

- (BOOL)playableInBackground {
    if (!SCIPrefEnabled(SCIPrefBackgroundPlay)) {
        return %orig;
    }

    NSString *active = [SCIYTHostPlayer activeVideoID];

    // Guarded rather than read straight off: -ID is declared on this class in our own
    // headers, but so was every selector that has gone missing between two YouTube builds.
    NSString *mine = [self respondsToSelector:@selector(ID)] ? self.ID : nil;

    if (active.length && mine.length && ![active isEqualToString:mine]) {
        SCILogV(@"background: %@ is not the video playing (%@) — leaving it to YouTube",
                mine, active);
        return %orig;
    }

    return YES;
}

%end


%hook YTPlaybackData

- (BOOL)isPlayableInBackground {
    if (!SCIPrefEnabled(SCIPrefBackgroundPlay)) {
        return %orig;
    }
    return YES;
}

%end


///
/// The "please update" dialog, and the paid-promotion overlay.
///
/// Kept in this file rather than given one of their own: both are one selector each,
/// both are model-level answers, and a file per line of code makes a tree nobody reads.
///

%hook YTGlobalConfig

- (BOOL)shouldBlockUpgradeDialog {
    // Always on, with no switch (removed in 1.37.0): an update replaces the app and removes this
    // tweak, so there was never a reason to want the prompt. Only the per-app gate is asked, so
    // switching Albrhi off for YouTube in the panel still leaves YouTube exactly as it was.
    if (!SCIPanelAllowsThisApp()) {
        return %orig;
    }

    // Note the polarity: this asks whether to *block* the dialog, so YES is what
    // silences it. Returning NO here would have been the confident, wrong fix.
    return YES;
}

%end


%hook YTIPlayerResponse

- (id)paidContentOverlayElementRendererOptions {
    if (!SCIPrefEnabled(SCIPrefHidePaidPromo)) {
        return %orig;
    }

    // The "includes paid promotion" banner. Hidden only on request and off by default:
    // it is a disclosure, and quietly removing one for everybody is not this tweak's
    // decision to make.
    return nil;
}

%end
