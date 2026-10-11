#import "SCITTDownload.h"
#import "../../Localization/SCILocalize.h"
#import "../../SCILog.h"
#import <ImageIO/ImageIO.h>
#import "../../UI/SCITTToast.h"
#import "../../UI/SCITTSheet.h"
#import "SCITTStillVideo.h"
#import "../../Prefs.h"
#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>

@interface SCITTDownload () <NSURLSessionDownloadDelegate>
@property (nonatomic, strong) SCITTMediaItem *item;
@property (nonatomic, strong) NSURLSession *session;

/// Which of `item.candidates` is being fetched, and what the ones already tried
/// turned out to be -- so a give-up message can name every link it rejected rather
/// than only the last.
@property (nonatomic, assign) NSUInteger candidateIndex;
@property (nonatomic, strong) NSMutableArray<NSString *> *rejected;
@end

/// Kept alive by hand while it runs -- an NSURLSession retains its delegate, but
/// nothing retains the object here, so without this it is released the moment +save:
/// returns and the download stops with no error and no callback. Locket's and X's own
/// downloaders keep the same set for the same reason.
static NSMutableSet<SCITTDownload *> *_running = nil;

/// What the last save attempt actually did, in the words of whatever refused it.
///
/// "Couldn't save it" on a HUD is all a user needs and nothing a fix can be built
/// from: an HTTP 403 on the resolved link, a Photos library that will not decode the
/// file, and a zero-byte download that answered 200 all look identical from there and
/// need entirely different fixes. Recorded here and shown on the status screen for
/// the same reason every other diagnostic in this tweak exists.
static NSString *sciLastDownloadState = nil;

/// When it happened, and how long the process has been running.
///
/// **A stale record read as a fresh one cost three releases of misdiagnosis.** This line
/// carried the identical byte count and media id across v0.7.0, v0.7.1 and v0.8.0 reports,
/// and every one of those was read as evidence that the newest chain had just saved audio --
/// when in fact no new attempt had been made at all, because the button was in the wrong
/// place to be tapped. Three fixes were aimed at a sentence that had not changed because
/// nothing had happened.
///
/// So the record says its own age. A line from a previous launch, or from minutes before the
/// current build was installed, is now impossible to mistake for the last thing that ran.
static NSDate *sciLastDownloadAt = nil;

void SCITTRecordDownload(NSString *state) {
    sciLastDownloadState = state;
    sciLastDownloadAt = [NSDate date];
    SCILogV(@"download: %@", state);
}

NSString *SCITTDownloadReport(void) {
    if (!sciLastDownloadState) return @"nothing saved yet this launch";

    NSTimeInterval ago = [[NSDate date] timeIntervalSinceDate:sciLastDownloadAt];
    return [NSString stringWithFormat:@"%@ (%.0fs ago)", sciLastDownloadState, ago];
}

@implementation SCITTDownload

/// Saves every picture of a photo post, in order.
///
/// Fetched on a background queue because +dataWithContentsOfURL: blocks until each picture
/// arrives, and a post can hold eight of them -- doing that on the main thread would freeze
/// the feed for the whole download.
///
/// **Each picture is imported in its own change block.** One block for all of them would make
/// a single failure discard the entire post, and a post where seven of eight arrived is worth
/// keeping the seven. The counter reports both numbers for the same reason: "saved 6 of 8" and
/// "saved nothing" are different problems.
/// The HUD for a photo-post save, held while the images go one at a time.

+ (void)askThenSavePhotos:(SCITTMediaItem *)item {
    NSArray<NSArray<NSURL *> *> *all = item.photoVariants;
    if (!all.count) return;

    NSUInteger index = (item.photoIndex < all.count) ? item.photoIndex : 0;
    NSArray<NSURL *> *current = all[index];

    // **One picture is still a question now, and that is the change.** It used to save immediately
    // whenever the post had a single image, because the only question then was "this one or all of
    // them" and there was nothing to choose between. There is now: the post's sound can be laid
    // over the picture and saved as a clip, which is a real choice about a one-picture post too.
    if (all.count < 2) {
        [self offerAudioForPicture:current item:item];
        return;
    }

    if (![SCITTSheet canPresent]) {
        // Nowhere to ask. Saving the one on screen is the conservative answer: a post of sixteen
        // arriving whole in Photos unasked is the complaint this exists to answer, and one more tap
        // gets the rest.
        [self savePhotos:@[current]];
        return;
    }

    NSString *allTitle = [NSString stringWithFormat:SCILocalized(@"photos_save_all"),
                          (unsigned long)all.count];

    [SCITTSheet showTitle:SCILocalized(@"photos_ask_title")
                  message:[NSString stringWithFormat:SCILocalized(@"photos_ask_message"),
                              (unsigned long)(index + 1), (unsigned long)all.count]
                   symbol:@"photo.stack"
                  actions:@[
        [SCITTSheetAction title:SCILocalized(@"photos_save_this")
                         symbol:@"photo"
                        primary:YES
                        handler:^{ [self offerAudioForPicture:current item:item]; }],
        [SCITTSheetAction title:allTitle
                         symbol:@"square.stack.3d.down.right"
                        primary:NO
                        handler:^{ [self savePhotos:all]; }],
    ]
                   cancel:SCILocalized(@"photos_cancel")];
}

///
/// **Every option read "0 seconds", and the cause is one this project has met twice before in
/// another form.** `%.0f` reads a `double` out of the argument list, and `5` written as a literal is
/// an `int` -- so the format read eight bytes where four had been pushed and printed whatever
/// followed. Nothing warns: a variadic argument has no declared type to check against. It is the
/// same family as the `objc_msgSend` casts that crashed the app, at a smaller scale: a value's type
/// at the call site has to match the type the callee will read, and a format string is a callee.
///
/// Offers the post's sound over one picture, and saves the picture plainly if the answer is no.
///
/// **The offer is only made when there is actually a sound to offer.** A question whose answers all
/// mean "save the picture" is not a question.
+ (void)offerAudioForPicture:(NSArray<NSURL *> *)picture item:(SCITTMediaItem *)item {
    if (!item.audioURL || !SCIPrefEnabled(SCIPrefPhotoAudio) || ![SCITTSheet canPresent]) {
        [self savePhotos:@[picture]];
        return;
    }

    [SCITTSheet showTitle:SCILocalized(@"audio_ask_title")
                  message:SCILocalized(@"audio_ask_message")
                   symbol:@"music.note"
                  actions:@[
        [SCITTSheetAction title:[NSString stringWithFormat:SCILocalized(@"audio_seconds"), (double)5]
                         symbol:nil primary:NO
                        handler:^{ [self saveClipFromPicture:picture item:item seconds:5]; }],
        [SCITTSheetAction title:[NSString stringWithFormat:SCILocalized(@"audio_seconds"), (double)10]
                         symbol:nil primary:YES
                        handler:^{ [self saveClipFromPicture:picture item:item seconds:10]; }],
        [SCITTSheetAction title:[NSString stringWithFormat:SCILocalized(@"audio_seconds"), (double)15]
                         symbol:nil primary:NO
                        handler:^{ [self saveClipFromPicture:picture item:item seconds:15]; }],
        [SCITTSheetAction title:SCILocalized(@"audio_picture_only")
                         symbol:@"photo" primary:NO
                        handler:^{ [self savePhotos:@[picture]]; }],
    ]
                   cancel:SCILocalized(@"photos_cancel")];
}

