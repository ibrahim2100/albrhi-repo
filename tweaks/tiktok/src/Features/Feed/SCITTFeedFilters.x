//
//  SCITTFeedFilters.x
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "SCITTFeedFilters.h"
#import "../../Prefs.h"
#import "../../SCILog.h"
#import "../../Localization/SCILocalize.h"
#import "../../UI/SCITTToast.h"

///
/// **Four decisions TikTok takes about what to show, answered where it takes them.**
///
/// The idea of each came from a published feature list (ASJTok, unlicensed, read for its list of features only -- it has no source in its
/// repository); every class and selector below was then read out of 46.4.0's own `MusicallyCore` with tools/objc-classes.py before a line was
/// written, and each group installs only where the build declares the selector with the encoding it was written against.
///
/// Nothing here is a view hidden after the fact: a suggestion is refused at the decision that inserts it, a LIVE item at the model's
/// construction, a label at the flag that decides it, a length at the getter the input asks.
///

static NSUInteger sciSuggestedRefused = 0, sciLongCommentLifted = 0, sciCommentsOpened = 0;
static NSUInteger sciModelsLive = 0, sciModelsSuggested = 0, sciLiveSurfaces = 0;
static NSUInteger sciSortForced = 0, sciCountsSeen = 0, sciCountsShown = 0;
static NSMutableDictionary<NSString *, NSDate *> *sciCountShown = nil;
static NSString *sciFeedFiltersState = nil;

BOOL SCITTModelIsFilteredOut(id model) {
    if (!model) return NO;

    if (SCIPrefEnabled(SCIPrefHideLive) && [model respondsToSelector:@selector(isLive)] && ((BOOL (*)(id, SEL))objc_msgSend)(model, @selector(isLive))) {
        sciModelsLive++;
        return YES;
    }

    if (SCIPrefEnabled(SCIPrefSkipSuggested)) {
        if (([model respondsToSelector:@selector(isRecommendUserCard)] && ((BOOL (*)(id, SEL))objc_msgSend)(model, @selector(isRecommendUserCard))) ||
            ([model respondsToSelector:@selector(isUserRecommendBigCard)] && ((BOOL (*)(id, SEL))objc_msgSend)(model, @selector(isUserRecommendBigCard)))) {
            sciModelsSuggested++;
            return YES;
        }
    }
    return NO;
}

static BOOL SCITTHasInstance(Class cls, const char *selector, const char *encoding) {
    if (!cls) return NO;
    Method method = class_getInstanceMethod(cls, sel_registerName(selector));
    const char *types = method ? method_getTypeEncoding(method) : NULL;
    return types && strcmp(types, encoding) == 0;
}

%group SCITTSuggestedGates
%hook TTKFeedUserRecommendManager

- (BOOL)canInsertRecommendedUsersInFYPAwemeList:(id)list loadMoreTimes:(long long)times pullType:(long long)pull offset:(long long)offset {
    if (!SCIPrefEnabled(SCIPrefSkipSuggested)) return %orig;
    sciSuggestedRefused++;
    return NO;
}

- (BOOL)canFetchRecommendedUsersForFYPWithLoadMoreTimes:(long long)times {
    if (!SCIPrefEnabled(SCIPrefSkipSuggested)) return %orig;
    sciSuggestedRefused++;
    return NO;
}

- (BOOL)canInsertRecommendedUsersInFriendsTabAwemeList:(id)list pullType:(long long)pull offset:(long long)offset {
    if (!SCIPrefEnabled(SCIPrefSkipSuggested)) return %orig;
    sciSuggestedRefused++;
    return NO;
}

- (BOOL)canFetchRecommendedUsersForFriendsTab {
    if (!SCIPrefEnabled(SCIPrefSkipSuggested)) return %orig;
    sciSuggestedRefused++;
    return NO;
}

- (BOOL)canInsertRecommendedUsersInFCPWithLoadMoreTimes:(long long)times {
    if (!SCIPrefEnabled(SCIPrefSkipSuggested)) return %orig;
    sciSuggestedRefused++;
    return NO;
}

%end
%end

%group SCITTLongCommentsGroup
%hook AWETextInputController

