#import "SCIAV1Transcoder.h"
#import "SCIMP4Demuxer.h"
#import "../../Settings/SCIDiagnosticsViewController.h"

#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import <CoreVideo/CoreVideo.h>

#import <errno.h>
#import "dav1d/dav1d.h"

// Every stage records here so a device failure names where it happened.
static void stage(NSString *name, BOOL ok, NSString *detail) {
    [SCIDiagnostics recordTranscodeStage:name ok:ok detail:detail];
}

// dav1d_data_wrap takes a C function pointer, not a block. The bitstream NSData
// outlives decoding and is released by the caller, so nothing needs freeing here.
static void sciNoFreeCallback(const uint8_t *buf, void *cookie) {}

@interface SCIAV1Transcoder ()
// Declared up front so call order within the file cannot matter, and so ARC has
// the pixel buffer's CF ownership explicitly (its name is not in the create/copy
// family the compiler would otherwise infer a +1 return from).
+ (NSString *)downloadToTempFile:(NSURL *)url extension:(NSString *)ext;
+ (CVPixelBufferRef)pixelBufferFromPicture:(Dav1dPicture *)pic pool:(CVPixelBufferPoolRef)pool deep:(BOOL)deep CF_RETURNS_RETAINED;
+ (NSArray *)encodeH264FromBitstream:(NSData *)bitstream fps:(double)fps
                            outWidth:(int *)outW outHeight:(int *)outH
                            progress:(void (^)(NSString *))progress;
+ (BOOL)muxVideoSamples:(NSArray *)samples audioPath:(NSString *)audioPath outputPath:(NSString *)outputPath;
+ (void)cleanup:(NSArray<NSString *> *)paths;
@end

@implementation SCIAV1Transcoder

// MARK: - Download

// A blocking download to a temp file. The transcoder already runs off the main
// thread, so a semaphore here keeps the pipeline linear and readable.
+ (NSString *)downloadToTempFile:(NSURL *)url extension:(NSString *)ext {
    if (!url) return nil;

    __block NSString *path = nil;
    dispatch_semaphore_t done = dispatch_semaphore_create(0);

    NSURLSessionDownloadTask *task =
        [[NSURLSession sharedSession] downloadTaskWithURL:url
                                        completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
            if (location && !error) {
                NSString *dest = [NSTemporaryDirectory() stringByAppendingPathComponent:
                                  [[NSUUID UUID].UUIDString stringByAppendingPathExtension:ext]];
                [[NSFileManager defaultManager] removeItemAtPath:dest error:nil];
                if ([[NSFileManager defaultManager] moveItemAtURL:location
                                                            toURL:[NSURL fileURLWithPath:dest]
                                                            error:nil]) {
                    path = dest;
                }
            }
            dispatch_semaphore_signal(done);
        }];

    [task resume];

    // Bounded: a stalled CDN connection must not hang the whole transcode forever.
    if (dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 90 * NSEC_PER_SEC)) != 0) {
        [task cancel];
        return nil;
    }
    return path;
}

// MARK: - Pixel conversion

// A dav1d I420 8-bit picture as an NV12 pixel buffer VideoToolbox can encode.
// Strides differ between dav1d's planes and the pixel buffer's rows, so every
// plane is copied line by line rather than in one block.
//
// **What the picture actually was, kept for the one report that has to explain a refusal.**
//
// `frames=0 samples=0` named the stage and nothing else, and the stage was not where the fault
// was: dav1d decoded perfectly and every frame was then refused here. A count of zero is the one
// number that cannot say why it is zero.
//
static NSString *sciLastPictureFormat = nil;

