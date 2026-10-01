#import "SCIYTFragments.h"
#import "SCIYTFragmentsInternal.h"
#import "../../SCILog.h"
#import "../../Localization/SCILocalize.h"
#import "../../Diagnostics/SCIYTDiagnostics.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

// MARK: - Reading numbers out of a file

/// Big-endian reads, each checked against the end. A malformed box is a file somebody served
/// us, and the answer to reading past its end is a refusal rather than whatever is next in memory.
static BOOL SCIFRead(const uint8_t *bytes, uint64_t length, uint64_t at, unsigned width, uint64_t *out) {
    if (at > length || width > length - at) return NO;
    uint64_t value = 0;
    for (unsigned i = 0; i < width; i++) value = (value << 8) | bytes[at + i];
    *out = value;
    return YES;
}

typedef struct {
    uint64_t start;     ///< where the box begins
    uint64_t size;      ///< whole box, header included
    uint64_t header;    ///< 8, or 16 for a 64-bit size
    char type[5];
} SCIFBox;

/// The box that starts at `*at`, or NO at the end or on anything that does not add up.
static BOOL SCIFNextBox(const uint8_t *bytes, uint64_t end, uint64_t *at, SCIFBox *box) {
    uint64_t size = 0, header = 8;
    if (*at + 8 > end) return NO;
    if (!SCIFRead(bytes, end, *at, 4, &size)) return NO;

    memcpy(box->type, bytes + *at + 4, 4);
    box->type[4] = 0;

    if (size == 1) {
        if (!SCIFRead(bytes, end, *at + 8, 8, &size)) return NO;
        header = 16;
    } else if (size == 0) {
        size = end - *at;
    }

    if (size < header || size > end - *at) return NO;

    box->start = *at;
    box->size = size;
    box->header = header;
    *at += size;
    return YES;
}

static BOOL SCIFIs(const SCIFBox *box, const char *type) {
    return strncmp(box->type, type, 4) == 0;
}

// MARK: - One track

@implementation SCIFTrack

- (NSUInteger)count { return self.samples.length / sizeof(SCIFSample); }

/// Where the last frame ends, in seconds. What the file claims, to compare with what was written.
- (double)seconds {
    NSUInteger count = [self count];
    if (!count || !self.timescale) return 0;
    const SCIFSample *all = self.samples.bytes;
    int64_t end = all[count - 1].dts + all[count - 1].duration;
    return (double)end / self.timescale;
}

@end

// MARK: - The sample description

/// A variable-length descriptor size: seven bits a byte, high bit meaning "more follows".
static BOOL SCIFDescriptor(const uint8_t *bytes, uint64_t end, uint64_t *at, uint8_t *tag, uint64_t *size) {
    if (*at >= end) return NO;
    *tag = bytes[(*at)++];
    uint64_t value = 0;
    for (int i = 0; i < 4; i++) {
        if (*at >= end) return NO;
        uint8_t byte = bytes[(*at)++];
        value = (value << 7) | (byte & 0x7F);
        if (!(byte & 0x80)) break;
    }
    *size = value;
    return *at + value <= end;
}

/// The ES descriptor out of an `esds` box -- after checking it really holds an AudioSpecificConfig -- or nil.
static NSData *SCIFAudioConfig(const uint8_t *bytes, uint64_t start, uint64_t end) {
    uint64_t at = start + 4;      // version and flags
    uint8_t tag = 0;
    uint64_t size = 0;

    // ES_Descriptor, then DecoderConfigDescriptor inside it, then DecoderSpecificInfo inside that.
    if (!SCIFDescriptor(bytes, end, &at, &tag, &size) || tag != 0x03) return nil;
    uint64_t esEnd = at + size;
    uint64_t flags = 0;
    if (!SCIFRead(bytes, esEnd, at + 2, 1, &flags)) return nil;
    at += 3;
    if (flags & 0x80) at += 2;
    if (flags & 0x40) { uint64_t url = 0; if (!SCIFRead(bytes, esEnd, at, 1, &url)) return nil; at += 1 + url; }
    if (flags & 0x20) at += 2;

    if (!SCIFDescriptor(bytes, esEnd, &at, &tag, &size) || tag != 0x04) return nil;
    uint64_t decoderEnd = at + size;
    at += 13;                     // object type, stream type, buffer size, max and average bitrate

    if (!SCIFDescriptor(bytes, decoderEnd, &at, &tag, &size) || tag != 0x05 || size < 2) return nil;

    // Core Audio's AAC "magic cookie" is the whole ES descriptor as the file carries it, not the
    // bare AudioSpecificConfig inside it. Handed the two-byte form, the writer wraps it in a
    // second descriptor of its own and produces an `esds` nothing will open -- measured: the
    // output had no readable audio track at all while the writer reported success.
    return [NSData dataWithBytes:bytes + start + 4 length:(NSUInteger)(end - start - 4)];
}

