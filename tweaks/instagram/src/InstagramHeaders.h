#import <Foundation/Foundation.h>
#include <objc/NSObject.h>
#import <UIKit/UIKit.h>
#import "modules/JGProgressHUD/JGProgressHUD.h"

#ifdef __cplusplus
#define _Bool bool
#endif

@interface NSURL ()
- (id)normalizedURL; // method provided by Instagram app
@end

@interface IGActionableConfirmationToastViewModel : NSObject {
    NSString *_text_annotatedTitleText;
    NSString *_text_annotatedSubtitleText;
}
@end

@interface IGActionableConfirmationToastPresenter : NSObject
- (void)showAlertWithViewModel:(id)model isAnimated:(_Bool)animated animationDuration:(double)duration presentationPriority:(long long)priority tapActionBlock:(id)tap presentedHandler:(id)presented dismissedHandler:(id)dismissed;
- (void)hideAlert;
@end

@interface IGRootViewController : UIViewController
- (IGActionableConfirmationToastPresenter *)toastPresenter;

- (void)addHandleLongPress; // new
- (void)handleLongPress:(UILongPressGestureRecognizer *)sender; // new
@end

@interface IGViewController : UIViewController
- (void)_superPresentViewController:(UIViewController *)viewController animated:(BOOL)animated completion:(id)completion;
@end

@interface IGMainFeedAppHeaderController : UIViewController
- (void)_superPresentViewController:(UIViewController *)viewController animated:(BOOL)animated completion:(id)completion; // new
@end

@interface IGShimmeringGridView : UIView
@end

@interface IGExploreGridViewController : IGViewController
@end

@interface UIImage ()
- (NSString *)ig_imageName;
@end

@interface IGProfileMenuSheetViewController :  IGViewController
@end

@interface IGTabBar: UIView
@end

@interface IGTabBarController : UIViewController
@end

@interface IGTableViewCell: UITableViewCell
- (id)initWithReuseIdentifier:(NSString *)identifier;
@end

@interface IGProfileSheetTableViewCell : IGTableViewCell
@end

@interface IGTallNavigationBarView : UIView
@end

@interface UIView (RCTViewUnmounting)
@property(retain, nonatomic) UIViewController *viewController;
- (UIView *)_rootView;
@end

@interface IGImageSpecifier : NSObject
@property(readonly, nonatomic) NSURL *url;
@end

// A single video quality variant (from -[IGVideo videoVersions])
@interface IGAPIVideoVersion : NSObject
- (id)width;      // NSNumber
- (id)height;     // NSNumber
- (id)bandwidth;  // NSNumber
- (id)urlString;  // NSString
@end

@interface IGVideo : NSObject
- (id)sortedVideoURLsBySize; // Before Instagram v398 — sorted ascending by size
- (id)allVideoURLs; // After Instagram v398 — UNORDERED NSSet
- (id)videoVersions; // Array of IGAPIVideoVersion (has width/height/bandwidth/urlString)
- (long long)numberOfQualities;
// DASH manifest XML — carries the real multi-resolution ladder (1080p etc.) that
// videoVersions often omits. Selector name varies between builds, so read defensively.
- (id)videoDashManifest;
- (id)dashManifest;
- (id)videoDashManifestXML;
@end

@interface IGPhoto : NSObject
- (id)imageURLForWidth:(CGFloat)width;
@end

@interface IGBaseMedia : NSObject
@property (retain, nonatomic) id explorePostInFeed;
@end

// Reels/clips audio asset — exposes the downloadable audio file URL
@interface IGSundialOriginalAudioAsset : NSObject
- (id)audioFileUrl;        // NSString/NSURL to the raw audio
- (id)albumArtUrl;
- (id)title;
- (id)artist;
@end

@interface IGMedia : IGBaseMedia
@property(readonly) IGVideo *video;
@property(readonly) IGPhoto *photo;
- (id)sundialOriginalAudioAsset;  // original audio (reels)
- (id)sundialMusicAsset;          // licensed music (reels)
@end

