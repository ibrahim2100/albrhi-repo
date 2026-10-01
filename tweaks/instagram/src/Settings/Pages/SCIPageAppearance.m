#import "../SCISettingsRegistry.h"
#import "../TweakSettings.h"
#import "../../Features/General/SCIDateFormat.h"
#import "../../Features/General/SCIAppIcon.h"
#import "../../InstagramHeaders.h"   // topMostController()
#import "../../Utils.h"

///
/// Appearance: how Instagram looks and how it tells the time.
///
/// Dates and theming end up here together because both are presentation-only —
/// nothing on this page changes what Instagram does, only how it is drawn. The seven date
/// settings are one row that opens their own screen (with the live preview on the row), the
/// note themes came from General, the follow-back and account-info rows from Downloads, and the
/// two small tools that had nowhere else (copy text, the colour picker) sit at the end.
///
@interface SCIPageAppearance : NSObject
+ (NSString *)patternSubtitle;
+ (void)editPattern;
+ (NSDictionary *)appIconSection;
@end

@implementation SCIPageAppearance

/// The pattern itself plus what it renders right now, so the effect of a change
/// is visible without leaving the settings screen.
+ (NSString *)patternSubtitle {
    NSString *pattern = [[NSUserDefaults standardUserDefaults] stringForKey:@"date_format_pattern"];
    if (!pattern.length) pattern = @"{DD}/{MM}/{YYYY} {HH}:{mm}";
    return [NSString stringWithFormat:@"%@  →  %@",
            pattern, [SCIDateFormat renderPattern:pattern forDate:[NSDate date]]];
}

+ (void)editPattern {
    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"date_pattern_t")
                                            message:SCILocalized(@"date_pattern_help")
                                     preferredStyle:UIAlertControllerStyleAlert];

    [sheet addTextFieldWithConfigurationHandler:^(UITextField *field) {
        NSString *current = [[NSUserDefaults standardUserDefaults] stringForKey:@"date_format_pattern"];
        field.text = current.length ? current : @"{DD}/{MM}/{YYYY} {HH}:{mm}";
        field.placeholder = @"{DD}/{MM}/{YYYY} {HH}:{mm}";
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    }];

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"date_pattern_save")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        NSString *text = sheet.textFields.firstObject.text ?: @"";
        [[NSUserDefaults standardUserDefaults] setObject:text forKey:@"date_format_pattern"];

        // Typing a pattern is a statement of intent to use it.
        [[NSUserDefaults standardUserDefaults] setObject:@"custom" forKey:@"date_format_preset"];

        [SCIUtils showSuccessHUDWithDescription:[SCIDateFormat renderPattern:text forDate:[NSDate date]]];
    }]];

    [topMostController() presentViewController:sheet animated:YES completion:nil];
}

/// The icon row, or a plain "not supported" line on a build that offers none, so
/// the section never appears empty or dead.
+ (NSDictionary *)appIconSection {
    UIMenu *menu = [SCIAppIcon iconMenu];

    SCISetting *row;
    if (menu) {
        NSString *current = [SCIAppIcon currentIconName] ?: SCILocalized(@"appicon_default");
        row = [SCISetting menuCellWithTitle:SCILocalized(@"appicon_title")
                                   subtitle:current
                                       menu:menu];
    } else {
        row = [SCISetting staticCellWithTitle:SCILocalized(@"appicon_title")
                                     subtitle:SCILocalized(@"appicon_unsupported")
                                         icon:nil];
    }

    return @{ @"header": SCILocalized(@"p_hdr_appicon"), @"rows": @[row] };
}