static void SCIFReadSampleEntry(SCIFTrack *track, const uint8_t *bytes, SCIFBox entry) {
    track.codec = @(entry.type);
    uint64_t body = entry.start + entry.header;
    uint64_t end = entry.start + entry.size;

    if (SCIFIs(&entry, "avc1") || SCIFIs(&entry, "avc3")) {
        uint64_t at = body + 78;       // the visual sample entry's fixed fields
        SCIFBox child;
        while (SCIFNextBox(bytes, end, &at, &child)) {
            if (!SCIFIs(&child, "avcC")) continue;

            uint64_t p = child.start + child.header;
            uint64_t lengthByte = 0, spsCount = 0;
            if (!SCIFRead(bytes, end, p + 4, 1, &lengthByte)) return;
            track.nalLength = (uint8_t)((lengthByte & 0x03) + 1);

            if (!SCIFRead(bytes, end, p + 5, 1, &spsCount)) return;
            p += 6;
            if ((spsCount & 0x1F) >= 1) {
                uint64_t size = 0;
                if (!SCIFRead(bytes, end, p, 2, &size) || p + 2 + size > end) return;
                track.sps = [NSData dataWithBytes:bytes + p + 2 length:(NSUInteger)size];
                p += 2 + size;
                for (uint64_t skip = 1; skip < (spsCount & 0x1F); skip++) {
                    if (!SCIFRead(bytes, end, p, 2, &size)) return;
                    p += 2 + size;
                }
            }

            uint64_t ppsCount = 0;
            if (!SCIFRead(bytes, end, p, 1, &ppsCount) || ppsCount < 1) return;
            p += 1;
            uint64_t size = 0;
            if (!SCIFRead(bytes, end, p, 2, &size) || p + 2 + size > end) return;
            track.pps = [NSData dataWithBytes:bytes + p + 2 length:(NSUInteger)size];
            return;
        }
        return;
    }

    // AV1 (`av01`): the picture is not decoded or touched, only described to the writer. The
    // visual sample entry's width and height sit at fixed offsets, and the codec's own
    // configuration is the `av1C` child, which the writer needs verbatim to write an entry a
    // player will accept.
    if (SCIFIs(&entry, "av01")) {
        uint64_t w = 0, h = 0;
        SCIFRead(bytes, end, body + 24, 2, &w);
        SCIFRead(bytes, end, body + 26, 2, &h);
        track.width = (uint32_t)w;
        track.height = (uint32_t)h;

        uint64_t at = body + 78;
        SCIFBox child;
        while (SCIFNextBox(bytes, end, &at, &child)) {
            if (SCIFIs(&child, "av1C")) {
                track.av1c = [NSData dataWithBytes:bytes + child.start + child.header
                                            length:(NSUInteger)(child.size - child.header)];
                return;
            }
        }
        return;
    }

    if (SCIFIs(&entry, "mp4a")) {
        uint64_t channels = 0, rate = 0;
        SCIFRead(bytes, end, body + 16, 2, &channels);
        SCIFRead(bytes, end, body + 24, 4, &rate);
        track.channels = (uint32_t)channels;
        track.sampleRate = (uint32_t)(rate >> 16);

        uint64_t at = body + 28;
        SCIFBox child;
        while (SCIFNextBox(bytes, end, &at, &child)) {
            if (SCIFIs(&child, "esds")) {
                track.audioConfig = SCIFAudioConfig(bytes, child.start + child.header, child.start + child.size);
                return;
            }
        }
    }
}

