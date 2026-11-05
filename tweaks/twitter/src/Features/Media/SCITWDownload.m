#import "shared/src/SCIMediaSniff.h"
#import "SCITWDownload.h"
#import "Localization/SCILocalize.h"
#import "SCILog.h"
#import "modules/JGProgressHUD/JGProgressHUD.h"
#import <Photos/Photos.h>

@interface SCITWDownload () <NSURLSessionDownloadDelegate>
@property (nonatomic, strong) SCITWMediaItem *item;
@property (nonatomic, strong) JGProgressHUD *hud;
@property (nonatomic, strong) NSURLSession *session;
@end


/// Kept alive by hand while it runs.
///
/// An NSURLSession retains its delegate, but the object here is created by a class method
/// and nothing else refers to it -- so without this it is released the moment `+save:`
/// returns, and the download stops with no error and no callback. That failure looks
/// exactly like the network being slow, which is why it costs an afternoon to find.
static NSMutableSet<SCITWDownload *> *_running = nil;

@implementation SCITWDownload

+ (void)save:(SCITWMediaItem *)item {
    if (!item.url) return;

    // Asked before the work, not after. A download that finishes and then discovers it may
    // not write anywhere has spent someone's data for nothing, and on a slow connection the
    // prompt arrives long after the tap that caused it and reads as unrelated.
    [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly
                                                handler:^(PHAuthorizationStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (status != PHAuthorizationStatusAuthorized &&
                status != PHAuthorizationStatusLimited) {
                [self report:SCILocalized(@"save_no_permission") ok:NO];
                return;
            }
            [self start:item];
        });
    }];
}

+ (void)start:(SCITWMediaItem *)item {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        _running = [NSMutableSet set];
    });

    SCITWDownload *download = [[SCITWDownload alloc] init];
    download.item = item;

    UIView *host = [self host];
    if (host) {
        JGProgressHUD *hud = [[JGProgressHUD alloc] initWithStyle:JGProgressHUDStyleDark];
        hud.indicatorView = [[JGProgressHUDPieIndicatorView alloc] init];
        hud.textLabel.text = SCILocalized(@"save_working");
        hud.progress = 0;
        [hud showInView:host];
        download.hud = hud;
    }

    NSURLSessionConfiguration *configuration =
        [NSURLSessionConfiguration defaultSessionConfiguration];

    // The delegate queue is not the main one: progress arrives many times a second and
    // every callback below hops to main itself only where it touches a view. Handing the
    // whole stream to the main queue makes X stutter while a large video downloads, which
    // is the tweak being blamed for the app being slow.
    download.session = [NSURLSession sessionWithConfiguration:configuration
                                                     delegate:download
                                                delegateQueue:nil];

    @synchronized (_running) { [_running addObject:download]; }

    [[download.session downloadTaskWithURL:item.url] resume];
    SCILogV(@"downloading %@", item.url);
}

/// Where a progress view can be put so it is on top of X rather than under it.
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
        [self.hud setProgress:(float)fraction animated:YES];
    });
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)task
didFinishDownloadingToURL:(NSURL *)location {
    // An HTTP error answers with a body like any other response and NSURLSession hands it over as
    // a successful download: a 403 or a 404 arrives here as a small page named like a video, which
    // Photos then refuses for a reason that says nothing about the real one.
    if ([task.response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSInteger status = ((NSHTTPURLResponse *)task.response).statusCode;
        if (status < 200 || status >= 300) {
            SCILogV(@"download refused: HTTP %ld", (long)status);
            [[NSFileManager defaultManager] removeItemAtURL:location error:NULL];
            [self finish:NO message:SCILocalized(@"save_failed")];
            return;
        }
    }

    // Moved out of the temporary location before this method returns, because iOS deletes
    // it the moment it does. Named with the right extension: Photos rejects a video handed
    // to it under the wrong one, and rejects it quietly.
    NSString *name = [NSString stringWithFormat:@"albrhi-%@.%@",
        [[NSUUID UUID] UUIDString], self.item.fileExtension];
    NSURL *staged = [NSURL fileURLWithPath:
        [NSTemporaryDirectory() stringByAppendingPathComponent:name]];

    [[NSFileManager defaultManager] removeItemAtURL:staged error:NULL];

    NSError *move = nil;
    if (![[NSFileManager defaultManager] moveItemAtURL:location toURL:staged error:&move]) {
        [self finish:NO message:SCILocalized(@"save_failed")];
        return;
    }

    // And looked at: a 200 with a web page in it is still not a video.
    SCIMediaKind seen = SCIMediaKindUnknown;
    if (!SCIMediaFileLooksFinished(staged, &seen)) {
        SCILogV(@"download refused: the file is %@", SCIMediaKindDescription(seen));
        [[NSFileManager defaultManager] removeItemAtURL:staged error:NULL];
        [self finish:NO message:SCILocalized(@"save_failed")];
        return;
    }

    BOOL isImage = (self.item.kind == SCITWMediaKindImage);

    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        if (isImage) {
            [PHAssetCreationRequest creationRequestForAssetFromImageAtFileURL:staged];
        } else {
            [PHAssetCreationRequest creationRequestForAssetFromVideoAtFileURL:staged];
        }
    } completionHandler:^(BOOL success, NSError *error) {
        [[NSFileManager defaultManager] removeItemAtURL:staged error:NULL];

        if (!success) SCILogV(@"photos refused: %@", error);
        [self finish:success message:SCILocalized(success ? @"save_done" : @"save_failed")];
    }];
}

- (void)URLSession:(NSURLSession *)session
                    task:(NSURLSessionTask *)task
    didCompleteWithError:(NSError *)error {
    // Only the failing case. The success path has already finished in the method above, and
    // reporting from both would show a tick and then an error for one download.
    if (error) [self finish:NO message:SCILocalized(@"save_failed")];
}

- (void)finish:(BOOL)success message:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.hud dismissAnimated:NO];
        self.hud = nil;

        [SCITWDownload report:message ok:success];

        [self.session invalidateAndCancel];
        @synchronized (_running) { [_running removeObject:self]; }
    });
}

+ (void)report:(NSString *)message ok:(BOOL)ok {
    UIView *host = [self host];
    if (!host) return;

    JGProgressHUD *hud = [[JGProgressHUD alloc] initWithStyle:JGProgressHUDStyleDark];
    hud.indicatorView = ok
        ? [[JGProgressHUDSuccessIndicatorView alloc] init]
        : [[JGProgressHUDErrorIndicatorView alloc] init];
    hud.textLabel.text = message;

    [hud showInView:host];
    [hud dismissAfterDelay:2.0];
}

@end
