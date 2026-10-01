#import "../SCIYTSettingsRegistry.h"
#import "../../Prefs.h"
#import "../../Localization/SCILocalize.h"

///
/// The player: what keeps going, how far a tap jumps, how fast it may run, and the highest
/// quality it may ask for.
///
/// Quality used to be a page of its own with three rows. A page is a place to go to, and three
/// rows are not worth the trip -- they sit under Player now, where somebody changing how a video
/// plays already is. The caps stay two rows and not one "data saver" switch because the two
/// connections are not one decision: a phone on home Wi-Fi and the same phone on a metered plan
/// abroad want different answers, and a single switch makes you choose which to be wrong about.
///
@interface SCIYTPlaybackPage : NSObject
@end

/// The intervals offered, with zero meaning "whatever YouTube does".
///
/// Seconds and not menu positions, for the same reason the quality caps are resolutions:
/// reordering this list must never quietly change what somebody chose.
static NSArray<NSNumber *> *SCISeekChoices(void) {
    return @[@0, @5, @10, @15, @30, @45, @60];
}

static NSString *SCISeekLabel(NSInteger seconds) {
    if (seconds <= 0) return SCILocalized(@"seek_default");
    return [NSString stringWithFormat:SCILocalized(@"seek_seconds_format"), (long)seconds];
}