// MARK: - Reading a file

@interface SCIYTFragments ()
@end

@implementation SCIYTFragments

+ (void)readTrack:(SCIFTrack *)track from:(const uint8_t *)bytes box:(SCIFBox)trak {
    uint64_t end = trak.start + trak.size;
    uint64_t at = trak.start + trak.header;
    SCIFBox child;

    while (SCIFNextBox(bytes, end, &at, &child)) {
        if (SCIFIs(&child, "tkhd")) {
            uint64_t p = child.start + child.header, version = 0, id = 0;
            SCIFRead(bytes, end, p, 1, &version);
            SCIFRead(bytes, end, p + (version == 1 ? 20 : 12), 4, &id);
            track.trackID = (uint32_t)id;
        }

        if (!SCIFIs(&child, "mdia")) continue;

        uint64_t mEnd = child.start + child.size, mAt = child.start + child.header;
        SCIFBox m;
        while (SCIFNextBox(bytes, mEnd, &mAt, &m)) {
            if (SCIFIs(&m, "mdhd")) {
                uint64_t p = m.start + m.header, version = 0, scale = 0;
                SCIFRead(bytes, mEnd, p, 1, &version);
                SCIFRead(bytes, mEnd, p + (version == 1 ? 20 : 12), 4, &scale);
                track.timescale = (uint32_t)scale;
            } else if (SCIFIs(&m, "hdlr")) {
                uint64_t p = m.start + m.header + 8;
                if (p + 4 <= mEnd) track.handler = [[NSString alloc] initWithBytes:bytes + p length:4 encoding:NSASCIIStringEncoding];
            } else if (SCIFIs(&m, "minf")) {
                // minf > stbl > stsd > first entry
                uint64_t iEnd = m.start + m.size, iAt = m.start + m.header;
                SCIFBox i1;
                while (SCIFNextBox(bytes, iEnd, &iAt, &i1)) {
                    if (!SCIFIs(&i1, "stbl")) continue;
                    uint64_t sEnd = i1.start + i1.size, sAt = i1.start + i1.header;
                    SCIFBox s;
                    while (SCIFNextBox(bytes, sEnd, &sAt, &s)) {
                        if (!SCIFIs(&s, "stsd")) continue;
                        uint64_t eAt = s.start + s.header + 8;     // version/flags and the entry count
                        SCIFBox entry;
                        if (SCIFNextBox(bytes, s.start + s.size, &eAt, &entry)) SCIFReadSampleEntry(track, bytes, entry);
                    }
                }
            }
        }
    }
}

