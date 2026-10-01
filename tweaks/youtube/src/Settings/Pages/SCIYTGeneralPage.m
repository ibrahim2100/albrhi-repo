#import "../SCIYTSettingsRegistry.h"
#import "../../Prefs.h"
#import "../../SCILog.h"
#import "../../Localization/SCILocalize.h"
#import "../../Diagnostics/SCIYTDiagnostics.h"
#import "shared/src/SCILicenseUI.h"
#import "../../Tweak.h"

///
/// General: the few things that are not about any one feature, the tools for when something is
/// wrong, and who made this.
///
/// Last by design. This is the section someone reaches by scrolling past everything they
/// came for. It absorbed the About page (three rows, two of them text) and the second
/// "Licence" row that page carried -- one licence row, here -- and gave "Save this video" to
/// Downloads, where somebody looking for it would look.
///
@interface SCIYTGeneralPage : NSObject
@end

/// Opens the report, or says where it is if the page will not build.
///
/// Wrapped for the same reason the panel itself is: this page reads objects YouTube gave us
/// and prints them, and it went unguarded while the panel around it was protected. The
/// report is on disk either way, which is the point of writing it there.
static void SCIOpenDiagnostics(SCIYTSettingsHostController *host) {
    if (!host) return;

    UIViewController *page = nil;

    @try {
        page = [SCIYTDiagnostics viewController];
    } @catch (NSException *exception) {
        [SCIYTDiagnostics recordPanelFailure:
            [NSString stringWithFormat:@"diagnostics page: %@", exception.reason]];
        SCILogV(@"diagnostics page could not be built: %@", exception.reason);
    }

    if (page) {
        [host.navigationController pushViewController:page animated:YES];
        return;
    }

    // Says where the report is rather than failing silently -- the file is the way out when
    // the page is not.
    NSString *path = [SCIYTDiagnostics writeReportToFile];

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:SCILocalized(@"diag_title")
                         message:[NSString stringWithFormat:SCILocalized(@"diag_page_failed"),
                                  path ?: @"Documents/AlbrhiYT-report.txt"]
                  preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:SCILocalized(@"ok")
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [host presentViewController:alert animated:YES completion:nil];
}

@implementation SCIYTGeneralPage

+ (void)load {
    [SCIYTSettingsRegistry registerPageWithOrder:90
                                        title:SCILocalized(@"page_general")
                                       detail:SCILocalized(@"page_general_note")
                                       symbol:@"gearshape.fill"
                                      builder:^NSArray<SCISection *> *(SCIYTSettingsHostController *host) {
        SCISection *general = [[SCISection alloc] init];
        general.title = SCILocalized(@"section_general");
        general.rows = @[
            // **The licence, inside the app.**
            //
            // Albrhi Panel's licence page exists only where PreferenceLoader does. A tweak
            // installed on its own -- and above all one injected into an IPA on a phone with no
            // jailbreak -- has no panel, no Settings row, and until this had no way to enter a
            // key at all. That is what let a self-contained build ship ungated: there was nowhere
            // to say no from.
            [SCIRow disclosureRow:SCILocalized(@"licence_row")
                           detail:SCILocalized(@"licence_row_note")
                           symbol:@"key.fill"
                           action:^{ [SCILicenseUI presentFrom:host]; }],
        ];

        SCISection *tools = [[SCISection alloc] init];
        tools.title = SCILocalized(@"section_tools");
        tools.footer = SCILocalized(@"section_tools_note");
        tools.rows = @[
            [SCIRow disclosureRow:SCILocalized(@"diagnostics")
                           detail:SCILocalized(@"diagnostics_note")
                           symbol:@"stethoscope"
                           action:^{ SCIOpenDiagnostics(host); }],
            [SCIRow disclosureRow:SCILocalized(@"scan_watch")
                           detail:SCILocalized(@"scan_watch_note")
                           symbol:@"viewfinder"
                           action:^{
                               [SCIYTDiagnostics requestWatchScan];

                               // Said plainly, because a scan that writes into a page you are
                               // not looking at is indistinguishable from a row that does
                               // nothing -- which is a mistake this project has made twice on
                               // two different apps.
                               UIAlertController *done = [UIAlertController
                                   alertControllerWithTitle:nil
                                                    message:SCILocalized(@"scan_done")
                                             preferredStyle:UIAlertControllerStyleAlert];
                               [done addAction:[UIAlertAction
                                   actionWithTitle:SCILocalized(@"ok")
                                             style:UIAlertActionStyleDefault
                                           handler:nil]];
                               [host presentViewController:done animated:YES completion:nil];
                           }],
            [SCIRow switchRow:SCILocalized(@"verbose_logging")
                       detail:SCILocalized(@"verbose_logging_note")
                       symbol:@"text.alignleft"
                      prefKey:SCIPrefVerboseLogging],
        ];

        // Who made it, under what licence. Here because the licence requires it and because a
        // tweak that talks to an outside service should say so where a user can find it; the
        // SponsorBlock credit also sits beside the switch that turns it on.
        SCISection *about = [[SCISection alloc] init];
        about.title = SCILocalized(@"about_title");
        about.rows = @[
            [SCIRow disclosureRow:SCILocalized(@"about_author")
                           detail:SCILocalized(@"about_author_note")
                           symbol:@"person.fill"
                           action:^{ }],
            [SCIRow disclosureRow:SCILocalized(@"about_version")
                           detail:SCIVersionString
                           symbol:@"number"
                           action:^{ }],
            [SCIRow disclosureRow:SCILocalized(@"about_licence")
                           detail:SCILocalized(@"about_licence_note")
                           symbol:@"doc.text"
                           action:^{ }],
        ];
        // The source, because GPLv3 requires it to be offered; and how to get back here -- a
        // two-finger long press is safe and reliable and completely undiscoverable.
        about.footer = [NSString stringWithFormat:@"%@\n\n%@",
                        SCILocalized(@"about_footer"), SCILocalized(@"panel_subtitle")];

        return @[general, tools, about];
    }];
}

@end
