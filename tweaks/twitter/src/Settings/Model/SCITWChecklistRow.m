#import "SCITWChecklistRow.h"
#import "SCITWPageRegistry.h"
#import "../SCITWPageController.h"
#import "Localization/SCILocalize.h"

@implementation SCITWRow (Checklist)

+ (instancetype)checklistRow:(NSString *)title
                      symbol:(NSString *)symbol
                        tint:(UIColor *)tint
                       items:(NSArray<SCITWRow *> *)items
                      footer:(NSString *)footer
                        host:(UIViewController *)host {
    NSUInteger on = 0;
    for (SCITWRow *item in items) {
        if (item.prefKey && [[NSUserDefaults standardUserDefaults] boolForKey:item.prefKey]) on++;
    }
    NSString *count = [NSString stringWithFormat:SCILocalized(@"checklist_count"),
                       (unsigned long)on, (unsigned long)items.count];

    // Weak: the host holds the rows and each row holds this block.
    __weak UIViewController *weakHost = host;

    return [SCITWRow actionRow:title
                          note:count
                        symbol:symbol
                          tint:tint
                        action:^{
        UIViewController *strongHost = weakHost;
        if (!strongHost.navigationController) return;

        SCITWPage *page = [[SCITWPage alloc] init];
        page.title = title;
        page.builder = ^NSArray<SCITWSection *> *(__unused UIViewController *h) {
            return @[[SCITWSection titled:nil footer:footer rows:items]];
        };
        [strongHost.navigationController
            pushViewController:[[SCITWPageController alloc] initWithPage:page] animated:YES];
    }];
}

@end
