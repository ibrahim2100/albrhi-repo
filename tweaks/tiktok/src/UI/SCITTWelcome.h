//
//  SCITTWelcome.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

///
/// The update screen: what this release changed, said lightly, once.
///
/// **It appears on the first launch after an update is installed, and then never again until an update that has something
/// to say.** The stored value is an *edition*, an integer raised by hand in SCITTWelcome.m, not the version string: a patch
/// release that only mends something keeps the edition and stays silent, because a screen that returns after every update
/// is a screen people learn to dismiss without reading, which costs the one time it mattered. A first install counts as an
/// update (nothing seen yet), so it gets the screen too.
///
@interface SCITTWelcome : NSObject

/// Shows it if this edition has not been seen, and records that it was **when it is actually drawn**. Safe to call on
/// every launch and from any thread. It waits for the app to be active with a key window and tries again for about half a
/// minute, because the first seconds of a launch are TikTok putting its own screens up; the old version recorded "seen"
/// before it knew whether anything had been drawn, so a launch with no window used the one showing up for nothing.
+ (void)showIfNeeded;

/// Shows it regardless, for the row in Settings that offers it again.
+ (void)show;

@end
