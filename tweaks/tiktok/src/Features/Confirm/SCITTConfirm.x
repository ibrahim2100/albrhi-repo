#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "SCITTConfirm.h"
#import "../../Prefs.h"
#import "../../SCILog.h"
#import "../../Localization/SCILocalize.h"
#import "../../UI/SCITTSheet.h"

///
/// Ask before a like, ask before a follow.
///
/// **Every hook point here was confirmed against the real TikTok 46.4.0 framework, with its type
/// encoding read rather than assumed** -- `tools/objc-classes.py` now prints encodings beside
/// selectors for exactly this, after a hook declared from a selector's *name* crashed the app
/// repeatedly (a `^q` out-parameter written as an `NSInteger`, a `void` return written as `id`):
///
///   TTKFeedInteractionLikeManager   -onLikeButtonClicked          v16@0:8
///   TTKFeedInteractionLikeManager   -doubleTapLikeWithAnimation:   v24@0:8@16
///   AWEPlayInteractionUserAvatarElement  -onFollowViewClicked:     v24@0:8@16
///   AWEIMProfileRelationView        -p_didTapFollowButton          v16@0:8
///
/// Both reference tweaks hook the same four, which is as much corroboration as this project ever
/// gets -- but the encodings are ours, from our build, because a working tweak's selector list is
/// what worked for its author.
///
/// **The one design decision worth reading: `%orig` is never captured in a block.** A confirmation
/// is asynchronous -- the answer arrives after the method has already returned -- so the obvious
/// shape is to call `%orig` from the alert's handler, and `%orig` inside a block is exactly the
/// fragile Logos construct this project's own toolchain notes warn about. Instead the action is
/// *replayed*: a flag is raised, the same selector is sent to the same object, and the hook lets it
/// through untouched. That also makes nesting safe by construction -- if TikTok's double-tap path
/// calls the button path internally, the inner call sees the flag and asks nothing.
///

@interface TTKFeedInteractionLikeManager : NSObject
- (void)onLikeButtonClicked;
- (void)doubleTapLikeWithAnimation:(id)animation;
@end

@interface AWEPlayInteractionUserAvatarElement : NSObject
- (void)onFollowViewClicked:(id)sender;
@end

@interface AWEIMProfileRelationView : UIView
- (void)p_didTapFollowButton;
@end

// A comment's heart and thumbs-down. Both are target-actions of the cell (`-onLikeAction:` / `-onDislikeAction:`, `v24@0:8@16`, read
// from TikTok 47.4.0); the model is the cell's `-commentModel` and says whether the heart is already on (`-userDigged`, `B16@0:8`).
@interface AWECommentModel : NSObject
- (BOOL)userDigged;
@end

@interface AWECommentPanelBaseCell : UITableViewCell
- (void)onLikeAction:(id)sender;
- (void)onDislikeAction:(id)sender;
- (id)commentModel;
@end

/// Raised only while a confirmed action is being replayed.
///
/// Read and written on the main thread alone -- every one of these hooks is a tap handler, and the
/// replay happens inside a `UIAlertAction` handler, which UIKit runs on the main thread. A lock here
/// would be answering a question that cannot be asked.
static BOOL sciReplaying = NO;

static NSUInteger sciAsked = 0;
static NSUInteger sciAllowed = 0;

/// There is no third counter, and that is deliberate: a refusal is `asked - allowed`.
///
/// A cancel *button* handler would have missed the sheet being dismissed by a tap outside it, which
/// is an answer of no that no button reports — so a counter incremented in that handler would have
/// disagreed with the other two, and the first attempt at this file set one from the difference at
/// ask time, when the answer had not arrived yet. Deriving it at report time is the only version
/// that cannot drift.

/// Which of the four attached, recorded at install so "it never asks" is not four silent causes.
static NSMutableArray<NSString *> *sciAttached = nil;

