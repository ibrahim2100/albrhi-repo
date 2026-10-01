#import "SCIYTHLS.h"
#import "../../SCILog.h"
#import "../../Localization/SCILocalize.h"
#import "../../Diagnostics/SCIYTDiagnostics.h"
#import "SCIYTTransport.h"
#import "SCIYTParts.h"
#import "SCIYTDirect.h"
#import <AVFoundation/AVFoundation.h>

@implementation SCIHLSVariant

- (NSString *)label {
    NSString *size = self.height ? [NSString stringWithFormat:@"%ldp", (long)self.height]
                                 : SCILocalized(@"dl_unknown_quality");

    // The codec matters to the user only when it is the reason a quality is missing, so
    // it is not spelled out -- except for AV1, which is playable by *some* devices and not
    // others, and a person choosing 4K should see that it is the one that needs a capable player.
    if ([self.codecs.lowercaseString containsString:@"av01"]) return [size stringByAppendingString:@" · AV1"];
    return size;
}

@end


/// Only what iOS can put in an .mp4 without re-encoding.
///
/// The same rule the itag list follows on the other path, applied to what a playlist
/// declares instead: avc1 is H.264, mp4a is AAC. A variant in VP9 or Opus would download
/// perfectly and then be a file that will not play, which is worse than not offering it.
static BOOL SCICodecsArePlayable(NSString *codecs) {
    if (!codecs.length) return YES;   // unstated is not a reason to refuse

    NSString *lower = codecs.lowercaseString;
    if ([lower containsString:@"vp9"] || [lower containsString:@"vp09"]) return NO;
    if ([lower containsString:@"av01"]) return NO;
    if ([lower containsString:@"opus"]) return NO;
    return YES;
}

/// Whether the joined parts are bare AAC rather than a transport stream.
///
/// An audio rendition is not always wrapped. HLS allows "packed audio" — elementary AAC
/// frames, optionally with an ID3 tag in front and nothing else — and that is what this
/// build serves: twenty-six parts with no TS sync byte anywhere in them. They downloaded
/// perfectly and were then refused, because joining gives the file an .mp4 name and
/// AVFoundation believes the name.
///
/// So the bytes decide instead, and the fix is the name. iOS reads ADTS natively; it has
/// to, since this is the format every HLS radio stream on the platform is made of.
static BOOL SCIIsPackedAudio(NSURL *file) {
    NSData *head = [NSData dataWithContentsOfURL:file
                                         options:NSDataReadingMappedIfSafe
                                           error:nil];
    if (head.length < 10) return NO;

    const uint8_t *bytes = head.bytes;
    NSUInteger at = 0;

    // The ID3 tag, if there is one: 'ID3', two version bytes, flags, then a length in
    // four syncsafe bytes -- seven bits each, the top bit always clear so the length can
    // never be mistaken for a frame sync.
    if (bytes[0] == 'I' && bytes[1] == 'D' && bytes[2] == '3') {
        NSUInteger size = ((NSUInteger)(bytes[6] & 0x7F) << 21)
                        | ((NSUInteger)(bytes[7] & 0x7F) << 14)
                        | ((NSUInteger)(bytes[8] & 0x7F) << 7)
                        |  (NSUInteger)(bytes[9] & 0x7F);
        at = 10 + size;
    }

    if (at + 1 >= head.length) return NO;
    return bytes[at] == 0xFF && (bytes[at + 1] & 0xF0) == 0xF0;   // an ADTS frame header
}

