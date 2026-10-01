#import "../SCIYTSettingsRegistry.h"
#import "../../Prefs.h"
#import "../../Localization/SCILocalize.h"
#import "../../Features/Download/Center/SCIYTDownloadCenter.h"
#import "../../Features/Download/SCIYTDownload.h"

///
/// Downloads.
///
/// Four groups, in the order somebody meets them: how a save starts (the Centre and the
/// buttons), how big and how good it is, what happens when it finishes, and how the saved
/// videos play. The Centre is the first row rather than a setting, because it is the thing
/// someone opening this screen after saving a video came looking for.
///
/// 1.37.0 rebuilt this page. It had fourteen rows in one list, two of which (the 4K pair) were
/// really one question, one of which (the tab bar) belonged to the tab bar page, and two of
/// which (a hold on the picture; the cover written into songs) were features this project had
/// already retreated from and kept a switch for.
///
@interface SCIYTDownloadsPage : NSObject
@end

@implementation SCIYTDownloadsPage

/// Four, six or eight simultaneous segment downloads.
///
/// **The right value is a fact about somebody's network, not about this source.** More connections
/// finish a few-hundred-segment playlist sooner, and Google may throttle a client that opens too
/// many -- which cannot be measured from a build machine. So the question is asked, the tested
/// value is marked, and an untouched preference behaves exactly as every previous release did.
+ (void)askForParallel {
    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"set_parallel")
                                            message:SCILocalized(@"set_parallel_note")
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    NSInteger current = SCIPrefNumber(SCIPrefParallel);
    if (current < 1) current = 4;

    for (NSNumber *value in @[@4, @6, @8]) {
        NSString *title = [NSString stringWithFormat:@"%@%@%@",
                           value,
                           value.integerValue == 4 ? SCILocalized(@"set_parallel_tested") : @"",
                           value.integerValue == current ? @" ✓" : @""];

        [sheet addAction:[UIAlertAction actionWithTitle:title
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            [[NSUserDefaults standardUserDefaults] setInteger:value.integerValue forKey:SCIPrefParallel];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    UIWindow *key = nil;
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window.isKeyWindow) { key = window; break; }
    }

    UIViewController *top = key.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;

    // An iPad refuses an action sheet with no anchor, and this screen is reachable there.
    sheet.popoverPresentationController.sourceView = top.view;
    sheet.popoverPresentationController.sourceRect =
        CGRectMake(CGRectGetMidX(top.view.bounds), CGRectGetMidY(top.view.bounds), 1, 1);

    [top presentViewController:sheet animated:YES completion:nil];
}


/// What the 1440p / 4K row says about itself, from the two switches behind it.
///
/// One question with three answers is one row. Two switches meant the second only made sense when
/// the first was on, and a screen that lets you set "convert" while "offer" is off is a screen
/// that lets you configure something that will never happen.
typedef NS_ENUM(NSInteger, SCIHiRes) { SCIHiResOff = 0, SCIHiResAV1, SCIHiResHEVC };

static SCIHiRes SCICurrentHiRes(void) {
    if (!SCIPrefEnabled(SCIPrefOffer4K)) return SCIHiResOff;
    return SCIPrefEnabled(SCIPrefConvertAV1) ? SCIHiResHEVC : SCIHiResAV1;
}

static NSString *SCIHiResLabel(SCIHiRes value) {
    switch (value) {
        case SCIHiResOff:  return SCILocalized(@"hires_off");
        case SCIHiResAV1:  return SCILocalized(@"hires_av1");
        case SCIHiResHEVC: return SCILocalized(@"hires_hevc");
    }
    return @"";
}

