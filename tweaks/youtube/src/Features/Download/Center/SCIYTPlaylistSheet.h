//
//  SCIYTPlaylistSheet.h
//  Albrhi for YouTube
//
//  Download a whole playlist: paste its link, see what is in it, pick one quality for all of it,
//  and let the Centre work through the videos two at a time.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIYTPlaylistSheet : UITableViewController

/// Presents it over `presenter`. A playlist link on the pasteboard is picked up and loaded.
+ (void)presentFrom:(UIViewController *)presenter;

@end

NS_ASSUME_NONNULL_END
