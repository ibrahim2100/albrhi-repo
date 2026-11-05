//
//  SCIYTQueueSheet.h
//  Albrhi for YouTube
//
//  The player's queue as a sheet: what is playing, what is next, reorderable and removable.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIYTQueueSheet : UITableViewController
+ (void)presentFrom:(UIViewController *)presenter;
@end

NS_ASSUME_NONNULL_END
