//
//  SCITTSectionBrowse.m
//  Albrhi for TikTok
//
//  Small conveniences in the feed, the browser and the profile.
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

@interface SCITTSectionBrowse : NSObject
@end

@implementation SCITTSectionBrowse

+ (void)load {
    SCITTRegisterSection(35, ^NSDictionary *{
        // Nine switches, all off. None of them tells TikTok anything untrue -- each changes what the app does or draws on this phone only,
        // which is why none carries a warning row.
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
            kSCISectionIcon: @"safari",
            kSCISectionColor: [UIColor systemBlueColor],
            kSCISectionTitle: SCILocalized(@"section_browse"),
            kSCISectionRows: @[
                row(SCIPrefOpenInSafari, SCILocalized(@"row_open_safari"), SCILocalized(@"row_open_safari_note"), @"safari.fill", [UIColor systemBlueColor]),
                row(SCIPrefHideWarnings, SCILocalized(@"row_hide_warnings"), SCILocalized(@"row_hide_warnings_note"), @"exclamationmark.triangle.fill", [UIColor systemOrangeColor]),
                row(SCIPrefHideTikBot, SCILocalized(@"row_hide_tikbot"), SCILocalized(@"row_hide_tikbot_note"), @"sparkles", [UIColor systemPurpleColor]),
                row(SCIPrefUnmute, SCILocalized(@"row_unmute"), SCILocalized(@"row_unmute_note"), @"speaker.wave.2.fill", [UIColor systemGreenColor]),
                row(SCIPrefAutoAdvance, SCILocalized(@"row_auto_advance"), SCILocalized(@"row_auto_advance_note"), @"arrow.down.to.line", [UIColor systemIndigoColor]),
                row(SCIPrefOpenFollowing, SCILocalized(@"row_open_following"), SCILocalized(@"row_open_following_note"), @"person.2.fill", [UIColor systemIndigoColor]),
                row(SCIPrefLongBio, SCILocalized(@"row_long_bio"), SCILocalized(@"row_long_bio_note"), @"text.alignleft", [UIColor systemTealColor]),
                row(SCIPrefCopyMenu, SCILocalized(@"row_copy_menu"), SCILocalized(@"row_copy_menu_note"), @"doc.on.doc.fill", [UIColor systemTealColor]),
                row(SCIPrefSaveAvatar, SCILocalized(@"row_save_avatar"), SCILocalized(@"row_save_avatar_note"), @"person.crop.circle.fill", [UIColor systemTealColor]),
            ],
        };
    });
}

@end
