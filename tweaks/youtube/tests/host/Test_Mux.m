//
//  Test_Mux.m
//  Albrhi for YouTube — host tests
//
//  SCIYTFragments writing one .mp4 out of YouTube-shaped files: a fragmented H.264 picture, a
//  fragmented AAC sound, further sound in other languages and caption tracks. The sources are made
//  here with AVAssetWriter's segment output (fMP4, `moof` + `mdat`, the layout YouTube serves), the
//  merge is the shipped code, and the result is read back by AVFoundation -- the only judge of
//  whether a player will offer the choices. (It was also run once on a real 25-minute video with
//  three languages and two caption tracks: 146 MB, 2.4 s, length agreeing to a tenth of a second.)
//
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "Features/Download/SCIYTFragments.h"
#import "Features/Download/SCIYTSubtitles.h"
#import "AlbrhiTestKit.h"

@interface SCIMuxCollector : NSObject <AVAssetWriterDelegate>
@property (nonatomic, strong) NSMutableData *data;
@end
@implementation SCIMuxCollector
- (void)assetWriter:(AVAssetWriter *)writer didOutputSegmentData:(NSData *)segmentData segmentType:(AVAssetSegmentType)type segmentReport:(AVAssetSegmentReport *)report {
    [self.data appendData:segmentData];
}
@end

static CVPixelBufferRef SCIMuxFrame(int w, int h, int index) {
    CVPixelBufferRef pb = NULL;
    CVPixelBufferCreate(NULL, w, h, kCVPixelFormatType_32BGRA, NULL, &pb);
    CVPixelBufferLockBaseAddress(pb, 0);
    memset(CVPixelBufferGetBaseAddress(pb), (index * 7) & 0xFF, CVPixelBufferGetBytesPerRow(pb) * h);
    CVPixelBufferUnlockBaseAddress(pb, 0);
    return pb;
}

static CMSampleBufferRef SCIMuxTone(double freq, double start, int n) {
    int16_t *pcm = malloc(n * 2);
    for (int i = 0; i < n; i++) pcm[i] = (int16_t)(sin(2 * M_PI * freq * (start + i / 44100.0)) * 6000);
    CMBlockBufferRef block = NULL;
    CMBlockBufferCreateWithMemoryBlock(NULL, pcm, n * 2, kCFAllocatorMalloc, NULL, 0, n * 2, 0, &block);
    AudioStreamBasicDescription d = {44100, kAudioFormatLinearPCM, kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked, 2, 1, 2, 1, 16, 0};
    CMAudioFormatDescriptionRef format; CMAudioFormatDescriptionCreate(NULL, &d, 0, NULL, 0, NULL, NULL, &format);
    CMSampleBufferRef sample;
    CMAudioSampleBufferCreateReadyWithPacketDescriptions(NULL, block, format, n, CMTimeMakeWithSeconds(start, 44100), NULL, &sample);
    CFRelease(block); CFRelease(format);
    return sample;
}

/// A fragmented file of `seconds`, picture or sound.
static BOOL SCIMuxSource(NSURL *url, BOOL picture, double freq, double seconds) {
    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
    AVAssetWriter *writer = [[AVAssetWriter alloc] initWithContentType:UTTypeMPEG4Movie];
    writer.outputFileTypeProfile = AVFileTypeProfileMPEG4AppleHLS;
    writer.preferredOutputSegmentInterval = CMTimeMake(1, 1);
    writer.initialSegmentStartTime = kCMTimeZero;
    SCIMuxCollector *collector = [SCIMuxCollector new];
    collector.data = [NSMutableData data];
    writer.delegate = collector;

    AVAssetWriterInput *input = picture
        ? [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:@{AVVideoCodecKey: AVVideoCodecTypeH264, AVVideoWidthKey: @160, AVVideoHeightKey: @90, AVVideoCompressionPropertiesKey: @{AVVideoMaxKeyFrameIntervalKey: @30}}]
        : [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:@{AVFormatIDKey: @(kAudioFormatMPEG4AAC), AVSampleRateKey: @44100, AVNumberOfChannelsKey: @1, AVEncoderBitRateKey: @64000}];
    [writer addInput:input];
    [writer startWriting];
    [writer startSessionAtSourceTime:kCMTimeZero];

    int frames = (int)(seconds * 30), i = 0;
    double at = 0;
    while (picture ? i < frames : at < seconds) {
        if (!input.isReadyForMoreMediaData) { usleep(200); continue; }
        if (picture) {
            CVPixelBufferRef pixels = SCIMuxFrame(160, 90, i);
            CMVideoFormatDescriptionRef format; CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixels, &format);
            CMSampleTimingInfo timing = { CMTimeMake(1, 30), CMTimeMake(i, 30), kCMTimeInvalid };
            CMSampleBufferRef sample; CMSampleBufferCreateReadyWithImageBuffer(NULL, pixels, format, &timing, &sample);
            [input appendSampleBuffer:sample];
            CFRelease(sample); CFRelease(format); CVPixelBufferRelease(pixels); i++;
        } else {
            CMSampleBufferRef sample = SCIMuxTone(freq, at, 4410);
            [input appendSampleBuffer:sample]; CFRelease(sample); at += 0.1;
        }
    }
    [input markAsFinished];
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    [writer finishWritingWithCompletionHandler:^{ dispatch_semaphore_signal(done); }];
    dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
    return writer.status == AVAssetWriterStatusCompleted && [collector.data writeToURL:url atomically:YES];
}

