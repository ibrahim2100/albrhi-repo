#import "SCITTReport.h"
#import "SCITTBadge.h"
#import "../Tweak.h"
#import "../Prefs.h"
#import "../Localization/SCILocalize.h"
#import "../Diagnostics/SCITTDiagnostics.h"
#import "../Features/Extras/SCITTExtras.h"
#import "../Features/Region/SCITTRegion.h"
#import "../Features/Profile/SCITTProfileBackground.h"
#import "../Features/Speed/SCITTSpeed.h"
#import "../Features/Lock/SCITTAppLock.h"
#import "../Features/Feed/SCITTFeedFilters.h"
#import "../Features/Messages/SCITTReadAlert.h"
#import "SCITTSettingsEntry.h"
#import "SCITTRowIcon.h"
#import "../Features/Download/SCITTMedia.h"
#import "../Features/Download/SCITTWatermark.h"
#import "../Features/Download/SCITTPlaybackProbe.h"
#import "../Features/Download/SCITTDownload.h"
#import "../Features/Download/SCITTButton.h"
#import "../Features/Interface/SCITTProgressBar.h"
#import "../Features/Confirm/SCITTConfirm.h"

///
/// **The screen and the copied text are built from one list now, and that is the whole point of
/// this file's shape.** CLAUDE.md records what the alternative cost: the gear ladder was added to
/// the table, the user was asked to send that row, and the report they sent had never contained it
/// -- a whole round trip spent on a row that did not exist where it was being looked for. Two
/// methods building two lists cannot be kept in step by discipline; one list read twice can never
/// drift at all.
///
/// So `+sections` is the only place a row is named, and both the table and `+reportText` walk it.
///

static NSString *const kSCIRowTitle = @"title";
static NSString *const kSCIRowValue = @"value";
static NSString *const kSCIRowIcon = @"icon";
static NSString *const kSCIRowColor = @"color";

///
/// A row whose value is a runtime dump rather than a finding.
///
/// **Three of these rows answered their question and then kept answering it.** The feed cell's
/// accessor list is what proved that cell has no aweme accessor at all; `AWEVideoModel`'s is where
/// `downloadNoWatermarkURL` was found. Both are settled, and both are still several thousand
/// characters that every report has to carry — three reports in a row arrived as walls of text
/// with the four lines that mattered buried inside them.
///
/// A diagnostic that is too heavy to read has stopped being a diagnostic. So a heavy row shows how
/// much it holds and stays out of the ordinary report; **Copy everything** puts the whole thing on
/// the pasteboard for the day a class list is the question again.
///
static NSString *const kSCIRowHeavy = @"heavy";
static NSString *const kSCISectionTitle = @"section";
static NSString *const kSCISectionRows = @"rows";

@interface SCITTReport ()
/// The sections as they were when this screen was last refreshed.
///
/// Not rebuilt per cell: a row here can dump a whole class's method list off the live runtime, and
/// `-tableView:cellForRowAtIndexPath:` runs several times per scroll. Building it once per refresh
/// is also the honest reading -- every row on screen then belongs to one moment, rather than each
/// row being a measurement taken whenever iOS happened to ask for it.
@property (nonatomic, strong) NSArray<NSDictionary *> *snapshot;
@end

@implementation SCITTReport

static NSDictionary *SCIRow(NSString *title, NSString *value, NSString *icon, UIColor *color) {
    return @{
        kSCIRowTitle: title ?: @"?",
        // A row whose value is nil is a row whose feature never reported, and the screen should
        // say so in words rather than showing a blank line that reads as "nothing is wrong".
        kSCIRowValue: value ?: @"—",
        kSCIRowIcon: icon ?: @"circle",
        kSCIRowColor: color ?: [UIColor systemGrayColor],
    };
}

static NSDictionary *SCIHeavyRow(NSString *title, NSString *value, NSString *icon, UIColor *color) {
    NSMutableDictionary *row = [SCIRow(title, value, icon, color) mutableCopy];
    row[kSCIRowHeavy] = @YES;
    return row;
}

