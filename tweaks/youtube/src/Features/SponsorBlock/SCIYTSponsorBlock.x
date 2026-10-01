#import "../../YouTubeHeaders.h"
#import "shared/src/SCIResponder.h"
#import "../../SCILog.h"
#import "../../Prefs.h"
#import "../../SCIYTLaunchGuard.h"
#import "../../Localization/SCILocalize.h"
#import "SCIYTSponsorClient.h"
#import "../Download/SCIYTPlayerStreams.h"
#import "../../Diagnostics/SCIYTDiagnostics.h"
#import <objc/runtime.h>
#import <objc/message.h>

///
/// Skip the sponsored parts.
///
/// The progress-bar markers below are derived from **iSponsorBlock** by Galactic Dev
/// (github.com/Galactic-Dev/iSponsorBlock), which is GPLv3, as this is. Taken from it:
/// the three player-bar class names, the placement arithmetic (start ÷ duration × width,
/// a two-point bar along the bottom), and the knowledge that the markers have to be
/// redrawn when segments arrive rather than only on layout. That last one is not an
/// obvious detail, and finding it by trial on a device would have cost several builds.
///
/// What is not taken: the layout. iSponsorBlock positions each marker with Auto Layout
/// constraints; these are frames. The layout engine is what took this tweak down in
/// 0.1.1 and again in 0.1.3, and a rectangle does not need it.
///
/// The credit is in the settings screen and the package description too — under GPLv3
/// that is an obligation, not a courtesy.
///
/// Three hooks, all on YTPlayerViewController, which is the one class that owns every
/// piece needed: it is told when a video activates, it is told when the time changes,
/// and it can seek. Checked against the binary rather than assumed -- the reference tweak
/// also hooks -singleVideo:currentVideoTimeDidChange: on this class, which it does not
/// implement, so that hook is added and then never called.
///
/// State is file-static rather than attached to the controller. One video plays at a
/// time, the controller is a singleton in practice, and associated objects on a class we
/// do not own are a lifetime problem to inherit for no gain here.
///

static NSString *sciCurrentVideoID = nil;
static NSArray<SCISponsorSegment *> *sciSegments = nil;

/// Segments already jumped over, by uuid.
///
/// Without this the skip repeats: seeking to the end of a segment fires another time
/// change, which is still near that segment, which seeks again. It also means a user who
/// scrubs back into a segment on purpose is left alone -- the tweak got its one say.
static NSMutableSet<NSString *> *sciSkipped = nil;

/// The current video's duration, captured from the player controller.
///
/// Here rather than asked for where it is used: the progress bar needs it to place a
/// marker and has no route to the controller, and the bar's own -totalTime is a lead
/// that may not exist. Zero means "not known yet", which is a reason to draw nothing.
static double sciTotalTime = 0;

/// What the markers currently on screen were drawn from.
///
/// -layoutSubviews on a player bar runs constantly while a video plays, and 0.5.0 tore
/// down and rebuilt every marker view on each pass: five segments meant five UIView
/// allocations per layout, for a picture that had not changed. Redrawing is only needed
/// when the segments change, the bar resizes, or a switch is flipped.
///
/// **Kept on the bar rather than in one variable, because there is never only one bar.**
///
/// A single global signature is right while exactly one progress bar exists, and wrong the moment
/// two do -- the watch page and the miniplayer, the player and a Shorts bar. Whichever laid out
/// last owned the variable: a bar the same width as its neighbour saw a matching signature and
/// **skipped drawing its markers entirely**, and bars of different widths overwrote each other's
/// signature on every pass, so the check that exists to prevent a redraw per frame prevented
/// nothing.
///
/// This project has met the same shape twice already -- a diagnostic that recorded the last event
/// instead of a tally, and a date label measured in one space and drawn in another. **State that
/// belongs to a view belongs on the view**, and an associated object is what says so.
///
static const void *kSCIMarkerSignature = &kSCIMarkerSignature;

static NSString *SCIMarkerSignatureFor(UIView *bar) {
    return objc_getAssociatedObject(bar, kSCIMarkerSignature);
}