void Test_Mux(void) {
    printf("one file, several sounds and captions\n");

    NSString *dir = NSTemporaryDirectory();
    NSURL *(^file)(NSString *) = ^NSURL *(NSString *name) { return [NSURL fileURLWithPath:[dir stringByAppendingPathComponent:name]]; };
    NSURL *video = file(@"albrhi_mux_v.mp4"), *sound0 = file(@"albrhi_mux_a0.m4a"), *sound1 = file(@"albrhi_mux_a1.m4a"), *sound2 = file(@"albrhi_mux_a2.m4a");
    BOOL made = SCIMuxSource(video, YES, 0, 4) && SCIMuxSource(sound0, NO, 440, 4) && SCIMuxSource(sound1, NO, 660, 4) && SCIMuxSource(sound2, NO, 880, 4);

    __block NSURL *merged = nil;
    __block NSString *why = nil;
    if (made) {
        NSArray *english = [SCIYTSubtitles cuesFromVTT:@"WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nHello\n\n"];
        NSArray *arabic = [SCIYTSubtitles cuesFromVTT:@"WEBVTT\n\n00:00:01.500 --> 00:00:03.000\nمرحبا\n\n"];
        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        [SCIYTFragments mergeVideo:video audio:sound0 audioLanguage:@"en"
                       extraAudios:@[@{@"file": sound1, @"lang": @"ar"}, @{@"file": sound2, @"lang": @"de"}]
                         subtitles:@[@{@"lang": @"en", @"cues": english}, @{@"lang": @"ar", @"cues": arabic}]
                        completion:^(NSURL *output, NSString *failure) { merged = output; why = failure; dispatch_semaphore_signal(done); }];
        // The completion comes back on the main queue, which is this one.
        while (dispatch_semaphore_wait(done, DISPATCH_TIME_NOW)) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
        }
    }

    ALBRHI_TEST(sources_are_fragmented_like_youtubes, {
        ALBRHI_ASSERT(made, @"the fragmented sources could not be made on this machine");
        NSData *bytes = [NSData dataWithContentsOfURL:video];
        ALBRHI_ASSERT([bytes rangeOfData:[@"moof" dataUsingEncoding:NSASCIIStringEncoding] options:0 range:NSMakeRange(0, bytes.length)].location != NSNotFound, @"a moof box");
    });

    ALBRHI_TEST(merge_succeeds_and_keeps_the_length, {
        ALBRHI_ASSERT(merged != nil, why ?: @"no output");
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:merged options:nil];
        ALBRHI_ASSERT(fabs(CMTimeGetSeconds(asset.duration) - 4.0) < 0.3, @"about four seconds");
    });

    ALBRHI_TEST(every_sound_is_a_choice_and_only_the_original_plays_unasked, {
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:merged options:nil];
        AVMediaSelectionGroup *group = [asset mediaSelectionGroupForMediaCharacteristic:AVMediaCharacteristicAudible];
        ALBRHI_ASSERT(group.options.count == 3, @"three sounds are offered as alternatives");
        NSArray<AVAssetTrack *> *sounds = [asset tracksWithMediaType:AVMediaTypeAudio];
        ALBRHI_ASSERT(sounds.count == 3 && sounds[0].isEnabled && !sounds[1].isEnabled && !sounds[2].isEnabled, @"the first is on, the others off");
        NSMutableSet *languages = [NSMutableSet set];
        for (AVAssetTrack *track in sounds) if (track.extendedLanguageTag) [languages addObject:track.extendedLanguageTag];
        NSSet *expected = [NSSet setWithArray:@[@"en", @"ar", @"de"]];
        ALBRHI_ASSERT([languages isEqualToSet:expected], @"labelled with their languages");
    });

    ALBRHI_TEST(captions_are_offered_but_off_by_default, {
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:merged options:nil];
        AVMediaSelectionGroup *group = [asset mediaSelectionGroupForMediaCharacteristic:AVMediaCharacteristicLegible];
        ALBRHI_ASSERT(group.options.count >= 2, @"both caption tracks are offered");
        for (AVAssetTrack *track in [asset tracksWithMediaType:AVMediaTypeSubtitle]) ALBRHI_ASSERT(!track.isEnabled, @"no caption shows unasked");
    });

    ALBRHI_TEST(without_extras_the_plain_merge_is_unchanged, {
        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        __block NSURL *plain = nil;
        [SCIYTFragments mergeVideo:video audio:sound0 completion:^(NSURL *output, NSString *failure) { plain = output; dispatch_semaphore_signal(done); }];
        while (dispatch_semaphore_wait(done, DISPATCH_TIME_NOW)) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
        }
        ALBRHI_ASSERT(plain != nil, @"merged");
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:plain options:nil];
        ALBRHI_ASSERT([asset tracksWithMediaType:AVMediaTypeAudio].count == 1 && [asset tracksWithMediaType:AVMediaTypeSubtitle].count == 0, @"one sound, no captions");
    });
}
