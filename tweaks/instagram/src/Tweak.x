#import <substrate.h>
#import "Compat/SCITitleMatch.h"
#import "shared/src/SCIKVC.h"
#import "InstagramHeaders.h"
#import "Tweak.h"
#import "Utils.h"
#import "Onboarding/SCIWhatsNewViewController.h"
#import "Features/General/SCIUpdateChecker.h"
#import "Downloader/Queue/SCIDownloadQueue.h"
#import "Compat/SCIResolve.h"

///////////////////////////////////////////////////////////

// Screenshot handlers
// %orig can't be passed as a macro/function argument in this Logos version
// (it expands to a call with commas and an unbalanced paren), so these guards
// don't take it — the caller stores %orig itself after the guard.
#define SCREENSHOT_GUARD_VOID() do { if ([SCIUtils getBoolPref:@"remove_screenshot_alert"]) return; } while (0)
#define SCREENSHOT_GUARD_NIL() do { if ([SCIUtils getBoolPref:@"remove_screenshot_alert"]) return nil; } while (0)

///////////////////////////////////////////////////////////

// * Tweak version *
NSString *SCIVersionString = @"v4.1.18";  // Albrhi

// Variables that work across features

// Tweak first-time setup
%hook IGInstagramAppDelegate
- (_Bool)application:(UIApplication *)application willFinishLaunchingWithOptions:(id)arg2 {
    // Default SCInsta config
    NSDictionary *sciDefaults = @{
        @"hide_ads": @(YES),
        @"copy_description": @(YES),
        @"detailed_color_picker": @(YES),
        @"remove_screenshot_alert": @(YES),
        @"call_confirm": @(YES),
        @"inline_download_button": @(YES),
        @"carousel_download_choice": @(YES),
        @"dl_use_queue": @(YES),
        @"dl_max_concurrent": @(3),
        @"story_seen_button": @(YES),
        @"story_download_button": @(YES),
        @"dm_media_save_button": @(YES),
        // On: view-once photos/videos don't register as seen until you tap the eye
        // toggle in the viewer.
        @"unlimited_replay": @(YES),
        // Queue downloads land in Photos. Without this the queue fetches the file
        // and leaves it sitting in the Download Center, which reads as a failure.
        @"dw_save_to_camera": @(YES),
        @"dl_clear_after_save": @(YES),
        @"save_profile": @(YES),
        @"show_follow_status": @(YES),
        @"media_press_action": @"zoom",
        @"settings_shortcut": @(YES),
        @"reels_tap_control": @"default",
        @"nav_icon_ordering": @"default",
        @"swipe_nav_tabs": @"default",
        @"enable_notes_customization": @(YES),
        @"custom_note_themes": @(YES),
        @"disable_auto_unmuting_reels": @(YES),
        @"reels_auto_next": @(NO),
        // Off by default: on-device AV1→H.264 transcoding is heavy (battery, heat,
        // time) and experimental. When off, videos download at their best saveable
        // progressive quality exactly as before.
        //
        // **On, and this is a reversal with a reason.**
        //
        // It shipped off because on-device AV1 transcoding is heavy -- battery and heat -- and
        // that was the right default while most reels arrived in a codec iOS could already save.
        // A device report ended that: the ladder now reads `saveable 0`, every rung AV1, so the
        // download button fails **silently on most of the feed** unless this is switched on, and
        // nothing on screen says why. A costly feature that works beats a free one that does
        // nothing, and the cost is visible while it runs -- there is a progress banner for it.
        //
        // `registerDefaults` is what makes this safe to change: a value somebody set by hand is
        // untouched, so anyone who turned it off keeps it off.
        //
        @"dw_transcode_av1": @(YES),
        // Off: taking the best quality automatically is the point of the tweak. This
        // only exists for when the top rung costs more time and space than wanted.
        @"dw_quality_picker": @(NO),

        // Presentation-only, all off so Instagram looks exactly as it did until
        // the user asks otherwise.
        @"date_format_enabled": @(NO),
        @"date_format_preset": @"absolute",
        @"date_format_pattern": @"{DD}/{MM}/{YYYY} {HH}:{mm}",
        // Hours below which the relative form is kept. Zero by default: someone who
        // turns this on wants a real date, not Instagram's wording back again.
        @"date_relative_hours": @(0),
        @"date_24_hour": @(YES),
        @"date_compact_relative": @(YES),
        @"date_combine": @"off",
        @"oled_theme": @(NO),

        // On: a version check is a plain GET to GitHub carrying nothing about the
        // user, and someone running a beta should hear when it is superseded. The
        // setting says what it contacts, and turns it off.
        @"update_check_enabled": @(YES),

        // DM additions, all off: each changes what Instagram shows or sends, so
        // none of them turns itself on.
        @"dm_full_last_active": @(NO),
        @"hide_voice_call_button": @(NO),
        @"hide_video_call_button": @(NO),
        // Beta: adds an entry to the composer sheet that sends any file through
        // Instagram's own sender. Off until asked for.
        @"send_file": @(NO),
        @"download_audio_message": @(NO),
        // Beta: renders a photo that carries music into a short video. Off, since
        // it turns a one-press download into a question.
        @"photo_as_video": @(NO),
        // Beta: keeps messages other people unsend by emptying the removal
        // processor's key list. Off until confirmed on device.
        @"keep_unsent_messages": @(NO),
        // An on-screen toggle for reels auto-scroll, on the sidebar above the
        // download button. Off by default; the feature itself is reels_auto_next.
        @"reels_autoscroll_button": @(NO),
        // Reels never show when they were posted. Off by default: it adds something
        // Instagram does not draw, and that should be asked for.
        @"reels_show_date": @(NO)
    };
    [[NSUserDefaults standardUserDefaults] registerDefaults:sciDefaults];

    return %orig;
}
- (_Bool)application:(UIApplication *)application didFinishLaunchingWithOptions:(id)arg2 {
    %orig;

    // Welcome screen on first install and after every update. Delayed so Instagram
    // has finished building its own UI — presenting into a half-built hierarchy
    // silently fails.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [SCIWhatsNewViewController presentIfNeededFromWindow:[self window]];
    });

    // After the welcome screen has had its moment, so two things never appear at
    // once. Silent unless there is genuinely a newer release.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [SCIUpdateChecker checkQuietly];
    });

    // Later still, so it can never stack on top of the update alert. Shown once
    // per Instagram version, and only when that version is newer than the one
    // Albrhi was tested against.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(9.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [SCIUpdateChecker warnIfInstagramIsNewer];
    });

    // Opt-in: jump straight into settings on every launch.
    if ([SCIUtils getBoolPref:@"tweak_settings_app_launch"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [SCIUtils showSettingsVC:[self window]];
        });
    }

    SCILogV(@"[SCInsta] Cleaning cache...");
    [SCIUtils cleanCache];

    if ([SCIUtils getBoolPref:@"flex_app_launch"]) {
        [[objc_getClass("FLEXManager") sharedManager] showExplorer];
    }

    return true;
}

