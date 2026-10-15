//
//  SCITTSectionExtras.m
//  Albrhi for TikTok
//
//  Things that belong to no other section.
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

@interface SCITTSectionExtras : NSObject
@end

@implementation SCITTSectionExtras

+ (void)load {
    SCITTRegisterSection(40, ^NSDictionary *{
        return @{
            // **Three features that share nothing but where they were found.** Each was confirmed
            // against the real 46.4.0 binary before a hook was written, and each installs on its
            // own -- a build missing one class must not cost the other two.
            kSCISectionIcon: @"sparkles",
            kSCISectionColor: [UIColor systemPurpleColor],
            kSCISectionTitle: SCILocalized(@"section_extras"),
            kSCISectionRows: @[
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefUnlimitedAccounts,
                    kSCIRowTitle: SCILocalized(@"row_accounts"),
                    kSCIRowNote: SCILocalized(@"row_accounts_note"),
                    kSCIRowIcon: @"person.2.fill",
                    kSCIRowColor: [UIColor systemIndigoColor],
                },
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefNoLoop,
                    kSCIRowTitle: SCILocalized(@"row_no_loop"),
                    kSCIRowNote: SCILocalized(@"row_no_loop_note"),
                    kSCIRowIcon: @"repeat.circle.fill",
                    kSCIRowColor: [UIColor systemIndigoColor],
                },
                @{
                    kSCIRowKind: kSCIKindChoice,
                    kSCIRowPref: SCIPrefSpeedRate,
                    kSCIRowOptions: @[
                        @{@"value": @1.0,  @"title": SCILocalized(@"speed_normal")},
                        @{@"value": @0.5,  @"title": @"0.5×"},
                        @{@"value": @0.75, @"title": @"0.75×"},
                        @{@"value": @1.25, @"title": @"1.25×"},
                        @{@"value": @1.5,  @"title": @"1.5×"},
                        @{@"value": @1.75, @"title": @"1.75×"},
                        @{@"value": @2.0,  @"title": @"2×"},
                        @{@"value": @3.0,  @"title": @"3×"},
                    ],
                    kSCIRowTitle: SCILocalized(@"row_speed"),
                    kSCIRowNote: SCILocalized(@"row_speed_note"),
                    kSCIRowIcon: @"speedometer",
                    kSCIRowColor: [UIColor systemIndigoColor],
                },
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefAppLock,
                    kSCIRowTitle: SCILocalized(@"row_lock"),
                    kSCIRowNote: SCILocalized(@"row_lock_note"),
                    kSCIRowIcon: @"lock.fill",
                    kSCIRowColor: [UIColor systemIndigoColor],
                },
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefKeepRecalled,
                    kSCIRowTitle: SCILocalized(@"row_keep_recalled"),
                    kSCIRowNote: SCILocalized(@"row_keep_recalled_note"),
                    kSCIRowIcon: @"arrow.uturn.backward.circle.fill",
                    kSCIRowColor: [UIColor systemIndigoColor],
                },
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefVideoDate,
                    kSCIRowTitle: SCILocalized(@"row_video_date"),
                    kSCIRowNote: SCILocalized(@"row_video_date_note"),
                    kSCIRowIcon: @"calendar",
                    kSCIRowColor: [UIColor systemIndigoColor],
                },
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefVisitorLog,
                    kSCIRowTitle: SCILocalized(@"row_visitors"),
                    kSCIRowNote: SCILocalized(@"row_visitors_note"),
                    kSCIRowIcon: @"eye.fill",
                    kSCIRowColor: [UIColor systemIndigoColor],
                },
            ],
        };
    });
}

@end
