//
//  SCITTToast.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

///
/// A banner at the top of the screen that never takes a touch.
///
/// It replaces the centred progress HUD, for three reasons the owner named in one sentence: it
/// sat in the middle of the video, it swallowed scrolling, and it looked like a system alert
/// rather than part of this tweak.
///
/// **Nothing here is modal.** The banner and every view inside it have `userInteractionEnabled`
/// off, so a download in progress cannot stop a scroll — a progress indicator is a *report*, and
/// a report that blocks the app is charging the user for information they did not ask to wait
/// for.
@interface SCITTToast : NSObject

/// Shows the banner, or updates the one already on screen. `progress` below zero means the work
/// has no measurable fraction yet and the bar animates instead of filling.
+ (void)showText:(NSString *)text symbol:(NSString *)symbol progress:(CGFloat)progress;

/// Replaces whatever is showing with a final state and takes it away after a moment.
+ (void)finishWithText:(NSString *)text ok:(BOOL)ok;

/// An information banner: an icon and a line, **no progress bar and no green check.** The banner a download ends with is a
/// check mark and a full green bar, so using it to say "this account has 124 videos" read as "something was saved"; a notice
/// that only informs must not look like a transfer finishing.
+ (void)noticeWithText:(NSString *)text symbol:(NSString *)symbol;

/// Takes it away now.
+ (void)dismiss;

@end

NS_ASSUME_NONNULL_END