///
/// The measured byte length of a link, or 0 if it will not say.
///
/// A `HEAD` costs one round trip and answers the only question that has ever mattered here.
/// Every previous attempt at quality compared *names* -- which chain, which gear, which
/// accessor -- and a name is a claim about a file. `Content-Length` is the file.
///
/// Headers a plain `NSURLSession` request does not send.
///
/// The external HD service answered neither `HEAD` nor a range `GET` and measured 0.0 MB twice
/// over — while the same address works in a browser. NA9 sets request headers and installs a
/// redirect delegate for the same call, which is evidence rather than decoration: the service
/// declines a request that does not look like a browser. Applied to every measurement because
/// TikTok's own CDN does not mind, and a second code path for one host is a second thing to
/// get wrong.
static void SCITTAddBrowserHeaders(NSMutableURLRequest *request) {
    [request setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 16_1 like Mac OS X) AppleWebKit/605.1.15"
                       " (KHTML, like Gecko) Version/16.1 Mobile/15E148 Safari/604.1"
   forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"*/*" forHTTPHeaderField:@"Accept"];
}

///
/// Asks the external service for its HD link, or nil.
///
/// **`…/video/media/hdplay/<id>.mp4` is not an endpoint on its own** — it answers 400 for an id
/// the service has not been asked about, which is why the link measured 0.0 MB in two device
/// reports and why no `User-Agent` fixed it. The service is an API: one JSON request names the
/// links, and the shortcut only works afterwards. NA9 parses JSON for this call rather than
/// fetching a URL, which is the detail its binary was showing and I first read as decoration.
///
/// **Worth knowing before enabling it: for the video measured from a real report, `hd_size` was
/// 3,786,622 bytes — byte for byte the file this tweak already downloads internally.** The
/// external route is not a better file there; it is the same file fetched by a route that also
/// tells a third party what is being watched. Kept because it was asked for and because other
/// videos may differ, and it stays off by default.
static NSURL *SCITTExternalHDLink(NSString *identifier) {
    NSString *address = [NSString stringWithFormat:
        @"https://tikwm.com/api/?url=https://www.tiktok.com/@/video/%@&hd=1", identifier];

    NSURL *endpoint = [NSURL URLWithString:address];
    if (!endpoint) return nil;

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:endpoint];
    request.timeoutInterval = 12;
    SCITTAddBrowserHeaders(request);

    __block NSURL *resolved = nil;
    dispatch_semaphore_t wait = dispatch_semaphore_create(0);

    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
        dataTaskWithRequest:request
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (data.length) {
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            id payload = [json isKindOfClass:[NSDictionary class]] ? json[@"data"] : nil;

            if ([payload isKindOfClass:[NSDictionary class]]) {
                // `hdplay` first, then the plain copy: both are watermark-free there, and the
                // second is still better than nothing when a post has no HD variant at all.
                for (NSString *key in @[@"hdplay", @"play"]) {
                    NSString *link = payload[key];
                    if ([link isKindOfClass:[NSString class]] && link.length) {
                        resolved = [NSURL URLWithString:link];
                        if (resolved) break;
                    }
                }
            }
        }
        dispatch_semaphore_signal(wait);
    }];
    [task resume];

    dispatch_semaphore_wait(wait, dispatch_time(DISPATCH_TIME_NOW, 15ull * NSEC_PER_SEC));
    return resolved;
}

static long long SCITTMeasure(NSURL *url, NSString **outKind) {
    if (!url) return 0;

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"HEAD";
    request.timeoutInterval = 8;
    SCITTAddBrowserHeaders(request);

    __block long long length = 0;
    __block NSString *kind = nil;
    dispatch_semaphore_t wait = dispatch_semaphore_create(0);

    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
        dataTaskWithRequest:request
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *http = [response isKindOfClass:[NSHTTPURLResponse class]]
            ? (NSHTTPURLResponse *)response : nil;
        if (http.statusCode >= 200 && http.statusCode < 300) {
            length = response.expectedContentLength;

            // **The type was in the response all along and 0.14.0 threw it away.** Measuring
            // by size alone chose a 0.9 MB `audio/mpeg` over an .mp4 whose HEAD was refused --
            // saving the music, which this project has already recorded as worse than saving
            // nothing. Size only ever settles a tie *between videos*.
            kind = response.MIMEType.lowercaseString;
        }
        dispatch_semaphore_signal(wait);
    }];
    [task resume];

    dispatch_semaphore_wait(wait, dispatch_time(DISPATCH_TIME_NOW, 10ull * NSEC_PER_SEC));

    if (outKind) *outKind = kind;
    return length > 0 ? length : 0;
}

///
/// The same question asked a second way, for servers that refuse `HEAD`.
///
/// **A refused `HEAD` was scoring zero and sinking a link to the bottom — including the
/// external HD link the user deliberately switched on**, which is the whole point of that
/// switch, and including `bitrateModels`' own address. A one-byte range request is a `GET`, so
/// a server that serves the file at all answers it, and `Content-Range: bytes 0-0/12345` gives
/// the total in its last field.
static long long SCITTMeasureByRange(NSURL *url, NSString **outKind) {
    if (!url) return 0;

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 8;
    [request setValue:@"bytes=0-0" forHTTPHeaderField:@"Range"];
    SCITTAddBrowserHeaders(request);

    __block long long length = 0;
    __block NSString *kind = nil;
    dispatch_semaphore_t wait = dispatch_semaphore_create(0);

    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
        dataTaskWithRequest:request
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *http = [response isKindOfClass:[NSHTTPURLResponse class]]
            ? (NSHTTPURLResponse *)response : nil;
        if (http.statusCode >= 200 && http.statusCode < 300) {
            kind = response.MIMEType.lowercaseString;

            NSString *range = http.allHeaderFields[@"Content-Range"];
            NSString *total = [[range componentsSeparatedByString:@"/"] lastObject];
            length = total.longLongValue;

            // A server that ignores the range and sends the file answers the question too.
            if (length <= 0 && response.expectedContentLength > 0) {
                length = response.expectedContentLength;
            }
        }
        dispatch_semaphore_signal(wait);
    }];
    [task resume];

    dispatch_semaphore_wait(wait, dispatch_time(DISPATCH_TIME_NOW, 12ull * NSEC_PER_SEC));

    if (outKind) *outKind = kind;
    return length > 0 ? length : 0;
}