//
// **The colour description, taken from the bitstream rather than assumed.**
//
// A device report settled what this is for: Instagram's reels ladder is
// `av01.0.12M.10.0.111.09.18.09.0` with `TransferCharacteristics=18`, `ColourPrimaries=9`,
// `MatrixCoefficients=9` -- ten-bit HLG in BT.2020, carrying Dolby Vision profile 10 beside it.
//
// **A file that holds those samples and does not say so is a file that plays wrong.** The player
// has no way to know, so it assumes BT.709 SDR and shows HDR data as if it were ordinary -- which
// is exactly the "saved video looks washed out next to the app" report, and it happens whether the
// samples are ten bits or eight.
//
// The numbers are AV1's own (ISO/IEC 23091-2), read from the sequence header dav1d hands back, so
// a clip that is not HDR is described as what it actually is rather than force-tagged.
//
static void SCIColourDescription(Dav1dPicture *pic,
                                 CFStringRef *primaries,
                                 CFStringRef *transfer,
                                 CFStringRef *matrix) {
    *primaries = NULL; *transfer = NULL; *matrix = NULL;
    if (!pic || !pic->seq_hdr) return;

    switch ((int)pic->seq_hdr->pri) {
        case 1:  *primaries = kCVImageBufferColorPrimaries_ITU_R_709_2; break;
        case 9:  *primaries = kCVImageBufferColorPrimaries_ITU_R_2020;  break;
        case 5:  *primaries = kCVImageBufferColorPrimaries_EBU_3213;    break;
        case 6:  *primaries = kCVImageBufferColorPrimaries_SMPTE_C;     break;
        default: break;
    }

    switch ((int)pic->seq_hdr->trc) {
        case 1:  *transfer = kCVImageBufferTransferFunction_ITU_R_709_2;      break;
        case 16: *transfer = kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ; break;
        case 18: *transfer = kCVImageBufferTransferFunction_ITU_R_2100_HLG;   break;
        case 8:  *transfer = kCVImageBufferTransferFunction_Linear;           break;
        default: break;
    }

    switch ((int)pic->seq_hdr->mtrx) {
        case 1:  *matrix = kCVImageBufferYCbCrMatrix_ITU_R_709_2;  break;
        case 9:  *matrix = kCVImageBufferYCbCrMatrix_ITU_R_2020;   break;
        case 6:  *matrix = kCVImageBufferYCbCrMatrix_ITU_R_601_4;  break;
        default: break;
    }
}