@interface IGPostItem : NSObject
@property(readonly) IGVideo *video;
@property(readonly) IGPhoto *photo;
@end

@interface IGPageMediaView : UIView
@property(readonly) NSMutableArray <IGPostItem *> *items;
- (IGPostItem *)currentMediaItem;
@end

@interface IGFeedItem : NSObject
@property long long likeCount;
@property(readonly) IGVideo *video;
- (BOOL)isSponsored;
- (BOOL)isSponsoredApp;
@end

@interface IGImageView : UIImageView
@property(retain, nonatomic) IGImageSpecifier *imageSpecifier;
@end

@interface IGFeedItemPagePhotoCell : UICollectionViewCell
@property (nonatomic, strong) id post;
@property (nonatomic, strong) IGPostItem *pagePhotoPost;
@end

@interface IGProfilePicturePreviewViewController : UIViewController
{
    IGImageView *_profilePictureView;
}
@property (nonatomic, strong) JGProgressHUD *hud;
- (void)addHandleLongPress; // new
- (void)handleLongPress:(UILongPressGestureRecognizer *)sender; // new
@end

@interface IGFeedItemMediaCell : UICollectionViewCell
@property(retain, nonatomic) IGMedia *post;
- (UIImage *)mediaCellCurrentlyDisplayedImage;
@end

@interface IGFeedItemPhotoCell : IGFeedItemMediaCell
@end

@interface IGFeedItemPhotoCellConfiguration : NSObject
@end

@interface IGFeedPhotoView : UIView
@property (nonatomic, strong) id delegate;

- (void)addLongPressGestureRecognizer; // new
@end

@interface IGModernFeedVideoCell : UIView
- (id)mediaCellFeedItem;
- (void)addLongPressGestureRecognizer; // new
@end

// Full-screen story viewer. Declared as a UIViewController so features can reach
// `view` — without this Logos only emits a forward declaration and any property
// access fails to compile.
@interface IGStoryViewerViewController : UIViewController
- (void)sciToggleStorySeen:(id)sender; // new
- (void)sciEnsureStorySeenButton;      // new
- (void)sciEnsureStoryDownloadButton;  // new
- (void)sciDownloadStory:(id)sender;   // new
@end

// Post action row (like · comment · send · … · save). Hosts the inline download
// button. Instagram also ships a Swift equivalent, IGSocialUFIView, which is
// hooked by name in InlineDownloadButton.xm — it has no header here because a
// dotted Swift class name isn't expressible as an @interface.
@interface IGUFIButtonBarView : UIView
- (void)sciInlineDownloadPressed:(id)sender; // new
@end

// The action row Instagram 410 actually renders. Confirmed by a live hierarchy
// scan: it holds `save-button` directly, while the like and comment buttons are
// wrapped in IGUFIButtonWithCountsView containers that are not UIControls
// themselves — which is why counting only direct UIControl children finds one.
@interface IGUFIInteractionCountsView : UIView
- (void)sciInlineDownloadPressed:(id)sender; // new
@end

@interface IGSundialViewerVideoCell : UIView
@property(readonly, nonatomic) IGMedia *video;

- (void)addLongPressGestureRecognizer; // new
@end

@interface IGSundialViewerPhotoView : UIView
- (void)addLongPressGestureRecognizer; // new
@end

@interface IGImageProgressView : UIView
@property(retain, nonatomic) IGImageSpecifier *imageSpecifier;
@end

@interface IGStatefulVideoPlayer : NSObject
@end

@interface IGStoryPhotoView : UIView
- (id)item;

- (void)addLongPressGestureRecognizer; // new
@end

@interface IGStoryFullscreenSectionController : NSObject
@property (nonatomic, strong, readwrite) IGMedia *currentStoryItem;
@end

@interface IGStoryVideoView : UIView
@property (nonatomic, weak, readwrite) IGStoryFullscreenSectionController *captionDelegate;

