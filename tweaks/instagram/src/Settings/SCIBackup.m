#import "SCIBackup.h"
#import "../Utils.h"
#import "../Tweak.h"
#import "../Localization/SCILocalize.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface SCIBackup () <UIDocumentPickerDelegate>
@end

@implementation SCIBackup

// Retained so the document picker's delegate outlives the presenting call.
static SCIBackup *sciBackupDelegate = nil;

/// Every Albrhi preference key. Only these are exported/imported — Instagram's own
/// defaults (which may include tokens or personal data) are never touched.
+ (NSArray<NSString *> *)keys {
    return @[
        @"albrhi_accent_hex", @"albrhi_language", @"call_confirm", @"carousel_download_choice", @"change_direct_theme_confirm",
        @"copy_account_info", @"copy_description", @"custom_album", @"custom_note_themes",
        @"date_24_hour", @"date_combine", @"date_compact_relative", @"date_format_enabled",
        @"date_format_pattern", @"date_format_preset", @"date_relative_hours", @"detailed_color_picker",
        @"disable_auto_unmuting_reels", @"disable_feed_autoplay", @"disable_instants_creation",
        @"disable_safe_mode", @"disable_typing_status", @"disable_view_once_limitations",
        @"dl_clear_after_save", @"dl_max_concurrent", @"dl_use_queue", @"dm_full_last_active",
        @"dm_media_save_button", @"dw_reel_audio", @"dw_save_to_camera", @"dw_silent_video",
        @"dw_transcode_av1", @"enable_notes_customization", @"flex_app_launch", @"flex_app_start",
        @"flex_instagram", @"follow_confirm", @"follow_request_confirm", @"hide_ads",
        @"hide_create_tab", @"hide_entire_feed", @"hide_explore_grid", @"hide_explore_tab",
        @"hide_feed_tab", @"hide_friends_map", @"hide_meta_ai", @"hide_notes_tray",
        @"hide_reels_blend", @"hide_reels_header", @"hide_reels_tab", @"hide_stories_tray",
        @"hide_trending_searches", @"hide_video_call_button", @"hide_voice_call_button",
        @"dw_quality_picker", @"inline_download_button", @"keep_unsent_messages", @"like_confirm", @"like_confirm_reels", @"media_press_action",
        @"nav_icon_ordering", @"no_recent_searches", @"no_seen_receipt", @"no_suggested_account",
        @"no_suggested_chats", @"no_suggested_post", @"no_suggested_reels", @"no_suggested_threads",
        @"no_suggested_users", @"oled_theme", @"post_comment_confirm", @"reels_auto_next",
        @"reels_autoscroll_button", @"reels_show_date",
        @"reels_show_scrubber", @"reels_tap_control", @"refresh_chats_confirm", @"refresh_reel_confirm", @"remove_lastseen",
        @"remove_screenshot_alert", @"repost_confirm", @"save_profile", @"settings_shortcut",
        @"shh_mode_confirm", @"show_follow_status", @"sticker_interact_confirm", @"story_download_button",
        @"story_seen_button", @"swipe_nav_tabs", @"tweak_settings_app_launch", @"unlimited_replay",
        @"verbose_logging", @"voice_message_confirm"
    ];
}

// MARK: - Export

+ (void)exportFrom:(UIViewController *)presenter {
    if (!presenter) return;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];

    for (NSString *key in [self keys]) {
        id value = [defaults objectForKey:key];
        // Only JSON-safe primitives ever live under our keys.
        if (value && [NSJSONSerialization isValidJSONObject:@[value]]) settings[key] = value;
    }

    NSDictionary *payload = @{
        @"app": @"Albrhi",
        @"version": SCIVersionString ?: @"",
        @"exported": @([[NSDate date] timeIntervalSince1970]),
        @"settings": settings
    };

    NSError *error = nil;
    NSData *json = [NSJSONSerialization dataWithJSONObject:payload
                                                  options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                    error:&error];
    if (!json) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"p_backup_bad_file")];
        return;
    }

    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"Albrhi-settings.json"];
    if (![json writeToFile:path atomically:YES]) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"p_backup_bad_file")];
        return;
    }

    UIActivityViewController *sheet =
        [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:path]]
                                          applicationActivities:nil];
    sheet.popoverPresentationController.sourceView = presenter.view;
    sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(presenter.view.bounds),
                                                                CGRectGetMidY(presenter.view.bounds), 1, 1);

    [presenter presentViewController:sheet animated:YES completion:nil];
}

// MARK: - Import

+ (void)importFrom:(UIViewController *)presenter {
    if (!presenter) return;

    if (!sciBackupDelegate) sciBackupDelegate = [[SCIBackup alloc] init];

    UIDocumentPickerViewController *picker =
        [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeJSON, UTTypeText]];
    picker.delegate = sciBackupDelegate;
    picker.allowsMultipleSelection = NO;

    [presenter presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (!url) return;

    BOOL scoped = [url startAccessingSecurityScopedResource];
    NSData *data = [NSData dataWithContentsOfURL:url];
    if (scoped) [url stopAccessingSecurityScopedResource];

    if (!data) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"p_backup_bad_file")];
        return;
    }

    NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    NSDictionary *settings = payload[@"settings"];

    if (![payload isKindOfClass:[NSDictionary class]]
        || ![payload[@"app"] isEqual:@"Albrhi"]
        || ![settings isKindOfClass:[NSDictionary class]]) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"p_backup_bad_file")];
        return;
    }

    // Apply only recognised keys — anything else in the file is ignored.
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSSet *allowed = [NSSet setWithArray:[SCIBackup keys]];

    for (NSString *key in settings) {
        if (![allowed containsObject:key]) continue;
        [defaults setObject:settings[key] forKey:key];
    }

    [defaults synchronize];

    [SCIUtils showSuccessHUDWithDescription:SCILocalized(@"p_backup_imported")];
    [SCIUtils showRestartConfirmation];
}

@end
