#import "SCIYTAV1Convert.h"
#import "SCIYTFragmentsInternal.h"
#import "../../SCILog.h"
#import "../../Localization/SCILocalize.h"
#import "../../Diagnostics/SCIYTDiagnostics.h"

#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import <CoreVideo/CoreVideo.h>
#import "dav1d/dav1d.h"

// dav1d_data_wrap wants a C function pointer. The bytes belong to the memory-mapped source file,
// which outlives the whole conversion, so there is nothing to free.
static void SCINoFree(const uint8_t *buf, void *cookie) {}

static void SCIConvertNote(NSString *line) {
    [SCIYTDiagnostics recordStreamAttempt:[@"av1→hevc: " stringByAppendingString:line]];
}

/// The colour description, from the bitstream rather than assumed -- the same reasoning as the
/// Instagram transcoder, whose first HDR report came back as a file that played washed out
/// because it held the samples and did not say what they were. Only the three numbers that
/// matter, in AV1's own terms (ISO/IEC 23091-2).
static void SCIColour(Dav1dPicture *pic, CFStringRef *primaries, CFStringRef *transfer, CFStringRef *matrix) {
    *primaries = NULL; *transfer = NULL; *matrix = NULL;
    if (!pic || !pic->seq_hdr) return;

    switch ((int)pic->seq_hdr->pri) {
        case 1: *primaries = kCVImageBufferColorPrimaries_ITU_R_709_2; break;
        case 9: *primaries = kCVImageBufferColorPrimaries_ITU_R_2020; break;
        default: break;
    }
    switch ((int)pic->seq_hdr->trc) {
        case 1:  *transfer = kCVImageBufferTransferFunction_ITU_R_709_2; break;
        case 16: *transfer = kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ; break;
        case 18: *transfer = kCVImageBufferTransferFunction_ITU_R_2100_HLG; break;
        default: break;
    }
    switch ((int)pic->seq_hdr->mtrx) {
        case 1: *matrix = kCVImageBufferYCbCrMatrix_ITU_R_709_2; break;
        case 9: *matrix = kCVImageBufferYCbCrMatrix_ITU_R_2020; break;
        default: break;
    }
}

/// An 8-bit I420 picture as an NV12 buffer the encoder takes. dav1d's planes and the buffer's rows
/// have different strides, so every plane is copied line by line. Only 8-bit: the formats this is
/// offered for are 8-bit, and anything else is refused here instead of being squeezed.
static CVPixelBufferRef SCIBufferFromPicture(Dav1dPicture *pic, CVPixelBufferPoolRef pool) CF_RETURNS_RETAINED;
static CVPixelBufferRef SCIBufferFromPicture(Dav1dPicture *pic, CVPixelBufferPoolRef pool) {
    if (pic->p.bpc != 8 || pic->p.layout != DAV1D_PIXEL_LAYOUT_I420) return NULL;

    int w = pic->p.w, h = pic->p.h;
    CVPixelBufferRef pb = NULL;
    if (!pool || CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pb) != kCVReturnSuccess) {
        NSDictionary *attrs = @{ (id)kCVPixelBufferIOSurfacePropertiesKey: @{} };
        if (CVPixelBufferCreate(kCFAllocatorDefault, w, h, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                                (__bridge CFDictionaryRef)attrs, &pb) != kCVReturnSuccess) return NULL;
    }

    CVPixelBufferLockBaseAddress(pb, 0);

    uint8_t *dstY = CVPixelBufferGetBaseAddressOfPlane(pb, 0);
    size_t dstYStride = CVPixelBufferGetBytesPerRowOfPlane(pb, 0);
    for (int y = 0; y < h; y++) {
        memcpy(dstY + y * dstYStride, (const uint8_t *)pic->data[0] + y * pic->stride[0], (size_t)w);
    }

    uint8_t *dstUV = CVPixelBufferGetBaseAddressOfPlane(pb, 1);
    size_t dstUVStride = CVPixelBufferGetBytesPerRowOfPlane(pb, 1);
    int cw = (w + 1) / 2, ch = (h + 1) / 2;
    for (int y = 0; y < ch; y++) {
        uint8_t *row = dstUV + y * dstUVStride;
        const uint8_t *u = (const uint8_t *)pic->data[1] + y * pic->stride[1];
        const uint8_t *v = (const uint8_t *)pic->data[2] + y * pic->stride[1];
        for (int x = 0; x < cw; x++) { row[2 * x] = u[x]; row[2 * x + 1] = v[x]; }
    }

    CVPixelBufferUnlockBaseAddress(pb, 0);

    CFStringRef pri, trc, mtx;
    SCIColour(pic, &pri, &trc, &mtx);
    if (pri) CVBufferSetAttachment(pb, kCVImageBufferColorPrimariesKey, pri, kCVAttachmentMode_ShouldPropagate);
    if (trc) CVBufferSetAttachment(pb, kCVImageBufferTransferFunctionKey, trc, kCVAttachmentMode_ShouldPropagate);
    if (mtx) CVBufferSetAttachment(pb, kCVImageBufferYCbCrMatrixKey, mtx, kCVAttachmentMode_ShouldPropagate);
    return pb;
}

