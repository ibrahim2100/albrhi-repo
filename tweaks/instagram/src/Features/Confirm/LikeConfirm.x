#import "../../Utils.h"
#import "shared/src/SCIKVC.h"
#import "../../Compat/SCIResolve.h"

///////////////////////////////////////////////////////////

// Confirmation handlers




///////////////////////////////////////////////////////////

// Liking posts
%hook IGUFIButtonBarView
- (void)_onLikeButtonPressed:(id)arg1 {
    if ([SCIUtils getBoolPref:@"like_confirm"]) {
        SCILogV(@"[SCInsta] Confirm post like triggered");
        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}
%end
%hook IGFeedPhotoView
- (void)_onDoubleTap:(id)arg1 {
    if ([SCIUtils getBoolPref:@"like_confirm"]) {
        SCILogV(@"[SCInsta] Confirm post like triggered");
        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}
%end
%group SCIgIGVideoPlayerOverlayContainerView

%hook IGVideoPlayerOverlayContainerView
- (void)_handleDoubleTapGesture:(id)arg1 {
    if ([SCIUtils getBoolPref:@"like_confirm"]) {
        SCILogV(@"[SCInsta] Confirm post like triggered");
        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}
%end

%end


// Liking reels
%hook IGSundialViewerVideoCell
- (void)controlsOverlayControllerDidTapLikeButton:(id)arg1 {
    if ([SCIUtils getBoolPref:@"like_confirm_reels"]) {
        SCILogV(@"[SCInsta] Confirm reels like triggered");
        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}
- (void)controlsOverlayControllerDidLongPressLikeButton:(id)arg1 gestureRecognizer:(id)arg2 {
    if ([SCIUtils getBoolPref:@"like_confirm_reels"]) {
        SCILogV(@"[SCInsta] Confirm reels like triggered");
        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}
- (void)gestureController:(id)arg1 didObserveDoubleTap:(id)arg2 {
    if ([SCIUtils getBoolPref:@"like_confirm_reels"]) {
        SCILogV(@"[SCInsta] Confirm reels like triggered");
        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}
%end
%hook IGSundialViewerPhotoCell
- (void)controlsOverlayControllerDidTapLikeButton:(id)arg1 {
    if ([SCIUtils getBoolPref:@"like_confirm_reels"]) {
        SCILogV(@"[SCInsta] Confirm reels like triggered");
        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}
- (void)gestureController:(id)arg1 didObserveDoubleTap:(id)arg2 {
    if ([SCIUtils getBoolPref:@"like_confirm_reels"]) {
        SCILogV(@"[SCInsta] Confirm reels like triggered");
        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}
%end
%hook IGSundialViewerCarouselCell
- (void)controlsOverlayControllerDidTapLikeButton:(id)arg1 {
    if ([SCIUtils getBoolPref:@"like_confirm_reels"]) {
        SCILogV(@"[SCInsta] Confirm reels like triggered");
        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}
- (void)gestureController:(id)arg1 didObserveDoubleTap:(id)arg2 {
    if ([SCIUtils getBoolPref:@"like_confirm_reels"]) {
        SCILogV(@"[SCInsta] Confirm reels like triggered");
        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}
%end

// Liking comments
%hook IGCommentCellController
- (void)commentCell:(id)arg1 didTapLikeButton:(id)arg2 {
    if ([SCIUtils getBoolPref:@"like_confirm"]) {
        SCILogV(@"[SCInsta] Confirm post like triggered");
        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}
- (void)commentCell:(id)arg1 didTapLikedByButtonForUser:(id)arg2 {
    if ([SCIUtils getBoolPref:@"like_confirm"]) {
        SCILogV(@"[SCInsta] Confirm post like triggered");
        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}
- (void)commentCellDidLongPressOnLikeButton:(id)arg1 {
    if ([SCIUtils getBoolPref:@"like_confirm"]) {
        SCILogV(@"[SCInsta] Confirm post like triggered");
        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}
- (void)commentCellDidEndLongPressOnLikeButton:(id)arg1 {
    if ([SCIUtils getBoolPref:@"like_confirm"]) {
        SCILogV(@"[SCInsta] Confirm post like triggered");
        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}
- (void)commentCellDidDoubleTap:(id)arg1 {
    if ([SCIUtils getBoolPref:@"like_confirm"]) {
        SCILogV(@"[SCInsta] Confirm post like triggered");
        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}
%end
%hook IGFeedItemPreviewCommentCell
- (void)_didTapLikeButton {
    if ([SCIUtils getBoolPref:@"like_confirm"]) {
        SCILogV(@"[SCInsta] Confirm post like triggered");
        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}
%end

// Liking stories
%group SCIgIGStoryFullscreenDefaultFooterView

%hook IGStoryFullscreenDefaultFooterView
- (void)_handleLikeTapped {
    if ([SCIUtils getBoolPref:@"like_confirm"]) {
        SCILogV(@"[SCInsta] Confirm post like triggered");
        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}
- (void)_likeTapped {
    if ([SCIUtils getBoolPref:@"like_confirm"]) {
        SCILogV(@"[SCInsta] Confirm post like triggered");
        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}
- (void)inputView:(id)arg1 didTapLikeButton:(id)arg2 {
    if ([SCIUtils getBoolPref:@"like_confirm"]) {
        SCILogV(@"[SCInsta] Confirm post like triggered");
        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}

// For some stupid reason they removed the "liketapped" methods on newer Instagram versions
// Now we have to do a shitty workaround instead :(
// Works 99% of the time, but sometimes clicks get through directly to the like button (somehow)
- (void)layoutSubviews {
    %orig;

    if (![SCIUtils getBoolPref:@"like_confirm"]) return;

    UIButton *likeButton = SCISafeValueForKey(self, @"likeButton");
    if (!likeButton) return;

    // 129115 = L(12) I(9) K(11) E(5)
    static NSInteger kOverlayTag = 129115;
    if ([likeButton viewWithTag:kOverlayTag]) return;

    UIButton *overlay = [UIButton buttonWithType:UIButtonTypeCustom];
    overlay.tag = kOverlayTag;
    overlay.frame = likeButton.bounds;
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [overlay addTarget:self action:@selector(overlayTapped:) forControlEvents:UIControlEventTouchUpInside];
    [likeButton addSubview:overlay];
}

%new(v@:@) - (void)overlayTapped:(UIButton *)overlay {
    UIButton *likeButton = (UIButton *)overlay.superview;

    [SCIUtils showConfirmation:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [likeButton sendActionsForControlEvents:UIControlEventTouchUpInside];
        });
    }];
}
%end

%end


// DM like button (seems to be hidden)
%hook IGDirectThreadViewController
- (void)_didTapLikeButton {
    if ([SCIUtils getBoolPref:@"like_confirm"]) {
        SCILogV(@"[SCInsta] Confirm post like triggered");
        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}
%end

%ctor {
    // The hooks outside the groups below. Logos writes this call itself for
    // a file with no %ctor -- and stops the moment there is one, so leaving
    // it out would silence every hook this file did not need to convert.
    %init;

    Class videoPlayerOverlayContainerView = SCIResolveClass(@"IGVideoPlayerOverlayContainerView");
    if (videoPlayerOverlayContainerView) %init(SCIgIGVideoPlayerOverlayContainerView, IGVideoPlayerOverlayContainerView = videoPlayerOverlayContainerView);
    Class storyFullscreenDefaultFooterView = SCIResolveClass(@"IGStoryFullscreenDefaultFooterView");
    if (storyFullscreenDefaultFooterView) %init(SCIgIGStoryFullscreenDefaultFooterView, IGStoryFullscreenDefaultFooterView = storyFullscreenDefaultFooterView);
}
