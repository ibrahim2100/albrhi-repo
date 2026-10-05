#import "../Model/SCITWPageRegistry.h"
#import "Prefs.h"
#import "Localization/SCILocalize.h"

///
/// The rest: one question each, answered differently.
///
/// `disable_rtl` is marked cautious and sits last on purpose. The working language of this
/// project is Arabic, and forcing left-to-right changes the direction of every piece of text
/// X draws rather than only the one that annoyed somebody.
///
@interface SCITWPageExtras : NSObject
@end

@implementation SCITWPageExtras

+ (void)load {
    [SCITWPageRegistry registerPageWithOrder:50
                                   title:SCILocalized(@"section_extras")
                                    note:SCILocalized(@"page_extras_note")
                                  symbol:@"sparkles"
                                    tint:[UIColor systemTealColor]
                                 builder:^NSArray<SCITWSection *> *(__unused UIViewController *host) {
        SCITWRow *rtl = [SCITWRow switchRow:SCILocalized(@"set_disable_rtl")
                                       note:SCILocalized(@"set_disable_rtl_note")
                                     symbol:@"text.alignleft"
                                       tint:[UIColor systemRedColor]
                                    prefKey:SCIPrefDisableRTL];
        rtl.cautious = YES;

        return @[
            [SCITWSection titled:SCILocalized(@"section_extras_posts")
                          footer:nil
                            rows:@[
                [SCITWRow switchRow:SCILocalized(@"set_tweet_to_image")
                               note:SCILocalized(@"set_tweet_to_image_note")
                             symbol:@"camera.viewfinder"
                               tint:[UIColor systemPinkColor]
                            prefKey:SCIPrefTweetToImage],
                [SCITWRow switchRow:SCILocalized(@"set_full_frame")
                               note:SCILocalized(@"set_full_frame_note")
                             symbol:@"rectangle.expand.vertical"
                               tint:[UIColor systemTealColor]
                            prefKey:SCIPrefFullFrameImages],
            ]],
            [SCITWSection titled:SCILocalized(@"section_extras_counts")
                          footer:nil
                            rows:@[
                [SCITWRow switchRow:SCILocalized(@"set_show_quotes")
                               note:SCILocalized(@"set_show_quotes_note")
                             symbol:@"quote.bubble.fill"
                               tint:[UIColor systemBlueColor]
                            prefKey:SCIPrefShowQuotes],
                [SCITWRow switchRow:SCILocalized(@"set_unrounded_quotes")
                               note:nil
                             symbol:@"number"
                               tint:[UIColor systemIndigoColor]
                            prefKey:SCIPrefUnroundedQuotes],
                [SCITWRow switchRow:SCILocalized(@"set_unrounded_counts")
                               note:SCILocalized(@"set_unrounded_counts_note")
                             symbol:@"person.2.fill"
                               tint:[UIColor systemTealColor]
                            prefKey:SCIPrefUnroundedCounts],
            ]],
            [SCITWSection titled:SCILocalized(@"section_extras_other")
                          footer:nil
                            rows:@[
                [SCITWRow switchRow:SCILocalized(@"set_undo_post")
                               note:SCILocalized(@"set_undo_post_note")
                             symbol:@"arrow.uturn.backward"
                               tint:[UIColor systemBlueColor]
                            prefKey:SCIPrefUndoPost],
                [SCITWRow switchRow:SCILocalized(@"set_copy_profile")
                               note:SCILocalized(@"set_copy_profile_note")
                             symbol:@"doc.on.doc"
                               tint:[UIColor systemTealColor]
                            prefKey:SCIPrefCopyProfileInfo],
                [SCITWRow switchRow:SCILocalized(@"set_bio_translate")
                               note:nil
                             symbol:@"character.bubble"
                               tint:[UIColor systemGreenColor]
                            prefKey:SCIPrefBioTranslate],
                [SCITWRow switchRow:SCILocalized(@"set_high_quality_upload")
                               note:SCILocalized(@"set_high_quality_upload_note")
                             symbol:@"photo.badge.arrow.down"
                               tint:[UIColor systemIndigoColor]
                            prefKey:SCIPrefHighQualityUpload],
                rtl,
            ]],
        ];
    }];
}

@end
