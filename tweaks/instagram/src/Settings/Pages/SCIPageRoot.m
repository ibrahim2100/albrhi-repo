#import "../SCISettingsRegistry.h"
#import "shared/src/SCILicenseUI.h"
#import "../../Features/General/SCIUpdateChecker.h"
#import "../TweakSettings.h"
#import "../../Onboarding/SCIWhatsNewViewController.h"
#import "../SCIDiagnosticsViewController.h"
#import "../SCIBackup.h"
#import "../../InstagramHeaders.h"   // topMostController()
#import "../../SCIProject.h"

///
/// Root-level sections: the things that must be reachable without drilling in,
/// plus the debug page and the credits footer.
///

@interface SCIPageRoot : NSObject
@end

@implementation SCIPageRoot

+ (void)load {
    // Accent colour now lives inside the Appearance page; language sits just above
    // the developer-contact section (order 450), not at the very top.

    // --- Feature pages are spliced in here, at order 300 ---

    // --- The licence (order 340) ---
    //
    // In the app, not in a panel. Albrhi Panel's licence page exists only where PreferenceLoader
    // does; this tweak can be installed on its own and injected into an IPA, and until this row
    // there was no way to enter a key from inside it at all.
    [SCISettingsRegistry registerRootSectionWithOrder:340 builder:^NSArray *{
        return @[@{
            @"header": @"",
            @"rows": @[
                [SCISetting buttonCellWithTitle:SCILocalized(@"licence_row")
                                       subtitle:SCILocalized(@"licence_row_note")
                                           icon:[SCISymbol symbolWithName:@"key.fill"]
                                         action:^{
                    // From whatever is on top: this row is inside the tweak's own settings, and
                    // the licence screen is presented over it. The walk up from the key window is
                    // the one route that needs no class name -- and `SCILicenseUI` climbs any
                    // remaining presentations itself.
                    UIWindow *window = nil;
                    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
                        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
                        for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
                            if (candidate.isKeyWindow) { window = candidate; break; }
                        }
                        if (window) break;
                    }
                    [SCILicenseUI presentFrom:window.rootViewController];
                }]
            ]
        }];
    }];

    // --- Diagnostics (order 350) — top level during beta, where testers can find it ---
    [SCISettingsRegistry registerRootSectionWithOrder:350 builder:^NSArray *{
        return @[@{
            @"header": @"",
            @"rows": @[
                [SCISetting navigationCellWithTitle:SCILocalized(@"diag_title")
                                           subtitle:SCILocalized(@"diag_sub")
                                               icon:[SCISymbol symbolWithName:@"stethoscope" color:[UIColor systemTealColor] size:20.0]
                                     viewController:[[SCIDiagnosticsViewController alloc] init]]
            ],
            @"footer": SCILocalized(@"diag_beta_footer")
        }];
    }];

    // --- Debug (order 400) ---
    [SCISettingsRegistry registerRootSectionWithOrder:400 builder:^NSArray *{
        return @[@{
            @"header": @"",
            @"rows": @[
                [SCISetting navigationCellWithTitle:SCILocalized(@"p_hdr_debug")
                                           subtitle:@""
                                               icon:[SCISymbol symbolWithName:@"ladybug"]
                                        navSections:@[
                    @{
                        @"header": SCILocalized(@"p_hdr_logging"),
                        @"rows": @[
                            [SCISetting switchCellWithTitle:SCILocalized(@"p_verbose_t")
                                                   subtitle:SCILocalized(@"p_verbose_s")
                                                defaultsKey:@"verbose_logging"]
                        ]
                    },
                    @{
                        @"header": @"FLEX",
                        @"rows": @[
                            [SCISetting switchCellWithTitle:SCILocalized(@"p_dbg_flexgesture_t") subtitle:SCILocalized(@"p_dbg_flexgesture_s") defaultsKey:@"flex_instagram"],
                            [SCISetting switchCellWithTitle:SCILocalized(@"p_dbg_flexlaunch_t") subtitle:SCILocalized(@"p_dbg_flexlaunch_s") defaultsKey:@"flex_app_launch"],
                            [SCISetting switchCellWithTitle:SCILocalized(@"p_dbg_flexfocus_t") subtitle:SCILocalized(@"p_dbg_flexfocus_s") defaultsKey:@"flex_app_start"]
                        ]
                    },
                    @{
                        @"header": SCILocalized(@"settings_header"),
                        @"rows": @[
                            [SCISetting switchCellWithTitle:SCILocalized(@"quick_access_title") subtitle:SCILocalized(@"quick_access_sub") defaultsKey:@"settings_shortcut" requiresRestart:YES],
                            [SCISetting switchCellWithTitle:SCILocalized(@"open_on_launch_title") subtitle:@"" defaultsKey:@"tweak_settings_app_launch"],
                            [SCISetting buttonCellWithTitle:SCILocalized(@"wn_show_again")
                                                   subtitle:@""
                                                       icon:[SCISymbol symbolWithName:@"sparkles"]
                                                     action:^{
                                [SCIWhatsNewViewController presentFromWindow:nil];
                            }],
                            [SCISetting buttonCellWithTitle:SCILocalized(@"reset_first_run_title")
                                                   subtitle:@""
                                                       icon:nil
                                                     action:^{
                                [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"albrhi_last_seen_version"];
                                [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"SCInstaFirstRun"];
                                [SCIUtils showRestartConfirmation];
                            }]
                        ]
                    },
                    @{
                        @"header": @"Instagram",
                        @"rows": @[
                            [SCISetting switchCellWithTitle:SCILocalized(@"p_dbg_safemode_t") subtitle:SCILocalized(@"p_dbg_safemode_s") defaultsKey:@"disable_safe_mode"]
                        ]
                    }
                ]]
            ]
        }];
    }];

    // --- Language (order 450) — just above the developer contact ---
    [SCISettingsRegistry registerRootSectionWithOrder:450 builder:^NSArray *{
        return @[@{
            @"header": SCILocalized(@"section_language"),
            @"rows": @[
                [SCISetting menuCellWithTitle:SCILocalized(@"language_title")
                                     subtitle:SCILocalized(@"language_sub")
                                         menu:[SCITweakSettings menus][@"albrhi_language"]]
            ]
        }];
    }];

    // --- Backup & restore (order 460) ---
    [SCISettingsRegistry registerRootSectionWithOrder:460 builder:^NSArray *{
        return @[@{
            @"header": SCILocalized(@"p_backup_hdr"),
            @"rows": @[
                [SCISetting buttonCellWithTitle:SCILocalized(@"p_backup_export_t")
                                       subtitle:SCILocalized(@"p_backup_export_s")
                                           icon:[SCISymbol symbolWithName:@"square.and.arrow.up" color:[SCIUtils SCIColor_Primary] size:20.0]
                                         action:^{ [SCIBackup exportFrom:topMostController()]; }],
                [SCISetting buttonCellWithTitle:SCILocalized(@"p_backup_import_t")
                                       subtitle:SCILocalized(@"p_backup_import_s")
                                           icon:[SCISymbol symbolWithName:@"square.and.arrow.down" color:[SCIUtils SCIColor_Primary] size:20.0]
                                         action:^{ [SCIBackup importFrom:topMostController()]; }]
            ]
        }];
    }];

    // --- Developer contact (order 500) ---
    // Connect, credits, the update check and the source: one row, one screen. They were four
    // sections and eleven rows at the bottom of the page, none of them something anyone looks at
    // twice -- and two of them (the developer, the source) opened the same repository.
    [SCISettingsRegistry registerRootSectionWithOrder:500 builder:^NSArray *{
        NSArray *connect = @[@{
            @"header": SCILocalized(@"section_connect"),
            @"rows": @[
                [SCISetting linkCellWithTitle:SCILocalized(@"social_instagram_title")
                                     subtitle:@"@Ib.11p"
                                         icon:[SCISymbol symbolWithName:@"camera.circle.fill" color:[UIColor systemPurpleColor] size:20.0]
                                          url:@"https://instagram.com/Ib.11p"],
                [SCISetting linkCellWithTitle:SCILocalized(@"social_snapchat_title")
                                     subtitle:@"@Ib.1p"
                                         icon:[SCISymbol symbolWithName:@"bolt.circle.fill" color:[UIColor systemYellowColor] size:20.0]
                                          url:@"https://snapchat.com/add/Ib.1p"],
                [SCISetting linkCellWithTitle:SCILocalized(@"social_telegram_title")
                                     subtitle:@"@Ib11p"
                                         icon:[SCISymbol symbolWithName:@"paperplane.circle.fill" color:[UIColor systemBlueColor] size:20.0]
                                          url:@"https://t.me/Ib11p"]
            ],
            @"footer": SCILocalized(@"social_open_sub")
        }];
        NSArray *credits = @[@{
            @"header": SCILocalized(@"credits_title"),
            @"rows": @[
                [SCISetting linkCellWithTitle:SCILocalized(@"developer_title")
                                     subtitle:@"Ibrahim Ismail AL-Rahn"
                                         icon:[SCISymbol symbolWithName:@"person.crop.circle.fill" color:[SCIUtils SCIColor_Primary] size:20.0]
                                          url:SCIRepoURL],
                [SCISetting linkCellWithTitle:SCILocalized(@"credits_title")
                                     subtitle:SCILocalized(@"credits_sub")
                                         icon:[SCISymbol symbolWithName:@"heart.text.square.fill" color:[UIColor systemPinkColor] size:20.0]
                                          url:@"https://github.com/SoCuul/SCInsta"],
                [SCISetting buttonCellWithTitle:SCILocalized(@"update_check_t")
                                       subtitle:SCILocalized(@"update_check_s")
                                           icon:[SCISymbol symbolWithName:@"arrow.triangle.2.circlepath" color:[SCIUtils SCIColor_Primary] size:20.0]
                                         action:^{ [SCIUpdateChecker checkFromSettings:nil]; }],
                [SCISetting switchCellWithTitle:SCILocalized(@"update_auto_t")
                                       subtitle:SCILocalized(@"update_auto_s")
                                    defaultsKey:@"update_check_enabled"],
                [SCISetting linkCellWithTitle:SCILocalized(@"view_repo_title")
                                     subtitle:SCILocalized(@"view_repo_sub")
                                         icon:[SCISymbol symbolWithName:@"chevron.left.forwardslash.chevron.right" color:[SCIUtils SCIColor_Primary] size:20.0]
                                          url:SCIRepoURL]
            ],
            @"footer": [NSString stringWithFormat:@"Albrhi %@ · BETA  ·  by Ibrahim Ismail AL-Rahn\nBased on SCInsta by SoCuul — GPLv3\n\nInstagram v%@",
                        SCIVersionString, [SCIUtils IGVersionString]]
        }];
        return @[@{
            @"header": @"",
            @"rows": @[
                [SCISetting navigationCellWithTitle:SCILocalized(@"about_row_title")
                                           subtitle:SCILocalized(@"about_row_sub")
                                               icon:[SCISymbol symbolWithName:@"info.circle.fill" color:[SCIUtils SCIColor_Primary] size:20.0]
                                        navSections:[connect arrayByAddingObjectsFromArray:credits]]
            ]
        }];
    }];

}

@end
