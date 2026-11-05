//
//  SCIYTCaptionSettings.m
//  Albrhi for YouTube
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCIYTCaptionSettings.h"
#import "SCIYTPlayer.h"
#import "../../../Tweak.h"
#import "../../../Prefs.h"
#import "../../../Localization/SCILocalize.h"

typedef NS_ENUM(NSInteger, SCICaptionSection) { SCICaptionSectionSize, SCICaptionSectionTiming, SCICaptionSectionSecond, SCICaptionSectionExport, SCICaptionSectionCount };

static const double kSCITimingStep = 0.5;

@interface SCIYTCaptionSettings ()
@property (nonatomic, copy) NSArray<NSDictionary *> *languages;
@property (nonatomic, strong) UILabel *timingValue;
@property (nonatomic, copy) NSString *exporting;     ///< the language being read for export, or nil
@end

@implementation SCIYTCaptionSettings

+ (void)presentFrom:(UIViewController *)presenter {
    SCIYTCaptionSettings *sheet = [[SCIYTCaptionSettings alloc] initWithStyle:UITableViewStyleInsetGrouped];
    UINavigationController *host = [[UINavigationController alloc] initWithRootViewController:sheet];
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *presentation = host.sheetPresentationController;
        presentation.detents = @[[UISheetPresentationControllerDetent mediumDetent], [UISheetPresentationControllerDetent largeDetent]];
        presentation.prefersGrabberVisible = YES;
    }
    [presenter presentViewController:host animated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = SCILocalized(@"cap_settings");
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(close)];
    self.languages = [SCIYTPlayer captionLanguages];
}

- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }

- (NSInteger)numberOfSectionsInTableView:(__unused UITableView *)tableView { return SCICaptionSectionCount; }

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == SCICaptionSectionExport) return (NSInteger)self.languages.count;
    if (section == SCICaptionSectionSecond) return (NSInteger)self.languages.count + 1;      // "Off" and each language
    return 1;
}

- (NSString *)tableView:(__unused UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case SCICaptionSectionSize: return SCILocalized(@"cap_size");
        case SCICaptionSectionTiming: return SCILocalized(@"cap_timing");
        case SCICaptionSectionSecond: return SCILocalized(@"cap_second");
        default: return SCILocalized(@"cap_export");
    }
}

- (NSString *)tableView:(__unused UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == SCICaptionSectionTiming) return SCILocalized(@"cap_timing_note");
    if (section == SCICaptionSectionSecond) return SCILocalized(@"cap_second_note");
    if (section == SCICaptionSectionExport) return SCILocalized(@"cap_export_note");
    return nil;
}

+ (NSArray<NSNumber *> *)scales { return @[@0.8, @1.0, @1.3, @1.7]; }