@implementation SCIYTAV1Convert

+ (void)convertVideo:(NSURL *)videoURL
               audio:(NSURL *)audioURL
            progress:(void (^)(double))progress
          completion:(void (^)(NSURL *, NSString *))completion {

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        void (^finish)(NSURL *, NSString *) = ^(NSURL *output, NSString *failure) {
            if (failure) SCIConvertNote([@"failed — " stringByAppendingString:failure]);
            dispatch_async(dispatch_get_main_queue(), ^{ completion(output, failure); });
        };

        NSString *why = nil;
        SCIFTrack *video = [SCIYTFragments trackFromFile:videoURL failure:&why];
        if (!video || ![video.codec isEqualToString:@"av01"] || !video.width || !video.height) {
            finish(nil, [NSString stringWithFormat:@"not an AV1 picture (%@)", why ?: video.codec ?: @"unreadable"]);
            return;
        }
        SCIFTrack *audio = [SCIYTFragments trackFromFile:audioURL failure:&why];
        if (!audio) { finish(nil, [@"sound unreadable — " stringByAppendingString:why ?: @"?"]); return; }

        NSUInteger total = [video count];
        double seconds = MAX([video seconds], 0.001);
        double fps = MIN(MAX((double)total / seconds, 1.0), 120.0);
        SCIConvertNote([NSString stringWithFormat:@"%ux%u, %lu frames, %.2f fps", video.width, video.height,
                        (unsigned long)total, fps]);

        // MARK: Decoder
        Dav1dSettings settings;
        dav1d_default_settings(&settings);
        // Film grain is a recipe dav1d would re-synthesise onto every frame -- decode time spent, and
        // then bits spent keeping the noise. A transcode wants neither (the Instagram transcoder's
        // reasoning, and measured there).
        settings.apply_grain = 0;
        // n_threads left at 0: one per logical core, which is what this wants.

        Dav1dContext *ctx = NULL;
        if (dav1d_open(&ctx, &settings) != 0) { finish(nil, @"dav1d could not open"); return; }

        // MARK: Writer
        NSURL *output = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:
            [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"mp4"]]];
        NSError *error = nil;
        AVAssetWriter *writer = [AVAssetWriter assetWriterWithURL:output fileType:AVFileTypeMPEG4 error:&error];
        if (!writer) { dav1d_close(&ctx); finish(nil, error.localizedDescription ?: @"writer init failed"); return; }

        // About 0.075 bits per pixel per frame: enough to keep what the AV1 source had at a similar
        // size, since HEVC and AV1 are not far apart at these rates and an under-fed encoder is the
        // difference people see.
        int64_t bitrate = (int64_t)((double)video.width * video.height * fps * 0.075);
        NSDictionary *videoSettings = @{
            AVVideoCodecKey: AVVideoCodecTypeHEVC,
            AVVideoWidthKey: @(video.width),
            AVVideoHeightKey: @(video.height),
            AVVideoCompressionPropertiesKey: @{
                AVVideoAverageBitRateKey: @(bitrate),
                AVVideoExpectedSourceFrameRateKey: @(fps),
                AVVideoMaxKeyFrameIntervalKey: @((NSInteger)MAX(1.0, fps * 2.0)),
            },
        };
        AVAssetWriterInput *videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                                            outputSettings:videoSettings];
        videoInput.expectsMediaDataInRealTime = NO;

        NSDictionary *bufferAttrs = @{
            (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
            (id)kCVPixelBufferWidthKey: @(video.width),
            (id)kCVPixelBufferHeightKey: @(video.height),
            (id)kCVPixelBufferIOSurfacePropertiesKey: @{},
        };
        AVAssetWriterInputPixelBufferAdaptor *adaptor =
            [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:videoInput
                                                                             sourcePixelBufferAttributes:bufferAttrs];
        if (![writer canAddInput:videoInput]) {
            dav1d_close(&ctx);
            finish(nil, @"the HEVC encoder is not available here");
            return;
        }
        [writer addInput:videoInput];

        CMFormatDescriptionRef audioFormat = [SCIYTFragments audioFormat:audio failure:&why];
        AVAssetWriterInput *audioInput = nil;
        if (audioFormat) {
            audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio
                                                            outputSettings:nil sourceFormatHint:audioFormat];
            audioInput.expectsMediaDataInRealTime = NO;
            if ([writer canAddInput:audioInput]) [writer addInput:audioInput]; else audioInput = nil;
        }
        if (!audioInput) {
            if (audioFormat) CFRelease(audioFormat);
            dav1d_close(&ctx);
            finish(nil, [@"sound could not be added — " stringByAppendingString:why ?: @"?"]);
            return;
        }

        if (![writer startWriting]) {
            if (audioFormat) CFRelease(audioFormat);
            dav1d_close(&ctx);
            finish(nil, [@"the writer would not start — " stringByAppendingString:writer.error.localizedDescription ?: @"?"]);
            return;
        }
        [writer startSessionAtSourceTime:kCMTimeZero];

        // MARK: The two pumps
        __block BOOL broke = NO;
        __block NSString *brokeBecause = nil;
        dispatch_group_t group = dispatch_group_create();

        // Picture: one frame per request from the writer. A decode is only asked for when the encoder
        // can take the result, which is what keeps memory flat.
        // The tracks themselves are used *inside* the blocks below, not just their pointers: the
        // file is memory-mapped by the track object, and a pointer taken outside outlives it the
        // moment this method returns -- which crashed in memmove on the first run, in the sound pump.
        int32_t vscale = (int32_t)video.timescale;
        __block NSUInteger nextSample = 0;
        __block Dav1dData pending;
        memset(&pending, 0, sizeof(pending));
        __block NSUInteger written = 0;
        __block int lastPercent = -1;
        __block BOOL sawFirst = NO;
        __block BOOL flushAsked = NO;

        // 1 = a picture, 0 = the stream is finished, -1 = an error.
        int (^nextPicture)(Dav1dPicture *) = ^int(Dav1dPicture *pic) {
            for (;;) {
                int r = dav1d_get_picture(ctx, pic);
                if (r == 0) return 1;
                if (r != DAV1D_ERR(EAGAIN)) return -1;

                if (pending.sz > 0) {
                    int s = dav1d_send_data(ctx, &pending);
                    if (s < 0 && s != DAV1D_ERR(EAGAIN)) return -1;
                    continue;
                }
                // Everything has been sent. With frame threading dav1d does not drain on the *first*
                // empty ask -- that call arms the drain and the next one performs it -- so the first
                // EAGAIN here is not the end. Stopping at it dropped the last frame of a 5,326 frame clip.
                if (nextSample >= total) {
                    if (!flushAsked) { flushAsked = YES; continue; }
                    return 0;
                }

                const SCIFSample s = ((const SCIFSample *)video.samples.bytes)[nextSample++];
                if (dav1d_data_wrap(&pending, (const uint8_t *)video.file.bytes + s.offset, s.length, SCINoFree, NULL) != 0) return -1;
                pending.m.timestamp = s.pts;
            }
        };

        dispatch_group_enter(group);
        dispatch_queue_t vq = dispatch_queue_create("com.albrhi.youtube.av1.video", DISPATCH_QUEUE_SERIAL);
        [videoInput requestMediaDataWhenReadyOnQueue:vq usingBlock:^{
            while (videoInput.isReadyForMoreMediaData) {
                if (broke || writer.status != AVAssetWriterStatusWriting) {
                    [videoInput markAsFinished];
                    dispatch_group_leave(group);
                    return;
                }

                Dav1dPicture pic;
                memset(&pic, 0, sizeof(pic));
                int got = nextPicture(&pic);
                if (got <= 0) {
                    if (got < 0) { broke = YES; brokeBecause = @"the AV1 stream could not be decoded"; }
                    [videoInput markAsFinished];
                    dispatch_group_leave(group);
                    return;
                }

                CVPixelBufferRef pb = SCIBufferFromPicture(&pic, adaptor.pixelBufferPool);
                if (!sawFirst) {
                    sawFirst = YES;
                    SCIConvertNote([NSString stringWithFormat:@"first picture: %d-bit, layout %d, transfer %d",
                                    pic.p.bpc, (int)pic.p.layout, pic.seq_hdr ? (int)pic.seq_hdr->trc : -1]);
                }
                CMTime pts = CMTimeMake(pic.m.timestamp, vscale);
                dav1d_picture_unref(&pic);

                if (!pb) { broke = YES; brokeBecause = @"a picture was not 8-bit 4:2:0"; continue; }
                BOOL ok = [adaptor appendPixelBuffer:pb withPresentationTime:pts];
                CVPixelBufferRelease(pb);
                if (!ok) { broke = YES; brokeBecause = @"the encoder refused a frame"; continue; }

                written++;
                int percent = (int)(100 * written / MAX(total, (NSUInteger)1));
                if (percent != lastPercent) {
                    lastPercent = percent;
                    if (progress) progress(MIN(1.0, (double)written / (double)total));
                }
            }
        }];

        // Sound: copied, not decoded.
        NSUInteger atotal = [audio count];
        int32_t ascale = (int32_t)audio.timescale;
        __block NSUInteger an = 0;
        dispatch_group_enter(group);
        dispatch_queue_t aq = dispatch_queue_create("com.albrhi.youtube.av1.audio", DISPATCH_QUEUE_SERIAL);
        [audioInput requestMediaDataWhenReadyOnQueue:aq usingBlock:^{
            while (audioInput.isReadyForMoreMediaData) {
                if (broke || writer.status != AVAssetWriterStatusWriting || an >= atotal) {
                    [audioInput markAsFinished];
                    dispatch_group_leave(group);
                    return;
                }
                CMSampleBufferRef buffer = [SCIYTFragments bufferFor:((const SCIFSample *)audio.samples.bytes)[an++] from:(const uint8_t *)audio.file.bytes format:audioFormat timescale:ascale];
                if (!buffer) { broke = YES; brokeBecause = @"a sound packet could not be read"; continue; }
                BOOL ok = [audioInput appendSampleBuffer:buffer];
                CFRelease(buffer);
                if (!ok) { broke = YES; brokeBecause = @"the writer refused a sound packet"; }
            }
        }];

        dispatch_group_notify(group, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            if (pending.sz > 0) dav1d_data_unref(&pending);
            Dav1dContext *toClose = ctx;
            dav1d_close(&toClose);

            if (broke) {
                [writer cancelWriting];
                if (audioFormat) CFRelease(audioFormat);
                [[NSFileManager defaultManager] removeItemAtURL:output error:nil];
                finish(nil, brokeBecause ?: @"conversion failed");
                return;
            }

            [writer finishWritingWithCompletionHandler:^{
                if (audioFormat) CFRelease(audioFormat);
                if (writer.status != AVAssetWriterStatusCompleted) {
                    [[NSFileManager defaultManager] removeItemAtURL:output error:nil];
                    finish(nil, [@"the writer failed — " stringByAppendingString:writer.error.localizedDescription ?: @"?"]);
                    return;
                }

                double wrote = CMTimeGetSeconds([AVURLAsset URLAssetWithURL:output options:nil].duration);
                SCIConvertNote([NSString stringWithFormat:@"wrote %.1fs (source %.1fs), %lu of %lu frames",
                                wrote, seconds, (unsigned long)written, (unsigned long)total]);
                finish(output, nil);
            }];
        });
    });
}

@end
