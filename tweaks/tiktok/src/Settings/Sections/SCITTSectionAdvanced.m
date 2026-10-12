//
//  SCITTSectionAdvanced.m
//  Albrhi for TikTok
//
//  Diagnostics, and the numbers behind them.
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

@interface SCITTSectionAdvanced : NSObject
@end

@implementation SCITTSectionAdvanced

+ (void)load {
    SCITTRegisterSection(70, ^NSDictionary *{
        return @{
            kSCISectionIcon: @"wrench.and.screwdriver.fill",
            kSCISectionColor: [UIColor systemGrayColor],
            kSCISectionTitle: SCILocalized(@"section_advanced"),
            kSCISectionRows: @[
                @{
                    // The welcome screen is shown once ever, which makes it easy to lose. This is
                    // the way back to it -- and the only reason it is under Advanced rather than at
                    // the top is that somebody who wants it has already seen it once.
                    kSCIRowKind: kSCIKindLink,
                    kSCIRowDestination: kSCIDestinationWelcome,
                    kSCIRowTitle: SCILocalized(@"row_welcome"),
                    kSCIRowNote: SCILocalized(@"row_welcome_note"),
                    kSCIRowIcon: @"sparkles",
                    kSCIRowColor: SCIAccent(),
                },
                @{
                    kSCIRowKind: kSCIKindLink,
                    kSCIRowDestination: kSCIDestinationReport,
                    kSCIRowTitle: SCILocalized(@"row_report"),
                    kSCIRowNote: SCILocalized(@"row_report_note"),
                    kSCIRowIcon: @"stethoscope",
                    kSCIRowColor: [UIColor systemGrayColor],
                },
            ],
        };
    });
}

@end