/// How a candidate ranks before its size is even looked at.
///
/// 2 answered as video, 1 would not say, 0 answered as audio. Audio never wins on size, no
/// matter how much larger it is, and a link whose server refuses `HEAD` still outranks it
/// because refusing to answer is not evidence of being the wrong thing.
// host-test:begin kindrank
static NSInteger SCITTKindRank(NSString *kind, NSURL *url) {
    NSString *extension = url.pathExtension.lowercaseString;

    if ([kind hasPrefix:@"audio/"] ||
        [@[@"mp3", @"m4a", @"aac", @"wav"] containsObject:extension]) return 0;

    if ([kind hasPrefix:@"video/"] ||
        [@[@"mp4", @"mov", @"m4v"] containsObject:extension]) return 2;

    return 1;
}

// host-test:end kindrank

/// The last measurement, for the settings screen.
static NSString *sciMeasured = nil;

NSString *SCITTMeasuredReport(void) {
    return sciMeasured ?: @"nothing measured yet this launch";
}

///
/// Reorders an item's candidate links so the largest file is tried first.
///
/// **This replaces guessing which chain is better with asking.** TikTok populates the quality
/// ladder only with the gears it is currently streaming -- one report showed five gears up to
/// 720, the next showed a single `comet_lowest_540_1` -- so preferring the ladder takes the
/// worse file exactly when the app has not fetched the better one. Preferring
/// `downloadNoWatermarkURL` instead would be the same mistake pointing the other way. Neither
/// name is reliable; the byte count is.
///
/// Runs off the main thread and is skipped entirely if there is only one link.
///
///
/// Whether a link should lose to a smaller one from a better source.
///
/// Two reasons, and the second was learned the expensive way:
///
/// **`downloadURL` is TikTok's watermarked save copy**, and reliably the largest file on offer,
/// so ranking by size alone stamps a watermark on every download.
///
/// **`h264DownloadURL` is a compatibility transcode, and being bigger is exactly why it looks
/// worse.** It was demoted on a guess from its name, then promoted to test that guess — and the
/// device answered: it won at 7.2 MB against 5.3 and 2.9, saved 7,561,985 bytes, and the picture
/// was *worse than before*. TikTok's own gears say why — `AWEVideoBSModel` declares `codec` and
/// `isBytevc1`, so the modern stream is HEVC and `h264` is the fallback re-encode for players
/// that cannot take it. H.264 needs far more bits for the same picture, so a larger H.264 file
/// and a smaller HEVC one are not comparable at all.
///
/// **That is the third time size answered the wrong question here** — first audio, then the
/// watermark, now the codec. Bytes compare two encodings of the same thing; they say nothing
/// about which thing, or which encoder.
// host-test:begin demoted
static BOOL SCITTOriginIsDemoted(NSString *origin) {
    return [origin isEqualToString:@"downloadURL"] || [origin isEqualToString:@"h264DownloadURL"];
}

// host-test:end demoted

+ (NSArray<NSURL *> *)orderByMeasuredSize:(NSArray<NSURL *> *)links
                                 origins:(NSArray<NSString *> *)origins {
    if (links.count < 2) return links;

    NSMutableArray<NSURL *> *measured = [NSMutableArray array];
    NSMutableDictionary<NSURL *, NSNumber *> *sizes = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSURL *, NSNumber *> *ranks = [NSMutableDictionary dictionary];
    NSMutableArray<NSString *> *report = [NSMutableArray array];

    for (NSURL *url in links) {
        NSString *kind = nil;
        long long size = SCITTMeasure(url, &kind);
        if (size <= 0) {
            NSString *rangeKind = nil;
            size = SCITTMeasureByRange(url, &rangeKind);
            if (rangeKind.length) kind = rangeKind;
        }
        NSInteger rank = SCITTKindRank(kind, url);

        // A clean video outranks a watermarked one whatever the sizes say; among equals, size
        // decides. Three tiers rather than two, so a watermarked video still beats an unknown.
        //
        // **The index is the loop's own, not a search.** `-indexOfObject:` was used here and it
        // silently mislabelled every link the moment the external HD address was inserted at
        // the front: the origins list still described the original order, so each label named
        // the previous link's accessor. A parallel array must be walked in lockstep with the
        // thing it parallels, never re-found.
        NSUInteger index = [links indexOfObjectIdenticalTo:url];
        NSString *origin = index < origins.count ? origins[index] : nil;
        if (rank == 2 && SCITTOriginIsDemoted(origin)) rank = 1;

        // Switching the external HD source on is a request for *that source*, not a hint to be
        // outvoted by an internal link that happens to measure larger. It ranks above them all
        // when it answers at all — and when it does not answer, it keeps its ordinary rank and
        // loses on the merits, so a service that is down costs the download nothing.
        if ([origin isEqualToString:@"tikwm HD"] && size > 0) rank = 3;

        sizes[url] = @(size);
        ranks[url] = @(rank);
        [measured addObject:url];
        [report addObject:[NSString stringWithFormat:@"%@ %.1f MB %@",
                           url.path.lastPathComponent ?: @"?", size / 1048576.0,
                           origin ?: (kind ?: @"?")]];
    }

    // Kind first, size second. A bigger audio file is still the wrong file, and a bigger
    // watermarked file is still a watermarked file.
    [measured sortUsingComparator:^NSComparisonResult(NSURL *a, NSURL *b) {
        if (![ranks[a] isEqual:ranks[b]]) return [ranks[b] compare:ranks[a]];
        return [sizes[b] compare:sizes[a]];
    }];

    // A link that would not answer scores 0 and sinks to the bottom rather than being dropped:
    // a server that refuses HEAD still serves GET, and losing a working link to a measurement
    // that failed would be the same class of mistake as hiding the button when a lookup
    // returned nil.
    sciMeasured = [NSString stringWithFormat:@"%@ — took %@",
                   [report componentsJoinedByString:@", "],
                   measured.firstObject.path.lastPathComponent ?: @"?"];

    return measured;
}

+ (UIViewController *)topViewController {
    UIView *host = [self host];
    UIViewController *controller = host.window.rootViewController;
    while (controller.presentedViewController) controller = controller.presentedViewController;
    return controller;
}

///
/// One change request, run and waited on, reporting whether Photos accepted it.
///
/// Photos serialises change requests anyway, so waiting costs nothing and buys ordering: eight
/// fired at once produce eight interleaved completions and an album in whatever order the
/// library felt like.
static BOOL SCITTPerformPhotoChange(void (^changes)(void), NSString **outError) {
    __block BOOL ok = NO;
    __block NSString *failure = nil;

    dispatch_semaphore_t wait = dispatch_semaphore_create(0);

    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:changes
                                      completionHandler:^(BOOL success, NSError *error) {
        ok = success;
        if (!success) failure = error.localizedDescription;
        dispatch_semaphore_signal(wait);
    }];

    dispatch_semaphore_wait(wait, dispatch_time(DISPATCH_TIME_NOW, 30ull * NSEC_PER_SEC));

    if (outError) *outError = failure;
    return ok;
}