+ (CVPixelBufferRef)pixelBufferFromPicture:(Dav1dPicture *)pic pool:(CVPixelBufferPoolRef)pool deep:(BOOL)deep CF_RETURNS_RETAINED {
    int bpc = pic->p.bpc;

    // The transfer characteristic settles "is this really HDR": 16 is PQ and 18 is HLG, and
    // anything else at 10 bits is ordinary SDR that loses nothing worth seeing in the shift below.
    int trc = pic->seq_hdr ? (int)pic->seq_hdr->trc : -1;
    sciLastPictureFormat = [NSString stringWithFormat:@"%d-bit, layout %d, transfer %d%@",
        bpc, (int)pic->p.layout, trc,
        (trc == 16 || trc == 18) ? @" (HDR)" : @""];

    if (pic->p.layout != DAV1D_PIXEL_LAYOUT_I420) return NULL;

    //
    // **Instagram's AV1 ladder is 10-bit, and this line refused every frame of it.**
    //
    // `bpc != 8` was written when the only thing tested was an 8-bit clip, and it is the whole
    // reason the transcoder reported `frames=0` on a reel whose eight AV1 renditions decoded
    // without a single error. The decoder was never the problem; the frame it handed back was
    // simply not the shape this function had been taught.
    //
    // The extra bits are dropped rather than carried: an 8-bit H.264 file is what iOS plays and
    // what Photos keeps, and this is the same shift every 8-bit player performs on the same
    // stream. **Worth being plain about the cost** -- if the source is genuinely HDR (PQ or HLG
    // transfer) a straight shift is not a tone map and the picture will read flat. The transfer
    // characteristic is recorded below so the next report says which kind of 10-bit this was,
    // rather than leaving it to be argued about.
    //
    if (bpc != 8 && bpc != 10 && bpc != 12) return NULL;

    //
    // **Ten bits kept when the encoder can take them, dropped only when it cannot.**
    //
    // 4.1.11 shifted every high-depth sample down to eight so the H.264 encoder would accept it,
    // which is what made AV1 reels saveable at all -- and it is also half of why they looked flat.
    // `x420` holds ten bits in the *most significant* bits of a sixteen-bit container, which the
    // SDK header states outright, so the conversion is a shift the other way: `16 - bpc`.
    //
    // The caller decides which of the two this is, because only the caller knows whether the
    // session it created is HEVC Main10 or H.264 -- and a buffer that disagrees with its encoder
    // is worse than a shallower one.
    //
    BOOL wide = (deep && bpc > 8);
    OSType format = wide ? kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
                         : kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;

    int shift = wide ? (16 - bpc) : (bpc - 8);
    int w = pic->p.w, h = pic->p.h;

    NSDictionary *attrs = @{
        (id)kCVPixelBufferIOSurfacePropertiesKey: @{},
        (id)kCVPixelBufferPixelFormatTypeKey: @(format)
    };

    //
    // The encoder's own pool first, and a plain allocation only when there is not one -- which is
    // the first frame, before the session exists. **A fallback that is never reachable is not a
    // fallback**, and this one is reached exactly once per clip.
    //
    CVPixelBufferRef pb = NULL;
    if (pool == NULL ||
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pb) != kCVReturnSuccess) {
        if (CVPixelBufferCreate(kCFAllocatorDefault, w, h, format,
                                (__bridge CFDictionaryRef)attrs, &pb) != kCVReturnSuccess) {
            return NULL;
        }
    }

    CVPixelBufferLockBaseAddress(pb, 0);

    // Luma: straight copy, row by row.
    uint8_t *dstY = CVPixelBufferGetBaseAddressOfPlane(pb, 0);
    size_t dstYStride = CVPixelBufferGetBytesPerRowOfPlane(pb, 0);
    const uint8_t *srcY = pic->data[0];
    ptrdiff_t srcYStride = pic->stride[0];
    for (int y = 0; y < h; y++) {
        if (wide) {
            // Sixteen bits out as well as in, the samples moved up rather than thrown away.
            const uint16_t *row = (const uint16_t *)(srcY + y * srcYStride);
            uint16_t *out = (uint16_t *)(dstY + y * dstYStride);
            for (int x = 0; x < w; x++) out[x] = (uint16_t)(row[x] << shift);
        } else if (shift == 0) {
            memcpy(dstY + y * dstYStride, srcY + y * srcYStride, w);
        } else {
            // dav1d holds a high-depth sample in a 16-bit container; the stride is in bytes.
            const uint16_t *row = (const uint16_t *)(srcY + y * srcYStride);
            uint8_t *out = dstY + y * dstYStride;
            for (int x = 0; x < w; x++) out[x] = (uint8_t)(row[x] >> shift);
        }
    }

    // Chroma: dav1d keeps U and V in separate planes; NV12 interleaves them.
    uint8_t *dstUV = CVPixelBufferGetBaseAddressOfPlane(pb, 1);
    size_t dstUVStride = CVPixelBufferGetBytesPerRowOfPlane(pb, 1);
    const uint8_t *srcU = pic->data[1];
    const uint8_t *srcV = pic->data[2];
    ptrdiff_t srcCStride = pic->stride[1];
    int cw = (w + 1) / 2, ch = (h + 1) / 2;
    for (int y = 0; y < ch; y++) {
        uint8_t *row = dstUV + y * dstUVStride;
        const uint8_t *ru = srcU + y * srcCStride;
        const uint8_t *rv = srcV + y * srcCStride;
        if (wide) {
            const uint16_t *u16 = (const uint16_t *)ru;
            const uint16_t *v16 = (const uint16_t *)rv;
            uint16_t *out = (uint16_t *)row;
            for (int x = 0; x < cw; x++) {
                out[2 * x]     = (uint16_t)(u16[x] << shift);
                out[2 * x + 1] = (uint16_t)(v16[x] << shift);
            }
        } else if (shift == 0) {
            for (int x = 0; x < cw; x++) {
                row[2 * x]     = ru[x];
                row[2 * x + 1] = rv[x];
            }
        } else {
            const uint16_t *u16 = (const uint16_t *)ru;
            const uint16_t *v16 = (const uint16_t *)rv;
            for (int x = 0; x < cw; x++) {
                row[2 * x]     = (uint8_t)(u16[x] >> shift);
                row[2 * x + 1] = (uint8_t)(v16[x] >> shift);
            }
        }
    }

    CVPixelBufferUnlockBaseAddress(pb, 0);

    //
    // **Attached to the buffer, so the encoder writes it into the file's own format description.**
    // Without this the samples are right and the file still plays wrong, which is the half of the
    // wash-out that has nothing to do with bit depth.
    //
    CFStringRef primaries = NULL, transfer = NULL, matrix = NULL;
    SCIColourDescription(pic, &primaries, &transfer, &matrix);
    if (primaries) CVBufferSetAttachment(pb, kCVImageBufferColorPrimariesKey, primaries, kCVAttachmentMode_ShouldPropagate);
    if (transfer)  CVBufferSetAttachment(pb, kCVImageBufferTransferFunctionKey, transfer, kCVAttachmentMode_ShouldPropagate);
    if (matrix)    CVBufferSetAttachment(pb, kCVImageBufferYCbCrMatrixKey, matrix, kCVAttachmentMode_ShouldPropagate);

    return pb;
}

