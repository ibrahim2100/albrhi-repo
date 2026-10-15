//
//  SCITTSectionWatching.m
//  Albrhi for TikTok
//
//  What the feed does while it is being watched.
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
#import "../../Prefs.h"
#import "../../Localization/SCILocalize.h"
#import <objc/runtime.h>
#import "../SCITTSectionRegistry.h"

@interface SCITTSectionWatching : NSObject
@end

@implementation SCITTSectionWatching

+ (void)load {
    SCITTRegisterSection(20, ^NSDictionary *{
        return @{
            kSCISectionIcon: @"play.rectangle.fill",
            kSCISectionColor: [UIColor systemIndigoColor],
            kSCISectionTitle: SCILocalized(@"section_watching"),
            kSCISectionRows: @[
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefHideAds,
                    kSCIRowTitle: SCILocalized(@"row_ads"),
                    kSCIRowNote: SCILocalized(@"row_ads_note"),
                    kSCIRowIcon: @"nosign",
                    kSCIRowColor: [UIColor systemRedColor],
                },
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefProgressBar,
                    kSCIRowTitle: SCILocalized(@"row_progress_bar"),
                    kSCIRowNote: SCILocalized(@"row_progress_bar_note"),
                    kSCIRowIcon: @"slider.horizontal.below.rectangle",
                    kSCIRowColor: [UIColor systemBlueColor],
                },
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefHideLive,
                    kSCIRowTitle: SCILocalized(@"row_hide_live"),
                    kSCIRowNote: SCILocalized(@"row_hide_live_note"),
                    kSCIRowIcon: @"dot.radiowaves.left.and.right",
                    kSCIRowColor: [UIColor systemRedColor],
                },
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefSkipSuggested,
                    kSCIRowTitle: SCILocalized(@"row_skip_suggested"),
                    kSCIRowNote: SCILocalized(@"row_skip_suggested_note"),
                    kSCIRowIcon: @"person.crop.circle.badge.xmark",
                    kSCIRowColor: [UIColor systemRedColor],
                },
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefVideoStats,
                    kSCIRowTitle: SCILocalized(@"row_video_stats"),
                    kSCIRowNote: SCILocalized(@"row_video_stats_note"),
                    kSCIRowIcon: @"heart.text.square",
                    kSCIRowColor: [UIColor systemBlueColor],
                },
            ],
        };
    });
}

@end