+ (void)askForHiRes:(SCIYTSettingsHostController *)host {
    if (!host) return;

    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"set_hires")
                                            message:SCILocalized(@"set_hires_note")
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    SCIHiRes current = SCICurrentHiRes();
    for (NSNumber *choice in @[@(SCIHiResOff), @(SCIHiResAV1), @(SCIHiResHEVC)]) {
        SCIHiRes value = (SCIHiRes)choice.integerValue;
        NSString *title = [NSString stringWithFormat:@"%@%@", SCIHiResLabel(value),
                           value == current ? @" ✓" : @""];
        [sheet addAction:[UIAlertAction actionWithTitle:title
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults setBool:(value != SCIHiResOff) forKey:SCIPrefOffer4K];
            [defaults setBool:(value == SCIHiResHEVC) forKey:SCIPrefConvertAV1];
            [host reloadSettings];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    sheet.popoverPresentationController.sourceView = host.view;
    sheet.popoverPresentationController.sourceRect =
        CGRectMake(CGRectGetMidX(host.view.bounds), CGRectGetMidY(host.view.bounds), 1, 1);
    [host presentViewController:sheet animated:YES completion:nil];
}

+ (void)load {
    [SCIYTSettingsRegistry registerPageWithOrder:10
                                        title:SCILocalized(@"page_downloads")
                                       detail:SCILocalized(@"page_downloads_note")
                                       symbol:@"arrow.down.circle.fill"
                                      builder:^NSArray<SCISection *> *(SCIYTSettingsHostController *host) {
        // How a save starts.
        SCISection *start = [[SCISection alloc] init];
        start.title = SCILocalized(@"section_dl_start");
        start.footer = SCILocalized(@"section_dl_start_note");
        start.rows = @[
            [SCIRow disclosureRow:SCILocalized(@"set_open_centre")
                           detail:nil
                           symbol:@"arrow.down.circle.fill"
                           action:^{ [SCIYTDownloadCenter present]; }],
            // The way in that does not depend on any button being where it was: settings.
            [SCIRow disclosureRow:SCILocalized(@"dl_row")
                           detail:SCILocalized(@"dl_row_note")
                           symbol:@"play.rectangle"
                           action:^{ [SCIYTDownload presentFrom:host]; }],
            [SCIRow switchRow:SCILocalized(@"set_native_download")
                       detail:SCILocalized(@"set_native_download_note")
                       symbol:@"arrow.down.circle"
                      prefKey:SCIPrefNativeDownload],
            [SCIRow switchRow:SCILocalized(@"set_action_row")
                       detail:SCILocalized(@"set_action_row_note")
                       symbol:@"square.and.arrow.down.on.square"
                      prefKey:SCIPrefActionRowButton],
            [SCIRow switchRow:SCILocalized(@"overlay_button_title")
                       detail:SCILocalized(@"overlay_button_note")
                       symbol:@"arrow.down.to.line"
                      prefKey:SCIPrefOverlayButton],
            [SCIRow switchRow:SCILocalized(@"set_shorts_button")
                       detail:SCILocalized(@"set_shorts_button_note")
                       symbol:@"play.rectangle.on.rectangle"
                      prefKey:SCIPrefShortsButton],
        ];

        // How big and how good.
        SCISection *size = [[SCISection alloc] init];
        size.title = SCILocalized(@"section_dl_size");
        size.rows = @[
            [SCIRow disclosureRow:SCILocalized(@"set_hires")
                           detail:SCIHiResLabel(SCICurrentHiRes())
                           symbol:@"4k.tv"
                           action:^{ [SCIYTDownloadsPage askForHiRes:host]; }],
            [SCIRow disclosureRow:SCILocalized(@"set_parallel")
                           detail:SCILocalized(@"set_parallel_note")
                           symbol:@"arrow.down.to.line"
                           action:^{ [SCIYTDownloadsPage askForParallel]; }],
        ];

        // When it finishes.
        SCISection *after = [[SCISection alloc] init];
        after.title = SCILocalized(@"section_dl_after");
        after.rows = @[
            [SCIRow switchRow:SCILocalized(@"set_auto_photos")
                       detail:SCILocalized(@"set_auto_photos_note")
                       symbol:@"photo.on.rectangle"
                      prefKey:SCIPrefAutoPhotos],
            [SCIRow switchRow:SCILocalized(@"set_tidy_photos")
                       detail:SCILocalized(@"set_tidy_photos_note")
                       symbol:@"tray.and.arrow.up"
                      prefKey:SCIPrefTidyAfterPhotos],
            [SCIRow switchRow:SCILocalized(@"set_finish_notice")
                       detail:SCILocalized(@"set_finish_notice_note")
                       symbol:@"bell.badge"
                      prefKey:SCIPrefFinishNotice],
        ];

        // Saved videos, once they are saved.
        SCISection *library = [[SCISection alloc] init];
        library.title = SCILocalized(@"section_dl_library");
        library.rows = @[
            [SCIRow switchRow:SCILocalized(@"set_lock_skip")
                       detail:SCILocalized(@"set_lock_skip_note")
                       symbol:@"lock.iphone"
                      prefKey:SCIPrefLockScreenSkip],
        ];

        return @[start, size, after, library];
    }];
}

@end
