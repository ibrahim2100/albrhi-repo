//
//  SCITTClean.x
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "SCITTClean.h"
#import "../../Prefs.h"
#import "../../SCILog.h"

///
/// **Six switches that each refuse one question TikTok's own code asks, and none of them hides a view after it was built.**
///
/// A closed, licensed reference tweak (OSTikTok 1.3.1, `docs/investigations/ostiktok.md`) showed that these places exist: its public
/// settings list and the TikTok class names it asks the runtime for. Nothing was copied and none of its protected code was read. Every
/// class, selector and type encoding below was then read from **TikTok 47.4.0's own `MusicallyCore`** (`tools/objc-classes.py --dump`),
/// and who asks each gate was measured with `docs/investigations/na9-scripts/callers.py`. A reference tweak's selector is a map of its
/// build, never a manifest of ours (CLAUDE.md §2), and this file is the second half of that sentence.
///
/// **Who asks** (caller scan, 47.4.0; the owner attribution is the nearest preceding method, a hint):
///
///   * Surveys: `-[TIKTOKFeedSurveyManager canShowSurvey:preModel:playInteractionContext:]` is read by `TTKFeedInteractionSurveyManager`
///     (`containerWillDisplay`, `rootGestureShouldBegin:`), `TTKFeedSurveyBizComponent` and `TTKFeedDetailCommonSurveyComponent` -- the
///     component that *inserts* a survey cell reads it, so refusing the answer prevents the cell rather than hiding one.
///     `canShowSurveyForPreloadModel:playInteractionContext:` is the same question asked ahead of time. The three config classes answer
///     the same question one level down (and `TTKABTest` asks one of them), and `TTKCommerceSurveyService -canShowSurvey:` is the shop's
///     own survey, read by the survey container and the gesture controller.
///   * Tako (TikTok's AI assistant): `-shouldShowTakoEntranceWithAwemeModel:referString:playlistPreviousPage:` is declared by **three**
///     classes (grep every implementer: the Swift `FeedInteractionTakoEntryPluginImpl` is the one the layout code and
///     `TTKFeedTikBotHelper` actually read), so all three are answered. `TTKSearchTabBar -p_isTakoAllow` is read by `p_takoStyle`;
///     `TTKCommentTakoGateHelper +shouldShowTakoInCommentWithAweme:` by the comment mention ranking.
///   * Floating promotions ("pendants"): every one of them -- the activity badge, the reward timer, the new-user tip -- is added to the
///     screen through **one** place, `-[TTKPendantUIManager tryAddPendantWithController:inContainer:]`, called by
///     `TTKNormalPendantController` and `TTKTimerPendantBaseController`. Refusing the add is the narrowest cut and leaves every
///     controller's own decision logic alone.
///   * Board cards: `TTKFeedBottomBarContainerView -updateWithData:` asks each bottom-bar manager `-shouldShowWithData:`.
///   * The sensitive-content mask: `AWEPlayInteractionServerDerivedMaskViewManager` builds the overlay from the server's mask info.
///
/// **Not run on a device.** "Installed" beside "0 refused" on the Status screen is a hook on a path nothing takes (CLAUDE.md §4.2).
///

static NSString *sciCleanState = nil;

// Tallies, one per switch, on the path that executes.
static NSUInteger sciSurveys = 0, sciTakoFeed = 0, sciTakoSearch = 0, sciTakoComment = 0;
static NSUInteger sciPendants = 0, sciBubbles = 0, sciBoards = 0, sciMask = 0;

static BOOL SCITTCleanInstance(Class cls, const char *selector, const char *encoding) {
    if (!cls) return NO;
    Method method = class_getInstanceMethod(cls, sel_registerName(selector));
    const char *types = method ? method_getTypeEncoding(method) : NULL;
    return types && strcmp(types, encoding) == 0;
}

static BOOL SCITTCleanClassMethod(Class cls, const char *selector, const char *encoding) {
    if (!cls) return NO;
    Method method = class_getClassMethod(cls, sel_registerName(selector));
    const char *types = method ? method_getTypeEncoding(method) : NULL;
    return types && strcmp(types, encoding) == 0;
}

#pragma mark - Surveys

// The manager every feed survey is asked through. Two doors: the live question and the one asked while the next video preloads.
%group SCITTCleanSurveyManager
%hook TIKTOKFeedSurveyManager

