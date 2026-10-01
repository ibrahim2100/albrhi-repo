#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>
#import "../../SCILog.h"
#import "../../SCIYTLaunchGuard.h"
#import "../../Prefs.h"

///
/// The player's own display link, asked to run at the screen's real ceiling.
///
/// YouTube sets a `CADisplayLink` for the player and caps it with `-setPreferredFramesPer
/// Second:`, and on a ProMotion phone that cap sits well under the panel's 120. This does
/// not touch what the video *decodes* at -- the source is whatever the stream is -- it only
/// stops the redraw loop that draws each decoded frame from being throttled tighter than
/// the screen it is drawn on, so motion reads as smooth as the hardware can make it rather
/// than as smooth as the app asked for.
///
/// Every `CADisplayLink` in the process is affected, not only the player's -- there is no
/// per-instance way to tell one apart from another at this hook point, and nothing else in
/// a video-playback app is likely to be driven by one, let alone by one asking for less
/// than the screen already gives for free.
///
%hook CADisplayLink

- (void)setPreferredFramesPerSecond:(NSInteger)framesPerSecond {
    SCIYTLaunchMark(@"display link: setPreferredFramesPerSecond");

    // Always on, with no switch (removed in 1.37.0) -- it was "pure upside" and a screen of
    // switches is not the place for one of those. Only the per-app gate is asked.
    if (!SCIPanelAllowsThisApp()) {
        %orig;
        return;
    }

    // The screen's own ceiling, not a hard-coded 120 -- correct on a 60Hz phone too,
    // where forcing 120 would ask for a rate the display link can never actually give.
    NSInteger ceiling = (NSInteger)[UIScreen mainScreen].maximumFramesPerSecond;
    %orig(MAX(framesPerSecond, ceiling));
}

%end