/// Rewrites packed audio as a plain .aac file: the tags removed, the frames untouched.
///
/// 0.12.3 established the frames are all there and all correct -- 7867 of them, which at
/// 1024 samples each is 182.6 seconds, the exact length the video claims. It then handed
/// them to AVAssetWriter, and what came back had no audio track in it. That code path had
/// never once run before: until the sound was being fetched at all, nothing ever reached
/// it, so "the writer works" was an assumption and not a measurement.
///
/// This does not use it. ADTS is a format iOS reads directly -- every AAC radio stream on
/// the platform is exactly this -- and the only thing wrong with the joined file was the
/// twenty-six ID3 tags scattered through it, one where each part begins. Take those out
/// and what is left is an ordinary .aac file, read by Apple's own parser with nothing of
/// ours between it and the bytes.
///
/// Written through a file handle rather than gathered: three hours of audio is a couple of
/// hundred megabytes, and a phone should not be asked to hold it to copy it.
static NSURL *SCIStripPackedAudio(NSURL *file) {
    NSData *input = [NSData dataWithContentsOfURL:file
                                          options:NSDataReadingMappedIfSafe
                                            error:nil];
    if (!input.length) return nil;

    NSURL *clean = [[file URLByDeletingPathExtension] URLByAppendingPathExtension:@"aac"];
    [[NSFileManager defaultManager] createFileAtPath:clean.path contents:nil attributes:nil];

    NSFileHandle *handle = [NSFileHandle fileHandleForWritingToURL:clean error:nil];
    if (!handle) return nil;

    const uint8_t *bytes = input.bytes;
    NSUInteger length = input.length;
    NSUInteger at = 0;
    unsigned long long kept = 0;

    NSMutableData *batch = [NSMutableData dataWithCapacity:1 << 20];

    while (at + 7 <= length) {
        // A tag between two parts, stepped over whole. Validated on the syncsafe length
        // bytes as well as the three letters, so audio that happens to spell ID3 cannot
        // send this skipping over the rest of the track.
        if (bytes[at] == 'I' && bytes[at + 1] == 'D' && bytes[at + 2] == '3' &&
            at + 10 <= length &&
            !(bytes[at + 6] & 0x80) && !(bytes[at + 7] & 0x80) &&
            !(bytes[at + 8] & 0x80) && !(bytes[at + 9] & 0x80)) {

            NSUInteger size = ((NSUInteger)bytes[at + 6] << 21)
                            | ((NSUInteger)bytes[at + 7] << 14)
                            | ((NSUInteger)bytes[at + 8] << 7)
                            |  (NSUInteger)bytes[at + 9];
            at += 10 + size;
            continue;
        }

        if (!(bytes[at] == 0xFF && (bytes[at + 1] & 0xF0) == 0xF0)) { at++; continue; }

        NSUInteger frame = ((NSUInteger)(bytes[at + 3] & 0x03) << 11)
                         | ((NSUInteger)bytes[at + 4] << 3)
                         | ((NSUInteger)(bytes[at + 5] & 0xE0) >> 5);
        if (frame < 7 || at + frame > length) break;

        // The header goes with it, unlike the transport path which strips it: a .aac file
        // *is* its headers, one before every frame.
        [batch appendBytes:bytes + at length:frame];
        at += frame;
        kept++;

        if (batch.length >= (1 << 20)) {
            @try { [handle writeData:batch]; } @catch (NSException *e) { break; }
            [batch setLength:0];
        }
    }

    if (batch.length) {
        @try { [handle writeData:batch]; } @catch (NSException *e) {}
    }
    [handle closeFile];

    if (!kept) {
        [[NSFileManager defaultManager] removeItemAtURL:clean error:nil];
        return nil;
    }

    SCILogV(@"hls: %llu ADTS frames kept, tags removed", kept);
    return clean;
}

/// The value of one attribute in an EXT-X line.
static NSString *SCIAttribute(NSString *line, NSString *name) {
    NSRange found = [line rangeOfString:[name stringByAppendingString:@"="]];
    if (found.location == NSNotFound) return nil;

    NSString *rest = [line substringFromIndex:NSMaxRange(found)];
    if ([rest hasPrefix:@"\""]) {
        rest = [rest substringFromIndex:1];
        NSRange close = [rest rangeOfString:@"\""];
        return close.location == NSNotFound ? rest : [rest substringToIndex:close.location];
    }

    NSRange comma = [rest rangeOfString:@","];
    return comma.location == NSNotFound ? rest : [rest substringToIndex:comma.location];
}


@implementation SCIYTHLS

/// What the last playlist turned out to be.
///
/// Kept so the failure can say it. "The pieces do not join" fits all three shapes a
/// playlist can have and distinguishes none of them, and the report that did carry the
/// distinction was being cleared mid-download by YouTube re-announcing the video.
static NSString *sciLastShape = nil;

/// A failure sentence with the playlist's shape under it.
static NSString *SCIWithShape(NSString *message) {
    return [NSString stringWithFormat:@"%@\n\n%@", message ?: @"", sciLastShape ?: @"?"];
}

+ (NSURLSession *)session {
    static NSURLSession *session = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSURLSessionConfiguration *config =
            [NSURLSessionConfiguration ephemeralSessionConfiguration];
        config.timeoutIntervalForRequest = 20;
        config.timeoutIntervalForResource = 60 * 30;
        session = [NSURLSession sessionWithConfiguration:config];
    });
    return session;
}

+ (void)fetchText:(NSString *)address completion:(void (^)(NSString *, NSString *))completion {
    NSURL *url = [NSURL URLWithString:address];
    if (!url) {
        completion(nil, SCILocalized(@"dl_failed"));
        return;
    }

    [[[self session] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || !data) {
            completion(nil, error.localizedDescription ?: SCILocalized(@"dl_failed"));
            return;
        }

        NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]]
            ? [(NSHTTPURLResponse *)response statusCode] : 200;
        if (status != 200) {
            completion(nil, [NSString stringWithFormat:@"HTTP %ld", (long)status]);
            return;
        }

        NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        completion(text, text.length ? nil : SCILocalized(@"dl_failed"));
    }] resume];
}