/// Every fragment's frames, appended to the track's table in file order.
+ (BOOL)readFragment:(SCIFTrack *)track from:(const uint8_t *)bytes length:(uint64_t)length moof:(SCIFBox)moof {
    uint64_t end = moof.start + moof.size;
    uint64_t at = moof.start + moof.header;
    SCIFBox traf;

    while (SCIFNextBox(bytes, end, &at, &traf)) {
        if (!SCIFIs(&traf, "traf")) continue;

        uint64_t tEnd = traf.start + traf.size, tAt = traf.start + traf.header;
        uint64_t baseOffset = moof.start;
        uint32_t defDuration = track.defaultDuration, defSize = track.defaultSize, defFlags = track.defaultFlags;
        BOOL mine = NO;
        uint64_t cursor = 0;
        BOOL cursorSet = NO;

        SCIFBox box;
        while (SCIFNextBox(bytes, tEnd, &tAt, &box)) {
            uint64_t p = box.start + box.header;

            if (SCIFIs(&box, "tfhd")) {
                uint64_t flags = 0, id = 0;
                SCIFRead(bytes, tEnd, p, 4, &flags);
                SCIFRead(bytes, tEnd, p + 4, 4, &id);
                mine = (id == track.trackID);
                p += 8;
                uint64_t v = 0;
                if (flags & 0x1) { SCIFRead(bytes, tEnd, p, 8, &v); baseOffset = v; p += 8; }
                if (flags & 0x2) p += 4;
                if (flags & 0x8)  { SCIFRead(bytes, tEnd, p, 4, &v); defDuration = (uint32_t)v; p += 4; }
                if (flags & 0x10) { SCIFRead(bytes, tEnd, p, 4, &v); defSize = (uint32_t)v; p += 4; }
                if (flags & 0x20) { SCIFRead(bytes, tEnd, p, 4, &v); defFlags = (uint32_t)v; p += 4; }
            } else if (SCIFIs(&box, "tfdt") && mine) {
                uint64_t version = 0, base = 0;
                SCIFRead(bytes, tEnd, p, 1, &version);
                if (SCIFRead(bytes, tEnd, p + 4, version == 1 ? 8 : 4, &base)) track.nextDTS = (int64_t)base;
            } else if (SCIFIs(&box, "trun") && mine) {
                uint64_t flags = 0, count = 0;
                SCIFRead(bytes, tEnd, p, 4, &flags);
                uint64_t version = flags >> 24;
                flags &= 0xFFFFFF;
                if (!SCIFRead(bytes, tEnd, p + 4, 4, &count)) return NO;
                p += 8;

                if (flags & 0x1) {
                    uint64_t raw = 0;
                    if (!SCIFRead(bytes, tEnd, p, 4, &raw)) return NO;
                    int32_t offset = (int32_t)raw;
                    cursor = (uint64_t)((int64_t)baseOffset + offset);
                    cursorSet = YES;
                    p += 4;
                }
                if (!cursorSet) { cursor = baseOffset; cursorSet = YES; }

                uint32_t firstFlags = defFlags;
                BOOL hasFirst = NO;
                if (flags & 0x4) {
                    uint64_t raw = 0;
                    if (!SCIFRead(bytes, tEnd, p, 4, &raw)) return NO;
                    firstFlags = (uint32_t)raw; hasFirst = YES; p += 4;
                }

                for (uint64_t i = 0; i < count; i++) {
                    uint64_t duration = defDuration, size = defSize, sflags = defFlags, cto = 0;
                    if (flags & 0x100) { if (!SCIFRead(bytes, tEnd, p, 4, &duration)) return NO; p += 4; }
                    if (flags & 0x200) { if (!SCIFRead(bytes, tEnd, p, 4, &size)) return NO; p += 4; }
                    if (flags & 0x400) { if (!SCIFRead(bytes, tEnd, p, 4, &sflags)) return NO; p += 4; }
                    else if (i == 0 && hasFirst) sflags = firstFlags;
                    if (flags & 0x800) { if (!SCIFRead(bytes, tEnd, p, 4, &cto)) return NO; p += 4; }
                    if (i == 0 && hasFirst && (flags & 0x400)) sflags = firstFlags;

                    int64_t composition = (version == 1) ? (int64_t)(int32_t)cto : (int64_t)cto;

                    if (size == 0 || cursor + size > length) return NO;

                    SCIFSample sample;
                    sample.offset = cursor;
                    sample.length = (uint32_t)size;
                    sample.duration = (uint32_t)duration;
                    sample.dts = track.nextDTS;
                    sample.pts = track.nextDTS + composition;
                    // "is non-sync" is bit 16 of the sample flags; absent means a key frame.
                    sample.sync = (sflags & 0x00010000) ? 0 : 1;
                    [track.samples appendBytes:&sample length:sizeof(sample)];

                    cursor += size;
                    track.nextDTS += (int64_t)duration;
                }
            }
        }
    }
    return YES;
}