///
/// What a blob of bytes actually is, from its own first bytes.
///
/// Every format here is identified by its documented signature, and the two non-image answers
/// matter as much as the image ones: a CDN that refuses a request answers with HTML or JSON, and
/// that arrives as a perfectly successful download of something that is not a picture.
static NSString *SCITTSniffImageKind(NSData *data) {
    if (data.length < 12) return @"empty or truncated";

    const unsigned char *b = (const unsigned char *)data.bytes;

    if (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return @"JPEG";
    if (b[0] == 0x89 && b[1] == 'P' && b[2] == 'N' && b[3] == 'G') return @"PNG";
    if (!memcmp(b, "GIF8", 4)) return @"GIF";
    if (!memcmp(b, "RIFF", 4) && !memcmp(b + 8, "WEBP", 4)) return @"WebP";
    // HEIC and its relatives: an ISO base-media file whose brand sits after the box length.
    if (!memcmp(b + 4, "ftyp", 4)) {
        if (!memcmp(b + 8, "heic", 4) || !memcmp(b + 8, "heix", 4) ||
            !memcmp(b + 8, "mif1", 4) || !memcmp(b + 8, "msf1", 4)) return @"HEIC";
        return [NSString stringWithFormat:@"ISO media (%.4s)", (const char *)(b + 8)];
    }
    if (b[0] == '<') return @"HTML or XML — not an image";
    if (b[0] == '{' || b[0] == '[') return @"JSON — not an image";

    return [NSString stringWithFormat:@"unknown (%02x %02x %02x %02x)", b[0], b[1], b[2], b[3]];
}

///
/// The picture these bytes hold, or nil when nothing on this phone can read them.
///
/// **`UIImage` and `ImageIO` are two different answers and both are needed.** `UIImage` declines
/// formats the system can otherwise decode, which is why the JPEG re-encode below was once
/// unreachable in exactly the case it existed for; `ImageIO` reads everything the OS has a decoder
/// for. When both refuse, the phone genuinely cannot read this variant -- a VVC still (`ftyp vvic`)
/// is the case a device report actually produced -- and the caller's business is then the next
/// link, not an error message.
static UIImage *SCITTDecodePicture(NSData *data) {
    if (!data.length) return nil;

    UIImage *image = [UIImage imageWithData:data];
    if (image) return image;

    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if (!source) return nil;

    CGImageRef decoded = CGImageSourceCreateImageAtIndex(source, 0, NULL);
    if (decoded) {
        image = [UIImage imageWithCGImage:decoded];
        CGImageRelease(decoded);
    }
    CFRelease(source);
    return image;
}

/// The file extension Photos needs to infer the type, or nil when the bytes are not a picture.
static NSString *SCITTExtensionForImageKind(NSString *kind) {
    if ([kind isEqualToString:@"JPEG"]) return @"jpg";
    if ([kind isEqualToString:@"PNG"]) return @"png";
    if ([kind isEqualToString:@"GIF"]) return @"gif";
    if ([kind isEqualToString:@"WebP"]) return @"webp";
    if ([kind isEqualToString:@"HEIC"]) return @"heic";
    return nil;
}

///
/// Downloads one picture, and says what happened when it does not arrive.
///
/// **`[NSData dataWithContentsOfURL:]` was the whole problem it hid.** It sends no headers worth
/// having and, more to the point, it *cannot report an HTTP status*: a 403 page and a photograph
/// are both "some bytes", so a CDN refusing the request was indistinguishable from a picture in an
/// awkward format. The video path had browser headers from the start and the photo path never did.
static NSData *SCITTFetchPhoto(NSURL *url, NSString **outNote) {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 20;
    SCITTAddBrowserHeaders(request);

    __block NSData *body = nil;
    __block NSString *note = nil;

    dispatch_semaphore_t wait = dispatch_semaphore_create(0);
    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
        dataTaskWithRequest:request
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *http = [response isKindOfClass:[NSHTTPURLResponse class]]
            ? (NSHTTPURLResponse *)response : nil;

        if (error) {
            note = error.localizedDescription;
        } else if (http && (http.statusCode < 200 || http.statusCode > 299)) {
            note = [NSString stringWithFormat:@"HTTP %ld (%@)",
                    (long)http.statusCode, http.MIMEType ?: @"no type"];
        } else if (!data.length) {
            note = @"empty response";
        } else {
            body = data;
            note = [NSString stringWithFormat:@"HTTP %ld, %@",
                    (long)(http ? http.statusCode : 200), http.MIMEType ?: @"no type"];
        }
        dispatch_semaphore_signal(wait);
    }];

    [task resume];
    dispatch_semaphore_wait(wait, dispatch_time(DISPATCH_TIME_NOW, 25ull * NSEC_PER_SEC));

    if (outNote) *outNote = note ?: @"timed out";
    return body;
}

///
/// The post's sound, on disk with an extension `AVURLAsset` can act on.
///
/// **A file's extension is how AVFoundation decides which parser to open it with**, and TikTok's
/// music links carry an opaque path with no extension at all -- an asset built from those bytes
/// under the wrong name has no tracks and reads as "the post has no sound". So the first bytes name
/// the container, the same way the photo save now names its own format, rather than the URL doing it.
static NSURL *SCITTStageAudio(NSURL *remote) {
    if (!remote) return nil;

    NSString *note = nil;
    NSData *data = SCITTFetchPhoto(remote, &note);
    if (!data.length) {
        SCILogV(@"clip audio: %@", note ?: @"nothing arrived");
        return nil;
    }

    NSString *extension = @"mp3";
    const unsigned char *b = (const unsigned char *)data.bytes;
    if (data.length > 12) {
        if (!memcmp(b + 4, "ftyp", 4)) extension = @"m4a";
        else if (!memcmp(b, "ID3", 3) || (b[0] == 0xFF && (b[1] & 0xE0) == 0xE0)) extension = @"mp3";
        else if (!memcmp(b, "OggS", 4)) extension = @"ogg";
        else if (!memcmp(b, "RIFF", 4)) extension = @"wav";
    }

    NSURL *file = [NSURL fileURLWithPath:
        [NSTemporaryDirectory() stringByAppendingPathComponent:
            [NSString stringWithFormat:@"albrhi-sound-%@.%@", [[NSUUID UUID] UUIDString], extension]]];

    return [data writeToURL:file atomically:YES] ? file : nil;
}

