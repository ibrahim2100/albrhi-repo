#import "../SCISettingsRegistry.h"
#import "../TweakSettings.h"

///
/// Privacy: everything that changes what Instagram tells other people about you,
/// gathered in one place instead of scattered across Stories, Messages and General.
///

@interface SCIPagePrivacy : NSObject
@end

@implementation SCIPagePrivacy

+ (void)load {
    [SCISettingsRegistry registerFeaturePageWithTitle:^NSString *{ return SCILocalized(@"page_privacy"); }
                                                 icon:@"hand.raised.fill"
                                                order:30
                                             sections:^NSArray *{
        return @[
            @{
                @"header": SCILocalized(@"p_hdr_priv_visibility"),
                @"rows": @[
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_sm_seen_t") subtitle:SCILocalized(@"p_sm_seen_s") defaultsKey:@"no_seen_receipt"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"story_seen_button_title") subtitle:SCILocalized(@"story_seen_button_sub") defaultsKey:@"story_seen_button"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_sm_markseen_t") subtitle:SCILocalized(@"p_sm_markseen_s") defaultsKey:@"remove_lastseen"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_sm_typing_t") subtitle:SCILocalized(@"p_sm_typing_s") defaultsKey:@"disable_typing_status"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_sm_online_t") subtitle:SCILocalized(@"p_sm_online_s") defaultsKey:@"hide_online_status"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_sm_screenshot_t") subtitle:SCILocalized(@"p_sm_screenshot_s") defaultsKey:@"remove_screenshot_alert"]
                ]
            },
            @{
                @"header": SCILocalized(@"p_hdr_priv_searches"),
                @"rows": @[
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_general_norecent_t") subtitle:SCILocalized(@"p_general_norecent_s") defaultsKey:@"no_recent_searches"]
                ]
            }
        ];
    }];
}

@end