/// A file's first track, with every frame located. Nil with a sentence when it cannot be read.
+ (SCIFTrack *)trackFromFile:(NSURL *)url failure:(NSString **)failure {
    NSData *data = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:nil];
    if (data.length < 32) { if (failure) *failure = @"file is empty"; return nil; }

    const uint8_t *bytes = data.bytes;
    uint64_t length = data.length;

    SCIFTrack *track = [[SCIFTrack alloc] init];
    track.samples = [NSMutableData data];
    track.file = data;

    uint64_t at = 0;
    SCIFBox box;
    BOOL sawMoov = NO;
    uint32_t trexDuration = 0, trexSize = 0, trexFlags = 0;
    NSMutableArray<NSValue *> *fragments = [NSMutableArray array];

    while (SCIFNextBox(bytes, length, &at, &box)) {
        if (SCIFIs(&box, "moov")) {
            sawMoov = YES;
            uint64_t mEnd = box.start + box.size, mAt = box.start + box.header;
            SCIFBox child;
            while (SCIFNextBox(bytes, mEnd, &mAt, &child)) {
                if (SCIFIs(&child, "trak") && !track.handler.length) {
                    [self readTrack:track from:bytes box:child];
                } else if (SCIFIs(&child, "mvex")) {
                    uint64_t xEnd = child.start + child.size, xAt = child.start + child.header;
                    SCIFBox x;
                    while (SCIFNextBox(bytes, xEnd, &xAt, &x)) {
                        if (!SCIFIs(&x, "trex")) continue;
                        uint64_t p = x.start + x.header + 4, id = 0, d = 0, s = 0, f = 0;
                        SCIFRead(bytes, xEnd, p, 4, &id);
                        SCIFRead(bytes, xEnd, p + 8, 4, &d);
                        SCIFRead(bytes, xEnd, p + 12, 4, &s);
                        SCIFRead(bytes, xEnd, p + 16, 4, &f);
                        if (id == track.trackID || !trexDuration) { trexDuration = (uint32_t)d; trexSize = (uint32_t)s; trexFlags = (uint32_t)f; }
                    }
                }
            }
        } else if (SCIFIs(&box, "moof")) {
            SCIFBox copy = box;
            [fragments addObject:[NSValue valueWithBytes:&copy objCType:@encode(SCIFBox)]];
        }
    }

    if (!sawMoov || !track.handler.length || !track.timescale) { if (failure) *failure = @"no readable track"; return nil; }
    if (!fragments.count) { if (failure) *failure = @"not a fragmented file"; return nil; }

    track.defaultDuration = trexDuration;
    track.defaultSize = trexSize;
    track.defaultFlags = trexFlags;

    for (NSValue *value in fragments) {
        SCIFBox moof;
        [value getValue:&moof];
        if (![self readFragment:track from:bytes length:length moof:moof]) {
            if (failure) *failure = @"a fragment does not add up";
            return nil;
        }
    }

    if (![track count]) { if (failure) *failure = @"no frames"; return nil; }
    return track;
}

// MARK: - Handing the frames to Apple

+ (CMSampleBufferRef)bufferFor:(SCIFSample)sample
                          from:(const uint8_t *)bytes
                        format:(CMFormatDescriptionRef)format
                     timescale:(int32_t)timescale CF_RETURNS_RETAINED {
    CMBlockBufferRef block = NULL;
    if (CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, NULL, sample.length, kCFAllocatorDefault,
                                           NULL, 0, sample.length, kCMBlockBufferAssureMemoryNowFlag,
                                           &block) != noErr) return NULL;
    if (CMBlockBufferReplaceDataBytes(bytes + sample.offset, block, 0, sample.length) != noErr) {
        CFRelease(block);
        return NULL;
    }

    CMSampleTimingInfo timing;
    timing.duration = CMTimeMake(sample.duration, timescale);
    timing.presentationTimeStamp = CMTimeMake(sample.pts, timescale);
    timing.decodeTimeStamp = CMTimeMake(sample.dts, timescale);

    CMSampleBufferRef buffer = NULL;
    size_t size = sample.length;
    OSStatus status = CMSampleBufferCreate(kCFAllocatorDefault, block, TRUE, NULL, NULL, format, 1, 1,
                                           &timing, 1, &size, &buffer);
    CFRelease(block);
    if (status != noErr) return NULL;

    if (!sample.sync) {
        CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, YES);
        if (attachments && CFArrayGetCount(attachments)) {
            CFMutableDictionaryRef entry = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
            CFDictionarySetValue(entry, kCMSampleAttachmentKey_NotSync, kCFBooleanTrue);
        }
    }
    return buffer;
}