// MARK: - Encode

// Collects compressed H.264 samples in encode order for the muxer.
static void encodeOutput(void *outputCallbackRefCon,
                         void *sourceFrameRefCon,
                         OSStatus status,
                         VTEncodeInfoFlags infoFlags,
                         CMSampleBufferRef sampleBuffer) {
    if (status != noErr || !sampleBuffer) return;
    if (!CMSampleBufferDataIsReady(sampleBuffer)) return;

    NSMutableArray *out = (__bridge NSMutableArray *)outputCallbackRefCon;
    @synchronized (out) {
        [out addObject:(__bridge id)sampleBuffer];
    }
}

// MARK: - Decode + encode

// Decodes the whole AV1 bitstream, encoding each frame to H.264 as it emerges so
// only the small compressed samples are held, never every raw frame at once.
+ (NSArray *)encodeH264FromBitstream:(NSData *)bitstream
                                 fps:(double)fps
                          outWidth:(int *)outW
                         outHeight:(int *)outH
                            progress:(void (^)(NSString *))progress {
    Dav1dSettings settings;
    dav1d_default_settings(&settings);

    //
    // **Film grain synthesis off, which is two savings and not one.**
    //
    // AV1 does not store grain; it stores a *recipe* for it, and dav1d re-synthesises it onto every
    // frame -- `apply_grain` defaults to 1. That costs decode time on every frame of the clip, and
    // then costs again at the other end, because synthetic noise is the most expensive thing an
    // H.264 encoder can be asked to carry: it is high-entropy by construction, so the bits that
    // preserve it are bits not spent on the picture.
    //
    // Reinstating it would be right for a player. This is a transcoder whose output is a fixed
    // bitrate H.264 file, so the grain would be paid for twice and look worse than not having it.
    //
    settings.apply_grain = 0;

    // Threading is already right and is left alone: 0 means one thread per logical core, which is
    // what this wants. Worth writing down so the next reader does not "fix" it to a constant.

    Dav1dContext *ctx = NULL;
    if (dav1d_open(&ctx, &settings) != 0) {
        stage(@"decode", NO, @"dav1d_open failed");
        return nil;
    }

    NSMutableArray *samples = [NSMutableArray array];
    __block VTCompressionSessionRef session = NULL;
    __block int frameIndex = 0;
    __block int width = 0, height = 0;
    __block BOOL failed = NO;

    /// Whether the session that was actually created takes ten-bit buffers. Decided once, at the
    /// first picture, by trying rather than by assuming what this hardware can do.
    __block BOOL deep = NO;

    // Wrapped, not copied: the NSData outlives the loop, so a no-op free callback
    // is correct and avoids duplicating a multi-megabyte buffer.
    Dav1dData data;
    memset(&data, 0, sizeof(data));
    dav1d_data_wrap(&data, bitstream.bytes, bitstream.length, sciNoFreeCallback, NULL);

    void (^handle)(Dav1dPicture *) = ^(Dav1dPicture *pic) {
        if (session == NULL) {
            width = pic->p.w;
            height = pic->p.h;

            //
            // **The encoder is told what it will be fed, so it can hand back its own buffers.**
            //
            // With no source attributes the session has no pixel buffer pool to offer, and the
            // loop below allocated a fresh CVPixelBuffer for every single frame -- an allocation
            // and an IOSurface mapping per frame, for the whole clip. Declaring the format here
            // makes `VTCompressionSessionGetPixelBufferPool` return a real pool, and a pooled
            // buffer is a recycled one.
            //
            //
            // **Ten-bit source gets a ten-bit encoder, and HEVC is the only one iOS offers.**
            //
            // A device report settled that this is not hypothetical: Instagram's reels ladder is
            // ten-bit HLG in BT.2020, `TransferCharacteristics=18`, with Dolby Vision beside it.
            // H.264 has no ten-bit profile here, so an eight-bit encoder cannot be handed that
            // picture without throwing two of its bits away -- which is what 4.1.11 did, and half
            // of why a saved reel read flat next to the app.
            //
            // **The fallback is tried, not assumed.** Main10 encoding needs hardware this build
            // cannot ask about, so the session is *created* and only one that actually came back
            // is used. A device that cannot do it takes the eight-bit path, which is what shipped
            // before and works.
            //
            BOOL deepSource = (pic->p.bpc > 8);

            NSDictionary *(^attributesFor)(OSType) = ^(OSType fmt) {
                return @{
                    (id)kCVPixelBufferPixelFormatTypeKey: @(fmt),
                    (id)kCVPixelBufferWidthKey: @(width),
                    (id)kCVPixelBufferHeightKey: @(height),
                    (id)kCVPixelBufferIOSurfacePropertiesKey: @{}
                };
            };

            OSStatus s = kVTParameterErr;

            if (deepSource) {
                s = VTCompressionSessionCreate(kCFAllocatorDefault, width, height,
                                               kCMVideoCodecType_HEVC, NULL,
                                               (__bridge CFDictionaryRef)attributesFor(kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange), NULL,
                                               encodeOutput, (__bridge void *)samples, &session);

                if (s == noErr) {
                    OSStatus profile = VTSessionSetProperty(session, kVTCompressionPropertyKey_ProfileLevel,
                                                            kVTProfileLevel_HEVC_Main10_AutoLevel);
                    if (profile != noErr) {
                        // A session that refuses Main10 would encode ten-bit buffers as eight
                        // anyway, silently. Fail here and take the honest path instead.
                        VTCompressionSessionInvalidate(session);
                        CFRelease(session);
                        session = NULL;
                        s = profile;
                    } else {
                        deep = YES;
                    }
                }
            }

            if (session == NULL) {
                s = VTCompressionSessionCreate(kCFAllocatorDefault, width, height,
                                               kCMVideoCodecType_H264, NULL,
                                               (__bridge CFDictionaryRef)attributesFor(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange), NULL,
                                               encodeOutput, (__bridge void *)samples, &session);
                if (s == noErr) {
                    VTSessionSetProperty(session, kVTCompressionPropertyKey_ProfileLevel,
                                         kVTProfileLevel_H264_High_AutoLevel);
                }
            }

            if (s != noErr || session == NULL) { failed = YES; return; }

            VTSessionSetProperty(session, kVTCompressionPropertyKey_RealTime, kCFBooleanFalse);

            //
            // The same description the buffers carry, told to the session as well: the attachment
            // governs the frame, this governs the track's format description, and a file where
            // those two disagree is a file two players will disagree about.
            //
            CFStringRef pri = NULL, trc = NULL, mtx = NULL;
            SCIColourDescription(pic, &pri, &trc, &mtx);
            if (pri) VTSessionSetProperty(session, kVTCompressionPropertyKey_ColorPrimaries, pri);
            if (trc) VTSessionSetProperty(session, kVTCompressionPropertyKey_TransferFunction, trc);
            if (mtx) VTSessionSetProperty(session, kVTCompressionPropertyKey_YCbCrMatrix, mtx);
            VTSessionSetProperty(session, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanTrue);

            int32_t keyInterval = (int32_t)MAX(1.0, fps * 2.0);
            CFNumberRef kiRef = CFNumberCreate(NULL, kCFNumberSInt32Type, &keyInterval);
            VTSessionSetProperty(session, kVTCompressionPropertyKey_MaxKeyFrameInterval, kiRef);
            CFRelease(kiRef);

            // Enough to preserve the source without inflating a low-bitrate clip:
            // roughly 0.07 bits per pixel per second.
            int32_t bitrate = (int32_t)(width * height * fps * 0.07);
            CFNumberRef brRef = CFNumberCreate(NULL, kCFNumberSInt32Type, &bitrate);
            VTSessionSetProperty(session, kVTCompressionPropertyKey_AverageBitRate, brRef);
            CFRelease(brRef);
        }

        CVPixelBufferRef pb = [self pixelBufferFromPicture:pic pool:VTCompressionSessionGetPixelBufferPool(session) deep:deep];
        if (!pb) { failed = YES; return; }

        CMTime pts = CMTimeMakeWithSeconds(frameIndex / fps, 600);
        CMTime dur = CMTimeMakeWithSeconds(1.0 / fps, 600);
        VTCompressionSessionEncodeFrame(session, pb, pts, dur, NULL, NULL, NULL);
        frameIndex++;

        // Live count so a slow transcode is visibly distinct from a stuck one.
        if (progress && frameIndex % 15 == 0) {
            progress([NSString stringWithFormat:@"%d", frameIndex]);
        }

        CVPixelBufferRelease(pb);
    };

    // Send, draining decoded frames after each push; EAGAIN just means "more data
    // needed" or "call get_picture again", not an error.
    size_t lastSize = data.sz + 1;
    int stalls = 0;
    while (data.sz > 0 && !failed) {
        int r = dav1d_send_data(ctx, &data);
        if (r < 0 && r != DAV1D_ERR(EAGAIN)) { failed = YES; break; }

        BOOL gotPicture = NO;
        Dav1dPicture pic;
        memset(&pic, 0, sizeof(pic));
        while (dav1d_get_picture(ctx, &pic) == 0) {
            handle(&pic);
            dav1d_picture_unref(&pic);
            gotPicture = YES;
            if (failed) break;
        }

        // Guard against a malformed stream that neither advances nor errors:
        // if a pass consumes no bytes and yields no frame, give up rather than spin.
        if (data.sz == lastSize && !gotPicture) {
            if (++stalls > 32) { failed = YES; break; }
        } else {
            stalls = 0;
        }
        lastSize = data.sz;
    }

    // Drain whatever is still buffered.
    //
    // **The first empty ask is not the end.** With frame threading dav1d arms its drain on the first
    // get_picture that finds no input and performs it on the next, so breaking at the first EAGAIN
    // left the frames still in flight undelivered -- measured in the YouTube converter on a 5,326
    // frame clip, which lost exactly its last frame until it asked twice.
    if (!failed) {
        BOOL armed = NO;
        for (;;) {
            Dav1dPicture pic;
            memset(&pic, 0, sizeof(pic));
            int r = dav1d_get_picture(ctx, &pic);
            if (r < 0) {
                if (r == DAV1D_ERR(EAGAIN) && !armed) { armed = YES; continue; }
                break;
            }
            handle(&pic);
            dav1d_picture_unref(&pic);
            if (failed) break;
        }
    }

    dav1d_data_unref(&data);

    if (session) {
        VTCompressionSessionCompleteFrames(session, kCMTimeInvalid);
        VTCompressionSessionInvalidate(session);
        CFRelease(session);
    }
    dav1d_close(&ctx);

    if (failed || samples.count == 0) {
        stage(@"decode+encode", NO,
              [NSString stringWithFormat:@"frames=%d samples=%lu — picture: %@", frameIndex,
                  (unsigned long)samples.count,
                  sciLastPictureFormat ?: @"none decoded, so the fault is before this point"]);
        return nil;
    }

    *outW = width;
    *outH = height;
    stage(@"decode+encode", YES,
          [NSString stringWithFormat:@"%dx%d, %d frames, %@ — %@", width, height, frameIndex,
              deep ? @"HEVC Main10, 10-bit kept" : @"H.264, 8-bit",
              sciLastPictureFormat ?: @"picture not described"]);
    return samples;
}