+ (void)load {
    [SCISettingsRegistry registerFeaturePageWithTitle:^NSString *{ return SCILocalized(@"page_appearance"); }
                                                 icon:@"paintbrush"
                                                order:70
                                             sections:^NSArray *{
        // The date settings, one level down. They are a feature of their own with a preview, and
        // seven rows of it were most of this page.
        SCISetting *dates = [SCISetting navigationCellWithTitle:SCILocalized(@"p_hdr_dates")
                                                       subtitle:@""
                                                           icon:[SCISymbol symbolWithName:@"calendar"]
                                                    navSections:@[@{
            @"header": @"",
            @"rows": @[
                [SCISetting switchCellWithTitle:SCILocalized(@"date_enable_t")
                                       subtitle:[SCIDateFormat previewString]
                                    defaultsKey:@"date_format_enabled"],
                [SCISetting menuCellWithTitle:SCILocalized(@"date_preset_t")
                                     subtitle:SCILocalized(@"date_preset_s")
                                         menu:[SCITweakSettings menus][@"date_format_preset"]],
                [SCISetting switchCellWithTitle:SCILocalized(@"date_24h_t")
                                       subtitle:SCILocalized(@"date_24h_s")
                                    defaultsKey:@"date_24_hour"],
                [SCISetting switchCellWithTitle:SCILocalized(@"date_compact_t")
                                       subtitle:SCILocalized(@"date_compact_s")
                                    defaultsKey:@"date_compact_relative"],
                [SCISetting stepperCellWithTitle:SCILocalized(@"date_threshold_t")
                                        subtitle:@"%@ %@"
                                     defaultsKey:@"date_relative_hours"
                                             min:0 max:72 step:1
                                           label:SCILocalized(@"date_unit_hours")
                                   singularLabel:SCILocalized(@"date_unit_hour")],
                [SCISetting menuCellWithTitle:SCILocalized(@"date_combine_t")
                                     subtitle:SCILocalized(@"date_combine_s")
                                         menu:[SCITweakSettings menus][@"date_combine"]],
                [SCISetting buttonCellWithTitle:SCILocalized(@"date_pattern_t")
                                       subtitle:[SCIPageAppearance patternSubtitle]
                                           icon:nil
                                         action:^{ [SCIPageAppearance editPattern]; }]
            ]
        }]];
        // The row says what a date looks like now, so the effect is visible without opening it.
        dates.subtitleBlock = ^NSString *{ return [SCIDateFormat previewString]; };

        return @[
            @{
                @"header": SCILocalized(@"p_hdr_theme"),
                @"rows": @[
                    [SCISetting switchCellWithTitle:SCILocalized(@"oled_t")
                                           subtitle:SCILocalized(@"oled_s")
                                        defaultsKey:@"oled_theme"
                                    requiresRestart:YES],
                    [SCISetting buttonCellWithTitle:SCILocalized(@"accent_color_title")
                                           subtitle:SCILocalized(@"accent_color_sub")
                                               icon:[SCISymbol symbolWithName:@"paintpalette.fill" color:[SCIUtils SCIColor_Primary] size:20.0]
                                             action:^{ [SCIUtils showAccentColorPicker]; }],
                    [SCISetting buttonCellWithTitle:SCILocalized(@"accent_reset_title")
                                           subtitle:@""
                                               icon:[SCISymbol symbolWithName:@"arrow.counterclockwise"]
                                             action:^{ [SCIUtils resetAccentColor]; }]
                ]
            },
            @{
                @"header": @"",
                @"rows": @[dates]
            },
            @{
                @"header": SCILocalized(@"p_hdr_notes"),
                @"rows": @[
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_general_notetheming_t") subtitle:SCILocalized(@"p_general_notetheming_s") defaultsKey:@"enable_notes_customization"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_general_customnote_t") subtitle:SCILocalized(@"p_general_customnote_s") defaultsKey:@"custom_note_themes"]
                ]
            },
            @{
                @"header": SCILocalized(@"p_hdr_profile"),
                @"rows": @[
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_followstatus_t") subtitle:SCILocalized(@"p_followstatus_s") defaultsKey:@"show_follow_status"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"copy_account_info_title") subtitle:SCILocalized(@"copy_account_info_sub") defaultsKey:@"copy_account_info"]
                ]
            },
            [SCIPageAppearance appIconSection],
            @{
                @"header": SCILocalized(@"p_hdr_tools"),
                @"rows": @[
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_general_copydesc_t") subtitle:SCILocalized(@"p_general_copydesc_s") defaultsKey:@"copy_description"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_general_colorpicker_t") subtitle:SCILocalized(@"p_general_colorpicker_s") defaultsKey:@"detailed_color_picker"]
                ]
            }
        ];
    }];
}

@end