- (UIButton *)stepper:(NSString *)symbol action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal];
    button.tintColor = SCIAccent();
    button.frame = CGRectMake(0, 0, 44, 44);
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    if (path.section == SCICaptionSectionSize) {
        NSArray *names = @[SCILocalized(@"cap_size_small"), SCILocalized(@"cap_size_normal"),
                           SCILocalized(@"cap_size_large"), SCILocalized(@"cap_size_huge")];
        UISegmentedControl *control = [[UISegmentedControl alloc] initWithItems:names];
        double scale = [SCIYTPlayer captionScale];
        NSInteger chosen = 1;
        double best = 99;
        NSArray<NSNumber *> *scales = [SCIYTCaptionSettings scales];
        for (NSUInteger i = 0; i < scales.count; i++) {
            double gap = fabs(scales[i].doubleValue - scale);
            if (gap < best) { best = gap; chosen = (NSInteger)i; }
        }
        control.selectedSegmentIndex = chosen;
        control.selectedSegmentTintColor = SCIAccent();
        [control setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]} forState:UIControlStateSelected];
        [control addTarget:self action:@selector(sizeChanged:) forControlEvents:UIControlEventValueChanged];
        control.translatesAutoresizingMaskIntoConstraints = NO;
        [cell.contentView addSubview:control];
        [NSLayoutConstraint activateConstraints:@[
            [control.leadingAnchor constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.leadingAnchor],
            [control.trailingAnchor constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.trailingAnchor],
            [control.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:8],
            [control.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-8],
        ]];
        return cell;
    }

    if (path.section == SCICaptionSectionTiming) {
        UIButton *earlier = [self stepper:@"minus.circle.fill" action:@selector(earlier)];
        UIButton *later = [self stepper:@"plus.circle.fill" action:@selector(later)];
        self.timingValue = [[UILabel alloc] init];
        self.timingValue.font = [UIFont monospacedDigitSystemFontOfSize:20 weight:UIFontWeightSemibold];
        self.timingValue.textAlignment = NSTextAlignmentCenter;
        UIButton *reset = [UIButton buttonWithType:UIButtonTypeSystem];
        [reset setTitle:SCILocalized(@"cap_timing_reset") forState:UIControlStateNormal];
        reset.tintColor = SCIAccent();
        [reset addTarget:self action:@selector(resetTiming) forControlEvents:UIControlEventTouchUpInside];

        UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[earlier, self.timingValue, later, reset]];
        row.axis = UILayoutConstraintAxisHorizontal;
        row.alignment = UIStackViewAlignmentCenter;
        row.spacing = 8;
        row.translatesAutoresizingMaskIntoConstraints = NO;
        [self.timingValue.widthAnchor constraintGreaterThanOrEqualToConstant:90].active = YES;
        [cell.contentView addSubview:row];
        [NSLayoutConstraint activateConstraints:@[
            [row.leadingAnchor constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.leadingAnchor],
            [row.trailingAnchor constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.trailingAnchor],
            [row.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:6],
            [row.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-6],
        ]];
        [self showTiming];
        return cell;
    }

    if (path.section == SCICaptionSectionSecond) {
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        NSString *chosen = [SCIYTPlayer secondCaptionLanguage];
        if (path.row == 0) {
            cell.textLabel.text = SCILocalized(@"player_captions_off");
            cell.accessoryType = chosen.length ? UITableViewCellAccessoryNone : UITableViewCellAccessoryCheckmark;
        } else {
            NSDictionary *entry = self.languages[(NSUInteger)path.row - 1];
            cell.textLabel.text = entry[@"name"];
            cell.accessoryType = [entry[@"lang"] isEqualToString:chosen] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        }
        cell.tintColor = SCIAccent();
        return cell;
    }

    NSDictionary *language = self.languages[(NSUInteger)path.row];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.textLabel.text = [NSString stringWithFormat:SCILocalized(@"cap_export_lang"), language[@"name"]];
    cell.textLabel.textColor = SCIAccent();
    cell.imageView.image = [UIImage systemImageNamed:@"square.and.arrow.up"];
    cell.imageView.tintColor = SCIAccent();
    return cell;
}

- (void)showTiming {
    self.timingValue.text = [NSString stringWithFormat:@"%+.1f s", [SCIYTPlayer captionDelay]];
}

- (void)sizeChanged:(UISegmentedControl *)control {
    [SCIYTPlayer setCaptionScale:[SCIYTCaptionSettings scales][(NSUInteger)control.selectedSegmentIndex].doubleValue];
}

- (void)earlier { [SCIYTPlayer setCaptionDelay:[SCIYTPlayer captionDelay] - kSCITimingStep]; [self showTiming]; }
- (void)later { [SCIYTPlayer setCaptionDelay:[SCIYTPlayer captionDelay] + kSCITimingStep]; [self showTiming]; }
- (void)resetTiming { [SCIYTPlayer setCaptionDelay:0]; [self showTiming]; }

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    if (path.section == SCICaptionSectionSecond) {
        NSString *lang = path.row == 0 ? nil : self.languages[(NSUInteger)path.row - 1][@"lang"];
        [SCIYTPlayer setSecondCaptionLanguage:lang];
        [tableView reloadSections:[NSIndexSet indexSetWithIndex:SCICaptionSectionSecond] withRowAnimation:UITableViewRowAnimationNone];
        return;
    }
    if (path.section != SCICaptionSectionExport || self.exporting) return;
    NSDictionary *language = self.languages[(NSUInteger)path.row];
    self.exporting = language[@"lang"];
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:path];
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    [spinner startAnimating];
    cell.accessoryView = spinner;

    __weak __typeof(self) weakSelf = self;
    [SCIYTPlayer exportCaptionsFor:language[@"lang"] completion:^(NSURL *file, NSString *failure) {
        __typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.exporting = nil;
        cell.accessoryView = nil;
        if (!file) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                message:failure ?: SCILocalized(@"cap_unreadable") preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:SCILocalized(@"ok") style:UIAlertActionStyleDefault handler:nil]];
            [strongSelf presentViewController:alert animated:YES completion:nil];
            return;
        }
        UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:@[file] applicationActivities:nil];
        share.popoverPresentationController.sourceView = cell;
        [strongSelf presentViewController:share animated:YES completion:nil];
    }];
}

@end
