//
//  SCIPanelHero.h
//  Albrhi Panel
//
//  The card at the top of the panel.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIPanelHero : NSObject

/// The table header: a dark gradient card carrying the mark, the name, the tagline and two chips (the version and how many apps are on).
/// `masterOn` NO dims the second chip and says so -- the page's one handle, repeated where it is read first.
+ (UIView *)viewForWidth:(CGFloat)width
                 version:(NSString *)version
                      on:(NSInteger)on
                      of:(NSInteger)total
                masterOn:(BOOL)masterOn;

@end

NS_ASSUME_NONNULL_END
