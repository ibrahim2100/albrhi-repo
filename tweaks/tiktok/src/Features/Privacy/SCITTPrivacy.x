#import <objc/runtime.h>
#import <string.h>
#import "SCITTPrivacy.h"
#import "../../Prefs.h"
#import "../../SCILog.h"
#import "../../Diagnostics/SCITTDiagnostics.h"

///
/// Three confirmed points where the app tells TikTok's own servers what was seen,
/// cross-validated between NA9 For TikTok and VibeTok -- both independently hook the
/// same three selectors, which is the same "two references agree" bar the rest of
/// this project holds a finding to before hooking it.
///
///   TTKStoryNetworkService +reportStoryViewedWithStoryID:uid:… a story was opened
///   AWEIMMessageReadComponent -p_markReadSyncToServerWithMessage:
///                                                       a DM was read
///   TTKProfileViewsVisitor -reportProfileView /
///                          -p_shouldReportProfileView   a profile was visited
///
/// The message case is the one worth being careful about: TikTok keeps a *local*
/// mark-as-read selector, `-p_markMessageAsReadLocally:`, entirely separate from the
/// one that syncs it outward. Only the sync method is hooked here, left untouched
/// otherwise, so the conversation's own unread badge still clears normally on this
/// device -- the same distinction Instagram's own story-seen feature draws between a
/// local record and the receipt built from it.
///

@interface TTKStoryNetworkService : NSObject
@end

@interface AWEIMMessageReadComponent : NSObject
@end

@interface TTKProfileViewsVisitor : NSObject
@end


///
/// **The story report is a class method of the network service, and it was hooked on the wrong class for
/// as long as this file existed.** `TTKStoryMarkReadService` is a Swift class: the runtime sees `-init`,
/// `-initWithContext:`, `-readItemIDs` and `-setReadItemIDs:` and nothing else, so a hook on `-markAsRead:`
/// *added* a method nobody sends, in 46.4.0 and in 47.1.0 alike -- "installed" in the log and silent in the
/// app. What actually goes to the server is `+[TTKStoryNetworkService reportStoryViewedWithStoryID:uid:completion:]`
/// and its `unlocked:` sibling (both declared, class methods, encodings read from the dumps). The local mark
/// that greys a story's ring (`-[TTKStoryManager markStoryReaded:]`) is a different selector and is left alone,
/// so the story still looks watched on this phone. The completion is not called: nothing was sent, and TikTok's
/// own in-flight set keeps the id for the session, which only stops it asking twice.
///
%group PrivacyStory
%hook TTKStoryNetworkService

+ (void)reportStoryViewedWithStoryID:(id)storyID uid:(id)uid completion:(id)completion {
    if (!SCIPrefEnabled(SCIPrefPrivacyStory)) {
        %orig;
        return;
    }
    [SCITTDiagnostics recordPrivacyAnswer:@"story view report withheld"];
}

+ (void)reportStoryViewedWithStoryID:(id)storyID uid:(id)uid unlocked:(id)unlocked completion:(id)completion {
    if (!SCIPrefEnabled(SCIPrefPrivacyStory)) {
        %orig;
        return;
    }
    [SCITTDiagnostics recordPrivacyAnswer:@"story view report withheld"];
}

%end
%end

%group PrivacyMessages
%hook AWEIMMessageReadComponent

- (void)p_markReadSyncToServerWithMessage:(id)message {
    if (!SCIPrefEnabled(SCIPrefPrivacyMessages)) {
        %orig;
        return;
    }
    [SCITTDiagnostics recordPrivacyAnswer:@"message read-sync withheld"];
}

%end
%end

%group PrivacyProfile
%hook TTKProfileViewsVisitor

- (void)reportProfileView {
    if (!SCIPrefEnabled(SCIPrefPrivacyProfile)) {
        %orig;
        return;
    }
    [SCITTDiagnostics recordPrivacyAnswer:@"profile view withheld"];
}

- (BOOL)p_shouldReportProfileView {
    if (!SCIPrefEnabled(SCIPrefPrivacyProfile)) return %orig;
    [SCITTDiagnostics recordPrivacyAnswer:@"profile view withheld"];
    return NO;
}

// Two more of this same class's own selectors, found in the same NA9/VibeTok symbol
// tables the three above came from and confirmed present in TikTok 46.4.0's own
// binary the same way -- -visit: is the entry point both references hook alongside
// -reportProfileView, and this gate answers a second, separate "has this already been
// reported" question the other two do not. (47.1.0 added a report cooldown beside them,
// `-p_hitReportCooldown`; every path to it goes through these four.)
- (void)visit:(id)profile {
    if (!SCIPrefEnabled(SCIPrefPrivacyProfile)) {
        %orig;
        return;
    }
    [SCITTDiagnostics recordPrivacyAnswer:@"profile view withheld"];
}

- (BOOL)p_shouldReportHasVeiwedProfileForUser:(id)user {
    if (!SCIPrefEnabled(SCIPrefPrivacyProfile)) return %orig;
    [SCITTDiagnostics recordPrivacyAnswer:@"profile view withheld"];
    return NO;
}

%end
%end


static BOOL SCITTPrivacyHas(Class cls, BOOL meta, const char *selector, const char *encoding) {
    if (!cls) return NO;
    Method method = meta ? class_getClassMethod(cls, sel_registerName(selector))
                         : class_getInstanceMethod(cls, sel_registerName(selector));
    const char *types = method ? method_getTypeEncoding(method) : NULL;
    return types && strcmp(types, encoding) == 0;
}

void SCITTInstallPrivacy(void) {
    Class story = NSClassFromString(@"TTKStoryNetworkService");
    if (SCITTPrivacyHas(story, YES, "reportStoryViewedWithStoryID:uid:completion:", "v40@0:8@16@24@?32") &&
        SCITTPrivacyHas(story, YES, "reportStoryViewedWithStoryID:uid:unlocked:completion:", "v48@0:8@16@24@32@?40")) {
        %init(PrivacyStory);
        SCILogV(@"privacy: story report attached");
    } else {
        SCILogV(@"privacy: story report selectors absent or differently typed -- not attached");
    }

    Class message = NSClassFromString(@"AWEIMMessageReadComponent");
    if (SCITTPrivacyHas(message, NO, "p_markReadSyncToServerWithMessage:", "v24@0:8@16")) {
        %init(PrivacyMessages);
        SCILogV(@"privacy: message read-sync attached");
    } else {
        SCILogV(@"privacy: message read-sync selector absent or differently typed -- not attached");
    }

    Class visitor = NSClassFromString(@"TTKProfileViewsVisitor");
    if (SCITTPrivacyHas(visitor, NO, "reportProfileView", "v16@0:8") &&
        SCITTPrivacyHas(visitor, NO, "p_shouldReportProfileView", "B16@0:8") &&
        SCITTPrivacyHas(visitor, NO, "visit:", "v24@0:8@16") &&
        SCITTPrivacyHas(visitor, NO, "p_shouldReportHasVeiwedProfileForUser:", "B24@0:8@16")) {
        %init(PrivacyProfile);
        SCILogV(@"privacy: profile view attached");
    } else {
        SCILogV(@"privacy: profile-view selectors absent or differently typed -- not attached");
    }
}