///
/// Asks, and calls `proceed` only on yes.
///
/// **The question is asked in the tweak's own sheet, not in a `UIAlertController`, and that was a
/// deliberate replacement.** A system alert appearing over TikTok's black feed reads as an error
/// dialog from the app rather than as a setting the person turned on themselves -- and it looked
/// like nothing else this tweak draws, while the saving banner and the feed button share one dark
/// blurred material. `SCITTSheet` also needs no view controller to present from, which removes the
/// whole class of failure where TikTok already has something presented.
///
/// **When there is nowhere to ask, the action happens.** A confirmation that cannot be presented
/// must not become a silent refusal: that would turn "ask me first" into "liking is broken", which
/// is the same mistake as hiding the download button whenever its preferred model lookup failed.
/// The point of a confirmation is the question, and if the question cannot be put, the tap the user
/// actually made is the best available answer.
///
static void SCITTAsk(NSString *title, NSString *symbol, void (^proceed)(void)) {
    if (![SCITTSheet canPresent]) {
        SCILogV(@"confirm: nowhere to present, letting it through");
        proceed();
        return;
    }

    sciAsked++;

    [SCITTSheet showTitle:title
                  message:nil
                   symbol:symbol
                  actions:@[
        [SCITTSheetAction title:SCILocalized(@"confirm_yes")
                         symbol:@"checkmark"
                        primary:YES
                        handler:^{
            sciAllowed++;
            proceed();
        }],
    ]
                   cancel:SCILocalized(@"photos_cancel")];
}


%group Confirm

%hook TTKFeedInteractionLikeManager

- (void)onLikeButtonClicked {
    if (sciReplaying || !SCIPrefEnabled(SCIPrefConfirmLike)) {
        %orig;
        return;
    }

    SCITTAsk(SCILocalized(@"confirm_like_title"), @"heart.fill", ^{
        sciReplaying = YES;
        [self onLikeButtonClicked];
        sciReplaying = NO;
    });
}

// The double tap on the video itself, which is where an accidental like actually comes from --
// hooked separately because it is a separate entry point, not a caller of the one above on every
// build. Its argument is an object (`v24@0:8@16`), carried through the replay unchanged rather
// than reconstructed.
- (void)doubleTapLikeWithAnimation:(id)animation {
    if (sciReplaying || !SCIPrefEnabled(SCIPrefConfirmLike)) {
        %orig;
        return;
    }

    SCITTAsk(SCILocalized(@"confirm_like_title"), @"heart.fill", ^{
        sciReplaying = YES;
        [self doubleTapLikeWithAnimation:animation];
        sciReplaying = NO;
    });
}

%end

%hook AWEPlayInteractionUserAvatarElement

// The follow button on the feed's own rail, beside the avatar.
- (void)onFollowViewClicked:(id)sender {
    if (sciReplaying || !SCIPrefEnabled(SCIPrefConfirmFollow)) {
        %orig;
        return;
    }

    SCITTAsk(SCILocalized(@"confirm_follow_title"), @"person.badge.plus", ^{
        sciReplaying = YES;
        [self onFollowViewClicked:sender];
        sciReplaying = NO;
    });
}

%end

%hook AWEIMProfileRelationView

// The follow button on a profile page and in a chat's own profile header. A different surface with
// its own selector, so following from a profile is asked about too -- otherwise the switch would
// only cover the feed and read as unreliable rather than as scoped.
- (void)p_didTapFollowButton {
    if (sciReplaying || !SCIPrefEnabled(SCIPrefConfirmFollow)) {
        %orig;
        return;
    }

    SCITTAsk(SCILocalized(@"confirm_follow_title"), @"person.badge.plus", ^{
        sciReplaying = YES;
        [self p_didTapFollowButton];
        sciReplaying = NO;
    });
}

%end

%end


%group ConfirmComments

%hook AWECommentPanelBaseCell

