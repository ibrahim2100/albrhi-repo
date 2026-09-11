#import "Utils.h"
#import "shared/src/SCIKVC.h"
#import "shared/src/SCIPanelGate.h"
#import <os/lock.h>
#import "UI/SCIConfirmSheet.h"
#import "Settings/SCIDiagnosticsViewController.h"
#import <objc/runtime.h>

// Delegate that persists the chosen accent color as a hex string.
@interface SCIAccentPickerDelegate : NSObject <UIColorPickerViewControllerDelegate>
@end

@implementation SCIAccentPickerDelegate
- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)viewController API_AVAILABLE(ios(14.0)) {
    NSString *hex = [SCIUtils hexStringFromColor:viewController.selectedColor];
    if (hex) [[NSUserDefaults standardUserDefaults] setObject:hex forKey:@"albrhi_accent_hex"];
}
- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController API_AVAILABLE(ios(14.0)) {
    NSString *hex = [SCIUtils hexStringFromColor:viewController.selectedColor];
    if (hex) [[NSUserDefaults standardUserDefaults] setObject:hex forKey:@"albrhi_accent_hex"];
    [SCIUtils showSuccessHUDWithDescription:SCILocalized(@"accent_color_title")];
}
@end

@implementation SCIUtils

///
/// Switches are read constantly — several of these hooks run inside -layoutSubviews,
/// so a scrolling feed asks the same handful of questions tens of times a second, and
/// each answer used to cost two trips into NSUserDefaults. The answers are kept here
/// instead and thrown away whenever anything writes to defaults, so a setting still
/// takes effect the moment it is changed.
///
/// os_unfair_lock rather than @synchronized: this sits on the drawing path, and the
/// lock is held only long enough to read or write one dictionary entry.
static NSMutableDictionary<NSString *, NSNumber *> *sBoolPrefCache = nil;
static os_unfair_lock sBoolPrefLock = OS_UNFAIR_LOCK_INIT;

+ (void)load {
    [[NSNotificationCenter defaultCenter] addObserverForName:NSUserDefaultsDidChangeNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(__unused NSNotification *note) {
        os_unfair_lock_lock(&sBoolPrefLock);
        [sBoolPrefCache removeAllObjects];
        os_unfair_lock_unlock(&sBoolPrefLock);
    }];
}

+ (BOOL)getBoolPref:(NSString *)key {
    if (![key length]) return false;

    // The panel's per-app switch, asked before anything else and before the cache.
    //
    // Every feature in this tweak reaches its setting through here -- 227 call sites --
    // so one line disables all of them at once. Nothing is uninstalled and no hook is
    // skipped: the hooks stay in place and answer %orig, which is the only way to stand
    // down that cannot leave the app half-patched.
    if (!SCIPanelAllowsThisApp()) return false;

    os_unfair_lock_lock(&sBoolPrefLock);
    NSNumber *cached = sBoolPrefCache[key];
    os_unfair_lock_unlock(&sBoolPrefLock);

    if (cached) return cached.boolValue;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL value = ([defaults objectForKey:key] != nil) && [defaults boolForKey:key];

    os_unfair_lock_lock(&sBoolPrefLock);
    if (!sBoolPrefCache) sBoolPrefCache = [NSMutableDictionary dictionary];
    sBoolPrefCache[key] = @(value);
    os_unfair_lock_unlock(&sBoolPrefLock);

    return value;
}
+ (double)getDoublePref:(NSString *)key {
    if (![key length] || [[NSUserDefaults standardUserDefaults] objectForKey:key] == nil) return 0;

    return [[NSUserDefaults standardUserDefaults] doubleForKey:key];
}
+ (NSString *)getStringPref:(NSString *)key {
    if (![key length] || [[NSUserDefaults standardUserDefaults] objectForKey:key] == nil) return @"";

    return [[NSUserDefaults standardUserDefaults] stringForKey:key];
}


+ (void)cleanCache {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSMutableArray<NSError *> *deletionErrors = [NSMutableArray array];

    // Temp folder
    // * disabled bc app crashed trying to delete certain files inside it
    // todo: remove the above disclaimer if this new code doesn't cause crashing
    NSArray *tempFolderContents = [fileManager contentsOfDirectoryAtURL:[NSURL fileURLWithPath:NSTemporaryDirectory()] includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];

    for (NSURL *fileURL in tempFolderContents) {
        NSError *cacheItemDeletionError;
        [fileManager removeItemAtURL:fileURL error:&cacheItemDeletionError];

        if (cacheItemDeletionError) [deletionErrors addObject:cacheItemDeletionError];
    }

    // Analytics folder
    NSString *analyticsFolder = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"Application Support/com.burbn.instagram/analytics"];
    NSArray *analyticsFolderContents = [fileManager contentsOfDirectoryAtURL:[[NSURL alloc] initFileURLWithPath:analyticsFolder] includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];

    for (NSURL *fileURL in analyticsFolderContents) {
        NSError *cacheItemDeletionError;
        [fileManager removeItemAtURL:fileURL error:&cacheItemDeletionError];

        if (cacheItemDeletionError) [deletionErrors addObject:cacheItemDeletionError];
    }
    
    // Caches folder
    NSString *cachesFolder = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"Caches"];
    NSArray *cachesFolderContents = [fileManager contentsOfDirectoryAtURL:[[NSURL alloc] initFileURLWithPath:cachesFolder] includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    
    for (NSURL *fileURL in cachesFolderContents) {
        NSError *cacheItemDeletionError;
        [fileManager removeItemAtURL:fileURL error:&cacheItemDeletionError];

        if (cacheItemDeletionError) [deletionErrors addObject:cacheItemDeletionError];
    }

    // Log errors
    if (deletionErrors.count > 1) {

        for (NSError *error in deletionErrors) {
            SCILogV(@"[SCInsta] File Deletion Error: %@", error);
        }

    }

}

// Displaying View Controllers
+ (void)showQuickLookVC:(NSArray<id> *)items {
    QLPreviewController *previewController = [[QLPreviewController alloc] init];
    QuickLookDelegate *quickLookDelegate = [[QuickLookDelegate alloc] initWithPreviewItemURLs:items];

    previewController.dataSource = quickLookDelegate;
    
    [topMostController() presentViewController:previewController animated:true completion:nil];
}
+ (void)showShareVC:(id)item {
    UIActivityViewController *acVC = [[UIActivityViewController alloc] initWithActivityItems:@[item] applicationActivities:nil];
    if (is_iPad()) {
        acVC.popoverPresentationController.sourceView = topMostController().view;
        acVC.popoverPresentationController.sourceRect = CGRectMake(topMostController().view.bounds.size.width / 2.0, topMostController().view.bounds.size.height / 2.0, 1.0, 1.0);
    }
    [topMostController() presentViewController:acVC animated:true completion:nil];
}
+ (void)showSettingsVC:(UIWindow *)window {
    UIViewController *rootController = [window rootViewController] ?: topMostController();
    while (rootController.presentedViewController) {
        rootController = rootController.presentedViewController;
    }

    SCISettingsViewController *settingsViewController = [SCISettingsViewController new];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:settingsViewController];
    
    [rootController presentViewController:navigationController animated:YES completion:nil];
}

