#import "../Model/SCITWPageRegistry.h"
#import "Prefs.h"
#import "Localization/SCILocalize.h"

///
/// What Albrhi itself adds to X: the save button, the profile photo, and the two
/// confirmations. First on the screen because it is what somebody who installed this tweak
/// came looking for -- the ad filters and the switch layer are things they will find, and
/// the download button is the thing they wanted.
///
@interface SCITWPageAlbrhi : NSObject
@end

@implementation SCITWPageAlbrhi

+ (void)load {
    [SCITWPageRegistry registerPageWithOrder:10
                                   title:SCILocalized(@"section_albrhi")
                                    note:SCILocalized(@"page_albrhi_note")
                                  symbol:@"arrow.down.circle.fill"
                                    tint:[UIColor systemBlueColor]
                                 builder:^NSArray<SCITWSection *> *(__unused UIViewController *host) {
        return @[
            [SCITWSection titled:SCILocalized(@"section_albrhi")
                          footer:nil
                            rows:@[
                [SCITWRow switchRow:SCILocalized(@"albrhi_save_button")
                               note:SCILocalized(@"albrhi_save_button_note")
                             symbol:@"arrow.down.circle.fill"
                               tint:[UIColor systemBlueColor]
                            prefKey:SCIPrefInlineButton],
                [SCITWRow switchRow:SCILocalized(@"albrhi_move_button")
                               note:SCILocalized(@"albrhi_move_button_note")
                             symbol:@"arrow.up.and.down.and.arrow.left.and.right"
                               tint:[UIColor systemIndigoColor]
                            prefKey:SCIPrefMoveSaveButton],
                [SCITWRow actionRow:SCILocalized(@"albrhi_reset_button")
                               note:SCILocalized(@"albrhi_reset_button_note")
                             symbol:@"arrow.uturn.backward.circle"
                               tint:[UIColor systemGrayColor]
                             action:^{
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:SCIPrefSaveButtonPlace];
                }],
                [SCITWRow switchRow:SCILocalized(@"albrhi_save_avatar")
                               note:SCILocalized(@"albrhi_save_avatar_note")
                             symbol:@"person.crop.circle.fill"
                               tint:[UIColor systemTealColor]
                            prefKey:SCIPrefSaveAvatar],
                [SCITWRow switchRow:SCILocalized(@"albrhi_confirm_repost")
                               note:SCILocalized(@"albrhi_confirm_repost_note")
                             symbol:@"arrow.2.squarepath"
                               tint:[UIColor systemGreenColor]
                            prefKey:SCIPrefConfirmRepost],
                [SCITWRow switchRow:SCILocalized(@"set_confirm_like")
                               note:SCILocalized(@"set_confirm_like_note")
                             symbol:@"heart.fill"
                               tint:[UIColor systemPinkColor]
                            prefKey:SCIPrefConfirmLike],
                [SCITWRow switchRow:SCILocalized(@"set_confirm_follow")
                               note:SCILocalized(@"set_confirm_follow_note")
                             symbol:@"person.badge.plus"
                               tint:[UIColor systemGreenColor]
                            prefKey:SCIPrefConfirmFollow],
            ]],
        ];
    }];
}

@end