- (void)applicationDidBecomeActive:(id)arg1 {
    %orig;

    // Background transfers finish without the app running; nudge the queue so any
    // completed download gets written to Photos on return.
    [[NSNotificationCenter defaultCenter] postNotificationName:SCIDownloadQueueDidChangeNotification
                                                        object:nil
                                                      userInfo:nil];
    
    if ([SCIUtils getBoolPref:@"flex_app_start"]) {
        [[objc_getClass("FLEXManager") sharedManager] showExplorer];
    }
}
%end

// Disable sending modded insta bug reports
%hook IGWindow
- (void)showDebugMenu {
    return;
}
%end

%hook IGBugReportUploader
- (id)initWithNetworker:(id)arg1
         pandoGraphQLService:(id)arg2
             analyticsLogger:(id)arg3
                userDefaults:(id)arg4
         launcherSetProvider:(id)arg5
shouldPersistLastBugReportId:(id)arg6
{
    return nil;
}
%end

// Disable anti-screenshot feature on visual messages
%hook IGStoryViewerContainerView
- (void)setShouldBlockScreenshot:(BOOL)arg1 viewModel:(id)arg2 {
    if ([SCIUtils getBoolPref:@"remove_screenshot_alert"]) return;
    %orig;
}
%end

// Disable screenshot logging/detection
%hook IGDirectVisualMessageViewerSession
- (id)visualMessageViewerController:(id)arg1 didDetectScreenshotForVisualMessage:(id)arg2 atIndex:(NSInteger)arg3 {
    if ([SCIUtils getBoolPref:@"remove_screenshot_alert"]) return nil;
    return %orig;
}
%end

