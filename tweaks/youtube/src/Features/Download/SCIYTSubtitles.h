//
//  SCIYTSubtitles.h
//  Albrhi for YouTube
//
//  Captions as YouTube serves them (WebVTT) turned into what an .mp4 can carry: a list of
//  non-overlapping cues, a schedule of samples with the gaps filled, and the text-track
//  description (`tx3g`) the writer needs. Pure and free of UIKit so a host test runs the same
//  code the tweak ships (tests/host/Test_Subtitles.m).
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIYTSubtitles : NSObject

/// Cues out of a WebVTT document: `@{@"start": NSNumber seconds, @"end": ..., @"text": NSString}`,
/// sorted, never overlapping (an earlier cue is cut where the next begins), none empty.
///
/// **YouTube's automatic captions are "rolling":** every cue repeats the previous line and adds
/// the new one with word timings (`<00:00:01.120><c> every</c>`), and between them sit cues of ten
/// milliseconds that only repeat. Read naively that is every sentence three times. When any cue
/// carries word timings, only the lines that carry them are kept -- they are the new words.
+ (NSArray<NSDictionary *> *)cuesFromVTT:(NSString *)vtt;

/// What the writer is given, in order and without holes: each entry `@{@"start", @"duration",
/// @"text"}` where `text` is nil for the silence between two cues. An MP4 text track has no
/// notion of "nothing until 10 s": each sample lasts until the next begins, so a gap left out
/// would keep the previous line on screen until the next one.
+ (NSArray<NSDictionary *> *)scheduleForCues:(NSArray<NSDictionary *> *)cues;

/// One text sample's payload: a big-endian 16-bit length and the UTF-8 text (empty for a gap).
+ (NSData *)payloadForText:(nullable NSString *)text;

/// The `tx3g` sample description, in the form CoreMedia reads.
+ (NSData *)descriptionData;

/// A format description for a subtitle track, or NULL (caller releases).
+ (nullable CMFormatDescriptionRef)newFormatDescription CF_RETURNS_RETAINED;

/// One sample buffer for a schedule entry (caller releases), or NULL.
+ (nullable CMSampleBufferRef)newSampleForEntry:(NSDictionary *)entry
                                         format:(CMFormatDescriptionRef)format CF_RETURNS_RETAINED;

@end

NS_ASSUME_NONNULL_END