// MARK: - The master playlist

+ (void)variantsForManifest:(NSString *)manifestURL
                 completion:(void (^)(NSArray<SCIHLSVariant *> *, NSString *))completion {
    if (!manifestURL.length) {
        completion(@[], SCILocalized(@"dl_hls_none"));
        return;
    }

    [self fetchText:manifestURL completion:^(NSString *text, NSString *failure) {
        if (!text) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(@[], failure); });
            return;
        }

        NSMutableArray<SCIHLSVariant *> *variants = [NSMutableArray array];
        NSArray<NSString *> *lines = [text componentsSeparatedByCharactersInSet:
            [NSCharacterSet newlineCharacterSet]];

        // The audio groups first, because a variant refers to one by name and the
        // reference can appear before the group is declared.
        //
        // This is the whole of the silent-download bug. A manifest may keep the sound in
        // its own renditions and leave the video segments without any, and the variant
        // line still advertises mp4a -- CODECS describes the presentation, not the parts.
        // 0.11.0 read only EXT-X-STREAM-INF, so those renditions were never fetched and
        // every download was a picture with nothing under it.
        NSMutableDictionary<NSString *, NSString *> *audioGroups = [NSMutableDictionary dictionary];
        for (NSString *raw in lines) {
            NSString *line = [raw stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceCharacterSet]];
            if (![line hasPrefix:@"#EXT-X-MEDIA"]) continue;
            if (![SCIAttribute(line, @"TYPE") isEqualToString:@"AUDIO"]) continue;

            NSString *group = SCIAttribute(line, @"GROUP-ID");
            NSString *uri = SCIAttribute(line, @"URI");
            if (!group.length || !uri.length) continue;

            // A group can hold several languages. The one marked DEFAULT wins; failing
            // that the first, which is the order the manifest itself considers best.
            BOOL isDefault = [SCIAttribute(line, @"DEFAULT") isEqualToString:@"YES"];
            if (audioGroups[group] && !isDefault) continue;

            audioGroups[group] = [[NSURL URLWithString:uri
                                         relativeToURL:[NSURL URLWithString:manifestURL]]
                                  absoluteString] ?: uri;
        }

        // An EXT-X-STREAM-INF line describes the next non-comment line, which is the URL.
        for (NSUInteger i = 0; i < lines.count; i++) {
            NSString *line = [lines[i] stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceCharacterSet]];
            if (![line hasPrefix:@"#EXT-X-STREAM-INF"]) continue;

            NSString *address = nil;
            for (NSUInteger j = i + 1; j < lines.count; j++) {
                NSString *candidate = [lines[j] stringByTrimmingCharactersInSet:
                    [NSCharacterSet whitespaceCharacterSet]];
                if (!candidate.length || [candidate hasPrefix:@"#"]) continue;
                address = candidate;
                break;
            }
            if (!address.length) continue;

            NSString *codecs = SCIAttribute(line, @"CODECS");
            if (!SCICodecsArePlayable(codecs)) continue;

            SCIHLSVariant *variant = [[SCIHLSVariant alloc] init];
            variant.playlistURL = [[NSURL URLWithString:address
                                          relativeToURL:[NSURL URLWithString:manifestURL]]
                                   absoluteString] ?: address;
            variant.codecs = codecs;
            variant.bandwidth = [SCIAttribute(line, @"BANDWIDTH") longLongValue];

            NSString *group = SCIAttribute(line, @"AUDIO");
            if (group.length) variant.audioPlaylistURL = audioGroups[group];

            NSString *resolution = SCIAttribute(line, @"RESOLUTION");
            NSArray<NSString *> *parts = [resolution componentsSeparatedByString:@"x"];
            if (parts.count == 2) {
                variant.width = [parts[0] integerValue];
                variant.height = [parts[1] integerValue];
            }

            [variants addObject:variant];
        }

        [variants sortUsingComparator:^NSComparisonResult(SCIHLSVariant *a, SCIHLSVariant *b) {
            if (a.height != b.height) return a.height > b.height ? NSOrderedAscending : NSOrderedDescending;
            return a.bandwidth > b.bandwidth ? NSOrderedAscending : NSOrderedDescending;
        }];

        NSUInteger separate = 0;
        for (SCIHLSVariant *variant in variants) {
            if (variant.audioPlaylistURL.length) separate++;
        }

        SCILogV(@"hls: %lu playable variants, %lu with separate audio",
                (unsigned long)variants.count, (unsigned long)separate);

        // In the report, because this is the difference between a download with sound and
        // one without, and it is not visible anywhere else.
        [SCIYTDiagnostics recordStreamAttempt:
            [NSString stringWithFormat:@"hls: %lu variants, %lu audio groups, %lu variants use one",
                (unsigned long)variants.count, (unsigned long)audioGroups.count,
                (unsigned long)separate]];

        dispatch_async(dispatch_get_main_queue(), ^{
            completion(variants, variants.count ? nil : SCILocalized(@"dl_hls_no_variants"));
        });
    }];
}

