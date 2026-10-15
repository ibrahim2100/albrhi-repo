//
//  SCITTSectionPrivacy.m
//  Albrhi for TikTok
//
//  Reports withheld from leaving the device.
//
//  **One section, one file, registered by itself.** It was a block inside a 220-line array
//  literal in SCITTStatus.m; adding a row meant editing the middle of that list and deleting
//  a feature meant counting braces. Nothing outside this file knows the section exists --
//  see SCITTSectionRegistry.h for why that is the point.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "../SCITTStatus.h"
#import "../SCITTReport.h"
#import "../SCITTBadge.h"
#import "../../UI/SCITTWelcome.h"
#import "../../Tweak.h"
#import "../../Prefs.h"
#import "../../Localization/SCILocalize.h"
#import <objc/runtime.h>
#import "../SCITTSectionRegistry.h"

@interface SCITTSectionPrivacy : NSObject
@end

@implementation SCITTSectionPrivacy

+ (void)load {
    SCITTRegisterSection(30, ^NSDictionary *{
        return @{
            // Three switches, not one. A story's seen mark, a message's read receipt and a profile
            // view are three reports to three different places, and one switch bundling them could
            // never be turned off for just one.
            kSCISectionIcon: @"hand.raised.fill",
            kSCISectionColor: [UIColor systemTealColor],
            kSCISectionTitle: SCILocalized(@"section_privacy"),
            kSCISectionRows: @[
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefPrivacyStory,
                    kSCIRowTitle: SCILocalized(@"row_privacy_story"),
                    kSCIRowNote: SCILocalized(@"row_privacy_story_note"),
                    kSCIRowIcon: @"eye.slash.fill",
                    kSCIRowColor: [UIColor systemTealColor],
                },
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefPrivacyMessages,
                    kSCIRowTitle: SCILocalized(@"row_privacy_messages"),
                    kSCIRowNote: SCILocalized(@"row_privacy_messages_note"),
                    kSCIRowIcon: @"message.fill",
                    kSCIRowColor: [UIColor systemTealColor],
                },
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefPrivacyProfile,
                    kSCIRowTitle: SCILocalized(@"row_privacy_profile"),
                    kSCIRowNote: SCILocalized(@"row_privacy_profile_note"),
                    kSCIRowIcon: @"person.fill.questionmark",
                    kSCIRowColor: [UIColor systemTealColor],
                },
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefReadAlert,
                    kSCIRowTitle: SCILocalized(@"row_read_alert"),
                    kSCIRowNote: SCILocalized(@"row_read_alert_note"),
                    kSCIRowIcon: @"bell.badge.fill",
                    kSCIRowColor: [UIColor systemTealColor],
                },
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefHideOnline,
                    kSCIRowTitle: SCILocalized(@"row_hide_online"),
                    kSCIRowNote: SCILocalized(@"row_hide_online_note"),
                    kSCIRowIcon: @"circle.slash",
                    kSCIRowColor: [UIColor systemTealColor],
                },
            ],
        };
    });
}

@end