// Colours
+ (UIColor *)SCIColor_Primary {
    // Custom accent override (hex stored by the settings color picker)
    NSString *hex = [[NSUserDefaults standardUserDefaults] stringForKey:@"albrhi_accent_hex"];
    UIColor *custom = [self colorFromHexString:hex];
    if (custom) return custom;

    // Albrhi default — burnt orange #E8590C
    return [UIColor colorWithRed:232/255.0 green:89/255.0 blue:12/255.0 alpha:1];
};

// Parse a #RRGGBB / RRGGBB hex string into a UIColor. Returns nil on invalid input.
+ (UIColor *)colorFromHexString:(NSString *)hex {
    if (![hex isKindOfClass:[NSString class]] || hex.length == 0) return nil;
    NSString *s = [[hex stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] uppercaseString];
    if ([s hasPrefix:@"#"]) s = [s substringFromIndex:1];
    if (s.length != 6) return nil;

    unsigned int rgb = 0;
    NSScanner *scanner = [NSScanner scannerWithString:s];
    if (![scanner scanHexInt:&rgb]) return nil;

    return [UIColor colorWithRed:((rgb >> 16) & 0xFF) / 255.0
                           green:((rgb >> 8) & 0xFF) / 255.0
                            blue:(rgb & 0xFF) / 255.0
                           alpha:1.0];
}

// Convert a UIColor to a #RRGGBB hex string.
+ (NSString *)hexStringFromColor:(UIColor *)color {
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![color getRed:&r green:&g blue:&b alpha:&a]) return nil;
    return [NSString stringWithFormat:@"#%02X%02X%02X",
            (int)roundf(r * 255), (int)roundf(g * 255), (int)roundf(b * 255)];
}

// Errors
+ (NSError *)errorWithDescription:(NSString *)errorDesc {
    return [self errorWithDescription:errorDesc code:1];
}
+ (NSError *)errorWithDescription:(NSString *)errorDesc code:(NSInteger)errorCode {
    NSError *error = [ NSError errorWithDomain:@"com.socuul.scinsta" code:errorCode userInfo:@{ NSLocalizedDescriptionKey: errorDesc } ];
    return error;
}

+ (JGProgressHUD *)showErrorHUDWithDescription:(NSString *)errorDesc {
    return [self showErrorHUDWithDescription:errorDesc dismissAfterDelay:4.0];
}
+ (JGProgressHUD *)showErrorHUDWithDescription:(NSString *)errorDesc dismissAfterDelay:(CGFloat)dismissDelay {
    JGProgressHUD *hud = [[JGProgressHUD alloc] init];
    hud.textLabel.text = errorDesc;
    hud.indicatorView = [[JGProgressHUDErrorIndicatorView alloc] init];

    [hud showInView:topMostController().view];
    [hud dismissAfterDelay:4.0];

    return hud;
}
+ (JGProgressHUD *)showSuccessHUDWithDescription:(NSString *)desc {
    JGProgressHUD *hud = [[JGProgressHUD alloc] init];
    hud.textLabel.text = desc;
    hud.indicatorView = [[JGProgressHUDSuccessIndicatorView alloc] init];

    [hud showInView:topMostController().view];
    [hud dismissAfterDelay:1.6];

    return hud;
}

+ (JGProgressHUD *)showProgressHUDWithText:(NSString *)text {
    JGProgressHUD *hud = [[JGProgressHUD alloc] init];
    hud.textLabel.text = text;
    [hud showInView:topMostController().view];
    return hud;
}

// Present the system color picker to choose a custom accent color.
+ (void)showAccentColorPicker {
    if (@available(iOS 14.0, *)) {
        UIColorPickerViewController *picker = [[UIColorPickerViewController alloc] init];
        picker.selectedColor = [self SCIColor_Primary];
        picker.supportsAlpha = NO;

        // Use a shared delegate object retained via associated storage.
        SCIAccentPickerDelegate *delegate = [[SCIAccentPickerDelegate alloc] init];
        objc_setAssociatedObject(picker, "albrhiAccentDelegate", delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        picker.delegate = delegate;

        [topMostController() presentViewController:picker animated:YES completion:nil];
    } else {
        [self showErrorHUDWithDescription:@"iOS 14+ required"];
    }
}

+ (void)resetAccentColor {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"albrhi_accent_hex"];
    [self showSuccessHUDWithDescription:SCILocalized(@"accent_reset_title")];
}

// Compose and copy a user's public info (username, name, verified) to the clipboard.
+ (void)copyAccountInfoForUser:(id)user {
    if (!user) {
        [self showErrorHUDWithDescription:SCILocalized(@"info_unavailable")];
        return;
    }

    NSMutableArray<NSString *> *parts = [NSMutableArray array];

    @try {
        if ([user respondsToSelector:@selector(username)]) {
            NSString *u = SCISafeValueForKey(user, @"username");
            if ([u isKindOfClass:[NSString class]] && u.length) [parts addObject:[NSString stringWithFormat:@"@%@", u]];
        }
    } @catch (__unused id e) {}

    @try {
        if ([user respondsToSelector:@selector(displayName)]) {
            NSString *n = [user performSelector:@selector(displayName)];
            if ([n isKindOfClass:[NSString class]] && n.length) [parts addObject:n];
        }
    } @catch (__unused id e) {}

    @try {
        if ([user respondsToSelector:@selector(computedIsVerified)] && [user computedIsVerified]) {
            [parts addObject:SCILocalized(@"info_verified")];
        }
    } @catch (__unused id e) {}

    if (parts.count == 0) {
        [self showErrorHUDWithDescription:SCILocalized(@"info_unavailable")];
        return;
    }

    // Append the follow-back relationship when known.
    NSString *followStatus = [self followStatusStringForUser:user];
    if (followStatus.length) [parts addObject:followStatus];

    [UIPasteboard generalPasteboard].string = [parts componentsJoinedByString:@"\n"];
    [self showSuccessHUDWithDescription:SCILocalized(@"info_copied")];
}

+ (NSString *)followStatusStringForUser:(id)user {
    if (!user) return nil;

    @try {
        // `followsCurrentUser` is the authoritative "do they follow me" flag.
        if ([user respondsToSelector:@selector(followsCurrentUser)]) {
            BOOL followsMe = SCISafeBoolForKey(user, @"followsCurrentUser");
            return SCILocalized(followsMe ? @"p_follows_you" : @"p_not_follows_you");
        }
    } @catch (__unused id e) {}

    return nil;
}

+ (NSString *)currentUsername {
    @try {
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (![window respondsToSelector:@selector(userSession)]) continue;

            id session = SCISafeValueForKey(window, @"userSession");
            id user = session ? SCISafeValueForKey(session, @"user") : nil;
            id username = user ? SCISafeValueForKey(user, @"username") : nil;

            if ([username isKindOfClass:[NSString class]] && [username length]) return username;
        }
    } @catch (__unused id e) {}

    return nil;
}

