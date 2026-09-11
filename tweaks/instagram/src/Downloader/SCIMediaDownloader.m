#import "SCIMediaDownloader.h"
#import "shared/src/SCIKVC.h"
#import "../UI/SCIQualitySheet.h"
#import "Download.h"
#import "Queue/SCIDownloadQueue.h"
#import "Transcode/SCIAV1Transcoder.h"
#import "Transcode/SCITranscodeBanner.h"
#import "Transcode/SCIPhotoVideo.h"
#import "../Utils.h"
#import "../Localization/SCILocalize.h"
#import "../Settings/SCIDiagnosticsViewController.h"
#import <objc/runtime.h>
// objc_msgSend is declared here, not in runtime.h -- the selectors probed in
// +videoDeclarationSignalFor: are confirmed in a class dump rather than declared in
// InstagramHeaders.h, so they are sent rather than called.
#import <objc/message.h>
#import <Photos/Photos.h>

@implementation SCIMediaDownloader

// MARK: - Qualities

// MARK: - Entry points

+ (void)downloadVideo:(IGVideo *)video sourceLabel:(NSString *)sourceLabel anchor:(UIView *)anchor {
    if (!video) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"err_no_video")];
        return;
    }

    // Best saveable rendition: the DASH ladder often carries a higher H.264/HEVC
    // than -videoVersions exposes. -getBestVideoUrl: falls back to the proven
    // -videoVersions path whenever DASH offers nothing iOS can save.
    NSURL *url = [SCIUtils getBestVideoUrl:video];

    if (!url) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"err_no_video")];
        return;
    }

    [SCIDiagnostics recordQualityCount:1 forVideoClass:NSStringFromClass([video class])];

    [self downloadURL:url sourceLabel:sourceLabel isVideo:YES];
}

/// Reels can be saved as video or as the original audio track.
+ (void)presentVideoOrAudioChoiceForVideo:(IGVideo *)video
                                 audioURL:(NSURL *)audioURL
                              sourceLabel:(NSString *)sourceLabel
                                   anchor:(UIView *)anchor {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:nil
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"dw_choice_video")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [SCIMediaDownloader downloadVideo:video sourceLabel:sourceLabel anchor:anchor];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"dw_choice_audio")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [SCIMediaDownloader downloadURL:audioURL sourceLabel:sourceLabel isVideo:NO];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    if (anchor) {
        sheet.popoverPresentationController.sourceView = anchor;
        sheet.popoverPresentationController.sourceRect = anchor.bounds;
    }

    [topMostController() presentViewController:sheet animated:YES completion:nil];
}

+ (void)downloadURL:(NSURL *)url sourceLabel:(NSString *)sourceLabel isVideo:(BOOL)isVideo {
    if (!url) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"err_no_media")];
        return;
    }

    NSString *extension = [[url lastPathComponent] pathExtension];

    // DASH BaseURLs and other CDN links often carry no file extension (or a query
    // string). Photos rejects an extension-less video, which surfaces as a failure —
    // fall back to a sensible default for the media kind.
    if (![extension length] || [extension length] > 4) {
        extension = isVideo ? @"mp4" : @"jpg";
    }

    // Queue mode: hand off and let the transfer run in the background.
    if ([SCIUtils getBoolPref:@"dl_use_queue"]) {
        SCIDownloadQueue *queue = [SCIDownloadQueue shared];

        SCIDownloadJob *existing = [queue completedJobForURL:url];
        if (existing) {
            [SCIUtils showToastForDuration:1.6
                                     title:SCILocalized(@"dl_already_downloaded")
                                  subtitle:existing.displayName];
            return;
        }

        [queue enqueueURL:url fileExtension:extension displayName:nil sourceLabel:sourceLabel];
        [SCIUtils showToastForDuration:1.2 title:SCILocalized(@"dl_added_to_queue")];

        return;
    }

    // Direct mode: the original blocking HUD flow.
    BOOL toPhotos = [SCIUtils getBoolPref:@"dw_save_to_camera"];

    DownloadAction action = toPhotos
        ? saveToPhotos
        : (isVideo ? share : quickLook);

    SCIDownloadDelegate *delegate = [[SCIDownloadDelegate alloc] initWithAction:action showProgress:isVideo];

    [delegate downloadFileWithURL:url fileExtension:extension hudLabel:nil];
}

