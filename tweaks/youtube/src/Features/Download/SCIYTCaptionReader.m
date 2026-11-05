//
//  SCIYTCaptionReader.m
//  Albrhi for YouTube
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCIYTCaptionReader.h"
#import "SCIYTSubtitles.h"

@implementation SCIYTCaptionReader

+ (NSArray<NSDictionary *> *)captionTracksInAsset:(AVAsset *)asset {
    NSMutableArray *out = [NSMutableArray array];
    for (AVAssetTrack *track in [asset tracksWithMediaType:AVMediaTypeSubtitle]) {
        NSString *lang = track.extendedLanguageTag.length ? track.extendedLanguageTag
                       : track.languageCode.length ? track.languageCode : @"und";
        NSString *name = nil;
        if (![lang isEqualToString:@"und"]) name = [[NSLocale currentLocale] displayNameForKey:NSLocaleIdentifier value:lang];
        if (!name.length) name = lang;
        [out addObject:@{@"track": track, @"lang": lang, @"name": name}];
    }
    return out;
}

+ (NSArray<NSDictionary *> *)cuesInTrack:(AVAssetTrack *)track asset:(AVAsset *)asset {
    NSError *error = nil;
    AVAssetReader *reader = [AVAssetReader assetReaderWithAsset:asset error:&error];
    if (!reader) return nil;
    AVAssetReaderTrackOutput *output = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:track outputSettings:nil];
    if (![reader canAddOutput:output]) return nil;
    [reader addOutput:output];
    if (![reader startReading]) return nil;

    NSMutableArray *cues = [NSMutableArray array];
    CMSampleBufferRef sample;
    while ((sample = [output copyNextSampleBuffer])) {
        CMBlockBufferRef block = CMSampleBufferGetDataBuffer(sample);
        size_t length = block ? CMBlockBufferGetDataLength(block) : 0;
        if (length >= 2 && length < 65536) {
            NSMutableData *bytes = [NSMutableData dataWithLength:length];
            if (CMBlockBufferCopyDataBytes(block, 0, length, bytes.mutableBytes) == kCMBlockBufferNoErr) {
                NSString *text = [SCIYTSubtitles textFromPayload:bytes];
                CMTime pts = CMSampleBufferGetPresentationTimeStamp(sample);
                CMTime dur = CMSampleBufferGetDuration(sample);
                double start = CMTimeGetSeconds(pts), span = CMTimeGetSeconds(dur);
                if (text.length && isfinite(start) && isfinite(span) && span > 0) {
                    [cues addObject:@{@"start": @(start), @"end": @(start + span), @"text": text}];
                }
            }
        }
        CFRelease(sample);
    }
    if (reader.status == AVAssetReaderStatusFailed) return nil;
    [cues sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"start"] compare:b[@"start"]];
    }];
    return cues;
}

+ (NSDictionary *)cueAtTime:(double)time inCues:(NSArray<NSDictionary *> *)cues {
    if (!cues.count || !isfinite(time)) return nil;
    NSInteger low = 0, high = (NSInteger)cues.count - 1, found = -1;
    while (low <= high) {                         // the last cue that starts at or before `time`
        NSInteger mid = (low + high) / 2;
        if ([cues[mid][@"start"] doubleValue] <= time) { found = mid; low = mid + 1; }
        else high = mid - 1;
    }
    if (found < 0) return nil;
    NSDictionary *cue = cues[found];
    return time < [cue[@"end"] doubleValue] ? cue : nil;
}

@end
