//
//  SCIYTAV1Convert.h
//  Albrhi for YouTube
//
//  AV1 in, HEVC out -- for a phone that cannot play AV1.
//
//  **Optional, and slow on purpose-built honesty rather than apology.** YouTube serves 1440p and
//  4K only as AV1, and an iPhone older than the 15 Pro has no AV1 decoder. The route that exists
//  is to decode in software and encode again with the hardware HEVC encoder, which is what
//  Instagram's reels transcoder already does on this phone with dav1d. Doing it to a three
//  minute 4K video costs minutes, not seconds, so it is a switch somebody turns on knowing that
//  and not something a download does on its own.
//
//  The decoder is dav1d (BSD-2, vendored, built by this repository's CI). The pictures go to
//  AVAssetWriter, which runs the HEVC encoder and owns the back-pressure -- the loop decodes only
//  when the writer asks for a frame, so memory stays at a handful of frames however long the clip
//  is (Instagram's version holds every compressed sample and that is fine for a reel, not for
//  half a gigabyte). The sound is AAC already and is copied across untouched.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

@interface SCIYTAV1Convert : NSObject

/// Converts the two fragmented files YouTube served (AV1 picture, AAC sound) into one HEVC .mp4.
/// `progress` is the fraction of frames written, on an arbitrary queue; `completion` is on the
/// main queue with the file, or a sentence and no file. The inputs are left alone.
+ (void)convertVideo:(NSURL *)video
               audio:(NSURL *)audio
            progress:(void (^)(double fraction))progress
          completion:(void (^)(NSURL *output, NSString *failure))completion;

@end
