#import "../SCIYTSettingsRegistry.h"
#import "../../Prefs.h"
#import "../../Localization/SCILocalize.h"
#import "../../Features/Download/Center/SCIYTDownloadCenter.h"

///
/// Downloads.
///
/// The Centre itself is the first row rather than a setting, because it is the thing
/// someone opening this screen after saving a video came looking for.
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

+ (void)load {
    [SCIYTSettingsRegistry registerPageWithOrder:10
                                        title:SCILocalized(@"page_downloads")
                                       detail:SCILocalized(@"page_downloads_note")
                                       symbol:@"arrow.down.circle.fill"
                                      builder:^NSArray<SCISection *> *(__unused SCIYTSettingsHostController *host) {
        SCISection *downloads = [[SCISection alloc] init];
        downloads.title = SCILocalized(@"set_downloads_title");
        downloads.rows = @[
            [SCIRow disclosureRow:SCILocalized(@"set_open_centre")
                           detail:nil
                           symbol:@"arrow.down.circle.fill"
                           action:^{ [SCIYTDownloadCenter present]; }],
            //
            // A disclosure that asks rather than a new cell type. This screen has switches and
            // disclosures; inventing a segmented row for three values would be more surface than
            // the question deserves, and the sheet can say what the trade is in a sentence.
            //
            [SCIRow disclosureRow:SCILocalized(@"set_parallel")
                           detail:SCILocalized(@"set_parallel_note")
                           symbol:@"arrow.down.to.line"
                           action:^{ [SCIYTDownloadsPage askForParallel]; }],
            //
            // The two ways a save starts, next to each other on purpose: they are one
            // decision seen from two sides, and a screen that puts them apart is a screen
            // where somebody turns both on and then wonders why holding the video still
            // opens a sheet.
            //
            [SCIRow switchRow:SCILocalized(@"set_native_download")
                       detail:SCILocalized(@"set_native_download_note")
                       symbol:@"arrow.down.circle"
                      prefKey:SCIPrefNativeDownload],
            [SCIRow switchRow:SCILocalized(@"set_hold_to_save")
                       detail:SCILocalized(@"set_hold_to_save_note")
                       symbol:@"hand.tap"
                      prefKey:SCIPrefHoldToSave],
            [SCIRow switchRow:SCILocalized(@"set_action_row")
                       detail:SCILocalized(@"set_action_row_note")
                       symbol:@"square.and.arrow.down.on.square"
                      prefKey:SCIPrefActionRowButton],
            [SCIRow switchRow:SCILocalized(@"set_pivot_bar")
                       detail:SCILocalized(@"set_pivot_bar_note")
                       symbol:@"rectangle.bottomthird.inset.filled"
                      prefKey:SCIPrefPivotBar],
            [SCIRow switchRow:SCILocalized(@"set_shorts_button")
                       detail:SCILocalized(@"set_shorts_button_note")
                       symbol:@"play.rectangle.on.rectangle"
                      prefKey:SCIPrefShortsButton],
            [SCIRow switchRow:SCILocalized(@"set_offer_4k")
                       detail:SCILocalized(@"set_offer_4k_note")
                       symbol:@"4k.tv"
                      prefKey:SCIPrefOffer4K],
            [SCIRow switchRow:SCILocalized(@"set_convert_av1")
                       detail:SCILocalized(@"set_convert_av1_note")
                       symbol:@"wand.and.rays"
                      prefKey:SCIPrefConvertAV1],
            [SCIRow switchRow:SCILocalized(@"set_auto_photos")
                       detail:SCILocalized(@"set_auto_photos_note")
                       symbol:@"photo.on.rectangle"
                      prefKey:SCIPrefAutoPhotos],
            [SCIRow switchRow:SCILocalized(@"set_finish_notice")
                       detail:SCILocalized(@"set_finish_notice_note")
                       symbol:@"bell.badge"
                      prefKey:SCIPrefFinishNotice],
            [SCIRow switchRow:SCILocalized(@"set_tidy_photos")
                       detail:SCILocalized(@"set_tidy_photos_note")
                       symbol:@"tray.and.arrow.up"
                      prefKey:SCIPrefTidyAfterPhotos],
            [SCIRow switchRow:SCILocalized(@"set_embed_artwork")
                       detail:SCILocalized(@"set_embed_artwork_note")
                       symbol:@"music.note.list"
                      prefKey:SCIPrefEmbedArtwork],
            [SCIRow switchRow:SCILocalized(@"set_lock_skip")
                       detail:SCILocalized(@"set_lock_skip_note")
                       symbol:@"lock.iphone"
                      prefKey:SCIPrefLockScreenSkip],
        ];
        return @[downloads];
    }];
}

@end
