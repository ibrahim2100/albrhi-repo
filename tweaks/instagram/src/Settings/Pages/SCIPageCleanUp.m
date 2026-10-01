#import "../SCISettingsRegistry.h"
#import "../TweakSettings.h"

///
/// Clean up: everything that takes something away from Instagram's own screens.
///
/// 4.5.0 gathered this from four pages. Feed held the suggested-post switches, General held the
/// suggested-users and explore ones plus the ads, Navigation held the tabs and Reels held its own
/// header -- the same kind of setting, found by remembering which page a particular thing had been
/// filed under. They are one page now, grouped by *where on screen* the thing is.
///
/// The groups of near-identical switches (which suggestions, which chat buttons, which tabs) are
/// one checklist row each: the question is "which of these", and a dozen rows of "No suggested X"
/// made the page a wall. Every switch inside is still its own preference with the same key.
///
@interface SCIPageCleanUp : NSObject
@end

@implementation SCIPageCleanUp

+ (void)load {
    [SCISettingsRegistry registerFeaturePageWithTitle:^NSString *{ return SCILocalized(@"page_cleanup"); }
                                                 icon:@"eye.slash"
                                                order:40
                                             sections:^NSArray *{
        SCISetting *suggestions = [SCISetting checklistCellWithTitle:SCILocalized(@"cl_suggestions")
                                                                icon:[SCISymbol symbolWithName:@"person.crop.rectangle.stack"]
                                                               items:@[
            [SCISetting switchCellWithTitle:SCILocalized(@"p_feed_nosuggposts_t") subtitle:SCILocalized(@"p_feed_nosuggposts_s") defaultsKey:@"no_suggested_post"],
            [SCISetting switchCellWithTitle:SCILocalized(@"p_feed_nosuggacct_t") subtitle:SCILocalized(@"p_feed_nosuggacct_s") defaultsKey:@"no_suggested_account"],
            [SCISetting switchCellWithTitle:SCILocalized(@"p_feed_nosuggreels_t") subtitle:SCILocalized(@"p_feed_nosuggreels_s") defaultsKey:@"no_suggested_reels"],
            [SCISetting switchCellWithTitle:SCILocalized(@"p_feed_nosuggthreads_t") subtitle:SCILocalized(@"p_feed_nosuggthreads_s") defaultsKey:@"no_suggested_threads"],
            [SCISetting switchCellWithTitle:SCILocalized(@"p_general_nosuggusers_t") subtitle:SCILocalized(@"p_general_nosuggusers_s") defaultsKey:@"no_suggested_users"],
            [SCISetting switchCellWithTitle:SCILocalized(@"p_general_nosuggchats_t") subtitle:SCILocalized(@"p_general_nosuggchats_s") defaultsKey:@"no_suggested_chats"]
        ]];

        SCISetting *chatButtons = [SCISetting checklistCellWithTitle:SCILocalized(@"cl_chat_buttons")
                                                                icon:[SCISymbol symbolWithName:@"bubble.left.and.bubble.right"]
                                                               items:@[
            [SCISetting switchCellWithTitle:SCILocalized(@"p_dm_voicecall_t") subtitle:SCILocalized(@"p_dm_voicecall_s") defaultsKey:@"hide_voice_call_button" requiresRestart:YES],
            [SCISetting switchCellWithTitle:SCILocalized(@"p_dm_videocall_t") subtitle:SCILocalized(@"p_dm_videocall_s") defaultsKey:@"hide_video_call_button" requiresRestart:YES],
            [SCISetting switchCellWithTitle:SCILocalized(@"p_reels_blend_t") subtitle:SCILocalized(@"p_reels_blend_s") defaultsKey:@"hide_reels_blend"]
        ]];

        SCISetting *tabs = [SCISetting checklistCellWithTitle:SCILocalized(@"cl_hide_tabs")
                                                         icon:[SCISymbol symbolWithName:@"rectangle.bottomthird.inset.filled"]
                                                        items:@[
            [SCISetting switchCellWithTitle:SCILocalized(@"p_nav_feedtab_t") subtitle:SCILocalized(@"p_nav_feedtab_s") defaultsKey:@"hide_feed_tab" requiresRestart:YES],
            [SCISetting switchCellWithTitle:SCILocalized(@"p_nav_exploretab_t") subtitle:SCILocalized(@"p_nav_exploretab_s") defaultsKey:@"hide_explore_tab" requiresRestart:YES],
            [SCISetting switchCellWithTitle:SCILocalized(@"p_nav_reelstab_t") subtitle:SCILocalized(@"p_nav_reelstab_s") defaultsKey:@"hide_reels_tab" requiresRestart:YES],
            [SCISetting switchCellWithTitle:SCILocalized(@"p_nav_createtab_t") subtitle:SCILocalized(@"p_nav_createtab_s") defaultsKey:@"hide_create_tab" requiresRestart:YES]
        ]];

        return @[
            @{
                @"header": SCILocalized(@"p_hdr_cleanup_ads"),
                @"rows": @[
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_general_ads_t") subtitle:SCILocalized(@"p_general_ads_s") defaultsKey:@"hide_ads"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_general_metaai_t") subtitle:SCILocalized(@"p_general_metaai_s") defaultsKey:@"hide_meta_ai"]
                ]
            },
            @{
                @"header": SCILocalized(@"p_hdr_cleanup_feed"),
                @"rows": @[
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_feed_storytray_t") subtitle:SCILocalized(@"p_feed_storytray_s") defaultsKey:@"hide_stories_tray"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_feed_entirefeed_t") subtitle:SCILocalized(@"p_feed_entirefeed_s") defaultsKey:@"hide_entire_feed"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_feed_autoplay_t") subtitle:SCILocalized(@"p_feed_autoplay_s") defaultsKey:@"disable_feed_autoplay"],
                    suggestions
                ]
            },
            @{
                @"header": SCILocalized(@"p_hdr_cleanup_explore"),
                @"rows": @[
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_general_exploregrid_t") subtitle:SCILocalized(@"p_general_exploregrid_s") defaultsKey:@"hide_explore_grid"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_general_trending_t") subtitle:SCILocalized(@"p_general_trending_s") defaultsKey:@"hide_trending_searches"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_reels_header_t") subtitle:SCILocalized(@"p_reels_header_s") defaultsKey:@"hide_reels_header"]
                ]
            },
            @{
                @"header": SCILocalized(@"p_hdr_cleanup_inbox"),
                @"rows": @[
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_general_hidenotes_t") subtitle:SCILocalized(@"p_general_hidenotes_s") defaultsKey:@"hide_notes_tray"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_general_friendsmap_t") subtitle:SCILocalized(@"p_general_friendsmap_s") defaultsKey:@"hide_friends_map"],
                    chatButtons
                ]
            },
            @{
                @"header": SCILocalized(@"p_hdr_cleanup_tabs"),
                @"rows": @[
                    [SCISetting menuCellWithTitle:SCILocalized(@"p_nav_order_t") subtitle:SCILocalized(@"p_nav_order_s") menu:[SCITweakSettings menus][@"nav_icon_ordering"]],
                    [SCISetting menuCellWithTitle:SCILocalized(@"p_nav_swipe_t") subtitle:SCILocalized(@"p_nav_swipe_s") menu:[SCITweakSettings menus][@"swipe_nav_tabs"]],
                    tabs
                ]
            }
        ];
    }];
}

@end
