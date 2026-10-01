#import "SCIYTChecklistRow.h"
#import "../Prefs.h"
#import "../Localization/SCILocalize.h"
#import "../UI/SCIYTSubpageController.h"

@implementation SCIRow (Checklist)

+ (instancetype)checklistRow:(NSString *)title
                      symbol:(NSString *)symbol
                       items:(NSArray<SCIRow *> *)items
                      footer:(NSString *)footer
                        host:(SCIYTSettingsHostController *)host {
    NSUInteger on = 0;
    for (SCIRow *item in items) {
        if (item.prefKey && SCIPrefEnabled(item.prefKey)) on++;
    }

    NSString *count = [NSString stringWithFormat:SCILocalized(@"checklist_count"),
                       (unsigned long)on, (unsigned long)items.count];

    // Weak: the row is held by the host's sections and its block would otherwise hold the
    // host back, the same loop SCIYTSettingsController's page rows already avoid.
    __weak SCIYTSettingsHostController *weakHost = host;

    return [SCIRow disclosureRow:title
                          detail:count
                          symbol:symbol
                          action:^{
        SCIYTSettingsHostController *strongHost = weakHost;
        if (!strongHost.navigationController) return;

        SCISection *section = [[SCISection alloc] init];
        section.rows = items;
        section.footer = footer;

        SCIYTPage *page = [[SCIYTPage alloc] init];
        page.title = title;
        page.builder = ^NSArray<SCISection *> *(__unused SCIYTSettingsHostController *h) { return @[section]; };

        [strongHost.navigationController pushViewController:[[SCIYTSubpageController alloc] initWithPage:page]
                                                   animated:YES];
    }];
}

@end
