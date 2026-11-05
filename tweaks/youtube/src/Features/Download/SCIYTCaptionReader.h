//
//  SCIYTCaptionReader.h
//  Albrhi for YouTube
//
//  Reads the caption tracks this tweak wrote into a saved file (`tx3g` text samples) back out as
//  cues, so the player can draw them itself (size, timing offset) and export them as .srt.
//  No UIKit, so a host test reads a real muxed file with the same code the player ships.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIYTCaptionReader : NSObject

/// The caption tracks of a file, in file order, each `@{@"track": AVAssetTrack, @"lang": NSString
/// (a BCP-47 tag, or "und"), @"name": NSString (the language in the person's own language)}`.
/// Needs the asset's `tracks` loaded (the player loads them first).
+ (NSArray<NSDictionary *> *)captionTracksInAsset:(AVAsset *)asset;

/// Every cue of one track: `@{@"start", @"end", @"text"}` in seconds, sorted, empty samples (the
/// silence between cues) left out. Blocks while it reads -- call it off the main queue. nil when the
/// track cannot be read at all (not a text track this code understands).
+ (nullable NSArray<NSDictionary *> *)cuesInTrack:(AVAssetTrack *)track asset:(AVAsset *)asset;

/// The cue to show at `time` (seconds, the timing offset already added), or nil. `cues` is sorted by
/// start; a binary search so it is cheap to ask twice a second for a two-hour film.
+ (nullable NSDictionary *)cueAtTime:(double)time inCues:(NSArray<NSDictionary *> *)cues;

@end

NS_ASSUME_NONNULL_END
