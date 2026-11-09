//
//  SCITTExactCounts.x
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <string.h>
#import "SCITTExactCounts.h"
#import "../../Prefs.h"
#import "../../SCILog.h"

///
/// **The exact number, from TikTok's own getter on the component that draws it -- not from a model reached around it.**
///
/// VibeTok (unlicensed; architecture only, CLAUDE.md §2) reads `context.currentPageUser.followerCount` and rewrites the label after `-updateUI`.
/// 47.1.0's metadata shows the component answers the question itself, so this asks the component:
///
///   TTKProfileExternalUserRelationInfoFollowerComponent  -getFollowerCount        q16@0:8
///                                                        -p_shouldShowFollowerCount B16@0:8   -countLabel @16@0:8   -updateUI v16@0:8
///   TTKProfileExternalUserRelationInfoLikeComponent      -p_getLikeCount           q16@0:8
///                                                        -p_shouldShowLikeCount     B16@0:8   -countLabel @16@0:8   -updateUI v16@0:8
///
/// **When it writes, and when it does not -- the rule that makes this right for any account:**
///   * only after TikTok's own `-updateUI` has run, so everything TikTok decided (private counts, a loading state, a hidden list) is already on
///     the label;
///   * only when TikTok's own gate (`p_shouldShow…Count`) says the count is shown. A profile that hides its likes, a private follower list: the
///     gate answers NO and the label is left exactly as TikTok drew it;
///   * only for a count above zero. Zero is also what a getter answers before the data has arrived, and "0" is what TikTok draws for a real zero
///     anyway, so writing it could only ever replace a right answer with a wrong one;
///   * the number is a `long long` from the component, grouped in thousands with a comma and Latin digits whatever the phone's language. Below a
///     thousand it equals what TikTok drew, so nothing visibly changes.
///
/// **What this does not cover, and the report says which layout appeared.** TikTok has a second profile layout built from
/// `TTKProfileUserRelationInfoComponent` and one `TTKProfileUserRelationInfoItemComponent` per number (`socialStatisticFormatWithType:enterFrom:`,
/// `p_isInPersonalPageOptimize`). Which layout an account sees is TikTok's experiment, not a setting. It is not rewritten here (its count is
/// not exposed by a getter), and a hook that only *counts* its `-updateUI` calls is installed so that a report names it: "the other layout drawn N
/// times" is the signal that a person is seeing abbreviated numbers this switch cannot reach.
///
/// **Not seen on a screen**: the simulator copy has no account, and a guest's profile header arrives empty.
///

@interface TTKProfileExternalUserRelationInfoFollowerComponent : NSObject
- (long long)getFollowerCount;
- (BOOL)p_shouldShowFollowerCount;
- (id)countLabel;
@end

@interface TTKProfileExternalUserRelationInfoLikeComponent : NSObject
- (long long)p_getLikeCount;
- (BOOL)p_shouldShowLikeCount;
- (id)countLabel;
@end

@interface TTKProfileUserRelationInfoItemComponent : NSObject
@end

static NSUInteger sciFollowerSeen = 0, sciFollowerWritten = 0, sciFollowerHidden = 0, sciFollowerZero = 0;
static NSUInteger sciLikeSeen = 0, sciLikeWritten = 0, sciLikeHidden = 0, sciLikeZero = 0;
static NSUInteger sciOtherLayoutSeen = 0;
static NSString *sciLastFollower = nil, *sciLastLike = nil;
static NSString *sciExactState = nil;

/// `1234567` -> `1,234,567`, Latin digits whatever the phone's language.
static NSString *SCITTGrouped(long long number) {
    static NSNumberFormatter *formatter;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        formatter = [[NSNumberFormatter alloc] init];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"];
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
        formatter.usesGroupingSeparator = YES;
        formatter.groupingSeparator = @",";
        formatter.groupingSize = 3;
    });
    return [formatter stringFromNumber:@(number)];
}

/// Writes `number` into the label, or leaves it. Returns what was written, or nil.
static NSString *SCITTWriteCount(id label, long long number, BOOL shown, NSUInteger *hidden, NSUInteger *zero) {
    if (!shown) { (*hidden)++; return nil; }
    if (number <= 0) { (*zero)++; return nil; }
    if (![label respondsToSelector:@selector(setText:)] || ![label respondsToSelector:@selector(text)]) return nil;
    NSString *text = SCITTGrouped(number);
    if (!text.length) return nil;
    if ([[(UILabel *)label text] isEqualToString:text]) return text;
    [(UILabel *)label setText:text];
    return text;
}

