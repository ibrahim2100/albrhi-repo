#import <UIKit/UIKit.h>
#import "shared/src/SCIKVC.h"
#import <objc/runtime.h>
#import "SCIYTDownload.h"
#import "SCIYTShortsButton.h"
#import "Center/SCIYTIcon.h"
#import "../../SCILog.h"
#import "../../Prefs.h"
#import "../../Localization/SCILocalize.h"
#import "../../Diagnostics/SCIYTDiagnostics.h"
#import "../../YouTubeHeaders.h"
#import "../../UI/SCIYTWindow.h"

///
/// A save button in Shorts, in the column with like, comment and share.
///
/// The same idea as the Instagram side's inline button, and the same reasoning: a feature
/// reached by a gesture nobody knows about is a feature nobody uses. Shorts has no long
/// press to spare -- the whole surface is already a scrubber and a swipe -- so it gets a
/// button instead.
///
/// **The hook is -layoutActionBar, and nothing about where the button goes is written down
/// as a number.** The action bar is found by measuring the overlay's own subviews: the
/// narrow column standing against the trailing edge is the one, and our button is placed
/// just above it. A hard-coded offset works on the phone it was tuned on and is wrong on
/// every other size, and this project has no second phone to check against.
///
/// What was found goes into the diagnostics report either way, so "no button in Shorts" is
/// answerable without another release to find out.
///

static char kSCIShortsButton;

/// The clip each overlay is actually drawing.
///
/// **Not the "currently playing" id.** Shorts builds the next clip's overlay while you are
/// still watching this one, so whatever was announced last is routinely the one below --
/// which is exactly what got downloaded. The overlay is handed its own model when it is
/// built, and that model is the only thing that knows which clip this particular button
/// belongs to.
static char kSCIShortsModel;

/// The action bar, by shape rather than by class name.
///
/// Narrow, tall, and hard against the trailing edge -- that is what the like/comment/share
/// column is and what nothing else in the overlay is. Naming its class would be a guess of
/// exactly the kind that left nineteen dead hooks in the tweak this project measured.
static UIView *SCIFindActionBar(UIView *overlay) {
    UIView *best = nil;

    for (UIView *child in overlay.subviews) {
        CGRect frame = child.frame;
        if (child.hidden || frame.size.width <= 0 || frame.size.height <= 0) continue;

        BOOL narrow = frame.size.width < overlay.bounds.size.width * 0.30;
        BOOL tall = frame.size.height > overlay.bounds.size.height * 0.20;
        BOOL trailing = CGRectGetMidX(frame) > overlay.bounds.size.width * 0.65;
        if (!narrow || !tall || !trailing) continue;

        // The lowest one that fits, because the action bar sits below anything else sharing
        // that column.
        if (!best || CGRectGetMaxY(frame) > CGRectGetMaxY(best.frame)) best = child;
    }

    return best;
}

///
/// The clip's own response, filed under the clip's own id.
///
/// This is the only place in Shorts where both facts are available at once. Shorts never
/// builds an MLVideo -- two reports running showed the same stale streams id while the clip
/// on screen changed underneath it -- so every other capture in the tweak belongs to some
/// ordinary video watched earlier, or to whichever clip was preloaded last.
///
/// YTReelModel is handed its response here and answers -videoId for itself. Nothing has to
/// be inferred, matched or detected, which is what the previous five attempts were all doing.
///
%hook YTReelModel

- (void)didReceiveResponse:(id)response {
    %orig;

    if (!response) return;

    NSString *videoID = ((YTReelModel *)self).videoId;

    // Recorded before anything is decided, and recorded when it fails.
    //
    // 0.29.1 filed responses here and the report showed nothing had ever been filed -- but
    // it could not say which of three things went wrong: the hook not attaching at all, the
    // model not knowing its id yet, or the response not being the shape the lookup expects.
    // Those are three different fixes, and choosing between them by reasoning is exactly
    // what the last six releases did.
    NSString *shape = @"?";
    @try {
        id streams = SCISafeValueForKey(response, @"streamingData");
        shape = streams ? @"has streamingData" : @"no streamingData";
    } @catch (__unused NSException *exception) {
        shape = @"no streamingData key";
    }

    [SCIYTDiagnostics recordShortsResponse:
        [NSString stringWithFormat:@"%@ for %@ — %@",
            NSStringFromClass([response class]),
            videoID.length ? videoID : @"(no id yet)", shape]];

    if (!videoID.length) return;

    [SCIYTDiagnostics recordResponse:response forVideo:videoID];
    SCILogV(@"shorts: filed a response for %@", videoID);
}

%end


%hook YTReelWatchPlaybackOverlayView

- (instancetype)initWithFrame:(CGRect)frame
                    reelModel:(id)reelModel
             ghostViewManager:(id)ghostViewManager
              parentResponder:(id)parentResponder {
    id overlay = %orig;

    // Kept weakly: the overlay does not own its model and must not start.
    if (overlay && reelModel) {
        objc_setAssociatedObject(overlay, &kSCIShortsModel, reelModel,
                                 OBJC_ASSOCIATION_ASSIGN);
    }
    return overlay;
}

