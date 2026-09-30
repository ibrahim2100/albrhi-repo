//
//  SCIYTFragments.h
//  Albrhi for YouTube
//
//  Turns YouTube's DASH files -- a video-only .mp4 and an audio-only .m4a, both
//  *fragmented* -- into one ordinary .mp4, without carrying a media library.
//
//  **Why this does not hand the files to AVFoundation, which would have been one line.**
//  Measured on this project's own build machine, not assumed: AVFoundation reads both files
//  with every timestamp doubled -- a 19-second clip reports 37.9 seconds, a 3:33 song
//  reports 7:06 -- while the files themselves say 18.93 and 19.06 seconds in their `mvhd`,
//  their `mdhd` and their `sidx`, and AudioToolbox agrees with the files. An `AVMutableComposition`
//  built from them and exported passes the wrong length straight through, which is a video that
//  plays twice as long as it is, in silence for the second half.
//
//  Whether the phone's own iOS does the same was not something this machine could tell. So
//  nothing here depends on it: the boxes are read directly, each frame's size and timestamp is
//  taken from the file's own tables, and AVAssetWriter is handed the compressed frames with
//  those timestamps -- which is what SCIYTTransport already does for transport streams, for the
//  same reason. Apple still builds the MP4 and its index tables; what is ours is only the
//  reading, and the reading is the part the file spells out in full.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

@interface SCIYTFragments : NSObject

/// H.264 video and AAC audio, each in its own fragmented file, written as one .mp4.
///
/// Either side failing to parse is a sentence rather than a guess: the codec that is not
/// supported, the box that was not there. On success the inputs are left alone -- the caller
/// knows which are scratch files.
+ (void)mergeVideo:(NSURL *)video
             audio:(NSURL *)audio
        completion:(void (^)(NSURL *output, NSString *failure))completion;

/// AAC in a fragmented file, written as an ordinary .m4a.
+ (void)rewriteAudio:(NSURL *)audio
          completion:(void (^)(NSURL *output, NSString *failure))completion;

@end
