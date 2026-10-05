#import "SCITWFeatures.h"
#import "SCITWSwitches.h"
#import "Prefs.h"
#import "SCILog.h"

@implementation SCITWFeature
@end


static SCITWFeature *Feature(NSString *identifier,
                             NSString *titleKey,
                             NSString *noteKey,
                             BOOL cautious,
                             NSString *iconName,
                             UIColor *iconColor,
                             NSDictionary<NSString *, NSNumber *> *keys) {
    SCITWFeature *feature = [[SCITWFeature alloc] init];
    feature.identifier = identifier;
    feature.titleKey = titleKey;
    feature.noteKey = noteKey;
    feature.cautious = cautious;
    feature.iconName = iconName;
    feature.iconColor = iconColor;
    feature.keys = keys;
    return feature;
}

@implementation SCITWFeatures

///
/// The table.
///
/// Every key was seen being asked on X 12.14; the count beside each group in the comments
/// is what the device reported, and it is there because it is the one number that says
/// whether a switch is load-bearing. A key asked thirty thousand times during a scroll is
/// doing something on every row; one asked twice at launch is a setting.
///
+ (NSArray<SCITWFeature *> *)all {
    static NSArray<SCITWFeature *> *all = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        all = @[
            // X's ad layer names itself: ssp_ads_*, plus the timeline's own rules about
            // where an ad may be placed. The three placement keys are turned *on* rather
            // than off -- they are X's own protections against an ad in the first slot and
            // beside a post that moved, and X ships them off.
            Feature(@"ads", @"f_ads", @"f_ads_note", NO,
                    @"megaphone.fill", [UIColor systemRedColor], @{
                @"ssp_ads_home_enabled": @NO,
                @"ssp_ads_home_client_only_integration": @NO,
                @"ssp_ads_preroll_enabled": @NO,
                @"ssp_ads_spotlight": @NO,
                @"ssp_ads_spotlight_client_only_integration": @NO,
                @"ssp_ads_profile_client_only_integration_enabled": @NO,
                @"ssp_ads_tweet_details_client_only_integration": @NO,
                @"ssp_ads_immersive_client_only_integration": @NO,
                @"ssp_ads_immersive_default_video_player_enabled": @NO,
                @"ssp_ads_google_native_ad_s2s_migration_enabled": @NO,
                @"ssp_ads_google_native_ad_actions_bar_enabled": @NO,
                @"ssp_ads_google_native_ad_reload_data_enabled": @NO,
                @"ssp_ads_google_native_ad_report_enabled": @NO,
                @"video_configurations_dynamic_ad_enabled": @NO,
                @"unified_cards_clip_long_media_promoted_content_enabled": @NO,
                @"ios_video_analytics_promoted_audible_view_enabled": @NO,
                @"ios_ad_formats_optional_headline_enabled": @NO,
                @"ios_ad_formats_media_component_render_overlay_dpa_enabled": @NO,
                @"ios_ad_formats_vanity_url_string_fallback_enabled": @NO,
                @"ads_spacing_client_fallback_top_down_enabled": @NO,
                @"home_timeline_first_position_ad_prevention_enabled": @YES,
                @"home_timeline_deduping_remove_ads_with_changed_adjacent_posts": @YES,
                @"home_timeline_client_deduping_skip_adjacent_to_ads": @YES,
                // The placements NeoFreeBird turns off on X 12.31 that this table did not name;
                // every one is a string in 12.20's T1Twitter.
                @"ssp_ads_profile": @NO,
                @"ssp_ads_immersive": @NO,
                @"ssp_ads_tweet_details": @NO,
                @"ssp_ads_spotlight_client_only_integration_preload": @NO,
            }),

            // Seven keys, each asked 7,734 times -- the same count, which is what a set of
            // labels on one button looks like from here.
            Feature(@"promote", @"f_promote", @"f_promote_note", NO,
                    @"arrowshape.turn.up.right.fill", [UIColor systemPinkColor], @{
                @"ios_tweet_promote_button_enabled": @NO,
                @"ios_tweet_promote_button_analytics_sheet_enabled": @NO,
                @"ios_tweet_promote_button_booster_status_label_enabled": @NO,
                @"ios_tweet_promote_button_label_upsell_tray_enabled": @NO,
                @"ios_tweet_promote_button_optimistic_label_enabled": @NO,
                @"ios_tweet_promote_button_self_serve_boost_label_enabled": @NO,
                @"ios_tweet_promote_button_social_context_label_enabled": @NO,
                // One switch per *placement* -- the root switch above does not govern them, which
                // is why the button survived in the places NeoFreeBird lists (timeline, composer,
                // overflow menu, both focal toolbars, analytics, the sent-post toast).
                @"ios_tweet_promote_button_timeline_enabled": @NO,
                @"ios_tweet_promote_button_in_tweet_composer_enabled": @NO,
                @"ios_tweet_promote_button_in_overflow_menu_enabled": @NO,
                @"ios_tweet_promote_button_in_focal_top_toolbar_enabled": @NO,
                @"ios_tweet_promote_button_in_focal_bottom_toolbar_enabled": @NO,
                @"ios_tweet_promote_button_in_focal_top_analytics_enabled": @NO,
                @"ios_tweet_promote_button_in_post_analytics_enabled": @NO,
                @"ios_tweet_promote_button_boost_again_in_top_toolbar_enabled": @NO,
                @"ios_tweet_promote_button_sent_tweet_toast_enabled": @NO,
                @"ios_tweet_promote_button_third_party_boost_enabled": @NO,
                @"thirdparty_boost_author_view_button_enabled": @NO,
            }),

            Feature(@"grok", @"f_grok", @"f_grok_note", NO,
                    @"sparkles", [UIColor systemPurpleColor], @{
                @"grok_ask_grok_button_under_post_preview_enabled": @NO,
                @"grok_ios_author_view_analyze_button_via_backend_enabled": @NO,
                @"grok_ios_analyze_context_menu_enabled": @NO,
                @"grok_ios_analyze_long_press_context_menu_enabled": @NO,
                @"grok_explain_text_selection_ask_grok_enabled": @NO,
                @"grok_ios_tweet_detail_followups_enabled": @NO,
                @"grok_ios_unread_indicator_enabled": @NO,
                @"grok_ios_v2_dash_new_badge_enabled": @NO,
                @"grok_tutorial_system_ios_enabled": @NO,
                @"grok_direct_grokapp_flow_notification_enabled": @NO,
                @"ios_tab_bar_default_show_grok": @NO,
                @"dash_items_download_grok_enabled": @NO,
                @"unified_cards_grok_card_transform_enabled": @NO,
                @"ios_button_layout_fix_use_grok_annotations": @NO,
                // Creation: the composer button, the Imagine menus and calls to action, Edit
                // with Grok on photo posts and the player's create-your-own button.
                @"grok_ask_grok_button_under_post_focal_enabled": @NO,
                @"grok_edit_with_grok_button_under_post_focal_enabled": @NO,
                @"grok_edit_with_grok_button_under_post_preview_enabled": @NO,
                @"ios_composer_grok_button_enabled": @NO,
                @"grok_imagine_composer_enabled": @NO,
                @"grok_composer_imagine_is_enabled": @NO,
                @"grok_composer_attachment_imagine_menu_is_enabled": @NO,
                @"grok_timeline_preview_imagine_menu_is_enabled": @NO,
                @"grok_timeline_video_imagine_menu_is_enabled": @NO,
                @"grok_timeline_slideshow_imagine_menu_is_enabled": @NO,
                @"grok_ios_edit_photo_post_button_enabled": @NO,
                @"grok_ios_imagine_cta_focal_enabled": @NO,
                @"grok_ios_imagine_cta_reply_enabled": @NO,
                @"grok_ios_imagine_cta_timeline_enabled": @NO,
                @"grok_ios_imagine_cta_profile_enabled": @NO,
                @"grok_immersive_create_own_button_enabled": @NO,
                // The profile header's summary button.
                @"grok_ios_profile_summary_enabled": @NO,
                // Added in X 12.28 and later, so not in 12.20 (asked of nothing there): taken
                // from NeoFreeBird, which is written against 12.31. Inert where they do not
                // exist, and the switch list says which keys a build actually asks about.
                @"grok_ios_grok_bot_upsells_enabled": @NO,
                @"grok_ios_grok_bot_sidebar_enabled": @NO,
                @"grok_ios_grok_bot_home_header_enabled": @NO,
                @"grok_ios_grok_bot_home_hero_enabled": @NO,
                @"grok_ios_grok_bot_preset_enabled": @NO,
                @"grok_ios_grok_bot_tab_icon_enabled": @NO,
            }),

            // The single most asked key on the whole device: 32,844 times. Kept out of the
            // Grok feature on purpose -- turning off automatic translation is not the same
            // decision as removing Grok's buttons, and someone reading a timeline in three
            // languages wants opposite things from the two.
            Feature(@"autotranslate", @"f_autotranslate", @"f_autotranslate_note", NO,
                    @"character.book.closed.fill", [UIColor systemBlueColor], @{
                @"grok_translations_post_auto_translation_is_enabled": @NO,
                @"grok_translations_bio_auto_translation_is_enabled": @NO,
                @"grok_translations_community_note_auto_translation_is_enabled": @NO,
                @"grok_translations_post_inline_translation_is_enabled": @NO,
                @"ios_tweet_detail_always_load_is_translatable": @NO,
            }),

            Feature(@"upsell", @"f_upsell", @"f_upsell_note", NO,
                    @"creditcard.fill", [UIColor systemGreenColor], @{
                @"subscriptions_offers_promotional_enabled": @NO,
                @"subscriptions_inapp_grok_upsell_enabled": @NO,
                @"subscriptions_inapp_grok": @NO,
                @"premium_business_ios_nav_promo_enabled": @NO,
                @"ios_premium_paywall_preloaded_webview_startup_preload_enabled": @NO,
                @"ios_subscription_journey_foreground_event_enabled": @NO,
                @"subscriptions_gifting_polling_after_purchase_enabled": @NO,
                @"creator_subscriptions_polling_after_purchase_enabled": @NO,
                // Not every upsell gates on being a non-subscriber, so each surface is named.
                @"ios_profile_analytics_upsell_enabled": @NO,
                @"ios_profile_analytics_upsell_possible_enabled": @NO,
                @"ios_profile_upgrade_upsell_enabled": @NO,
                @"ios_profile_upgrade_upsell_swapper_enabled": @NO,
                @"ios_profile_visitor_upsell_enabled": @NO,
                @"subscriptions_upsells_get_verified_profile": @NO,
                @"subscriptions_upsells_reply_boost_enabled": @NO,
                @"subscriptions_upsells_reply_boost_popup_enabled": @NO,
                @"subscriptions_upsells_post_analytics_enabled": @NO,
                @"longform_notetweets_composer_upsell_enabled": @NO,
                @"longform_notetweets_composer_auto_upsell_enabled": @NO,
                @"subscriptions_cta_on_replies_enabled": @NO,
                @"super_follow_upsell_sticky_button_enabled": @NO,
                @"subscriptions_new_paywall_enabled": @NO,
                @"subscriptions_gifting_premium_enabled": @NO,
                @"subscriptions_gifting_premium_intro_copy_enabled": @NO,
                @"ios_notifications_blue_verified_introductory_offer_visible": @NO,
            }),

            //
            // From NeoFreeBird (orionblur, GPLv3), written against X 12.31 -- each key below was
            // checked as a real string in X 12.20's binaries before it was written here, except
            // the ones marked as newer.
            //

            // The photo grid X replaced with a swipeable carousel. The avatar-avoidance key is
            // also listed under "clean up the interface"; both want the same answer.
            Feature(@"carousel", @"f_carousel", @"f_carousel_note", NO,
                    @"rectangle.grid.1x2.fill", [UIColor systemTealColor], @{
                @"ios_ui_multi_media_carousel_enabled": @NO,
                @"ios_ui_quote_tweet_multi_media_carousel_enabled": @NO,
                @"ios_ui_multi_media_carousel_avatar_avoidance_enabled": @NO,
            }),

            // `hasNonDefaultValueForKey:` is hooked beside the typed getters for exactly this
            // pair: the captions setup only consults the value when the switch reports a
            // non-default one.
            Feature(@"captions", @"f_captions", @"f_captions_note", NO,
                    @"captions.bubble.fill", [UIColor systemGrayColor], @{
                @"ios_tav_default_closed_captions_enabled": @NO,
                @"ios_audio_transcription_subtitles_vod_enabled": @NO,
            }),

            // A number, not a yes or no: a negative threshold stops the vertical video player
            // moving to the next clip by itself, and removes the row from its own settings sheet.
            Feature(@"noadvance", @"f_noadvance", @"f_noadvance_note", NO,
                    @"stop.circle.fill", [UIColor systemRedColor], @{
                @"immersive_video_auto_advance_duration_threshold": @(-1),
            }),

            // Ten years, in seconds: the timeline is not refreshed behind your back because the
            // app was in the background. The second key keeps the tab you were on.
            Feature(@"norefresh", @"f_norefresh", @"f_norefresh_note", NO,
                    @"arrow.counterclockwise.circle.fill", [UIColor systemBlueColor], @{
                @"home_timeline_foreground_refresh_min_background_seconds": @(315360000.0),
                @"home_timeline_non_sticky_tab_on_new_session_enabled": @NO,
            }),

            Feature(@"profiletabs", @"f_profiletabs", @"f_profiletabs_note", NO,
                    @"person.crop.rectangle.stack.fill", [UIColor systemIndigoColor], @{
                @"articles_timeline_profile_tab_enabled": @NO,
                @"highlights_tweets_tab_ui_enabled": @NO,
            }),

            Feature(@"replycontext", @"f_replycontext", @"f_replycontext_note", NO,
                    @"text.bubble.fill", [UIColor systemBlueColor], @{
                @"ios_tweet_detail_conversation_context_removal_enabled": @NO,
            }),

            // Not in 12.20 -- a newer key, from NeoFreeBird.
            Feature(@"downvote", @"f_downvote", @"f_downvote_note", NO,
                    @"hand.thumbsdown.fill", [UIColor systemOrangeColor], @{
                @"conversational_replies_ios_downvote_enabled": @NO,
            }),

            // Likes and follows make the timeline fetch fresh suggestions and splice them in;
            // this is the switch X ships for turning that off.
            Feature(@"blending", @"f_blending", @"f_blending_note", NO,
                    @"person.crop.circle.badge.xmark", [UIColor systemOrangeColor], @{
                @"wtf_device_follow_nudge_turn_off_reactive_blending_enabled": @YES,
            }),

            // The `&t=` that rides along on a copied link names the session it came from.
            Feature(@"sharetoken", @"f_sharetoken", @"f_sharetoken_note", NO,
                    @"link.badge.plus", [UIColor systemGreenColor], @{
                @"rehire_share_update_url_enabled": @NO,
            }),

            // Scribe is X's own name for its event pipeline, and the keys say what each
            // one sends -- storage, cellular type, device integrity.
            //
            // **app_attest_* is deliberately absent.** Those are how X proves to its own
            // servers that this is a real, unmodified device, and switching them off is
            // not a privacy setting: it is telling the server something it will not
            // believe, on an account that can be locked for it. Not offered, rather than
            // offered with a warning -- there is no version of that trade worth an account.
            Feature(@"tracking", @"f_tracking", @"f_tracking_note", YES,
                    @"eye.slash.fill", [UIColor systemRedColor], @{
                @"ios_scribe_flush_linger_on_background_enabled": @NO,
                @"ios_scribe_linger_monotonic_clock_enabled": @NO,
                @"ios_scribe_device_integrity_enabled": @NO,
                @"ios_scribe_device_status_concrete_cellular_type_enabled": @NO,
                @"ios_scribe_device_status_storage_info_enabled": @NO,
                @"ios_scribe_loss_reporting_enabled": @NO,
                @"ios_scribe_enter_background_session_length_reset_enabled": @NO,
                @"ios_scribe_disable_background_flush": @YES,
                @"scribe_livepipeline_events_enabled": @NO,
                @"ios_detailed_logging_assimilation_scribing_enabled": @NO,
                @"home_timeline_scribing_scroll_enabled": @NO,
                @"home_timeline_flyby_impression_enabled": @NO,
                @"video_attribution_author_id_scribe_enabled": @NO,
                @"ios_client_performance_view_controller_scribe_fallback_enabled": @NO,
                @"ios_video_analytics_short_form_complete_enabled": @NO,
                @"ios_video_analytics_validate_swift_cme_enabled": @NO,
                @"home_timeline_performance_zipkin_pct_metadata_enabled": @NO,
                @"ios_graphql_conversion_error_logging_enabled": @NO,
                @"ces_client_network_events_use_p2_endpoint": @NO,
                @"perftown_enabled": @NO,
                @"traffic_should_persist_trafficmap": @NO,
                @"ios_castle_sdk_enabled": @NO,
                @"ios_braze_client_enabled": @NO,
                @"crashlytics_logging_enabled": @NO,
                @"crashlytics_logging_logger_enabled": @NO,
            }),

            Feature(@"clutter", @"f_clutter", @"f_clutter_note", NO,
                    @"hand.raised.slash.fill", [UIColor systemTealColor], @{
                @"ios_ui_inline_actions_tip_enabled": @NO,
                @"level_up_reactive_prompts_like_reaction_enabled": @NO,
                @"level_up_reactive_prompts_user_follow_reaction_enabled": @NO,
                @"consideration_lonely_birds_first_like_ios_enabled": @NO,
                @"onboarding_new_local_push_reminder_to_finish_enabled": @NO,
                @"nudges_ios_articles_link_tracking_enabled": @NO,
                @"nudges_ios_articles_news_domain_deferred_set_cache_enabled": @NO,
                @"hashflags_animation_like_button_enabled": @NO,
                @"hashflags_settings_enabled": @NO,
                @"ios_timeline_avatar_discovery_spaces_experiment": @NO,
                @"ios_timeline_avatar_discovery_fleets_experiment": @NO,
                @"branded_features_custom_screenshots_on_htl_enabled": @NO,
                @"branded_features_is_branded_likes_on_tweet_content_enabled": @NO,
                @"branded_like_preview_enabled": @NO,
                @"ios_chrome_activity_progress_toast_enabled": @NO,
                @"ios_ui_multi_media_carousel_avatar_avoidance_enabled": @NO,
            }),

            Feature(@"viewcounts", @"f_viewcounts", @"f_viewcounts_note", NO,
                    @"eye.fill", [UIColor systemIndigoColor], @{
                @"view_counts_public_visibility_enabled": @NO,
                @"view_counts_everywhere_api_enabled": @NO,
                @"ios_rank_badge_enabled": @NO,
            }),

            //
            // **Hiding a section is not switching a capability off, and this feature was
            // doing both.**
            //
            // `voice_rooms_consumption_enabled: NO` is X being told this account may not
            // *listen* to a Space at all — so opening a link somebody sent came back
            // "unavailable", which is a broken app rather than a tidy timeline, and was
            // reported in exactly those words. `audio_articles_enabled` is the same shape
            // one surface over: an article that will not play.
            //
            // Both are gone. What hides the Spaces strip is `-_t1_initializeFleets` being
            // withheld (`Features/Spaces/`) and what hides the tab is its own `audiospace`
            // entry (`Features/Tabs/`) — two surfaces, neither of which touches whether the
            // thing works when you ask for it deliberately.
            //
            // **Measured against BHTwitter 4.5 rather than reasoned about**: it hides the
            // same strip through the same selector, names the same `audiospace` tab, and
            // carries **none** of these four keys anywhere in its binary. A tweak whose hide
            // has worked for years never touches the capability, which is the whole finding.
            //
            // The two kept are gates on *surfaces*: the button that starts a Space, and the
            // avatar ring that advertises one in the timeline. The row says so.
            //
            Feature(@"spaces", @"f_spaces", @"f_spaces_note", NO,
                    @"waveform", [UIColor systemPurpleColor], @{
                @"voice_rooms_main_fab_creation_enabled": @NO,
                @"ios_timeline_avatar_discovery_spaces_experiment": @NO,
            }),

            // A warning being removed, so it is marked cautious and defaults off like every
            // other feature here. YouTube's paid-promotion switch defaults off for the same
            // reason: taking a disclosure away for everybody is not a tweak's call.
            Feature(@"sensitive", @"f_sensitive", @"f_sensitive_note", YES,
                    @"exclamationmark.triangle.fill", [UIColor systemOrangeColor], @{
                @"sensitive_tweet_warnings_enabled": @NO,
                @"sensitive_tweet_warnings_fixed_height_enabled": @NO,
                @"media_poll_sensitive_media_banner_enabled": @NO,
            }),

            // Links, out of the app.
            //
            // **The key was found in a device report rather than reasoned about**, which is
            // the whole reason this recorder exists. Two releases hooked browser classes:
            // `SFSafariViewController`, which X names once in all its binaries, and then
            // `T1BaseWebViewController`, whose `-_t1_loadInitialURL` the report then showed
            // was never called at all -- `0 left to X`, so nothing had gone past it. The
            // same report showed `ios_in_app_article_webview_enabled` asked **72 times** and
            // answered on. That is the decision, and X makes it before any browser class
            // exists to hook.
            Feature(@"safari", @"f_safari", @"f_safari_note", NO,
                    @"safari", [UIColor systemBlueColor], @{
                @"ios_in_app_article_webview_enabled": @NO,
            }),

            Feature(@"gif", @"f_gif", @"f_gif_note", NO,
                    @"photo.fill.on.rectangle.fill", [UIColor systemPinkColor], @{
                @"photo_ignore_autoplay_settings_for_gif": @NO,
            }),

            Feature(@"zoom", @"f_zoom", @"f_zoom_note", NO,
                    @"plus.magnifyingglass", [UIColor systemBlueColor], @{
                @"ios_inline_zoom_enabled": @YES,
            }),

            Feature(@"gestures", @"f_gestures", @"f_gestures_note", NO,
                    @"hand.draw.fill", [UIColor systemBrownColor], @{
                @"ios_ui_timeline_gestures_by_default_enabled": @YES,
                @"ios_tab_bar_gesture_rework_enabled": @YES,
                @"custom_post_swipe_gestures_enabled": @YES,
                @"ios_ui_timeline_name_profile_navigation_enabled": @YES,
            }),

            Feature(@"tabs", @"f_tabs", @"f_tabs_note", NO,
                    @"square.grid.2x2.fill", [UIColor systemIndigoColor], @{
                @"ios_tab_bar_default_show_communities": @YES,
                @"ios_tab_bar_default_show_profile": @YES,
                @"hometimeline_pinned_tabs_generic_timelines_enabled": @YES,
            }),

            Feature(@"privacy", @"f_privacy", @"f_privacy_note", NO,
                    @"lock.fill", [UIColor systemGreenColor], @{
                @"hidden_profile_likes_enabled": @YES,
                @"hidden_profile_subscriptions_enabled": @YES,
                @"global_mention_settings_enabled": @YES,
                @"dont_mention_me_view_api_enabled": @YES,
            }),

            Feature(@"launch", @"f_launch", @"f_launch_note", NO,
                    @"bolt.fill", [UIColor systemYellowColor], @{
                @"app_launch_animated_launch_screen_enabled": @NO,
                @"ios_home_timeline_container_defer_loading_inactive_timelines_enabled": @YES,
                @"ios_client_performance_defer_notifications_load_until_view_will_appear_enabled": @YES,
                @"ios_client_performance_defer_fleetline_loading_untill_home_timeline_is_loaded_enabled": @YES,
            }),

            // Cautious, and last. These are X's own optimisations, shipped switched off --
            // which usually means they are being rolled out, and sometimes means they were
            // rolled back. Turning them on is the one group here where "it got worse" is a
            // plausible outcome, so it says so and is easy to undo.
            Feature(@"perf", @"f_perf", @"f_perf_note", YES,
                    @"speedometer", [UIColor systemOrangeColor], @{
                @"ios_client_performance_urt_timeline_update_action_async_start_enabled": @YES,
                @"ios_client_performance_urt_timeline_update_stop_main_queue_dispatch_enabled": @YES,
                @"ios_client_performance_status_author_view_info_text_layout_eligibility_validation_enabled": @YES,
                @"ios_client_performance_status_view_layout_state_generator_cached_view_adapter_set_enabled": @YES,
                @"ios_client_performance_add_status_cell_autoplayable_once_per_visibility_call_enabled": @YES,
                @"ios_client_performance_dynamic_color_lazy_init_enabled": @YES,
                @"ios_memory_relief_clear_cached_display_text_enabled": @YES,
                @"ios_unified_cache_computed_count_limits_enabled": @YES,
                @"ios_performance_is_monitoring_memory_pressure_changes_enabled": @YES,
                @"ios_super_awesome_video_cache_enabled": @YES,
                @"urt_empty_cursor_chunk_clearing_enabled": @YES,
            }),
        ];
    });
    return all;
}