// MARK: - One quality

+ (void)downloadVariant:(SCIHLSVariant *)variant
               progress:(void (^)(double))progress
             completion:(void (^)(NSURL *, NSString *))completion {

    if (variant.directVideoURL.length) {
        [SCIYTDirect downloadVariant:variant progress:progress completion:completion];
        return;
    }

    NSString *audioPlaylist = variant.audioPlaylistURL;

    // The pictures first, and that is the whole download when the variant carries its own
    // sound. When it does not, the video is the first nine tenths of the bar: an audio
    // rendition is a small fraction of the size, and a bar that drops back to zero
    // halfway through reads as a failure to whoever is watching it.
    [self downloadPlaylist:variant.playlistURL
                  progress:^(double fraction) {
                      if (progress) progress(audioPlaylist.length ? fraction * 0.9 : fraction);
                  }
                completion:^(NSURL *video, NSString *failure) {
        if (!video || !audioPlaylist.length) {
            completion(video, failure);
            return;
        }

        [self downloadPlaylist:audioPlaylist
                      progress:^(double fraction) {
                          if (progress) progress(0.9 + fraction * 0.1);
                      }
                    completion:^(NSURL *audio, NSString *audioFailure) {
            if (!audio) {
                // The video was fetched and is fine. Throwing it away to report that its
                // sound was not would be the worse of the two outcomes -- but it goes in
                // the report, because a silent file with nothing said about it is the
                // exact failure this release exists to end.
                SCILogV(@"hls: audio rendition failed — %@", audioFailure);
                [SCIYTDiagnostics recordStreamAttempt:
                    [@"hls: audio rendition failed — " stringByAppendingString:
                        audioFailure ?: @"?"]];
                completion(video, nil);
                return;
            }

            [self combineVideo:video audio:audio completion:completion];
        }];
    }];
}

+ (void)downloadAudioFor:(SCIHLSVariant *)variant
                progress:(void (^)(double))progress
              completion:(void (^)(NSURL *, NSString *))completion {

    if (variant.directAudioURL.length) {
        [SCIYTDirect downloadAudioFor:variant progress:progress completion:completion];
        return;
    }

    // The whole saving of this route: when the soundtrack is its own playlist, asking
    // for sound means downloading a few megabytes instead of a few hundred. The pictures
    // are never fetched.
    if (variant.audioPlaylistURL.length) {
        [self downloadPlaylist:variant.audioPlaylistURL progress:progress completion:completion];
        return;
    }

    // Otherwise there is nothing to fetch on its own, and the sound has to be taken out
    // of the finished video. The download is the long part, so it gets the bar.
    [self downloadVariant:variant
                 progress:^(double fraction) { if (progress) progress(fraction * 0.95); }
               completion:^(NSURL *file, NSString *failure) {
        if (!file) { completion(nil, failure); return; }
        [self stripPictures:file completion:completion];
    }];
}

/// Keeps the sound of a finished video and throws the pictures away.
+ (void)stripPictures:(NSURL *)file completion:(void (^)(NSURL *, NSString *))completion {
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:file options:nil];

    [asset loadValuesAsynchronouslyForKeys:@[@"tracks", @"duration"] completionHandler:^{
        AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeAudio].firstObject;
        if (!track) {
            [[NSFileManager defaultManager] removeItemAtURL:file error:nil];
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, SCILocalized(@"dl_no_audio_track"));
            });
            return;
        }

        AVMutableComposition *composition = [AVMutableComposition composition];
        AVMutableCompositionTrack *sound =
            [composition addMutableTrackWithMediaType:AVMediaTypeAudio
                                     preferredTrackID:kCMPersistentTrackID_Invalid];

        CMTime length = CMTIME_IS_NUMERIC(asset.duration) ? asset.duration : track.timeRange.duration;
        NSError *error = nil;

        if (![sound insertTimeRange:CMTimeRangeMake(kCMTimeZero, length)
                            ofTrack:track atTime:kCMTimeZero error:&error]) {
            [[NSFileManager defaultManager] removeItemAtURL:file error:nil];
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error.localizedDescription ?: SCILocalized(@"dl_failed"));
            });
            return;
        }

        NSURL *output = [NSURL fileURLWithPath:
            [NSTemporaryDirectory() stringByAppendingPathComponent:
                [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"m4a"]]];

        AVAssetExportSession *export =
            [[AVAssetExportSession alloc] initWithAsset:composition
                                             presetName:AVAssetExportPresetPassthrough];
        export.outputURL = output;
        export.outputFileType = AVFileTypeAppleM4A;

        [export exportAsynchronouslyWithCompletionHandler:^{
            [[NSFileManager defaultManager] removeItemAtURL:file error:nil];

            BOOL ok = (export.status == AVAssetExportSessionStatusCompleted);
            if (!ok) [[NSFileManager defaultManager] removeItemAtURL:output error:nil];

            dispatch_async(dispatch_get_main_queue(), ^{
                completion(ok ? output : nil, ok ? nil : SCILocalized(@"dl_failed"));
            });
        }];
    }];
}