/// Read live, every time, so nothing on this screen can be a value from an earlier launch.
+ (NSArray<NSDictionary *> *)sections {
    return @[
        @{
            kSCISectionTitle: SCILocalized(@"section_overview"),
            kSCISectionRows: @[
                SCIRow(SCILocalized(@"status_gate"),
                       SCIPanelAllowsThisApp() ? SCILocalized(@"gate_on") : SCILocalized(@"gate_off"),
                       @"switch.2", [UIColor systemGrayColor]),
                SCIRow(SCILocalized(@"diag_ads"), [SCITTDiagnostics adFilterState],
                       @"nosign", [UIColor systemRedColor]),
                SCIRow(SCILocalized(@"status_button"), SCITTButtonReport(),
                       @"arrow.down.circle.fill", SCIAccent()),
                SCIRow(SCILocalized(@"status_download"), SCITTDownloadReport(),
                       @"square.and.arrow.down", SCIAccent()),
                SCIRow(SCILocalized(@"status_progress_bar"), SCITTProgressBarReport(),
                       @"slider.horizontal.below.rectangle", [UIColor systemBlueColor]),
                SCIRow(SCILocalized(@"status_confirm"), SCITTConfirmReport(),
                       @"hand.raised.fill", [UIColor systemRedColor]),
            ],
        },
        @{
            // The quality rows, together, because that is how they answer anything: a gear list
            // says what was offered, the byte counts say what the links actually weigh, and the
            // player's own signature says whether the two lists are even the same ladder.
            kSCISectionTitle: SCILocalized(@"section_quality"),
            kSCISectionRows: @[
                SCIRow(SCILocalized(@"status_gears"), [SCITTMedia gearLadder],
                       @"square.stack.3d.up", [UIColor systemOrangeColor]),
                SCIRow(SCILocalized(@"status_measured"), SCITTMeasuredReport(),
                       @"ruler", [UIColor systemGreenColor]),
                SCIRow(SCILocalized(@"status_video_date"), SCITTDateReport(),
                       @"calendar", [UIColor systemIndigoColor]),
                SCIRow(SCILocalized(@"status_extras"), SCITTExtrasReport(),
                       @"square.grid.2x2", [UIColor systemIndigoColor]),
                SCIRow(SCILocalized(@"status_region"), SCITTRegionReport(),
                       @"globe", [UIColor systemTealColor]),
                SCIRow(SCILocalized(@"status_profile_bg"), SCITTProfileBackgroundReport(),
                       @"photo.on.rectangle", [UIColor systemTealColor]),
                SCIRow(SCILocalized(@"status_speed"), SCITTSpeedReport(),
                       @"speedometer", [UIColor systemIndigoColor]),
                SCIRow(SCILocalized(@"status_lock"), SCITTAppLockReport(),
                       @"lock.fill", [UIColor systemIndigoColor]),
                SCIRow(SCILocalized(@"status_feed_filters"), SCITTFeedFiltersReport(),
                       @"line.3.horizontal.decrease.circle", [UIColor systemRedColor]),
                SCIRow(SCILocalized(@"status_read_alert"), SCITTReadAlertReport(),
                       @"bell.badge.fill", [UIColor systemTealColor]),
                SCIRow(SCILocalized(@"status_settings_entry"), SCITTSettingsEntryReport(),
                       @"gearshape.fill", [UIColor systemGrayColor]),
                SCIRow(SCILocalized(@"status_watermark"), SCITTWatermarkReport(),
                       @"drop.fill", [UIColor systemCyanColor]),
                SCIRow(SCILocalized(@"status_playback"), SCITTPlaybackReport(),
                       @"waveform", [UIColor systemPurpleColor]),
            ],
        },
        @{
            kSCISectionTitle: SCILocalized(@"section_resolution"),
            kSCISectionRows: @[
                SCIRow(SCILocalized(@"status_media_resolve"), [SCITTMedia lastAttemptState],
                       @"link", [UIColor systemPurpleColor]),
                // The photo chain, step by step. "saved 1 of 1" on a post of several is two
                // different bugs -- a short list, or a list whose entries lost their links -- and a
                // count of what was saved cannot tell them apart.
                SCIRow(SCILocalized(@"status_photos"), [SCITTMedia photoReport],
                       @"photo.stack", [UIColor systemPinkColor]),
                // Unfiltered on purpose. The filter here used to be model/aweme/item/data, and
                // what came back was every UIKit and accessibility category containing "item" or
                // "data" and nothing about a video -- which was itself the finding: this cell has
                // no aweme accessor of its own. A filter built from the names I expected is the
                // last thing that will show me the one I did not.
                SCIHeavyRow(SCILocalized(@"status_cell_accessors"),
                       [SCITTMedia accessorsOnClassNamed:@"AWEFeedViewTemplateCell" matching:@[]],
                       @"rectangle.on.rectangle", [UIColor systemPurpleColor]),
                SCIHeavyRow(SCILocalized(@"status_media_candidates"),
                       [SCITTMedia candidateAccessorsOnAwemeModel],
                       @"magnifyingglass", [UIColor systemPurpleColor]),
                // The video model's own accessors, asked of the device rather than guessed from a
                // framework-wide selector dump -- which says a name exists and never says on what
                // class. Three releases here went to exactly that gap.
                SCIHeavyRow(SCILocalized(@"status_video_accessors"),
                       [SCITTMedia accessorsOnClassNamed:@"AWEVideoModel"
                                                matching:@[@"url", @"URL", @"addr", @"Addr",
                                                           @"bitrate", @"bitRate", @"uri", @"URI",
                                                           @"play", @"download"]],
                       @"film", [UIColor systemPurpleColor]),
            ],
        },
        @{
            kSCISectionTitle: SCILocalized(@"section_protection"),
            kSCISectionRows: @[
                SCIRow(SCILocalized(@"diag_bypass"), [SCITTDiagnostics bypassState],
                       @"shield.lefthalf.filled", [UIColor systemIndigoColor]),
                SCIRow(SCILocalized(@"diag_privacy"), [SCITTDiagnostics privacyState],
                       @"eye.slash.fill", [UIColor systemTealColor]),
            ],
        },
    ];
}