%hook IGDirectVisualMessageReplayService
- (id)visualMessageViewerController:(id)arg1 didDetectScreenshotForVisualMessage:(id)arg2 atIndex:(NSInteger)arg3 {
    SCREENSHOT_GUARD_NIL();
    return %orig;
}
%end

%hook IGDirectVisualMessageReportService
- (id)visualMessageViewerController:(id)arg1 didDetectScreenshotForVisualMessage:(id)arg2 atIndex:(NSInteger)arg3 {
    SCREENSHOT_GUARD_NIL();
    return %orig;
}
%end

%hook IGDirectVisualMessageScreenshotSafetyLogger
- (id)initWithUserSession:(id)arg1 entryPoint:(NSInteger)arg2 {
    if ([SCIUtils getBoolPref:@"remove_screenshot_alert"]) {
        SCILogV(@"[SCInsta] Disable visual message screenshot safety logger");
        return nil;
    }

    return %orig;
}
%end

%hook IGScreenshotObserver
- (id)initForController:(id)arg1 {
    SCREENSHOT_GUARD_NIL();
    return %orig;
}
%end

%hook IGScreenshotObserverDelegate
- (void)screenshotObserverDidSeeScreenshotTaken:(id)arg1 {
    SCREENSHOT_GUARD_VOID();
    %orig;
}
- (void)screenshotObserverDidSeeActiveScreenCapture:(id)arg1 event:(NSInteger)arg2 {
    SCREENSHOT_GUARD_VOID();
    %orig;
}
%end

%group SCIgIGDirectMediaViewerViewController

%hook IGDirectMediaViewerViewController
- (void)screenshotObserverDidSeeScreenshotTaken:(id)arg1 {
    SCREENSHOT_GUARD_VOID();
    %orig;
}
- (void)screenshotObserverDidSeeActiveScreenCapture:(id)arg1 event:(NSInteger)arg2 {
    SCREENSHOT_GUARD_VOID();
    %orig;
}
%end

%end


%hook IGStoryViewerViewController
- (void)screenshotObserverDidSeeScreenshotTaken:(id)arg1 {
    SCREENSHOT_GUARD_VOID();
    %orig;
}
- (void)screenshotObserverDidSeeActiveScreenCapture:(id)arg1 event:(NSInteger)arg2 {
    SCREENSHOT_GUARD_VOID();
    %orig;
}
%end

%hook IGSundialFeedViewController
- (void)screenshotObserverDidSeeScreenshotTaken:(id)arg1 {
    SCREENSHOT_GUARD_VOID();
    %orig;
}
- (void)screenshotObserverDidSeeActiveScreenCapture:(id)arg1 event:(NSInteger)arg2 {
    SCREENSHOT_GUARD_VOID();
    %orig;
}
%end

%hook IGDirectVisualMessageViewerController
- (void)screenshotObserverDidSeeScreenshotTaken:(id)arg1 {
    SCREENSHOT_GUARD_VOID();
    %orig;
}
- (void)screenshotObserverDidSeeActiveScreenCapture:(id)arg1 event:(NSInteger)arg2 {
    SCREENSHOT_GUARD_VOID();
    %orig;
}
%end

/////////////////////////////////////////////////////////////////////////////

// Hide items