/// Joins a video file and an audio file into one, without re-encoding either.
///
/// A composition of two tracks exported passthrough: the samples are copied, and the only
/// thing produced is a new index. The sound is trimmed to the length of the picture --
/// renditions routinely run a fraction of a second longer, and a composition is as long
/// as its longest track, which would end the video on a frozen last frame.
+ (void)combineVideo:(NSURL *)video
               audio:(NSURL *)audio
          completion:(void (^)(NSURL *, NSString *))completion {

    void (^finish)(NSURL *) = ^(NSURL *file) {
        [[NSFileManager defaultManager] removeItemAtURL:audio error:nil];
        dispatch_async(dispatch_get_main_queue(), ^{ completion(file, nil); });
    };

    AVURLAsset *videoAsset = [AVURLAsset URLAssetWithURL:video options:nil];
    AVURLAsset *audioAsset = [AVURLAsset URLAssetWithURL:audio options:nil];

    // Both files are made to say how long they are before anything is asked of them.
    //
    // A raw AAC file has no index in it. AVFoundation cannot know its length without
    // reading the whole thing, and until it has, the track's timeRange is not a number --
    // it is an invalid CMTime that arithmetic quietly propagates. A range built from that
    // is what "the operation could not be completed" was: a refusal with nothing wrong in
    // the media at all, only in a length nobody had waited for.
    dispatch_group_t loading = dispatch_group_create();
    for (AVURLAsset *asset in @[videoAsset, audioAsset]) {
        dispatch_group_enter(loading);
        [asset loadValuesAsynchronouslyForKeys:@[@"tracks", @"duration"]
                             completionHandler:^{ dispatch_group_leave(loading); }];
    }

    dispatch_group_notify(loading, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
    AVAssetTrack *videoTrack = [videoAsset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    AVAssetTrack *audioTrack = [audioAsset tracksWithMediaType:AVMediaTypeAudio].firstObject;

    // Whatever was actually obtained, rather than nothing. Every return below that hands
    // back `video` is a download that succeeded and lost its sound at the last step.
    // Every way this can fail is recorded, not only logged.
    //
    // It used to be logged, and that cost a round: the join was the one step between a
    // soundtrack that had downloaded and a video that came out silent, and the report said
    // nothing about it at all. A step that can drop the sound has to say when it does.
    if (!videoTrack || !audioTrack) {
        [SCIYTDiagnostics recordStreamAttempt:
            [NSString stringWithFormat:@"hls: nothing to join — video %@, audio %@",
                videoTrack ? @"yes" : @"no", audioTrack ? @"yes" : @"no"]];
        finish(video);
        return;
    }

    // The asset's own duration first, the track's as a fallback: for a stream with no
    // index the two are not always both known, and either one alone is enough.
    CMTime (^usable)(CMTime, CMTime) = ^CMTime(CMTime first, CMTime second) {
        if (CMTIME_IS_NUMERIC(first) && CMTimeCompare(first, kCMTimeZero) > 0) return first;
        return second;
    };

    CMTime length = usable(videoAsset.duration, videoTrack.timeRange.duration);
    CMTime sung   = usable(audioAsset.duration, audioTrack.timeRange.duration);

    if (!CMTIME_IS_NUMERIC(length) || CMTimeCompare(length, kCMTimeZero) <= 0) {
        [SCIYTDiagnostics recordStreamAttempt:@"hls: the video will not say how long it is"];
        finish(video);
        return;
    }
    if (!CMTIME_IS_NUMERIC(sung) || CMTimeCompare(sung, kCMTimeZero) <= 0) sung = length;

    AVMutableComposition *composition = [AVMutableComposition composition];
    AVMutableCompositionTrack *pictures =
        [composition addMutableTrackWithMediaType:AVMediaTypeVideo
                                 preferredTrackID:kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *sound =
        [composition addMutableTrackWithMediaType:AVMediaTypeAudio
                                 preferredTrackID:kCMPersistentTrackID_Invalid];

    NSError *error = nil;

    // Separately, and each says which one it was. One generic refusal covering both sides
    // is what sent the last round looking at the wrong track.
    if (![pictures insertTimeRange:CMTimeRangeMake(kCMTimeZero, length)
                           ofTrack:videoTrack atTime:kCMTimeZero error:&error]) {
        [SCIYTDiagnostics recordStreamAttempt:[NSString stringWithFormat:
            @"hls: pictures refused (%.1fs) — %@", CMTimeGetSeconds(length),
            error.localizedDescription ?: @"?"]];
        finish(video);
        return;
    }

    if (![sound insertTimeRange:CMTimeRangeMake(kCMTimeZero, CMTimeMinimum(length, sung))
                        ofTrack:audioTrack atTime:kCMTimeZero error:&error]) {
        [SCIYTDiagnostics recordStreamAttempt:[NSString stringWithFormat:
            @"hls: sound refused (%.1fs of %.1fs) — %@",
            CMTimeGetSeconds(sung), CMTimeGetSeconds(length),
            error.localizedDescription ?: @"?"]];
        finish(video);
        return;
    }

    NSURL *output = [NSURL fileURLWithPath:
        [NSTemporaryDirectory() stringByAppendingPathComponent:
            [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"mp4"]]];

    AVAssetExportSession *export =
        [[AVAssetExportSession alloc] initWithAsset:composition
                                         presetName:AVAssetExportPresetPassthrough];
    export.outputURL = output;
    export.outputFileType = AVFileTypeMPEG4;

    [export exportAsynchronouslyWithCompletionHandler:^{
        if (export.status == AVAssetExportSessionStatusCompleted) {
            [[NSFileManager defaultManager] removeItemAtURL:video error:nil];
            finish(output);
        } else {
            [SCIYTDiagnostics recordStreamAttempt:
                [@"hls: join failed — " stringByAppendingString:
                    export.error.localizedDescription ?: @"?"]];
            [[NSFileManager defaultManager] removeItemAtURL:output error:nil];
            finish(video);
        }
    }];
    });
}

/// Fetches one playlist -- video or audio, the shapes are the same -- as an .mp4.
+ (void)downloadPlaylist:(NSString *)playlistURL
                progress:(void (^)(double))progress
              completion:(void (^)(NSURL *, NSString *))completion {

    void (^finish)(NSURL *, NSString *) = ^(NSURL *file, NSString *failure) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(file, failure); });
    };

    [self fetchText:playlistURL completion:^(NSString *text, NSString *failure) {
        if (!text) {
            finish(nil, failure);
            return;
        }

        NSMutableArray<NSString *> *segments = [NSMutableArray array];
        NSString *initSegment = nil;
        BOOL byteRanged = NO;
        NSURL *base = [NSURL URLWithString:playlistURL];

        for (NSString *raw in [text componentsSeparatedByCharactersInSet:
                               [NSCharacterSet newlineCharacterSet]]) {
            NSString *line = [raw stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceCharacterSet]];
            if (!line.length) continue;

            if ([line hasPrefix:@"#EXT-X-MAP"]) {
                // Fragmented MP4. The initialisation segment carries the headers every
                // following part needs, and its presence is what decides whether joining
                // the parts produces something readable at all.
                NSString *uri = SCIAttribute(line, @"URI");
                if (uri.length) {
                    initSegment = [[NSURL URLWithString:uri relativeToURL:base] absoluteString];
                }
                continue;
            }

            if ([line hasPrefix:@"#EXT-X-BYTERANGE"]) {
                // Every "segment" is a slice of one file rather than a file of its own.
                //
                // This line was skipped along with every other tag, which is why 0.10.1
                // downloaded something unusable: the parser saw the same URL repeated
                // once per slice and fetched the *whole file* each time, then joined the
                // copies end to end. Hundreds of megabytes, and of course nothing could
                // read it.
                byteRanged = YES;
                continue;
            }

            if ([line hasPrefix:@"#"]) continue;

            NSString *resolved = [[NSURL URLWithString:line relativeToURL:base] absoluteString];
            if (resolved.length) [segments addObject:resolved];
        }

        if (!segments.count) {
            finish(nil, SCILocalized(@"dl_hls_no_segments"));
            return;
        }

        // What the playlist actually turned out to be, in the report. 0.10.1 said only
        // that the pieces would not join, which is a symptom and names none of the three
        // shapes a playlist can have.
        NSCountedSet *distinct = [NSCountedSet setWithArray:segments];

        // The last part of the first address, which is what says whether these are
        // MPEG-TS parts or fragmented MP4 -- the one thing that decides whether joining
        // them can work at all.
        NSString *shape = [NSString stringWithFormat:@"%lu entries, %lu URLs%@%@, ends %@",
            (unsigned long)segments.count, (unsigned long)distinct.count,
            byteRanged ? @", ranges" : @"",
            initSegment ? @", fMP4 init" : @", no init",
            [[segments.firstObject componentsSeparatedByString:@"/"] lastObject] ?: @"?"];

        sciLastShape = [shape copy];
        [SCIYTDiagnostics recordStreamAttempt:[@"hls: " stringByAppendingString:shape]];

        // One file addressed by ranges: the whole of it is the media, so it is fetched
        // once instead of once per slice. This is both the fix for the previous release
        // and the simplest possible case -- a complete file, already muxed, no joining.
        if (distinct.count == 1 && segments.count > 1) {
            SCILogV(@"hls: %lu ranges over one file — fetching it whole",
                    (unsigned long)segments.count);
            [self joinSegments:@[segments.firstObject]
                   initSegment:nil
                      progress:progress
                    completion:finish];
            return;
        }

        // Said plainly rather than attempted and left half-done. Joined MPEG-TS parts are
        // not a file AVFoundation will export, and producing a broken video would be
        // worse than saying which format this build serves.
        if (!initSegment) {
            SCILogV(@"hls: no EXT-X-MAP, segments are probably MPEG-TS");
        }

        SCILogV(@"hls: %lu segments%@", (unsigned long)segments.count,
                initSegment ? @", fragmented MP4" : @", no init segment");

        [self joinSegments:segments
               initSegment:initSegment
                  progress:progress
                completion:finish];
    }];
}