- (unsigned long long)maxLength {
    unsigned long long limit = %orig;
    if (!SCIPrefEnabled(SCIPrefLongComments)) return limit;

    // Only a limit of comment size is lifted: a field limited to a handful of characters (a name, a tag) is not a comment box, and the server
    // would refuse a long one.
    if (limit >= 100 && limit < 500) {
        sciLongCommentLifted++;
        return 500;
    }
    return limit;
}

%end
%end

%group SCITTClosedCommentsGroup
%hook AWEAwemeModel

- (BOOL)isForbidComment {
    BOOL closed = %orig;
    if (!closed || !SCIPrefEnabled(SCIPrefDisabledComments)) return closed;
    sciCommentsOpened++;
    return NO;
}

%end
%end

%group SCITTProfileSortGroup
%hook TTKProfileTabBarSortManager

- (BOOL)shouldShowSort {
    if (!SCIPrefEnabled(SCIPrefSortAnyProfile)) return %orig;
    sciSortForced++;
    return YES;
}

- (BOOL)canRespondSortMethod {
    if (!SCIPrefEnabled(SCIPrefSortAnyProfile)) return %orig;
    sciSortForced++;
    return YES;
}

%end
%end

%group SCITTProfileCountGroup
%hook TTKProfileTabBarSortManager

- (instancetype)initWithUserID:(id)userID awemeCount:(long long)count {
    id built = %orig;
    sciCountsSeen++;
    if (!SCIPrefEnabled(SCIPrefVideoCount) || count < 0) return built;

    // Once per account every ten minutes: a profile's tab bar is rebuilt when its page reloads, and a banner each time would be noise.
    NSString *key = [userID description] ?: @"";
    if (!sciCountShown) sciCountShown = [NSMutableDictionary dictionary];
    NSDate *last = sciCountShown[key];
    if (last && [[NSDate date] timeIntervalSinceDate:last] < 600) return built;
    sciCountShown[key] = [NSDate date];

    sciCountsShown++;
    NSString *text = [NSString stringWithFormat:SCILocalized(@"video_count_text"), (long long)count];
    dispatch_async(dispatch_get_main_queue(), ^{ [SCITTToast noticeWithText:text symbol:@"person.crop.circle"]; });
    return built;
}

%end
%end

%group SCITTLiveSurfacesGroup

/// **The LIVE the eye sees is not the LIVE item in the list.** Dropping a LIVE `AWEAwemeModel` where it is built
/// (above) removes the video that is a live room, and leaves the other places TikTok puts LIVE: the badge in the
/// feed's top bar (`AWEFeedContainerViewController`'s `MTLiveEntranceView`, with a left and a right placement) and the
/// "someone you follow is live" bubble (`AWETopLiveBubbleManager`). Both are decided by a BOOL the app already asks
/// before it draws anything, so answering NO is the app's own "not now" path rather than a view hidden after.
%hook AWEFeedContainerViewController

- (BOOL)_shouldShowMTLiveEntranceView {
    if (!SCIPrefEnabled(SCIPrefHideLive)) return %orig;
    sciLiveSurfaces++;
    return NO;
}

- (BOOL)_shouldShowMTLiveEntranceViewOnLeft {
    if (!SCIPrefEnabled(SCIPrefHideLive)) return %orig;
    sciLiveSurfaces++;
    return NO;
}

- (BOOL)_shouldShowMTLiveEntranceViewOnRight {
    if (!SCIPrefEnabled(SCIPrefHideLive)) return %orig;
    sciLiveSurfaces++;
    return NO;
}

- (BOOL)shouldShowLiveBadge {
    if (!SCIPrefEnabled(SCIPrefHideLive)) return %orig;
    sciLiveSurfaces++;
    return NO;
}

%end
%end

%group SCITTLiveBubbleGroup
%hook AWETopLiveBubbleManager

- (BOOL)canShow {
    if (!SCIPrefEnabled(SCIPrefHideLive)) return %orig;
    sciLiveSurfaces++;
    return NO;
}

%end
%end

NSString *SCITTFeedFiltersReport(void) {
    return [NSString stringWithFormat:@"%@; suggested: %lu gate answers refused, %lu cards dropped at construction; LIVE dropped: %lu items + %lu surface answers; comment limit lifted: %lu; closed comments opened: %lu; profile sort forced: %lu; video counts: %lu seen, %lu shown",
            sciFeedFiltersState ?: @"not installed",
            (unsigned long)sciSuggestedRefused, (unsigned long)sciModelsSuggested, (unsigned long)sciModelsLive, (unsigned long)sciLiveSurfaces,
            (unsigned long)sciLongCommentLifted, (unsigned long)sciCommentsOpened,
            (unsigned long)sciSortForced, (unsigned long)sciCountsSeen, (unsigned long)sciCountsShown];
}

