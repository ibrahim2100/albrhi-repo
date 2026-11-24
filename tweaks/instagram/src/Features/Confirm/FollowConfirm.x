#import "../../Compat/SCIResolve.h"
#import "../../Utils.h"
#import "../../InstagramHeaders.h"

////////////////////////////////////////////////////////


////////////////////////////////////////////////////////

// Follow button on profile page
%hook IGFollowController
- (void)_didPressFollowButton {
    // Get user follow status (check if already following user)
    NSInteger UserFollowStatus = self.user.followStatus;

    // Only show confirm dialog if user is not following
    if (UserFollowStatus == 2) {
        if ([SCIUtils getBoolPref:@"follow_confirm"]) {
        SCILogV(@"[SCInsta] Confirm follow triggered");
        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
    }
    else {
        return %orig;
    }
}
%end

// Follow button on discover people page
%hook IGDiscoverPeopleButtonGroupView
- (void)_onFollowButtonTapped:(id)arg1 {
    if ([SCIUtils getBoolPref:@"follow_confirm"]) {
        SCILogV(@"[SCInsta] Confirm follow triggered");
        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}
- (void)_onFollowingButtonTapped:(id)arg1 {
    if ([SCIUtils getBoolPref:@"follow_confirm"]) {
        SCILogV(@"[SCInsta] Confirm follow triggered");
        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}
%end

// Suggested for you (home feed & profile) follow button
%hook IGHScrollAYMFCell
- (void)_didTapAYMFActionButton {
    if ([SCIUtils getBoolPref:@"follow_confirm"]) {
        SCILogV(@"[SCInsta] Confirm follow triggered");
        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}
%end
%hook IGHScrollAYMFActionButton
- (void)_didTapTextActionButton {
    if ([SCIUtils getBoolPref:@"follow_confirm"]) {
        SCILogV(@"[SCInsta] Confirm follow triggered");
        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}
%end

// Follow button on reels
%hook IGUnifiedVideoFollowButton
- (void)_hackilyHandleOurOwnButtonTaps:(id)arg1 event:(id)arg2 {
    if ([SCIUtils getBoolPref:@"follow_confirm"]) {
        SCILogV(@"[SCInsta] Confirm follow triggered");
        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}
%end

// Follow text on profile (when collapsed into top bar) 
%hook IGProfileViewController
- (void)navigationItemsControllerDidTapHeaderFollowButton:(id)arg1 {
    if ([SCIUtils getBoolPref:@"follow_confirm"]) {
        SCILogV(@"[SCInsta] Confirm follow triggered");
        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}
%end

// Follow button on suggested friends (in story section)
%hook IGStorySectionController
- (void)followButtonTapped:(id)arg1 cell:(id)arg2 {
    if ([SCIUtils getBoolPref:@"follow_confirm"]) {
        SCILogV(@"[SCInsta] Confirm follow triggered");
        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}
%end

// Follow all button in group chats (3+ members) people view
static void (*orig_listSectionController)(id, SEL, id, id);

static void hooked_listSectionController(id self, SEL _cmd, id arg1, id arg2) {
    if ([SCIUtils getBoolPref:@"follow_confirm"]) {

        [SCIUtils showConfirmation:^{
            orig_listSectionController(self, _cmd, arg1, arg2);
        }];

        return;
    }

    orig_listSectionController(self, _cmd, arg1, arg2);
}

///
/// **`IGFollowController` is a Swift class in 450.1.0 and 456.0.0 and its `-_didPressFollowButton` is gone**; it declares two entry points
/// instead (`-didPressFollowButtonFromControlEvent`, `v16@0:8`, and `-didPressFollowButtonWith:`, `v24@0:8@16`). Both are asked first. They are
/// two ways in (a control event and a model), found in a class dump of 456; **whether one calls the other through the Objective-C layer was not
/// established** (the only references to either sit in one Swift thunk), so if a follow ever asks twice the Diagnostics counter says so. Bound
/// through the resolver, and only where the class declares the selector.
///
%group SCIgIGFollowControllerSwift
%hook IGFollowController
- (void)didPressFollowButtonFromControlEvent {
    if ([SCIUtils getBoolPref:@"follow_confirm"]) {
        SCILogV(@"[SCInsta] Confirm follow triggered (Swift controller, control event)");
        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}
- (void)didPressFollowButtonWith:(id)arg1 {
    if ([SCIUtils getBoolPref:@"follow_confirm"]) {
        SCILogV(@"[SCInsta] Confirm follow triggered (Swift controller, model)");
        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}
%end
%end

%ctor {
    %init;

    Class followController = SCIResolveClass(@"IGFollowController");
    if (followController && class_getInstanceMethod(followController, NSSelectorFromString(@"didPressFollowButtonFromControlEvent"))) {
        %init(SCIgIGFollowControllerSwift, IGFollowController = followController);
    }

    Class cls = objc_getClass("IGDirectDetailMembersKit.IGDirectThreadDetailsMembersListViewController");
    if (!cls) return;

    MSHookMessageEx(
        cls,
        @selector(listSectionController:didTapHeaderButtonWithViewModel:),
        (IMP)hooked_listSectionController,
        (IMP *)&orig_listSectionController
    );
}