/// Whether this IGVideo can actually produce a download.
///
/// A photo post still hands back a non-nil IGVideo — an empty shell with no
/// renditions. Treating "video != nil" as "this is a video" sent every photo down
/// the video path, where it failed with "could not extract URL" while the
/// long-press path, which checks the photo directly, worked fine.
+ (BOOL)hasPlayableVideo:(IGVideo *)video {
    if (!video) return NO;

    @try {
        if ([video respondsToSelector:@selector(videoVersions)]) {
            id versions = [video performSelector:@selector(videoVersions)];

            if ([versions respondsToSelector:@selector(count)] && [versions count] > 0) return YES;
        }
    } @catch (__unused id e) {}

    // No rendition list, but another accessor may still resolve a URL.
    if ([SCIUtils getVideoUrl:video] != nil) return YES;

    //
    // **The gate was narrower than the thing it gates, and that is its own bug.**
    // This check ran `+getVideoUrl:` — `videoVersions`, `sortedVideoURLsBySize`,
    // `allVideoURLs` — while the downloader it stands in front of runs
    // `+getBestVideoUrl:`, which *also* parses the DASH manifest. So a video whose
    // only rendition lives in that manifest was refused here by a test the actual
    // download would have passed. `-dashManifestData` is declared on `IGVideo` in the
    // tested build (and on `IGVideo` only, which is why nothing is asked of the media).
    //
    // A capability check must ask the same question the capability answers.
    //
    @try {
        for (NSDictionary *rep in [SCIUtils dashRepresentationsForVideo:video media:nil]) {
            if ([rep[@"type"] isEqualToString:@"video"] && [rep[@"url"] length]) return YES;
        }
    } @catch (__unused id e) {}

    return NO;
}

///
/// Does this media *say* it is a video, whether or not one can be resolved yet — and
/// if so, which signal said so? Nil when none did.
///
/// **The distinction this exists for.** `+hasPlayableVideo:` answers "is there a
/// rendition I can fetch right now", and a repost answers NO to that while still being
/// a video. Reading that NO as "therefore a photo" is what saved a repost's cover image
/// when a video was asked for, so the kind is asked here, separately.
///
/// Read from the class dump of the tested build rather than guessed. Three independent
/// signals, because no single one of them is safe alone:
///
///   -videoDuration on IGVideo   a photo post's hollow IGVideo has no duration, so a
///                               positive one is a video and needs no enum constant
///   -dashManifestData           a manifest exists only for a video
///   -mediaTypeEnum on IGMedia   Instagram's own media_type; 2 is video in its API and
///                               has been for years, but it is a constant this project
///                               did not measure, so it is asked last
///
/// Any one of the three is enough. They are OR-ed rather than AND-ed because the
/// failure that matters is a video being missed, and a photo post satisfies none of
/// them: its hollow IGVideo carries no duration, no manifest, and its media type is
/// not the video one.
///
/// The *name* is returned rather than a flag because the three point at different
/// causes, and one sentence covering all of them is a diagnostic that cannot say which.
+ (NSString *)videoDeclarationSignalFor:(id)media {
    if (!media) return nil;

    IGVideo *video = nil;
    @try { video = SCISafeValueForKey(media, @"video"); } @catch (__unused id e) {}

    // All three are sent through objc_msgSend rather than called: they are selectors
    // confirmed in a class dump of the tested build, not methods InstagramHeaders.h
    // declares, so a direct call has no visible interface to compile against. Each cast
    // must name the real return type -- a double comes back in a floating-point
    // register, and reading it through an `id`-shaped signature reads the wrong one.
    @try {
        SEL duration = NSSelectorFromString(@"videoDuration");
        if ([video respondsToSelector:duration] &&
            ((double (*)(id, SEL))objc_msgSend)(video, duration) > 0.0) {
            return @"duration";
        }
    } @catch (__unused id e) {}

    @try {
        SEL manifest = NSSelectorFromString(@"dashManifestData");
        if ([video respondsToSelector:manifest] &&
            ((id (*)(id, SEL))objc_msgSend)(video, manifest) != nil) {
            return @"dash manifest";
        }
    } @catch (__unused id e) {}

    @try {
        SEL typeEnum = NSSelectorFromString(@"mediaTypeEnum");
        if ([media respondsToSelector:typeEnum] &&
            ((long long (*)(id, SEL))objc_msgSend)(media, typeEnum) == 2) {
            return @"mediaTypeEnum";
        }
    } @catch (__unused id e) {}

    return nil;
}


