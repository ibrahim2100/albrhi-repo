#import "../Model/SCITWPageRegistry.h"
#import "Prefs.h"
#import "Localization/SCILocalize.h"

///
/// The small things in X's own interface: what to take away, and what to put back.
///
/// Together on one page because each is a single answer to a single question X already asks
/// (see `Features/Interface`), and because somebody tidying X's screen opens one place for all
/// of it rather than six. Every row attaches when X is opened, which the footer says.
///
@interface SCITWPageInterface : NSObject
@end

@implementation SCITWPageInterface

+ (void)load {
    [SCITWPageRegistry registerPageWithOrder:35
                                   title:SCILocalized(@"section_interface")
                                    note:SCILocalized(@"section_interface_note")
                                  symbol:@"slider.horizontal.3"
                                    tint:[UIColor systemOrangeColor]
                                 builder:^NSArray<SCITWSection *> *(__unused UIViewController *host) {
        return @[
            [SCITWSection titled:SCILocalized(@"section_interface_hide")
                          footer:SCILocalized(@"section_interface_footer")
                            rows:@[
                [SCITWRow switchRow:SCILocalized(@"set_hide_compose")
                               note:SCILocalized(@"set_hide_compose_note")
                             symbol:@"plus.circle.fill"
                               tint:[UIColor systemBlueColor]
                            prefKey:SCIPrefHideCompose],
                [SCITWRow switchRow:SCILocalized(@"set_hide_paid_badge")
                               note:SCILocalized(@"set_hide_paid_badge_note")
                             symbol:@"checkmark.seal.fill"
                               tint:[UIColor systemBlueColor]
                            prefKey:SCIPrefHideBlueBadge],
                [SCITWRow switchRow:SCILocalized(@"set_hide_follow_posts")
                               note:SCILocalized(@"set_hide_follow_posts_note")
                             symbol:@"person.crop.circle.badge.plus"
                               tint:[UIColor systemGreenColor]
                            prefKey:SCIPrefHideFollowOnPosts],
                [SCITWRow switchRow:SCILocalized(@"set_hide_trends")
                               note:SCILocalized(@"set_hide_trends_note")
                             symbol:@"chart.line.uptrend.xyaxis"
                               tint:[UIColor systemOrangeColor]
                            prefKey:SCIPrefHideTrends],
            ]],
            [SCITWSection titled:SCILocalized(@"section_interface_show")
                          footer:nil
                            rows:@[
                [SCITWRow switchRow:SCILocalized(@"set_keep_tab_bar")
                               note:SCILocalized(@"set_keep_tab_bar_note")
                             symbol:@"rectangle.bottomthird.inset.filled"
                               tint:[UIColor systemIndigoColor]
                            prefKey:SCIPrefKeepTabBar],
                [SCITWRow switchRow:SCILocalized(@"set_tab_labels")
                               note:SCILocalized(@"set_tab_labels_note")
                             symbol:@"textformat"
                               tint:[UIColor systemTealColor]
                            prefKey:SCIPrefTabLabels],
                [SCITWRow switchRow:SCILocalized(@"set_scroll_indicator")
                               note:SCILocalized(@"set_scroll_indicator_note")
                             symbol:@"arrow.up.and.down"
                               tint:[UIColor systemGrayColor]
                            prefKey:SCIPrefScrollIndicator],
                [SCITWRow switchRow:SCILocalized(@"set_hq_images")
                               note:SCILocalized(@"set_hq_images_note")
                             symbol:@"photo.fill"
                               tint:[UIColor systemPinkColor]
                            prefKey:SCIPrefHighQualityImages],
                [SCITWRow switchRow:SCILocalized(@"set_no_dock")
                               note:SCILocalized(@"set_no_dock_note")
                             symbol:@"pip.exit"
                               tint:[UIColor systemPurpleColor]
                            prefKey:SCIPrefNoDocking],
            ]],
        ];
    }];
}

@end
