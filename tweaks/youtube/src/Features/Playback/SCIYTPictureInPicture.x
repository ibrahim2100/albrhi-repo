#import "../../YouTubeHeaders.h"
#import "../../SCILog.h"
#import "../../Prefs.h"

///
/// Real, system Picture-in-Picture -- the same window iOS gives Safari a video for --
/// rather than anything this tweak draws itself.
///
/// The app already carries the whole thing: `AVPictureInPictureController` is linked, and
/// `MLVideo` answers `-isPlayableInPictureInPicture` and `-isPlayableInPictureInPictureByUser
/// Settings` right next to `-playableInBackground`, the same class and the same shape
/// SCIYTBackground.x already hooks. What gates it is the second one -- "by user settings" --
/// which is how the app tells its own PIP controller that this account's plan allows it.
/// Forcing it YES is the entire feature; the controller, the AVFoundation session and the
/// system window are all already there and already working, unlocked rather than built.
///
/// `-isPlayableInPictureInPicture` is left alone. It answers a different, narrower
/// question -- whether *this video* supports PIP at all, which can be genuinely NO for a
/// live stream or a restricted upload -- and forcing that one risks a PIP window opened on
/// a video that cannot actually play in it. Only the account-plan gate is forced.
///
%hook MLVideo

- (BOOL)isPlayableInPictureInPictureByUserSettings {
    if (!SCIPrefEnabled(SCIPrefNativePIP)) {
        return %orig;
    }
    return YES;
}

%end

///
/// **On YouTube 21.41.5 the question moved to another class, and the hook above answers nothing.**
///
/// Read with tools/objc-classes.py from 21.41.5's own binary (and found by running `tools/objc-diff.py
/// --check` on this tweak against it): `MLVideo` no longer declares `-isPlayableInPictureInPictureByUserSettings`.
/// `YTBackgroundabilityPolicyImpl` does (`B16@0:8`), beside `-isBackgroundableByUserSettings` and its
/// `playableInPiPByUserSettings` property -- the same "does this account's plan allow it" gate, now on
/// the policy object. On that build the hook above was a method added to a class nobody asks.
///
/// Both hooks stay: a build that still has the answer on `MLVideo` is served by the first, a build that has it
/// on the policy by this one. The class is named by PoomSmart's YouPiP (MIT), whose source reads this property
/// on `YTBackgroundabilityPolicy`; the selector and its encoding were confirmed here, not carried over.
///
%hook YTBackgroundabilityPolicyImpl

- (BOOL)isPlayableInPictureInPictureByUserSettings {
    if (!SCIPrefEnabled(SCIPrefNativePIP)) {
        return %orig;
    }
    return YES;
}

%end