- (void)addLongPressGestureRecognizer; // new
@end

@interface IGStoryModernVideoView : UIView
@property (nonatomic, readonly) IGMedia *item;

- (void)addLongPressGestureRecognizer; // new
@end

@interface IGStoryFullscreenOverlayView : UIView
@property (nonatomic, weak, readwrite) id gestureDelegate;
- (id)gestureDelegate;
- (void)addLongPressGestureRecognizer; // new
@end

@interface IGDirectVisualMessageViewerController : UIViewController
- (void)sciAddVisualSeenButton;         // new
- (void)sciToggleVisualSeen:(id)sender;   // new
- (void)sciAddVisualSaveButton;         // new
- (void)sciSaveVisualMessage:(id)sender;  // new
@end

// Full-screen viewer for regular photos/videos sent in DMs (IG 410). Its init hands
// over the photo and video objects and an `allowSavingMedia` flag we can force on.
@interface IGDirectMediaViewerViewController : UIViewController
- (void)sciAddDMSaveButton;         // new
- (void)sciSaveDMMedia:(id)sender;  // new
@end

@interface IGDirectVisualMessageViewerViewModeAwareDataSource : NSObject
@end

@interface IGDirectVisualMessage : NSObject
- (id)rawVideo;
- (id)photo;   // IGPhoto for a view-once photo
- (id)video;   // IGVideo for a view-once video
@end

@interface IGUser : NSObject
@property NSInteger followStatus;
@property(copy) NSString *username;
@property BOOL followsCurrentUser;
- (NSURL *)HDProfilePicURL;          // full-resolution profile picture
- (id)HDMultipleProfilePicURLs;      // array of HD variants (pick largest)
- (CGSize)HDProfilePicSize;
- (NSURL *)profilePicURL;
- (BOOL)computedIsVerified;          // real verified-badge state
- (NSString *)displayName;           // user's display name
@end

@interface IGFollowController : NSObject 
@property IGUser *user;
@end

// DM thread header: the call buttons and the title/presence view.
@interface IGDirectCallButton : UIView
@end

@interface IGDirectThreadCallButtonsCoordinator : NSObject
@end

@interface IGDirectLeftAlignedTitleView : UIView
@end

// Both removal paths for an unsent message.
@interface IGDirectRealtimeIrisThreadDelta : NSObject
@end

@interface IGDirectMessageUpdate : NSObject
@end

@interface IGCoreTextView : UIView
@end

@interface IGUserSession : NSObject
@property (readonly, nonatomic) IGUser *user;
@end

@interface IGWindow : UIWindow
@property (nonatomic) __weak IGUserSession *userSession;
@end

@interface IGShakeWindow : UIWindow
@property (nonatomic) __weak IGUserSession *userSession;
@end

@interface IGStyledString : NSObject
@property (retain, nonatomic) NSMutableAttributedString *attributedString;
- (void)appendString:(id)arg1;
@end

@interface IGInstagramAppDelegate : NSObject <UIApplicationDelegate>
@end

@interface IGDirectInboxSearchAIAgentsPillsContainerCell : UIView
@end

@interface IGTapButton : UIButton
@end

@interface IGLabel : UILabel
@end

@interface IGLabelItemViewModel : NSObject
- (id)labelTitle;
- (id)uniqueIdentifier;
@end

@interface IGDirectInboxSuggestedThreadCellViewModel : NSObject
@end

@interface IGDirectInboxHeaderCellViewModel : NSObject
- (id)title;
@end

@interface IGSearchResultViewModel : NSObject
- (id)title;
- (NSUInteger)itemType;
@end

@interface IGDirectShareRecipient : NSObject
- (NSString *)threadName;
- (BOOL)isBroadcastChannel;
@end

@interface IGDirectRecipientCellViewModel : NSObject
- (id)recipient;
- (NSInteger)sectionType;
@end

