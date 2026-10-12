#import "../Model/SCITWPageRegistry.h"
#import "../SCITWKeysList.h"
#import "Features/Switches/SCITWSwitches.h"
#import "Diagnostics/SCITWReport.h"
#import "Prefs.h"
#import "Localization/SCILocalize.h"
#import "shared/src/SCIPanelGate.h"

///
/// Advanced, and last on purpose.
///
/// The switch layer, the raw key list, the counters and the log switch are four different
/// audiences from every section above: somebody diagnosing a problem, not somebody choosing
/// what X looks like. Fourteen diagnostic rows interleaved with the switches is two screens
/// pretending to be one -- the TikTok settings screen shipped exactly that and it was the
/// first thing reported about it.
///
@interface SCITWPageAdvanced : NSObject
@end

@implementation SCITWPageAdvanced

+ (void)load {
    [SCITWPageRegistry registerPageWithOrder:90
                                   title:SCILocalized(@"section_advanced")
                                    note:SCILocalized(@"page_advanced_note")
                                  symbol:@"wrench.and.screwdriver.fill"
                                    tint:[UIColor systemGrayColor]
                                 builder:^NSArray<SCITWSection *> *(UIViewController *host) {
        __weak UIViewController *weakHost = host;

        // The switch layer itself is not here any more -- it heads the screen, in
        // SCITWPageLayer. What is left is the two things you reach *because* of it: the
        // raw key list, and the log.
        SCITWSection *layer =
            [SCITWSection titled:SCILocalized(@"section_advanced")
                          footer:nil
                            rows:@[
                [SCITWRow actionRow:SCILocalized(@"keys_link_title")
                               note:SCILocalized(@"keys_footer")
                             symbol:@"key.fill"
                               tint:[UIColor systemTealColor]
                             action:^{
                    UIViewController *strongHost = weakHost;
                    if (!strongHost.navigationController) return;
                    [strongHost.navigationController pushViewController:[[SCITWKeysList alloc] init]
                                                               animated:YES];
                }],
                [SCITWRow switchRow:SCILocalized(@"albrhi_logging")
                               note:SCILocalized(@"albrhi_logging_note")
                             symbol:@"doc.text.magnifyingglass"
                               tint:[UIColor systemGrayColor]
                            prefKey:SCIPrefVerboseLogging],
            ]];

        // Read at draw time rather than captured when the screen was built, so a number
        // that moved while somebody was reading is the number they see on the next reload.
        SCITWSection *status =
            [SCITWSection titled:SCILocalized(@"section_status")
                          footer:nil
                            rows:@[
                [SCITWRow infoRow:SCILocalized(@"status_gate") value:^NSString *{
                    return SCIPanelAllowsThisApp() ? SCILocalized(@"gate_on")
                                                   : SCILocalized(@"gate_off");
                }],
                [SCITWRow infoRow:SCILocalized(@"status_providers") value:^NSString *{
                    NSUInteger count = [SCITWSwitches attachedProviders].count;
                    return count ? [NSString stringWithFormat:@"%lu", (unsigned long)count]
                                 : SCILocalized(@"status_providers_none");
                }],
                [SCITWRow infoRow:SCILocalized(@"status_keys") value:^NSString *{
                    return [NSString stringWithFormat:@"%lu",
                            (unsigned long)[SCITWSwitches records].count];
                }],
                [SCITWRow infoRow:SCILocalized(@"status_asked") value:^NSString *{
                    return [NSString stringWithFormat:@"%lu",
                            (unsigned long)[SCITWSwitches totalAsked]];
                }],
            ]];

        return @[layer, status];
    }];
}

@end
