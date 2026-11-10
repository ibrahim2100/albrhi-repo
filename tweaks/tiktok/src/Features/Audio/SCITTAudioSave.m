//
//  SCITTAudioSave.m
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "SCITTAudioSave.h"
#import "../Download/SCITTDownload.h"
#import "../../Localization/SCILocalize.h"
#import "../../SCILog.h"
#import "shared/src/SCIFileName.h"
#import "../../UI/SCITTToast.h"

///
/// **Saving sound, not sending it.** 0.29.0 built "use a video's sound as a voice message" (a swap at `AVAudioRecorder -stop`), which is not what was asked
/// for; this is. Two rows in the menu the download button opens when held:
///
///   * **the video as audio** -- the video's own track (voice and music as TikTok mixed them) taken out as an `.m4a`, the whole length;
///   * **the post's sound on its own** -- `AWEAwemeModel.music.playURL`, the music or recording the post uses, as the file TikTok serves it.
///
/// **Neither goes to Photos, which does not take audio**: the file is handed to the share sheet, so it can go to Files, AirDrop, Voice Memos' share targets or any
/// app. Not run on a device -- the simulator copy is used to look at the menu and the sheet -- and the report counts each step.
///

/// The controller to present from: declared here as a category because it is a class method of the downloader that its header does not list.
@interface SCITTDownload (SCITTAudioPresenting)
+ (UIViewController *)topViewController;
@end

static NSUInteger sciAudioStarted = 0, sciAudioShared = 0, sciAudioFailed = 0, sciAudioNoSound = 0;
static NSString *sciAudioLast = nil, *sciAudioFailure = nil;
static BOOL sciAudioBusy = NO;

static void SCITTAudioFail(NSString *key, NSString *detail) {
    sciAudioFailed++;
    sciAudioBusy = NO;
    sciAudioFailure = detail ?: key;
    SCILogV(@"[Audio] failed: %@", sciAudioFailure);
    [SCITTToast finishWithText:SCILocalized(key) ok:NO];
}

/// The controller to present from. `+[SCITTDownload topViewController]` answers through the banner's host view, which is nil whenever no banner is
/// on screen (found by running it: the sheet had "nowhere to present"), so this asks the scenes' windows itself: the key window's root, else the
/// first window that has one, followed up through whatever is presented.
static UIViewController *SCITTAudioPresenter(void) {
    UIViewController *controller = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (!window.rootViewController || window.hidden) continue;
            if (window.isKeyWindow) { controller = window.rootViewController; break; }
            if (!controller) controller = window.rootViewController;
        }
        if (controller && ((UIWindowScene *)scene).keyWindow.rootViewController) break;
    }
    while (controller.presentedViewController) controller = controller.presentedViewController;
    return controller;
}

/// Opens the share sheet on the file. Main queue.
static void SCITTAudioShare(NSURL *file, NSString *label) {
    sciAudioBusy = NO;
    UIViewController *top = SCITTAudioPresenter() ?: [SCITTDownload topViewController];
    if (!top) {
        SCITTAudioFail(@"audio_failed", @"nowhere to present the share sheet");
        return;
    }
    [SCITTToast dismiss];
    UIActivityViewController *sheet = [[UIActivityViewController alloc] initWithActivityItems:@[file] applicationActivities:nil];
    sheet.popoverPresentationController.sourceView = top.view;
    sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(top.view.bounds), CGRectGetMidY(top.view.bounds), 1, 1);
    sheet.completionWithItemsHandler = ^(UIActivityType type, BOOL completed, NSArray *items, NSError *error) {
        [[NSFileManager defaultManager] removeItemAtURL:file error:NULL];   // the copy was only ever for the sheet
    };
    [top presentViewController:sheet animated:YES completion:nil];
    sciAudioShared++;
    sciAudioLast = label;
    SCILogV(@"[Audio] share sheet opened: %@ (%@)", label, file.lastPathComponent);
}

/// A file name a person can recognise in Files: `@account - the start of the caption - id.m4a` (SCIFileName, host-tested), and when the post says
/// nothing about itself, "TikTok audio <id>" as before.
static NSURL *SCITTAudioTarget(NSString *account, NSString *caption, NSString *itemID, NSString *kind, NSString *extension) {
    NSString *id8 = itemID.length ? itemID : [[NSUUID UUID].UUIDString substringToIndex:8];
    NSString *name = SCIFileNameBuild(account, caption, id8, extension, [NSString stringWithFormat:@"TikTok %@", kind]);
    return [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];
}

#pragma mark - The video as audio

static void SCITTAudioExport(NSURL *video, NSString *itemID, NSString *account, NSString *caption) {
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:video options:nil];
    if ([asset tracksWithMediaType:AVMediaTypeAudio].count == 0) {
        [[NSFileManager defaultManager] removeItemAtURL:video error:NULL];
        sciAudioNoSound++;
        SCITTAudioFail(@"audio_no_sound", @"the file has no audio track");
        return;
    }

    NSURL *output = SCITTAudioTarget(account, caption, itemID, @"audio", @"m4a");
    [[NSFileManager defaultManager] removeItemAtURL:output error:NULL];
    AVAssetExportSession *export = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPresetAppleM4A];
    if (!export) {
        [[NSFileManager defaultManager] removeItemAtURL:video error:NULL];
        SCITTAudioFail(@"audio_failed", @"no export session for the asset");
        return;
    }
    export.outputURL = output;
    export.outputFileType = AVFileTypeAppleM4A;
    [export exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSFileManager defaultManager] removeItemAtURL:video error:NULL];
            if (export.status != AVAssetExportSessionStatusCompleted) {
                SCITTAudioFail(@"audio_failed", export.error.localizedDescription ?: @"export did not complete");
                return;
            }
            SCITTAudioShare(output, @"video as audio (m4a)");
        });
    }];
}