// MARK: - Mux

+ (BOOL)muxVideoSamples:(NSArray *)samples
              audioPath:(NSString *)audioPath
             outputPath:(NSString *)outputPath {
    [[NSFileManager defaultManager] removeItemAtPath:outputPath error:nil];

    NSError *error = nil;
    AVAssetWriter *writer =
        [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:outputPath]
                                  fileType:AVFileTypeMPEG4
                                     error:&error];
    if (!writer) {
        stage(@"mux", NO, error.localizedDescription ?: @"writer init failed");
        return NO;
    }

    CMSampleBufferRef first = (__bridge CMSampleBufferRef)samples.firstObject;
    CMFormatDescriptionRef fmt = CMSampleBufferGetFormatDescription(first);

    AVAssetWriterInput *videoInput =
        [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo
                                       outputSettings:nil
                                     sourceFormatHint:fmt];
    videoInput.expectsMediaDataInRealTime = NO;
    if ([writer canAddInput:videoInput]) [writer addInput:videoInput];

    // Audio is optional: a missing or unreadable track yields a video-only file
    // rather than failing the whole transcode.
    AVAssetReader *audioReader = nil;
    AVAssetReaderTrackOutput *audioOutput = nil;
    AVAssetWriterInput *audioInput = nil;

    if (audioPath) {
        AVURLAsset *asset = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:audioPath]];
        AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeAudio].firstObject;
        if (track) {
            audioReader = [AVAssetReader assetReaderWithAsset:asset error:nil];
            audioOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:track
                                                                    outputSettings:@{ AVFormatIDKey: @(kAudioFormatLinearPCM) }];
            if ([audioReader canAddOutput:audioOutput]) [audioReader addOutput:audioOutput];

            NSDictionary *aac = @{
                AVFormatIDKey: @(kAudioFormatMPEG4AAC),
                AVSampleRateKey: @44100,
                AVNumberOfChannelsKey: @2,
                AVEncoderBitRateKey: @128000
            };
            audioInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio
                                                        outputSettings:aac];
            audioInput.expectsMediaDataInRealTime = NO;
            if ([writer canAddInput:audioInput]) [writer addInput:audioInput];
        }
    }

    if (![writer startWriting]) {
        stage(@"mux", NO, writer.error.localizedDescription ?: @"startWriting failed");
        return NO;
    }
    [writer startSessionAtSourceTime:kCMTimeZero];

    // Both inputs are pumped in parallel via requestMediaDataWhenReady. Feeding all
    // of one input and then the other deadlocks a non-realtime writer: it will not
    // drain video past a point until audio covers the same time range, so the video
    // input never becomes ready and the audio is never reached.
    BOOL hasAudio = audioReader && audioInput && [audioReader startReading];

    dispatch_group_t group = dispatch_group_create();

    dispatch_group_enter(group);
    __block NSUInteger vi = 0;
    __block BOOL vDone = NO;
    dispatch_queue_t vq = dispatch_queue_create("com.albrhi.mux.video", DISPATCH_QUEUE_SERIAL);
    [videoInput requestMediaDataWhenReadyOnQueue:vq usingBlock:^{
        if (vDone) return;
        while (videoInput.isReadyForMoreMediaData) {
            if (writer.status != AVAssetWriterStatusWriting || vi >= samples.count) {
                vDone = YES;
                [videoInput markAsFinished];
                dispatch_group_leave(group);
                return;
            }
            [videoInput appendSampleBuffer:(__bridge CMSampleBufferRef)samples[vi++]];
        }
    }];

    if (hasAudio) {
        dispatch_group_enter(group);
        __block BOOL aDone = NO;
        dispatch_queue_t aq = dispatch_queue_create("com.albrhi.mux.audio", DISPATCH_QUEUE_SERIAL);
        [audioInput requestMediaDataWhenReadyOnQueue:aq usingBlock:^{
            if (aDone) return;
            while (audioInput.isReadyForMoreMediaData) {
                CMSampleBufferRef buf = (writer.status == AVAssetWriterStatusWriting)
                    ? [audioOutput copyNextSampleBuffer] : NULL;
                if (!buf) {
                    aDone = YES;
                    [audioInput markAsFinished];
                    dispatch_group_leave(group);
                    return;
                }
                [audioInput appendSampleBuffer:buf];
                CFRelease(buf);
            }
        }];
    } else if (audioInput) {
        [audioInput markAsFinished];
    }

    // Bounded: neither the pumps nor the writer callback can hang the pipeline.
    if (dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 180 * NSEC_PER_SEC)) != 0) {
        stage(@"mux", NO, @"input pumps timed out");
        return NO;
    }

    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    [writer finishWritingWithCompletionHandler:^{ dispatch_semaphore_signal(done); }];
    if (dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 120 * NSEC_PER_SEC)) != 0) {
        stage(@"mux", NO, @"finishWriting timed out");
        return NO;
    }

    BOOL ok = writer.status == AVAssetWriterStatusCompleted;
    stage(@"mux", ok, ok ? @"completed"
                         : (writer.error.localizedDescription ?: @"writer failed"));
    return ok;
}