static void SCISetMarkerSignature(UIView *bar, NSString *signature) {
    objc_setAssociatedObject(bar, kSCIMarkerSignature, signature, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

static void SCIResetForNewVideo(NSString *videoID) {
    sciCurrentVideoID = [videoID copy];
    sciSegments = nil;
    sciSkipped = [NSMutableSet set];
    sciTotalTime = 0;

    // Nothing to clear per bar: every signature carries the video id, so a new video makes each
    // bar's stored signature stale on its own account, whichever bars happen to exist.
}

/// The video's identifier, whatever this build happens to call it.
///
/// A chain rather than one selector: the object handed to the delegate is an id, its
/// class is not declared here, and the accessor has carried more than one name across
/// versions. respondsToSelector first, always -- sending a selector an object does not
/// implement is exactly what crashed 0.1.1.
///
/// `ID` leads, and its absence is why 0.3.0 never skipped anything. The object handed
/// to -didActivateVideo: is an MLVideo, whose accessor is `-ID` -- measured, and the
/// diagnostics page has been reading it that way since 0.1.0. The names below it were
/// written from what the accessor is *usually* called, none of them matched, every
/// lookup returned nil, and the feature returned before it ever asked for a segment.
/// The rule this repository already had ("a class name copied from another project is
/// a lead, never a fact") applies to accessors too.
static NSString *SCIVideoIDFrom(id video) {
    if (!video) return nil;

    for (NSString *name in @[@"ID", @"videoID", @"videoId", @"currentVideoID", @"identifier"]) {
        SEL selector = NSSelectorFromString(name);
        if (![video respondsToSelector:selector]) continue;

        id value = ((id (*)(id, SEL))objc_msgSend)(video, selector);
        if ([value isKindOfClass:[NSString class]] && ((NSString *)value).length) {
            return value;
        }
    }
    return nil;
}


// MARK: - The notice

///
/// A line saying what was skipped, with an undo.
///
/// Frame-based, deliberately. The layout engine took this tweak down twice, and a label
/// and a button in a rounded box need no constraints at all -- the arithmetic is three
/// lines and it cannot be unsatisfiable.
///
@interface SCISponsorNotice : UIView
+ (void)showCategory:(NSString *)category undo:(void (^)(void))undo;
@end

@implementation SCISponsorNotice {
    void (^_undo)(void);
}

static __weak SCISponsorNotice *sciVisibleNotice = nil;

+ (void)showCategory:(NSString *)category undo:(void (^)(void))undo {
    if (!SCIPrefEnabled(SCIPrefSBNotice)) return;

    UIWindow *host = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isKeyWindow) { host = window; break; }
        }
        if (host) break;
    }
    if (!host) return;

    [sciVisibleNotice removeFromSuperview];

    CGFloat width = MIN(host.bounds.size.width - 32, 340);
    CGFloat height = 44;

    SCISponsorNotice *notice = [[SCISponsorNotice alloc] initWithFrame:CGRectMake(
        (host.bounds.size.width - width) / 2,
        host.safeAreaInsets.top + 12,
        width, height)];
    notice->_undo = [undo copy];
    notice.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.94];
    notice.layer.cornerRadius = 14;
    notice.layer.cornerCurve = kCACornerCurveContinuous;
    notice.alpha = 0;

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(14, 0, width - 90, height)];
    label.text = [NSString stringWithFormat:SCILocalized(@"sb_skipped_format"),
        [SCIYTSponsorClient displayNameForCategory:category]];
    label.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    label.textColor = UIColor.whiteColor;
    [notice addSubview:label];

    UIButton *undoButton = [UIButton buttonWithType:UIButtonTypeSystem];
    undoButton.frame = CGRectMake(width - 76, 0, 66, height);
    [undoButton setTitle:SCILocalized(@"sb_undo") forState:UIControlStateNormal];
    [undoButton setTitleColor:[UIColor colorWithRed:1.0 green:0.28 blue:0.38 alpha:1.0]
                     forState:UIControlStateNormal];
    undoButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [undoButton addTarget:notice action:@selector(undoTapped)
         forControlEvents:UIControlEventTouchUpInside];
    [notice addSubview:undoButton];

    [host addSubview:notice];
    sciVisibleNotice = notice;

    [UIView animateWithDuration:0.2 animations:^{
        notice.alpha = 1;
    }];

    // Four seconds: long enough to read and reach the undo, short enough not to sit over
    // the video.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (notice.superview) [notice dismiss];
    });
}

- (void)undoTapped {
    if (_undo) _undo();
    [self dismiss];
}

