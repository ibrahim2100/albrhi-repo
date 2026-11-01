//
//  SeekButtons.x
//  Albrhi for YouTube Music
//
//  Carried over from YTMEnhanced (github.com/py233/YTMEnhanced) under GPLv3, itself derived
//  from YTMusicUltimate. Kept diffable against upstream: the edits are the %group wrapper and
//  its installer, the shared YTMU() reader, and any one-line %orig body opened out because
//  the Logos this repository pins needs %orig alone in a full block.
//
#import "../YTMShared.h"
#import "shared/src/SCIKVC.h"
#import "../Headers/YTMNowPlayingViewController.h"
#import <objc/runtime.h>


static NSInteger seekTime() {
    NSDictionary *YTMUltimateDict = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"YTMUltimate"];

    if (YTMUltimateDict && YTMUltimateDict[@"seekTime"]) {
        NSInteger index = [YTMUltimateDict[@"seekTime"] integerValue];
        NSArray *seekTimes = @[@0, @10, @20, @30, @60];

        return [seekTimes[index] integerValue];
    }

    return 0;
}

%group YTMSeekButtons

%hook YTMNowPlayingViewController
- (void)viewDidLoad {
    %orig;

    if (!YTMU(@"YTMUltimateIsEnabled") || !YTMU(@"seekButtons")) {
        return;
    }

    //
    // **Edited here: the ivar is confirmed before it is asked for.**
    //
    // Upstream sends -valueForKey: on faith. This project has already paid for that -- a probe
    // that guessed keys and trusted @catch to make it safe crashed Instagram, and the rule written
    // out of it is that -valueForKey: runs the app's own code rather than politely failing. One
    // runtime question turns a guess into a fact, and a build without this ivar leaves the buttons
    // alone instead of raising inside -viewDidLoad.
    //
    if (class_getInstanceVariable([self class], "_nowPlayingView") == NULL) return;

    YTMNowPlayingView *nowPlayingView = SCISafeValueForKey(self, @"_nowPlayingView");

    if (nowPlayingView) {
        YTMPlayerControlsView *controlsView = nowPlayingView.playerControlsView;

        [controlsView.prevButton removeTarget:self action:@selector(didTapPrevButton) forControlEvents:UIControlEventTouchUpInside];
        [controlsView.nextButton removeTarget:self action:@selector(didTapNextButton) forControlEvents:UIControlEventTouchUpInside];

        [controlsView.prevButton addTarget:self action:@selector(didTapSeekBackwardButton) forControlEvents:UIControlEventTouchUpInside];
        [controlsView.nextButton addTarget:self action:@selector(didTapSeekForwardButton) forControlEvents:UIControlEventTouchUpInside];

        UILongPressGestureRecognizer *longPressPrev = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressPrev:)];
        [longPressPrev setMinimumPressDuration:0.5];
        [controlsView.prevButton addGestureRecognizer:longPressPrev];

        UILongPressGestureRecognizer *longPressNext = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressNext:)];
        [longPressNext setMinimumPressDuration:0.5];
        [controlsView.nextButton addGestureRecognizer:longPressNext];

        NSInteger backValue = seekTime() == 0 ? 10 : seekTime();
        NSInteger forwardValue = seekTime() == 0 ? 30 : seekTime();

        YTAssetLoader *al = [[%c(YTAssetLoader) alloc] initWithBundle:[NSBundle mainBundle]];

        UIImage *backImage = [al imageNamed:[NSString stringWithFormat:@"ic_seek_back_%ld_40", backValue]];
        UIImage *forwardImage = [al imageNamed:[NSString stringWithFormat:@"ic_seek_forward_%ld_40", forwardValue]];

        [controlsView.prevButton setImage:backImage forState:UIControlStateNormal];
        [controlsView.prevButton setImage:backImage forState:UIControlStateSelected];
        [controlsView.nextButton setImage:forwardImage forState:UIControlStateNormal];
        [controlsView.nextButton setImage:forwardImage forState:UIControlStateSelected];
    }
}

// - (void)didTapPrevButton {
//     YTMU(@"YTMUltimateIsEnabled") && YTMU(@"seekButtons") ? [self didTapSeekBackwardButton] : %orig;
// }

// - (void)didTapNextButton {
//     YTMU(@"YTMUltimateIsEnabled") && YTMU(@"seekButtons") ? [self didTapSeekForwardButton] : %orig;
// }

%new(v@:@)
- (void)longPressPrev:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        [self didTapPrevButton];
    }
}

%new(v@:@)
- (void)longPressNext:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        [self didTapNextButton];
    }
}
%end

%hook YTColdConfig
//
// **Edited here: `%orig` was the middle operand of a ternary.**
//
// `%orig` expands with `#line` directives, so it survives as the *last* operand of a ternary --
// which is why several carried-over files here use exactly that and compile -- and breaks the
// rest of the line when anything follows it. Two of those cost this build a compile before
// check.py grew a rule for the shape.
//
- (NSInteger)iosPlayerClientSharedConfigTransportControlsSeekForwardTime {
    NSInteger chosen = seekTime();
    if (chosen == 0) return %orig;
    return chosen;
}

- (NSInteger)iosPlayerClientSharedConfigTransportControlsSeekBackwardTime {
    NSInteger chosen = seekTime();
    if (chosen == 0) return %orig;
    return chosen;
}
%end

%end

void SCIYTMInstallSeekButtons(void) { %init(YTMSeekButtons); }