/// Fetches every part in order and appends it to one file.
///
/// Sequentially, and to a file handle rather than into memory: the parts of a 1080p video
/// come to a couple of hundred megabytes, and a phone should not be asked to hold that
/// twice. Sequential also keeps the order right without any reassembly step, which is the
/// entire reason this produces a playable file at the end.
+ (void)joinSegments:(NSArray<NSString *> *)segments
         initSegment:(NSString *)initSegment
            progress:(void (^)(double))progress
          completion:(void (^)(NSURL *, NSString *))completion {

    NSMutableArray<NSString *> *addresses = [NSMutableArray array];
    if (initSegment) [addresses addObject:initSegment];
    [addresses addObjectsFromArray:segments];

    // Fetched several at a time, and joined by index afterwards.
    //
    // This was one part at a time appended to a single handle, and correct for exactly that
    // reason: sequential arrival meant sequential order, with nothing to reassemble. It was
    // also ninety round trips end to end, and on a phone the latency rather than the
    // bandwidth is most of that wait.
    //
    // SCIYTParts keeps the ordering guarantee without the queue -- each part's slot is
    // decided before its request is made, so nothing about arrival order can reach the file.
    // Its header sets out why that distinction earns a class of its own.
    [SCIYTParts fetch:addresses
             progress:progress
           completion:^(NSArray<NSURL *> *ordered, NSURL *folder, NSString *error) {
        if (!ordered.count) {
            completion(nil, error ?: SCILocalized(@"dl_failed"));
            return;
        }

        // Named .mp4 whatever is inside it, exactly as before: the next step reads the bytes
        // rather than the name, and renames the file if it turns out to be something else.
        NSURL *joined = [SCIYTParts join:ordered extension:@"mp4" folder:folder];
        if (!joined) {
            completion(nil, SCILocalized(@"dl_ts_write_failed"));
            return;
        }

        [self exportJoined:joined completion:completion];
    }];
}