// Media
+ (NSURL *)getPhotoUrl:(IGPhoto *)photo {
    if (!photo) return nil;

    // Get highest quality photo link
    NSURL *photoUrl = [photo imageURLForWidth:100000.00];

    return photoUrl;
}
+ (NSURL *)getPhotoUrlForMedia:(IGMedia *)media {
    if (!media) return nil;

    IGPhoto *photo = media.photo;

    return [SCIUtils getPhotoUrl:photo];
}

/// The story item's own API dictionary, where a story's real video lives.
///
/// **A story's `IGVideo` is a hollow shell, the same shape as a photo post's and a
/// repost's** -- so `-videoVersions` and the rest answer nothing and the download
/// falls through to the poster frame. The data is not gone; it is in the item's raw
/// dictionary under `video_versions` / `video_dash_manifest`, which the object
/// accessors are not exposing for a reel item. This reaches it the way the reference
/// tweak does: by asking the item for its dictionary rather than the wrong object for
/// a URL. Additive -- it is consulted only after the accessor path has already failed,
/// so no post that downloads today can change.
///
/// Three accessors, each behind `-respondsToSelector:`, and the first that returns a
/// dictionary carrying a video or image key wins. Names read from the reference build's
/// strings, not invented: `dictionaryRepresentation`, `igMedia` (whose own dictionary
/// is then asked), `dictionary`.
+ (NSDictionary *)mediaDictionary:(id)media {
    if (!media) return nil;

    NSArray<NSString *> *keys = @[@"video_versions", @"video_dash_manifest",
                                  @"image_versions2", @"media_type"];

    BOOL (^looksLikeMedia)(id) = ^BOOL(id candidate) {
        if (![candidate isKindOfClass:[NSDictionary class]]) return NO;
        for (NSString *key in keys) {
            if (candidate[key] != nil) return YES;
        }
        return NO;
    };

    // The item directly, then the IGMedia it may wrap, each asked for a dictionary.
    NSMutableArray *hosts = [NSMutableArray arrayWithObject:media];
    @try {
        id inner = SCISafeValueForKey(media, @"igMedia");
        if (inner) [hosts addObject:inner];
    } @catch (__unused id e) {}

    for (id host in hosts) {
        for (NSString *name in @[@"dictionaryRepresentation", @"dictionary", @"jsonDictionary"]) {
            @try {
                SEL selector = NSSelectorFromString(name);
                if (![host respondsToSelector:selector]) continue;
                id dict = ((id (*)(id, SEL))objc_msgSend)(host, selector);
                if (looksLikeMedia(dict)) return dict;
            } @catch (__unused id e) {}
        }
    }

    return nil;
}

/// A saveable video URL out of a media dictionary, DASH first then progressive.
///
/// The DASH manifest goes through the same ladder parser the object path uses, so an
/// AV1-only story is refused here exactly as an AV1-only post is (the transcode path
/// still owns that case). `video_versions` is Instagram's progressive ladder, ordered
/// high to low, each entry `{url,width,height}` -- the largest area wins, matching what
/// `+getBestVideoUrl:` does with the object's own versions.
+ (NSURL *)videoURLFromMediaDict:(NSDictionary *)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;

    // DASH first: the ladder may carry a higher rendition than the progressive list,
    // and the existing parser already knows which families iOS can save.
    id manifest = dict[@"video_dash_manifest"];
    if ([manifest isKindOfClass:[NSString class]] && [manifest length]) {
        NSURL *best = nil;
        long long bestArea = 0;
        for (NSDictionary *rep in [self dashRepresentationsFromXML:manifest]) {
            NSString *family = rep[@"family"];
            if (![family isEqualToString:@"h264"] && ![family isEqualToString:@"hevc"]) continue;
            long long area = [rep[@"area"] longLongValue];
            if (area < bestArea) continue;
            NSURL *url = [NSURL URLWithString:rep[@"url"]];
            if (url) { best = url; bestArea = area; }
        }
        if (best) return best;
    }

    // Progressive: pick the largest by area, not position -- the list is usually
    // ordered but a saved copy should not depend on it.
    id versions = dict[@"video_versions"];
    if ([versions isKindOfClass:[NSArray class]]) {
        NSURL *best = nil;
        long long bestArea = 0;
        for (id entry in versions) {
            if (![entry isKindOfClass:[NSDictionary class]]) continue;
            NSString *urlString = entry[@"url"];
            if (![urlString isKindOfClass:[NSString class]] || !urlString.length) continue;
            long long area = [entry[@"width"] longLongValue] * [entry[@"height"] longLongValue];
            if (best && area < bestArea) continue;
            NSURL *url = [NSURL URLWithString:urlString];
            if (url) { best = url; bestArea = area; }
        }
        if (best) return best;
    }

    return nil;
}
// Extract the pixel area (width*height) from a version dictionary, if present.
// Read a numeric-ish property from either an IGAPIVideoVersion object (via
// selectors width/height/bandwidth) or an NSDictionary (via keys). Returns 0 if absent.
+ (long long)qualityValueFrom:(id)version key:(NSString *)key {
    if (!version) return 0;

    // Dictionary shape
    if ([version isKindOfClass:[NSDictionary class]]) {
        id v = version[key];
        // dictionaries may also carry a bandwidth under alternate keys
        if (!v && [key isEqualToString:@"bandwidth"]) {
            v = version[@"bitrate"] ?: version[@"estimated_bytes"];
        }
        return v ? [v longLongValue] : 0;
    }

    // Object shape (IGAPIVideoVersion): -width, -height, -bandwidth return NSNumber (id)
    @try {
        if ([version respondsToSelector:NSSelectorFromString(key)]) {
            id v = SCISafeValueForKey(version, key);
            if ([v respondsToSelector:@selector(longLongValue)]) return [v longLongValue];
        }
    } @catch (__unused id e) {}
    return 0;
}

// Read the URL string from an IGAPIVideoVersion object or dictionary.
+ (NSString *)urlStringFromVersion:(id)version {
    if (!version) return nil;
    if ([version isKindOfClass:[NSDictionary class]]) {
        id u = version[@"url"] ?: version[@"urlString"];
        return [u isKindOfClass:[NSString class]] ? u : nil;
    }
    @try {
        // Try every plausible accessor name — the exact one differs between
        // Instagram builds (urlString / url / progressiveDownloadURL / etc.).
        for (NSString *sel in @[@"urlString", @"url", @"progressiveDownloadURL", @"downloadURL", @"assetURL", @"videoURL"]) {
            if ([version respondsToSelector:NSSelectorFromString(sel)]) {
                id u = SCISafeValueForKey(version, sel);
                if ([u isKindOfClass:[NSString class]] && [u length]) return u;
                if ([u isKindOfClass:[NSURL class]]) return [(NSURL *)u absoluteString];
            }
        }
    } @catch (__unused id e) {}
    return nil;
}

