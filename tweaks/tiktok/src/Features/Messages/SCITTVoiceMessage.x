//
//  SCITTVoiceMessage.x
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import <string.h>
#import "SCITTVoiceMessage.h"
#import "../../Prefs.h"
#import "../../SCILog.h"
#import "../../Localization/SCILocalize.h"
#import "../../UI/SCITTToast.h"

///
/// **A video's sound sent as a voice message.**
///
/// From VibeTok's table (unlicensed; architecture only, CLAUDE.md §2 -- the owner allowed copying, a licence is the author's to give, so this is written
/// here). Its shape is two halves: turn a video into an `.m4a`, and when TikTok's voice recorder stops, put that file where the recording was.
///
/// **What differs here, deliberately:**
///   * It starts from the video the person is looking at (the menu the download button opens when held), not from a file picker, so no
///     photo-library or document permission is involved and the file is one this tweak fetched itself.
///   * **The swap is armed by a choice and happens once.** VibeTok's switch is a standing preference: every recording made while it is on is replaced,
///     which is how a person records a real voice message and sends a movie's dialogue. Here the sound is prepared by an explicit act, expires after
///     fifteen minutes, is used up by the first recording that stops, and the banner says each of those three things.
///   * The sound is cut at sixty seconds (TikTok's own limit for a recorded voice message is not read from the binary; sixty is what a person can
///     record), and the banner says when it was cut.
///
/// **Not run on a device**: the swap needs a direct-message recorder, and the copy of TikTok that runs here has no account. The report names the
/// extension of the file it replaced, so a recorder that writes a format TikTok then refuses is traceable from one report.
///

static const NSTimeInterval kSCITTVoiceMaxSeconds = 60;
static const NSTimeInterval kSCITTVoiceArmedFor = 15 * 60;

static NSString *sciVoicePath = nil;          // the prepared .m4a, nil when nothing is armed
static NSDate *sciVoiceArmedAt = nil;
static BOOL sciVoiceBusy = NO;
static NSUInteger sciVoicePrepared = 0, sciVoiceFailed = 0, sciVoiceReplaced = 0, sciVoiceStops = 0, sciVoiceExpired = 0;
static NSString *sciVoiceLastFailure = nil, *sciVoiceLastExtension = nil, *sciVoiceState = nil;

static NSString *SCITTVoiceFolder(void) {
    NSString *base = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject ?: NSTemporaryDirectory();
    NSString *folder = [base stringByAppendingPathComponent:@"AlbrhiTikTok"];
    [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
    return folder;
}

BOOL SCITTVoiceIsArmed(void) {
    if (!sciVoicePath) return NO;
    if (sciVoiceArmedAt && -[sciVoiceArmedAt timeIntervalSinceNow] > kSCITTVoiceArmedFor) {
        sciVoiceExpired++;
        SCITTVoiceDisarm();
        return NO;
    }
    return [[NSFileManager defaultManager] fileExistsAtPath:sciVoicePath];
}

void SCITTVoiceDisarm(void) {
    if (sciVoicePath) [[NSFileManager defaultManager] removeItemAtPath:sciVoicePath error:NULL];
    sciVoicePath = nil;
    sciVoiceArmedAt = nil;
}

static void SCITTVoiceFail(NSString *reasonKey, NSString *detail) {
    sciVoiceFailed++;
    sciVoiceBusy = NO;
    sciVoiceLastFailure = detail ?: reasonKey;
    [SCITTToast finishWithText:SCILocalized(reasonKey) ok:NO];
}

/// Takes the sound of a local video file as `voice.m4a` and arms it. Main-queue callbacks only.
static void SCITTVoiceExport(NSURL *video) {
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:video options:nil];
    if ([asset tracksWithMediaType:AVMediaTypeAudio].count == 0) {
        [[NSFileManager defaultManager] removeItemAtURL:video error:NULL];
        SCITTVoiceFail(@"voice_no_audio", @"the file has no audio track");
        return;
    }

    NSString *output = [SCITTVoiceFolder() stringByAppendingPathComponent:@"voice.m4a"];
    [[NSFileManager defaultManager] removeItemAtPath:output error:NULL];

    AVAssetExportSession *export = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPresetAppleM4A];
    if (!export) {
        [[NSFileManager defaultManager] removeItemAtURL:video error:NULL];
        SCITTVoiceFail(@"voice_failed", @"no export session for the asset");
        return;
    }
    export.outputURL = [NSURL fileURLWithPath:output];
    export.outputFileType = AVFileTypeAppleM4A;

    double seconds = CMTimeGetSeconds(asset.duration);
    BOOL cut = seconds > kSCITTVoiceMaxSeconds;
    if (cut) export.timeRange = CMTimeRangeMake(kCMTimeZero, CMTimeMakeWithSeconds(kSCITTVoiceMaxSeconds, 600));

    [SCITTToast showText:SCILocalized(@"voice_working") symbol:@"waveform" progress:-1];
    [export exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSFileManager defaultManager] removeItemAtURL:video error:NULL];
            if (export.status != AVAssetExportSessionStatusCompleted) {
                SCITTVoiceFail(@"voice_failed", export.error.localizedDescription ?: @"export did not complete");
                return;
            }
            sciVoicePath = output;
            sciVoiceArmedAt = [NSDate date];
            sciVoicePrepared++;
            sciVoiceBusy = NO;
            [SCITTToast finishWithText:SCILocalized(cut ? @"voice_armed_cut" : @"voice_armed") ok:YES];
        });
    }];
}