/// Fetches the candidates in turn and stops at the first that arrives as a file with sound in it (a picture, or a silent rendition, goes to the next).
static void SCITTAudioFetchVideo(NSArray<NSURL *> *links, NSUInteger index, NSString *itemID, NSString *account, NSString *caption) {
    if (index >= links.count) {
        SCITTAudioFail(@"audio_failed", @"no link produced a file with sound");
        return;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:links[index]];
    [request setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 16_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.1 Mobile/15E148 Safari/604.1"
   forHTTPHeaderField:@"User-Agent"];

    [[[NSURLSession sharedSession] downloadTaskWithRequest:request completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)response statusCode] : 0;
        // Moved out of the system's own temporary spot before this block returns (it is deleted afterwards), under a name AVFoundation reads a container from.
        NSURL *kept = nil;
        if (!error && status == 200 && location) {
            kept = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"albrhi-source-%u.mp4", arc4random()]]];
            if (![[NSFileManager defaultManager] moveItemAtURL:location toURL:kept error:NULL]) kept = nil;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!kept) { SCITTAudioFetchVideo(links, index + 1, itemID, account, caption); return; }
            AVURLAsset *probe = [AVURLAsset URLAssetWithURL:kept options:nil];
            if ([probe tracksWithMediaType:AVMediaTypeAudio].count == 0) {
                [[NSFileManager defaultManager] removeItemAtURL:kept error:NULL];
                SCITTAudioFetchVideo(links, index + 1, itemID, account, caption);
                return;
            }
            SCITTAudioExport(kept, itemID, account, caption);
        });
    }] resume];
}

void SCITTAudioSaveVideoSound(SCITTMediaItem *item, NSString *account, NSString *caption) {
    SCILogV(@"[Audio] video sound asked: busy %d, links %lu", sciAudioBusy, (unsigned long)item.candidates.count);
    if (sciAudioBusy) return;
    NSArray<NSURL *> *links = item.candidates;
    if (!links.count) {
        sciAudioFailure = @"the video has no resolved link yet";
        sciAudioFailed++;
        [SCITTToast noticeWithText:SCILocalized(@"audio_nothing") symbol:@"questionmark.circle"];
        return;
    }
    sciAudioBusy = YES;
    sciAudioStarted++;
    [SCITTToast showText:SCILocalized(@"audiosave_working") symbol:@"waveform" progress:-1];
    SCITTAudioFetchVideo(links, 0, item.itemID, account, caption);
}

#pragma mark - The post's sound

void SCITTAudioSavePostSound(NSURL *sound, NSString *itemID, NSString *account, NSString *caption) {
    SCILogV(@"[Audio] post sound asked: busy %d, url %@", sciAudioBusy, sound.host);
    if (sciAudioBusy) return;
    if (!sound) {
        sciAudioNoSound++;
        [SCITTToast noticeWithText:SCILocalized(@"audio_no_post_sound") symbol:@"questionmark.circle"];
        return;
    }
    sciAudioBusy = YES;
    sciAudioStarted++;
    [SCITTToast showText:SCILocalized(@"audiosave_working") symbol:@"waveform" progress:-1];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:sound];
    [request setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 16_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.1 Mobile/15E148 Safari/604.1"
   forHTTPHeaderField:@"User-Agent"];
    [[[NSURLSession sharedSession] downloadTaskWithRequest:request completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)response statusCode] : 0;
        NSData *head = (!error && status == 200 && location) ? [NSData dataWithContentsOfURL:location options:NSDataReadingMappedIfSafe error:NULL] : nil;

        // The first bytes name the container: TikTok's music links carry an opaque path with no extension, so a name taken from the URL would be a guess.
        NSString *extension = @"mp3";
        const unsigned char *b = (const unsigned char *)head.bytes;
        if (head.length > 12) {
            if (!memcmp(b + 4, "ftyp", 4)) extension = @"m4a";
            else if (!memcmp(b, "ID3", 3) || (b[0] == 0xFF && (b[1] & 0xE0) == 0xE0)) extension = @"mp3";
            else if (!memcmp(b, "OggS", 4)) extension = @"ogg";
            else if (!memcmp(b, "RIFF", 4)) extension = @"wav";
        }
        NSURL *file = SCITTAudioTarget(account, caption, itemID, @"sound", extension);
        BOOL kept = head.length > 0;
        if (kept) {
            [[NSFileManager defaultManager] removeItemAtURL:file error:NULL];
            kept = [[NSFileManager defaultManager] moveItemAtURL:location toURL:file error:NULL];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!kept) { SCITTAudioFail(@"audio_failed", error.localizedDescription ?: [NSString stringWithFormat:@"HTTP %ld", (long)status]); return; }
            SCITTAudioShare(file, [NSString stringWithFormat:@"post sound (%@)", extension]);
        });
    }] resume];
}

NSString *SCITTAudioReport(void) {
    return [NSString stringWithFormat:@"started %lu, shared %lu (last: %@), no sound to take %lu, failed %lu%@",
            (unsigned long)sciAudioStarted, (unsigned long)sciAudioShared, sciAudioLast ?: @"—", (unsigned long)sciAudioNoSound,
            (unsigned long)sciAudioFailed, sciAudioFailure ? [@"; last failure: " stringByAppendingString:sciAudioFailure] : @""];
}