void SCITTInstallFeedFilters(void) {
    NSMutableArray *installed = [NSMutableArray array], *skipped = [NSMutableArray array];

    Class manager = NSClassFromString(@"TTKFeedUserRecommendManager");
    if (SCITTHasInstance(manager, "canInsertRecommendedUsersInFYPAwemeList:loadMoreTimes:pullType:offset:", "B48@0:8@16q24q32q40")
        && SCITTHasInstance(manager, "canFetchRecommendedUsersForFYPWithLoadMoreTimes:", "B24@0:8q16")
        && SCITTHasInstance(manager, "canInsertRecommendedUsersInFriendsTabAwemeList:pullType:offset:", "B40@0:8@16q24q32")
        && SCITTHasInstance(manager, "canFetchRecommendedUsersForFriendsTab", "B16@0:8")
        && SCITTHasInstance(manager, "canInsertRecommendedUsersInFCPWithLoadMoreTimes:", "B24@0:8q16")) {
        %init(SCITTSuggestedGates); [installed addObject:@"suggested gates"];
    } else { [skipped addObject:@"TTKFeedUserRecommendManager gates"]; }

    if (SCITTHasInstance(NSClassFromString(@"AWETextInputController"), "maxLength", "Q16@0:8")) {
        %init(SCITTLongCommentsGroup); [installed addObject:@"comment length"];
    } else { [skipped addObject:@"AWETextInputController -maxLength"]; }

    if (SCITTHasInstance(NSClassFromString(@"AWEAwemeModel"), "isForbidComment", "B16@0:8")) {
        %init(SCITTClosedCommentsGroup); [installed addObject:@"closed comments"];
    } else { [skipped addObject:@"AWEAwemeModel -isForbidComment"]; }

    Class sorter = NSClassFromString(@"TTKProfileTabBarSortManager");
    if (SCITTHasInstance(sorter, "shouldShowSort", "B16@0:8") && SCITTHasInstance(sorter, "canRespondSortMethod", "B16@0:8")) {
        %init(SCITTProfileSortGroup); [installed addObject:@"profile sort"];
    } else { [skipped addObject:@"TTKProfileTabBarSortManager sort gates"]; }

    if (SCITTHasInstance(sorter, "initWithUserID:awemeCount:", "@32@0:8@16q24")) {
        %init(SCITTProfileCountGroup); [installed addObject:@"video count"];
    } else { [skipped addObject:@"TTKProfileTabBarSortManager -initWithUserID:awemeCount:"]; }

    Class container = NSClassFromString(@"AWEFeedContainerViewController");
    if (SCITTHasInstance(container, "_shouldShowMTLiveEntranceView", "B16@0:8")
        && SCITTHasInstance(container, "_shouldShowMTLiveEntranceViewOnLeft", "B16@0:8")
        && SCITTHasInstance(container, "_shouldShowMTLiveEntranceViewOnRight", "B16@0:8")
        && SCITTHasInstance(container, "shouldShowLiveBadge", "B16@0:8")) {
        %init(SCITTLiveSurfacesGroup); [installed addObject:@"LIVE badge"];
    } else { [skipped addObject:@"AWEFeedContainerViewController LIVE gates"]; }

    if (SCITTHasInstance(NSClassFromString(@"AWETopLiveBubbleManager"), "canShow", "B16@0:8")) {
        %init(SCITTLiveBubbleGroup); [installed addObject:@"LIVE bubble"];
    } else { [skipped addObject:@"AWETopLiveBubbleManager -canShow"]; }

    sciFeedFiltersState = [NSString stringWithFormat:@"installed: %@%@",
                           installed.count ? [installed componentsJoinedByString:@", "] : @"none",
                           skipped.count ? [@" — skipped: " stringByAppendingString:[skipped componentsJoinedByString:@", "]] : @""];
    SCILogV(@"[FeedFilters] %@", sciFeedFiltersState);
}
