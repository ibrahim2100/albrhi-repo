//
//  SCITTRowIcon.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

///
/// The icon every row on the settings and report screens shares: one weight, one size, and the outline variant of a symbol
/// where there is one. The registry names filled symbols, which are heavy next to TikTok's own line icons and differ in
/// visual size from one symbol to the next. Colour is left to the caller: it carries meaning on these screens (the accent on
/// a switch, orange on a warning) and decoration carries none.
///
static inline UIImage *SCITTRowIcon(NSString *name) {
    UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:19 weight:UIImageSymbolWeightRegular];
    NSString *base = name.length ? name : @"circle";
    NSString *outline = [base hasSuffix:@".fill"] ? [base substringToIndex:base.length - 5] : nil;
    return (outline ? [UIImage systemImageNamed:outline withConfiguration:config] : nil)
        ?: [UIImage systemImageNamed:base withConfiguration:config];
}
