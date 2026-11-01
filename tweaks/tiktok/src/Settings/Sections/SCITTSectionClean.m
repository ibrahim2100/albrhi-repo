//
//  SCITTSectionClean.m
//  Albrhi for TikTok
//
//  What TikTok adds around the videos: surveys, the AI assistant, promotions, cards, history and the sensitive overlay.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "../SCITTStatus.h"
#import "../SCITTReport.h"
#import "../SCITTBadge.h"
#import "../../Tweak.h"
#import "../../Prefs.h"
#import "../../Localization/SCILocalize.h"
#import "../SCITTSectionRegistry.h"

@interface SCITTSectionClean : NSObject
@end

@implementation SCITTSectionClean

+ (void)load {
    SCITTRegisterSection(38, ^NSDictionary *{
        NSDictionary *(^row)(NSString *, NSString *, NSString *, NSString *, UIColor *) =
            ^NSDictionary *(NSString *pref, NSString *title, NSString *note, NSString *icon, UIColor *color) {
            return @{
                kSCIRowKind: kSCIKindSwitch,
                kSCIRowPref: pref,
                kSCIRowTitle: title,
                kSCIRowNote: note,
                kSCIRowIcon: icon,
                kSCIRowColor: color,
            };
        };
        return @{
            kSCISectionIcon: @"wand.and.stars",
            kSCISectionColor: [UIColor systemPurpleColor],
            kSCISectionTitle: SCILocalized(@"section_clean"),
            kSCISectionRows: @[
                row(SCIPrefNoSurveys, SCILocalized(@"row_no_surveys"), SCILocalized(@"row_no_surveys_note"), @"list.bullet.clipboard.fill", [UIColor systemOrangeColor]),
                row(SCIPrefHideTako, SCILocalized(@"row_hide_tako"), SCILocalized(@"row_hide_tako_note"), @"sparkles", [UIColor systemPurpleColor]),
                row(SCIPrefHidePendants, SCILocalized(@"row_hide_pendants"), SCILocalized(@"row_hide_pendants_note"), @"gift.fill", [UIColor systemPinkColor]),
                row(SCIPrefHideBoards, SCILocalized(@"row_hide_boards"), SCILocalized(@"row_hide_boards_note"), @"rectangle.on.rectangle.fill", [UIColor systemIndigoColor]),
                row(SCIPrefHideSearchHistory, SCILocalized(@"row_hide_search_history"), SCILocalized(@"row_hide_search_history_note"), @"clock.arrow.circlepath", [UIColor systemTealColor]),
                row(SCIPrefNoSensitiveMask, SCILocalized(@"row_no_sensitive_mask"), SCILocalized(@"row_no_sensitive_mask_note"), @"eye.trianglebadge.exclamationmark.fill", [UIColor systemRedColor]),
            ],
        };
    });
}

@end