// Pick the highest-quality entry from a collection of version objects/dicts.
+ (NSURL *)bestURLFromVersions:(id)versions {
    if (![versions respondsToSelector:@selector(count)] || [versions count] == 0) return nil;

    id best = nil;
    long long bestScore = -1;
    for (id version in versions) {
        NSString *urlString = [self urlStringFromVersion:version];
        if (![urlString length]) continue;

        long long w = [self qualityValueFrom:version key:@"width"];
        long long h = [self qualityValueFrom:version key:@"height"];
        long long area = w * h;
        long long bandwidth = [self qualityValueFrom:version key:@"bandwidth"];
        // Primary: pixel area. Tie-break: bandwidth. Fall back to bandwidth if no dimensions.
        long long score = (area > 0) ? (area * 1000000LL + bandwidth) : bandwidth;
        if (score > bestScore) { bestScore = score; best = version; }
    }
    if (!best) return nil;
    NSString *urlString = [self urlStringFromVersion:best];
    return [urlString length] ? [NSURL URLWithString:urlString] : nil;
}

+ (NSURL *)getVideoUrl:(IGVideo *)video {
    if (!video) return nil;

    // Always take the highest-quality rendition available (resolution, then bitrate).
    BOOL preferMaxQuality = YES;

    // --- Strategy 1: videoVersions → array of IGAPIVideoVersion (width/height/bandwidth) ---
    // This is the correct shape on current Instagram builds.
    @try {
        if ([video respondsToSelector:@selector(videoVersions)]) {
            id versions = [video performSelector:@selector(videoVersions)];
            if (preferMaxQuality) {
                NSURL *best = [self bestURLFromVersions:versions];
                if (best) return best;
            } else if ([versions respondsToSelector:@selector(firstObject)]) {
                // Lowest quality requested: versions are typically ordered high→low, so take last.
                id last = [versions respondsToSelector:@selector(lastObject)] ? [versions lastObject] : nil;
                NSString *u = [self urlStringFromVersion:last];
                if ([u length]) return [NSURL URLWithString:u];
            }
        }
    } @catch (__unused id e) {}

    // --- Strategy 2 (pre-v398): sortedVideoURLsBySize is ASCENDING → take last for highest ---
    if ([video respondsToSelector:@selector(sortedVideoURLsBySize)]) {
        NSArray<NSDictionary *> *sorted = [video sortedVideoURLsBySize];
        if ([sorted isKindOfClass:[NSArray class]] && sorted.count > 0) {
            NSDictionary *pick = preferMaxQuality ? sorted.lastObject : sorted.firstObject;
            NSString *urlString = pick[@"url"];
            if (urlString.length) return [NSURL URLWithString:urlString];
        }
    }

    // --- Strategy 3 (fallback): allVideoURLs is an UNORDERED set with no metadata ---
    if ([video respondsToSelector:@selector(allVideoURLs)]) {
        id urls = [video allVideoURLs];
        if ([urls isKindOfClass:[NSSet class]]) return [(NSSet *)urls anyObject];
        if ([urls isKindOfClass:[NSArray class]] && [(NSArray *)urls count] > 0) return [(NSArray *)urls lastObject];
    }

    return nil;
}
+ (NSArray<NSString *> *)selectorsMatching:(NSString *)needle onObject:(id)object {
    if (!object || !needle.length) return @[];

    NSMutableArray<NSString *> *found = [NSMutableArray array];

    // Walk up to NSObject: the property may be declared on a superclass, and
    // stopping at the leaf would miss it.
    for (Class cls = [object class]; cls && cls != [NSObject class]; cls = class_getSuperclass(cls)) {
        unsigned int count = 0;
        Method *methods = class_copyMethodList(cls, &count);
        if (!methods) continue;

        for (unsigned int i = 0; i < count; i++) {
            SEL selector = method_getName(methods[i]);
            NSString *name = NSStringFromSelector(selector);

            // Getters only: anything taking an argument cannot be probed blindly.
            if ([name containsString:@":"]) continue;

            if ([name rangeOfString:needle options:NSCaseInsensitiveSearch].location == NSNotFound) continue;
            if ([found containsObject:name]) continue;

            [found addObject:name];
        }

        free(methods);
    }

    return [found copy];
}

+ (NSString *)dashManifestXMLForVideo:(id)video media:(id)media {
    // Names guessed from another tweak's symbol table found nothing on a real
    // device, so the candidate list is now built from what these objects
    // actually respond to. The manifest is reachable from either the video or
    // the media object depending on how the post was constructed, so both are
    // asked.
    for (id host in @[video ?: [NSNull null], media ?: [NSNull null]]) {
        if (host == [NSNull null]) continue;

        NSMutableArray<NSString *> *selectorNames =
            [[self selectorsMatching:@"dash" onObject:host] mutableCopy];

        for (NSString *name in [self selectorsMatching:@"manifest" onObject:host]) {
            if (![selectorNames containsObject:name]) [selectorNames addObject:name];
        }

        for (NSString *name in selectorNames) {
            SEL selector = NSSelectorFromString(name);
            if (![host respondsToSelector:selector]) continue;

            id value = nil;
            @try { value = [host performSelector:selector]; } @catch (__unused id e) { continue; }

            if ([value isKindOfClass:[NSString class]] && [value length]) return value;

            if ([value isKindOfClass:[NSData class]]) {
                NSString *text = [[NSString alloc] initWithData:value encoding:NSUTF8StringEncoding];
                if ([text length]) return text;
            }
        }

        // Some builds expose the field only through the API dictionary rather
        // than as a property, so KVC reaches it where respondsToSelector: does not.
        @try {
            id value = SCISafeValueForKey(host, @"video_dash_manifest");
            if ([value isKindOfClass:[NSString class]] && [value length]) return value;
        } @catch (__unused id e) {}
    }

    return nil;
}

// MARK: - DASH ladder

// Reads a numeric attribute (width="1080") from a single Representation block.
// The \b guards against width="…" matching inside bandWIDTH="…" — a bug that once
// reported the bitrate as the width.
+ (long long)dashInt:(NSString *)name inBlock:(NSString *)block {
    NSRegularExpression *regex =
        [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"\\b%@=\"(\\d+)\"", name]
                                                  options:NSRegularExpressionCaseInsensitive
                                                    error:nil];
    NSTextCheckingResult *m = [regex firstMatchInString:block options:0 range:NSMakeRange(0, block.length)];
    if (!m || m.numberOfRanges < 2) return 0;
    return [[block substringWithRange:[m rangeAtIndex:1]] longLongValue];
}

// Reads a string attribute (codecs="avc1.64…") from a Representation block.
+ (NSString *)dashString:(NSString *)name inBlock:(NSString *)block {
    NSRegularExpression *regex =
        [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"\\b%@=\"([^\"]+)\"", name]
                                                  options:NSRegularExpressionCaseInsensitive
                                                    error:nil];
    NSTextCheckingResult *m = [regex firstMatchInString:block options:0 range:NSMakeRange(0, block.length)];
    if (!m || m.numberOfRanges < 2) return nil;
    return [block substringWithRange:[m rangeAtIndex:1]];
}

