//
//  SCITTSectionRegion.m
//  Albrhi for TikTok
//
//  The country TikTok is told the phone is in. Real by default; picking one is a choice with a cost, said on the row.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>
#import "../SCITTSectionRegistry.h"
#import "../../Prefs.h"
#import "../../Features/Region/SCITTRegionTable.h"
#import "../../Localization/SCILocalize.h"

@interface SCITTSectionRegion : NSObject
@end

@implementation SCITTSectionRegion

+ (void)load {
    SCITTRegisterSection(45, ^NSDictionary *{
        // The first option is "real": it removes the key, so nothing is rewritten.
        NSMutableArray *options = [NSMutableArray arrayWithObject:@{@"value": @"", @"title": SCILocalized(@"region_real")}];
        for (NSDictionary *entry in SCITTRegionTable()) {
            [options addObject:@{@"value": entry[@"code"], @"title": [NSString stringWithFormat:@"%@ — %@", SCITTRegionName(entry), entry[@"code"]]}];
        }
        return @{
            kSCISectionIcon: @"globe",
            kSCISectionColor: [UIColor systemTealColor],
            kSCISectionTitle: SCILocalized(@"section_region"),
            kSCISectionRows: @[
                @{
                    kSCIRowKind: kSCIKindChoice,
                    kSCIRowPref: SCIPrefRegionCode,
                    kSCIRowOptions: options,
                    kSCIRowChoiceFooter: SCILocalized(@"region_footer"),
                    kSCIRowTitle: SCILocalized(@"row_region"),
                    kSCIRowNote: SCILocalized(@"row_region_note"),
                    kSCIRowIcon: @"globe",
                    kSCIRowColor: [UIColor systemTealColor],
                    kSCIRowWarns: @YES,
                },
            ],
        };
    });
}

@end