/// Whether this media is a stub Instagram has not fetched yet -- both accessors are
/// declared on IGMedia in the tested build. Used only to word the failure, never to
/// decide the kind: a photo post can be momentarily unfetched too.
+ (BOOL)mediaNeedsFetch:(id)media {
    for (NSString *name in @[@"needsMediaFetch", @"needsFetch"]) {
        @try {
            SEL selector = NSSelectorFromString(name);
            if ([media respondsToSelector:selector] &&
                ((BOOL (*)(id, SEL))objc_msgSend)(media, selector)) {
                return YES;
            }
        } @catch (__unused id e) {}
    }
    return NO;
}

+ (void)downloadMedia:(id)media sourceLabel:(NSString *)sourceLabel anchor:(UIView *)anchor {
    if (!media) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"err_no_media")];
        return;
    }

    // Video wins — but only a real one. A video post also carries a poster photo,
    // and a photo post carries an empty video.
    IGVideo *video = nil;
    @try { video = SCISafeValueForKey(media, @"video"); } @catch (__unused id e) {}

    if ([self hasPlayableVideo:video]) {
        [SCIDiagnostics recordDownloadKind:@"video"];

        // Probed here rather than in -downloadVideo:, which never receives the
        // media object: the first attempt passed nil for it and so only ever
        // questioned IGVideo. Read-only — nothing downstream uses the result yet.
        NSMutableArray<NSString *> *candidates = [NSMutableArray array];
        for (id host in @[video, media]) {
            for (NSString *name in [SCIUtils selectorsMatching:@"dash" onObject:host]) {
                if (![candidates containsObject:name]) [candidates addObject:name];
            }
            for (NSString *name in [SCIUtils selectorsMatching:@"manifest" onObject:host]) {
                if (![candidates containsObject:name]) [candidates addObject:name];
            }
        }

        [SCIDiagnostics recordDashManifest:[SCIUtils dashManifestXMLForVideo:video media:media]
                                candidates:candidates];

        // Reel audio used to be offered by the long-press handler, which no longer
        // exists. The choice lives here now so the setting keeps working.
        NSURL *audioUrl = [SCIUtils getBoolPref:@"dw_reel_audio"]
            ? [SCIUtils getAudioUrlForMedia:media]
            : nil;

        if (audioUrl) {
            [self presentVideoOrAudioChoiceForVideo:video
                                           audioURL:audioUrl
                                        sourceLabel:sourceLabel
                                             anchor:anchor];
            return;
        }

        // Opt-in: when the only higher quality is AV1 (which iOS cannot save),
        // transcode it to H.264 on device. Falls back to the progressive
        // download on any failure, so this can never leave the user empty-handed.
        if ([self tryTranscodeForVideo:video media:media sourceLabel:sourceLabel]) {
            return;
        }

        [self downloadVideo:video sourceLabel:sourceLabel anchor:anchor];
        return;
    }

    //
    // **A video that cannot be resolved yet is not a photo, and this is the bug that
    // reached a device.** Saving a repost saved its cover image: the repost's IGMedia
    // is a stub built from `IGRepostModel`'s `mediaId`, so `+hasPlayableVideo:`
    // correctly answered NO while the cover photo resolved perfectly -- and the code
    // below read that NO as "therefore a photo".
    //
    // `+hasPlayableVideo:` answers "can I play one *now*". It never meant "this is not
    // a video", and only the photo branch's position made it mean that. The kind is
    // asked separately now, and a declared video that will not resolve says so instead
    // of quietly handing back a different file than the one that was asked for.
    //
    //
    // **A story's video is not on the object, it is in the dictionary.** A reel item's
    // `IGVideo` is a hollow shell — `+hasPlayableVideo:` above correctly answered NO —
    // but the item's own API dictionary still carries `video_versions` and
    // `video_dash_manifest`. Without this, a video story fell through to the photo branch
    // below and saved the poster frame, which is exactly the repost-cover bug wearing a
    // story's clothes. Tried before the photo branch so the video wins when there is one,
    // and only reached after the object path has already failed, so no post regresses.
    //
    NSURL *dictVideo = [SCIUtils videoURLFromMediaDict:[SCIUtils mediaDictionary:media]];
    if (dictVideo) {
        [SCIDiagnostics recordDownloadKind:@"video (from item dictionary)"];
        [self downloadURL:dictVideo sourceLabel:sourceLabel isVideo:YES];
        return;
    }

    NSString *signal = [self videoDeclarationSignalFor:media];
    if (signal) {
        // The signal is named, not just counted. "Declared but no rendition resolved"
        // was one sentence covering three different causes -- a duration with no
        // renditions, a manifest that would not parse, and a media type that says video
        // while nothing else does are three different bugs, and the next report should
        // not need a fourth round trip to say which.
        BOOL pending = [self mediaNeedsFetch:media];
        [SCIDiagnostics recordDownloadKind:[NSString stringWithFormat:@"video (%@) — %@",
            signal, pending ? @"not fetched yet, refused rather than saving the cover"
                            : @"no rendition resolved"]];

        [SCIUtils showErrorHUDWithDescription:SCILocalized(pending
            ? @"err_video_not_ready" : @"err_video_unresolved")];
        return;
    }

    NSURL *photoUrl = [SCIUtils getPhotoUrlForMedia:media];
    if (photoUrl) {
        [SCIDiagnostics recordDownloadKind:@"photo"];

        // A photo with music behind it — in reels or in the feed — loses the sound
        // when saved as a picture. Offered only when there is genuinely audio, so
        // an ordinary photo still downloads with one press and no questions.
        if ([SCIUtils getBoolPref:@"photo_as_video"]) {
            NSURL *audioUrl = [SCIUtils getAudioUrlForMedia:media];
            if (audioUrl) {
                // The choice is always offered — the setting decides whether the
                // clip is on the table, never that it is taken for granted.
                [SCIPhotoVideo offerForPhoto:photoUrl audio:audioUrl savePhoto:^{
                    [self downloadURL:photoUrl sourceLabel:sourceLabel isVideo:NO];
                }];
                return;
            }
        }

        [self downloadURL:photoUrl sourceLabel:sourceLabel isVideo:NO];
        return;
    }

    [SCIDiagnostics recordDownloadKind:@"neither — resolution failed"];

    [SCIUtils showErrorHUDWithDescription:SCILocalized(@"err_no_media")];
}