/// Asks how far, and remembers.
///
/// Presented from the screen it was tapped on rather than from the key window — the settings
/// panel is itself presented over YouTube, and a sheet asking the window arrives underneath.
static void SCIAskForSeek(SCIYTSettingsHostController *host) {
    if (!host) return;

    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:nil
                                            message:SCILocalized(@"seek_seconds_note")
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSNumber *seconds in SCISeekChoices()) {
        [sheet addAction:[UIAlertAction actionWithTitle:SCISeekLabel(seconds.integerValue)
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            [[NSUserDefaults standardUserDefaults] setInteger:seconds.integerValue
                                                       forKey:SCIPrefSeekSeconds];

            // Rebuilt rather than redrawn: the row's subtitle is the chosen value, and it is
            // made when the section is made.
            [host reloadSettings];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    sheet.popoverPresentationController.sourceView = host.view;
    sheet.popoverPresentationController.sourceRect =
        CGRectMake(CGRectGetMidX(host.view.bounds), CGRectGetMidY(host.view.bounds), 0, 0);

    [host presentViewController:sheet animated:YES completion:nil];
}

/// The ceilings offered, highest first, with "no limit" as the default.
///
/// Real resolutions, not menu positions: the stored value is 1080 rather than "the third one
/// down", so reordering this list can never quietly change what someone chose.
static NSArray<NSNumber *> *SCIQualityCaps(void) {
    return @[@0, @2160, @1440, @1080, @720, @480, @360, @144];
}

static NSString *SCIQualityLabel(NSInteger cap) {
    if (cap <= 0) return SCILocalized(@"quality_auto");
    return [NSString stringWithFormat:SCILocalized(@"quality_cap_format"), (long)cap];
}

/// Asks which ceiling, and remembers the answer.
///
/// Presented from the screen it was tapped on rather than from the key window: the settings
/// panel is itself presented over YouTube, and a sheet asking the window would arrive
/// underneath it.
static void SCIAskForCap(SCIYTSettingsHostController *host, NSString *key) {
    if (!host) return;

    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:nil
                                            message:SCILocalized(@"set_cap_note")
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSNumber *cap in SCIQualityCaps()) {
        [sheet addAction:[UIAlertAction actionWithTitle:SCIQualityLabel(cap.integerValue)
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            [[NSUserDefaults standardUserDefaults] setInteger:cap.integerValue forKey:key];

            // Rebuilt, not just reloaded: the row's subtitle is the chosen value, and it is
            // made when the section is made.
            [host reloadSettings];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    // Required on iPad and harmless on a phone. Without it the sheet has nothing to point at
    // and UIKit raises rather than guessing.
    sheet.popoverPresentationController.sourceView = host.view;
    sheet.popoverPresentationController.sourceRect =
        CGRectMake(CGRectGetMidX(host.view.bounds), CGRectGetMidY(host.view.bounds), 0, 0);

    [host presentViewController:sheet animated:YES completion:nil];
}

@implementation SCIYTPlaybackPage

+ (void)load {
    [SCIYTSettingsRegistry registerPageWithOrder:20
                                        title:SCILocalized(@"page_playback")
                                       detail:SCILocalized(@"page_playback_note")
                                       symbol:@"play.circle.fill"
                                      builder:^NSArray<SCISection *> *(SCIYTSettingsHostController *host) {
        SCISection *player = [[SCISection alloc] init];
        player.title = SCILocalized(@"section_player");
        player.rows = @[
            [SCIRow switchRow:SCILocalized(@"background_playback")
                       detail:SCILocalized(@"background_playback_note")
                       symbol:@"speaker.wave.2.fill"
                      prefKey:SCIPrefBackgroundPlay],
            [SCIRow switchRow:SCILocalized(@"fix_playback_errors")
                       detail:SCILocalized(@"fix_playback_errors_note")
                       symbol:@"arrow.clockwise.circle.fill"
                      prefKey:SCIPrefFixPlaybackErrors],
            [SCIRow switchRow:SCILocalized(@"native_pip")
                       detail:SCILocalized(@"native_pip_note")
                       symbol:@"pip.fill"
                      prefKey:SCIPrefNativePIP],
            [SCIRow disclosureRow:SCILocalized(@"seek_seconds")
                           detail:SCISeekLabel(SCIPrefNumber(SCIPrefSeekSeconds))
                           symbol:@"goforward"
                           action:^{ SCIAskForSeek(host); }],
            [SCIRow switchRow:SCILocalized(@"extra_speeds")
                       detail:SCILocalized(@"extra_speeds_note")
                       symbol:@"gauge.high"
                      prefKey:SCIPrefExtraSpeeds],
        ];

        SCISection *quality = [[SCISection alloc] init];
        quality.title = SCILocalized(@"section_quality");
        quality.footer = SCILocalized(@"set_cap_note");
        quality.rows = @[
            [SCIRow disclosureRow:SCILocalized(@"set_cap_wifi")
                           detail:SCIQualityLabel(SCIPrefNumber(SCIPrefCapWiFi))
                           symbol:@"wifi"
                           action:^{ SCIAskForCap(host, SCIPrefCapWiFi); }],
            [SCIRow disclosureRow:SCILocalized(@"set_cap_cellular")
                           detail:SCIQualityLabel(SCIPrefNumber(SCIPrefCapCellular))
                           symbol:@"antenna.radiowaves.left.and.right"
                           action:^{ SCIAskForCap(host, SCIPrefCapCellular); }],
            [SCIRow switchRow:SCILocalized(@"set_classic_quality")
                       detail:SCILocalized(@"set_classic_quality_note")
                       symbol:@"list.bullet"
                      prefKey:SCIPrefClassicQuality],
        ];

        // The one thing added to the picture rather than to the app around it.
        SCISection *over = [[SCISection alloc] init];
        over.title = SCILocalized(@"section_over_video");
        over.rows = @[
            [SCIRow switchRow:SCILocalized(@"overlay_endtime_title")
                       detail:SCILocalized(@"overlay_endtime_note")
                       symbol:@"clock"
                      prefKey:SCIPrefOverlayEndTime],
        ];

        // The experimental section is gone, and deliberately not left switched off.
        //
        // "Ask for plain streams" was measured to the end on 21.30.5: the getter forced, then
        // the stored value written through the class's own setter until the getter answered
        // YES on its own. Every one of the twenty-two formats still came back with an empty
        // ?cpn= URL, and the HLS manifest -- the one thing the downloader actually uses --
        // stopped arriving. No gain, and a real loss.
        //
        // A switch that provably does nothing is a switch that lies, so it is not shipped
        // dark. See CLAUDE.md before considering it again.
        return @[player, quality, over];
    }];
}

@end