- (BOOL)canShowSurvey:(id)survey preModel:(id)previous playInteractionContext:(id)context {
    if (!SCIPrefEnabled(SCIPrefNoSurveys)) return %orig;
    sciSurveys++;
    return NO;
}

- (BOOL)canShowSurveyForPreloadModel:(id)model playInteractionContext:(id)context {
    if (!SCIPrefEnabled(SCIPrefNoSurveys)) return %orig;
    sciSurveys++;
    return NO;
}

%end
%end

// The same question one level down. The base and the feed config both declare it (the feed one overrides), so each is answered on its own.
%group SCITTCleanSurveyFeedConfig
%hook TTKFeedSurveyFeedConfig

- (BOOL)canShowSurveyForModel:(id)model previousModel:(id)previous playInteractionContext:(id)context currentIndex:(long long)index {
    if (!SCIPrefEnabled(SCIPrefNoSurveys)) return %orig;
    sciSurveys++;
    return NO;
}

%end
%end

%group SCITTCleanSurveyBaseConfig
%hook TTKFeedSurveyBaseConfig

- (BOOL)canShowSurveyForModel:(id)model previousModel:(id)previous playInteractionContext:(id)context currentIndex:(long long)index {
    if (!SCIPrefEnabled(SCIPrefNoSurveys)) return %orig;
    sciSurveys++;
    return NO;
}

%end
%end

%group SCITTCleanSurveyMultiConfig
%hook TTKFeedSurveyMultiConfig

- (BOOL)canShowSurveyForModel:(id)model previousModel:(id)previous playInteractionContext:(id)context {
    if (!SCIPrefEnabled(SCIPrefNoSurveys)) return %orig;
    sciSurveys++;
    return NO;
}

- (BOOL)canShowSurveyForPreloadModel:(id)model playInteractionContext:(id)context {
    if (!SCIPrefEnabled(SCIPrefNoSurveys)) return %orig;
    sciSurveys++;
    return NO;
}

%end
%end

// The shop's own survey, a separate service with a separate question.
%group SCITTCleanSurveyCommerce
%hook TTKCommerceSurveyService

- (BOOL)canShowSurvey:(id)model {
    if (!SCIPrefEnabled(SCIPrefNoSurveys)) return %orig;
    sciSurveys++;
    return NO;
}

%end
%end

#pragma mark - Tako, TikTok's AI assistant

// The button above the avatars. Declared by three classes with the same encoding.
%group SCITTCleanTakoElement
%hook TTKFeedRightTakoElement

- (BOOL)shouldShowTakoEntranceWithAwemeModel:(id)model referString:(id)refer playlistPreviousPage:(id)page {
    if (!SCIPrefEnabled(SCIPrefHideTako)) return %orig;
    sciTakoFeed++;
    return NO;
}

%end
%end

%group SCITTCleanTakoComponent
%hook TTKFeedFYPBottomRightTakoEntranceComponent

- (BOOL)shouldShowTakoEntranceWithAwemeModel:(id)model referString:(id)refer playlistPreviousPage:(id)page {
    if (!SCIPrefEnabled(SCIPrefHideTako)) return %orig;
    sciTakoFeed++;
    return NO;
}

%end
%end

// The Swift plugin the layout code and the TikBot helper really read. Its prompt bubble ("ask Tako about this") is a second question.
%group SCITTCleanTakoPlugin
%hook _TtC31TikTokFeedInteractionBizImplExt34FeedInteractionTakoEntryPluginImpl

- (BOOL)shouldShowTakoEntranceWithAwemeModel:(id)model referString:(id)refer playlistPreviousPage:(id)page {
    if (!SCIPrefEnabled(SCIPrefHideTako)) return %orig;
    sciTakoFeed++;
    return NO;
}

- (BOOL)shouldShowTakoPromptBubble {
    if (!SCIPrefEnabled(SCIPrefHideTako)) return %orig;
    sciTakoFeed++;
    return NO;
}

%end
%end

// The bar under a video and the banner above it.
%group SCITTCleanTakoBottomBar
%hook TTKFeedBottomBarTakoManager

- (BOOL)shouldShowTakoBottomBarWith:(id)data {
    if (!SCIPrefEnabled(SCIPrefHideTako)) return %orig;
    sciTakoFeed++;
    return NO;
}

- (BOOL)shouldShowWithData:(id)data {
    if (!SCIPrefEnabled(SCIPrefHideTako)) return %orig;
    sciTakoFeed++;
    return NO;
}

%end
%end

%group SCITTCleanTakoBanner
%hook TTKFeedBannerTakoAppearHandler

