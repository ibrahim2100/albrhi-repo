//
//  SCIYTDownloadCenter.h
//  Albrhi for YouTube
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

///
/// The Download Centre.
///
/// Two tabs — video and sound — each its own list, and tapping a row plays it here rather
/// than sending it anywhere. That is the point of it: a downloaded video used to leave
/// for Photos immediately and there was no such thing as "my downloads" at all.
///
/// This class only opens the thing. The lists are `SCIYTDownloadList` and the player is
/// `SCIYTPlayer`; keeping the way in separate from what it opens means the panel, the
/// tab-bar button and anything added later all call one method.
///
@interface SCIYTDownloadCenter : NSObject

/// Opens it over whatever is on screen. Guarded; a screen that cannot be built must
/// fail to open rather than take YouTube with it.
+ (void)present;


/// Puts the page into YouTube's own content area, under the tab bar.
///
/// This is what makes it feel like Home or You rather than a window over them: the bar
/// stays, the tab stays lit, and only the content changes. Answers NO if the bar is not
/// arranged the way this expects, in which case the caller should fall back to presenting.
+ (BOOL)showInsidePivotBar:(UIViewController *)bar;

/// Takes it down again, when another tab is chosen.
+ (void)removeFromPivotBar;

/// Whether the Centre page is in the content area now (its view is in a window, which is what "on top of every page" means).
+ (BOOL)isShownInPivotBar;

@end

NS_ASSUME_NONNULL_END
