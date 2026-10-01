//
//  SCIYTChecklistRow.h
//  Albrhi for YouTube
//
//  One row that stands for a group of switches.
//
//  Eight SponsorBlock categories and four hidden top-bar buttons are twelve rows that are each
//  rarely changed after the first time and are all the same kind of decision. A row that says
//  how many of them are on and opens the list keeps the page short without hiding anything:
//  every switch is still one tap from where it was, and its preference key is unchanged, so a
//  backup or a preset written before this still applies.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCIYTSettingRow.h"
#import "SCIYTSettingsRegistry.h"

NS_ASSUME_NONNULL_BEGIN

@interface SCIRow (Checklist)

/// A disclosure row whose detail reads "3 of 8 on" and which pushes a screen holding `items`
/// (switch rows). The count is taken when the page is built, which the settings screen does
/// every time it appears, so coming back from the list shows the number it just changed.
///
/// @param footer shown under the list on the pushed screen; may be nil.
+ (instancetype)checklistRow:(NSString *)title
                      symbol:(nullable NSString *)symbol
                       items:(NSArray<SCIRow *> *)items
                      footer:(nullable NSString *)footer
                        host:(SCIYTSettingsHostController *)host;

@end

NS_ASSUME_NONNULL_END
