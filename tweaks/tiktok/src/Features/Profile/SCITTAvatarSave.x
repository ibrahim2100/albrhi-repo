//
//  SCITTAvatarSave.x
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "SCITTAvatarSave.h"
#import "../Download/SCITTDownload.h"
#import "../../UI/SCITTToast.h"
#import "../../Localization/SCILocalize.h"
#import "../../Prefs.h"
#import "../../SCILog.h"

///
/// **A Save button on the enlarged profile picture.**
///
/// `TTKEnlargeAvatarViewController` is the screen TikTok opens for a tapped avatar. It is handed an `AWEUserModel` by
/// `-configWithUserModel:` (`v24@0:8@16`), and the model carries the picture in four sizes, each an `AWEURLModel` with a `-URLList`:
/// `avatarLarger`, `avatar300`, `avatarMedium`, `avatarThumb` (all `@16@0:8` on `AWEUserModel` in 47.1.0). The links go to the same
/// saver the photo posts use, as **one picture offered several ways**, largest first -- that saver takes the first link whose bytes
/// actually decode and says which one it was.
///
/// The button is a view this code adds once per screen; nothing of TikTok's is moved or replaced. **Not run on a device.**
///

@interface TTKEnlargeAvatarViewController : UIViewController
@end

static NSString *sciAvatarState = nil;
static NSUInteger sciAvatarButtons = 0, sciAvatarSaves = 0, sciAvatarNoLinks = 0, sciAvatarLinksLast = 0;

static const void *kSCITTAvatarModelKey = &kSCITTAvatarModelKey;
static const void *kSCITTAvatarButtonKey = &kSCITTAvatarButtonKey;

static BOOL SCITTAvatarHas(Class cls, const char *selector, const char *encoding) {
    if (!cls) return NO;
    Method method = class_getInstanceMethod(cls, sel_registerName(selector));
    const char *types = method ? method_getTypeEncoding(method) : NULL;
    return types && strcmp(types, encoding) == 0;
}

static id SCITTAvatarObject(id object, NSString *name) {
    if (!object) return nil;
    SEL selector = NSSelectorFromString(name);
    Method method = class_getInstanceMethod(object_getClass(object), selector);
    const char *types = method ? method_getTypeEncoding(method) : NULL;
    if (!types || types[0] != '@') return nil;
    return ((id (*)(id, SEL))objc_msgSend)(object, selector);
}

/// Every address the user's picture is offered at, largest size first, without repeats.
static NSArray<NSURL *> *SCITTAvatarLinks(id user) {
    NSMutableArray<NSURL *> *links = [NSMutableArray array];
    for (NSString *size in @[@"avatarLarger", @"avatar300", @"avatarMedium", @"avatarThumb"]) {
        id list = SCITTAvatarObject(SCITTAvatarObject(user, size), @"URLList");
        if (![list isKindOfClass:[NSArray class]]) continue;
        for (id entry in (NSArray *)list) {
            NSURL *url = [entry isKindOfClass:[NSURL class]] ? entry
                       : ([entry isKindOfClass:[NSString class]] ? [NSURL URLWithString:entry] : nil);
            NSString *scheme = url.scheme.lowercaseString;
            if (!url || !([scheme isEqualToString:@"https"] || [scheme isEqualToString:@"http"])) continue;
            if (![links containsObject:url]) [links addObject:url];
        }
    }
    return links;
}

@interface SCITTAvatarTarget : NSObject
+ (instancetype)shared;
- (void)saveTapped:(UIButton *)button;
@end

@implementation SCITTAvatarTarget

+ (instancetype)shared {
    static SCITTAvatarTarget *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[SCITTAvatarTarget alloc] init]; });
    return shared;
}

- (void)saveTapped:(UIButton *)button {
    id user = objc_getAssociatedObject(button, kSCITTAvatarModelKey);
    NSArray<NSURL *> *links = SCITTAvatarLinks(user);
    sciAvatarLinksLast = links.count;
    if (!links.count) {
        sciAvatarNoLinks++;
        [SCITTToast noticeWithText:SCILocalized(@"avatar_none") symbol:@"questionmark.circle"];
        return;
    }
    sciAvatarSaves++;
    // One picture, several ways to fetch it: a single group.
    [SCITTDownload savePhotos:@[links]];
}

@end

%group SCITTAvatarSaveGroup
%hook TTKEnlargeAvatarViewController

- (void)configWithUserModel:(id)model {
    %orig;
    objc_setAssociatedObject(self, kSCITTAvatarModelKey, model, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UIButton *button = objc_getAssociatedObject(self, kSCITTAvatarButtonKey);
    if (button) objc_setAssociatedObject(button, kSCITTAvatarModelKey, model, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!SCIPrefEnabled(SCIPrefSaveAvatar)) {
        [(UIButton *)objc_getAssociatedObject(self, kSCITTAvatarButtonKey) setHidden:YES];
        return;
    }

    UIButton *button = objc_getAssociatedObject(self, kSCITTAvatarButtonKey);
    if (!button) {
        button = [UIButton buttonWithType:UIButtonTypeSystem];
        UIButtonConfiguration *config = [UIButtonConfiguration filledButtonConfiguration];
        config.title = SCILocalized(@"avatar_save");
        config.image = [UIImage systemImageNamed:@"arrow.down.circle.fill"];
        config.imagePadding = 6;
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        config.baseBackgroundColor = [UIColor colorWithWhite:0.12 alpha:0.78];
        config.baseForegroundColor = [UIColor whiteColor];
        config.contentInsets = NSDirectionalEdgeInsetsMake(10, 18, 10, 18);
        button.configuration = config;
        button.translatesAutoresizingMaskIntoConstraints = NO;
        [button addTarget:[SCITTAvatarTarget shared] action:@selector(saveTapped:) forControlEvents:UIControlEventTouchUpInside];
        objc_setAssociatedObject(button, kSCITTAvatarModelKey, objc_getAssociatedObject(self, kSCITTAvatarModelKey),
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, kSCITTAvatarButtonKey, button, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        [self.view addSubview:button];
        // Four-edge reasoning does not apply to a small control; centred and a fixed distance above the safe area is what is
        // true on every size of phone and in either layout direction.
        [NSLayoutConstraint activateConstraints:@[
            [button.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
            [button.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-28],
        ]];
        sciAvatarButtons++;
    }
    button.hidden = NO;
    [self.view bringSubviewToFront:button];
}

%end
%end

NSString *SCITTAvatarSaveReport(void) {
    return [NSString stringWithFormat:@"%@; buttons placed %lu; saves asked %lu (links in the last: %lu); no links %lu",
            sciAvatarState ?: @"not installed", (unsigned long)sciAvatarButtons, (unsigned long)sciAvatarSaves,
            (unsigned long)sciAvatarLinksLast, (unsigned long)sciAvatarNoLinks];
}

void SCITTInstallAvatarSave(void) {
    Class screen = NSClassFromString(@"TTKEnlargeAvatarViewController");
    if (SCITTAvatarHas(screen, "configWithUserModel:", "v24@0:8@16") && SCITTAvatarHas(screen, "viewDidAppear:", "v20@0:8B16")) {
        %init(SCITTAvatarSaveGroup);
        sciAvatarState = @"installed: TTKEnlargeAvatarViewController";
    } else {
        sciAvatarState = @"skipped: TTKEnlargeAvatarViewController -configWithUserModel: / -viewDidAppear:";
    }
    SCILogV(@"[AvatarSave] %@", sciAvatarState);
}