// Reads and XML-unescapes the <BaseURL> of a Representation block, absolute only.
+ (NSString *)dashBaseURLInBlock:(NSString *)block {
    NSRegularExpression *regex =
        [NSRegularExpression regularExpressionWithPattern:@"<BaseURL>(.*?)</BaseURL>"
                                                  options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators
                                                    error:nil];
    NSTextCheckingResult *m = [regex firstMatchInString:block options:0 range:NSMakeRange(0, block.length)];
    if (!m || m.numberOfRanges < 2) return nil;

    NSString *url = [[block substringWithRange:[m rangeAtIndex:1]]
                     stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    url = [url stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
    url = [url stringByReplacingOccurrencesOfString:@"&lt;" withString:@"<"];
    url = [url stringByReplacingOccurrencesOfString:@"&gt;" withString:@">"];
    url = [url stringByReplacingOccurrencesOfString:@"&quot;" withString:@"\""];

    // Relative BaseURLs would need an MPD base we do not track.
    return [url hasPrefix:@"http"] ? url : nil;
}

// Which family a DASH codecs string belongs to, in terms of what iOS can save:
//   "h264" (avc1/avc3), "hevc" (hvc1/hev1), "av1" (av01), "vp9" (vp09/vp9), or nil.
// H.264/HEVC save straight to Photos; AV1/VP9 need transcoding first (phase two).
+ (NSString *)dashCodecFamily:(NSString *)codecs {
    NSString *c = [codecs lowercaseString];
    if (![c length]) return nil;
    if ([c hasPrefix:@"avc1"] || [c hasPrefix:@"avc3"]) return @"h264";
    if ([c hasPrefix:@"hvc1"] || [c hasPrefix:@"hev1"]) return @"hevc";
    if ([c hasPrefix:@"av01"]) return @"av1";
    if ([c hasPrefix:@"vp09"] || [c hasPrefix:@"vp9"]) return @"vp9";
    return nil;
}

+ (NSArray<NSDictionary *> *)dashRepresentationsForVideo:(id)video media:(id)media {
    return [self dashRepresentationsFromXML:[self dashManifestXMLForVideo:video media:media]];
}

+ (NSArray<NSDictionary *> *)dashRepresentationsFromXML:(NSString *)xml {
    if (![xml length] || [xml rangeOfString:@"<Representation"].location == NSNotFound) return @[];

    NSRegularExpression *repRegex =
        [NSRegularExpression regularExpressionWithPattern:@"<Representation\\b[^>]*>.*?</Representation>"
                                                  options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators
                                                    error:nil];

    NSMutableArray<NSDictionary *> *out = [NSMutableArray array];

    for (NSTextCheckingResult *match in [repRegex matchesInString:xml options:0 range:NSMakeRange(0, xml.length)]) {
        NSString *block = [xml substringWithRange:match.range];

        NSString *baseURL = [self dashBaseURLInBlock:block];
        if (![baseURL length]) continue;

        NSString *codecs = [self dashString:@"codecs" inBlock:block];
        long long w = [self dashInt:@"width" inBlock:block];
        long long h = [self dashInt:@"height" inBlock:block];
        long long bandwidth = [self dashInt:@"bandwidth" inBlock:block];

        // A Representation with no dimensions is the audio track; keep it tagged so
        // the transcoder can pair it with the decoded video stream.
        NSString *type = (w > 0 && h > 0) ? @"video" : @"audio";

        // frameRate is "num/den" (e.g. 15360/512 ≈ 30). The transcoder needs it to
        // stamp presentation times; default to 30 when absent or malformed.
        double fps = 30.0;
        NSString *fr = [self dashString:@"frameRate" inBlock:block];
        NSArray<NSString *> *parts = [fr componentsSeparatedByString:@"/"];
        if (parts.count == 2 && [parts[1] doubleValue] > 0) {
            fps = [parts[0] doubleValue] / [parts[1] doubleValue];
        } else if (parts.count == 1 && [fr doubleValue] > 0) {
            fps = [fr doubleValue];
        }

        [out addObject:@{
            @"type": type,
            @"url": baseURL,
            @"codecs": codecs ?: @"",
            @"family": [self dashCodecFamily:codecs] ?: @"",
            @"width": @(w),
            @"height": @(h),
            @"area": @(w * h),
            @"bandwidth": @(bandwidth),
            @"fps": @(fps)
        }];
    }

    return out;
}

// The best video URL that iOS can save as-is: the highest-resolution H.264/HEVC
// rendition across the DASH ladder AND -videoVersions.
//
// -videoVersions stays the floor and the safety net: if DASH exposes nothing
// saveable (an AV1-only reel, an exception, an unparsable manifest), this returns
// exactly what the proven path returned. AV1/VP9 renditions are ignored here —
// saving those is phase two's job, behind its own switch.
+ (NSURL *)getBestVideoUrl:(IGVideo *)video {
    NSURL *fallback = [self getVideoUrl:video];

    @try {
        long long fallbackArea = 0;
        NSURL *best = fallback;

        // Counted per stage rather than at the end. A quality picker was built three
        // times against this pipeline and each one showed a single option, because
        // nobody knew which stage the renditions were being lost at — whether the
        // manifest carried few, whether parsing dropped them, or whether they were
        // all in a codec iOS cannot save. One total answers none of that.
        NSInteger versions = 0;
        @try {
            if ([video respondsToSelector:@selector(videoVersions)]) {
                id list = [video performSelector:@selector(videoVersions)];
                if ([list respondsToSelector:@selector(count)]) versions = (NSInteger)[list count];
            }
        } @catch (__unused id e) {}

        NSArray<NSDictionary *> *reps = [self dashRepresentationsForVideo:video media:nil];

        NSInteger videoReps = 0;
        NSInteger saveable = 0;
        NSMutableSet<NSString *> *distinct = [NSMutableSet set];

        //
        // **Counted separately, because a picker has two ladders to offer from and this line
        // described one of them.**
        //
        // `distinct` is filled below the saveable test, so an AV1-only ladder scores zero -- by
        // construction, not by observation. A device report read `saveable 0 · distinct 0` beside
        // nine AV1 rungs up to 1440p and was taken to mean there was nothing to choose between,
        // when what it meant was that nothing could be chosen *without transcoding*. Same family
        // as the quality picker's own `raw → parsed → deduped`: name the stages, or one number
        // answers for two.
        //
        NSMutableSet<NSString *> *transcodable = [NSMutableSet set];
        NSString *chosen = nil;

        for (NSDictionary *rep in reps) {
            if (![rep[@"type"] isEqualToString:@"video"]) continue;
            videoReps++;

            NSString *family = rep[@"family"];
            if ([family isEqualToString:@"av1"] || [family isEqualToString:@"vp9"]) {
                [transcodable addObject:[NSString stringWithFormat:@"%@x%@", rep[@"width"], rep[@"height"]]];
            }
            if (![family isEqualToString:@"h264"] && ![family isEqualToString:@"hevc"]) continue;
            saveable++;

            // What a picker would actually be able to offer: one entry per distinct
            // resolution, since the ladder repeats a size at several bitrates.
            [distinct addObject:[NSString stringWithFormat:@"%@x%@", rep[@"width"], rep[@"height"]]];

            long long area = [rep[@"area"] longLongValue];
            if (area <= fallbackArea) continue;

            NSURL *url = [NSURL URLWithString:rep[@"url"]];
            if (!url) {
                NSString *encoded = [rep[@"url"] stringByAddingPercentEncodingWithAllowedCharacters:
                                     [NSCharacterSet URLQueryAllowedCharacterSet]];
                url = [NSURL URLWithString:encoded];
            }
            if (!url) continue;

            best = url;
            fallbackArea = area;
            chosen = [NSString stringWithFormat:@"%@x%@ %@", rep[@"width"], rep[@"height"], family];
        }

        [SCIDiagnostics recordQualityFunnelWithVersions:versions
                                       representations:(NSInteger)reps.count
                                             videoReps:videoReps
                                              saveable:saveable
                                              distinct:(NSInteger)distinct.count
                                           transcodable:(NSInteger)transcodable.count
                                                chosen:chosen];

        return best;
    } @catch (__unused id e) {
        return fallback;
    }
}

+ (NSURL *)urlFromDashRep:(NSDictionary *)rep {
    if (!rep) return nil;
    NSURL *url = [NSURL URLWithString:rep[@"url"]];
    if (url) return url;
    NSString *encoded = [rep[@"url"] stringByAddingPercentEncodingWithAllowedCharacters:
                         [NSCharacterSet URLQueryAllowedCharacterSet]];
    return [NSURL URLWithString:encoded];
}

// Ranks one video representation above another: resolution first (a bigger frame
// is the headline win), then frame rate (so 1080p60 is taken over 1080p30 when
// both exist — the source's real smoothness, not a forced 30), then bitrate.
+ (BOOL)dashRep:(NSDictionary *)a beats:(NSDictionary *)b {
    long long areaA = [a[@"area"] longLongValue], areaB = [b[@"area"] longLongValue];
    if (areaA != areaB) return areaA > areaB;

    double fpsA = [a[@"fps"] doubleValue], fpsB = [b[@"fps"] doubleValue];
    if (fpsA != fpsB) return fpsA > fpsB;

    return [a[@"bandwidth"] longLongValue] > [b[@"bandwidth"] longLongValue];
}

/// The clip's length, from the manifest's mediaPresentationDuration="PT10.5S".
/// Both the transcode banner and the quality sheet need it, so it is parsed here
/// rather than twice.
+ (double)dashDurationForVideo:(id)video media:(id)media {
    NSString *xml = [self dashManifestXMLForVideo:video media:media];
    NSString *dur = [self dashString:@"mediaPresentationDuration" inBlock:xml ?: @""];

    if ([dur hasPrefix:@"PT"] && [dur hasSuffix:@"S"]) {
        double seconds = [[dur substringWithRange:NSMakeRange(2, dur.length - 3)] doubleValue];
        if (seconds > 0) return seconds;
    }
    return 0;
}

/// The distinct AV1 heights this video offers, tallest first — what a picker can
/// meaningfully present. The ladder repeats a resolution at several bitrates, and
/// choosing between two copies of 720p is not a choice anyone wants to make, so the
/// tallest bitrate of each height is the only one kept.
+ (NSArray<NSDictionary *> *)transcodeOptionsForVideo:(id)video media:(id)media {
    NSMutableDictionary<NSNumber *, NSDictionary *> *byHeight = [NSMutableDictionary dictionary];

    @try {
        for (NSDictionary *rep in [self dashRepresentationsForVideo:video media:media]) {
            if (![rep[@"family"] isEqualToString:@"av1"]) continue;
            if (![rep[@"type"] isEqualToString:@"video"]) continue;

            NSNumber *height = rep[@"height"];
            NSDictionary *existing = byHeight[height];

            // Ranked the same way the transcoder ranks, so the option offered for a
            // height is exactly the rendition that will be fetched for it. Comparing
            // bitrate alone could show 30 fps while the transcoder took the 60.
            if (!existing || [self dashRep:rep beats:existing]) {
                byHeight[height] = rep;
            }
        }
    } @catch (__unused id e) {}

    // The clip length lives on the manifest, not on a Representation, so it is
    // folded into each option here — the sheet needs it to turn a bitrate into the
    // megabytes a download will actually cost.
    double duration = [self dashDurationForVideo:video media:media];

    NSMutableArray<NSDictionary *> *options = [NSMutableArray array];
    for (NSDictionary *rep in [byHeight allValues]) {
        NSMutableDictionary *option = [rep mutableCopy];
        if (duration > 0) option[@"duration"] = @(duration);
        [options addObject:option];
    }

    return [options sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [b[@"height"] compare:a[@"height"]];
    }];
}

+ (NSDictionary *)transcodePlanForVideo:(id)video media:(id)media {
    return [self transcodePlanForVideo:video media:media preferredHeight:0];
}

+ (NSDictionary *)transcodePlanForVideo:(id)video media:(id)media preferredHeight:(long long)preferredHeight {
    @try {
        NSArray<NSDictionary *> *reps = [self dashRepresentationsForVideo:video media:media];
        if (reps.count == 0) return nil;

        NSDictionary *bestAV1 = nil, *bestAudio = nil;
        long long bestSaveableHeight = 0;

        for (NSDictionary *rep in reps) {
            long long h = [rep[@"height"] longLongValue];
            NSString *family = rep[@"family"];

            if ([rep[@"type"] isEqualToString:@"audio"]) {
                if (!bestAudio || [rep[@"bandwidth"] longLongValue] > [bestAudio[@"bandwidth"] longLongValue]) {
                    bestAudio = rep;
                }
                continue;
            }

            // The tallest rendition iOS can already save without transcoding.
            if (([family isEqualToString:@"h264"] || [family isEqualToString:@"hevc"]) && h > bestSaveableHeight) {
                bestSaveableHeight = h;
            }

            if ([family isEqualToString:@"av1"]) {
                // A requested height narrows the field to that rung of the ladder;
                // within it the best bitrate still wins. With none requested this is
                // exactly the old behaviour — the tallest rendition, automatically.
                if (preferredHeight > 0 && h != preferredHeight) continue;

                if (!bestAV1 || [self dashRep:rep beats:bestAV1]) {
                    bestAV1 = rep;
                }
            }
        }

        if (!bestAV1) return nil;

        // Only worth the transcode when AV1 clears both the DASH H.264 ladder and
        // the ~720p progressive rendition -videoVersions typically tops out at.
        long long av1Height = [bestAV1[@"height"] longLongValue];

        // The "is it worth it" test only applies to the automatic path. Someone who
        // picked 720p from a list asked for 720p, and refusing them because it is not
        // an improvement would make the picker look broken.
        if (preferredHeight == 0 && (av1Height <= bestSaveableHeight || av1Height <= 720)) return nil;

        NSURL *videoURL = [self urlFromDashRep:bestAV1];
        if (!videoURL) return nil;

        NSMutableDictionary *plan = [NSMutableDictionary dictionary];
        plan[@"videoURL"] = videoURL;
        plan[@"fps"] = bestAV1[@"fps"] ?: @30;
        plan[@"width"] = bestAV1[@"width"];
        plan[@"height"] = bestAV1[@"height"];

        // Clip duration (mediaPresentationDuration="PT10.517188S") lets the banner
        // show a real percentage: total frames ≈ duration × fps.
        double seconds = [self dashDurationForVideo:video media:media];
        if (seconds > 0) plan[@"duration"] = @(seconds);
        if (bestAudio) {
            NSURL *audioURL = [self urlFromDashRep:bestAudio];
            if (audioURL) plan[@"audioURL"] = audioURL;
        }
        return plan;
    } @catch (__unused id e) {
        return nil;
    }
}

+ (NSURL *)getVideoUrlForMedia:(id)media {
    if (!media) return nil;

    IGVideo *video = nil;
    @try { video = SCISafeValueForKey(media, @"video"); } @catch (__unused id e) {}
    if (!video) return nil;

    return [SCIUtils getVideoUrl:video];
}

// Returns an array of @{ @"label": NSString, @"url": NSURL } for every available
// video quality, sorted highest-first. Used by the pre-download quality picker.
+ (NSArray<NSDictionary *> *)availableVideoQualitiesForVideo:(IGVideo *)video {
    if (!video) return @[];

    NSMutableArray<NSDictionary *> *out = [NSMutableArray array];
    @try {
        if ([video respondsToSelector:@selector(videoVersions)]) {
            id versions = [video performSelector:@selector(videoVersions)];
            if ([versions respondsToSelector:@selector(count)]) {
                for (id version in versions) {
                    NSString *urlString = [self urlStringFromVersion:version];
                    if (![urlString length]) continue;
                    long long w = [self qualityValueFrom:version key:@"width"];
                    long long h = [self qualityValueFrom:version key:@"height"];
                    NSString *label = (w > 0 && h > 0)
                        ? [NSString stringWithFormat:@"%lld×%lld", w, h]
                        : SCILocalized(@"quality_unknown");
                    [out addObject:@{ @"label": label,
                                      @"url": [NSURL URLWithString:urlString],
                                      @"area": @(w * h) }];
                }
            }
        }
    } @catch (__unused id e) {}

    // Sort highest area first
    [out sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [b[@"area"] compare:a[@"area"]];
    }];
    return out;
}
// Accepts an IGMedia directly, or any object exposing a media/feedItem accessor.
// The post's audio URL is what gets kept on the slide, rather than the post itself.
// Holding the post would either retain it — and the post already holds its slides,
// so that is a cycle — or hold it unsafely and leave a dangling pointer once it goes.
// A URL is a value: neither problem applies.
static const void *SCIParentAudioKey = &SCIParentAudioKey;

