#import "../../Utils.h"

%hook IGDirectThreadViewController
- (void)swipeableScrollManagerDidEndDraggingAboveSwipeThreshold:(id)arg1 {
    if ([SCIUtils getBoolPref:@"shh_mode_confirm"]) {
        SCILogV(@"[SCInsta] Confirm shh mode triggered");

        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}

- (void)shhModeTransitionButtonDidTap:(id)arg1 {
    if ([SCIUtils getBoolPref:@"shh_mode_confirm"]) {
        SCILogV(@"[SCInsta] Confirm shh mode triggered");

        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}

- (void)messageListViewControllerDidToggleShhMode:(id)arg1 {
    if ([SCIUtils getBoolPref:@"shh_mode_confirm"]) {
        SCILogV(@"[SCInsta] Confirm shh mode triggered");

        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}
%end

///
/// **450.1.0 moved two of the three handlers off `IGDirectThreadViewController`** (which lost 436 methods) onto
/// feature controllers with the same selector and the same `v24@0:8@16`. `-shhModeTransitionButtonDidTap:` was not found on any
/// class in 450, so the swipe and the toggle are what is covered there. Plain `%hook`s: on 410 and 439 the classes do not declare
/// these, and a hook nothing calls costs nothing.
///
%hook IGDirectThreadViewBottomSwipeFeatureController
- (void)swipeableScrollManagerDidEndDraggingAboveSwipeThreshold:(id)arg1 {
    if ([SCIUtils getBoolPref:@"shh_mode_confirm"]) {
        SCILogV(@"[SCInsta] Confirm shh mode triggered");

        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}
%end

%hook IGDirectThreadViewMessageListFeatureController
- (void)messageListViewControllerDidToggleShhMode:(id)arg1 {
    if ([SCIUtils getBoolPref:@"shh_mode_confirm"]) {
        SCILogV(@"[SCInsta] Confirm shh mode triggered");

        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}
%end