/// Fetches the candidates in turn and stops at the first that arrives as a file with sound in it.
static void SCITTVoiceFetch(NSArray<NSURL *> *links, NSUInteger index) {
    if (index >= links.count) {
        SCITTVoiceFail(@"voice_failed", @"no link produced a file");
        return;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:links[index]];
    [request setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 16_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.1 Mobile/15E148 Safari/604.1"
   forHTTPHeaderField:@"User-Agent"];

    NSURLSessionDownloadTask *task = [[NSURLSession sharedSession] downloadTaskWithRequest:request
                                                                         completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)response statusCode] : 0;
        // The file is moved out of the system's temporary spot before this block returns (it is deleted afterwards), and given an extension
        // AVFoundation recognises: it reads the container from the name.
        NSURL *kept = nil;
        if (!error && status == 200 && location) {
            kept = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:
                                           [NSString stringWithFormat:@"albrhi-voice-%u.mp4", arc4random()]]];
            if (![[NSFileManager defaultManager] moveItemAtURL:location toURL:kept error:NULL]) kept = nil;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!kept) {
                SCITTVoiceFetch(links, index + 1);
                return;
            }
            AVURLAsset *probe = [AVURLAsset URLAssetWithURL:kept options:nil];
            if ([probe tracksWithMediaType:AVMediaTypeAudio].count == 0) {
                [[NSFileManager defaultManager] removeItemAtURL:kept error:NULL];
                SCITTVoiceFetch(links, index + 1);   // this link was a picture or a silent rendition: the next may carry the sound
                return;
            }
            SCITTVoiceExport(kept);
        });
    }];
    [task resume];
}

void SCITTVoicePrepareFromItem(SCITTMediaItem *item) {
    if (sciVoiceBusy) return;
    NSArray<NSURL *> *links = item.candidates;
    if (!links.count) {
        sciVoiceLastFailure = @"the video has no resolved link yet";
        sciVoiceFailed++;
        [SCITTToast noticeWithText:SCILocalized(@"voice_nothing") symbol:@"questionmark.circle"];
        return;
    }
    sciVoiceBusy = YES;
    SCITTVoiceDisarm();
    [SCITTToast showText:SCILocalized(@"voice_working") symbol:@"waveform" progress:-1];
    SCITTVoiceFetch(links, 0);
}

%group SCITTVoiceGroup
%hook AVAudioRecorder

- (void)stop {
    %orig;
    sciVoiceStops++;
    if (!SCIPrefEnabled(SCIPrefVoiceFromVideo) || !SCITTVoiceIsArmed()) return;

    NSURL *target = self.url;
    NSFileManager *files = [NSFileManager defaultManager];
    if (![target isFileURL] || ![files fileExistsAtPath:target.path]) return;   // not a file recording: leave it, stay armed

    NSError *failure = nil;
    [files removeItemAtURL:target error:NULL];
    BOOL copied = [files copyItemAtPath:sciVoicePath toPath:target.path error:&failure];
    sciVoiceLastExtension = target.pathExtension.length ? target.pathExtension : @"(none)";
    if (!copied) {
        sciVoiceFailed++;
        sciVoiceLastFailure = failure.localizedDescription ?: @"copy over the recording failed";
        return;
    }
    sciVoiceReplaced++;
    SCITTVoiceDisarm();
    dispatch_async(dispatch_get_main_queue(), ^{
        [SCITTToast noticeWithText:SCILocalized(@"voice_replaced") symbol:@"waveform.badge.mic"];
    });
}

%end
%end

NSString *SCITTVoiceReport(void) {
    return [NSString stringWithFormat:
            @"%@; armed: %@; prepared %lu, replaced a recording %lu (last file extension: %@), recorder stops seen %lu, expired %lu, failed %lu%@",
            sciVoiceState ?: @"not installed", SCITTVoiceIsArmed() ? @"yes" : @"no",
            (unsigned long)sciVoicePrepared, (unsigned long)sciVoiceReplaced, sciVoiceLastExtension ?: @"—",
            (unsigned long)sciVoiceStops, (unsigned long)sciVoiceExpired, (unsigned long)sciVoiceFailed,
            sciVoiceLastFailure ? [@"; last failure: " stringByAppendingString:sciVoiceLastFailure] : @""];
}

void SCITTInstallVoiceMessage(void) {
    Method method = class_getInstanceMethod([AVAudioRecorder class], @selector(stop));
    const char *types = method ? method_getTypeEncoding(method) : NULL;
    if (!types || strcmp(types, "v16@0:8") != 0) {
        sciVoiceState = @"skipped: AVAudioRecorder -stop not found";
        SCILogV(@"[Voice] %@", sciVoiceState);
        return;
    }
    %init(SCITTVoiceGroup);
    sciVoiceState = @"installed: AVAudioRecorder -stop";
    SCILogV(@"[Voice] %@", sciVoiceState);
}
