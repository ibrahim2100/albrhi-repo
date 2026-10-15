//
//  SCITTChoiceList.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// The value a choice row currently holds, as its title ("" when the stored value matches no option).
NSString *SCITTChoiceCurrentTitle(NSArray<NSDictionary *> *options, NSString *pref);

/// A plain list of options with a check mark on the current one. Picking stores the value (the first option removes the key)
/// and goes back. Options are dictionaries `{@"value": NSString or NSNumber, @"title": NSString}`.
@interface SCITTChoiceList : UITableViewController

- (instancetype)initWithTitle:(NSString *)title pref:(NSString *)pref options:(NSArray<NSDictionary *> *)options footer:(nullable NSString *)footer;

@end

NS_ASSUME_NONNULL_END