///
/// Saves one downloaded picture, trying three ways and naming the one that worked.
///
/// **`PHPhotosErrorDomain 3302` is Photos refusing the *format*, not the bytes** — it arrived
/// for images `UIImage` had already decoded perfectly well, which rules out a bad download. The
/// cause is that a data resource carries no file name, so the library has to guess the type,
/// and TikTok serves these as WebP, which it will not take.
///
/// So the original bytes are offered *with* their own file name first — that is the only path
/// that saves the picture exactly as posted, no re-encode. If Photos still refuses the format,
/// the decoded image is re-encoded as JPEG, which it always accepts and which is a real loss
/// worth taking over saving nothing. The plain image request is kept last as the path that
/// worked before any of this.
static BOOL SCITTSavePhotoData(NSData *data, UIImage *image, NSURL *source,
                               NSString **outHow, NSString **outError) {
    // **The file name is built from what the bytes are, not from what the URL is called.**
    //
    // A data resource carries no type of its own, so Photos infers one from the name -- and the
    // name was being taken from the URL's last path component, which on TikTok's CDN is an opaque
    // id with no extension or a misleading one. `.jpg` was then appended to whatever it was, so a
    // WebP arrived announced as a JPEG, and a library told the wrong format is a library that
    // refuses the file: `PHPhotosErrorDomain 3302`, which is exactly what came back. Two guesses
    // (the name, and the extension bolted onto it) where the first four bytes are a fact.
    NSString *kind = SCITTSniffImageKind(data);
    NSString *extension = SCITTExtensionForImageKind(kind);

    PHAssetResourceCreationOptions *options = [[PHAssetResourceCreationOptions alloc] init];
    options.originalFilename = extension
        ? [@"photo" stringByAppendingPathExtension:extension]
        : (source.lastPathComponent.length ? source.lastPathComponent : @"photo");

    NSString *error = nil;

    if (SCITTPerformPhotoChange(^{
        PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
        [request addResourceWithType:PHAssetResourceTypePhoto data:data options:options];
    }, &error)) {
        if (outHow) *outHow = @"as posted";
        return YES;
    }

    // **Decoding through ImageIO rather than only UIImage.** A device report came back with
    // 3302 after all three attempts, which means the image was nil and only the first ran:
    // `UIImage` will not decode some of what TikTok serves, and the JPEG fallback was therefore
    // unreachable exactly when it was needed. `CGImageSourceCreateWithData` reads every format
    // the system has a decoder for, including the ones UIImage declines, so the re-encode path
    // is now available whenever anything at all can read the bytes.
    if (!image) {
        CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
        if (source) {
            CGImageRef decoded = CGImageSourceCreateImageAtIndex(source, 0, NULL);
            if (decoded) {
                image = [UIImage imageWithCGImage:decoded];
                CGImageRelease(decoded);
            }
            CFRelease(source);
        }
    }

    if (image) {
        NSData *jpeg = UIImageJPEGRepresentation(image, 0.95);
        if (jpeg.length) {
            PHAssetResourceCreationOptions *asJPEG = [[PHAssetResourceCreationOptions alloc] init];
            asJPEG.originalFilename = @"photo.jpg";

            if (SCITTPerformPhotoChange(^{
                PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
                [request addResourceWithType:PHAssetResourceTypePhoto data:jpeg options:asJPEG];
            }, &error)) {
                if (outHow) *outHow = @"re-encoded as JPEG";
                return YES;
            }
        }

        if (SCITTPerformPhotoChange(^{
            [PHAssetChangeRequest creationRequestForAssetFromImage:image];
        }, &error)) {
            if (outHow) *outHow = @"via UIImage";
            return YES;
        }
    }

    if (outError) {
        // **What the bytes actually are, named, because "undecodable" was a dead end three
        // releases long.** A refusal has two completely different causes that produced the same
        // sentence: a real picture in a format Photos will not take, and something that is not a
        // picture at all -- an HTML error page or a JSON refusal from the CDN, which decodes to
        // nothing and saves as nothing. One is a format problem and the other is a *download*
        // problem, and no fourth fallback could have been chosen without knowing which.
        *outError = [NSString stringWithFormat:@"%@ [%@, %lu bytes, named %@; tried: as posted%@]",
                     error ?: @"refused", kind, (unsigned long)data.length,
                     options.originalFilename,
                     image ? @", JPEG, UIImage" : @" only — nothing could decode it"];
    }
    return NO;
}

///
/// One picture plus the post's sound, saved as a video.
///
/// The picture and the sound are fetched through the same helper the photo save uses, so both
/// carry browser headers and both report an HTTP status rather than "some bytes" -- the fix that
/// made photo saving work at all. **The sound not arriving is not a failure of the clip**: the
/// exporter lays down whatever audio it is given and writes the picture regardless, which is the
/// same refusal-in-the-right-place rule that keeps the download button visible when a lookup fails.
+ (void)saveClipFromPicture:(NSArray<NSURL *> *)picture
                       item:(SCITTMediaItem *)item
                    seconds:(NSTimeInterval)seconds {
    [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly
                                               handler:^(PHAuthorizationStatus status) {
        if (status != PHAuthorizationStatusAuthorized && status != PHAuthorizationStatusLimited) {
            SCITTRecordDownload(@"Photos access refused");
            [self report:SCILocalized(@"save_no_permission") ok:NO];
            return;
        }

        // Indeterminate rather than a percentage: the work here is a download, a render and an
        // export, and a bar that only knows about the first of the three tells the user the save is
        // finished when it is a third done.
        [SCITTToast showText:SCILocalized(@"audio_working") symbol:@"music.note" progress:-1];

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            // The same walk the photo save does: a variant iOS cannot decode is the next link's
            // turn, not the end of the attempt.
            NSString *note = nil;
            UIImage *still = nil;
            NSMutableArray<NSString *> *tried = [NSMutableArray array];

            for (NSURL *candidate in picture) {
                NSData *stillData = SCITTFetchPhoto(candidate, &note);
                if (!stillData.length) {
                    [tried addObject:note ?: @"nothing arrived"];
                    continue;
                }

                still = SCITTDecodePicture(stillData);
                if (still) break;
                [tried addObject:[NSString stringWithFormat:@"%@ (no decoder)",
                    SCITTSniffImageKind(stillData)]];
            }

            if (!still) {
                SCITTRecordDownload([NSString stringWithFormat:@"clip — no readable picture (%@)",
                    [tried componentsJoinedByString:@", "]]);
                [self report:SCILocalized(@"save_failed") ok:NO];
                return;
            }

            NSURL *audioFile = SCITTStageAudio(item.audioURL);

            [SCITTStillVideo renderImage:still
                                audioURL:audioFile
                                 seconds:seconds
                              completion:^(NSURL *file, NSString *failure) {
                if (audioFile) [[NSFileManager defaultManager] removeItemAtURL:audioFile error:NULL];

                if (!file) {
                    SCITTRecordDownload([NSString stringWithFormat:@"clip — %@",
                        failure ?: @"not written"]);
                    [self report:SCILocalized(@"save_failed") ok:NO];
                    return;
                }

                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    [PHAssetCreationRequest creationRequestForAssetFromVideoAtFileURL:file];
                } completionHandler:^(BOOL success, NSError *error) {
                    [[NSFileManager defaultManager] removeItemAtURL:file error:NULL];

                    SCITTRecordDownload(success
                        ? [NSString stringWithFormat:@"clip saved — %.0fs, %@ sound",
                            seconds, audioFile ? @"with" : @"without"]
                        : [NSString stringWithFormat:@"clip refused by Photos: %@",
                            error.localizedDescription ?: @"no reason given"]);

                    [self report:SCILocalized(success ? @"audio_done" : @"save_failed") ok:success];
                }];
            }];
        });
    }];
}

