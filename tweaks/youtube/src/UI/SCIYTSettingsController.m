#import "SCIYTSettingsController.h"
#import "SCIYTSubpageController.h"
#import "../Settings/SCIYTSettingsRegistry.h"
#import "../Tweak.h"
#import "../SCILog.h"
#import "../Localization/SCILocalize.h"
#import "../Diagnostics/SCIYTDiagnostics.h"
#import "SCIYTWindow.h"

@implementation SCIYTSettingsController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = SCILocalized(@"panel_title");
    self.tableView.tableHeaderView = [self identityHeader];

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose
                                                      target:self
                                                      action:@selector(close)];
}

///
/// One row per registered page, and no settings at all.
///
/// This screen held every section of every feature, which worked at four pages and stopped
/// working at nine: the answer to "where is that setting" became scrolling, and a setting
/// that has to be scrolled for is a setting nobody finds twice. Nothing here knows what any
/// page contains -- only what it is called.
///
- (void)buildSections {
    NSMutableArray<SCIRow *> *rows = [NSMutableArray array];

    // Weak, and this is not decoration. The rows are held by this controller, a row holds
    // its block, and a block capturing self strongly would close the loop -- the settings
    // screen would never be released, and neither would the pages it built.
    __weak __typeof(self) weakSelf = self;

    for (SCIYTPage *page in [SCIYTSettingsRegistry pages]) {
        // The page is captured, not its index: a block reading `pages[i]` at tap time would
        // read whatever the array holds then, which is a different page the moment anything
        // else registers one.
        [rows addObject:[SCIRow disclosureRow:page.title
                                       detail:page.detail
                                       symbol:page.symbol
                                       action:^{ [weakSelf openPage:page]; }]];
    }

    SCISection *index = [[SCISection alloc] init];
    index.rows = rows;
    index.footer = SCILocalized(@"panel_subtitle");

    self.sections = @[index];
}

- (void)openPage:(SCIYTPage *)page {
    SCIYTSubpageController *screen = [[SCIYTSubpageController alloc] initWithPage:page];

    // Pushed rather than presented, so the way back is the one iOS already put there and
    // every screen after this inherits it for free.
    [self.navigationController pushViewController:screen animated:YES];
}

///
/// The identity card, and it reports its own health.
///
/// The badge reads the runtime, not a constant: if the classes the features hook are not
/// there, it says so here, at the top, before anything else is read. Every earlier version
/// put that answer somewhere the user had to go looking for -- and in 0.1.0 it was behind
/// the very thing that had failed.
///
- (UIView *)identityHeader {
    UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 108)];

    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(20, 12, 0, 84)];
    card.backgroundColor = [SCIAccent() colorWithAlphaComponent:0.10];
    card.layer.borderColor = [SCIAccent() colorWithAlphaComponent:0.28].CGColor;
    card.layer.borderWidth = 0.5;
    card.layer.cornerRadius = 16;
    card.layer.cornerCurve = kCACornerCurveContinuous;

    // Sized by the autoresizing mask rather than by constraints. A table header is laid out
    // by the table, which sets its width and asks nothing else of it, so a mask is both
    // sufficient and impossible to over-constrain.
    card.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [host addSubview:card];

    UIView *badge = [[UIView alloc] initWithFrame:CGRectMake(14, 20, 44, 44)];
    badge.backgroundColor = SCIAccent();
    badge.layer.cornerRadius = 13;
    badge.layer.cornerCurve = kCACornerCurveContinuous;
    [card addSubview:badge];

    UIImageView *icon = [[UIImageView alloc] initWithFrame:CGRectMake(11, 11, 22, 22)];
    icon.image = [UIImage systemImageNamed:@"play.rectangle.fill"];
    icon.tintColor = UIColor.whiteColor;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [badge addSubview:icon];

    UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(70, 22, 200, 20)];
    name.text = SCILocalized(@"panel_title");
    name.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    name.textColor = UIColor.whiteColor;
    [card addSubview:name];

    UILabel *version = [[UILabel alloc] initWithFrame:CGRectMake(70, 42, 220, 18)];
    version.text = [NSString stringWithFormat:@"%@ · %@ %@",
        SCIVersionString, SCILocalized(@"diag_app_version"), [SCIYTDiagnostics appVersion]];
    version.font = [UIFont systemFontOfSize:12];
    version.textColor = [UIColor.whiteColor colorWithAlphaComponent:0.6];
    [card addSubview:version];

    BOOL healthy = [SCIYTDiagnostics featuresAttached];

    UILabel *status = [[UILabel alloc] initWithFrame:CGRectMake(70, 60, 220, 16)];
    status.text = healthy ? SCILocalized(@"identity_attached") : SCILocalized(@"identity_partial");
    status.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    status.textColor = healthy ? [UIColor colorWithRed:0.36 green:0.79 blue:0.65 alpha:1.0]
                              : [UIColor colorWithRed:0.94 green:0.62 blue:0.15 alpha:1.0];
    [card addSubview:status];

    return host;
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

// MARK: - Presentation

+ (UIViewController *)topMostController {
    return SCIYTTopViewController();
}

+ (void)present {
    UIViewController *host = [self topMostController];
    if (!host) {
        SCILogV(@"settings: nothing to present from");
        return;
    }

    if (host.isBeingPresented || host.isBeingDismissed) {
        SCILogV(@"settings: host is mid-transition, not presenting");
        return;
    }

    // The guard stays even though a table view is far less likely to throw than the
    // hand-built panel it replaces. It is not there because this code is expected to fail;
    // it is there because a tweak whose job is to report what is happening must never be the
    // reason the app stops.
    @try {
        SCIYTSettingsController *settings = [[SCIYTSettingsController alloc] init];
        UINavigationController *nav =
            [[UINavigationController alloc] initWithRootViewController:settings];

        nav.modalPresentationStyle = UIModalPresentationFullScreen;
        nav.navigationBar.barStyle = UIBarStyleBlack;
        nav.navigationBar.tintColor = SCIAccent();

        // Forced inside the guard, so a layout fault lands here rather than later inside
        // UIKit's transition where it would be out of reach.
        (void)settings.view;

        [host presentViewController:nav animated:YES completion:nil];
    } @catch (NSException *exception) {
        [SCIYTDiagnostics recordPanelFailure:
            [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]];

        NSLog(@"[AlbrhiYT] the settings screen could not be built: %@ — %@",
              exception.name, exception.reason);
    }
}

@end