+ (CMFormatDescriptionRef)videoFormat:(SCIFTrack *)track failure:(NSString **)failure CF_RETURNS_RETAINED {
    // AV1 is written untouched, which is why 1440p and 4K can be offered at all: YouTube serves
    // them as fragmented MP4 in AV1 (and as WebM in VP9, which has no such route). Whether the
    // *phone* can play the result is a different question and it is answered where the file is
    // opened, not here -- this only has to write a file that is correct.
    if ([track.codec isEqualToString:@"av01"]) {
        if (!track.av1c.length || !track.width || !track.height) {
            if (failure) *failure = @"AV1 picture without its configuration";
            return NULL;
        }

        NSDictionary *extensions = @{
            (__bridge NSString *)kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms: @{ @"av1C": track.av1c }
        };
        CMFormatDescriptionRef format = NULL;
        OSStatus status = CMVideoFormatDescriptionCreate(kCFAllocatorDefault, kCMVideoCodecType_AV1,
                                                         (int32_t)track.width, (int32_t)track.height,
                                                         (__bridge CFDictionaryRef)extensions, &format);
        if (status != noErr) {
            if (failure) *failure = [NSString stringWithFormat:@"the AV1 description was refused (%d)", (int)status];
            return NULL;
        }
        return format;
    }

    if (![track.codec hasPrefix:@"avc"] || !track.sps.length || !track.pps.length) {
        if (failure) *failure = [NSString stringWithFormat:@"video is %@, not H.264 or AV1", track.codec ?: @"unknown"];
        return NULL;
    }
    // The frames in the file are length-prefixed, and the writer is told how long the prefix is.
    // Anything but four bytes would need every frame rewritten, and YouTube does not send it.
    if (track.nalLength != 4) {
        if (failure) *failure = [NSString stringWithFormat:@"unsupported NAL length %u", track.nalLength];
        return NULL;
    }

    const uint8_t *sets[2] = { track.sps.bytes, track.pps.bytes };
    const size_t sizes[2] = { track.sps.length, track.pps.length };
    CMFormatDescriptionRef format = NULL;
    if (CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault, 2, sets, sizes, 4, &format) != noErr) {
        if (failure) *failure = @"the picture description was refused";
        return NULL;
    }
    return format;
}

+ (CMFormatDescriptionRef)audioFormat:(SCIFTrack *)track failure:(NSString **)failure CF_RETURNS_RETAINED {
    if (![track.codec isEqualToString:@"mp4a"] || !track.audioConfig.length || !track.sampleRate) {
        if (failure) *failure = [NSString stringWithFormat:@"audio is %@, not AAC", track.codec ?: @"unknown"];
        return NULL;
    }

    AudioStreamBasicDescription description = {0};
    description.mSampleRate = track.sampleRate;
    description.mFormatID = kAudioFormatMPEG4AAC;
    description.mChannelsPerFrame = track.channels ?: 2;
    description.mFramesPerPacket = 1024;

    CMFormatDescriptionRef format = NULL;
    if (CMAudioFormatDescriptionCreate(kCFAllocatorDefault, &description, 0, NULL,
                                       track.audioConfig.length, track.audioConfig.bytes,
                                       NULL, &format) != noErr) {
        if (failure) *failure = @"the sound description was refused";
        return NULL;
    }
    return format;
}

