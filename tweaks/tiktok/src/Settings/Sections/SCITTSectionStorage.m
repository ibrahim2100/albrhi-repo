//
//  SCITTSectionStorage.m
//  Albrhi for TikTok
//
//  What the app keeps on the phone, and a way to clean it.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "../SCITTStatus.h"
#import "../SCITTReport.h"
#import "../SCITTBadge.h"
#import "../../Tweak.h"
#import "../../Prefs.h"
#import "../../Localization/SCILocalize.h"
#import "../../UI/SCITTToast.h"
#import "../../Features/Storage/SCITTCache.h"
#import "../SCITTSectionRegistry.h"

@interface SCITTSectionStorage : NSObject
@end

@implementation SCITTSectionStorage

+ (void)load {
    SCITTRegisterSection(55, ^NSDictionary *{
        return @{
            kSCISectionIcon: @"internaldrive",
            kSCISectionColor: [UIColor systemGreenColor],
            kSCISectionTitle: SCILocalized(@"section_storage"),
            kSCISectionRows: @[
                @{
                    // A threshold, not a switch. Cleaning at every launch also throws away what TikTok has just preloaded for the first swipes, so the
                    // first scrolls of every session are slower and use the mobile network again; "when over" keeps what a cache is for and still
                    // stops it growing without end.
                    kSCIRowKind: kSCIKindChoice,
                    kSCIRowPref: SCIPrefCacheAuto,
                    kSCIRowOptions: @[
                        @{@"value": @0,    @"title": SCILocalized(@"cache_auto_off")},
                        @{@"value": @1,    @"title": SCILocalized(@"cache_auto_always")},
                        @{@"value": @500,  @"title": SCILocalized(@"cache_auto_500")},
                        @{@"value": @1000, @"title": SCILocalized(@"cache_auto_1000")},
                        @{@"value": @2000, @"title": SCILocalized(@"cache_auto_2000")},
                    ],
                    kSCIRowChoiceFooter: SCILocalized(@"cache_auto_footer"),
                    kSCIRowTitle: SCILocalized(@"row_cache_auto"),
                    kSCIRowNote: SCILocalized(@"row_cache_auto_note"),
                    kSCIRowIcon: @"clock.arrow.circlepath",
                    kSCIRowColor: [UIColor systemGreenColor],
                },
                @{
                    kSCIRowKind: kSCIKindAction,
                    kSCIRowAction: ^{
                        [SCITTToast noticeWithText:SCILocalized(@"cache_clearing") symbol:@"trash"];
                        SCITTCacheClearNow(^(unsigned long long freed) {
                            NSString *size = [NSByteCountFormatter stringFromByteCount:(long long)freed countStyle:NSByteCountFormatterCountStyleFile];
                            [SCITTToast noticeWithText:freed ? [NSString stringWithFormat:SCILocalized(@"cache_cleared"), size] : SCILocalized(@"cache_nothing")
                                                symbol:@"checkmark.circle.fill"];
                        });
                    },
                    kSCIRowTitle: SCILocalized(@"row_cache_clear"),
                    // The live number: what is in the two folders right now, measured when the page opens.
                    kSCIRowNote: [NSString stringWithFormat:SCILocalized(@"row_cache_clear_note"), SCITTCacheSummary()],
                    kSCIRowIcon: @"trash",
                    kSCIRowColor: [UIColor systemGreenColor],
                },
            ],
        };
    });
}

@end
