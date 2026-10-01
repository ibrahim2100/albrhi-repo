//
//  SCITWChecklistRow.h
//  Albrhi for X
//
//  One row that stands for a few switches, and says how many of them are on.
//
//  Three confirmations side by side are three rows doing one job; a row reading "1 of 3 on"
//  that opens the list keeps the page short and hides nothing -- every switch keeps its own
//  preference key, so a backup written before this still applies.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCITWRow.h"

NS_ASSUME_NONNULL_BEGIN

@interface SCITWRow (Checklist)

/// An action row whose note is "N of M on" and which pushes a screen holding `items`
/// (switch rows). Counted when the page is built, which happens on every appearance, so the
/// number is current when the user comes back from the list.
+ (instancetype)checklistRow:(NSString *)title
                      symbol:(nullable NSString *)symbol
                        tint:(nullable UIColor *)tint
                       items:(NSArray<SCITWRow *> *)items
                      footer:(nullable NSString *)footer
                        host:(UIViewController *)host;

@end

NS_ASSUME_NONNULL_END