///
/// **A picture is a list of links, and the save takes the first whose bytes actually read.**
///
/// It used to take one link per picture and hand whatever came back to Photos. A device report
/// then showed `ISO media (vvic)` — a VVC still, a format iOS has no decoder for — so nothing on
/// the phone could read it and Photos refused the file with `3302`. Nothing was wrong with the
/// download or the name: that *variant* is unreadable here, and the model offers others.
///
/// So each candidate is fetched and read before it is offered to the library, and the first that
/// decodes wins. A format that cannot be decoded is not a failure to report and stop on; it is a
/// reason to try the next link, which is the difference between "TikTok served something odd" and
/// "saving is broken".
///
+ (void)savePhotos:(NSArray<NSArray<NSURL *> *> *)groups {
    [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly
                                               handler:^(PHAuthorizationStatus status) {
        if (status != PHAuthorizationStatusAuthorized &&
            status != PHAuthorizationStatusLimited) {
            SCITTRecordDownload(@"Photos access refused");
            dispatch_async(dispatch_get_main_queue(), ^{
                [self report:SCILocalized(@"save_no_permission") ok:NO];
            });
            return;
        }

        [SCITTToast showText:SCILocalized(@"save_working") symbol:@"photo" progress:0];

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSUInteger saved = 0, noData = 0, refused = 0;
            NSString *firstError = nil;
            NSMutableSet<NSString *> *ways = [NSMutableSet set];

            for (NSArray<NSURL *> *group in groups) {
                //
                // **For one picture, the biggest readable variant; for a whole album, the first.**
                //
                // A device report saved cleanly at 1170×2080 and named `thumbnailPhotoURL` as the
                // winner -- which is not the tiny preview the name suggests, but it is not proof
                // that nothing larger was readable either: the walk takes the first variant that
                // decodes, and "first" is a position in a list, not a size. The video path settled
                // this argument long ago by measuring instead of ranking names, and the same answer
                // applies here: one `HEAD` per link, largest first, then download.
                //
                // Only for a single picture. An album of twenty-one at ten links each would be two
                // hundred round trips before the first byte of anything is saved, and the person
                // who asked for "all of them" asked for all of them, not for the best possible
                // version of all of them.
                //
                NSArray<NSURL *> *ordered = group;
                if (groups.count == 1 && group.count > 1) {
                    //
                    // **Clean before watermarked, and size only decides inside each of those.**
                    //
                    // Sorting the whole list by bytes put `userWatermarkedPhotoURL` first and saved
                    // the watermark back — at the identical 1170×2080, because a watermarked copy is
                    // the same picture re-encoded with something painted on it, and that is usually
                    // the *larger* file. So measuring alone made the picture worse.
                    //
                    // CLAUDE.md already says this about the video path, in these words: size answers
                    // "which is bigger", never "which is right", and each wrong-file report has been
                    // a different property size cannot see — the audio track, the watermark, the
                    // codec. This is the fourth, one layer down, made by the same hand that wrote
                    // the rule. **Kind decides first; bytes settle ties inside a kind.**
                    //
                    NSMutableArray<NSURL *> *clean = [NSMutableArray array];
                    NSMutableArray<NSURL *> *stamped = [NSMutableArray array];
                    NSMutableDictionary<NSString *, NSNumber *> *sizes = [NSMutableDictionary dictionary];

                    for (NSURL *candidate in group) {
                        long long bytes = SCITTMeasure(candidate, NULL);
                        if (bytes <= 0) bytes = SCITTMeasureByRange(candidate, NULL);
                        // A link that will not answer keeps its place rather than sinking: refusing
                        // to be measured is not evidence of being small, and this project has
                        // already disabled a working feature by treating it as such.
                        sizes[candidate.absoluteString] = @(bytes > 0 ? bytes : LLONG_MAX / 2);

                        NSString *origin = [SCITTMedia photoOriginFor:candidate] ?: @"";
                        // Only the accessor's name knows this. Nothing measurable about the bytes
                        // says whether a watermark is painted into them.
                        BOOL watermarked = [origin rangeOfString:@"watermark"
                                                         options:NSCaseInsensitiveSearch].location != NSNotFound;
                        [(watermarked ? stamped : clean) addObject:candidate];
                    }

                    NSComparator biggestFirst = ^NSComparisonResult(NSURL *a, NSURL *b) {
                        return [sizes[b.absoluteString] compare:sizes[a.absoluteString]];
                    };
                    [clean sortUsingComparator:biggestFirst];
                    [stamped sortUsingComparator:biggestFirst];

                    ordered = [clean arrayByAddingObjectsFromArray:stamped];
                }

                BOOL done = NO;
                NSMutableArray<NSString *> *tried = [NSMutableArray array];
                NSString *lastError = nil;

                for (NSURL *url in ordered) {
                    NSString *fetchNote = nil;
                    NSData *data = SCITTFetchPhoto(url, &fetchNote);
                    if (!data.length) {
                        [tried addObject:[NSString stringWithFormat:@"%@ (%@)",
                            url.lastPathComponent.pathExtension.length
                                ? url.lastPathComponent.pathExtension : @"link",
                            fetchNote ?: @"nothing arrived"]];
                        lastError = fetchNote;
                        continue;
                    }

                    // Read here, before Photos is asked: a format the phone has no decoder for is
                    // the next link's turn, not an error to stop on.
                    NSString *kind = SCITTSniffImageKind(data);
                    UIImage *image = SCITTDecodePicture(data);
                    if (!image) {
                        [tried addObject:[NSString stringWithFormat:@"%@ (no decoder)", kind]];
                        continue;
                    }

                    NSString *how = nil, *error = nil;
                    if (SCITTSavePhotoData(data, image, url, &how, &error)) {
                        saved++;
                        // The *variant*, not just the method. "saved (as posted)" was true of a
                        // watermarked copy too, which is how a device report of "it saves, but with
                        // a watermark" had nothing in the log to confirm it. The accessor's name is
                        // the only thing that knows.
                        // The pixels, because that is the question a person actually has about a
                        // saved picture, and a variant name only answers it indirectly.
                        NSString *origin = [SCITTMedia photoOriginFor:url];
                        NSString *pixels = [NSString stringWithFormat:@"%.0f×%.0f",
                            image.size.width * image.scale, image.size.height * image.scale];
                        [ways addObject:origin.length
                            ? [NSString stringWithFormat:@"%@ %@ · %@", origin, pixels, how ?: @"saved"]
                            : [NSString stringWithFormat:@"%@ · %@", pixels, how ?: @"saved"]];
                        done = YES;
                        break;
                    }

                    [tried addObject:[NSString stringWithFormat:@"%@ (%@)", kind,
                        error ?: @"refused"]];
                    lastError = error;
                }

                if (!done) {
                    // Counted by what actually happened: nothing readable is a different problem
                    // from nothing arriving, and both used to land in one number.
                    if (lastError.length && !tried.count) noData++;
                    else refused++;
                    if (!firstError) {
                        firstError = [NSString stringWithFormat:@"%lu link(s) tried: %@",
                            (unsigned long)group.count,
                            [tried componentsJoinedByString:@", "]];
                    }
                }

                NSUInteger finished = saved + noData + refused;
                [SCITTToast showText:SCILocalized(@"save_working")
                              symbol:@"photo"
                            progress:(CGFloat)finished / (CGFloat)groups.count];
            }

            // Counted apart, because a download that never arrived and a library that refused
            // the file need different fixes and one number said only that nothing happened.
            NSMutableString *note = [NSMutableString stringWithFormat:@"photo post — saved %lu of %lu",
                (unsigned long)saved, (unsigned long)groups.count];
            if (ways.count) {
                [note appendFormat:@" (%@)",
                    [[ways allObjects] componentsJoinedByString:@", "]];
            }
            if (noData) [note appendFormat:@"; %lu never downloaded", (unsigned long)noData];
            if (refused) [note appendFormat:@"; %lu refused by Photos", (unsigned long)refused];
            if (firstError) [note appendFormat:@" (%@)", firstError];

            SCITTRecordDownload(note);

            NSUInteger finalSaved = saved;
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *message = groups.count > 1
                    ? [NSString stringWithFormat:SCILocalized(@"photos_saved_count"),
                       (unsigned long)finalSaved, (unsigned long)groups.count]
                    : SCILocalized(finalSaved ? @"save_done" : @"save_failed");
                [self report:message ok:(finalSaved == groups.count)];
            });
        });
    }];
}