// Direct suggested chats (in search bar)
%hook IGDirectInboxSearchListAdapterDataSource
- (id)objectsForListAdapter:(id)arg1 {
    NSArray *originalObjs = %orig();
    NSMutableArray *filteredObjs = [NSMutableArray arrayWithCapacity:[originalObjs count]];

    for (id obj in originalObjs) {
        BOOL shouldHide = NO;

        // Section header 
        if ([obj isKindOfClass:%c(IGLabelItemViewModel)]) {

            // Broadcast channels
            if ([SCISafeValueForKey(obj, @"uniqueIdentifier") isEqualToString:@"channels"]) {
                if ([SCIUtils getBoolPref:@"no_suggested_chats"]) {
                    SCILogV(@"[SCInsta] Hiding suggested chats (header)");

                    shouldHide = YES;
                }
            }

            // Ask Meta AI
            else if (SCIMatchesEnglishTitle(SCISafeValueForKey(obj, @"labelTitle"), @[@"Ask Meta AI"], @"Meta AI row")) {
                if ([SCIUtils getBoolPref:@"hide_meta_ai"]) {
                    SCILogV(@"[SCInsta] Hiding meta ai suggested chats (header)");

                    shouldHide = YES;
                }
            }

            // AI
            else if (SCIMatchesEnglishTitle(SCISafeValueForKey(obj, @"labelTitle"), @[@"AI"], @"Meta AI row")) {
                if ([SCIUtils getBoolPref:@"hide_meta_ai"]) {
                    SCILogV(@"[SCInsta] Hiding ai suggested chats (header)");

                    shouldHide = YES;
                }
            }
            
        }

        // AI agents section
        else if (
            [obj isKindOfClass:%c(IGDirectInboxSearchAIAgentsPillsSectionViewModel)]
         || [obj isKindOfClass:%c(IGDirectInboxSearchAIAgentsSuggestedPromptViewModel)]
         || [obj isKindOfClass:%c(IGDirectInboxSearchAIAgentsSuggestedPromptLoggingViewModel)]
        ) {

            if ([SCIUtils getBoolPref:@"hide_meta_ai"]) {
                SCILogV(@"[SCInsta] Hiding suggested chats (ai agents)");

                shouldHide = YES;
            }

        }

        // Recipients list
        else if ([obj isKindOfClass:%c(IGDirectRecipientCellViewModel)]) {

            // Broadcast channels
            if ([[obj recipient] isBroadcastChannel]) {
                if ([SCIUtils getBoolPref:@"no_suggested_chats"]) {
                    SCILogV(@"[SCInsta] Hiding suggested chats (broadcast channels recipient)");

                    shouldHide = YES;
                }
            }
            
            // Meta AI (special section types)
            else if (([obj sectionType] == 20) || [obj sectionType] == 18) {
                if ([SCIUtils getBoolPref:@"hide_meta_ai"]) {
                    SCILogV(@"[SCInsta] Hiding meta ai suggested chats (meta ai recipient)");

                    shouldHide = YES;
                }
            }

            // Meta AI (catch-all)
            else if (SCIMatchesEnglishTitle([[obj recipient] threadName], @[@"Meta AI"], @"Meta AI thread")) {
                if ([SCIUtils getBoolPref:@"hide_meta_ai"]) {
                    SCILogV(@"[SCInsta] Hiding meta ai suggested chats (meta ai recipient)");

                    shouldHide = YES;
                }
            }
        }

        // Populate new objs array
        if (!shouldHide) {
            [filteredObjs addObject:obj];
        }

    }

    return [filteredObjs copy];
}
%end

// Direct suggested chats (thread creation view)
%hook IGDirectThreadCreationViewController
- (id)objectsForListAdapter:(id)arg1 {
    NSArray *originalObjs = %orig();
    NSMutableArray *filteredObjs = [NSMutableArray arrayWithCapacity:[originalObjs count]];

    for (id obj in originalObjs) {
        BOOL shouldHide = NO;

        // Meta AI suggested user in direct new message view
        if ([SCIUtils getBoolPref:@"hide_meta_ai"]) {
            
            if ([obj isKindOfClass:%c(IGDirectCreateChatCellViewModel)]) {

                // "AI Chats"
                if (SCIMatchesEnglishTitle(SCISafeValueForKey(obj, @"title"), @[@"AI chats"], @"AI chats row")) {
                    SCILogV(@"[SCInsta] Hiding meta ai: direct thread creation ai chats section");

                    shouldHide = YES;
                }

            }

            else if ([obj isKindOfClass:%c(IGDirectRecipientCellViewModel)]) {

                // Meta AI suggested user
                if (SCIMatchesEnglishTitle([[obj recipient] threadName], @[@"Meta AI"], @"Meta AI thread")) {
                    SCILogV(@"[SCInsta] Hiding meta ai: direct thread creation ai suggestion");

                    shouldHide = YES;
                }

            }
            
        }

        // Invite friends to insta contacts upsell
        if ([SCIUtils getBoolPref:@"no_suggested_users"]) {
            if ([obj isKindOfClass:%c(IGContactInvitesSearchUpsellViewModel)]) {
                SCILogV(@"[SCInsta] Hiding suggested users: invite contacts upsell");

                shouldHide = YES;
            }
        }

        // Populate new objs array
        if (!shouldHide) {
            [filteredObjs addObject:obj];
        }
    }

    return [filteredObjs copy];
}
%end

// Direct suggested chats (inbox view)
%group SCIgIGDirectInboxListAdapterDataSource

