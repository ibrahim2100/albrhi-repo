#import "../SCISettingsRegistry.h"
#import "../TweakSettings.h"
#import "../SCISymbol.h"
#import "../SCIUnsentLogViewController.h"
#import "../../Features/StoriesAndMessages/SCIUnsentLog.h"

@interface SCIPageStoriesMessages : NSObject
@end

@implementation SCIPageStoriesMessages

+ (void)load {
    [SCISettingsRegistry registerFeaturePageWithTitle:^NSString *{ return SCILocalized(@"page_stories_messages"); }
                                                 icon:@"rectangle.portrait.on.rectangle.portrait.angled"
                                                order:60
                                             sections:^NSArray *{
        // Seen receipts, typing, screenshots and searches now live on the Privacy page.
        return @[
            @{
                @"header": SCILocalized(@"p_hdr_messages"),
                @"rows": @[
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_dm_save_t") subtitle:SCILocalized(@"p_dm_save_s") defaultsKey:@"dm_media_save_button"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_dm_lastactive_t") subtitle:SCILocalized(@"p_dm_lastactive_s") defaultsKey:@"dm_full_last_active"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_dm_keepunsent_t") subtitle:SCILocalized(@"p_dm_keepunsent_s") defaultsKey:@"keep_unsent_messages" requiresRestart:YES],
                    [SCISetting navigationCellWithTitle:SCILocalized(@"unsent_log_title")
                                               subtitle:SCILocalized(@"unsent_log_sub")
                                                   icon:[SCISymbol symbolWithName:@"trash.slash.fill" color:[UIColor systemRedColor] size:20.0]
                                         viewController:[[SCIUnsentLogViewController alloc] init]]
                ]
            },
            @{
                @"header": SCILocalized(@"p_hdr_dm_calls"),
                @"rows": @[
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_dm_voicecall_t") subtitle:SCILocalized(@"p_dm_voicecall_s") defaultsKey:@"hide_voice_call_button" requiresRestart:YES],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_dm_videocall_t") subtitle:SCILocalized(@"p_dm_videocall_s") defaultsKey:@"hide_video_call_button" requiresRestart:YES],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_dm_sendfile_t") subtitle:SCILocalized(@"p_dm_sendfile_s") defaultsKey:@"send_file" requiresRestart:YES]
                ]
            },
            @{
                @"header": SCILocalized(@"p_hdr_visual"),
                @"rows": @[
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_sm_replay_t") subtitle:SCILocalized(@"p_sm_replay_s") defaultsKey:@"unlimited_replay"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_sm_viewonce_t") subtitle:SCILocalized(@"p_sm_viewonce_s") defaultsKey:@"disable_view_once_limitations"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_story_dl_title") subtitle:SCILocalized(@"p_story_dl_sub") defaultsKey:@"story_download_button"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_sm_instants_t") subtitle:SCILocalized(@"p_sm_instants_s") defaultsKey:@"disable_instants_creation" requiresRestart:YES]
                ]
            }
        ];
    }];
}

@end