- (BOOL)canDisplayBanner {
    if (!SCIPrefEnabled(SCIPrefHideTako)) return %orig;
    sciTakoFeed++;
    return NO;
}

%end
%end

// Search: the entrance on the tab bar, and the answer card inside the results.
%group SCITTCleanTakoSearchTabBar
%hook TTKSearchTabBar

- (BOOL)p_isTakoAllow {
    if (!SCIPrefEnabled(SCIPrefHideTako)) return %orig;
    sciTakoSearch++;
    return NO;
}

%end
%end

%group SCITTCleanTakoSearchCard
%hook TTKSearchInnerAskTakoService

// The one inverted question: "should the card be disabled?"
- (BOOL)shouldDisableAskTakoCard {
    if (!SCIPrefEnabled(SCIPrefHideTako)) return %orig;
    sciTakoSearch++;
    return YES;
}

%end
%end

// Comments: a class method, so the metaclass is hooked.
%group SCITTCleanTakoComments
%hook TTKCommentTakoGateHelper

+ (BOOL)shouldShowTakoInCommentWithAweme:(id)aweme {
    if (!SCIPrefEnabled(SCIPrefHideTako)) return %orig;
    sciTakoComment++;
    return NO;
}

%end
%end

#pragma mark - Floating promotions

// Every pendant is added through here, so one refusal covers the activity badge, the reward timer and the new-user tip. The rectangle it
// returns is the space the pendant took; zero is "none".
%group SCITTCleanPendants
%hook TTKPendantUIManager

- (CGRect)tryAddPendantWithController:(id)controller inContainer:(id)container {
    if (!SCIPrefEnabled(SCIPrefHidePendants)) return %orig;
    sciPendants++;
    return CGRectZero;
}

- (CGRect)tryAddPendantWithController:(id)controller inContainer:(id)container adjustPosition:(BOOL)adjust {
    if (!SCIPrefEnabled(SCIPrefHidePendants)) return %orig;
    sciPendants++;
    return CGRectZero;
}

%end
%end

// The speech bubble a campaign pendant shows beside itself.
%group SCITTCleanPendantBubbles
%hook TTKCampaignPendantManager

- (BOOL)couldShowPendantBubbleWithType:(unsigned long long)type {
    if (!SCIPrefEnabled(SCIPrefHidePendants)) return %orig;
    sciBubbles++;
    return NO;
}

%end
%end

#pragma mark - Bulletin board cards

// The card under a video that points at a bulletin board.
%group SCITTCleanBoardFeed
%hook TTKFeedBottomBarBulletinBoardViewManager

- (BOOL)shouldShowWithData:(id)data {
    if (!SCIPrefEnabled(SCIPrefHideBoards)) return %orig;
    sciBoards++;
    return NO;
}

%end
%end

// The "create your own board" banner on a profile. The inbox variant of this question returns an object (`@16@0:8`), not a BOOL, and an
// answer of the wrong kind is worse than no answer, so it is left alone.
%group SCITTCleanBoardProfile
%hook TTKInboxBulletinBoardManager

- (BOOL)canShowBulletinBoardCreateGuideBannerInProfile {
    if (!SCIPrefEnabled(SCIPrefHideBoards)) return %orig;
    sciBoards++;
    return NO;
}

%end
%end

#pragma mark - The sensitive-content mask

// The overlay is built by this manager from the server's mask info and removed by the person tapping "watch video". Not building it is
// the whole feature; nothing about the video, the model or the server's answer is touched.
%group SCITTCleanMask
%hook AWEPlayInteractionServerDerivedMaskViewManager

- (void)updateServerDerivedMaskView {
    if (!SCIPrefEnabled(SCIPrefNoSensitiveMask)) {
        %orig;
        return;
    }
    sciMask++;
}

- (void)handleUpdateServerDerivedMaskView:(id)update {
    if (!SCIPrefEnabled(SCIPrefNoSensitiveMask)) {
        %orig;
        return;
    }
    sciMask++;
}

%end
%end

NSString *SCITTCleanReport(void) {
    return [NSString stringWithFormat:
        @"%@; surveys refused %lu; Tako refused: feed %lu, search %lu, comments %lu; pendants refused %lu (bubbles %lu); "
        @"board cards refused %lu; mask not built %lu",
        sciCleanState ?: @"not installed",
        (unsigned long)sciSurveys, (unsigned long)sciTakoFeed, (unsigned long)sciTakoSearch, (unsigned long)sciTakoComment,
        (unsigned long)sciPendants, (unsigned long)sciBubbles, (unsigned long)sciBoards, (unsigned long)sciMask];
}