@interface IGDirectInboxSearchAIAgentsSuggestedPromptRowCell : UIView
@end

@interface IGDSSegmentedPillBarView : UIView
- (id)delegate;
@end

@interface IGImageWithAccessoryButton : IGTapButton
- (void)addLongPressGestureRecognizer; // new
- (void)handleLongPress:(UILongPressGestureRecognizer *)gr; // new
@end

@interface IGHomeFeedHeaderViewController
- (void)headerDidLongPressLogo:(id)arg1;
@end

@interface IGSearchBarDonutButton : UIView
@end

@interface IGAnimatablePlaceholderTextField : UITextField
@end

@interface IGDirectCommandSystemViewModel : NSObject
- (id)row;
@end

@interface IGDirectCommandSystemRow : NSObject
@end

@interface IGDirectCommandSystemResult : NSObject
- (id)title;
- (id)commandString;
@end

@interface IGGrowingTextView : UIView
- (id)placeholderText;
- (void)setPlaceholderText:(id)arg1;
@end

@interface IGUnifiedVideoCollectionView : UIScrollView
@end

@interface IGBadgedNavigationButton : UIView
- (void)addLongPressGestureRecognizer; // new
@end

@interface IGSearchBar : UIView
- (NSObject *)sanitizePlaceholderForConfig:(NSObject *)config; // new
@end

@interface IGSearchBarConfig : NSObject
@end

@interface IGDirectComposer : UIView
- (NSObject *)patchConfig:(NSObject *)config; // new
@end

@interface IGDirectComposerConfig : NSObject
@end

@interface IGAnimatablePlaceholderTextFieldContainer : UIView
@end

@interface IGDirectInboxConfig : NSObject
@end

@interface IGDirectMediaPickerConfig : NSObject
@end

@interface IGDirectMediaPickerGalleryConfig : NSObject
@end

@interface IGStoryEyedropperToggleButton : UIControl
@property (nonatomic, strong, readwrite) UIColor *color;

- (void)setPushedDown:(BOOL)pushedDown;

- (void)addLongPressGestureRecognizer; // new
@end

@interface IGStoryTextEntryViewController : UIViewController
- (void)textViewControllerDidUpdateWithColor:(id)color colorSource:(NSInteger)source;
@end

@interface IGStoryColorPaletteView : UIView
@end

@interface IGProfilePictureImageView : UIView
@property (nonatomic, readonly) IGUser *userGQL;

- (void)addLongPressGestureRecognizer; // new
@end

// The IG 410 profile stats row (Swift). Its followers stat button carries the
// accessibility id `user-detail-header-followers`. Hooked to host the follow badge.
@interface IGProfileHeaderStatButtonContainerView : UIView
@end

@interface IGImageRequest : NSObject
- (id)url;
@end

@interface IGDiscoveryGridItem : NSObject
- (id)model;
@end

@interface IGStoryTextEntryControlsOverlayView : UIView

@property (readonly, nonatomic) NSMutableArray *animationTypes;
@property (readonly, nonatomic) NSMutableArray *effectTypes;

- (void)reloadData;

@end

@interface _TtC27IGGalleryDestinationToolbar31IGGalleryDestinationToolbarView : UIView
@property(nonatomic, copy, readwrite) NSArray *tools;
@end

// The reels action bar — the same idea as the feed row, stacked vertically down
// the right edge. Hosts the inline download button there.
@interface IGSundialViewerVerticalUFI : UIView
- (void)_didTapLikeButton:(id)arg1;
- (void)_didTapRepostButton:(id)arg1;

- (void)sciInlineDownloadPressed:(id)sender; // new
@end

@interface IGMainAppSurfaceIntent : NSObject
- (id)tabStringFromSurfaceIntent;
@end

@interface IGSundialFeedViewController : UIViewController
- (void)refreshControlDidEndFinishLoadingAnimation:(id)arg1;
- (BOOL)autoAdvanceToNextItem; // IG's own auto-advance-to-next-reel switch
- (BOOL)autoScrollState;
@end