// MARK: - AV1 transcode

/// Attempts the on-device AV1→H.264 transcode when it would raise the quality and
/// the user has opted in. Returns YES if it took over the download (running in the
/// background), NO to let the normal progressive path proceed.
+ (BOOL)tryTranscodeForVideo:(IGVideo *)video media:(id)media sourceLabel:(NSString *)sourceLabel {
    if (![SCIUtils getBoolPref:@"dw_transcode_av1"]) return NO;

    // Opt-in: ask which resolution to take rather than always taking the tallest.
    // Off, this path is untouched and still picks the best automatically, which is
    // what the tweak is for; on, it is the user's call.
    if ([SCIUtils getBoolPref:@"dw_quality_picker"]) {
        NSArray<NSDictionary *> *options = [SCIUtils transcodeOptionsForVideo:video media:media];

        if (options.count > 1) {
            [SCIQualitySheet presentWithOptions:options chosen:^(long long height) {
                [self runTranscodeForVideo:video media:media sourceLabel:sourceLabel height:height];
            }];
            return YES;
        }
    }

    return [self runTranscodeForVideo:video media:media sourceLabel:sourceLabel height:0];
}

/// @param height  a chosen rung of the AV1 ladder, or zero for the tallest.
+ (BOOL)runTranscodeForVideo:(IGVideo *)video
                       media:(id)media
                 sourceLabel:(NSString *)sourceLabel
                      height:(long long)height {

    NSDictionary *plan = [SCIUtils transcodePlanForVideo:video media:media preferredHeight:height];
    if (!plan) return NO;

    NSString *title = [NSString stringWithFormat:SCILocalized(@"transcode_progress"),
                       [plan[@"width"] intValue], [plan[@"height"] intValue]];

    // Append the frame rate when known, e.g. "1440 × 2560 @ 60".
    int planFps = (int)round([plan[@"fps"] doubleValue]);
    if (planFps > 0) title = [title stringByAppendingFormat:@" @ %d", planFps];

    SCITranscodeBanner *banner = [SCITranscodeBanner shared];
    [banner showWithTitle:title];

    // Total frames from clip duration lets the banner show a real percentage.
    double duration = [plan[@"duration"] doubleValue];
    double fps = [plan[@"fps"] doubleValue];
    NSInteger totalFrames = (duration > 0 && fps > 0) ? (NSInteger)(duration * fps) : 0;

    // The transcode reports frame counts and "mux"; the banner turns them into a
    // bar the user can watch while scrolling, since it never blocks the app.
    void (^onProgress)(NSString *) = ^(NSString *status) {
        if ([status isEqualToString:@"mux"]) {
            [banner setDetail:SCILocalized(@"transcode_muxing") fraction:-1];
            return;
        }
        NSInteger frame = status.integerValue;
        NSString *detail = [NSString stringWithFormat:SCILocalized(@"transcode_frames"), (long)frame];
        float fraction = totalFrames > 0 ? (float)frame / (float)totalFrames : -1;
        [banner setDetail:detail fraction:fraction];
    };

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *out = [NSTemporaryDirectory() stringByAppendingPathComponent:
                         [[NSUUID UUID].UUIDString stringByAppendingPathExtension:@"mp4"]];

        BOOL ok = [SCIAV1Transcoder transcodeVideoURL:plan[@"videoURL"]
                                             audioURL:plan[@"audioURL"]
                                                  fps:[plan[@"fps"] doubleValue]
                                         toOutputPath:out
                                             progress:onProgress];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (ok) {
                [self saveTranscodedFileWithBanner:out banner:banner];
            } else {
                // The transcode named its failing stage in diagnostics; the user
                // still gets the progressive rendition.
                [banner finishWithSuccess:NO message:SCILocalized(@"transcode_fell_back")];
                [self downloadVideo:video sourceLabel:sourceLabel anchor:nil];
            }
        });
    });

    return YES;
}

