#import <objc/runtime.h>
#import "shared/src/SCIKVC.h"
#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../../Downloader/Download.h"
#import "../../Downloader/SCIMediaDownloader.h"
#import "../../Localization/SCILocalize.h"

///
/// Profile picture download and account-info copy.
///
/// The long-press download for feed posts, reels and stories was removed: the
/// inline download button covers posts and reels, and the story viewer has its
/// own button. Profile pictures have no action row to attach to, so they keep the
/// gesture.
///

static SCIDownloadDelegate *imageDownloadDelegate;

static void initDownloaders (void) {
    // Re-evaluated per download so a settings change applies without a restart.
    BOOL toPhotos = [SCIUtils getBoolPref:@"dw_save_to_camera"];

    imageDownloadDelegate = [[SCIDownloadDelegate alloc] initWithAction:(toPhotos ? saveToPhotos : quickLook)
                                                          showProgress:NO];
}

%hook IGProfilePictureImageView
- (void)didMoveToSuperview {
    %orig;

    // The long-press drives profile-picture saving, account-info copy and the
    // follow-status indicator — attach it if any of them is enabled.
    if ([SCIUtils getBoolPref:@"save_profile"]
        || [SCIUtils getBoolPref:@"copy_account_info"]
        || [SCIUtils getBoolPref:@"show_follow_status"]) {
        [self addLongPressGestureRecognizer];
    }

    return;
}
%new(v@:) - (void)addLongPressGestureRecognizer {
    // Once per view, not once per move.
    //
    // -didMoveToSuperview fires every time the view is re-parented, and the profile-picture
    // screens re-parent the avatar repeatedly -- so this stacked a new recogniser on the
    // same view each time, each one firing the same handler on a single long press.
    //
    // Marked with an associated flag rather than by scanning -gestureRecognizers for a long
    // press: Instagram attaches its own long presses to this view, and a scan cannot tell
    // one of those from ours without inspecting targets, which is not something a
    // recogniser exposes. A flag is exact and answers in one read.
    static const void *kAttachedKey = &kAttachedKey;
    if (objc_getAssociatedObject(self, kAttachedKey)) return;
    objc_setAssociatedObject(self, kAttachedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    SCILogV(@"[SCInsta] Adding profile picture long press gesture recognizer");

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    [self addGestureRecognizer:longPress];
}
%new(v@:@) - (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) return;

    NSURL *imageUrl = nil;
    IGUser *user = nil;

    // Resolve the underlying user object once.
    @try { user = SCISafeValueForKey(self, @"userGQL"); } @catch (__unused id e) {}
    if (!user) { @try { user = SCISafeValueForKey(self, @"user"); } @catch (__unused id e) {} }

    // 1) Prefer the full-resolution HD URL from the user object.
    @try {
        if ([user respondsToSelector:@selector(HDMultipleProfilePicURLs)]) {
            id variants = [user HDMultipleProfilePicURLs];
            if ([variants isKindOfClass:[NSArray class]] && [variants count] > 0) {
                id last = [variants lastObject];
                if ([last isKindOfClass:[NSURL class]]) imageUrl = last;
                else if ([last isKindOfClass:[NSString class]]) imageUrl = [NSURL URLWithString:last];
                else if ([last respondsToSelector:@selector(url)]) imageUrl = [last performSelector:@selector(url)];
            }
        }
        if (!imageUrl && [user respondsToSelector:@selector(HDProfilePicURL)]) {
            imageUrl = [user HDProfilePicURL];
        }
        if (!imageUrl && [user respondsToSelector:@selector(profilePicURL)]) {
            imageUrl = [user profilePicURL];
        }
    } @catch (__unused id e) {}

    // 2) Fall back to whatever the on-screen image view is displaying.
    if (!imageUrl) {
        IGImageView *_imageView = MSHookIvar<IGImageView *>(self, "_imageView");
        if (_imageView) {
            IGImageSpecifier *imageSpecifier = _imageView.imageSpecifier;
            if (imageSpecifier) imageUrl = imageSpecifier.url;
        }
    }

    BOOL copyInfoEnabled = [SCIUtils getBoolPref:@"copy_account_info"];
    BOOL followStatusEnabled = [SCIUtils getBoolPref:@"show_follow_status"];

    // When account-info copy or the follow-status feature is enabled and we have a
    // user, present a choice sheet. The follow-back relationship shows as the sheet
    // message ("Follows you" / "Doesn't follow you").
    if ((copyInfoEnabled || followStatusEnabled) && user) {
        NSString *followMsg = followStatusEnabled ? [SCIUtils followStatusStringForUser:user] : nil;

        UIAlertController *sheet = [UIAlertController alertControllerWithTitle:nil message:followMsg preferredStyle:UIAlertControllerStyleActionSheet];

        if (imageUrl) {
            NSURL *finalUrl = imageUrl;
            [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"info_download_pfp")
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction *a) {
                initDownloaders();
                [imageDownloadDelegate downloadFileWithURL:finalUrl
                                             fileExtension:[[finalUrl lastPathComponent] pathExtension]
                                                  hudLabel:SCILocalized(@"loading")];
            }]];
        }
        if (copyInfoEnabled) {
            [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"info_copy")
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction *a) {
                [SCIUtils copyAccountInfoForUser:user];
            }]];
        }
        [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel") style:UIAlertActionStyleCancel handler:nil]];

        sheet.popoverPresentationController.sourceView = self;
        sheet.popoverPresentationController.sourceRect = self.bounds;
        [topMostController() presentViewController:sheet animated:YES completion:nil];
        return;
    }

    if (!imageUrl) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"err_no_photo")];
        return;
    }

    // Download image & preview / save
    initDownloaders();
    [imageDownloadDelegate downloadFileWithURL:imageUrl
                                 fileExtension:[[imageUrl lastPathComponent] pathExtension]
                                      hudLabel:SCILocalized(@"loading")];
}
%end
