#import "../../InstagramHeaders.h"
#import "shared/src/SCIKVC.h"
#import "../../Utils.h"
#import "../../Localization/SCILocalize.h"
#import "../../Downloader/SCIMediaDownloader.h"
#import <objc/runtime.h>
#import "../../Compat/SCIResolve.h"

///
/// Save button for DM photos & videos.
///
/// In IG 410 a permanent photo/video sent in a DM opens full-screen in
/// IGDirectMediaViewerViewController. Its initialiser hands over the photo and
/// video objects plus an `allowSavingMedia` flag the sender can switch off.
///
/// This forces `allowSavingMedia` on (so Instagram's own save works everywhere)
/// and adds an explicit Save button to the viewer, wired to the same download
/// coordinator the rest of the tweak uses — so the quality picker applies here too.
///

static const void *kSCIDMPhotoKey = &kSCIDMPhotoKey;
static const void *kSCIDMVideoKey = &kSCIDMVideoKey;
static const NSInteger kSCIDMSaveButtonTag = 0x5D115A;

%group SCIgIGDirectMediaViewerViewController

%hook IGDirectMediaViewerViewController

- (id)initWithPhoto:(id)photo
              video:(id)video
       previewImage:(id)previewImage
    backgroundColor:(id)backgroundColor
          messageId:(id)messageId
          threadKey:(id)threadKey
   allowSavingMedia:(BOOL)allowSavingMedia
   wasGeneratedByAI:(BOOL)wasGeneratedByAI
        productType:(long long)productType
        userSession:(id)userSession
             module:(id)module
threadSubscriptionService:(id)threadSubscriptionService {

    BOOL enabled = [SCIUtils getBoolPref:@"dm_media_save_button"];

    id vc = %orig(photo, video, previewImage, backgroundColor, messageId, threadKey,
                  enabled ? YES : allowSavingMedia,
                  wasGeneratedByAI, productType, userSession, module, threadSubscriptionService);

    if (vc && enabled) {
        // Stash the media so our button can download it directly.
        if (photo) objc_setAssociatedObject(vc, kSCIDMPhotoKey, photo, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (video) objc_setAssociatedObject(vc, kSCIDMVideoKey, video, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    return vc;
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    if (![SCIUtils getBoolPref:@"dm_media_save_button"]) return;
    [self sciAddDMSaveButton];
}

- (void)viewDidLayoutSubviews {
    %orig;

    if (![SCIUtils getBoolPref:@"dm_media_save_button"]) return;

    // The viewer mounts its media/overlay after appearing, which can bury our
    // button — (re)add it and keep it on top on every layout pass.
    [self sciAddDMSaveButton];
    UIView *button = [((IGDirectMediaViewerViewController *)self).view viewWithTag:kSCIDMSaveButtonTag];
    if (button) [((IGDirectMediaViewerViewController *)self).view bringSubviewToFront:button];
}

%new(v@:) - (void)sciAddDMSaveButton {
    if ([((IGDirectMediaViewerViewController *)self).view viewWithTag:kSCIDMSaveButtonTag]) return;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tag = kSCIDMSaveButtonTag;
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.35];
    button.layer.cornerRadius = 22.0;
    button.tintColor = [UIColor whiteColor];
    button.accessibilityLabel = SCILocalized(@"p_dm_save_t");

    UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:20.0 weight:UIImageSymbolWeightSemibold];
    [button setImage:[UIImage systemImageNamed:@"square.and.arrow.down" withConfiguration:config] forState:UIControlStateNormal];

    [button addTarget:self action:@selector(sciSaveDMMedia:) forControlEvents:UIControlEventTouchUpInside];

    [((IGDirectMediaViewerViewController *)self).view addSubview:button];

    [NSLayoutConstraint activateConstraints:@[
        [button.trailingAnchor constraintEqualToAnchor:((IGDirectMediaViewerViewController *)self).view.safeAreaLayoutGuide.trailingAnchor constant:-18.0],
        [button.bottomAnchor constraintEqualToAnchor:((IGDirectMediaViewerViewController *)self).view.safeAreaLayoutGuide.bottomAnchor constant:-24.0],
        [button.widthAnchor constraintEqualToConstant:44.0],
        [button.heightAnchor constraintEqualToConstant:44.0]
    ]];
}

%new(v@:@) - (void)sciSaveDMMedia:(UIButton *)sender {
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];

    id video = objc_getAssociatedObject(self, kSCIDMVideoKey);
    id photo = objc_getAssociatedObject(self, kSCIDMPhotoKey);

    // Fallback: read straight off the viewer if the init capture missed.
    if (!video) { @try { video = SCISafeValueForKey(self, @"video"); } @catch (__unused id e) {} }
    if (!photo) { @try { photo = SCISafeValueForKey(self, @"photo"); } @catch (__unused id e) {} }

    // Video wins — a video message may also carry a poster photo.
    if (video) {
        [SCIMediaDownloader downloadVideo:video sourceLabel:nil anchor:sender];
        return;
    }

    if (photo) {
        NSURL *url = [SCIUtils getPhotoUrl:photo];
        if (url) {
            [SCIMediaDownloader downloadURL:url sourceLabel:nil isVideo:NO];
            return;
        }
    }

    [SCIUtils showErrorHUDWithDescription:SCILocalized(@"err_no_media")];
}

%end

%end

%ctor {
    Class directMediaViewerViewController = SCIResolveClass(@"IGDirectMediaViewerViewController");
    if (directMediaViewerViewController) %init(SCIgIGDirectMediaViewerViewController, IGDirectMediaViewerViewController = directMediaViewerViewController);
}
