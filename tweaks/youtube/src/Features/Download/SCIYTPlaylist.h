//
//  SCIYTPlaylist.h
//  Albrhi for YouTube
//
//  A playlist's videos, from its link.
//
//  Measured before it was written (not assumed): YouTube's `/browse` with the web client answers
//  `VL<playlistId>` with the first 100 videos and a continuation token for the next hundred, 100 at
//  a time, down to the last. Every video is a `watchEndpoint` carrying its id, wherever the page
//  layout nests it, so the reading walks the answer for those rather than naming a path that moves.
//  The visionOS client the downloads use answers 20 with no way on, which is why this asks as the web.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIYTPlaylist : NSObject

/// The playlist id in a pasted link or id, or nil. Lists of the kinds that cannot be read
/// anonymously or never end (a Mix, `RD…`; Liked videos, `LL`; Watch later, `WL`) are refused with
/// `reason` saying which -- a message is better than a spinner that never finishes.
+ (nullable NSString *)playlistIDFromText:(NSString *)text reason:(NSString * _Nullable * _Nullable)reason;

/// One page of an answer: the video ids in order (each once), the token for the next page if
/// there is one, and the playlist's title and size text when the page carries them. Pure.
+ (NSArray<NSString *> *)videoIDsInBrowse:(NSDictionary *)json
                                    token:(NSString * _Nullable * _Nullable)token
                                    title:(NSString * _Nullable * _Nullable)title
                                    total:(NSString * _Nullable * _Nullable)total;

/// Loads up to `limit` videos. `completion` runs on the main queue: the list, the title, how many
/// the playlist says it holds (a display string), and a sentence when nothing could be read.
+ (void)loadPlaylistID:(NSString *)playlistID
                 limit:(NSUInteger)limit
            completion:(void (^)(NSArray<NSString *> *videoIDs, NSString * _Nullable title,
                                 NSString * _Nullable total, NSString * _Nullable failure))completion;

@end

NS_ASSUME_NONNULL_END
