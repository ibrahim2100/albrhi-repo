#import "../../Utils.h"
#import "../../InstagramHeaders.h"

///
/// Removes the voice and video call buttons from a DM thread's navigation bar.
///
/// The two buttons are told apart by their accessibility identifiers —
/// "audio-call" and "video-chat" — which Instagram sets itself, so each can be
/// hidden independently.
///
/// Hiding the view is not enough on its own: the tap handlers live on a separate
/// coordinator and still fire if the button is reached another way, so those are
/// blocked too.
///
/// Hook points identified from RyukGram (github.com/faroukbmiled/RyukGram, GPLv3),
/// a fellow SCInsta fork.
///

static BOOL SCIShouldHideCallButton(UIView *button) {
    NSString *identifier = button.accessibilityIdentifier;
    if (!identifier.length) return NO;

    if ([identifier isEqualToString:@"audio-call"]) {
        return [SCIUtils getBoolPref:@"hide_voice_call_button"];
    }
    if ([identifier isEqualToString:@"video-chat"]) {
        return [SCIUtils getBoolPref:@"hide_video_call_button"];
    }
    return NO;
}

%hook IGDirectCallButton

- (void)didMoveToWindow {
    %orig;

    if (SCIShouldHideCallButton(self)) {
        self.hidden = YES;
    }
}

%end

// The coordinator owns the taps. Blocking them means a button that is hidden but
// still somehow reachable — through an accessibility action, say — does nothing
// rather than placing a call.
%hook IGDirectThreadCallButtonsCoordinator

// 450.1.0 dropped the sender argument of both (`-_didTapAudioButton`, `-_didTapVideoButton`: `v16@0:8`).
- (void)_didTapAudioButton {
    if ([SCIUtils getBoolPref:@"hide_voice_call_button"]) return;
    %orig;
}

- (void)_didTapVideoButton {
    if ([SCIUtils getBoolPref:@"hide_video_call_button"]) return;
    %orig;
}

- (void)_didTapAudioButton:(id)sender {
    if ([SCIUtils getBoolPref:@"hide_voice_call_button"]) return;
    %orig;
}

- (void)_didTapVideoButton:(id)sender {
    if ([SCIUtils getBoolPref:@"hide_video_call_button"]) return;
    %orig;
}

%end
