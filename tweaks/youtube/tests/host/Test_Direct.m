//
//  Test_Direct.m
//  Albrhi for YouTube — host tests
//
//  The direct route's choice of what to offer: which formats are kept, which audio track wins,
//  and the quality ladder (one entry per height, the highest bitrate, tallest first).
//
//  The code under test is copied out of SCIYTDirect.m by marker (see run.sh), not retyped, so
//  what passes is what ships. What this cannot say is what YouTube serves today -- that is the
//  report's `direct:` lines, from a phone.
//
#import <Foundation/Foundation.h>
#import "SCIYTHLS.h"
#import "AlbrhiTestKit.h"

// SCIYTHLS.m is not compiled here; the value type is all the ladder needs.
@implementation SCIHLSVariant
- (NSString *)label { return nil; }
@end

@interface SCIYTDirect : NSObject
+ (void)sortFormats:(NSArray *)all video:(NSMutableArray<NSDictionary *> *)videos av1:(NSMutableArray<NSDictionary *> *)av1 audio:(NSDictionary **)audio;
+ (NSArray<SCIHLSVariant *> *)ladderForVideos:(NSMutableArray<NSDictionary *> *)videos audio:(NSDictionary *)audio videoID:(NSString *)videoID;
@end

@implementation SCIYTDirect
#include "direct_region.inc"
@end

static NSDictionary *Video(NSString *codec, NSInteger height, NSInteger bitrate, NSString *mime) {
    return @{@"url": [NSString stringWithFormat:@"https://example.invalid/v%ld_%ld", (long)height, (long)bitrate],
             @"mimeType": [NSString stringWithFormat:@"%@; codecs=\"%@\"", mime ?: @"video/mp4", codec],
             @"contentLength": @"1000000", @"height": @(height), @"width": @(height * 16 / 9), @"bitrate": @(bitrate)};
}

static NSDictionary *Audio(NSString *codec, NSInteger bitrate, NSDictionary *extra) {
    NSMutableDictionary *format = [@{@"url": @"https://example.invalid/a",
                                     @"mimeType": [NSString stringWithFormat:@"audio/mp4; codecs=\"%@\"", codec],
                                     @"contentLength": @"500000", @"bitrate": @(bitrate)} mutableCopy];
    [format addEntriesFromDictionary:extra ?: @{}];
    return format;
}

