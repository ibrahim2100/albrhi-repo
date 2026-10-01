#import "SCIYTThumbnails.h"
#import "SCIYTLibrary.h"
#import "../../../Prefs.h"
#import "../../../SCILog.h"
#import <AVFoundation/AVFoundation.h>

@implementation SCIYTThumbnails

+ (NSURL *)folder {
    static NSURL *folder = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        folder = [[SCIYTLibrary folder] URLByAppendingPathComponent:@".thumbnails" isDirectory:YES];
        [[NSFileManager defaultManager] createDirectoryAtURL:folder
                                withIntermediateDirectories:YES
                                                 attributes:nil
                                                      error:nil];
    });
    return folder;
}

+ (NSURL *)fileFor:(SCIYTJob *)job {
    return [[self folder] URLByAppendingPathComponent:
        [job.identifier stringByAppendingPathExtension:@"jpg"]];
}

+ (UIImage *)cached:(SCIYTJob *)job {
    if (!job.identifier.length) return nil;
    return [UIImage imageWithContentsOfFile:[self fileFor:job].path];
}

+ (void)forget:(SCIYTJob *)job {
    if (!job.identifier.length) return;
    [[NSFileManager defaultManager] removeItemAtURL:[self fileFor:job] error:nil];
}

/// A saved song's cover, fetched from YouTube's own still for that video.
///
/// A sound file has no picture inside it, so an audio row used to be a music-note glyph and
/// the player behind it was flat black. The video it came from has a cover and we kept its
/// id, so there is one to fetch -- and once fetched it is the same cached file every other
/// row uses, so the list, the player and the lock screen all get it at once.
+ (void)fetchCoverFor:(SCIYTJob *)job completion:(void (^)(UIImage *))completion {
    if (!job.videoID.length || [self cached:job]) return;

    // Two sizes, in order. Not every video has a maximum-resolution still -- older and
    // lower-quality uploads simply do not -- and asking for one that is not there returns a
    // placeholder rather than an error, so the smaller one is the safe second try.
    NSArray<NSString *> *names = @[@"maxresdefault", @"hqdefault"];

    for (NSString *name in names) {
        NSString *text = [NSString stringWithFormat:@"https://i.ytimg.com/vi/%@/%@.jpg",
                          job.videoID, name];
        NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:text]];
        UIImage *image = data.length ? [UIImage imageWithData:data] : nil;

        // YouTube answers a missing still with a small grey placeholder rather than a 404,
        // so the size is the test: a real cover is never 120 across.
        if (image.size.width < 200) continue;

        [data writeToURL:[self fileFor:job] atomically:YES];

        // Kept beside the file and never written into it: everything on screen reads this copy,
        // and rewriting a song to tag it was the one operation here that could lose the song
        // (the switch for it shipped off, then was removed in 1.37.0 -- see the changelog).

        dispatch_async(dispatch_get_main_queue(), ^{ completion(image); });
        return;
    }
}

+ (void)prepare:(SCIYTJob *)job completion:(void (^)(UIImage *))completion {
    NSURL *source = [job fileURL];
    if (!source) return;

    // Already done, and the length with it. Nothing to open.
    if (job.duration > 0 && (job.kind == SCIYTJobKindAudio || [self cached:job])) return;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:source options:nil];

        // Loaded before it is asked anything. A raw AAC file has no index and will not
        // state its length until it has been read through -- the same fact that made the
        // composition refuse an invalid range in 0.12.5.
        [asset loadValuesAsynchronouslyForKeys:@[@"tracks", @"duration"] completionHandler:^{
            double seconds = CMTIME_IS_NUMERIC(asset.duration) ? CMTimeGetSeconds(asset.duration) : 0;
            if (seconds > 0) job.duration = seconds;

            if (job.kind == SCIYTJobKindAudio || [asset tracksWithMediaType:AVMediaTypeVideo].count == 0) {
                // No picture inside, so the cover comes from where the sound came from.
                [self fetchCoverFor:job completion:completion];

                if (seconds > 0) {
                    dispatch_async(dispatch_get_main_queue(), ^{ completion(nil); });
                }
                return;
            }

            AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
            generator.appliesPreferredTrackTransform = YES;
            generator.maximumSize = CGSizeMake(480, 480);

            // A second in, not the first frame: videos open on black, on a fade, or on a
            // title card often enough that frame zero is the least useful picture in the
            // file. Clamped for anything shorter than that.
            CMTime at = CMTimeMakeWithSeconds(MIN(1.0, MAX(seconds - 0.1, 0)), 600);

            NSError *error = nil;
            CGImageRef frame = [generator copyCGImageAtTime:at actualTime:NULL error:&error];
            if (!frame) {
                SCILogV(@"thumbnails: no frame — %@", error.localizedDescription);
                return;
            }

            UIImage *image = [UIImage imageWithCGImage:frame];
            CGImageRelease(frame);

            NSData *jpeg = UIImageJPEGRepresentation(image, 0.8);
            if (jpeg.length) [jpeg writeToURL:[self fileFor:job] atomically:YES];

            dispatch_async(dispatch_get_main_queue(), ^{ completion(image); });
        }];
    });
}

+ (NSString *)clock:(double)seconds {
    if (seconds <= 0 || !isfinite(seconds)) return @"--:--";

    NSInteger whole = (NSInteger)seconds;
    NSInteger hours = whole / 3600;
    NSInteger minutes = (whole % 3600) / 60;
    NSInteger rest = whole % 60;

    return hours > 0
        ? [NSString stringWithFormat:@"%ld:%02ld:%02ld", (long)hours, (long)minutes, (long)rest]
        : [NSString stringWithFormat:@"%ld:%02ld", (long)minutes, (long)rest];
}

@end
