#import "../SCISettingsRegistry.h"
#import "../TweakSettings.h"
#import "../../Downloader/Queue/SCIDownloadCenterViewController.h"

///
/// Downloads, regrouped in 4.5.0 by what each setting is *about*: the buttons that start a save,
/// the questions asked first, what else can be saved, where it goes, and the queue behind it.
///
/// It had a section called "Video quality" holding the voice-message, photo-as-video and silent
/// video switches (none of which is about quality) and a section called "Profile pictures" holding
/// the follow-back check. The save buttons for stories and for DM media lived on the Stories &
/// messages page. Headings are promises about what is under them; these were not keeping theirs.
///
@interface SCIPageDownloads : NSObject
@end

@implementation SCIPageDownloads

+ (void)load {
    [SCISettingsRegistry registerFeaturePageWithTitle:^NSString *{ return SCILocalized(@"section_downloads"); }
                                                 icon:@"arrow.down.circle.fill"
                                                order:20
                                             sections:^NSArray *{
        // The extras a save can offer: one question ("which") and not four rows.
        SCISetting *extras = [SCISetting checklistCellWithTitle:SCILocalized(@"cl_dl_extras")
                                                           icon:[SCISymbol symbolWithName:@"plus.circle"]
                                                          items:@[
            [SCISetting switchCellWithTitle:SCILocalized(@"dw_reel_audio_title") subtitle:SCILocalized(@"dw_reel_audio_sub") defaultsKey:@"dw_reel_audio"],
            [SCISetting switchCellWithTitle:SCILocalized(@"dw_voice_msg_title") subtitle:SCILocalized(@"dw_voice_msg_sub") defaultsKey:@"download_audio_message" requiresRestart:YES],
            [SCISetting switchCellWithTitle:SCILocalized(@"dw_photovid_title") subtitle:SCILocalized(@"dw_photovid_sub") defaultsKey:@"photo_as_video"],
            [SCISetting switchCellWithTitle:SCILocalized(@"dw_silent_video_title") subtitle:SCILocalized(@"dw_silent_video_sub") defaultsKey:@"dw_silent_video"]
        ]];

        // The queue's own three settings, one level down: nobody changes them twice.
        SCISetting *queue = [SCISetting navigationCellWithTitle:SCILocalized(@"dl_queue_title")
                                                       subtitle:SCILocalized(@"dl_queue_sub")
                                                           icon:[SCISymbol symbolWithName:@"list.bullet.rectangle"]
                                                    navSections:@[@{
            @"header": @"",
            @"rows": @[
                [SCISetting switchCellWithTitle:SCILocalized(@"dl_use_queue_title") subtitle:SCILocalized(@"dl_use_queue_sub") defaultsKey:@"dl_use_queue"],
                [SCISetting stepperCellWithTitle:SCILocalized(@"dl_max_concurrent_title") subtitle:@"%@ %@" defaultsKey:@"dl_max_concurrent" min:1 max:6 step:1 label:SCILocalized(@"p_lbl_downloads") singularLabel:SCILocalized(@"p_lbl_download")],
                [SCISetting switchCellWithTitle:SCILocalized(@"dl_clear_title") subtitle:SCILocalized(@"dl_clear_sub") defaultsKey:@"dl_clear_after_save"]
            ]
        }]];

        return @[
            @{
                @"header": @"",
                @"rows": @[
                    [SCISetting navigationCellWithTitle:SCILocalized(@"dl_center_title")
                                               subtitle:SCILocalized(@"dl_center_sub")
                                                   icon:[SCISymbol symbolWithName:@"tray.full.fill" color:[SCIUtils SCIColor_Primary] size:20.0]
                                         viewController:[[SCIDownloadCenterViewController alloc] init]]
                ]
            },
            @{
                @"header": SCILocalized(@"p_hdr_dl_buttons"),
                @"rows": @[
                    [SCISetting switchCellWithTitle:SCILocalized(@"inline_download_title") subtitle:SCILocalized(@"inline_download_sub") defaultsKey:@"inline_download_button"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_story_dl_title") subtitle:SCILocalized(@"p_story_dl_sub") defaultsKey:@"story_download_button"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_dm_save_t") subtitle:SCILocalized(@"p_dm_save_s") defaultsKey:@"dm_media_save_button"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"save_profile_title") subtitle:SCILocalized(@"save_profile_sub") defaultsKey:@"save_profile"]
                ]
            },
            @{
                @"header": SCILocalized(@"p_hdr_dl_ask"),
                @"rows": @[
                    [SCISetting switchCellWithTitle:SCILocalized(@"dw_quality_picker_t") subtitle:SCILocalized(@"dw_quality_picker_s") defaultsKey:@"dw_quality_picker"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_carousel_choice_t") subtitle:SCILocalized(@"p_carousel_choice_s") defaultsKey:@"carousel_download_choice"]
                ]
            },
            @{
                @"header": SCILocalized(@"p_hdr_dl_formats"),
                @"rows": @[
                    extras,
                    [SCISetting switchCellWithTitle:SCILocalized(@"dw_transcode_av1_title") subtitle:SCILocalized(@"dw_transcode_av1_sub") defaultsKey:@"dw_transcode_av1"]
                ]
            },
            @{
                @"header": SCILocalized(@"p_hdr_dl_saving"),
                @"rows": @[
                    [SCISetting switchCellWithTitle:SCILocalized(@"dw_save_to_camera_title") subtitle:SCILocalized(@"dw_save_to_camera_sub") defaultsKey:@"dw_save_to_camera"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"custom_album_title") subtitle:SCILocalized(@"custom_album_sub") defaultsKey:@"custom_album"],
                    queue
                ]
            }
        ];
    }];
}

@end
