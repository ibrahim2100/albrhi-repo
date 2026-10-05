#import "../Model/SCITWPageRegistry.h"
#import "Prefs.h"
#import "Localization/SCILocalize.h"

///
/// Links, and the app lock.
///
/// Together because both are about what leaves the app rather than what it looks like: a
/// copied link carrying the account that shared it, a `t.co` hiding where a tap goes, a
/// search box remembering, and a phone handed to somebody for a moment.
///
@interface SCITWPageLinks : NSObject
@end

@implementation SCITWPageLinks

+ (void)load {
    [SCITWPageRegistry registerPageWithOrder:20
                                   title:SCILocalized(@"section_links")
                                    note:SCILocalized(@"section_links_note")
                                  symbol:@"lock.shield.fill"
                                    tint:[UIColor systemGreenColor]
                                 builder:^NSArray<SCITWSection *> *(__unused UIViewController *host) {
        return @[
            [SCITWSection titled:SCILocalized(@"section_links")
                          footer:SCILocalized(@"section_links_note")
                            rows:@[
                [SCITWRow switchRow:SCILocalized(@"set_strip_tracking")
                               note:SCILocalized(@"set_strip_tracking_note")
                             symbol:@"link.badge.plus"
                               tint:[UIColor systemGreenColor]
                            prefKey:SCIPrefStripTracking],
                [SCITWRow switchRow:SCILocalized(@"set_expand_links")
                               note:SCILocalized(@"set_expand_links_note")
                             symbol:@"eye"
                               tint:[UIColor systemTealColor]
                            prefKey:SCIPrefExpandLinks],
                [SCITWRow switchRow:SCILocalized(@"set_no_search_history")
                               note:SCILocalized(@"set_no_search_history_note")
                             symbol:@"magnifyingglass"
                               tint:[UIColor systemIndigoColor]
                            prefKey:SCIPrefNoSearchHistory],
                [SCITWRow switchRow:SCILocalized(@"set_app_lock")
                               note:SCILocalized(@"set_app_lock_note")
                             symbol:@"faceid"
                               tint:[UIColor systemPurpleColor]
                            prefKey:SCIPrefAppLock],
            ]],
            [SCITWSection titled:SCILocalized(@"section_chat")
                          footer:SCILocalized(@"section_chat_note")
                            rows:@[
                [SCITWRow switchRow:SCILocalized(@"set_hide_typing")
                               note:SCILocalized(@"set_hide_typing_note")
                             symbol:@"ellipsis.bubble"
                               tint:[UIColor systemIndigoColor]
                            prefKey:SCIPrefHideTyping],
                [SCITWRow switchRow:SCILocalized(@"set_block_screenshot")
                               note:SCILocalized(@"set_block_screenshot_note")
                             symbol:@"camera.viewfinder"
                               tint:[UIColor systemRedColor]
                            prefKey:SCIPrefBlockScreenshotDetect],
            ]],
        ];
    }];
}

@end
