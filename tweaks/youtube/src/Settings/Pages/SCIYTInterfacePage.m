#import "../SCIYTSettingsRegistry.h"
#import "../SCIYTChecklistRow.h"
#import "../../Prefs.h"
#import "../../Localization/SCILocalize.h"
#import "../SCIYTTabBarController.h"

///
/// Everything that takes something away from YouTube's own screen: the ads first, then the
/// parts of the app around the video that you can switch off, then the tab bar.
///
/// One page for what used to be two (a page of two ad switches, and this). They are the same
/// kind of thing -- each *removes* something -- and the ads are simply the one the tweak is
/// installed for. Everything but the ads ships off, so turning any of the rest on is a
/// deliberate act. See `Features/Interface/SCIYTHide.x` for how each is done — none of them
/// hides a view; they answer the question the app asks before building it.
///
@interface SCIYTInterfacePage : NSObject
@end

@implementation SCIYTInterfacePage

+ (void)load {
    [SCIYTSettingsRegistry registerPageWithOrder:40
                                        title:SCILocalized(@"page_clean")
                                       detail:SCILocalized(@"page_clean_note")
                                       symbol:@"hand.raised.fill"
                                      builder:^NSArray<SCISection *> *(SCIYTSettingsHostController *host) {
        SCISection *ads = [[SCISection alloc] init];
        ads.title = SCILocalized(@"section_ads");
        ads.rows = @[
            [SCIRow switchRow:SCILocalized(@"hide_ads")
                       detail:SCILocalized(@"hide_ads_note")
                       symbol:@"hand.raised.fill"
                      prefKey:SCIPrefHideAds],
            [SCIRow switchRow:SCILocalized(@"hide_paid_promotion")
                       detail:SCILocalized(@"hide_paid_promotion_note")
                       symbol:@"megaphone.fill"
                      prefKey:SCIPrefHidePaidPromo],
        ];

        SCISection *player = [[SCISection alloc] init];
        player.title = SCILocalized(@"section_hide_player");
        player.rows = @[
            [SCIRow switchRow:SCILocalized(@"hide_ambient_glow")
                       detail:SCILocalized(@"hide_ambient_glow_note")
                       symbol:@"light.max"
                      prefKey:SCIPrefHideAmbient],
            [SCIRow switchRow:SCILocalized(@"hide_endscreen")
                       detail:SCILocalized(@"hide_endscreen_note")
                       symbol:@"rectangle.grid.2x2"
                      prefKey:SCIPrefHideEndscreen],
            [SCIRow switchRow:SCILocalized(@"hide_info_cards")
                       detail:SCILocalized(@"hide_info_cards_note")
                       symbol:@"info.circle"
                      prefKey:SCIPrefHideInfoCards],
        ];

        SCISection *tabs = [[SCISection alloc] init];
        tabs.title = SCILocalized(@"section_tab_bar");
        tabs.footer = SCILocalized(@"section_tab_bar_note");
        tabs.rows = @[
            [SCIRow disclosureRow:SCILocalized(@"set_tabs_arrange")
                           detail:SCILocalized(@"set_tabs_arrange_note")
                           symbol:@"square.grid.2x2"
                           action:^{ [SCIYTTabBarController present]; }],
            // Here and not under Downloads: it is the tab bar being changed, and somebody who
            // wants the Download Centre tab gone looks for it with the other tab settings.
            [SCIRow switchRow:SCILocalized(@"set_pivot_bar")
                       detail:SCILocalized(@"set_pivot_bar_note")
                       symbol:@"rectangle.bottomthird.inset.filled"
                      prefKey:SCIPrefPivotBar],
        ];

        SCISection *bar = [[SCISection alloc] init];
        bar.title = SCILocalized(@"section_hide_topbar");
        NSArray<SCIRow *> *barItems = @[
            [SCIRow switchRow:SCILocalized(@"hide_search_button")
                       detail:nil
                       symbol:@"magnifyingglass"
                      prefKey:SCIPrefHideSearchButton],
            [SCIRow switchRow:SCILocalized(@"hide_notify_button")
                       detail:nil
                       symbol:@"bell"
                      prefKey:SCIPrefHideNotifyButton],
            [SCIRow switchRow:SCILocalized(@"hide_create_button")
                       detail:nil
                       symbol:@"plus.circle"
                      prefKey:SCIPrefHideCreateButton],
            [SCIRow switchRow:SCILocalized(@"hide_cast_button")
                       detail:nil
                       symbol:@"tv.badge.wifi"
                      prefKey:SCIPrefHideCastButton],
        ];
        bar.rows = @[
            [SCIRow checklistRow:SCILocalized(@"hide_topbar_row")
                          symbol:@"rectangle.topthird.inset.filled"
                           items:barItems
                          footer:SCILocalized(@"section_hide_topbar_note")
                            host:host],
        ];

        SCISection *elsewhere = [[SCISection alloc] init];
        elsewhere.title = SCILocalized(@"section_hide_elsewhere");
        elsewhere.rows = @[
            [SCIRow switchRow:SCILocalized(@"hide_share_promo")
                       detail:SCILocalized(@"hide_share_promo_note")
                       symbol:@"square.and.arrow.up"
                      prefKey:SCIPrefHideSharePromo],
        ];

        return @[ads, player, bar, elsewhere, tabs];
    }];
}

@end