void Test_Direct(void) {
    printf("direct route\n");

    ALBRHI_TEST(sorts_formats_by_kind, {
        NSMutableArray *videos = [NSMutableArray array], *av1 = [NSMutableArray array];
        NSDictionary *audio = nil;
        NSArray *all = @[Video(@"avc1.640028", 1080, 4000000, nil),
                         Video(@"av01.0.12M.08", 2160, 9000000, nil),
                         Video(@"vp09.00.40.08", 1080, 3500000, @"video/webm"),   // WebM: cannot be written untouched
                         Audio(@"mp4a.40.2", 128000, nil)];
        [SCIYTDirect sortFormats:all video:videos av1:av1 audio:&audio];
        ALBRHI_ASSERT(videos.count == 1, @"one H.264 video");
        ALBRHI_ASSERT(av1.count == 1, @"one AV1 video, kept apart");
        ALBRHI_ASSERT(audio != nil, @"an AAC track");
    });

    ALBRHI_TEST(audio_prefers_highest_bitrate_aac_lc_default_non_drc, {
        NSMutableArray *videos = [NSMutableArray array], *av1 = [NSMutableArray array];
        NSDictionary *audio = nil;
        NSArray *all = @[Audio(@"mp4a.40.2", 48000, nil),
                         Audio(@"mp4a.40.2", 128000, nil),
                         Audio(@"mp4a.40.2", 256000, @{@"isDrc": @YES}),                                // compressed copy
                         Audio(@"mp4a.40.2", 192000, @{@"audioTrack": @{@"audioIsDefault": @NO}}),    // a dubbed language
                         Audio(@"mp4a.40.5", 300000, nil)];                                              // HE-AAC: skipped
        [SCIYTDirect sortFormats:all video:videos av1:av1 audio:&audio];
        ALBRHI_ASSERT([audio[@"bitrate"] integerValue] == 128000, @"the 128k default track wins");
    });

    ALBRHI_TEST(entries_without_a_url_or_length_are_skipped, {
        NSMutableArray *videos = [NSMutableArray array], *av1 = [NSMutableArray array];
        NSDictionary *audio = nil;
        NSMutableDictionary *noURL = [Video(@"avc1.640028", 720, 2000000, nil) mutableCopy];
        [noURL removeObjectForKey:@"url"];
        NSMutableDictionary *noLength = [Video(@"avc1.640028", 480, 1000000, nil) mutableCopy];
        noLength[@"contentLength"] = @"0";
        NSMutableDictionary *notHTTP = [Video(@"avc1.640028", 360, 500000, nil) mutableCopy];
        notHTTP[@"url"] = @"file:///etc/passwd";
        [SCIYTDirect sortFormats:@[noURL, noLength, notHTTP, @"not a dictionary"] video:videos av1:av1 audio:&audio];
        ALBRHI_ASSERT(videos.count == 0 && av1.count == 0 && audio == nil, @"nothing usable");
    });

    ALBRHI_TEST(ladder_one_entry_per_height_best_bitrate_tallest_first, {
        NSMutableArray *videos = [@[Video(@"avc1.4d401f", 360, 600000, nil),
                                    Video(@"avc1.640028", 1080, 4000000, nil),
                                    Video(@"avc1.64002a", 1080, 6500000, nil),    // the 60 fps copy
                                    Video(@"avc1.4d401e", 720, 2200000, nil)] mutableCopy];
        NSArray<SCIHLSVariant *> *ladder = [SCIYTDirect ladderForVideos:videos audio:Audio(@"mp4a.40.2", 128000, nil) videoID:@"abc"];
        ALBRHI_ASSERT(ladder.count == 3, @"three heights");
        ALBRHI_ASSERT(ladder[0].height == 1080 && ladder[1].height == 720 && ladder[2].height == 360, @"tallest first");
        ALBRHI_ASSERT(ladder[0].bandwidth == 6500000 + 128000, @"the higher bitrate at 1080 wins, audio added");
        ALBRHI_ASSERT([ladder[0].directVideoURL hasSuffix:@"v1080_6500000"], @"and it is that file");
    });

    ALBRHI_TEST(ladder_fills_everything_the_downloader_reads, {
        NSMutableArray *videos = [@[Video(@"avc1.640028", 1080, 4000000, nil)] mutableCopy];
        SCIHLSVariant *v = [SCIYTDirect ladderForVideos:videos audio:Audio(@"mp4a.40.2", 128000, nil) videoID:@"dQw4w9WgXcQ"].firstObject;
        ALBRHI_ASSERT([v.codecs isEqualToString:@"avc1.640028,mp4a.40.2"], @"video,audio codecs");
        ALBRHI_ASSERT(v.width == 1920, @"width");
        ALBRHI_ASSERT(v.directVideoBytes == 1000000 && v.directAudioBytes == 500000, @"both lengths, for the size check before writing");
        ALBRHI_ASSERT([v.directAudioURL isEqualToString:@"https://example.invalid/a"], @"audio url");
        ALBRHI_ASSERT([v.directVideoID isEqualToString:@"dQw4w9WgXcQ"], @"video id");
    });

    ALBRHI_TEST(ladder_mixes_h264_and_av1_by_height, {
        // What the 4K switch does before calling: AV1 above 1080 is appended, then one rule orders both.
        NSMutableArray *videos = [@[Video(@"avc1.640028", 1080, 4000000, nil),
                                    Video(@"av01.0.12M.08", 2160, 9000000, nil),
                                    Video(@"av01.0.08M.08", 1440, 5000000, nil)] mutableCopy];
        NSArray<SCIHLSVariant *> *ladder = [SCIYTDirect ladderForVideos:videos audio:Audio(@"mp4a.40.2", 128000, nil) videoID:@"x"];
        ALBRHI_ASSERT(ladder.count == 3 && ladder[0].height == 2160 && ladder[1].height == 1440 && ladder[2].height == 1080, @"4K, 1440p, 1080p");
        ALBRHI_ASSERT([ladder[0].codecs hasPrefix:@"av01"], @"the top rung is AV1");
    });

    ALBRHI_TEST(ladder_of_nothing_is_empty, {
        NSArray *ladder = [SCIYTDirect ladderForVideos:[NSMutableArray array] audio:Audio(@"mp4a.40.2", 1, nil) videoID:@"x"];
        ALBRHI_ASSERT(ladder.count == 0, @"empty, never nil");
    });
}