/// Writes the tracks given, interleaved, and calls back with the finished file.
///
/// **Both inputs are fed from the writer's own requests, not one after the other.** Feeding all
/// of the video and then all of the sound waits, on a long file, for room the writer will not
/// make until the other track has caught up -- a deadlock that looks like a download stuck at
/// ninety per cent. `requestMediaDataWhenReady` lets each side take what the writer asks for.
+ (void)writeVideo:(SCIFTrack *)video
             audio:(SCIFTrack *)audio
          fileType:(AVFileType)fileType
         extension:(NSString *)extension
        completion:(void (^)(NSURL *, NSString *))completion {

    void (^finish)(NSURL *, NSString *) = ^(NSURL *output, NSString *failure) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(output, failure); });
    };

    NSString *failure = nil;
    CMFormatDescriptionRef videoFormat = video ? [self videoFormat:video failure:&failure] : NULL;
    if (video && !videoFormat) { finish(nil, failure); return; }

    CMFormatDescriptionRef audioFormat = audio ? [self audioFormat:audio failure:&failure] : NULL;
    if (audio && !audioFormat) {
        if (videoFormat) CFRelease(videoFormat);
        finish(nil, failure);
        return;
    }

    NSURL *output = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:
        [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:extension]]];

    NSError *error = nil;
    AVAssetWriter *writer = [AVAssetWriter assetWriterWithURL:output fileType:fileType error:&error];
    if (!writer) {
        if (videoFormat) CFRelease(videoFormat);
        if (audioFormat) CFRelease(audioFormat);
        finish(nil, SCILocalized(@"dl_direct_write_failed"));
        return;
    }

    AVAssetWriterInput *videoInput = nil, *audioInput = nil;
    if (videoFormat) {
        videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                        outputSettings:nil sourceFormatHint:videoFormat];
        videoInput.expectsMediaDataInRealTime = NO;
        if ([writer canAddInput:videoInput]) [writer addInput:videoInput]; else videoInput = nil;
    }
    if (audioFormat) {
        audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio
                                                        outputSettings:nil sourceFormatHint:audioFormat];
        audioInput.expectsMediaDataInRealTime = NO;
        if ([writer canAddInput:audioInput]) [writer addInput:audioInput]; else audioInput = nil;
    }

    if ((videoFormat && !videoInput) || (audioFormat && !audioInput) || (!videoInput && !audioInput)) {
        if (videoFormat) CFRelease(videoFormat);
        if (audioFormat) CFRelease(audioFormat);
        finish(nil, SCILocalized(@"dl_direct_write_failed"));
        return;
    }

    writer.shouldOptimizeForNetworkUse = YES;   // index first, so it plays from a share sheet and Photos
    [writer startWriting];
    [writer startSessionAtSourceTime:kCMTimeZero];

    dispatch_group_t group = dispatch_group_create();
    __block BOOL broke = NO;

    // One pump per track. It keeps its place between requests, so the writer decides how much of
    // each side it wants at a time.
    void (^pump)(AVAssetWriterInput *, SCIFTrack *, CMFormatDescriptionRef, NSString *) =
        ^(AVAssetWriterInput *input, SCIFTrack *track, CMFormatDescriptionRef format, NSString *name) {
        if (!input) return;

        dispatch_group_enter(group);
        dispatch_queue_t queue = dispatch_queue_create(name.UTF8String, DISPATCH_QUEUE_SERIAL);
        const uint8_t *bytes = track.file.bytes;
        const SCIFSample *all = track.samples.bytes;
        NSUInteger total = [track count];
        __block NSUInteger next = 0;
        int32_t scale = (int32_t)track.timescale;

        [input requestMediaDataWhenReadyOnQueue:queue usingBlock:^{
            while (input.isReadyForMoreMediaData) {
                if (broke || writer.status != AVAssetWriterStatusWriting) {
                    [input markAsFinished];
                    dispatch_group_leave(group);
                    return;
                }
                if (next >= total) {
                    [input markAsFinished];
                    dispatch_group_leave(group);
                    return;
                }

                CMSampleBufferRef buffer = [self bufferFor:all[next] from:bytes format:format timescale:scale];
                next++;
                if (!buffer) { broke = YES; continue; }

                BOOL appended = [input appendSampleBuffer:buffer];
                CFRelease(buffer);
                if (!appended) broke = YES;
            }
        }];
    };

    pump(videoInput, video, videoFormat, @"com.albrhi.youtube.fragments.video");
    pump(audioInput, audio, audioFormat, @"com.albrhi.youtube.fragments.audio");

    dispatch_group_notify(group, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        if (broke) {
            [writer cancelWriting];
            if (videoFormat) CFRelease(videoFormat);
            if (audioFormat) CFRelease(audioFormat);
            [[NSFileManager defaultManager] removeItemAtURL:output error:nil];
            finish(nil, SCILocalized(@"dl_direct_write_failed"));
            return;
        }

        [writer finishWritingWithCompletionHandler:^{
            if (videoFormat) CFRelease(videoFormat);
            if (audioFormat) CFRelease(audioFormat);

            if (writer.status != AVAssetWriterStatusCompleted) {
                SCILogV(@"fragments: writer refused — %@", writer.error.localizedDescription);
                [SCIYTDiagnostics recordStreamAttempt:[@"direct: writer refused — "
                    stringByAppendingString:writer.error.localizedDescription ?: @"?"]];
                [[NSFileManager defaultManager] removeItemAtURL:output error:nil];
                finish(nil, SCILocalized(@"dl_direct_write_failed"));
                return;
            }

            // What came out, asked of the finished file. An ordinary .mp4 has no fragment tables
            // to misread, so this is the one place AVFoundation's answer can be believed -- and it
            // is set against what the source said it held.
            AVURLAsset *made = [AVURLAsset URLAssetWithURL:output options:nil];
            double wrote = CMTimeGetSeconds(made.duration);
            double claimed = MAX(video ? [video seconds] : 0, audio ? [audio seconds] : 0);
            [SCIYTDiagnostics recordStreamAttempt:[NSString stringWithFormat:
                @"direct: wrote %.1fs (sources say %.1fs) — video %lu frames, audio %lu packets%@",
                wrote, claimed, (unsigned long)[video count], (unsigned long)[audio count],
                (claimed > 0 && fabs(wrote - claimed) / claimed > 0.1) ? @" — LENGTH DISAGREES" : @""]];

            finish(output, nil);
        }];
    });
}