/// Rewrites the joined parts as a normal .mp4.
///
/// A passthrough export: both tracks are already H.264 and AAC, which the variant filter
/// guaranteed, so nothing is re-encoded and this is a remux. It is also the step that
/// says whether the joining worked -- an unreadable file fails here rather than arriving
/// in Photos as something that will not play.
+ (void)exportJoined:(NSURL *)joined completion:(void (^)(NSURL *, NSString *))completion {
    // A transport stream never reaches the export below, because it cannot: iOS has no
    // reader for a local .ts, so AVURLAsset reports no video track and the file is thrown
    // away as unreadable. That was the whole of the "the pieces do not join" failure --
    // ninety-four parts fetched perfectly and then discarded at the last step for being in
    // the wrong wrapper. SCIYTTransport unwraps them; from there this is an ordinary file.
    if ([SCIYTTransport isTransportStream:joined]) {
        [SCIYTTransport convert:joined completion:^(NSURL *output, NSString *error) {
            [[NSFileManager defaultManager] removeItemAtURL:joined error:nil];
            completion(output, output ? nil : SCIWithShape(error ?: SCILocalized(@"dl_hls_unreadable")));
        }];
        return;
    }

    // Read rather than renamed. 0.12.2 gave this file an .aac name and handed it to
    // AVFoundation, on the reasoning that the bytes were already what an .aac file holds.
    // The bytes are -- but twenty-six ID3 tags sit *inside* the joined file, one where
    // each part begins, and a reader is entitled to make nothing of that. It made nothing
    // of it silently, which is the same silence this began with.
    //
    // So the frames come out here, by the parser that already pulls the identical frames
    // out of transport packets. Nothing about them is unusual; only the wrapper was.
    if (SCIIsPackedAudio(joined)) {
        NSURL *clean = SCIStripPackedAudio(joined);
        if (clean) {
            NSUInteger tracks = [[AVURLAsset URLAssetWithURL:clean options:nil]
                                    tracksWithMediaType:AVMediaTypeAudio].count;
            [SCIYTDiagnostics recordStreamAttempt:[NSString stringWithFormat:
                @"hls: packed audio → adts, %lu track(s)", (unsigned long)tracks]];

            if (tracks) {
                [[NSFileManager defaultManager] removeItemAtURL:joined error:nil];
                completion(clean, nil);
                return;
            }
            [[NSFileManager defaultManager] removeItemAtURL:clean error:nil];
        }

        // Unwrapping the frames ourselves, if Apple's reader will not have them plain.
        // Kept as a second route rather than the first: it builds the track through code
        // that no download had ever exercised, and this one leans on the parser iOS uses
        // for AAC every day.
        [SCIYTTransport convert:joined completion:^(NSURL *output, NSString *error) {
            [[NSFileManager defaultManager] removeItemAtURL:joined error:nil];

            if (output) {
                NSUInteger tracks = [[AVURLAsset URLAssetWithURL:output options:nil]
                                        tracksWithMediaType:AVMediaTypeAudio].count;
                [SCIYTDiagnostics recordStreamAttempt:[NSString stringWithFormat:
                    @"hls: converted audio, %lu track(s)", (unsigned long)tracks]];
            }

            completion(output, output ? nil : SCIWithShape(error ?: SCILocalized(@"dl_hls_unreadable")));
        }];
        return;
    }

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:joined options:nil];

    // Either track is enough. An audio rendition has no pictures in it and demanding
    // some was the reason a separately-carried soundtrack could not be fetched at all.
    if (![asset tracksWithMediaType:AVMediaTypeVideo].count &&
        ![asset tracksWithMediaType:AVMediaTypeAudio].count) {

        // The first bytes, in the report. "Unreadable" names no format and the next
        // attempt would begin by guessing which one arrived -- which is how the last two
        // rounds were spent.
        NSData *head = [NSData dataWithContentsOfURL:joined options:NSDataReadingMappedIfSafe
                                               error:nil];
        const uint8_t *bytes = head.bytes;
        if (head.length >= 4) {
            [SCIYTDiagnostics recordStreamAttempt:
                [NSString stringWithFormat:@"hls: unreadable, starts %02X %02X %02X %02X",
                    bytes[0], bytes[1], bytes[2], bytes[3]]];
        }

        [[NSFileManager defaultManager] removeItemAtURL:joined error:nil];
        completion(nil, SCIWithShape(SCILocalized(@"dl_hls_unreadable")));
        return;
    }

    // An audio rendition is handed back as it is. It goes into a composition next, which
    // reads it directly, and rewrapping it first would only add a step that can refuse.
    if (![asset tracksWithMediaType:AVMediaTypeVideo].count) {
        completion(joined, nil);
        return;
    }

    NSURL *output = [NSURL fileURLWithPath:
        [NSTemporaryDirectory() stringByAppendingPathComponent:
            [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"mp4"]]];

    AVAssetExportSession *export =
        [[AVAssetExportSession alloc] initWithAsset:asset
                                         presetName:AVAssetExportPresetPassthrough];
    export.outputURL = output;
    export.outputFileType = AVFileTypeMPEG4;

    [export exportAsynchronouslyWithCompletionHandler:^{
        [[NSFileManager defaultManager] removeItemAtURL:joined error:nil];

        if (export.status == AVAssetExportSessionStatusCompleted) {
            completion(output, nil);
        } else {
            SCILogV(@"hls: export failed — %@", export.error.localizedDescription);

            // The shape, in the message. Whoever reports this should not have to open a
            // second screen to say which of three completely different problems it was.
            completion(nil, SCIWithShape(SCILocalized(@"dl_hls_unreadable")));
        }
    }];
}

@end
