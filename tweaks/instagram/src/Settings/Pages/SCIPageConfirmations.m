#import "../SCISettingsRegistry.h"
#import "../TweakSettings.h"

@interface SCIPageConfirmations : NSObject
@end

@implementation SCIPageConfirmations

+ (void)load {
    [SCISettingsRegistry registerFeaturePageWithTitle:^NSString *{ return SCILocalized(@"page_confirmations"); }
                                                 icon:@"checkmark"
                                                order:90
                                             sections:^NSArray *{
        return @[
            @{
                @"header": @"",
                @"rows": @[
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_cf_like_t") subtitle:SCILocalized(@"p_cf_like_s") defaultsKey:@"like_confirm"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_cf_likereels_t") subtitle:SCILocalized(@"p_cf_likereels_s") defaultsKey:@"like_confirm_reels"]
                ]
            },
            @{
                @"header": @"",
                @"rows": @[
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_cf_follow_t") subtitle:SCILocalized(@"p_cf_follow_s") defaultsKey:@"follow_confirm"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_cf_repost_t") subtitle:SCILocalized(@"p_cf_repost_s") defaultsKey:@"repost_confirm"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_cf_call_t") subtitle:SCILocalized(@"p_cf_call_s") defaultsKey:@"call_confirm"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_cf_voice_t") subtitle:SCILocalized(@"p_cf_voice_s") defaultsKey:@"voice_message_confirm"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_cf_followreq_t") subtitle:SCILocalized(@"p_cf_followreq_s") defaultsKey:@"follow_request_confirm"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_cf_shh_t") subtitle:SCILocalized(@"p_cf_shh_s") defaultsKey:@"shh_mode_confirm"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_cf_comment_t") subtitle:SCILocalized(@"p_cf_comment_s") defaultsKey:@"post_comment_confirm"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_cf_theme_t") subtitle:SCILocalized(@"p_cf_theme_s") defaultsKey:@"change_direct_theme_confirm"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_cf_sticker_t") subtitle:SCILocalized(@"p_cf_sticker_s") defaultsKey:@"sticker_interact_confirm"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_cf_refreshchats_t") subtitle:SCILocalized(@"p_cf_refreshchats_s") defaultsKey:@"refresh_chats_confirm"]
                ]
            }
        ];
    }];
}

@end
