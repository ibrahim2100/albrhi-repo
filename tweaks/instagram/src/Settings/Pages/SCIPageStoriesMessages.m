#import "../SCISettingsRegistry.h"
#import "../TweakSettings.h"
#import "../SCISymbol.h"
#import "../SCIUnsentLogViewController.h"
#import "../../Features/StoriesAndMessages/SCIUnsentLog.h"

///
/// Messages: what the chat itself does, and what visual messages may do.
///
/// Seen receipts, typing, screenshots and searches live on Privacy; the chat-header buttons are
/// on Clean up; the save buttons for DM media and for stories are on Downloads. What is left is
/// the chat's own behaviour -- which is why the page is called Messages now and not "Stories &
/// messages", having no longer any story setting on it.
///
@interface SCIPageStoriesMessages : NSObject
@end

@implementation SCIPageStoriesMessages

+ (void)load {
    [SCISettingsRegistry registerFeaturePageWithTitle:^NSString *{ return SCILocalized(@"page_stories_messages"); }
                                                 icon:@"bubble.left.and.bubble.right.fill"
                                                order:60
                                             sections:^NSArray *{
        return @[
            @{
                @"header": SCILocalized(@"p_hdr_messages"),
                @"rows": @[
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_dm_lastactive_t") subtitle:SCILocalized(@"p_dm_lastactive_s") defaultsKey:@"dm_full_last_active"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_dm_keepunsent_t") subtitle:SCILocalized(@"p_dm_keepunsent_s") defaultsKey:@"keep_unsent_messages" requiresRestart:YES],
                    [SCISetting navigationCellWithTitle:SCILocalized(@"unsent_log_title")
                                               subtitle:SCILocalized(@"unsent_log_sub")
                                                   icon:[SCISymbol symbolWithName:@"trash.slash.fill" color:[UIColor systemRedColor] size:20.0]
                                         viewController:[[SCIUnsentLogViewController alloc] init]],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_dm_sendfile_t") subtitle:SCILocalized(@"p_dm_sendfile_s") defaultsKey:@"send_file" requiresRestart:YES]
                ]
            },
            @{
                @"header": SCILocalized(@"p_hdr_visual"),
                @"rows": @[
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_sm_replay_t") subtitle:SCILocalized(@"p_sm_replay_s") defaultsKey:@"unlimited_replay"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_sm_viewonce_t") subtitle:SCILocalized(@"p_sm_viewonce_s") defaultsKey:@"disable_view_once_limitations"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_sm_instants_t") subtitle:SCILocalized(@"p_sm_instants_s") defaultsKey:@"disable_instants_creation" requiresRestart:YES]
                ]
            }
        ];
    }];
}

@end
