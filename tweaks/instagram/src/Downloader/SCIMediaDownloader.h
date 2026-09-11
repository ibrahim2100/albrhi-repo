#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "../InstagramHeaders.h"

NS_ASSUME_NONNULL_BEGIN

///
/// The single entry point for downloading media.
///
/// Before this existed, each surface — feed video, reel, story, the inline button —
/// built its own download call. The quality picker was wired into exactly one of
/// them, so "choose quality before download" silently did nothing everywhere else.
///
/// Every path now funnels through here, which owns the whole decision chain:
/// quality picker → queue or direct → the right delegate for the media kind.
///

@interface SCIMediaDownloader : NSObject

/// Downloads a video, offering the resolution picker first when enabled and more
/// than one rendition exists.
/// @param anchor The view an iPad action sheet points at. Required on iPad.
+ (void)downloadVideo:(IGVideo *)video
          sourceLabel:(nullable NSString *)sourceLabel
               anchor:(nullable UIView *)anchor;

/// Downloads an already-resolved URL. Used for photos and audio, which have no
/// rendition choice.
+ (void)downloadURL:(NSURL *)url
        sourceLabel:(nullable NSString *)sourceLabel
              isVideo:(BOOL)isVideo;

/// Resolves an IGMedia-like object to its video or photo and downloads it.
/// Video wins when both are present.
+ (void)downloadMedia:(id)media
          sourceLabel:(nullable NSString *)sourceLabel
               anchor:(nullable UIView *)anchor;


/// Finds the currently-visible story media inside a view hierarchy and downloads
/// it. Powers the on-screen story download button.
+ (void)downloadVisibleStoryInView:(UIView *)root anchor:(nullable UIView *)anchor;

/// The section controller and model the story viewer is about to display, handed
/// over by Instagram's own delegate call.
///
/// **A hooked method's argument needs no class-name search, and the search is what
/// broke.** The view route below binds `IGStoryModernVideoView`/`IGStoryPhotoView` by
/// name; on a build that renames or re-nests them it matches nothing, the item comes
/// back nil, and the button says "no media" before the downloader is ever entered --
/// which is exactly what a device on 439 reported, with the download-kind row blank.
/// `-fullscreenSectionController:willDisplayStoryModel:` is already hooked for the
/// mark-as-seen skip and already fires on both tested builds, so the object arrives
/// for free and cannot be renamed out from under us.
+ (void)noteStorySection:(nullable id)controller model:(nullable id)model;

/// Whether this media has a video that can actually be resolved to a URL right now —
/// asking every source `+downloadVideo:` itself would use, including the DASH manifest.
///
/// Exposed so the button's own media search can *prefer* a candidate that answers YES.
/// A NO from here means "no rendition available", never "this is a photo": the kind is
/// decided separately inside `+downloadMedia:`, because a repost answers NO while still
/// being a video.
+ (BOOL)hasPlayableVideo:(nullable IGVideo *)video;

@end

NS_ASSUME_NONNULL_END