+ (void)saveTranscodedFileWithBanner:(NSString *)path banner:(SCITranscodeBanner *)banner {
    [banner setDetail:SCILocalized(@"transcode_saving") fraction:-1];

    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:[NSURL fileURLWithPath:path]];
    } completionHandler:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
            [banner finishWithSuccess:success
                              message:success ? SCILocalized(@"transcode_saved")
                                              : (error.localizedDescription ?: SCILocalized(@"err_save_failed"))];
        });
    }];
}

// MARK: - On-screen story download

/// The section controller and model Instagram last said it was about to display.
/// Weak: they belong to the app, and a stale one simply fails the checks below.
static __weak id sciStorySection = nil;
static __weak id sciStoryModel = nil;
/// What the delegate handed over, kept as text. "Never told about a story" and "told,
/// and nothing on those objects answered" need opposite fixes and are indistinguishable
/// from two nil weak references.
static NSString *sciStoryNoted = nil;

+ (void)noteStorySection:(id)controller model:(id)model {
    sciStorySection = controller;
    sciStoryModel = model;

    sciStoryNoted = [NSString stringWithFormat:@"%@ / %@",
                     controller ? NSStringFromClass([controller class]) : @"nil",
                     model ? NSStringFromClass([model class]) : @"nil"];
}

+ (void)downloadVisibleStoryInView:(UIView *)root anchor:(UIView *)anchor {
    id media = [self currentStoryMediaInView:root];
    if (!media) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"err_no_media")];
        return;
    }

    [self downloadMedia:media sourceLabel:nil anchor:(anchor ?: root)];
}

/// Whether a candidate is something `+downloadMedia:` could actually resolve.
///
/// The delegate hands over a *model*, and on this app that is as likely to be the
/// whole reel as the item inside it -- so an unvalidated candidate risks saving a
/// tray's cover instead of the story on screen, which is the repost-cover bug for a
/// third time. A candidate earns its place by answering one of the three questions
/// the downloader itself asks, and nothing is handed on that answers none of them.
+ (BOOL)looksLikeStoryItem:(id)candidate {
    if (!candidate) return NO;

    if ([SCIUtils mediaDictionary:candidate]) return YES;
    if ([self videoDeclarationSignalFor:candidate]) return YES;

    IGVideo *video = nil;
    @try { video = SCISafeValueForKey(candidate, @"video"); } @catch (__unused id e) {}
    if ([self hasPlayableVideo:video]) return YES;

    @try { if ([SCIUtils getPhotoUrlForMedia:candidate]) return YES; } @catch (__unused id e) {}

    return NO;
}