%group SCITTExactFollowers
%hook TTKProfileExternalUserRelationInfoFollowerComponent

- (void)updateUI {
    %orig;
    sciFollowerSeen++;
    if (!SCIPrefEnabled(SCIPrefExactCounts)) return;
    NSString *written = SCITTWriteCount([self countLabel], [self getFollowerCount], [self p_shouldShowFollowerCount], &sciFollowerHidden, &sciFollowerZero);
    if (written) { sciFollowerWritten++; sciLastFollower = written; }
}

%end
%end

%group SCITTExactLikes
%hook TTKProfileExternalUserRelationInfoLikeComponent

- (void)updateUI {
    %orig;
    sciLikeSeen++;
    if (!SCIPrefEnabled(SCIPrefExactCounts)) return;
    NSString *written = SCITTWriteCount([self countLabel], [self p_getLikeCount], [self p_shouldShowLikeCount], &sciLikeHidden, &sciLikeZero);
    if (written) { sciLikeWritten++; sciLastLike = written; }
}

%end
%end

/// Counts only. Never touches a label.
%group SCITTExactOtherLayout
%hook TTKProfileUserRelationInfoItemComponent

- (void)updateUI {
    %orig;
    sciOtherLayoutSeen++;
}

%end
%end

NSString *SCITTExactCountsReport(void) {
    return [NSString stringWithFormat:
            @"%@; followers: updates %lu, written %lu (hidden by TikTok %lu, zero %lu, last %@); likes: updates %lu, written %lu (hidden %lu, zero %lu, last %@); "
            @"other layout (not rewritten) drawn %lu times",
            sciExactState ?: @"not installed",
            (unsigned long)sciFollowerSeen, (unsigned long)sciFollowerWritten, (unsigned long)sciFollowerHidden, (unsigned long)sciFollowerZero, sciLastFollower ?: @"—",
            (unsigned long)sciLikeSeen, (unsigned long)sciLikeWritten, (unsigned long)sciLikeHidden, (unsigned long)sciLikeZero, sciLastLike ?: @"—",
            (unsigned long)sciOtherLayoutSeen];
}

static BOOL SCITTCountsHas(Class cls, const char *selector, const char *encoding) {
    Method method = cls ? class_getInstanceMethod(cls, sel_registerName(selector)) : NULL;
    const char *types = method ? method_getTypeEncoding(method) : NULL;
    return types && strcmp(types, encoding) == 0;
}

void SCITTInstallExactCounts(void) {
    NSMutableArray<NSString *> *installed = [NSMutableArray array];
    NSMutableArray<NSString *> *skipped = [NSMutableArray array];

    Class follower = NSClassFromString(@"TTKProfileExternalUserRelationInfoFollowerComponent");
    if (SCITTCountsHas(follower, "updateUI", "v16@0:8") && SCITTCountsHas(follower, "getFollowerCount", "q16@0:8")
        && SCITTCountsHas(follower, "p_shouldShowFollowerCount", "B16@0:8") && SCITTCountsHas(follower, "countLabel", "@16@0:8")) {
        %init(SCITTExactFollowers);
        [installed addObject:@"followers"];
    } else {
        [skipped addObject:@"followers"];
    }

    Class like = NSClassFromString(@"TTKProfileExternalUserRelationInfoLikeComponent");
    if (SCITTCountsHas(like, "updateUI", "v16@0:8") && SCITTCountsHas(like, "p_getLikeCount", "q16@0:8")
        && SCITTCountsHas(like, "p_shouldShowLikeCount", "B16@0:8") && SCITTCountsHas(like, "countLabel", "@16@0:8")) {
        %init(SCITTExactLikes);
        [installed addObject:@"likes"];
    } else {
        [skipped addObject:@"likes"];
    }

    if (SCITTCountsHas(NSClassFromString(@"TTKProfileUserRelationInfoItemComponent"), "updateUI", "v16@0:8")) {
        %init(SCITTExactOtherLayout);
        [installed addObject:@"other layout (count only)"];
    } else {
        [skipped addObject:@"other layout (count only)"];
    }

    sciExactState = [NSString stringWithFormat:@"%@%@",
        installed.count ? [@"installed: " stringByAppendingString:[installed componentsJoinedByString:@", "]] : @"nothing installed",
        skipped.count ? [@" — skipped: " stringByAppendingString:[skipped componentsJoinedByString:@"; "]] : @""];
    SCILogV(@"[ExactCounts] %@", sciExactState);
}