@interface IGRefreshControl : UIControl
@end

@interface IGDirectThreadViewDrawingViewController : UIViewController
- (void)drawingControls:controls didSelectColor:color;
@end

@interface IGSundialViewerNavigationBarOld : UIView
@end

@interface IGFeedItemUFICell : UIView
- (void)UFIButtonBarDidTapOnRepost:(id)arg1;
@end

@interface IGNotesCreationFeatureSupportModel : NSObject
@end

@interface IGNotesCustomThemeCreationModel : NSObject
+ (id)defaultModelForExpressiveEmojiType:(id)arg1;
@end

@interface IGDirectNotesComposerViewController : UIViewController
- (void)notesBubbleEditorViewControllerDidUpdateWithCustomThemeCreationModel:(id)model;
@end

@interface IGDirectNotesBubbleEditorColorPaletteView : UIView
@property (nonatomic, copy) UIColor *backgroundColor; // new
@property (nonatomic, copy) UIColor *textColor; // new
@property (nonatomic, copy) NSString *emojiText; // new

- (void)presentColorPicker:(NSString *)target; // new
- (void)applySCICustomTheme:(NSString *)target; // new
@end

@interface _TtC20IGDirectNotesUISwift39IGDirectNotesBubbleEditorViewController : UIViewController
@property (nonatomic) IGDirectNotesComposerViewController *delegate;
@end

@interface IGDSBottomButtonsView : UIView
- (void)setPrimaryButtonEnabled:(BOOL)enabled;
- (void)setSecondaryButtonEnabled:(BOOL)enabled;
@end

@interface IGStoryTrayViewModel : NSObject
@property (nonatomic, readonly) NSString *pk;
@property (nonatomic, readonly) BOOL isUnseenNux;
@end

@interface _TtC32IGSundialOrganicCTAContainerView32IGSundialOrganicCTAContainerView : UIView
@end

@interface IGCommentThreadViewController : UIViewController
@end

@interface IGSeeAllItemConfiguration : NSObject
@property (readonly, nonatomic) long long destination;
@end

@interface IGDSMenuItem : NSObject
- (instancetype)initWithTitle:(NSString *)title image:(UIImage *)image handler:(void (^)(void))handler;
@end

// The sheet behind the composer's plus button.
@interface IGDSMenu : NSObject
@end

// A voice message: the wrapper, and the audio it actually holds.
@interface IGAudio : NSObject
@end

@interface IGDirectAudio : NSObject
@end

@interface IGDirectThreadViewController : UIViewController
- (void)markLastMessageAsSeen;
@end

@interface IGTabBarButton : UIButton
- (void)addHandleLongPress; // new
@end

@interface IGStoryFullscreenDefaultFooterView : NSObject
@end

@interface IGDirectThreadThemePickerOption : NSObject
@end

@interface IGCreationActionBarButton : UIButton
@end

@interface IGCreationActionBarLabeledButton : NSObject
@property (readonly, nonatomic) IGCreationActionBarButton *button;
@end



/////////////////////////////////////////////////////////////////////////////



static BOOL is_iPad() {
    if ([(NSString *)[UIDevice currentDevice].model hasPrefix:@"iPad"]) {
        return YES;
    }
    return NO;
}



/////////////////////////////////////////////////////////////////////////////



static UIViewController * _Nullable _topMostController(UIViewController * _Nonnull cont) {
    UIViewController *topController = cont;
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    if ([topController isKindOfClass:[UINavigationController class]]) {
        UIViewController *visible = ((UINavigationController *)topController).visibleViewController;
        if (visible) {
            topController = visible;
        }
    }
    return (topController != cont ? topController : nil);
}
static UIViewController * _Nonnull topMostController() {
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
    UIViewController *next = nil;
    while ((next = _topMostController(topController)) != nil) {
        topController = next;
    }
    return topController;
}

