#import "../SCISettingsRegistry.h"
#import "../TweakSettings.h"

@interface SCIPageReels : NSObject
@end

@implementation SCIPageReels

+ (void)load {
    [SCISettingsRegistry registerFeaturePageWithTitle:^NSString *{ return SCILocalized(@"page_reels"); }
                                                 icon:@"film.stack"
                                                order:50
                                             sections:^NSArray *{
        return @[
            @{
                @"header": @"",
                @"rows": @[
                    [SCISetting menuCellWithTitle:SCILocalized(@"p_reels_tap_t") subtitle:SCILocalized(@"p_reels_tap_s") menu:[SCITweakSettings menus][@"reels_tap_control"]],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_reels_scrubber_t") subtitle:SCILocalized(@"p_reels_scrubber_s") defaultsKey:@"reels_show_scrubber"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_reels_unmute_t") subtitle:SCILocalized(@"p_reels_unmute_s") defaultsKey:@"disable_auto_unmuting_reels" requiresRestart:YES],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_reels_autonext_t") subtitle:SCILocalized(@"p_reels_autonext_s") defaultsKey:@"reels_auto_next"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_reels_autonextbtn_t") subtitle:SCILocalized(@"p_reels_autonextbtn_s") defaultsKey:@"reels_autoscroll_button"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_reels_date_t") subtitle:SCILocalized(@"p_reels_date_s") defaultsKey:@"reels_show_date"]
                ]
            }
        ];
    }];
}

@end