+ (void)save:(SCITTMediaItem *)item {
    if (!item.url) return;

    // A photo post takes an entirely different path: several images, saved as images.
    //
    // The video path downloads to a temporary file and asks Photos to import it as a video,
    // and handing it a JPEG produces exactly the PHPhotosErrorDomain refusal that has already
    // appeared in one report -- Photos rejecting a file it was told was the wrong kind. The
    // two are separated here rather than inside the importer, so neither has to ask what the
    // other is doing.
    if (item.photoURLs.count) {
        [self askThenSavePhotos:item];
        return;
    }

    // **Shown on the tap, before anything slow.** The gap the owner reported was not a stall in
    // the download -- it was the Photos permission callback plus a `HEAD` for every candidate
    // link, up to ten seconds each, all of it ahead of the first pixel of feedback. The work was
    // running; nothing said so. **A button must answer the finger, not the network.**
    [SCITTToast showText:SCILocalized(@"save_working") symbol:@"arrow.down.circle" progress:-1];

    [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly
                                                handler:^(PHAuthorizationStatus status) {
        if (status != PHAuthorizationStatusAuthorized &&
            status != PHAuthorizationStatusLimited) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self report:SCILocalized(@"save_no_permission") ok:NO];
            });
            return;
        }

        // Measured off the main thread: it is one HEAD per link and the feed keeps scrolling.
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSMutableArray<NSURL *> *links = [item.candidates mutableCopy] ?: [NSMutableArray array];

            // Grown and shrunk together with `links`, because a parallel array that is only
            // sometimes updated is worse than none: the labels stay plausible while naming the
            // wrong thing, which is exactly what a device report showed.
            NSMutableArray<NSString *> *origins =
                [item.candidateOrigins mutableCopy] ?: [NSMutableArray array];
            while (origins.count < links.count) [origins addObject:@"?"];

            // The one link in this tweak that leaves TikTok, and only on request.
            //
            // NA9's HD button has been reliable for years across TikTok updates for a reason
            // that is not cleverness: it never touches the app's model chain at all, so there
            // was never an internal accessor in that path to break. It asks tikwm.com, keyed
            // by the post id.
            //
            // The cost is the whole reason this is a switch and not the default: it tells a
            // service unrelated to TikTok and unrelated to this tweak which video you are
            // watching -- the exact thing the three privacy switches beside it exist to stop.
            // Off unless someone turns it on, and its own row says what it does before they do.
            if (SCIPrefEnabled(SCIPrefExternalHD) && item.itemID.length) {
                NSURL *external = SCITTExternalHDLink(item.itemID);
                if (external) {
                    [links insertObject:external atIndex:0];
                    [origins insertObject:@"tikwm HD" atIndex:0];
                }
            }

            NSArray<NSURL *> *ordered = [self orderByMeasuredSize:links origins:origins];
            if (ordered.count) {
                item.candidates = ordered;
                item.url = ordered.firstObject;
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                [self start:item];
            });
        });
    }];
}

+ (void)start:(SCITTMediaItem *)item {
    static dispatch_once_t once;
    dispatch_once(&once, ^{ _running = [NSMutableSet set]; });

    SCITTDownload *download = [[SCITTDownload alloc] init];
    download.item = item;
    download.candidateIndex = 0;
    download.rejected = [NSMutableArray array];

    // The banner is already on screen from the tap; this only gives it a real fraction to show
    // now that a transfer exists to measure.
    [SCITTToast showText:SCILocalized(@"save_working") symbol:@"arrow.down.circle" progress:0];

    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    download.session = [NSURLSession sessionWithConfiguration:configuration
                                                     delegate:download
                                                delegateQueue:nil];

    @synchronized (_running) { [_running addObject:download]; }

    [download fetchCurrentCandidate];
}

/// The candidate list, or the single URL for an item that predates it.
- (NSArray<NSURL *> *)links {
    if (self.item.candidates.count) return self.item.candidates;
    return self.item.url ? @[self.item.url] : @[];
}

- (void)fetchCurrentCandidate {
    NSArray<NSURL *> *links = [self links];
    if (self.candidateIndex >= links.count) {
        // Every candidate fetched and every one of them turned out to be something
        // other than a video. Naming all of them is the point: one rejected link says
        // nothing, the whole list says which chain family to stop trusting.
        SCITTRecordDownload([NSString stringWithFormat:@"no candidate was a video — %@",
            [self.rejected componentsJoinedByString:@"; "]]);
        [self finish:NO message:SCILocalized(@"save_failed")];
        return;
    }

    NSURL *url = links[self.candidateIndex];
    [[self.session downloadTaskWithURL:url] resume];
    SCILogV(@"downloading candidate %lu/%lu: %@",
        (unsigned long)(self.candidateIndex + 1), (unsigned long)links.count, url);
}

