//
//  SCITTSectionDownload.m
//  Albrhi for TikTok
//
//  The download button, quality and where a file goes.
//
//  **One section, one file, registered by itself.** It was a block inside a 220-line array
//  literal in SCITTStatus.m; adding a row meant editing the middle of that list and deleting
//  a feature meant counting braces. Nothing outside this file knows the section exists --
//  see SCITTSectionRegistry.h for why that is the point.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "../SCITTStatus.h"
#import "../SCITTReport.h"
#import "../SCITTBadge.h"
#import "../../UI/SCITTWelcome.h"
#import "../../Tweak.h"
#import "../../Features/Download/SCITTButtonStyle.h"
#import "../../Prefs.h"
#import "../../Localization/SCILocalize.h"
#import <objc/runtime.h>
#import "../SCITTSectionRegistry.h"

@interface SCITTSectionDownload : NSObject
@end

/// One option per design, each with a picture of itself. The first (the tool's own mark) is the default and stores nothing.
static NSArray<NSDictionary *> *SCITTButtonStyleOptions(void) {
    NSMutableArray *options = [NSMutableArray array];
    for (NSUInteger i = 0; i < SCITTButtonStyleCount(); i++) {
        [options addObject:@{
            @"value": i == 0 ? @"" : SCITTButtonStyleID(i),
            @"title": SCILocalized(SCITTButtonStyleNameKey(i)),
            @"image": SCITTButtonStylePreview(i, 28),
        }];
    }
    return options;
}

@implementation SCITTSectionDownload

+ (void)load {
    SCITTRegisterSection(10, ^NSDictionary *{
        return @{
            kSCISectionIcon: @"arrow.down.circle.fill",
            kSCISectionColor: [UIColor systemBlueColor],
            kSCISectionTitle: SCILocalized(@"section_download"),
            kSCISectionRows: @[
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefDownloadButton,
                    kSCIRowTitle: SCILocalized(@"row_download_button"),
                    kSCIRowNote: SCILocalized(@"row_download_button_note"),
                    kSCIRowIcon: @"arrow.down",
                    kSCIRowColor: SCIAccent(),
                },
                @{
                    kSCIRowKind: kSCIKindChoice,
                    kSCIRowPref: SCIPrefButtonStyle,
                    kSCIRowOptions: SCITTButtonStyleOptions(),
                    kSCIRowChoiceFooter: SCILocalized(@"button_style_footer"),
                    kSCIRowTitle: SCILocalized(@"row_button_style"),
                    kSCIRowNote: SCILocalized(@"row_button_style_note"),
                    kSCIRowIcon: @"paintbrush",
                    kSCIRowColor: SCIAccent(),
                },
                @{
                    kSCIRowKind: kSCIKindChoice,
                    kSCIRowPref: SCIPrefButtonLabel,
                    kSCIRowOptions: @[
                        @{@"value": @"",     @"title": SCILocalized(@"btn_label_name")},
                        @{@"value": @"word", @"title": SCILocalized(@"btn_label_word")},
                        @{@"value": @"none", @"title": SCILocalized(@"btn_label_none")},
                    ],
                    kSCIRowChoiceFooter: SCILocalized(@"button_label_footer"),
                    kSCIRowTitle: SCILocalized(@"row_button_label"),
                    kSCIRowNote: SCILocalized(@"row_button_label_note"),
                    kSCIRowIcon: @"textformat",
                    kSCIRowColor: SCIAccent(),
                },
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefPhotoDownload,
                    kSCIRowTitle: SCILocalized(@"row_photo_download"),
                    kSCIRowNote: SCILocalized(@"row_photo_download_note"),
                    kSCIRowIcon: @"photo.on.rectangle.angled",
                    kSCIRowColor: [UIColor systemPinkColor],
                },
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefPhotoAudio,
                    kSCIRowTitle: SCILocalized(@"row_photo_audio"),
                    kSCIRowNote: SCILocalized(@"row_photo_audio_note"),
                    kSCIRowIcon: @"music.note",
                    kSCIRowColor: [UIColor systemPurpleColor],
                },
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefExternalHD,
                    kSCIRowTitle: SCILocalized(@"row_external_hd"),
                    kSCIRowNote: SCILocalized(@"row_external_hd_note"),
                    kSCIRowIcon: @"antenna.radiowaves.left.and.right",
                    kSCIRowColor: [UIColor systemOrangeColor],
                    // **The one row on this screen whose note is drawn in a warning colour, and it
                    // is not decoration.** Turning it on tells a service outside TikTok which video
                    // is being watched -- the exact thing the three privacy switches below exist to
                    // stop. A cost paid by the person using this is a cost they have to be able to
                    // see before they pay it, and a grey note under a switch does not read as a
                    // cost. Nothing else here earns this treatment; if a second row ever does, that
                    // is a reason to re-read what it does, not to reuse the styling.
                    kSCIRowWarns: @YES,
                },
            ],
        };
    });
}

@end