%hook IGDirectInboxListAdapterDataSource
- (id)objectsForListAdapter:(id)arg1 {
    NSArray *originalObjs = %orig();
    NSMutableArray *filteredObjs = [NSMutableArray arrayWithCapacity:[originalObjs count]];

    for (id obj in originalObjs) {
        BOOL shouldHide = NO;

        // Section header
        if ([obj isKindOfClass:%c(IGDirectInboxHeaderCellViewModel)]) {
            
            // "Suggestions" header
            if ([[obj title] isEqualToString:@"Suggestions"]) {
                if ([SCIUtils getBoolPref:@"no_suggested_users"]) {
                    SCILogV(@"[SCInsta] Hiding suggested chats (header: messages tab)");

                    shouldHide = YES;
                }
            }

            // "Accounts to follow/message" header
            else if ([[obj title] hasPrefix:@"Accounts to"]) {
                if ([SCIUtils getBoolPref:@"no_suggested_users"]) {
                    SCILogV(@"[SCInsta] Hiding suggested users: (header: inbox view)");

                    shouldHide = YES;
                }
            }

        }

        // Suggested recipients
        else if ([obj isKindOfClass:%c(IGDirectInboxSuggestedThreadCellViewModel)]) {
            if ([SCIUtils getBoolPref:@"no_suggested_users"]) {
                SCILogV(@"[SCInsta] Hiding suggested chats (recipients: channels tab)");

                shouldHide = YES;
            }
        }

        // "Accounts to follow" recipients
        else if ([obj isKindOfClass:%c(IGDiscoverPeopleItemConfiguration)] || [obj isKindOfClass:%c(IGDiscoverPeopleConnectionItemConfiguration)]) {
            if ([SCIUtils getBoolPref:@"no_suggested_users"]) {
                SCILogV(@"[SCInsta] Hiding suggested chats: (recipients: inbox view)");

                shouldHide = YES;
            }
        }

        // Hide notes tray
        else if ([obj isKindOfClass:%c(IGDirectNotesTrayRowViewModel)]) {
            if ([SCIUtils getBoolPref:@"hide_notes_tray"]) {
                SCILogV(@"[SCInsta] Hiding notes tray");

                shouldHide = YES;
            }
        }

        // Populate new objs array
        if (!shouldHide) {
            [filteredObjs addObject:obj];
        }

    }

    return [filteredObjs copy];
}
%end

%end


// Explore page results
%group SCIgIGSearchListKitDataSource

%hook IGSearchListKitDataSource
- (id)objectsForListAdapter:(id)arg1 {
    NSArray *originalObjs = %orig();
    NSMutableArray *filteredObjs = [NSMutableArray arrayWithCapacity:[originalObjs count]];

    for (id obj in originalObjs) {
        BOOL shouldHide = NO;

        // Meta AI
        if ([SCIUtils getBoolPref:@"hide_meta_ai"]) {

            // Section header 
            if ([obj isKindOfClass:%c(IGLabelItemViewModel)]) {

                // "Ask Meta AI" search results header
                if (SCIMatchesEnglishTitle(SCISafeValueForKey(obj, @"labelTitle"), @[@"Ask Meta AI"], @"Meta AI row")) {
                    shouldHide = YES;
                }

            }

            // Empty search bar upsell view
            else if ([obj isKindOfClass:%c(IGSearchNullStateUpsellViewModel)]) {
                shouldHide = YES;
            }

            // Meta AI search suggestions
            else if ([obj isKindOfClass:%c(IGSearchResultNestedGroupViewModel)]) {
                shouldHide = YES;
            }

            // Meta AI suggested search results
            else if ([obj isKindOfClass:%c(IGSearchResultViewModel)]) {

                // itemType 6 is meta ai suggestions
                if ([obj itemType] == 6) {
                    if ([SCIUtils getBoolPref:@"hide_meta_ai"]) {
                        shouldHide = YES;
                    }
                    
                }

                // Meta AI user account in search results
                else if ([[[obj title] string] isEqualToString:@"meta.ai"]) {
                    if ([SCIUtils getBoolPref:@"hide_meta_ai"]) {
                        shouldHide = YES;
                    }
                }

            }
            
        }

        // No suggested users
        if ([SCIUtils getBoolPref:@"no_suggested_users"]) {

            // Section header 
            if ([obj isKindOfClass:%c(IGLabelItemViewModel)]) {

                // "Suggested for you" search results header
                if (SCIMatchesEnglishTitle(SCISafeValueForKey(obj, @"labelTitle"), @[@"Suggested for you"], @"suggested header")) {
                    shouldHide = YES;
                }

            }

            // Instagram users
            else if ([obj isKindOfClass:%c(IGDiscoverPeopleItemConfiguration)]) {
                shouldHide = YES;
            }

            // See all suggested users
            else if ([obj isKindOfClass:%c(IGSeeAllItemConfiguration)] && ((IGSeeAllItemConfiguration *)obj).destination == 4) {
                shouldHide = YES;
            }

        }

        // Populate new objs array
        if (!shouldHide) {
            [filteredObjs addObject:obj];
        }

    }

    return [filteredObjs copy];
}
%end

