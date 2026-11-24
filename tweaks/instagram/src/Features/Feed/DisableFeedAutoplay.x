#import "../../Utils.h"

// Demangled name: IGFeedPlayback.IGFeedPlaybackStrategy
%hook _TtC14IGFeedPlayback22IGFeedPlaybackStrategy
- (id)initWithShouldDisableAutoplay:(_Bool)autoplay {
    if ([SCIUtils getBoolPref:@"disable_feed_autoplay"]) return %orig(true);

    return %orig(autoplay);
}

// 450.1.0 has three initialisers that each carry the flag first (the longer ones were added after 410); the shortest above is gone.
- (id)initWithShouldDisableAutoplay:(_Bool)autoplay shouldClearStaleReservation:(_Bool)stale {
    if ([SCIUtils getBoolPref:@"disable_feed_autoplay"]) return %orig(true, stale);

    return %orig(autoplay, stale);
}

- (id)initWithShouldDisableAutoplay:(_Bool)autoplay shouldClearStaleReservation:(_Bool)stale shouldBypassDisabledAutoplayForVoiceover:(_Bool)voiceover {
    if ([SCIUtils getBoolPref:@"disable_feed_autoplay"]) return %orig(true, stale, voiceover);

    return %orig(autoplay, stale, voiceover);
}

- (id)initWithShouldDisableAutoplay:(_Bool)autoplay shouldClearStaleReservation:(_Bool)stale shouldBypassDisabledAutoplayForVoiceover:(_Bool)voiceover shouldOverrideDefaultThresholds:(_Bool)thresholds mobileConfig:(id)config {
    if ([SCIUtils getBoolPref:@"disable_feed_autoplay"]) return %orig(true, stale, voiceover, thresholds, config);

    return %orig(autoplay, stale, voiceover, thresholds, config);
}
%end