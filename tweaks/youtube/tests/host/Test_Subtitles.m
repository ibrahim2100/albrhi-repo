//
//  Test_Subtitles.m
//  Albrhi for YouTube — host tests
//
//  YouTube's WebVTT into cues and into the samples an .mp4 text track needs
//  (SCIYTSubtitles.m, compiled as shipped). The "rolling" fixture is a shortened copy of what
//  YouTube returns for an automatic caption track, measured: every line twice, with ten-millisecond
//  cues between them that only repeat.
//
#import <Foundation/Foundation.h>
#import "Features/Download/SCIYTSubtitles.h"
#import "AlbrhiTestKit.h"

static NSString *const kManual =
    @"WEBVTT\nKind: captions\nLanguage: en\n\n"
     "00:00:27.103 --> 00:00:29.678\nGood morning. How are you?\n\n"
     "00:00:29.702 --> 00:00:31.105\n(Audience) Good.\n\n"
     "NOTE a comment\n\n"
     "00:00:40.000 --> 00:00:42.500 align:start position:0%\nTom &amp; Jerry &lt;3\nsecond line\n\n";

static NSString *const kRolling =
    @"WEBVTT\nKind: captions\nLanguage: en\n\n"
     "00:00:00.080 --> 00:00:02.550 align:start position:0%\n \ni<00:00:00.320><c> recreated</c><00:00:01.120><c> every</c><00:00:01.439><c> single</c><00:00:01.839><c> set</c>\n\n"
     "00:00:02.550 --> 00:00:02.560 align:start position:0%\ni recreated every single set\n \n\n"
     "00:00:02.560 --> 00:00:04.390 align:start position:0%\ni recreated every single set\ngame<00:00:02.879><c> in</c><00:00:03.120><c> real</c><00:00:03.360><c> life</c>\n\n"
     "00:00:04.390 --> 00:00:04.400 align:start position:0%\ngame in real life\n \n\n";

