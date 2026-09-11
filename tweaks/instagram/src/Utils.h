#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuickLook/QuickLook.h>
#import <os/log.h>
#import <objc/message.h>

#import "modules/JGProgressHUD/JGProgressHUD.h"

#import "SCILog.h"
#import "InstagramHeaders.h"
#import "QuickLook.h"

#import "Localization/SCILocalize.h"
#import "Settings/SCISettingsViewController.h"

#define SCILog(fmt, ...) \
    do { \
        NSString *tmpStr = [NSString stringWithFormat:(fmt), ##__VA_ARGS__]; \
        os_log(OS_LOG_DEFAULT, "[SCInsta Test] %{public}s", tmpStr.UTF8String); \
    } while(0)

#define SCILogId(prefix, obj) os_log(OS_LOG_DEFAULT, "[SCInsta Test] %{public}@: %{public}@", prefix, obj);

@interface SCIUtils : NSObject

+ (BOOL)getBoolPref:(NSString *)key;
+ (double)getDoublePref:(NSString *)key;
+ (NSString *)getStringPref:(NSString *)key;

+ (void)cleanCache;

// Displaying View Controllers
+ (void)showQuickLookVC:(NSArray<id> *)items;
+ (void)showShareVC:(id)item;
+ (void)showSettingsVC:(UIWindow *)window;

// Colours
+ (UIColor *)SCIColor_Primary;
+ (UIColor *)colorFromHexString:(NSString *)hex;
+ (NSString *)hexStringFromColor:(UIColor *)color;
+ (void)showAccentColorPicker;
+ (void)resetAccentColor;

// Errors
+ (NSError *)errorWithDescription:(NSString *)errorDesc;
+ (NSError *)errorWithDescription:(NSString *)errorDesc code:(NSInteger)errorCode;

+ (JGProgressHUD *)showErrorHUDWithDescription:(NSString *)errorDesc;
+ (JGProgressHUD *)showErrorHUDWithDescription:(NSString *)errorDesc dismissAfterDelay:(CGFloat)dismissDelay;
+ (JGProgressHUD *)showSuccessHUDWithDescription:(NSString *)desc;

/// An indeterminate progress HUD that stays until the caller dismisses it. Used
/// for work with no byte-count to report, such as the on-device AV1 transcode.
+ (JGProgressHUD *)showProgressHUDWithText:(NSString *)text;
+ (void)copyAccountInfoForUser:(id)user;
/// Localized "Follows you" / "Doesn't follow you" for a given IGUser, or nil when
/// the relationship can't be determined (e.g. your own profile).
+ (NSString *)followStatusStringForUser:(id)user;
/// Username of the currently logged-in account, or nil. Used to avoid showing a
/// follow-back badge on your own profile.
+ (NSString *)currentUsername;

// Media
+ (NSURL *)getPhotoUrl:(IGPhoto *)photo;
+ (NSURL *)getPhotoUrlForMedia:(IGMedia *)media;

/// A story item's raw API dictionary, and a saveable video URL out of it -- the path a
/// hollow story `IGVideo` forces, since the real `video_versions` / `video_dash_manifest`
/// live in the dictionary rather than on the object. See the implementation.
+ (nullable NSDictionary *)mediaDictionary:(nullable id)media;
+ (nullable NSURL *)videoURLFromMediaDict:(nullable NSDictionary *)dict;

/// A saveable audio URL out of a story item's dictionary, with the key path it came
/// from written into @c outKeyPath for the diagnostics page. A photo story with music
/// carries its track here and on no accessor the object answers -- see the
/// implementation for why the leaf is searched rather than named.
+ (nullable NSURL *)audioURLFromMediaDict:(nullable NSDictionary *)dict
                                  keyPath:(NSString *_Nullable *_Nullable)outKeyPath;

+ (NSURL *)getVideoUrl:(IGVideo *)video;
+ (NSURL *)getVideoUrlForMedia:(id)media;
+ (NSURL *)getAudioUrlForMedia:(id)mediaLike;

/// Remembers the post a carousel slide belongs to. Music is a property of the post,
/// not of the individual slide, so a slide asked about its audio on its own has none
/// and the save-as-video choice never appears on multi-photo posts. Recorded where
/// the slides are resolved, since that is the one place both are in hand.
+ (void)rememberParentPost:(id)parent forSlide:(id)slide;
+ (NSArray<NSDictionary *> *)availableVideoQualitiesForVideo:(IGVideo *)video;

/// The raw DASH manifest XML for a video, or nil when this build exposes none.
///
/// Instagram serves video over DASH, and the manifest lists renditions that
/// -videoVersions does not carry. Nothing parses this yet: the point is to read
/// what Instagram actually sends on a real device before writing a parser
/// against a guessed schema.
+ (nullable NSString *)dashManifestXMLForVideo:(nullable id)video media:(nullable id)media;

/// Every DASH representation on a video, video and audio alike, each tagged with
/// its codec family, dimensions and direct URL. Empty when the build exposes no
/// manifest. Phase two reads the audio and AV1 entries; phase one uses only the
/// saveable video ones.
+ (NSArray<NSDictionary *> *)dashRepresentationsForVideo:(nullable id)video media:(nullable id)media;

/// The same, parsed from a manifest string already in hand (the diagnostics page
/// keeps the last one), so the ladder can be shown without another live fetch.
+ (NSArray<NSDictionary *> *)dashRepresentationsFromXML:(nullable NSString *)xml;

/// The highest-resolution rendition iOS can save as-is, drawn from the DASH ladder
/// and -videoVersions together. Never returns less than -getVideoUrl: would: that
/// remains the floor, so an AV1-only clip still downloads at its progressive best.
+ (nullable NSURL *)getBestVideoUrl:(nullable IGVideo *)video;

/// A plan for transcoding, or nil when transcoding would not raise the quality.
///
/// Returned only when the AV1 ladder offers a resolution higher than anything iOS
/// can save directly — the case the transcoder exists for. Keys: @c videoURL
/// (AV1), optional @c audioURL (xHE-AAC), @c fps, @c width, @c height.
+ (nullable NSDictionary *)transcodePlanForVideo:(nullable id)video media:(nullable id)media;

/// As above, but for one chosen rung of the AV1 ladder. Zero means "the best one",
/// which is what the automatic path passes and what it has always done.
+ (nullable NSDictionary *)transcodePlanForVideo:(nullable id)video
                                           media:(nullable id)media
                                 preferredHeight:(long long)preferredHeight;

/// The distinct AV1 resolutions on offer, tallest first, for the optional picker.
+ (NSArray<NSDictionary *> *)transcodeOptionsForVideo:(nullable id)video media:(nullable id)media;

/// Every zero-argument selector on an object's class hierarchy whose name
/// contains @c needle, case-insensitively.
///
/// The first version of the DASH probe guessed four selector names and found
/// none of them, which is the mistake this project keeps paying for: a name
/// that exists in a class dump is not a name the object answers to. Asking the
/// runtime what the object actually responds to replaces the guess with a fact.
+ (NSArray<NSString *> *)selectorsMatching:(NSString *)needle onObject:(nullable id)object;

// Quality-selection helpers (IGAPIVideoVersion objects or dictionaries)
+ (long long)qualityValueFrom:(id)version key:(NSString *)key;
+ (NSString *)urlStringFromVersion:(id)version;
+ (NSURL *)bestURLFromVersions:(id)versions;

// View Controllers
+ (UIViewController *)viewControllerForView:(UIView *)view;
+ (UIViewController *)viewControllerForAncestralView:(UIView *)view;
+ (UIViewController *)nearestViewControllerForView:(UIView *)view;

// Functions
+ (NSString *)IGVersionString;
+ (BOOL)isNotch;

+ (BOOL)existingLongPressGestureRecognizerForView:(UIView *)view;

// Alerts
+ (BOOL)showConfirmation:(void(^)(void))okHandler title:(NSString *)title;
+ (BOOL)showConfirmation:(void(^)(void))okHandler cancelHandler:(void(^)(void))cancelHandler title:(NSString *)title;
+ (BOOL)showConfirmation:(void(^)(void))okHandler;
+ (BOOL)showConfirmation:(void(^)(void))okHandler cancelHandler:(void(^)(void))cancelHandler;
+ (void)showRestartConfirmation;

// Toasts
+ (void)showToastForDuration:(double)duration title:(NSString *)title;
+ (void)showToastForDuration:(double)duration title:(NSString *)title subtitle:(NSString *)subtitle;

// Math
+ (NSUInteger)decimalPlacesInDouble:(double)value;

// Ivars
+ (id)getIvarForObj:(id)obj name:(const char *)name;
+ (void)setIvarForObj:(id)obj name:(const char *)name value:(id)value;

@end