+ (NSString *)reportText {
    NSMutableString *report = [NSMutableString string];
    [report appendFormat:@"Albrhi for TikTok %@\n", SCIVersionString];
    [report appendFormat:@"app %@\n",
        [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"?"];

    NSUInteger skipped = 0;
    for (NSDictionary *section in [self sections]) {
        [report appendFormat:@"\n== %@ ==\n", section[kSCISectionTitle]];
        for (NSDictionary *row in section[kSCISectionRows]) {
            if ([row[kSCIRowHeavy] boolValue]) { skipped++; continue; }
            [report appendFormat:@"%@: %@\n", row[kSCIRowTitle], row[kSCIRowValue]];
        }
    }

    // Named, not silently dropped: a report that quietly omits something is worse than a long
    // one, because the next person reads its absence as "this build has nothing to say there".
    if (skipped) {
        [report appendFormat:@"\n(%lu class dump(s) left out — Copy everything includes them)\n",
            (unsigned long)skipped];
    }

    return report;
}

/// Everything, class dumps included. What the second Copy button sends.
+ (NSString *)fullReportText {
    NSMutableString *report = [NSMutableString stringWithString:[self reportText]];

    for (NSDictionary *section in [self sections]) {
        for (NSDictionary *row in section[kSCISectionRows]) {
            if (![row[kSCIRowHeavy] boolValue]) continue;
            [report appendFormat:@"\n== %@ ==\n%@\n", row[kSCIRowTitle], row[kSCIRowValue]];
        }
    }

    return report;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = SCILocalized(@"report_title");
    // Two, because they answer two different requests: "send me the report" and "send me the
    // class list too". One button doing both would put four thousand characters of method names
    // into every ordinary report, which is what this release is undoing.
    self.navigationItem.rightBarButtonItems = @[
        [[UIBarButtonItem alloc] initWithTitle:SCILocalized(@"copy_report")
                                         style:UIBarButtonItemStyleDone
                                        target:self
                                        action:@selector(copyReport)],
        [[UIBarButtonItem alloc] initWithTitle:SCILocalized(@"copy_report_all")
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(copyFullReport)],
    ];

    // Every value here is a dynamically-built string -- a comma list of hooks, a whole gear
    // ladder, a class's method list -- so a fixed row height draws the wrapped lines on top of
    // the row below rather than pushing it down. That was a real reported bug on this tweak's
    // own settings screen, and it is the same table style.
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 72;
    self.tableView.sectionHeaderTopPadding = 0;

    UIRefreshControl *refresh = [[UIRefreshControl alloc] init];
    [refresh addTarget:self action:@selector(pulled) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = refresh;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // Rebuilt on every appearance: the numbers move while the app is being used, and a screen
    // showing what they were when it was first opened is the snapshot-versus-tally trap again.
    [self refresh];
}

- (void)refresh {
    self.snapshot = [SCITTReport sections];
    [self.tableView reloadData];
}

- (void)pulled {
    [self refresh];
    [self.refreshControl endRefreshing];
}

- (void)copyFullReport {
    [UIPasteboard generalPasteboard].string = [SCITTReport fullReportText];
    [self confirmCopied];
}

- (void)copyReport {
    [UIPasteboard generalPasteboard].string = [SCITTReport reportText];
    [self confirmCopied];
}

- (void)confirmCopied {

    UIImpactFeedbackGenerator *haptic =
        [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [haptic impactOccurred];

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:nil
                                           message:SCILocalized(@"report_copied")
                                    preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alert animated:YES completion:nil];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.9 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [alert dismissViewControllerAnimated:YES completion:nil];
    });
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (NSInteger)self.snapshot.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section < 0 || section >= (NSInteger)self.snapshot.count) return 0;
    return (NSInteger)[self.snapshot[(NSUInteger)section][kSCISectionRows] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section < 0 || section >= (NSInteger)self.snapshot.count) return nil;
    return self.snapshot[(NSUInteger)section][kSCISectionTitle];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    // Subtitle rather than Value1: Value1 puts its two labels side by side on one line by design,
    // and a value here can be several hundred characters with nowhere to wrap to except over the
    // title beside it.
    UITableViewCell *cell =
        [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    if (indexPath.section >= (NSInteger)self.snapshot.count) return cell;
    NSArray *rows = self.snapshot[(NSUInteger)indexPath.section][kSCISectionRows];
    if (indexPath.row >= (NSInteger)rows.count) return cell;

    NSDictionary *row = rows[(NSUInteger)indexPath.row];

    // A heavy row is summarised on screen. Its value is a class's whole method list -- drawing it
    // makes the screen unscrollable and tells nobody anything; the count is the part a person can
    // act on, and Copy everything is where the list itself lives.
    NSString *value = row[kSCIRowValue];
    if ([row[kSCIRowHeavy] boolValue]) {
        NSUInteger count = [[value componentsSeparatedByString:@", "] count];
        value = [NSString stringWithFormat:SCILocalized(@"status_heavy_summary"),
                 (unsigned long)count];
    }

    cell.textLabel.text = row[kSCIRowTitle];
    cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    cell.detailTextLabel.text = value;
    cell.detailTextLabel.numberOfLines = 0;
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    cell.imageView.image = SCITTRowIcon(row[kSCIRowIcon]);
    cell.imageView.tintColor = [UIColor labelColor];

    return cell;
}

@end