void Test_Subtitles(void) {
    printf("subtitles\n");

    ALBRHI_TEST(manual_captions_become_cues_with_entities_decoded, {
        NSArray *cues = [SCIYTSubtitles cuesFromVTT:kManual];
        ALBRHI_ASSERT(cues.count == 3, @"three cues, the NOTE block ignored");
        ALBRHI_ASSERT([cues[0][@"text"] isEqualToString:@"Good morning. How are you?"], @"text kept");
        ALBRHI_ASSERT(fabs([cues[0][@"start"] doubleValue] - 27.103) < 1e-9, @"start parsed");
        ALBRHI_ASSERT(fabs([cues[0][@"end"] doubleValue] - 29.678) < 1e-9, @"end parsed");
        ALBRHI_ASSERT([cues[2][@"text"] isEqualToString:@"Tom & Jerry <3\nsecond line"], @"entities decoded, two lines kept");
    });

    ALBRHI_TEST(rolling_automatic_captions_are_not_read_three_times, {
        NSArray *cues = [SCIYTSubtitles cuesFromVTT:kRolling];
        ALBRHI_ASSERT(cues.count == 2, @"only the lines with word timings are the new words");
        ALBRHI_ASSERT([cues[0][@"text"] isEqualToString:@"i recreated every single set"], @"first line, tags gone");
        ALBRHI_ASSERT([cues[1][@"text"] isEqualToString:@"game in real life"], @"second line without the carried-over one");
    });

    ALBRHI_TEST(cues_never_overlap, {
        NSString *vtt = @"WEBVTT\n\n00:00:01.000 --> 00:00:09.000\nfirst\n\n00:00:05.000 --> 00:00:07.000\nsecond\n\n";
        NSArray *cues = [SCIYTSubtitles cuesFromVTT:vtt];
        ALBRHI_ASSERT(cues.count == 2, @"both kept");
        ALBRHI_ASSERT([cues[0][@"end"] doubleValue] <= [cues[1][@"start"] doubleValue], @"the first is cut where the second begins");
    });

    ALBRHI_TEST(identical_neighbours_are_one_cue, {
        NSString *vtt = @"WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nhello\n\n00:00:02.000 --> 00:00:03.000\nhello\n\n";
        NSArray *cues = [SCIYTSubtitles cuesFromVTT:vtt];
        ALBRHI_ASSERT(cues.count == 1 && fabs([cues[0][@"end"] doubleValue] - 3) < 1e-9, @"merged and extended");
    });

    ALBRHI_TEST(short_timestamps_and_junk_are_handled, {
        NSString *vtt = @"WEBVTT\n\n01:05.500 --> 01:07.000\nok\n\nnot a cue\n\n00:00:09.000 --> 00:00:08.000\nbackwards\n\n";
        NSArray *cues = [SCIYTSubtitles cuesFromVTT:vtt];
        ALBRHI_ASSERT(cues.count == 1 && fabs([cues[0][@"start"] doubleValue] - 65.5) < 1e-9, @"mm:ss.mmm read, a backwards cue dropped");
        ALBRHI_ASSERT([SCIYTSubtitles cuesFromVTT:@""].count == 0, @"empty");
        NSString *nothing = nil;
        ALBRHI_ASSERT([SCIYTSubtitles cuesFromVTT:nothing].count == 0, @"nil");
    });

    ALBRHI_TEST(schedule_fills_the_gaps_so_a_line_does_not_stay_on_screen, {
        NSArray *cues = [SCIYTSubtitles cuesFromVTT:kManual];
        NSArray *schedule = [SCIYTSubtitles scheduleForCues:cues];
        ALBRHI_ASSERT(schedule.count == 6, @"gap, cue, cue, gap, cue → leading gap + 3 cues + 2 gaps");
        ALBRHI_ASSERT(schedule[0][@"text"] == nil && fabs([schedule[0][@"duration"] doubleValue] - 27.103) < 1e-9, @"silence from zero to the first cue");
        double at = 0;
        for (NSDictionary *e in schedule) {
            ALBRHI_ASSERT(fabs([e[@"start"] doubleValue] - at) < 1e-6, @"contiguous: every sample starts where the last ended");
            at += [e[@"duration"] doubleValue];
        }
    });

    ALBRHI_TEST(payload_is_a_length_and_utf8, {
        NSData *p = [SCIYTSubtitles payloadForText:@"مرحبا"];
        const uint8_t *b = p.bytes;
        ALBRHI_ASSERT(p.length == 2 + 10 && b[0] == 0 && b[1] == 10, @"five Arabic letters are ten bytes");
        ALBRHI_ASSERT([SCIYTSubtitles payloadForText:nil].length == 2, @"a gap is a zero length");
    });

    ALBRHI_TEST(description_is_accepted_by_coremedia_and_samples_carry_their_times, {
        CMFormatDescriptionRef format = [SCIYTSubtitles newFormatDescription];
        ALBRHI_ASSERT(format != NULL, @"CoreMedia accepts the tx3g description");
        if (format) {
            ALBRHI_ASSERT(CMFormatDescriptionGetMediaType(format) == kCMMediaType_Subtitle, @"a subtitle track");
            CMSampleBufferRef s = [SCIYTSubtitles newSampleForEntry:@{@"start": @1.5, @"duration": @2.0, @"text": @"hi"} format:format];
            ALBRHI_ASSERT(s != NULL, @"a sample is built");
            if (s) {
                CMTime pts = CMSampleBufferGetPresentationTimeStamp(s), dur = CMSampleBufferGetDuration(s);
                ALBRHI_ASSERT(fabs(CMTimeGetSeconds(pts) - 1.5) < 1e-6 && fabs(CMTimeGetSeconds(dur) - 2.0) < 1e-6, @"time and duration");
                CFRelease(s);
            }
            CFRelease(format);
        }
    });
}
