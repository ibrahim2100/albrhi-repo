//
//  SCIYTWatch.h
//  Albrhi for YouTube
//
//  Watching a video in Albrhi's own player, for the day YouTube's refuses.
//
//  **Why this exists.** On 21.33.6 (the last build iOS 16 can run) a regular video plays for a
//  second or two and then stops with "Something went wrong" -- on the stock app, with no tweak
//  installed, signed in or out, while Shorts and this tweak's own downloads work every time.
//  That pattern is what a server asking for proof of origin looks like: the first seconds are
//  served, the next request is refused, and the downloader is untouched because it asks as a
//  different client. Nothing here can mend the app's own player and nothing here tries to
//  forge the proof it wants (that is the line this project keeps -- see `app_attest_*` in the
//  X tweak). What *is* in reach is the thing that still works: the same download, played.
//
//  It fetches the video the way a save does (so it is a row in the Download Centre afterwards,
//  and says so), and opens the Centre's player the moment it is whole. A wait of a few seconds
//  to a minute, depending on length and line -- not streaming, and said to be.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>
#import "../SCIYTHLS.h"

NS_ASSUME_NONNULL_BEGIN

@interface SCIYTWatch : NSObject

/// The quality a person watching would want: the tallest that is not AV1 (an iPhone on iOS 16
/// cannot decode it) and not above 720p (the wait is the whole file). Nil for an empty list.
+ (nullable SCIHLSVariant *)bestVariantToWatch:(NSArray<SCIHLSVariant *> *)variants;

/// Fetches `variant` and plays it when it is whole. A copy already in the Centre plays at once.
+ (void)watchVariant:(SCIHLSVariant *)variant
               title:(nullable NSString *)title
             videoID:(nullable NSString *)videoID
                from:(UIViewController *)presenter;

/// Asks which qualities exist for this video id, picks one, and does the above.
+ (void)watchVideoID:(NSString *)videoID
               title:(nullable NSString *)title
                from:(UIViewController *)presenter;

/// After YouTube's player has failed: asks, once per video a minute, whether to watch it here.
/// Honours the switch and the launch guard. Safe to call from the error path -- it presents on
/// the next turn of the run loop and never throws.
+ (void)offerAfterFailureFrom:(UIViewController *)presenter videoID:(nullable NSString *)videoID;

/// What happened, for the report: offers made, accepted, started, finished, failed.
+ (NSString *)report;

@end

NS_ASSUME_NONNULL_END