/// Records why this candidate was not it, then fetches the next one.
- (void)rejectCandidate:(NSString *)reason {
    NSArray<NSURL *> *links = [self links];
    NSURL *url = self.candidateIndex < links.count ? links[self.candidateIndex] : nil;

    [self.rejected addObject:[NSString stringWithFormat:@"%@ (%@)",
        reason, url.lastPathComponent ?: @"?"]];

    self.candidateIndex++;
    [self fetchCurrentCandidate];
}

+ (UIView *)host {
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isKeyWindow) return window;
        }
    }
    return nil;
}

#pragma mark - Session

- (void)URLSession:(NSURLSession *)session
                       downloadTask:(NSURLSessionDownloadTask *)task
                       didWriteData:(int64_t)wrote
                  totalBytesWritten:(int64_t)written
          totalBytesExpectedToWrite:(int64_t)expected {
    if (expected <= 0) return;
    double fraction = (double)written / (double)expected;
    dispatch_async(dispatch_get_main_queue(), ^{
        [SCITTToast showText:SCILocalized(@"save_working")
                      symbol:@"arrow.down.circle"
                    progress:(CGFloat)fraction];
    });
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)task
didFinishDownloadingToURL:(NSURL *)location {
    // An HTTP error answers with a body like any other response, and NSURLSession
    // hands that body over as a perfectly successful download -- so a 403 on the
    // resolved link arrives here as an error page saved with a .mp4 name, which
    // Photos then refuses for reasons that say nothing about the real cause.
    if ([task.response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSInteger status = ((NSHTTPURLResponse *)task.response).statusCode;
        if (status < 200 || status >= 300) {
            [[NSFileManager defaultManager] removeItemAtURL:location error:NULL];
            [self rejectCandidate:[NSString stringWithFormat:@"HTTP %ld", (long)status]];
            return;
        }
    }

    NSString *mime = task.response.MIMEType.lowercaseString ?: @"";
    unsigned long long bytes =
        [[[NSFileManager defaultManager] attributesOfItemAtPath:location.path error:NULL] fileSize];

    //
    // **Asked of the file, not of its name.** Both the URL's path extension and the
    // response's MIME type were tried in turn across two releases and both were wrong
    // on a real device: a genuine video kept saving as "sound saved", which is the
    // audio branch below being taken for a file that plainly has a video track. This
    // project's own ground rule already covers exactly this -- "a non-nil object is not
    // a working object; check that a thing can actually do its job, not that it is
    // non-null" -- and the same applies to a file's kind. AVFoundation reading the
    // downloaded file's own track list is the measurement; an extension on a URL that
    // may carry query parameters, no path at all, or a CDN's own naming is a guess.
    //
    NSURL *staged = [NSURL fileURLWithPath:
        [NSTemporaryDirectory() stringByAppendingPathComponent:
            [NSString stringWithFormat:@"tiktok-%@.mp4", [[NSUUID UUID] UUIDString]]]];

    [[NSFileManager defaultManager] removeItemAtURL:staged error:NULL];

    NSError *move = nil;
    if (![[NSFileManager defaultManager] moveItemAtURL:location toURL:staged error:&move]) {
        SCITTRecordDownload([NSString stringWithFormat:@"could not stage the file: %@",
            move.localizedDescription ?: @"no reason given"]);
        [self finish:NO message:SCILocalized(@"save_failed")];
        return;
    }

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:staged options:nil];
    NSUInteger videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo].count;
    NSUInteger audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio].count;
    BOOL audioOnly = (videoTracks == 0 && audioTracks > 0);

    // Neither kind of track at all is a file that is not media -- an error page, a
    // truncated transfer, an HTML redirect that answered 200. Saying so is worth far
    // more than handing it to Photos and reporting whatever Photos makes of it.
    if (videoTracks == 0 && audioTracks == 0) {
        [[NSFileManager defaultManager] removeItemAtURL:staged error:NULL];
        [self rejectCandidate:[NSString stringWithFormat:@"not media, %llu bytes, %@",
            bytes, mime.length ? mime : @"no mime"]];
        return;
    }

    //
    // **Audio is now a rejected candidate, not an outcome.** This branch used to save
    // the file into Documents and report "sound saved" -- which is exactly what a real
    // device kept doing for a video, because `originURLList` reliably answers with the
    // *sound's* link and there was nothing to fall back to. There is now: every chain's
    // link is kept, so an audio-only file means "wrong candidate, try the next one"
    // rather than "this video is a song". Only when every candidate has been fetched and
    // every one of them lacked a video track is audio accepted as the honest answer --
    // handled in -fetchCurrentCandidate's own exhausted branch, which names all of them.
    //
    if (audioOnly) {
        [[NSFileManager defaultManager] removeItemAtURL:staged error:NULL];
        [self rejectCandidate:[NSString stringWithFormat:@"audio only, %llu bytes, %@",
            bytes, mime.length ? mime : @"no mime"]];
        return;
    }

    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetCreationRequest creationRequestForAssetFromVideoAtFileURL:staged];
    } completionHandler:^(BOOL success, NSError *error) {
        [[NSFileManager defaultManager] removeItemAtURL:staged error:NULL];
        if (success) {
            SCITTRecordDownload([NSString stringWithFormat:
                @"saved to Photos — %lu video / %lu audio track(s), %llu bytes",
                (unsigned long)videoTracks, (unsigned long)audioTracks, bytes]);
            [self finish:YES message:SCILocalized(@"save_done")];
            return;
        }
        // Named, not just "couldn't save it". Photos refuses a video for reasons that
        // need opposite fixes -- a file it will not decode, a permission narrower than
        // it appeared, a zero-length download that answered 200 -- and the message
        // shown so far could not tell any of them apart.
        SCITTRecordDownload([NSString stringWithFormat:@"Photos refused: %@",
            error.localizedDescription ?: @"no reason given"]);
        [self finish:NO message:SCILocalized(@"save_failed")];
    }];
}

- (void)URLSession:(NSURLSession *)session
                    task:(NSURLSessionTask *)task
    didCompleteWithError:(NSError *)error {
    if (!error) return;
    // A transfer that failed outright is a rejected candidate like any other -- the
    // next link in the list may well be reachable when this one was not.
    [self rejectCandidate:[NSString stringWithFormat:@"transfer failed: %@",
        error.localizedDescription ?: @"no reason given"]];
}

- (void)finish:(BOOL)success message:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Left to `+report:` below, which turns the banner into its finished state rather than
        // taking it away and putting a second one back.


        [SCITTDownload report:message ok:success];

        [self.session invalidateAndCancel];
        @synchronized (_running) { [_running removeObject:self]; }
    });
}

+ (void)report:(NSString *)message ok:(BOOL)ok {
    [SCITTToast finishWithText:message ok:ok];
}

@end