/// The item the story viewer is showing, taken from the objects it handed us.
///
/// Every name here is tried behind `-respondsToSelector:` and the one that answered
/// is recorded, so a build that names it differently produces a report naming what it
/// *does* answer rather than a silent nil. The section controller is asked first: the
/// model may be the reel, and only an accessor whose name says "item" is trusted on it.
+ (id)storyItemFromDelegateObjectsRoute:(NSString **)route {
    id section = sciStorySection;
    id model = sciStoryModel;
    if (!section && !model) return nil;

    NSArray<NSString *> *names = @[@"currentStoryItem", @"storyItem", @"currentItem",
                                   @"currentReelItem", @"item"];

    for (id host in @[section ?: [NSNull null], model ?: [NSNull null]]) {
        if (host == [NSNull null]) continue;

        for (NSString *name in names) {
            @try {
                SEL selector = NSSelectorFromString(name);
                if (![host respondsToSelector:selector]) continue;

                id candidate = ((id (*)(id, SEL))objc_msgSend)(host, selector);
                if (![self looksLikeStoryItem:candidate]) continue;

                if (route) {
                    *route = [NSString stringWithFormat:@"%@ -%@",
                              NSStringFromClass([host class]), name];
                }
                return candidate;
            } @catch (__unused id e) {}
        }
    }

    // The model may itself be the item on a build that hands one over directly.
    if ([self looksLikeStoryItem:model]) {
        if (route) {
            *route = [NSString stringWithFormat:@"%@ (the model itself)",
                      NSStringFromClass([model class])];
        }
        return model;
    }

    return nil;
}

/// Locates the media of the story currently on screen. Adjacent stories are kept
/// mounted off-screen, so the candidate covering the viewer's centre wins.
+ (id)currentStoryMediaInView:(UIView *)root {
    NSString *route = nil;
    id fromDelegate = [self storyItemFromDelegateObjectsRoute:&route];
    if (fromDelegate) {
        [SCIDiagnostics recordStorySearchRoute:route classes:nil];
        return fromDelegate;
    }

    NSString *handed = sciStoryNoted
        ? [NSString stringWithFormat:@"nothing answered on %@", sciStoryNoted]
        : @"the viewer never named a story";

    if (!root) {
        [SCIDiagnostics recordStorySearchRoute:handed classes:nil];
        return nil;
    }

    CGPoint centre = CGPointMake(CGRectGetMidX(root.bounds), CGRectGetMidY(root.bounds));
    NSMutableArray<NSString *> *seen = [NSMutableArray array];
    id media = [self storyMediaSearchIn:root root:root centre:centre seen:seen];

    [SCIDiagnostics recordStorySearchRoute:(media
            ? [NSString stringWithFormat:@"found by searching the views (%@)", handed]
            : [NSString stringWithFormat:@"%@, and no view matched", handed])
                                   classes:seen];
    return media;
}

+ (id)storyMediaSearchIn:(UIView *)view
                    root:(UIView *)root
                  centre:(CGPoint)centre
                    seen:(NSMutableArray<NSString *> *)seen {
    if (!view) return nil;

    if (!view.hidden && view.alpha > 0.05 && !CGRectIsEmpty(view.bounds)) {
        BOOL coversCentre = CGRectContainsPoint([view convertRect:view.bounds toView:root], centre);
        NSString *cls = NSStringFromClass([view class]);

        //
        // **A hard-coded class list cannot show you the name you did not expect, and
        // this one matched nothing on 439.** `IGStoryModernVideoView` and
        // `IGStoryPhotoView` are still the names a same-generation reference uses, so
        // they stay first -- but any centre-covering view whose name mentions a story
        // is now asked as well, including a Swift-mangled `_TtC…Story…`, and every one
        // of them is recorded whether it answered or not. A device report then names
        // the real class instead of costing another round of guessing.
        //
        if (coversCentre && [cls rangeOfString:@"Story" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            if (![seen containsObject:cls]) [seen addObject:cls];

            for (NSString *name in @[@"item", @"storyItem", @"currentStoryItem", @"reelItem"]) {
                @try {
                    id item = SCISafeValueForKey(view, name);
                    if ([self looksLikeStoryItem:item]) return item;
                } @catch (__unused id e) {}
            }

            // The older build reaches its item through the caption delegate rather
            // than through a property of its own.
            @try {
                id caption = SCISafeValueForKey(view, @"captionDelegate");
                id item = caption ? SCISafeValueForKey(caption, @"currentStoryItem") : nil;
                if ([self looksLikeStoryItem:item]) return item;
            } @catch (__unused id e) {}
        }
    }

    for (UIView *sub in view.subviews) {
        id media = [self storyMediaSearchIn:sub root:root centre:centre seen:seen];
        if (media) return media;
    }

    return nil;
}

@end