- (void)layoutActionBar {
    %orig;

    if (!SCIPrefEnabled(SCIPrefShortsButton)) return;

    UIView *overlay = (UIView *)self;
    if (overlay.bounds.size.width <= 0) return;

    UIView *bar = SCIFindActionBar(overlay);

    UIButton *button = objc_getAssociatedObject(self, &kSCIShortsButton);

    // Re-added when the overlay has cleared its subviews, which it does between clips.
    // Remembering the button and not checking it is still in the view is how it appears on
    // the first Short and never again.
    if (button && button.superview != overlay) {
        [overlay addSubview:button];
    }

    if (!button) {
        button = [UIButton buttonWithType:UIButtonTypeSystem];
        [button setImage:[SCIYTIcon downloadMarkOfSize:30 filled:YES]
                forState:UIControlStateNormal];
        button.tintColor = [UIColor whiteColor];

        // The same shadow every icon in that column carries. Without it a white glyph
        // disappears into a pale video, which is half of what Shorts are.
        button.layer.shadowColor = [UIColor blackColor].CGColor;
        button.layer.shadowOpacity = 0.5;
        button.layer.shadowRadius = 3;
        button.layer.shadowOffset = CGSizeZero;

        [button addTarget:[SCIYTShortsSaver class]
                   action:@selector(saveFrom:)
         forControlEvents:UIControlEventTouchUpInside];

        [overlay addSubview:button];
        objc_setAssociatedObject(self, &kSCIShortsButton, button, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        // The button carries its overlay so the tap can find the right model. Weak, because
        // the overlay already owns the button.
        objc_setAssociatedObject(button, &kSCIShortsModel, overlay, OBJC_ASSOCIATION_ASSIGN);

        [SCIYTDiagnostics recordShortsButton:
            bar ? @"added above the action bar" : @"added, no action bar found — placed by edge"];
    }

    // Frames, never constraints. The layout engine took this tweak down in 0.1.1 and again
    // in 0.1.3, and a rectangle placed under a rectangle needs no help from it -- especially
    // inside a -layoutSubviews that is already running.
    CGFloat side = 44;
    CGFloat inset = 12;

    // In the column when it was found, and against the trailing edge when it was not. 0.23.0
    // returned early instead, so a shape this did not recognise meant no button at all -- and
    // the report said so to nobody, because nobody opens a report for a button they were
    // never told to expect. A button roughly in the right place beats a correct refusal.
    CGFloat x = bar ? CGRectGetMidX(bar.frame) - side / 2
                    : overlay.bounds.size.width - side - inset;

    // Above the column, not below it. Below put it in among the caption and the channel
    // name, and low enough on some screens to be under the tab bar entirely.
    CGFloat y = bar ? CGRectGetMinY(bar.frame) - side - 8
                    : overlay.bounds.size.height * 0.42;

    // Kept on screen whichever way it was placed.
    CGFloat lowest = overlay.bounds.size.height - side - inset;
    button.frame = CGRectMake(x, MIN(MAX(y, inset), lowest), side, side);

    // Brought to the front each pass: the overlay re-adds its own views on layout and ours
    // would end up behind them.
    [overlay bringSubviewToFront:button];
}

%end


///
/// The target.
///
/// A class object rather than the overlay, so the button holds no strong reference to a view
/// Shorts recycles. Which clip to save comes from the button's own overlay instead -- see
/// kSCIShortsModel above for why the "currently playing" id is the wrong answer here.
///
@implementation SCIYTShortsSaver

+ (void)saveFrom:(UIButton *)button {
    UIView *overlay = objc_getAssociatedObject(button, &kSCIShortsModel);
    id model = overlay ? objc_getAssociatedObject(overlay, &kSCIShortsModel) : nil;

    NSString *videoID = nil;
    if ([model respondsToSelector:@selector(videoId)]) {
        videoID = ((YTReelModel *)model).videoId;
    }

    UIViewController *top = SCIYTTopViewController();
    if (!top) return;

    SCILogV(@"shorts: save %@ (announced was %@)", videoID, [SCIYTDiagnostics activeVideoID]);
    [SCIYTDiagnostics recordShortsSave:
        [NSString stringWithFormat:@"saving %@, announced %@, overlay %@, model %@",
            videoID ?: @"?", [SCIYTDiagnostics activeVideoID] ?: @"?",
            overlay ? @"found" : @"missing", model ? NSStringFromClass([model class]) : @"missing"]];

    // Refuses rather than falling back.
    //
    // Without this the sheet opens anyway and everything downstream reaches for whatever is
    // playing -- which in Shorts is the clip queued below, so the wrong video is saved with
    // no sign that anything went wrong. That is the failure being reported, and it has now
    // survived two fixes precisely because it is silent: a download that succeeds on the
    // wrong thing looks like a working feature until you open the file.
    //
    // Saying so is worth more than guessing. The message carries what was found so the
    // answer arrives with the complaint instead of needing another release to ask.
    if (!videoID.length) {
        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:SCILocalized(@"dl_title")
                             message:[NSString stringWithFormat:SCILocalized(@"dl_shorts_unknown"),
                                      overlay ? @"yes" : @"no",
                                      model ? NSStringFromClass([model class]) : @"none"]
                      preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:[UIAlertAction actionWithTitle:SCILocalized(@"ok")
                                                  style:UIAlertActionStyleDefault
                                                handler:nil]];
        [top presentViewController:alert animated:YES completion:nil];
        return;
    }

    // The same sheet the long press opens on a normal video. One download path, which is the
    // rule this project has kept since the Instagram side had four of them.
    [SCIYTDownload presentFrom:top videoID:videoID];
}

@end