void SCITTInstallClean(void) {
    NSMutableArray<NSString *> *installed = [NSMutableArray array];
    NSMutableArray<NSString *> *skipped = [NSMutableArray array];

    // Each gate waits for its own class, its own selector and the encoding it was written against: a hook on a selector the class does not
    // declare would *add* it (CLAUDE.md §4.2), and one build missing a class must not cost the others.
    Class survey = NSClassFromString(@"TIKTOKFeedSurveyManager");
    if (SCITTCleanInstance(survey, "canShowSurvey:preModel:playInteractionContext:", "B40@0:8@16@24@32")
        && SCITTCleanInstance(survey, "canShowSurveyForPreloadModel:playInteractionContext:", "B32@0:8@16@24")) {
        %init(SCITTCleanSurveyManager);
        [installed addObject:@"survey manager"];
    } else {
        [skipped addObject:@"TIKTOKFeedSurveyManager -canShowSurvey…"];
    }
    if (SCITTCleanInstance(NSClassFromString(@"TTKFeedSurveyFeedConfig"), "canShowSurveyForModel:previousModel:playInteractionContext:currentIndex:", "B48@0:8@16@24@32q40")) {
        %init(SCITTCleanSurveyFeedConfig);
        [installed addObject:@"survey feed config"];
    } else {
        [skipped addObject:@"TTKFeedSurveyFeedConfig"];
    }
    if (SCITTCleanInstance(NSClassFromString(@"TTKFeedSurveyBaseConfig"), "canShowSurveyForModel:previousModel:playInteractionContext:currentIndex:", "B48@0:8@16@24@32q40")) {
        %init(SCITTCleanSurveyBaseConfig);
        [installed addObject:@"survey base config"];
    } else {
        [skipped addObject:@"TTKFeedSurveyBaseConfig"];
    }
    Class multi = NSClassFromString(@"TTKFeedSurveyMultiConfig");
    if (SCITTCleanInstance(multi, "canShowSurveyForModel:previousModel:playInteractionContext:", "B40@0:8@16@24@32")
        && SCITTCleanInstance(multi, "canShowSurveyForPreloadModel:playInteractionContext:", "B32@0:8@16@24")) {
        %init(SCITTCleanSurveyMultiConfig);
        [installed addObject:@"survey multi config"];
    } else {
        [skipped addObject:@"TTKFeedSurveyMultiConfig"];
    }
    if (SCITTCleanInstance(NSClassFromString(@"TTKCommerceSurveyService"), "canShowSurvey:", "B24@0:8@16")) {
        %init(SCITTCleanSurveyCommerce);
        [installed addObject:@"shop survey"];
    } else {
        [skipped addObject:@"TTKCommerceSurveyService"];
    }

    static const char *kTakoEntrance = "shouldShowTakoEntranceWithAwemeModel:referString:playlistPreviousPage:";
    if (SCITTCleanInstance(NSClassFromString(@"TTKFeedRightTakoElement"), kTakoEntrance, "B40@0:8@16@24@32")) {
        %init(SCITTCleanTakoElement);
        [installed addObject:@"tako element"];
    } else {
        [skipped addObject:@"TTKFeedRightTakoElement"];
    }
    if (SCITTCleanInstance(NSClassFromString(@"TTKFeedFYPBottomRightTakoEntranceComponent"), kTakoEntrance, "B40@0:8@16@24@32")) {
        %init(SCITTCleanTakoComponent);
        [installed addObject:@"tako component"];
    } else {
        [skipped addObject:@"TTKFeedFYPBottomRightTakoEntranceComponent"];
    }
    Class plugin = NSClassFromString(@"_TtC31TikTokFeedInteractionBizImplExt34FeedInteractionTakoEntryPluginImpl");
    if (SCITTCleanInstance(plugin, kTakoEntrance, "B40@0:8@16@24@32") && SCITTCleanInstance(plugin, "shouldShowTakoPromptBubble", "B16@0:8")) {
        %init(SCITTCleanTakoPlugin);
        [installed addObject:@"tako plugin"];
    } else {
        [skipped addObject:@"FeedInteractionTakoEntryPluginImpl"];
    }
    Class bar = NSClassFromString(@"TTKFeedBottomBarTakoManager");
    if (SCITTCleanInstance(bar, "shouldShowTakoBottomBarWith:", "B24@0:8@16") && SCITTCleanInstance(bar, "shouldShowWithData:", "B24@0:8@16")) {
        %init(SCITTCleanTakoBottomBar);
        [installed addObject:@"tako bottom bar"];
    } else {
        [skipped addObject:@"TTKFeedBottomBarTakoManager"];
    }
    if (SCITTCleanInstance(NSClassFromString(@"TTKFeedBannerTakoAppearHandler"), "canDisplayBanner", "B16@0:8")) {
        %init(SCITTCleanTakoBanner);
        [installed addObject:@"tako banner"];
    } else {
        [skipped addObject:@"TTKFeedBannerTakoAppearHandler"];
    }
    if (SCITTCleanInstance(NSClassFromString(@"TTKSearchTabBar"), "p_isTakoAllow", "B16@0:8")) {
        %init(SCITTCleanTakoSearchTabBar);
        [installed addObject:@"tako search tab"];
    } else {
        [skipped addObject:@"TTKSearchTabBar"];
    }
    if (SCITTCleanInstance(NSClassFromString(@"TTKSearchInnerAskTakoService"), "shouldDisableAskTakoCard", "B16@0:8")) {
        %init(SCITTCleanTakoSearchCard);
        [installed addObject:@"tako search card"];
    } else {
        [skipped addObject:@"TTKSearchInnerAskTakoService"];
    }
    if (SCITTCleanClassMethod(NSClassFromString(@"TTKCommentTakoGateHelper"), "shouldShowTakoInCommentWithAweme:", "B24@0:8@16")) {
        %init(SCITTCleanTakoComments);
        [installed addObject:@"tako comments"];
    } else {
        [skipped addObject:@"TTKCommentTakoGateHelper"];
    }

    Class pendants = NSClassFromString(@"TTKPendantUIManager");
    if (SCITTCleanInstance(pendants, "tryAddPendantWithController:inContainer:", "{CGRect={CGPoint=dd}{CGSize=dd}}32@0:8@16@24")
        && SCITTCleanInstance(pendants, "tryAddPendantWithController:inContainer:adjustPosition:", "{CGRect={CGPoint=dd}{CGSize=dd}}36@0:8@16@24B32")) {
        %init(SCITTCleanPendants);
        [installed addObject:@"pendants"];
    } else {
        [skipped addObject:@"TTKPendantUIManager"];
    }
    if (SCITTCleanInstance(NSClassFromString(@"TTKCampaignPendantManager"), "couldShowPendantBubbleWithType:", "B24@0:8Q16")) {
        %init(SCITTCleanPendantBubbles);
        [installed addObject:@"pendant bubbles"];
    } else {
        [skipped addObject:@"TTKCampaignPendantManager"];
    }

    if (SCITTCleanInstance(NSClassFromString(@"TTKFeedBottomBarBulletinBoardViewManager"), "shouldShowWithData:", "B24@0:8@16")) {
        %init(SCITTCleanBoardFeed);
        [installed addObject:@"board card"];
    } else {
        [skipped addObject:@"TTKFeedBottomBarBulletinBoardViewManager"];
    }
    if (SCITTCleanInstance(NSClassFromString(@"TTKInboxBulletinBoardManager"), "canShowBulletinBoardCreateGuideBannerInProfile", "B16@0:8")) {
        %init(SCITTCleanBoardProfile);
        [installed addObject:@"board profile banner"];
    } else {
        [skipped addObject:@"TTKInboxBulletinBoardManager"];
    }

    Class mask = NSClassFromString(@"AWEPlayInteractionServerDerivedMaskViewManager");
    if (SCITTCleanInstance(mask, "updateServerDerivedMaskView", "v16@0:8")
        && SCITTCleanInstance(mask, "handleUpdateServerDerivedMaskView:", "v24@0:8@16")) {
        %init(SCITTCleanMask);
        [installed addObject:@"mask"];
    } else {
        [skipped addObject:@"AWEPlayInteractionServerDerivedMaskViewManager"];
    }

    sciCleanState = [NSString stringWithFormat:@"%@%@",
        installed.count ? [@"installed: " stringByAppendingString:[installed componentsJoinedByString:@", "]] : @"nothing installed",
        skipped.count ? [NSString stringWithFormat:@" — skipped: %@", [skipped componentsJoinedByString:@"; "]] : @""];
    SCILogV(@"[Clean] %@", sciCleanState);
}