- (void)onLikeAction:(id)sender {
    if (sciReplaying || !SCIPrefEnabled(SCIPrefConfirmCommentLike)) {
        %orig;
        return;
    }

    // Taking a heart back is never asked about -- the same rule as an unlike or an unfollow on the video. When the model cannot say
    // (a build that renamed the getter), the tap is asked about: a question too many is better than a heart nobody meant.
    id model = [self respondsToSelector:@selector(commentModel)] ? [self commentModel] : nil;
    BOOL alreadyLiked = model && [model respondsToSelector:@selector(userDigged)] && [(AWECommentModel *)model userDigged];
    if (alreadyLiked) {
        %orig;
        return;
    }

    SCITTAsk(SCILocalized(@"confirm_comment_like_title"), @"heart.fill", ^{
        sciReplaying = YES;
        [self onLikeAction:sender];
        sciReplaying = NO;
    });
}

- (void)onDislikeAction:(id)sender {
    if (sciReplaying || !SCIPrefEnabled(SCIPrefConfirmCommentDislike)) {
        %orig;
        return;
    }

    SCITTAsk(SCILocalized(@"confirm_comment_dislike_title"), @"hand.thumbsdown.fill", ^{
        sciReplaying = YES;
        [self onDislikeAction:sender];
        sciReplaying = NO;
    });
}

%end
%end


void SCITTInstallConfirm(void) {
    sciAttached = [NSMutableArray array];

    // Recorded from the runtime rather than assumed from the hook list: a `%hook` on a class this
    // build does not carry attaches nothing and says nothing, which is how a feature is reported
    // missing for releases while its switch is on.
    if (NSClassFromString(@"TTKFeedInteractionLikeManager")) [sciAttached addObject:@"like"];
    if (NSClassFromString(@"AWEPlayInteractionUserAvatarElement")) [sciAttached addObject:@"follow (feed)"];
    if (NSClassFromString(@"AWEIMProfileRelationView")) [sciAttached addObject:@"follow (profile)"];

    // The comment cell is its own group: a build whose cell lacks either action must not cost the video's like and follow.
    Class cell = NSClassFromString(@"AWECommentPanelBaseCell");
    Method like = cell ? class_getInstanceMethod(cell, sel_registerName("onLikeAction:")) : NULL;
    Method dislike = cell ? class_getInstanceMethod(cell, sel_registerName("onDislikeAction:")) : NULL;
    const char *likeTypes = like ? method_getTypeEncoding(like) : NULL;
    const char *dislikeTypes = dislike ? method_getTypeEncoding(dislike) : NULL;
    if (likeTypes && dislikeTypes && strcmp(likeTypes, "v24@0:8@16") == 0 && strcmp(dislikeTypes, "v24@0:8@16") == 0) {
        %init(ConfirmComments);
        [sciAttached addObject:@"comment like/dislike"];
    }

    %init(Confirm);
    SCILogV(@"confirmations installed: %@", [sciAttached componentsJoinedByString:@", "]);
}

NSString *SCITTConfirmReport(void) {
    NSString *where = sciAttached.count
        ? [sciAttached componentsJoinedByString:@", "]
        : @"no confirmation class in this build";

    NSString *on = [NSString stringWithFormat:@"like %@ · follow %@ · comment like %@ · comment dislike %@",
        SCIPrefEnabled(SCIPrefConfirmLike) ? @"on" : @"off",
        SCIPrefEnabled(SCIPrefConfirmFollow) ? @"on" : @"off",
        SCIPrefEnabled(SCIPrefConfirmCommentLike) ? @"on" : @"off",
        SCIPrefEnabled(SCIPrefConfirmCommentDislike) ? @"on" : @"off"];

    // Three counters, not one. "It never asked" and "it asked and I cancelled every time" are the
    // same number of likes and completely different findings -- the tally-versus-snapshot rule from
    // CLAUDE.md, applied before it costs a release this time.
    return [NSString stringWithFormat:@"%@ | %@ | asked %lu, allowed %lu, refused %lu",
        on, where, (unsigned long)sciAsked, (unsigned long)sciAllowed,
        (unsigned long)(sciAsked - sciAllowed)];
}
