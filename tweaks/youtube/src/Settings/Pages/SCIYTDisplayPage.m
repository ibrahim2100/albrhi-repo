#import "../SCIYTSettingsRegistry.h"
#import "../../Prefs.h"
#import "../../Localization/SCILocalize.h"
#import "../../Features/Display/SCIYTDimmer.h"

///
/// The screen: which way round it goes, and how bright it is.
///
/// One page for two features that have nothing in common in the code and everything in
/// common on the phone — both are about the thing you are looking at rather than about the
/// video, and looking for either of them anywhere else would be looking in the wrong place.
///
@interface SCIYTDisplayPage : NSObject
@end


#pragma mark - Asking for a time

///
/// A clock face and a Done button.
///
/// A picker rather than a list of hours: a schedule offered in whole hours is a schedule
/// that cannot say half past ten, and a list long enough to say it is a list nobody wants to
/// scroll. UIDatePicker is the control iOS users already know how to use for exactly this.
///
@interface SCIYTTimeSheet : UIViewController
@property (nonatomic, strong) UIDatePicker *picker;
@property (nonatomic, copy) void (^onDone)(NSInteger minuteOfDay);
@end

@implementation SCIYTTimeSheet

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.picker = [[UIDatePicker alloc] init];
    self.picker.datePickerMode = UIDatePickerModeTime;
    self.picker.preferredDatePickerStyle = UIDatePickerStyleWheels;
    self.picker.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.picker];

    UIButton *done = [UIButton buttonWithType:UIButtonTypeSystem];
    [done setTitle:SCILocalized(@"done") forState:UIControlStateNormal];
    done.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    done.translatesAutoresizingMaskIntoConstraints = NO;
    [done addTarget:self action:@selector(finish) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:done];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.picker.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.picker.topAnchor constraintEqualToAnchor:safe.topAnchor constant:24],
        [done.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [done.topAnchor constraintEqualToAnchor:self.picker.bottomAnchor constant:8],
    ]];
}

- (void)finish {
    NSDateComponents *parts =
        [[NSCalendar currentCalendar] components:(NSCalendarUnitHour | NSCalendarUnitMinute)
                                        fromDate:self.picker.date];

    // Read before dismissing, not inside the completion: the picker is this controller's
    // subview and the controller is what is being torn down.
    NSInteger minute = parts.hour * 60 + parts.minute;

    void (^done)(NSInteger) = self.onDone;
    [self dismissViewControllerAnimated:YES completion:^{
        if (done) done(minute);
    }];
}

@end


#pragma mark - Reading and writing those minutes

/// Minutes since midnight, shown the way the phone shows a time.
///
/// Stored as a number of minutes rather than as a string, so it cannot be misread in another
/// locale, and formatted here so a 12-hour phone sees a 12-hour clock.
static NSString *SCITimeLabel(NSInteger minuteOfDay) {
    NSDateComponents *parts = [[NSDateComponents alloc] init];
    parts.hour = minuteOfDay / 60;
    parts.minute = minuteOfDay % 60;

    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *date = [calendar dateFromComponents:parts];
    if (!date) return @"--:--";

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.timeStyle = NSDateFormatterShortStyle;
    formatter.dateStyle = NSDateFormatterNoStyle;
    return [formatter stringFromDate:date];
}

static void SCIAskForTime(SCIYTSettingsHostController *host, NSString *key) {
    if (!host) return;

    SCIYTTimeSheet *sheet = [[SCIYTTimeSheet alloc] init];
    sheet.modalPresentationStyle = UIModalPresentationPageSheet;

    if (@available(iOS 15.0, *)) {
        sheet.sheetPresentationController.detents = @[[UISheetPresentationControllerDetent mediumDetent]];
        sheet.sheetPresentationController.prefersGrabberVisible = YES;
    }

    sheet.onDone = ^(NSInteger minuteOfDay) {
        [[NSUserDefaults standardUserDefaults] setInteger:minuteOfDay forKey:key];

        // Rebuilt, because the row's subtitle is the time it just set.
        [host reloadSettings];

        // And applied at once: a schedule whose effect waits for the next minute is a
        // schedule nobody can tell they configured correctly.
        [SCIYTDimmer refresh];
    };

    [host presentViewController:sheet animated:YES completion:^{
        // Set after presenting, when the picker exists. Doing it before means writing to a
        // view -viewDidLoad has not made yet, which silently does nothing.
        NSDateComponents *parts = [[NSDateComponents alloc] init];
        NSInteger stored = SCIPrefNumber(key);
        parts.hour = stored / 60;
        parts.minute = stored % 60;

        NSDate *date = [[NSCalendar currentCalendar] dateFromComponents:parts];
        if (date) sheet.picker.date = date;
    }];
}


#pragma mark - Asking for a direction, and a level

static NSString *SCIDirectionLabel(NSInteger direction) {
    switch (direction) {
        case 1:  return SCILocalized(@"fullscreen_left");
        case 2:  return SCILocalized(@"fullscreen_right");
        case 3:  return SCILocalized(@"fullscreen_portrait");
        default: return SCILocalized(@"fullscreen_off");
    }
}