@class FLEXAlert, FLEXAlertAction;

typedef void (^FLEXAlertReveal)(void);
typedef void (^FLEXAlertBuilder)(FLEXAlert *make);
typedef FLEXAlert * _Nonnull (^FLEXAlertStringProperty)(NSString * _Nullable);
typedef FLEXAlert * _Nonnull (^FLEXAlertStringArg)(NSString * _Nullable);
typedef FLEXAlert * _Nonnull (^FLEXAlertTextField)(void(^configurationHandler)(UITextField *textField));
typedef FLEXAlertAction * _Nonnull (^FLEXAlertAddAction)(NSString *title);
typedef FLEXAlertAction * _Nonnull (^FLEXAlertActionStringProperty)(NSString * _Nullable);
typedef FLEXAlertAction * _Nonnull (^FLEXAlertActionProperty)(void);
typedef FLEXAlertAction * _Nonnull (^FLEXAlertActionBOOLProperty)(BOOL);
typedef FLEXAlertAction * _Nonnull (^FLEXAlertActionHandler)(void(^handler)(NSArray<NSString *> *strings));

@interface FLEXAlert : NSObject

// Shows a simple alert with one button which says "Dismiss"
+ (void)showAlert:(NSString * _Nullable)title message:(NSString * _Nullable)message from:(UIViewController *)viewController;

// Shows a simple alert with no buttons and only a title, for half a second
+ (void)showQuickAlert:(NSString *)title from:(UIViewController *)viewController;

// Construct and display an alert
+ (void)makeAlert:(FLEXAlertBuilder)block showFrom:(UIViewController *)viewController;
// Construct and display an action sheet-style alert
+ (void)makeSheet:(FLEXAlertBuilder)block
         showFrom:(UIViewController *)viewController
           source:(id)viewOrBarItem;

// Construct an alert
+ (UIAlertController *)makeAlert:(FLEXAlertBuilder)block;
// Construct an action sheet-style alert
+ (UIAlertController *)makeSheet:(FLEXAlertBuilder)block;

// Set the alert's title.
///
// Call in succession to append strings to the title.
@property (nonatomic, readonly) FLEXAlertStringProperty title;
// Set the alert's message.
///
// Call in succession to append strings to the message.
@property (nonatomic, readonly) FLEXAlertStringProperty message;
// Add a button with a given title with the default style and no action.
@property (nonatomic, readonly) FLEXAlertAddAction button;
// Add a text field with the given (optional) placeholder text.
@property (nonatomic, readonly) FLEXAlertStringArg textField;
// Add and configure the given text field.
///
// Use this if you need to more than set the placeholder, such as
// supply a delegate, make it secure entry, or change other attributes.
@property (nonatomic, readonly) FLEXAlertTextField configuredTextField;

@end

@interface FLEXAlertAction : NSObject

// Set the action's title.
///
// Call in succession to append strings to the title.
@property (nonatomic, readonly) FLEXAlertActionStringProperty title;
// Make the action destructive. It appears with red text.
@property (nonatomic, readonly) FLEXAlertActionProperty destructiveStyle;
// Make the action cancel-style. It appears with a bolder font.
@property (nonatomic, readonly) FLEXAlertActionProperty cancelStyle;
// Enable or disable the action. Enabled by default.
@property (nonatomic, readonly) FLEXAlertActionBOOLProperty enabled;
// Give the button an action. The action takes an array of text field strings.
@property (nonatomic, readonly) FLEXAlertActionHandler handler;
// Access the underlying UIAlertAction, should you need to change it while
// the encompassing alert is being displayed. For example, you may want to
// enable or disable a button based on the input of some text fields in the alert.
// Do not call this more than once per instance.
@property (nonatomic, readonly) UIAlertAction *action;

@end
@interface FLEXManager : NSObject
+ (instancetype)sharedManager;
- (void)showExplorer;
- (void)hideExplorer;
- (void)toggleExplorer;
@end