%end


// Story tray
%group SCIgIGMainStoryTrayDataSource

%hook IGMainStoryTrayDataSource
- (id)allItemsForTrayUsingCachedValue:(BOOL)cached {
    NSArray *originalObjs = %orig(cached);
    NSMutableArray *filteredObjs = [NSMutableArray arrayWithCapacity:[originalObjs count]];

    for (IGStoryTrayViewModel *obj in originalObjs) {
        BOOL shouldHide = NO;

        if ([SCIUtils getBoolPref:@"no_suggested_users"]) {
            if ([obj isKindOfClass:%c(IGStoryTrayViewModel)]) {
                NSNumber *type = SCISafeNumberForKey(obj, @"type");
                
                // 8/9 looks to be the types for recommended stories
                if ([type isEqual:@(8)] || [type isEqual:@(9)]) {
                    SCILogV(@"[SCInsta] Hiding suggested users: story tray");

                    shouldHide = YES;

                }
            }
        }

        if ([SCIUtils getBoolPref:@"hide_ads"]) {
            // "New!" account id is 3538572169
            if ([obj isKindOfClass:%c(IGStoryTrayViewModel)] && (obj.isUnseenNux == YES || [obj.pk isEqualToString:@"3538572169"])) {
                SCILogV(@"[SCInsta] Removing ads: story tray");

                shouldHide = YES;
            }
        }

        // Populate new objs array
        if (!shouldHide) {
            [filteredObjs addObject:obj];
        }
    }

    return [filteredObjs copy];
}
%end

%end


// Story tray expanded footer (Suggested accounts to follow)
%hook IGStoryTraySectionController
- (void)storyTrayControllerShowSUPOGEducationBump {
    if ([SCIUtils getBoolPref:@"no_suggested_users"]) return;

    return %orig();
}
%end

// Modern IGDS app menus
%hook IGDSMenu
- (id)initWithMenuItems:(NSArray<IGDSMenuItem *> *)originalObjs edr:(BOOL)edr headerLabelText:(id)headerLabelText {
    NSMutableArray *filteredObjs = [NSMutableArray arrayWithCapacity:[originalObjs count]];

    for (id obj in originalObjs) {
        BOOL shouldHide = NO;

        // Meta AI
        if (
            SCIMatchesEnglishTitle(SCISafeValueForKey(obj, @"title"), @[@"AI images", @"Meta AI"], @"AI search rows")
        ) {
            
            if ([SCIUtils getBoolPref:@"hide_meta_ai"]) {
                SCILogV(@"[SCInsta] Hiding meta ai from IGDS menu");

                shouldHide = YES;
            }

        }

        // Populate new objs array
        if (!shouldHide) {
            [filteredObjs addObject:obj];
        }

    }

    return %orig([filteredObjs copy], edr, headerLabelText);
}
%end

/////////////////////////////////////////////////////////////////////////////

// Confirm buttons

%hook IGFeedItemUFICell
- (void)UFIButtonBarDidTapOnLike:(id)arg1 {
    if ([SCIUtils getBoolPref:@"like_confirm"]) {
        SCILogV(@"[SCInsta] Confirm post like triggered");

        [SCIUtils showConfirmation:^(void) {
            %orig(arg1);
        }];
    }
    else {
        return %orig;
    }  
}

- (void)UFIButtonBarDidTapOnRepost:(id)arg1 {
    if ([SCIUtils getBoolPref:@"repost_confirm"]) {
        SCILogV(@"[SCInsta] Confirm repost triggered");

        [SCIUtils showConfirmation:^(void) {
            %orig(arg1);
        }];
    }
    else {
        return %orig;
    }
}