+ (NSString *)preferenceFor:(SCITWFeature *)feature {
    return [SCIPrefFeaturePrefix stringByAppendingString:feature.identifier];
}

+ (BOOL)isOn:(SCITWFeature *)feature {
    return [[NSUserDefaults standardUserDefaults] boolForKey:[self preferenceFor:feature]];
}

+ (BOOL)isOnIdentifier:(NSString *)identifier {
    for (SCITWFeature *feature in [self all]) {
        if ([feature.identifier isEqualToString:identifier]) return [self isOn:feature];
    }
    return NO;
}

+ (void)setOn:(BOOL)on feature:(SCITWFeature *)feature {
    [[NSUserDefaults standardUserDefaults] setBool:on forKey:[self preferenceFor:feature]];
    [self apply];
}

+ (void)apply {
    NSMutableDictionary<NSString *, NSNumber *> *map = [NSMutableDictionary dictionary];

    for (SCITWFeature *feature in [self all]) {
        if (![self isOn:feature]) continue;

        // Later features win where two name the same key. In this table the overlaps all
        // want the same value -- "hide Spaces" and "clean up the interface" both turn the
        // avatar ring off -- so the order is not load-bearing today. It is written down
        // because the day it stops being true, nothing else would say which one applied.
        [map addEntriesFromDictionary:feature.keys];
    }

    [SCITWSwitches setFeatureOverrides:map];
    SCILogV(@"features apply: %lu keys", (unsigned long)map.count);
}

+ (SCITWFeature *)featureOwningKey:(NSString *)key {
    for (SCITWFeature *feature in [self all]) {
        if (![self isOn:feature]) continue;
        if (feature.keys[key]) return feature;
    }
    return nil;
}

@end
