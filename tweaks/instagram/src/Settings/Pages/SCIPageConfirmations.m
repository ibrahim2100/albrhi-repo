#import "../SCISettingsRegistry.h"
#import "../TweakSettings.h"

///
/// Confirmations: which taps ask first.
///
/// Thirteen switches in two unlabelled lists became three checklists, by where the tap happens.
/// "Which of these should ask" is one question asked of a dozen things, and a dozen rows was the
/// shape of the answer rather than of the question. Each switch keeps its own preference.
///
@interface SCIPageConfirmations : NSObject
@end

@implementation SCIPageConfirmations

+ (void)load {
    [SCISettingsRegistry registerFeaturePageWithTitle:^NSString *{ return SCILocalized(@"page_confirmations"); }
                                                 icon:@"checkmark"
                                                order:90
                                             sections:^NSArray *{
        SCISetting *social = [SCISetting checklistCellWithTitle:SCILocalized(@"cl_conf_social")
                                                           icon:[SCISymbol symbolWithName:@"heart"]
                                                          items:@[
            [SCISetting switchCellWithTitle:SCILocalized(@"p_cf_like_t") subtitle:SCILocalized(@"p_cf_like_s") defaultsKey:@"like_confirm"],
            [SCISetting switchCellWithTitle:SCILocalized(@"p_cf_follow_t") subtitle:SCILocalized(@"p_cf_follow_s") defaultsKey:@"follow_confirm"],
            [SCISetting switchCellWithTitle:SCILocalized(@"p_cf_followreq_t") subtitle:SCILocalized(@"p_cf_followreq_s") defaultsKey:@"follow_request_confirm"],
            [SCISetting switchCellWithTitle:SCILocalized(@"p_cf_repost_t") subtitle:SCILocalized(@"p_cf_repost_s") defaultsKey:@"repost_confirm"],
            [SCISetting switchCellWithTitle:SCILocalized(@"p_cf_comment_t") subtitle:SCILocalized(@"p_cf_comment_s") defaultsKey:@"post_comment_confirm"]
        ]];

        SCISetting *messages = [SCISetting checklistCellWithTitle:SCILocalized(@"cl_conf_messages")
                                                             icon:[SCISymbol symbolWithName:@"bubble.left"]
                                                            items:@[
            [SCISetting switchCellWithTitle:SCILocalized(@"p_cf_call_t") subtitle:SCILocalized(@"p_cf_call_s") defaultsKey:@"call_confirm"],
            [SCISetting switchCellWithTitle:SCILocalized(@"p_cf_voice_t") subtitle:SCILocalized(@"p_cf_voice_s") defaultsKey:@"voice_message_confirm"],
            [SCISetting switchCellWithTitle:SCILocalized(@"p_cf_shh_t") subtitle:SCILocalized(@"p_cf_shh_s") defaultsKey:@"shh_mode_confirm"],
            [SCISetting switchCellWithTitle:SCILocalized(@"p_cf_theme_t") subtitle:SCILocalized(@"p_cf_theme_s") defaultsKey:@"change_direct_theme_confirm"],
            [SCISetting switchCellWithTitle:SCILocalized(@"p_cf_sticker_t") subtitle:SCILocalized(@"p_cf_sticker_s") defaultsKey:@"sticker_interact_confirm"],
            [SCISetting switchCellWithTitle:SCILocalized(@"p_cf_refreshchats_t") subtitle:SCILocalized(@"p_cf_refreshchats_s") defaultsKey:@"refresh_chats_confirm"]
        ]];

        SCISetting *reels = [SCISetting checklistCellWithTitle:SCILocalized(@"cl_conf_reels")
                                                          icon:[SCISymbol symbolWithName:@"film"]
                                                         items:@[
            [SCISetting switchCellWithTitle:SCILocalized(@"p_cf_likereels_t") subtitle:SCILocalized(@"p_cf_likereels_s") defaultsKey:@"like_confirm_reels"],
            [SCISetting switchCellWithTitle:SCILocalized(@"p_reels_refresh_t") subtitle:SCILocalized(@"p_reels_refresh_s") defaultsKey:@"refresh_reel_confirm"]
        ]];

        return @[@{ @"header": SCILocalized(@"p_hdr_confirm_ask"), @"rows": @[social, messages, reels] }];
    }];
}

@end
