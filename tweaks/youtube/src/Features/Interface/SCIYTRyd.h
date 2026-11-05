//
//  SCIYTRyd.h
//  Albrhi for YouTube
//
//  Likes and dislikes of the video that is playing, from Return YouTube Dislike (returnyoutubedislikeapi.com,
//  `GET /votes?videoId=`). YouTube stopped showing the dislike count in 2021; this service keeps an estimate
//  from its own extension's users' votes plus the figures YouTube still gave when it did.
//
//  **A third party is told which video is on the screen**, which is a cost paid only by whoever turned the
//  switch on, so it is off by default and the row says so (CLAUDE.md §2). Nothing is sent otherwise, and
//  nothing but the video id is sent at all: no account, no cookie, no visitor id.
//
//  The parsing and formatting are pure and host-tested (tests/host/Test_Robust.m).
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Posted on the main queue when the figures for the video on screen arrive (or are cleared on a new video).
extern NSNotificationName const SCIYTRydDidChangeNotification;

@interface SCIYTRyd : NSObject

/// A video became the one playing. Starts the lookup when the switch is on; always forgets the last video's figures.
+ (void)videoActivated:(nullable NSString *)videoID;

/// The figures for the video playing now, or nil: `@{@"likes", @"dislikes", @"rating", @"views"}` (numbers).
+ (nullable NSDictionary<NSString *, NSNumber *> *)current;

/// `1.2M`, `34K`, `987`: the compact form of a count, one decimal under ten of a unit and none above.
+ (NSString *)compact:(double)count;

/// Reads a `/votes` answer into the dictionary above, or nil when it is not one (missing or negative counts, a removed video).
+ (nullable NSDictionary<NSString *, NSNumber *> *)parseVotes:(nullable id)json;

/// The text of the top-row button: "👎 34K", or a dash while waiting.
+ (NSString *)buttonTitle;

/// A readable summary for the alert the button opens.
+ (NSString *)summary;

@end

NS_ASSUME_NONNULL_END