- (void)UFIButtonBarDidLongPressOnRepost:(id)arg1 {
    if ([SCIUtils getBoolPref:@"repost_confirm"]) {
        SCILogV(@"[SCInsta] Confirm repost triggered (long press ignored)");
    }
    else {
        return %orig;
    }
}
- (void)UFIButtonBarDidLongPressOnRepost:(id)arg1 withGestureRecognizer:(id)arg2 {
    if ([SCIUtils getBoolPref:@"repost_confirm"]) {
        SCILogV(@"[SCInsta] Confirm repost triggered (long press ignored)");
    }
    else {
        return %orig;
    }
}
%end

%hook IGSundialViewerVerticalUFI
- (void)_didTapLikeButton:(id)arg1 {
    if ([SCIUtils getBoolPref:@"like_confirm_reels"]) {
        SCILogV(@"[SCInsta] Confirm reels like triggered");

        [SCIUtils showConfirmation:^(void) {
            %orig(arg1);
        }];
    }
    else {
        return %orig;
    }
}

- (void)_didLongPressLikeButton:(id)arg1 {
    if ([SCIUtils getBoolPref:@"like_confirm_reels"]) {
        SCILogV(@"[SCInsta] Confirm repost triggered (long press ignored)");
    }
    else {
        return %orig;
    }
}

- (void)_didTapRepostButton:(id)arg1 {
    if ([SCIUtils getBoolPref:@"repost_confirm"]) {
        SCILogV(@"[SCInsta] Confirm repost triggered");

        [SCIUtils showConfirmation:^(void) {
            %orig(arg1);
        }];
    }
    else {
        return %orig;
    }
}

- (void)_didLongPressRepostButton:(id)arg1 {
    if ([SCIUtils getBoolPref:@"repost_confirm"]) {
        SCILogV(@"[SCInsta] Confirm repost triggered (long press ignored)");
    }
    else {
        return %orig;
    }
}
%end

/////////////////////////////////////////////////////////////////////////////

// FLEX explorer gesture handler
%hook IGRootViewController
- (void)viewDidLoad {
    %orig;
    
    // Recognize 5-finger long press
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = 1;
    longPress.numberOfTouchesRequired = 5;
    [self.view addGestureRecognizer:longPress];
}
%new - (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) return;

    if ([SCIUtils getBoolPref:@"flex_instagram"]) {
        [[objc_getClass("FLEXManager") sharedManager] showExplorer];
    }
}
%end

// Disable safe mode (defaults reset upon subsequent crashes)
%hook IGSafeModeChecker
- (id)initWithInstacrashCounterProvider:(void *)provider crashThreshold:(unsigned long long)threshold {
    if ([SCIUtils getBoolPref:@"disable_safe_mode"]) return nil;

    return %orig(provider, threshold);
}
- (unsigned long long)crashCount {
    if ([SCIUtils getBoolPref:@"disable_safe_mode"]) {
        return 0;
    }

    return %orig;
}
%end

%ctor {
    // The hooks outside the groups below. Logos writes this call itself for
    // a file with no %ctor -- and stops the moment there is one, so leaving
    // it out would silence every hook this file did not need to convert.
    %init;

    Class directMediaViewerViewController = SCIResolveClass(@"IGDirectMediaViewerViewController");
    if (directMediaViewerViewController) %init(SCIgIGDirectMediaViewerViewController, IGDirectMediaViewerViewController = directMediaViewerViewController);
    Class directInboxListAdapterDataSource = SCIResolveClass(@"IGDirectInboxListAdapterDataSource");
    if (directInboxListAdapterDataSource) %init(SCIgIGDirectInboxListAdapterDataSource, IGDirectInboxListAdapterDataSource = directInboxListAdapterDataSource);
    Class searchListKitDataSource = SCIResolveClass(@"IGSearchListKitDataSource");
    if (searchListKitDataSource) %init(SCIgIGSearchListKitDataSource, IGSearchListKitDataSource = searchListKitDataSource);
    Class mainStoryTrayDataSource = SCIResolveClass(@"IGMainStoryTrayDataSource");
    if (mainStoryTrayDataSource) %init(SCIgIGMainStoryTrayDataSource, IGMainStoryTrayDataSource = mainStoryTrayDataSource);
}