/// Points the sheet at something. Required on iPad and harmless on a phone — without it
/// UIKit raises rather than guessing where the popover came from.
static void SCIAnchor(UIAlertController *sheet, SCIYTSettingsHostController *host) {
    sheet.popoverPresentationController.sourceView = host.view;
    sheet.popoverPresentationController.sourceRect =
        CGRectMake(CGRectGetMidX(host.view.bounds), CGRectGetMidY(host.view.bounds), 0, 0);
}

static void SCIAskForDirection(SCIYTSettingsHostController *host, NSString *key) {
    if (!host) return;

    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:nil
                                            message:SCILocalized(@"fullscreen_note")
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSNumber *direction in @[@0, @1, @2, @3]) {
        [sheet addAction:[UIAlertAction actionWithTitle:SCIDirectionLabel(direction.integerValue)
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            [[NSUserDefaults standardUserDefaults] setInteger:direction.integerValue forKey:key];
            [host reloadSettings];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    SCIAnchor(sheet, host);
    [host presentViewController:sheet animated:YES completion:nil];
}

/// The levels offered. Stopping at 80 rather than at the 85 the dimmer allows, so the
/// picker never offers the edge of what is usable.
static NSArray<NSNumber *> *SCIDimLevels(void) {
    return @[@20, @30, @40, @50, @60, @70, @80];
}

static NSString *SCIDimLabel(NSInteger level) {
    if (level <= 0) return SCILocalized(@"dim_level_none");
    return [NSString stringWithFormat:SCILocalized(@"dim_level_format"), (long)level];
}

static void SCIAskForLevel(SCIYTSettingsHostController *host) {
    if (!host) return;

    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:nil
                                            message:SCILocalized(@"dim_level_note")
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSNumber *level in SCIDimLevels()) {
        [sheet addAction:[UIAlertAction actionWithTitle:SCIDimLabel(level.integerValue)
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            [[NSUserDefaults standardUserDefaults] setInteger:level.integerValue
                                                       forKey:SCIPrefDimLevel];
            [host reloadSettings];
            [SCIYTDimmer refresh];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    SCIAnchor(sheet, host);
    [host presentViewController:sheet animated:YES completion:nil];
}


#pragma mark - The page

@implementation SCIYTDisplayPage

+ (void)load {
    [SCIYTSettingsRegistry registerPageWithOrder:30
                                        title:SCILocalized(@"page_display")
                                       detail:SCILocalized(@"page_display_note")
                                       symbol:@"iphone.gen3"
                                      builder:^NSArray<SCISection *> *(SCIYTSettingsHostController *host) {
        SCISection *fullscreen = [[SCISection alloc] init];
        fullscreen.title = SCILocalized(@"section_fullscreen");
        fullscreen.footer = SCILocalized(@"fullscreen_footer");
        fullscreen.rows = @[
            [SCIRow disclosureRow:SCILocalized(@"fullscreen_button")
                           detail:SCIDirectionLabel(SCIPrefNumber(SCIPrefFullscreenButton))
                           symbol:@"arrow.up.left.and.arrow.down.right"
                           action:^{ SCIAskForDirection(host, SCIPrefFullscreenButton); }],
            [SCIRow disclosureRow:SCILocalized(@"fullscreen_swipe")
                           detail:SCIDirectionLabel(SCIPrefNumber(SCIPrefFullscreenSwipe))
                           symbol:@"hand.draw"
                           action:^{ SCIAskForDirection(host, SCIPrefFullscreenSwipe); }],
        ];

        SCISection *brightness = [[SCISection alloc] init];
        brightness.title = SCILocalized(@"section_brightness");
        brightness.footer = SCILocalized(@"dim_footer");
        brightness.rows = @[
            [SCIRow switchRow:SCILocalized(@"dim_enabled")
                       detail:SCILocalized(@"dim_enabled_note")
                       symbol:@"moon.fill"
                      prefKey:SCIPrefDimEnabled],
            [SCIRow disclosureRow:SCILocalized(@"dim_level")
                           detail:SCIDimLabel(SCIPrefNumber(SCIPrefDimLevel))
                           symbol:@"sun.min"
                           action:^{ SCIAskForLevel(host); }],
        ];

        SCISection *night = [[SCISection alloc] init];
        night.title = SCILocalized(@"section_night");
        night.footer = SCILocalized(@"night_footer");
        night.rows = @[
            [SCIRow switchRow:SCILocalized(@"night_schedule")
                       detail:SCILocalized(@"night_schedule_note")
                       symbol:@"clock"
                      prefKey:SCIPrefNightSchedule],
            [SCIRow disclosureRow:SCILocalized(@"night_from")
                           detail:SCITimeLabel(SCIPrefNumber(SCIPrefNightStart))
                           symbol:@"moon.stars"
                           action:^{ SCIAskForTime(host, SCIPrefNightStart); }],
            [SCIRow disclosureRow:SCILocalized(@"night_to")
                           detail:SCITimeLabel(SCIPrefNumber(SCIPrefNightEnd))
                           symbol:@"sunrise"
                           action:^{ SCIAskForTime(host, SCIPrefNightEnd); }],
        ];

        return @[fullscreen, brightness, night];
    }];
}

@end