+ (void)rememberParentPost:(id)parent forSlide:(id)slide {
    if (!parent || !slide || parent == slide) return;

    NSURL *audio = [self getAudioUrlForMedia:parent];
    if (!audio) return;

    @try {
        objc_setAssociatedObject(slide, SCIParentAudioKey, audio, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } @catch (__unused id error) {}
}

/// A saveable audio URL out of a story item's dictionary, and the key path it came from.
///
/// **A photo story with music is Instagram's own named case, and the object does not
/// carry it.** `+getAudioUrlForMedia:` resolves `sundialOriginalAudioAsset` /
/// `sundialMusicAsset` -- reel and feed accessors that a story item does not answer --
/// so the photo branch found no audio, offered no choice, and saved a silent picture.
/// Third time the answer has been "the object is hollow, the dictionary still has it".
///
/// **The subtree is confirmed; the leaf is not, so the leaf is searched rather than
/// named.** `story_music_stickers`, `story_music_lyric_stickers`, `music_metadata`,
/// `original_audio` and `is_story_image_with_music` are all real keys in a
/// same-generation reference's own binary. The nested URL key is in none of it, and
/// this project has lost three releases to guessing a hop it had not read -- so the
/// music subtree is walked for whatever URL it actually holds, which also survives the
/// rename that a hard-coded path would not. The key path that answered is reported.
///
/// Cover art lives in the same subtree, so a candidate is refused on an image
/// extension or an artwork-shaped key name rather than trusted for being a URL.
+ (NSURL *)audioURLFromMediaDict:(NSDictionary *)dict keyPath:(NSString **)outKeyPath {
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;

    NSArray<NSString *> *roots = @[@"story_music_stickers", @"story_music_lyric_stickers",
                                   @"music_metadata", @"original_audio",
                                   @"story_original_sound_info", @"audio"];

    NSMutableDictionary *bestSoFar = [NSMutableDictionary dictionary];
    for (NSString *root in roots) {
        id subtree = dict[root];
        if (subtree) [self sciWalkForAudio:subtree path:root depth:0 best:bestSoFar];
    }

    NSString *found = bestSoFar[@"url"];
    if (!found.length) return nil;

    if (outKeyPath) *outKeyPath = bestSoFar[@"path"];
    return [NSURL URLWithString:found];
}

/// One step of the music-subtree walk. A method rather than a block, because a block
/// that calls itself is a retain cycle ARC refuses outright (check.py rule 11).
/// Depth-limited: an unbounded walk over a structure the app owns is a cost
/// proportional to data this tweak does not control.
+ (void)sciWalkForAudio:(id)node
                   path:(NSString *)path
                  depth:(NSInteger)depth
                   best:(NSMutableDictionary *)best {
    if (depth > 6) return;

    if ([node isKindOfClass:[NSArray class]]) {
        NSInteger index = 0;
        for (id child in (NSArray *)node) {
            [self sciWalkForAudio:child
                             path:[NSString stringWithFormat:@"%@[%ld]", path, (long)index++]
                            depth:depth + 1
                             best:best];
        }
        return;
    }
    if (![node isKindOfClass:[NSDictionary class]]) return;

    for (id rawKey in (NSDictionary *)node) {
        if (![rawKey isKindOfClass:[NSString class]]) continue;

        NSString *key = (NSString *)rawKey;
        id value = ((NSDictionary *)node)[key];
        NSString *here = path.length ? [NSString stringWithFormat:@"%@.%@", path, key] : key;

        if ([value isKindOfClass:[NSDictionary class]] || [value isKindOfClass:[NSArray class]]) {
            [self sciWalkForAudio:value path:here depth:depth + 1 best:best];
            continue;
        }
        if (![value isKindOfClass:[NSString class]]) continue;

        NSString *text = (NSString *)value;
        if (![text hasPrefix:@"http"]) continue;

        NSString *lowerKey = key.lowercaseString;
        if ([lowerKey rangeOfString:@"url"].location == NSNotFound) continue;

        // Cover art and profile pictures sit beside the track in the same subtree, so a
        // candidate is refused by shape rather than trusted for being a URL.
        BOOL refused = NO;
        for (NSString *bad in @[@"cover", @"thumbnail", @"thumb", @"image", @"artwork",
                                @"profile", @"display", @"icon"]) {
            if ([lowerKey rangeOfString:bad].location != NSNotFound) { refused = YES; break; }
        }
        if (refused) continue;

        NSString *ext = [NSURL URLWithString:text].path.pathExtension.lowercaseString;
        for (NSString *bad in @[@"jpg", @"jpeg", @"png", @"webp", @"heic", @"gif"]) {
            if ([ext isEqualToString:bad]) { refused = YES; break; }
        }
        if (refused) continue;

        NSInteger score = 1;
        if ([lowerKey rangeOfString:@"download_url"].location != NSNotFound) score = 4;
        else if ([lowerKey rangeOfString:@"audio"].location != NSNotFound) score = 3;
        else if ([ext isEqualToString:@"m4a"] || [ext isEqualToString:@"aac"] ||
                 [ext isEqualToString:@"mp3"] || [ext isEqualToString:@"mp4"]) score = 2;

        if (score > [best[@"score"] integerValue]) {
            best[@"score"] = @(score);
            best[@"url"] = text;
            best[@"path"] = here;
        }
    }
}

+ (NSURL *)getAudioUrlForMedia:(id)mediaLike {
    if (!mediaLike) return nil;

    // Resolve to the object that actually carries the audio asset selectors.
    id media = mediaLike;
    if (![media respondsToSelector:@selector(sundialOriginalAudioAsset)]) {
        for (NSString *accessor in @[@"media", @"feedItem", @"currentMedia", @"item", @"mediaView", @"video"]) {
            @try {
                if ([media respondsToSelector:NSSelectorFromString(accessor)]) {
                    id candidate = SCISafeValueForKey(media, accessor);
                    if ([candidate respondsToSelector:@selector(sundialOriginalAudioAsset)]) {
                        media = candidate;
                        break;
                    }
                }
            } @catch (__unused id e) {}
        }
    }

    id asset = nil;
    @try {
        if ([media respondsToSelector:@selector(sundialOriginalAudioAsset)]) {
            asset = [media performSelector:@selector(sundialOriginalAudioAsset)];
        }
        if (!asset && [media respondsToSelector:@selector(sundialMusicAsset)]) {
            asset = [media performSelector:@selector(sundialMusicAsset)];
        }
    } @catch (__unused id e) {}

    // A carousel slide carries no music of its own — the post does. Fall back to
    // what the post had, noted when the slides were resolved, so multi-photo posts
    // offer the same choice a single photo does.
    if (!asset) {
        return objc_getAssociatedObject(mediaLike, SCIParentAudioKey);
    }

    @try {
        if ([asset respondsToSelector:@selector(audioFileUrl)]) {
            id u = [asset performSelector:@selector(audioFileUrl)];
            if ([u isKindOfClass:[NSURL class]]) return u;
            if ([u isKindOfClass:[NSString class]] && [u length]) return [NSURL URLWithString:u];
        }
    } @catch (__unused id e) {}
    return nil;
}

// View Controllers
+ (UIViewController *)viewControllerForView:(UIView *)view {
    NSString *viewDelegate = @"viewDelegate";
    if ([view respondsToSelector:NSSelectorFromString(viewDelegate)]) {
        return SCISafeValueForKey(view, viewDelegate);
    }

    return nil;
}

+ (UIViewController *)viewControllerForAncestralView:(UIView *)view {
    NSString *_viewControllerForAncestor = @"_viewControllerForAncestor";
    if ([view respondsToSelector:NSSelectorFromString(_viewControllerForAncestor)]) {
        return SCISafeValueForKey(view, _viewControllerForAncestor);
    }

    return nil;
}

+ (UIViewController *)nearestViewControllerForView:(UIView *)view {
    return [self viewControllerForView:view] ?: [self viewControllerForAncestralView:view];
}

// Functions
+ (NSString *)IGVersionString {
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
};
+ (BOOL)isNotch {
    return [[[UIApplication sharedApplication] keyWindow] safeAreaInsets].bottom > 0;
};

+ (BOOL)existingLongPressGestureRecognizerForView:(UIView *)view {
    NSArray *allRecognizers = view.gestureRecognizers;

    for (UIGestureRecognizer *recognizer in allRecognizers) {
        if ([[recognizer class] isSubclassOfClass:[UILongPressGestureRecognizer class]]) {
            return YES;
        }
    }

    return NO;
}

// Alerts
+ (BOOL)showConfirmation:(void(^)(void))okHandler title:(NSString *)title {
    [SCIConfirmSheet presentWithTitle:title symbol:nil confirm:okHandler cancel:nil];

    return nil;
};
+ (BOOL)showConfirmation:(void(^)(void))okHandler cancelHandler:(void(^)(void))cancelHandler title:(NSString *)title {
    [SCIConfirmSheet presentWithTitle:title symbol:nil confirm:okHandler cancel:cancelHandler];

    return nil;
};
+ (BOOL)showConfirmation:(void(^)(void))okHandler {
    return [self showConfirmation:okHandler title:nil];
};
+ (BOOL)showConfirmation:(void(^)(void))okHandler cancelHandler:(void(^)(void))cancelHandler {
    return [self showConfirmation:okHandler cancelHandler:cancelHandler title:nil];
}
+ (void)showRestartConfirmation {
    [SCIConfirmSheet presentWithTitle:SCILocalized(@"confirm_restart_title")
                               symbol:@"arrow.clockwise"
                              confirm:^{ exit(0); }
                               cancel:nil];
};

// Toasts
+ (void)showToastForDuration:(double)duration title:(NSString *)title {
    [SCIUtils showToastForDuration:duration title:title subtitle:nil];
}
+ (void)showToastForDuration:(double)duration title:(NSString *)title subtitle:(NSString *)subtitle {
    // Root VC
    Class rootVCClass = NSClassFromString(@"IGRootViewController");

    UIViewController *topMostVC = topMostController();
    if (![topMostVC isKindOfClass:rootVCClass]) return;

    IGRootViewController *rootVC = (IGRootViewController *)topMostVC;

    // Presenter
    IGActionableConfirmationToastPresenter *toastPresenter = [rootVC toastPresenter];
    if (toastPresenter == nil) return;

    // View Model
    Class modelClass = NSClassFromString(@"IGActionableConfirmationToastViewModel");
    IGActionableConfirmationToastViewModel *model = [modelClass new];
    
    [model setValue:title forKey:@"text_annotatedTitleText"];
    [model setValue:subtitle forKey:@"text_annotatedSubtitleText"];

    // Show new toast, after clearing existing one
    [toastPresenter hideAlert];
    [toastPresenter showAlertWithViewModel:model isAnimated:true animationDuration:duration presentationPriority:0 tapActionBlock:nil presentedHandler:nil dismissedHandler:nil];
}

// Math
+ (NSUInteger)decimalPlacesInDouble:(double)value {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [formatter setMaximumFractionDigits:15]; // Allow enough digits for double precision
    [formatter setMinimumFractionDigits:0];
    [formatter setDecimalSeparator:@"."]; // Force dot for internal logic, then respect locale for final display if needed

    NSString *stringValue = [formatter stringFromNumber:@(value)];

    // Find decimal separator
    NSRange decimalRange = [stringValue rangeOfString:formatter.decimalSeparator];

    if (decimalRange.location == NSNotFound) {
        return 0;
    } else {
        return stringValue.length - (decimalRange.location + decimalRange.length);
    }
}

// Ivars
+ (id)getIvarForObj:(id)obj name:(const char *)name {
    Ivar ivar = class_getInstanceVariable(object_getClass(obj), name);
    if (!ivar) return nil;

    return object_getIvar(obj, ivar);
}
+ (void)setIvarForObj:(id)obj name:(const char *)name value:(id)value {
    Ivar ivar = class_getInstanceVariable(object_getClass(obj), name);
    if (!ivar) return;
    
    object_setIvarWithStrongDefault(obj, ivar, value);
}


@end
