//
//  SCIYTChapterSheet.h
//  Albrhi for YouTube
//
//  The chapters of the playing file (SponsorBlock's community chapters, kept with the file), to jump to.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIYTChapterSheet : UITableViewController
/// `chapters`: `@{@"start": seconds, @"title": name}` in time order. `current` is the index playing
/// now (or -1). `jump` is called with the chosen start.
+ (void)presentFrom:(UIViewController *)presenter
           chapters:(NSArray<NSDictionary *> *)chapters
            current:(NSInteger)current
               jump:(void (^)(double seconds))jump;
@end

NS_ASSUME_NONNULL_END