// MARK: - The two jobs

+ (void)mergeVideo:(NSURL *)videoURL
             audio:(NSURL *)audioURL
        completion:(void (^)(NSURL *, NSString *))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSString *why = nil;
        SCIFTrack *video = [self trackFromFile:videoURL failure:&why];
        if (!video) {
            [SCIYTDiagnostics recordStreamAttempt:[@"direct: video unreadable — " stringByAppendingString:why ?: @"?"]];
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, SCILocalized(@"dl_direct_unreadable")); });
            return;
        }
        SCIFTrack *audio = [self trackFromFile:audioURL failure:&why];
        if (!audio) {
            [SCIYTDiagnostics recordStreamAttempt:[@"direct: audio unreadable — " stringByAppendingString:why ?: @"?"]];
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, SCILocalized(@"dl_direct_unreadable")); });
            return;
        }

        [SCIYTDiagnostics recordStreamAttempt:[NSString stringWithFormat:
            @"direct: read video %@ %lu frames @%u, audio %@ %lu packets @%u",
            video.codec, (unsigned long)[video count], video.timescale,
            audio.codec, (unsigned long)[audio count], audio.timescale]];

        [self writeVideo:video audio:audio fileType:AVFileTypeMPEG4 extension:@"mp4" completion:completion];
    });
}

+ (void)rewriteAudio:(NSURL *)audioURL completion:(void (^)(NSURL *, NSString *))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSString *why = nil;
        SCIFTrack *audio = [self trackFromFile:audioURL failure:&why];
        if (!audio) {
            [SCIYTDiagnostics recordStreamAttempt:[@"direct: audio unreadable — " stringByAppendingString:why ?: @"?"]];
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, SCILocalized(@"dl_direct_unreadable")); });
            return;
        }

        [self writeVideo:nil audio:audio fileType:AVFileTypeAppleM4A extension:@"m4a" completion:completion];
    });
}

@end
