#import "../SCIYTSettingsRegistry.h"
#import "../SCIYTChecklistRow.h"
#import "../../Prefs.h"
#import "../../Localization/SCILocalize.h"

///
/// SponsorBlock, in two sections.
///
/// Split because "skip sponsored parts" is one decision and "which parts count" is eight
/// more, and a single list of nine switches reads as nine equal choices.
///
@interface SCIYTSponsorPage : NSObject
@end

@implementation SCIYTSponsorPage

+ (void)load {
    [SCIYTSettingsRegistry registerPageWithOrder:50
                                        title:SCILocalized(@"page_sponsor")
                                       detail:SCILocalized(@"page_sponsor_note")
                                       symbol:@"forward.end.fill"
                                      builder:^NSArray<SCISection *> *(SCIYTSettingsHostController *host) {
        SCISection *sponsor = [[SCISection alloc] init];
        sponsor.title = SCILocalized(@"section_sponsorblock");
        sponsor.rows = @[
            [SCIRow switchRow:SCILocalized(@"sponsorblock")
                       detail:SCILocalized(@"sponsorblock_note")
                       symbol:@"forward.end.fill"
                      prefKey:SCIPrefSponsorBlock],
            [SCIRow switchRow:SCILocalized(@"sponsorblock_notice")
                       detail:SCILocalized(@"sponsorblock_notice_note")
                       symbol:@"bubble.left.fill"
                      prefKey:SCIPrefSBNotice],
            [SCIRow switchRow:SCILocalized(@"sponsorblock_markers")
                       detail:SCILocalized(@"sponsorblock_markers_note")
                       symbol:@"paintpalette.fill"
                      prefKey:SCIPrefSBMarkers],
        ];

        SCISection *categories = [[SCISection alloc] init];
        categories.title = SCILocalized(@"sb_categories");
        NSArray<SCIRow *> *items = @[
            [SCIRow switchRow:SCILocalized(@"sb_sponsor")
                       detail:SCILocalized(@"sb_sponsor_note")
                       symbol:@"dollarsign.circle.fill"
                      prefKey:SCIPrefSBSponsor],
            [SCIRow switchRow:SCILocalized(@"sb_selfpromo")
                       detail:SCILocalized(@"sb_selfpromo_note")
                       symbol:@"person.crop.circle.fill"
                      prefKey:SCIPrefSBSelfPromo],
            [SCIRow switchRow:SCILocalized(@"sb_interaction")
                       detail:SCILocalized(@"sb_interaction_note")
                       symbol:@"hand.thumbsup.fill"
                      prefKey:SCIPrefSBInteraction],
            [SCIRow switchRow:SCILocalized(@"sb_intro")
                       detail:SCILocalized(@"sb_intro_note")
                       symbol:@"film.fill"
                      prefKey:SCIPrefSBIntro],
            [SCIRow switchRow:SCILocalized(@"sb_outro")
                       detail:SCILocalized(@"sb_outro_note")
                       symbol:@"rectangle.stack.fill"
                      prefKey:SCIPrefSBOutro],
            [SCIRow switchRow:SCILocalized(@"sb_preview")
                       detail:SCILocalized(@"sb_preview_note")
                       symbol:@"text.bubble.fill"
                      prefKey:SCIPrefSBPreview],
            [SCIRow switchRow:SCILocalized(@"sb_filler")
                       detail:SCILocalized(@"sb_filler_note")
                       symbol:@"scissors"
                      prefKey:SCIPrefSBFiller],
            [SCIRow switchRow:SCILocalized(@"sb_music_offtopic")
                       detail:SCILocalized(@"sb_music_offtopic_note")
                       symbol:@"music.note"
                      prefKey:SCIPrefSBMusicOffTopic],
        ];
        categories.rows = @[
            [SCIRow checklistRow:SCILocalized(@"sb_categories_row")
                          symbol:@"checklist"
                           items:items
                          footer:SCILocalized(@"sb_categories_note")
                            host:host],
        ];
        // Where the data comes from, its licence, and what does and does not leave the
        // phone. The attribution is a condition of CC BY-NC-SA; the privacy sentence is
        // there because a feature that talks to a server should say so where it is switched
        // on, not in a changelog.
        categories.footer = SCILocalized(@"sb_credit");
        return @[sponsor, categories];
    }];
}

@end