// MARK: - Orchestration

+ (BOOL)transcodeVideoURL:(NSURL *)videoURL
                 audioURL:(NSURL *)audioURL
                      fps:(double)fps
             toOutputPath:(NSString *)outputPath
                 progress:(void (^)(NSString *))progress {
    if (fps < 1.0) fps = 30.0;

    NSString *videoPath = [self downloadToTempFile:videoURL extension:@"mp4"];
    if (!videoPath) { stage(@"download-video", NO, @"failed/timeout"); return NO; }
    stage(@"download-video", YES, nil);

    NSString *audioPath = [self downloadToTempFile:audioURL extension:@"mp4"];
    stage(@"download-audio", audioPath != nil, audioPath ? nil : @"none (video-only)");

    NSData *mp4 = [NSData dataWithContentsOfFile:videoPath];
    NSData *bitstream = [SCIMP4Demuxer av1BitstreamFromMP4:mp4];
    if (!bitstream) {
        stage(@"demux", NO, @"no av1C/mdat");
        [self cleanup:@[videoPath, audioPath ?: @""]];
        return NO;
    }
    stage(@"demux", YES, [NSString stringWithFormat:@"%lu bytes", (unsigned long)bitstream.length]);

    int w = 0, h = 0;
    NSArray *samples = [self encodeH264FromBitstream:bitstream fps:fps
                                           outWidth:&w outHeight:&h progress:progress];
    if (!samples) {
        [self cleanup:@[videoPath, audioPath ?: @""]];
        return NO;
    }

    if (progress) progress(@"mux");
    BOOL ok = [self muxVideoSamples:samples audioPath:audioPath outputPath:outputPath];

    [self cleanup:@[videoPath, audioPath ?: @""]];
    return ok;
}

+ (void)cleanup:(NSArray<NSString *> *)paths {
    for (NSString *p in paths) {
        if (p.length) [[NSFileManager defaultManager] removeItemAtPath:p error:nil];
    }
}

@end