- (void)dismiss {
    [UIView animateWithDuration:0.2 animations:^{
        self.alpha = 0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

@end


// MARK: - The markers on the progress bar

///
/// SponsorBlock's own colours, so a segment reads the same here as it does in the
/// browser extension people already know.
///
static UIColor *SCIColorForCategory(NSString *category) {
    static NSDictionary<NSString *, NSArray<NSNumber *> *> *table = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        table = @{
            @"sponsor":        @[@0.00, @0.83, @0.00],  // green
            @"selfpromo":      @[@1.00, @1.00, @0.00],  // yellow
            @"interaction":    @[@0.80, @0.00, @1.00],  // purple
            @"intro":          @[@0.00, @1.00, @1.00],  // cyan
            @"outro":          @[@0.01, @0.01, @0.93],  // blue
            @"preview":        @[@0.00, @0.56, @0.84],  // light blue
            @"filler":         @[@0.45, @0.00, @1.00],  // violet
            @"music_offtopic": @[@1.00, @0.60, @0.00],  // orange
        };
    });

    NSArray<NSNumber *> *rgb = table[category];
    if (!rgb) return [UIColor colorWithWhite:0.8 alpha:0.9];

    return [UIColor colorWithRed:rgb[0].doubleValue
                           green:rgb[1].doubleValue
                            blue:rgb[2].doubleValue
                           alpha:0.9];
}

/// Marker views carry this tag so they can be found and removed without keeping an
/// array on a class we do not own.
static const NSInteger SCIMarkerTag = 0x5B10C;

/// The last progress bar that laid itself out.
///
/// Needed because segments arrive from the network *after* the bar has drawn, and a bar
/// with nothing left to lay out will not ask again -- so markers would not appear until
/// something else forced a layout pass. iSponsorBlock solves this by walking
/// overlayView.playerBar.modularPlayerBar from the player controller; this remembers the
/// bar instead, which needs no class names beyond the three already hooked.
///
/// Weak: the bar belongs to YouTube and outliving it is not this tweak's business.
static __weak UIView *sciLastBar = nil;

/// Draws one marker per segment across `bar`, replacing whatever was there.
///
/// Frames, not constraints. Every other part of this tweak that touched the layout
/// engine crashed, and a rectangle whose position is start ÷ duration × width does not
/// need it. Redrawn from scratch on each layout pass because that is also when the bar
/// resizes -- rotation, fullscreen, the miniplayer -- and a stale marker is worse than
/// none.
static void SCIDrawMarkers(UIView *bar, double barTotalTime) {
    if (!bar || SCIYTStoodDown()) return;

    sciLastBar = bar;

    BOOL wanted = SCIPrefEnabled(SCIPrefSponsorBlock) && SCIPrefEnabled(SCIPrefSBMarkers);
    double totalForSignature = (isfinite(barTotalTime) && barTotalTime > 0) ? barTotalTime : sciTotalTime;

    // Everything a marker's position depends on. Cheap to build, and comparing it is
    // what turns a redraw per frame into a redraw per change.
    NSString *signature = [NSString stringWithFormat:@"%@|%d|%lu|%.1f|%.1f",
        sciCurrentVideoID ?: @"-", wanted ? 1 : 0, (unsigned long)sciSegments.count,
        totalForSignature, (double)bar.bounds.size.width];

    if ([signature isEqualToString:SCIMarkerSignatureFor(bar)] &&
        [bar viewWithTag:SCIMarkerTag] != nil) {
        return;
    }

    SCISetMarkerSignature(bar, signature);

    // Removed before every early return below, so switching the feature off or moving to
    // a video with no segments clears what the last one drew.
    for (UIView *existing in [bar.subviews copy]) {
        if (existing.tag == SCIMarkerTag) [existing removeFromSuperview];
    }

    if (!wanted || !sciSegments.count) return;

    // The bar's own duration when it has one, ours when it does not.
    double total = (isfinite(barTotalTime) && barTotalTime > 0) ? barTotalTime : sciTotalTime;
    if (!isfinite(total) || total <= 0) return;

    CGFloat width = bar.bounds.size.width;
    CGFloat height = bar.bounds.size.height;
    if (width <= 0 || height <= 0) return;

    // Two points tall, sitting on the bottom edge: enough to see, not enough to obscure
    // the bar's own progress.
    CGFloat thickness = 2.0;

    for (SCISponsorSegment *segment in sciSegments) {
        double start = segment.start / total;
        double end = segment.end / total;
        if (!isfinite(start) || !isfinite(end)) continue;

        start = MAX(0.0, MIN(1.0, start));
        end = MAX(0.0, MIN(1.0, end));
        if (end <= start) continue;

        CGFloat x = (CGFloat)(start * width);
        // A one-point floor, so a segment that is genuinely short still shows up rather
        // than becoming a zero-width view nobody can see.
        CGFloat w = MAX((CGFloat)((end - start) * width), 1.0);

        UIView *marker = [[UIView alloc] initWithFrame:
            CGRectMake(x, height - thickness, w, thickness)];
        marker.tag = SCIMarkerTag;
        marker.backgroundColor = SCIColorForCategory(segment.category);
        marker.userInteractionEnabled = NO;

        [bar addSubview:marker];
        [bar bringSubviewToFront:marker];
    }

    // Inside the redraw, so this formats a string when the picture actually changed
    // rather than on every layout pass.
    [SCIYTDiagnostics recordMarkerBar:NSStringFromClass([bar class])
                                count:(NSInteger)sciSegments.count];
}

///
/// Three bar classes, because which one a build renders is not knowable from the binary.
/// A %hook on a class that is not there never attaches, so hooking all three costs
/// nothing and the report says which one turned up.
///

%hook YTInlinePlayerBarView

- (void)layoutSubviews {
    %orig;

    // Asked before anything else is done.
    //
    // This is the hottest hook in the tweak: a progress bar lays itself out continuously
    // while a video plays. The pref was checked inside SCIDrawMarkers, which meant entering
    // an exception scope and sending two messages on every pass merely to discover the
    // feature was switched off. Two dictionary reads instead, and nothing else.
    if (!SCIPrefEnabled(SCIPrefSponsorBlock) || !SCIPrefEnabled(SCIPrefSBMarkers)) return;

    @try {
        double total = [self respondsToSelector:@selector(totalTime)] ? self.totalTime : 0;
        SCIDrawMarkers(self, total);
    } @catch (NSException *exception) {
        // A drawing fault must never reach the app: the skipping works without the
        // colours, and a tweak that crashes the player to draw a rectangle is a worse
        // trade than no rectangle.
        SCILogV(@"markers: %@", exception.reason);
    }
}

%end

%hook YTSegmentableInlinePlayerBarView

- (void)layoutSubviews {
    %orig;

    // Asked before anything else is done.
    //
    // This is the hottest hook in the tweak: a progress bar lays itself out continuously
    // while a video plays. The pref was checked inside SCIDrawMarkers, which meant entering
    // an exception scope and sending two messages on every pass merely to discover the
    // feature was switched off. Two dictionary reads instead, and nothing else.
    if (!SCIPrefEnabled(SCIPrefSponsorBlock) || !SCIPrefEnabled(SCIPrefSBMarkers)) return;

    @try {
        double total = [self respondsToSelector:@selector(totalTime)] ? self.totalTime : 0;
        SCIDrawMarkers(self, total);
    } @catch (NSException *exception) {
        SCILogV(@"markers: %@", exception.reason);
    }
}

%end

%hook YTModularPlayerBarView

- (void)layoutSubviews {
    %orig;

    // Asked before anything else is done.
    //
    // This is the hottest hook in the tweak: a progress bar lays itself out continuously
    // while a video plays. The pref was checked inside SCIDrawMarkers, which meant entering
    // an exception scope and sending two messages on every pass merely to discover the
    // feature was switched off. Two dictionary reads instead, and nothing else.
    if (!SCIPrefEnabled(SCIPrefSponsorBlock) || !SCIPrefEnabled(SCIPrefSBMarkers)) return;

    @try {
        double total = [self respondsToSelector:@selector(totalTime)] ? self.totalTime : 0;
        SCIDrawMarkers(self, total);
    } @catch (NSException *exception) {
        SCILogV(@"markers: %@", exception.reason);
    }
}

%end


// MARK: - The player

%hook YTPlayerViewController

- (void)playbackController:(id)controller
           didActivateVideo:(id)video
           withPlaybackData:(id)playbackData {
    %orig;

    if (!SCIPrefEnabled(SCIPrefSponsorBlock)) return;

    // The video object first, then the controller. Two objects rather than one because
    // 0.3.0 asked only the first, under names it does not answer to, and the feature
    // never ran at all -- and because iSponsorBlock, which works on this same 21.x line,
    // reads it off the controller instead. Either answering is enough.
    NSString *videoID = SCIVideoIDFrom(video);
    if (!videoID.length) videoID = SCIVideoIDFrom(self);

    if (!videoID.length) {
        SCILogV(@"sponsorblock: could not read a video id from %@", [video class]);

        // Named class and all, because the fix for this is knowing which accessor that
        // class actually has -- which is the exact information 0.3.0 lacked.
        [SCIYTDiagnostics recordSponsorState:
            [NSString stringWithFormat:SCILocalized(@"diag_sponsor_no_id"),
                NSStringFromClass([video class])]];
        return;
    }

    if ([videoID isEqualToString:sciCurrentVideoID] && sciSegments) return;

    // The id the player actually activated, handed to the page that everything else
    // reads from. MLVideo objects are made for preloaded videos too, so the id captured
    // there is not reliably the one on screen -- a report showed the two disagreeing
    // while the download was asking YouTube about the wrong one.
    [SCIYTDiagnostics recordActiveVideoID:videoID];

    // And the controller itself, which is the only route to -contentPlayerResponse --
    // where the formats that actually carry links turned out to be. Held weakly by the
    // other side; this is a hook that already runs, not a new one.
    [SCIYTPlayerStreams rememberPlayer:self];

    // And the playback data, which is the argument this hook has been discarding since
    // 0.3.0. YTPlaybackData carries -playerResponse and -CPN, which is to say it carries
    // both halves of what downloading needs, handed over at the moment they are true.
    [SCIYTPlayerStreams rememberPlaybackData:playbackData];

    SCIResetForNewVideo(videoID);

    // Captured by value: by the time this returns, the user may well be on a different
    // video, and applying one video's segments to another would skip at random.
    NSString *requested = [videoID copy];

    [SCIYTSponsorClient segmentsForVideo:videoID
                             completion:^(NSArray<SCISponsorSegment *> *segments) {
        if (![requested isEqualToString:sciCurrentVideoID]) {
            SCILogV(@"sponsorblock: reply arrived for a video no longer playing");
            return;
        }
        sciSegments = segments;

        // Draw them now rather than waiting for the bar to lay itself out again. It
        // already has -- the video is playing -- so without this the colours would not
        // appear until a rotation or a scrub, which reads exactly like the feature not
        // working. The completion is already on the main thread.
        UIView *bar = sciLastBar;
        if (bar) {
            @try {
                double total = [bar respondsToSelector:@selector(totalTime)]
                    ? ((YTInlinePlayerBarView *)bar).totalTime : 0;
                SCIDrawMarkers(bar, total);
            } @catch (NSException *exception) {
                SCILogV(@"markers: %@", exception.reason);
            }
        }

        [SCIYTDiagnostics recordSponsorState:
            [NSString stringWithFormat:SCILocalized(@"diag_sponsor_segments"),
                requested, (unsigned long)segments.count]];
    }];
}

- (void)potentiallyMutatedSingleVideo:(id)video currentVideoTimeDidChange:(id)change {
    %orig;

    if (!SCIPrefEnabled(SCIPrefSponsorBlock) || !sciSegments.count) return;

    // The duration, captured here because this is the one place it is reliably to hand
    // and the progress bar -- which needs it to place a marker -- has no route to the
    // controller. Guarded: it is a lead from another tweak, not a measured fact.
    if ([self respondsToSelector:@selector(currentVideoTotalMediaTime)]) {
        double total = self.currentVideoTotalMediaTime;
        if (isfinite(total) && total > 0) sciTotalTime = total;
    }

    NSTimeInterval now = self.currentVideoMediaTime;
    if (!isfinite(now) || now < 0) return;

    for (SCISponsorSegment *segment in sciSegments) {
        if (now < segment.start || now >= segment.end) continue;
        if ([sciSkipped containsObject:segment.uuid]) continue;

        // A segment shorter than a second is not worth a jump: the seek itself costs
        // about that much, so skipping would be slower than watching it.
        if (segment.end - segment.start < 1.0) {
            [sciSkipped addObject:segment.uuid];
            continue;
        }

        [sciSkipped addObject:segment.uuid];

        SCILogV(@"sponsorblock: skipping %@ (%.1f → %.1f)",
                segment.category, segment.start, segment.end);

        [SCIYTDiagnostics recordSponsorState:
            [NSString stringWithFormat:SCILocalized(@"diag_sponsor_skipped"),
                segment.category, segment.start, segment.end]];

        [self seekToTime:segment.end];

        NSTimeInterval back = segment.start;
        __weak __typeof(self) weakSelf = self;
        [SCISponsorNotice showCategory:segment.category undo:^{
            // Back to where the skip started, and the segment stays marked as done so
            // the next time change does not immediately jump forward again.
            [weakSelf seekToTime:back];
        }];

        return;
    }
}

%end
