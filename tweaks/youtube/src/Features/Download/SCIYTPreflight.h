//
//  SCIYTPreflight.h
//  Albrhi for YouTube
//
//  Looking before a batch starts. A playlist of eighty videos that begins downloading and fills the
//  phone at video forty is found out in the morning; one that says "about 14 GB, 9 GB free" before
//  the first byte is a decision. (The idea is OmniGet's `preflight.rs`, GPL-3.0; this is a rewrite.)
//
//  The sizes are an **estimate** from the video's length and the height asked for, calibrated on six
//  videos measured from this machine (H.264, the highest-bitrate copy of each height, megabytes per
//  second of video): medians 1080p 0.41, 720p 0.15, 480p 0.07, 360p 0.04, 240p 0.02, 144p 0.01 and
//  0.0162 for the AAC track, with 720p ranging 0.12 to 0.30 and 1080p 0.38 to 0.53. The table uses the
//  upper part of that range (1080p 0.50, 720p 0.20, ...) because a verdict that errs low fills the
//  phone; two lecture videos measured at 0.34 MB/s at 720p, higher than any of the six. A video
//  varies by a factor of two (a talking head and a slideshow differ), so the verdict leaves a margin
//  and the wording says "about".
//
//  Pure: numbers in, a verdict out, so a host test runs the same code.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SCIYTPreflightVerdict) {
    SCIYTPreflightFits = 0,     ///< comfortably inside the free space
    SCIYTPreflightTight,        ///< would use most of what is free: say so
    SCIYTPreflightTooBig,       ///< would not fit
};

@interface SCIYTPreflight : NSObject

/// Bytes one video of `seconds` is expected to take at `height` (0 = the tallest the ladder offers,
/// treated as 1080p) or as sound only.
+ (long long)estimatedBytesForSeconds:(double)seconds height:(NSInteger)height soundOnly:(BOOL)soundOnly;

/// The sum over a batch. `durations` is by video id; a video whose length is not known counts as
/// `unknownSeconds` (the median of the known ones when there are any, else ten minutes).
+ (long long)estimatedBytesForVideoIDs:(NSArray<NSString *> *)ids
                             durations:(NSDictionary<NSString *, NSNumber *> *)durations
                                height:(NSInteger)height
                             soundOnly:(BOOL)soundOnly;

/// A batch of `bytes` against `free` bytes of room. The estimate is held 30% high first (it can be
/// wrong either way) and half a gigabyte is kept back for the phone itself.
+ (SCIYTPreflightVerdict)verdictForBytes:(long long)bytes free:(long long)free;

/// What the volume holding the library has free for something the person asked for (the OS's own
/// "important usage" figure, which counts what it would clear for you), or -1 when unreadable.
+ (long long)freeBytes;

@end

NS_ASSUME_NONNULL_END
