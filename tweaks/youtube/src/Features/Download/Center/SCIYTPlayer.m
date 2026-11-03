#import "SCIYTPlayer.h"
#import "../../../Tweak.h"
#import "SCIYTThumbnails.h"
#import "SCIYTLibrary.h"
#import "SCIYTIcon.h"
#import "SCIYTPalette.h"
#import "SCIYTPlayerMath.h"
#import "SCIYTHostPlayer.h"
#import "SCIYTArbiter.h"
#import "../../../Diagnostics/SCIYTDiagnostics.h"
#import "../../../SCILog.h"
#import "../../../Prefs.h"
#import "../../../Localization/SCILocalize.h"
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <MediaPlayer/MediaPlayer.h>


/// How long the controls stay up once you stop touching them.
static const NSTimeInterval kSCIChromeLinger = 3.5;

/// How far a double tap moves you, in seconds. Ten, which is what every player that has
/// this gesture uses -- a number people already know without being told.
static const double kSCINudge = 10;

@interface SCIYTPlayer () <AVPictureInPictureControllerDelegate, UIGestureRecognizerDelegate>
- (void)load;
- (void)togglePlay;
- (void)teardown;
@property (nonatomic, strong) NSArray<SCIYTJob *> *jobs;
@property (nonatomic) NSUInteger index;

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *layer;
@property (nonatomic, strong) AVPictureInPictureController *pip;
@property (nonatomic, strong) id ticker;
@property (nonatomic) BOOL observingTimeControl;

@property (nonatomic, strong) UIView *stage;
@property (nonatomic, strong) UIImageView *backdrop;
@property (nonatomic, strong) UIVisualEffectView *blur;
@property (nonatomic, strong) UIImageView *artwork;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIView *chrome;
@property (nonatomic, strong) UIVisualEffectView *transportCapsule;
@property (nonatomic, strong) CAGradientLayer *scrim;

/// The song's own colours, behind everything.
@property (nonatomic, strong) CAGradientLayer *wash;
@property (nonatomic, strong) UIColor *accent;

@property (nonatomic, strong) UILabel *name;
@property (nonatomic, strong) UILabel *subtitle;
@property (nonatomic, strong) UILabel *elapsed;
@property (nonatomic, strong) UILabel *remaining;
@property (nonatomic, strong) UISlider *scrubber;
@property (nonatomic, strong) UIButton *playPause;
@property (nonatomic, strong) UIButton *pipButton;
@property (nonatomic, strong) UIButton *closeButton;

@property (nonatomic, strong) NSLayoutConstraint *stageBottomToChrome;
@property (nonatomic, strong) NSLayoutConstraint *stageBottomToView;

@property (nonatomic) BOOL scrubbing;
@property (nonatomic) BOOL chromeHidden;
@property (nonatomic, strong) NSTimer *linger;

@property (nonatomic, strong) id nextToken;
@property (nonatomic, strong) id previousToken;
@property (nonatomic, strong) id positionToken;
@property (nonatomic, strong) id forwardToken;
@property (nonatomic, strong) id backwardToken;
@property (nonatomic) BOOL torndown;
@property (nonatomic) BOOL publishedLength;

@property (nonatomic, strong) UIButton *speedButton;
@property (nonatomic, strong) UIButton *sleepButton;
@property (nonatomic, strong) NSTimer *sleeper;
@property (nonatomic) float speed;
@property (nonatomic) BOOL sleepAtEnd;

/// Half-seconds spent with a file that will not say how long it is.
@property (nonatomic) NSInteger blindTicks;

/// The title line is showing the "unreadable" notice instead of the name.
@property (nonatomic) BOOL showingUnreadable;

/// The lock screen picture for the current row, built once per row, not per description
/// (the entry is rewritten on every pause, seek and return from the background).
@property (nonatomic, strong) UIImage *lockArtwork;
@property (nonatomic, copy) NSString *lockArtworkFile;

// Gestures (SCIPrefPlayerGestures). Recognisers are always installed and decide at the moment
// they would begin, so the switch takes effect the next touch rather than the next launch.
@property (nonatomic, strong) UIPanGestureRecognizer *seekPan;
@property (nonatomic, strong) UIPanGestureRecognizer *edgePan;
@property (nonatomic, strong) UIPanGestureRecognizer *dismissPan;
@property (nonatomic, strong) UILabel *hud;
@property (nonatomic, strong) NSTimer *hudTimer;
@property (nonatomic, strong) MPVolumeView *volumeView;
@property (nonatomic) double dragStart;
@property (nonatomic) double dragTarget;
@property (nonatomic) SCIPlayerDrag dragKind;
@property (nonatomic) BOOL holdingFast;

// What a file carries besides its picture and its first sound: other languages, captions.
@property (nonatomic, strong) UIButton *tracksButton;
@property (nonatomic, strong) UIButton *repeatButton;
/// 0 off, 1 the whole queue, 2 this one.
@property (nonatomic) NSInteger repeatMode;

/// Whether the audio session is already ours, so it is not taken twice.
@property (nonatomic) BOOL claimed;

/// Half-seconds since the lock screen entry was last written.
@property (nonatomic) NSInteger sinceAnnounced;
@end

/// Where playback stopped is written down as it moves, not only on the way out.
///
/// -viewDidDisappear: is not reached when the app is killed from the switcher or jetsammed,
/// and those are exactly the times someone stops watching. Twice a second is far too often
/// for a disk write, so the position lives on the job as it plays and is committed on the
/// events that matter: pausing, leaving, changing track, closing.
static const double kSCIResumeFloor = 10;

/// How near the end still counts as finished.
///
/// Offering to resume something with twenty seconds left is offering to watch the credits.
static const double kSCIResumeCeiling = 20;

NSNotificationName const SCIYTPlaybackDidChangeNotification = @"SCIYTPlaybackDidChange";

/// The one player. Held here rather than by whoever presented it, because what keeps it
/// alive has to outlive the screen that opened it.
static SCIYTPlayer *sciCurrent = nil;

@implementation SCIYTPlayer

+ (void)presentFrom:(UIViewController *)presenter
               jobs:(NSArray<SCIYTJob *> *)jobs
              start:(NSUInteger)index {

    if (!presenter || index >= jobs.count) return;

    // The same instance every time. A player built per tap made closing the screen and
    // stopping the music one action, so browsing the list meant silence.
    SCIYTPlayer *player = sciCurrent;
    if (!player) {
        player = [[SCIYTPlayer alloc] init];
        player.modalPresentationStyle = UIModalPresentationFullScreen;
        sciCurrent = player;
    }

    BOOL sameRow = [player.jobs isEqualToArray:jobs] && player.index == index && player.player;

    player.jobs = jobs;
    if (!sameRow) player.index = index;

    if (player.presentingViewController) return;
    [presenter presentViewController:player animated:YES completion:^{
        // Loaded after it is on screen, and only when it is not already playing this row --
        // reopening from the mini bar must not start the song over.
        if (!sameRow) [player load];
    }];
}

+ (SCIYTPlayer *)current { return sciCurrent; }
+ (BOOL)isActive { return sciCurrent.player != nil; }
+ (SCIYTJob *)nowPlaying { return [sciCurrent current]; }
+ (BOOL)isPlaying { return sciCurrent.player.rate > 0; }

+ (void)toggle { [sciCurrent togglePlay]; }

+ (void)stop {
    SCIYTPlayer *player = sciCurrent;
    sciCurrent = nil;

    [player teardown];
    [[NSNotificationCenter defaultCenter]
        postNotificationName:SCIYTPlaybackDidChangeNotification object:nil];
}

/// YouTube's player started audibly: ours stops talking, and says so only on its own screen.
/// Not described to the lock screen -- that entry is YouTube's now.
+ (void)pauseForHost {
    SCIYTPlayer *player = sciCurrent;
    if (!player || player.player.rate <= 0) return;

    [player.player pause];
    [player rememberPosition];
    [player showPlaying:NO];
    [[NSNotificationCenter defaultCenter]
        postNotificationName:SCIYTPlaybackDidChangeNotification object:nil];
}

/// YouTube's code just let go of the audio session. When it is our player that is playing, the
/// session is taken back -- forced, because the flag that says it is already ours is now stale.
+ (BOOL)reclaimAudioIfPlaying {
    SCIYTPlayer *player = sciCurrent;
    if (!player || player.player.rate <= 0 || [SCIYTArbiter owner] != SCIOwnerOurs) return NO;

    dispatch_async(dispatch_get_main_queue(), ^{
        player.claimed = NO;
        [player claimAudio];
    });
    return YES;
}

+ (double)progress {
    SCIYTPlayer *player = sciCurrent;
    double at = CMTimeGetSeconds(player.player.currentTime);
    double length = CMTimeGetSeconds(player.player.currentItem.duration);
    if (!isfinite(length) || length <= 0 || !isfinite(at)) return 0;

    return MIN(MAX(at / length, 0), 1);
}

+ (void)reopenFrom:(UIViewController *)presenter {
    SCIYTPlayer *player = sciCurrent;
    if (!player || !presenter || player.presentingViewController) return;

    [presenter presentViewController:player animated:YES completion:nil];
}

/// Turns with the phone, unlike the sheet it was presented from.
///
/// The video used to shrink the moment you rotated: the screen went landscape, the layout
/// did not, and a picture sized for a column ended up in the middle of a wide black field.
/// Allowing every orientation is half of it -- the other half is that the layout changes
/// shape, further down.
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (BOOL)prefersStatusBarHidden { return self.chromeHidden; }
- (BOOL)prefersHomeIndicatorAutoHidden { return self.chromeHidden; }
- (UIStatusBarStyle)preferredStatusBarStyle { return UIStatusBarStyleLightContent; }

// MARK: - Building it

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    [self claimAudio];

    [self buildStage];
    [self buildChrome];
    [self buildGestures];
    [self wireRemote];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(wentAway)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];

    // Earlier than DidEnterBackground, which is already too late to be detaching a layer.
    // By the time that arrives iOS has decided whether this player may keep going.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(wentAway)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];

    // An interruption is a call, an alarm, another app taking the session. iOS does not
    // resume anyone automatically; whoever wants to carry on has to ask.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(interrupted:)
                                                 name:AVAudioSessionInterruptionNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(cameBack)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];

    // Resigning active is not leaving: the notification shade, Control Center, a Face ID
    // sheet and a call banner all resign without ever entering the background, so
    // WillEnterForeground never follows them and the layer detached above stayed empty --
    // sound carrying on under a black picture until the screen was closed and reopened.
    // Becoming active is the one event every one of those ends with.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(cameBack)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];

    // Not loaded here. Presentation does it, and only when the row being opened is not the
    // one already playing -- otherwise reopening from the mini bar restarts the song.
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    // Deliberately no teardown. Closing the screen is not stopping the music -- that is
    // +stop, which the mini bar's close button calls and nothing else does. The remote
    // commands and the now-playing entry stay exactly where they are, because the lock
    // screen should keep working while the screen is shut.
    if (self.isBeingDismissed || self.movingFromParentViewController) {
        [[NSNotificationCenter defaultCenter]
            postNotificationName:SCIYTPlaybackDidChangeNotification object:nil];
    }
}

- (void)dealloc {
    [self teardown];
}

- (void)teardown {
    if (self.torndown) return;
    self.torndown = YES;

    [self.linger invalidate];
    self.linger = nil;

    [[NSNotificationCenter defaultCenter] removeObserver:self];

    if (self.ticker) {
        [self.player removeTimeObserver:self.ticker];
        self.ticker = nil;
    }

    if (self.observingTimeControl) {
        [self.player removeObserver:self forKeyPath:@"timeControlStatus"];
        self.observingTimeControl = NO;
    }

    [self.player pause];
    self.pip = nil;
    self.layer.player = nil;

    MPRemoteCommandCenter *centre = [MPRemoteCommandCenter sharedCommandCenter];
    [centre.playCommand removeTarget:self];
    [centre.pauseCommand removeTarget:self];
    [centre.togglePlayPauseCommand removeTarget:self];
    if (self.nextToken) { [centre.nextTrackCommand removeTarget:self.nextToken]; self.nextToken = nil; }
    if (self.previousToken) { [centre.previousTrackCommand removeTarget:self.previousToken]; self.previousToken = nil; }
    if (self.positionToken) { [centre.changePlaybackPositionCommand removeTarget:self.positionToken]; self.positionToken = nil; }
    if (self.forwardToken) { [centre.skipForwardCommand removeTarget:self.forwardToken]; self.forwardToken = nil; }
    if (self.backwardToken) { [centre.skipBackwardCommand removeTarget:self.backwardToken]; self.backwardToken = nil; }

    [SCIYTArbiter oursEnded];

    // Letting go of the entry and the session is for when nobody else holds them. If YouTube's
    // player has taken over, the entry on the lock screen is its own and the session is under
    // its playback -- clearing the first blanks the lock screen and deactivating the second
    // silences the video that is playing.
    self.claimed = NO;
    if ([SCIYTArbiter owner] != SCIOwnerHost) {
        [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nil;
        [[AVAudioSession sharedInstance] setActive:NO
                                       withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
                                             error:nil];
    }
}

/// The picture, and what stands in for it when there is none.
///
/// A song gets its own cover blown up and blurred behind it. It is the one thing that makes
/// an audio screen look like a player rather than a file open in a viewer, and it costs one
/// image that is already on disk.
- (void)buildStage {
    self.backdrop = [[UIImageView alloc] init];
    self.backdrop.contentMode = UIViewContentModeScaleAspectFill;
    self.backdrop.clipsToBounds = YES;
    self.backdrop.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.backdrop];

    self.blur = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
    self.blur.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.blur];

    // The song's colour, over the blurred cover and under everything else.
    //
    // A blur of the artwork alone is what the first version did and it is muddy: enlarged
    // and softened, most covers become a brownish smear that looks the same whatever is
    // playing. Reading the cover's actual colours and laying a gradient of *those* on top
    // keeps the identity -- a red album gives a red screen -- while giving the text a
    // surface with a predictable brightness to sit on.
    self.wash = [CAGradientLayer layer];
    self.wash.startPoint = CGPointMake(0.5, 0);
    self.wash.endPoint = CGPointMake(0.5, 1);
    [self.view.layer insertSublayer:self.wash above:self.blur.layer];

    self.stage = [[UIView alloc] init];
    self.stage.backgroundColor = [UIColor clearColor];
    self.stage.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.stage];

    self.artwork = [[UIImageView alloc] init];
    self.artwork.contentMode = UIViewContentModeScaleAspectFill;
    self.artwork.clipsToBounds = YES;
    self.artwork.layer.cornerRadius = 14;
    self.artwork.layer.cornerCurve = kCACornerCurveContinuous;

    // A cover sitting on a blur of itself needs an edge or it dissolves into its own
    // background. A hairline and a soft drop is what lifts it off.
    self.artwork.layer.borderWidth = 0.5;
    self.artwork.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.18].CGColor;
    self.artwork.layer.shadowColor = [UIColor blackColor].CGColor;
    self.artwork.layer.shadowOpacity = 0.45;
    self.artwork.layer.shadowRadius = 24;
    self.artwork.layer.shadowOffset = CGSizeMake(0, 12);
    self.artwork.translatesAutoresizingMaskIntoConstraints = NO;
    [self.stage addSubview:self.artwork];

    [NSLayoutConstraint activateConstraints:@[
        [self.backdrop.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.backdrop.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.backdrop.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.backdrop.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        [self.blur.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.blur.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.blur.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.blur.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        [self.stage.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.stage.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.stage.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        [self.artwork.centerXAnchor constraintEqualToAnchor:self.stage.centerXAnchor],
        [self.artwork.centerYAnchor constraintEqualToAnchor:self.stage.centerYAnchor],
        [self.artwork.widthAnchor constraintLessThanOrEqualToAnchor:self.stage.widthAnchor multiplier:0.78],
        [self.artwork.heightAnchor constraintLessThanOrEqualToAnchor:self.stage.heightAnchor multiplier:0.78],
        [self.artwork.widthAnchor constraintEqualToAnchor:self.artwork.heightAnchor]
    ]];

    // Shown only while AVFoundation is actually waiting on data, not while it merely has
    // not started -- +load sets it up before -play is ever called, so a spinner tied to
    // "not yet playing" would flash on every single open.
    self.spinner = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.spinner.color = [UIColor colorWithWhite:1 alpha:0.85];
    self.spinner.hidesWhenStopped = YES;
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [self.stage addSubview:self.spinner];

    [NSLayoutConstraint activateConstraints:@[
        [self.spinner.centerXAnchor constraintEqualToAnchor:self.stage.centerXAnchor],
        [self.spinner.centerYAnchor constraintEqualToAnchor:self.stage.centerYAnchor],
    ]];

    // Both kept, one active at a time. Rotating changes which -- in landscape the picture
    // takes the whole screen and the controls float over it, which is what a video wants
    // and what the old fixed layout could not do.
    self.stageBottomToView = [self.stage.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor];

    self.layer = [AVPlayerLayer layer];
    self.layer.videoGravity = AVLayerVideoGravityResizeAspect;
    [self.stage.layer addSublayer:self.layer];
}

/// Takes the screen's colours from the cover, and cross-fades to them.
///
/// Off the main thread, because reading a picture is work and this runs on every track
/// change; back on it to touch anything drawn. The fade is half a second -- long enough to
/// read as one thing becoming another, short enough that skipping through a list does not
/// feel like waiting for the room lights.
- (void)dressForCover:(UIImage *)cover {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray<UIColor *> *pair = [SCIYTPalette backgroundFor:cover];
        UIColor *accent = [SCIYTPalette accentFor:cover];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.accent = accent;

            CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath:@"colors"];
            fade.duration = 0.5;
            fade.timingFunction =
                [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            [self.wash addAnimation:fade forKey:@"wash"];

            self.wash.colors = @[(id)pair.firstObject.CGColor, (id)pair.lastObject.CGColor];

            [UIView animateWithDuration:0.5 animations:^{
                self.scrubber.minimumTrackTintColor = accent;
                self.playPause.tintColor = accent;

                // The cover throws its own colour onto the screen behind it, which is the
                // detail that makes artwork look lit rather than pasted on.
                self.artwork.layer.shadowColor = accent.CGColor;
                self.artwork.layer.shadowOpacity = 0.55;
            }];
        });
    });
}

/// The cover grows a little while it plays and settles back when paused.
///
/// Small on purpose -- four per cent. A record that visibly pumps is a gimmick; one that is
/// slightly larger while playing is something you feel rather than notice, and it means the
/// screen answers the play button even when the artwork is all you are looking at.
- (void)breathe:(BOOL)playing {
    if ([self current].kind != SCIYTJobKindAudio) return;

    [UIView animateWithDuration:0.45
                          delay:0
         usingSpringWithDamping:0.75
          initialSpringVelocity:0
                        options:UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.artwork.transform = playing ? CGAffineTransformIdentity
                                         : CGAffineTransformMakeScale(0.96, 0.96);
    } completion:nil];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    self.layer.frame = self.stage.bounds;
    self.scrim.frame = self.chrome.bounds;

    // Half the height, measured rather than assumed: the row grows with Dynamic Type and a
    // hardcoded radius would stop being a capsule the moment it did.
    CGFloat capsuleHeight = self.transportCapsule.bounds.size.height;
    if (capsuleHeight > 0) self.transportCapsule.layer.cornerRadius = capsuleHeight / 2;
    self.wash.frame = self.view.bounds;
    [self applyShape];
}

/// Which of the two layouts applies, decided from the shape of the screen.
- (void)applyShape {
    BOOL wide = self.view.bounds.size.width > self.view.bounds.size.height;

    if (wide == self.stageBottomToView.isActive) return;

    self.stageBottomToChrome.active = !wide;
    self.stageBottomToView.active = wide;

    // Over the video, the controls need something behind them or white text lands on a
    // white frame. In portrait they sit on their own ground and need nothing.
    self.scrim.hidden = !wide;
    self.chrome.backgroundColor = [UIColor clearColor];
}

- (void)buildChrome {
    self.chrome = [[UIView alloc] init];
    self.chrome.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.chrome];

    self.scrim = [CAGradientLayer layer];
    self.scrim.colors = @[(id)[UIColor clearColor].CGColor,
                          (id)[UIColor colorWithWhite:0 alpha:0.75].CGColor];
    self.scrim.hidden = YES;
    [self.chrome.layer insertSublayer:self.scrim atIndex:0];

    self.name = [[UILabel alloc] init];
    self.name.font = [UIFont systemFontOfSize:19 weight:UIFontWeightBold];
    self.name.textColor = [UIColor whiteColor];
    self.name.textAlignment = NSTextAlignmentCenter;
    self.name.numberOfLines = 2;

    self.subtitle = [[UILabel alloc] init];
    self.subtitle.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    self.subtitle.textColor = [UIColor colorWithWhite:1 alpha:0.55];
    self.subtitle.textAlignment = NSTextAlignmentCenter;

    self.scrubber = [[UISlider alloc] init];
    self.scrubber.minimumTrackTintColor = SCIAccent();
    self.scrubber.maximumTrackTintColor = [UIColor colorWithWhite:1 alpha:0.22];

    // A smaller thumb than the system default, which is sized for a volume slider and looks
    // clumsy on a timeline. Grown while dragging so the finger has something to hold.
    [self.scrubber setThumbImage:[self thumbOfSize:12] forState:UIControlStateNormal];
    [self.scrubber setThumbImage:[self thumbOfSize:20] forState:UIControlStateHighlighted];

    [self.scrubber addTarget:self action:@selector(scrubMoved)
            forControlEvents:UIControlEventValueChanged];
    [self.scrubber addTarget:self action:@selector(scrubStarted)
            forControlEvents:UIControlEventTouchDown];
    [self.scrubber addTarget:self action:@selector(scrubEnded)
            forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];

    self.elapsed = [self timeLabel:NSTextAlignmentLeft];
    self.remaining = [self timeLabel:NSTextAlignmentRight];

    UIStackView *times = [[UIStackView alloc] initWithArrangedSubviews:@[self.elapsed, self.remaining]];
    times.axis = UILayoutConstraintAxisHorizontal;
    times.distribution = UIStackViewDistributionFillEqually;

    UIButton *back = [self control:@"gobackward.10" size:24 action:@selector(nudgeBack)];
    UIButton *previous = [self control:@"backward.end.fill" size:22 action:@selector(previous)];

    // Plain glyphs, not the .circle.fill pair this used to carry.
    //
    // iOS's own video player draws a bare play triangle and pause bars; the filled circle is
    // what Music uses. Since the whole point of this pass is that the screen should read as
    // the system's player rather than as a tweak's, the glyph follows the system's -- and
    // -showPlaying: swaps between the same two names, so the two places agree.
    self.playPause = [self control:@"pause.fill" size:34 action:@selector(togglePlay)];

    UIButton *next = [self control:@"forward.end.fill" size:22 action:@selector(next)];
    UIButton *ahead = [self control:@"goforward.10" size:24 action:@selector(nudgeAhead)];

    UIStackView *transport = [[UIStackView alloc] initWithArrangedSubviews:
        @[previous, back, self.playPause, ahead, next]];
    transport.axis = UILayoutConstraintAxisHorizontal;
    transport.distribution = UIStackViewDistributionEqualCentering;
    transport.alignment = UIStackViewAlignmentCenter;
    transport.translatesAutoresizingMaskIntoConstraints = NO;
    transport.layoutMarginsRelativeArrangement = YES;
    transport.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(10, 22, 10, 22);

    // The transport row on a frosted capsule, which is the single thing that most makes this
    // read as iOS's player rather than as buttons on a black field.
    //
    // A host view rather than a blur added into the stack: a UIStackView lays out its
    // *arranged* subviews and treats anything else as a plain subview that it will neither
    // size nor position, so a blur put in beside the buttons would sit at the origin at zero
    // size. The host is what the stack arranges; the blur and the buttons are pinned inside
    // it, where the stack's rules do not apply.
    UIView *transportHost = [[UIView alloc] init];
    transportHost.translatesAutoresizingMaskIntoConstraints = NO;

    UIVisualEffectView *capsule = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
    capsule.translatesAutoresizingMaskIntoConstraints = NO;
    capsule.clipsToBounds = YES;
    capsule.layer.cornerCurve = kCACornerCurveContinuous;
    [transportHost addSubview:capsule];
    [transportHost addSubview:transport];

    [NSLayoutConstraint activateConstraints:@[
        [capsule.leadingAnchor constraintEqualToAnchor:transport.leadingAnchor],
        [capsule.trailingAnchor constraintEqualToAnchor:transport.trailingAnchor],
        [capsule.topAnchor constraintEqualToAnchor:transport.topAnchor],
        [capsule.bottomAnchor constraintEqualToAnchor:transport.bottomAnchor],

        // Centred rather than stretched: the capsule is as wide as the buttons need and no
        // wider, the way the system's is.
        [transport.centerXAnchor constraintEqualToAnchor:transportHost.centerXAnchor],
        [transport.topAnchor constraintEqualToAnchor:transportHost.topAnchor],
        [transport.bottomAnchor constraintEqualToAnchor:transportHost.bottomAnchor],
        [transport.leadingAnchor constraintGreaterThanOrEqualToAnchor:transportHost.leadingAnchor]
    ]];

    self.transportCapsule = capsule;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:
        @[self.name, self.subtitle, self.scrubber, times, transportHost]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 8;
    [stack setCustomSpacing:18 afterView:self.subtitle];
    [stack setCustomSpacing:14 afterView:times];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.chrome addSubview:stack];

    self.closeButton = [self control:@"chevron.down" size:18 action:@selector(close)];
    self.closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.closeButton];

    self.pipButton = [self control:@"pip.enter" size:18 action:@selector(enterPiP)];
    self.pipButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.pipButton.hidden = YES;
    [self.view addSubview:self.pipButton];

    // The second row: speed, where the sound is going, and the sleep timer. Below the
    // transport rather than beside it, because these are settings for the listening and the
    // five above are the listening itself -- one row of eight would flatten that difference.
    self.speed = 1;
    self.speedButton = [self textControl:@"1×" action:@selector(pickSpeed)];
    self.sleepButton = [self control:@"moon.zzz" size:17 action:@selector(pickSleep)];

    AVRoutePickerView *route = [[AVRoutePickerView alloc] init];
    route.activeTintColor = SCIAccent();
    route.tintColor = [UIColor colorWithWhite:1 alpha:0.75];

    self.repeatButton = [self control:@"repeat" size:17 action:@selector(cycleRepeat)];
    self.repeatButton.accessibilityLabel = SCILocalized(@"player_repeat_off");
    self.tracksButton = [self control:@"captions.bubble" size:17 action:@selector(pickTracks)];
    self.tracksButton.accessibilityLabel = SCILocalized(@"player_captions");
    self.tracksButton.hidden = YES;

    UIStackView *extras = [[UIStackView alloc] initWithArrangedSubviews:
        @[self.speedButton, self.repeatButton, route, self.tracksButton, self.sleepButton]];
    extras.axis = UILayoutConstraintAxisHorizontal;
    extras.distribution = UIStackViewDistributionEqualCentering;
    extras.alignment = UIStackViewAlignmentCenter;
    [stack addArrangedSubview:extras];
    [stack setCustomSpacing:16 afterView:transport];

    self.stageBottomToChrome =
        [self.stage.bottomAnchor constraintEqualToAnchor:self.chrome.topAnchor constant:-8];
    self.stageBottomToChrome.active = YES;

    [NSLayoutConstraint activateConstraints:@[
        [self.chrome.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.chrome.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.chrome.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [stack.topAnchor constraintEqualToAnchor:self.chrome.topAnchor constant:14],
        [stack.leadingAnchor constraintEqualToAnchor:self.chrome.leadingAnchor constant:26],
        [stack.trailingAnchor constraintEqualToAnchor:self.chrome.trailingAnchor constant:-26],
        [stack.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-18],

        [self.closeButton.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:6],
        [self.closeButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:14],
        [self.closeButton.widthAnchor constraintEqualToConstant:44],
        [self.closeButton.heightAnchor constraintEqualToConstant:44],

        [self.pipButton.centerYAnchor constraintEqualToAnchor:self.closeButton.centerYAnchor],
        [self.pipButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-14],
        [self.pipButton.widthAnchor constraintEqualToConstant:44],
        [self.pipButton.heightAnchor constraintEqualToConstant:44]
    ]];
}

/// Tap anywhere to show or hide; double tap a side to jump.
///
/// The single tap waits on the double, or every jump would flash the controls on its way.
- (void)buildGestures {
    UITapGestureRecognizer *once =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleChrome)];

    UITapGestureRecognizer *twice =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTapped:)];
    twice.numberOfTapsRequired = 2;

    [once requireGestureRecognizerToFail:twice];

    [self.stage addGestureRecognizer:once];
    [self.stage addGestureRecognizer:twice];
    self.stage.userInteractionEnabled = YES;

    // Drag down from anywhere to close, the way every full-screen player on the platform
    // already works -- a chevron in the corner is the only way out otherwise, and that is
    // not where a thumb goes to leave a screen.
    UIPanGestureRecognizer *dismiss =
        [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDismissPan:)];
    dismiss.delegate = self;
    [self.view addGestureRecognizer:dismiss];
    self.dismissPan = dismiss;

    // The rest, on the picture only (the controls below it keep their own touches).
    self.seekPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleSeekPan:)];
    self.seekPan.delegate = self;
    [self.stage addGestureRecognizer:self.seekPan];

    self.edgePan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleEdgePan:)];
    self.edgePan.delegate = self;
    [self.stage addGestureRecognizer:self.edgePan];

    UILongPressGestureRecognizer *hold =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleHold:)];
    hold.minimumPressDuration = 0.45;
    hold.delegate = self;
    [self.stage addGestureRecognizer:hold];

    UIPinchGestureRecognizer *pinch =
        [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
    pinch.delegate = self;
    [self.stage addGestureRecognizer:pinch];

    UITapGestureRecognizer *two =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(twoFingerTapped:)];
    two.numberOfTouchesRequired = 2;
    two.delegate = self;
    [self.stage addGestureRecognizer:two];

    self.hud = [[UILabel alloc] init];
    self.hud.font = [UIFont monospacedDigitSystemFontOfSize:17 weight:UIFontWeightSemibold];
    self.hud.textColor = [UIColor whiteColor];
    self.hud.textAlignment = NSTextAlignmentCenter;
    self.hud.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
    self.hud.layer.cornerRadius = 14;
    self.hud.layer.cornerCurve = kCACornerCurveContinuous;
    self.hud.clipsToBounds = YES;
    self.hud.alpha = 0;
    self.hud.isAccessibilityElement = NO;
    self.hud.translatesAutoresizingMaskIntoConstraints = NO;
    [self.stage addSubview:self.hud];
    [NSLayoutConstraint activateConstraints:@[
        [self.hud.centerXAnchor constraintEqualToAnchor:self.stage.centerXAnchor],
        [self.hud.topAnchor constraintEqualToAnchor:self.stage.safeAreaLayoutGuide.topAnchor constant:64],
        [self.hud.heightAnchor constraintEqualToConstant:34],
        [self.hud.widthAnchor constraintGreaterThanOrEqualToConstant:84],
    ]];

    // The volume slider of the system lives in this view, and reads back only while the view
    // is in a window. Parked off screen and invisible rather than hidden (a hidden one is
    // ignored), and created once.
    self.volumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(-200, -200, 10, 10)];
    self.volumeView.alpha = 0.01;
    self.volumeView.userInteractionEnabled = NO;
    [self.view addSubview:self.volumeView];
}

// MARK: - Gestures on the picture

- (BOOL)gesturesOn { return SCIPrefEnabled(SCIPrefPlayerGestures); }

/// A word over the picture, for about a second.
- (void)say:(NSString *)text {
    self.hud.text = [NSString stringWithFormat:@"  %@  ", text];
    [self.hudTimer invalidate];
    [UIView animateWithDuration:0.12 animations:^{ self.hud.alpha = 1; }];
    self.hudTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:NO block:^(NSTimer *t) {
        [UIView animateWithDuration:0.25 animations:^{ self.hud.alpha = 0; }];
    }];
}

- (UISlider *)systemVolumeSlider {
    for (UIView *view in self.volumeView.subviews) {
        if ([view isKindOfClass:[UISlider class]]) return (UISlider *)view;
    }
    return nil;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture {
    if (gesture == self.dismissPan) {
        // Down, and not at an edge where the same drag means brightness or volume. Sideways
        // and upward drags were already ignored in the handler; refusing them here as well
        // leaves the touch to the recogniser that wants it.
        UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gesture;
        CGPoint v = [pan velocityInView:self.view];
        if (v.y <= 0 || fabs(v.x) > fabs(v.y)) return NO;
        if ([self gesturesOn]) {
            CGPoint at = [pan locationInView:self.stage];
            if (CGRectContainsPoint(self.stage.bounds, at)
                && SCIPlayerClassifyDrag(v.x, v.y, at.x, self.stage.bounds.size.width) != SCIPlayerDragNone) {
                return NO;
            }
        }
        return YES;
    }

    if (gesture == self.seekPan || gesture == self.edgePan) {
        if (![self gesturesOn]) return NO;
        UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gesture;
        CGPoint v = [pan velocityInView:self.stage];
        CGPoint at = [pan locationInView:self.stage];
        SCIPlayerDrag kind = SCIPlayerClassifyDrag(v.x, v.y, at.x, self.stage.bounds.size.width);
        if (gesture == self.seekPan) return kind == SCIPlayerDragSeek && self.player.currentItem;
        return kind == SCIPlayerDragBrightness || kind == SCIPlayerDragVolume;
    }

    return [self gesturesOn];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)a shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)b {
    // A pinch and a two-finger tap are made of the same two fingers.
    return [a isKindOfClass:[UIPinchGestureRecognizer class]] || [b isKindOfClass:[UIPinchGestureRecognizer class]];
}

- (void)handleSeekPan:(UIPanGestureRecognizer *)pan {
    double length = CMTimeGetSeconds(self.player.currentItem.duration);
    CGFloat width = self.stage.bounds.size.width;

    switch (pan.state) {
        case UIGestureRecognizerStateBegan:
            self.dragStart = CMTimeGetSeconds(self.player.currentTime);
            self.dragTarget = self.dragStart;
            self.scrubbing = YES;
            [self.linger invalidate];
            break;

        case UIGestureRecognizerStateChanged: {
            self.dragTarget = SCIPlayerSeekTarget(self.dragStart, [pan translationInView:self.stage].x, width, length);
            if (isfinite(length) && length > 0) {
                self.scrubber.value = (float)(self.dragTarget / length);
                self.elapsed.text = [SCIYTThumbnails clock:self.dragTarget];
                self.remaining.text = [@"-" stringByAppendingString:[SCIYTThumbnails clock:length - self.dragTarget]];
            }
            double delta = self.dragTarget - self.dragStart;
            [self say:[NSString stringWithFormat:@"%@%@  ·  %@", delta < 0 ? @"−" : @"+",
                       [SCIYTThumbnails clock:fabs(delta)], [SCIYTThumbnails clock:self.dragTarget]]];
            break;
        }

        case UIGestureRecognizerStateEnded:
            self.scrubbing = NO;
            [self seekTo:self.dragTarget];
            [self restartLinger];
            break;

        default:
            // Cancelled or failed: nothing was committed, so nothing moves.
            self.scrubbing = NO;
            [self restartLinger];
            break;
    }
}

- (void)handleEdgePan:(UIPanGestureRecognizer *)pan {
    CGFloat height = self.stage.bounds.size.height;

    switch (pan.state) {
        case UIGestureRecognizerStateBegan: {
            CGPoint at = [pan locationInView:self.stage];
            CGPoint v = [pan velocityInView:self.stage];
            self.dragKind = SCIPlayerClassifyDrag(v.x, v.y, at.x, self.stage.bounds.size.width);
            self.dragStart = (self.dragKind == SCIPlayerDragBrightness)
                ? UIScreen.mainScreen.brightness
                : [self systemVolumeSlider].value;
            break;
        }

        case UIGestureRecognizerStateChanged: {
            double level = SCIPlayerEdgeLevel(self.dragStart, [pan translationInView:self.stage].y, height);
            BOOL bright = (self.dragKind == SCIPlayerDragBrightness);
            if (bright) {
                UIScreen.mainScreen.brightness = level;
            } else {
                [self systemVolumeSlider].value = (float)level;
            }
            [self say:[NSString stringWithFormat:@"%@  %d%%", bright ? @"☀︎" : @"🔊", (int)lround(level * 100)]];
            break;
        }

        default: break;
    }
}

/// Held, the picture plays at 2×; let go and it is back to what it was. The chosen speed is
/// never overwritten, only overridden for as long as the finger is down.
- (void)handleHold:(UILongPressGestureRecognizer *)hold {
    if (hold.state == UIGestureRecognizerStateBegan) {
        if (self.player.rate <= 0) return;
        self.holdingFast = YES;
        self.player.rate = 2;
        [self lightHaptic];
        [self say:[NSString stringWithFormat:SCILocalized(@"player_hud_speed"), @"2"]];
        return;
    }

    if (hold.state == UIGestureRecognizerStateEnded
        || hold.state == UIGestureRecognizerStateCancelled
        || hold.state == UIGestureRecognizerStateFailed) {
        if (!self.holdingFast) return;
        self.holdingFast = NO;
        if (self.player.rate > 0) self.player.rate = self.speed;
        [self describeToLockScreen];
    }
}

- (void)handlePinch:(UIPinchGestureRecognizer *)pinch {
    if (pinch.state != UIGestureRecognizerStateEnded) return;
    if ([self current].kind != SCIYTJobKindVideo) return;

    int choice = SCIPlayerZoomChoice(pinch.scale);
    if (choice == 0) return;

    self.layer.videoGravity = (choice > 0) ? AVLayerVideoGravityResizeAspectFill : AVLayerVideoGravityResizeAspect;
    [self lightHaptic];
    [self say:SCILocalized(choice > 0 ? @"player_hud_zoom_fill" : @"player_hud_zoom_fit")];
}

- (void)twoFingerTapped:(__unused UITapGestureRecognizer *)tap {
    [self togglePlay];
}

// Left alone for the slider, the transport buttons and the route picker -- a pan
// recognizer sitting on the whole screen would otherwise catch the same touch a control
// underneath it needs to track, and dragging the scrubber would drag the screen instead.
- (BOOL)gestureRecognizer:(__unused UIGestureRecognizer *)gestureRecognizer
       shouldReceiveTouch:(UITouch *)touch {
    for (UIView *view = touch.view; view && view != self.view; view = view.superview) {
        if ([view isKindOfClass:[UIControl class]]) return NO;
    }
    return YES;
}

- (void)handleDismissPan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self.view];

    switch (pan.state) {
        case UIGestureRecognizerStateChanged: {
            // A horizontal or upward drag is not this gesture -- left alone rather than
            // fought, so it never fights the double-tap zones for the same touch.
            if (translation.y < 0 || fabs(translation.x) > fabs(translation.y)) return;

            self.view.transform = CGAffineTransformMakeTranslation(0, translation.y * 0.85);
            self.view.alpha = 1 - MIN(translation.y / self.view.bounds.size.height, 1) * 0.35;
            break;
        }

        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            CGFloat velocity = [pan velocityInView:self.view].y;

            if (translation.y > 120 || velocity > 800) {
                self.view.transform = CGAffineTransformIdentity;
                self.view.alpha = 1;
                [[[UIImpactFeedbackGenerator alloc]
                    initWithStyle:UIImpactFeedbackStyleMedium] impactOccurred];
                [self close];
            } else {
                [UIView animateWithDuration:0.3
                                       delay:0
                      usingSpringWithDamping:0.8
                       initialSpringVelocity:0
                                     options:UIViewAnimationOptionAllowUserInteraction
                                  animations:^{
                    self.view.transform = CGAffineTransformIdentity;
                    self.view.alpha = 1;
                } completion:nil];
            }
            break;
        }

        default: break;
    }
}

/// A small, consistent nudge on the transport actions -- play, pause, skip, track change --
/// which is what makes the buttons feel answered rather than merely tapped.
- (void)lightHaptic {
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
}

- (UIImage *)thumbOfSize:(CGFloat)size {
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.opaque = NO;

    UIGraphicsImageRenderer *renderer =
        [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(size, size) format:format];

    return [renderer imageWithActions:^(__unused UIGraphicsImageRendererContext *context) {
        [[UIColor whiteColor] setFill];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, size, size)] fill];
    }];
}

/// A control that is a word rather than a glyph. Speed has no symbol that reads at a
/// glance, and "1.5×" is its own icon.
- (UIButton *)textControl:(NSString *)text action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:text forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont monospacedDigitSystemFontOfSize:15 weight:UIFontWeightSemibold];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UILabel *)timeLabel:(NSTextAlignment)alignment {
    UILabel *label = [[UILabel alloc] init];
    label.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightSemibold];

    // Brighter than the 0.55 this carried. iOS's own player keeps its timecodes legible
    // against a moving picture, and 0.55 white over a bright frame is not.
    label.textColor = [UIColor colorWithWhite:1 alpha:0.85];
    label.textAlignment = alignment;
    label.text = @"--:--";
    return label;
}

- (UIButton *)control:(NSString *)symbol size:(CGFloat)size action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *weight =
        [UIImageSymbolConfiguration configurationWithPointSize:size weight:UIImageSymbolWeightMedium];
    [button setImage:[UIImage systemImageNamed:symbol withConfiguration:weight]
            forState:UIControlStateNormal];
    button.tintColor = [UIColor whiteColor];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

// MARK: - Showing and hiding

- (void)toggleChrome {
    [self setChromeHidden:!self.chromeHidden animated:YES];
}

- (void)setChromeHidden:(BOOL)hidden animated:(BOOL)animated {
    _chromeHidden = hidden;

    void (^apply)(void) = ^{
        CGFloat alpha = hidden ? 0 : 1;
        self.chrome.alpha = alpha;
        self.closeButton.alpha = alpha;
        self.pipButton.alpha = alpha;
    };

    if (animated) {
        [UIView animateWithDuration:0.25 animations:apply];
    } else {
        apply();
    }

    [self setNeedsStatusBarAppearanceUpdate];
    [self setNeedsUpdateOfHomeIndicatorAutoHidden];
    [self restartLinger];
}

/// Hides the controls again after a while, but only while something is playing.
///
/// Paused, they stay: a paused screen with no controls looks broken, and the reason to hide
/// them is to see the picture move.
- (void)restartLinger {
    [self.linger invalidate];
    self.linger = nil;

    if (self.chromeHidden || self.player.rate == 0) return;
    if ([self current].kind != SCIYTJobKindVideo) return;

    __weak __typeof(self) weakSelf = self;
    self.linger = [NSTimer scheduledTimerWithTimeInterval:kSCIChromeLinger
                                                  repeats:NO
                                                    block:^(__unused NSTimer *timer) {
        [weakSelf setChromeHidden:YES animated:YES];
    }];
}

// MARK: - Speed, and stopping on its own

- (void)pickSpeed {
    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"player_speed")
                                            message:nil
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    __weak __typeof(self) weakSelf = self;
    for (NSNumber *rate in @[@0.75, @1.0, @1.25, @1.5, @1.75, @2.0]) {
        NSString *label = [NSString stringWithFormat:@"%@×",
            [@(rate.floatValue) stringValue]];

        [sheet addAction:[UIAlertAction actionWithTitle:label
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            [weakSelf applySpeed:rate.floatValue];
        }]];
    }

    [self offer:sheet from:self.speedButton];
}

- (void)applySpeed:(float)rate {
    self.speed = rate;
    [self.speedButton setTitle:[NSString stringWithFormat:@"%@×", [@(rate) stringValue]]
                      forState:UIControlStateNormal];

    // Only while playing. Setting a rate on a paused player starts it, which is not what
    // choosing a speed asks for.
    if (self.player.rate > 0) self.player.rate = rate;
    [self describeToLockScreen];
    [self restartLinger];
}

- (void)pickSleep {
    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"player_sleep")
                                            message:nil
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    __weak __typeof(self) weakSelf = self;

    if (self.sleeper || self.sleepAtEnd) {
        [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"player_sleep_off")
                                                  style:UIAlertActionStyleDestructive
                                                handler:^(__unused UIAlertAction *action) {
            [weakSelf cancelSleep];
        }]];
    }

    for (NSNumber *minutes in @[@5, @15, @30, @45, @60]) {
        NSString *label = [NSString stringWithFormat:SCILocalized(@"player_sleep_minutes"),
            (long)minutes.integerValue];

        [sheet addAction:[UIAlertAction actionWithTitle:label
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            [weakSelf sleepIn:minutes.integerValue * 60];
        }]];
    }

    // The one everybody actually wants for a song, and the one a clock cannot express.
    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"player_sleep_end")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        [weakSelf cancelSleep];
        weakSelf.sleepAtEnd = YES;
        [weakSelf markSleep:YES];
    }]];

    [self offer:sheet from:self.sleepButton];
}

- (void)sleepIn:(NSTimeInterval)seconds {
    [self cancelSleep];

    __weak __typeof(self) weakSelf = self;
    self.sleeper = [NSTimer scheduledTimerWithTimeInterval:seconds
                                                   repeats:NO
                                                     block:^(__unused NSTimer *timer) {
        [weakSelf.player pause];
        [weakSelf showPlaying:NO];
        [weakSelf describeToLockScreen];
        [weakSelf cancelSleep];
    }];

    [self markSleep:YES];
}

- (void)cancelSleep {
    [self.sleeper invalidate];
    self.sleeper = nil;
    self.sleepAtEnd = NO;
    [self markSleep:NO];
}

/// The moon fills in while a timer is set, so it is visible at a glance whether one is.
- (void)markSleep:(BOOL)armed {
    UIImageSymbolConfiguration *weight =
        [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightMedium];
    [self.sleepButton setImage:[UIImage systemImageNamed:(armed ? @"moon.zzz.fill" : @"moon.zzz")
                                       withConfiguration:weight]
                      forState:UIControlStateNormal];
    self.sleepButton.tintColor = armed ? SCIAccent() : [UIColor whiteColor];
}

/// Presents a sheet, anchored so iPad has something to point at.
- (void)offer:(UIAlertController *)sheet from:(UIView *)anchor {
    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    sheet.popoverPresentationController.sourceView = anchor ?: self.view;
    sheet.popoverPresentationController.sourceRect = anchor ? anchor.bounds : self.view.bounds;

    [self presentViewController:sheet animated:YES completion:nil];
}

// MARK: - Where you stopped

/// Writes the position down, for this file, now.
- (void)rememberPosition {
    SCIYTJob *job = [self current];
    if (!job) return;

    double at = CMTimeGetSeconds(self.player.currentTime);
    double length = CMTimeGetSeconds(self.player.currentItem.duration);
    if (!isfinite(at) || !isfinite(length) || length <= 0) return;

    // Only somewhere worth returning to. The first few seconds are not a place you left
    // off, and the last few are the end -- both would offer to resume something nobody
    // stopped in the middle of.
    job.position = (at > kSCIResumeFloor && at < length - kSCIResumeCeiling) ? at : 0;
    [[SCIYTLibrary shared] save];
}

- (void)doubleTapped:(UITapGestureRecognizer *)tap {
    CGPoint at = [tap locationInView:self.stage];
    BOOL ahead = at.x > CGRectGetMidX(self.stage.bounds);
    [self skipBy:ahead ? kSCINudge : -kSCINudge];
}

- (void)nudgeBack { [self lightHaptic]; [self skipBy:-kSCINudge]; }
- (void)nudgeAhead { [self lightHaptic]; [self skipBy:kSCINudge]; }

// MARK: - The queue

/// Tells whatever is showing a mini bar that something changed under it.
- (void)announce {
    [[NSNotificationCenter defaultCenter]
        postNotificationName:SCIYTPlaybackDidChangeNotification object:nil];
}

- (SCIYTJob *)current {
    return (self.index < self.jobs.count) ? self.jobs[self.index] : nil;
}

- (void)load {
    SCIYTJob *job = [self current];
    NSURL *file = [job fileURL];

    if (!file) {
        if (self.index + 1 < self.jobs.count) { self.index++; [self load]; return; }
        [self close];
        return;
    }

    // YouTube's own player, stopped before ours starts. Same process, so the audio session
    // will not do this for us and both would play at once. Ownership is taken with it, so the
    // lock screen's buttons and the "now playing" entry follow this player and not YouTube's.
    [SCIYTArbiter oursStarted];
    [SCIYTArbiter pauseHostPlayers];

    // The one being left, before it is replaced.
    if (self.player) [self rememberPosition];

    if (self.ticker) { [self.player removeTimeObserver:self.ticker]; self.ticker = nil; }

    // Off the outgoing player before it is replaced -- KVO does not follow a property to a
    // new object, and leaving it registered on one about to be released is a crash waiting
    // for the next track change.
    if (self.observingTimeControl) {
        [self.player removeObserver:self forKeyPath:@"timeControlStatus"];
        self.observingTimeControl = NO;
    }

    self.player = [AVPlayer playerWithURL:file];

    // Only ever asked "is it waiting on data right now" -- not "has playback started yet",
    // which is true for the entire span between +load and the first frame and would spin
    // the wheel on every single open rather than only the times a file is actually slow.
    [self.player addObserver:self
                   forKeyPath:@"timeControlStatus"
                      options:NSKeyValueObservingOptionNew
                      context:NULL];
    self.observingTimeControl = YES;

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVPlayerItemDidPlayToEndTimeNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachedEnd)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:self.player.currentItem];

    BOOL isVideo = (job.kind == SCIYTJobKindVideo);
    self.layer.player = isVideo ? self.player : nil;

    UIImage *still = [SCIYTThumbnails cached:job];
    self.artwork.image = still;
    self.artwork.hidden = isVideo || !still;
    self.backdrop.image = still;
    self.blur.hidden = isVideo;
    self.backdrop.hidden = isVideo;
    self.wash.hidden = isVideo;

    if (!isVideo) [self dressForCover:still];

    self.name.text = job.title;
    self.subtitle.text = job.quality;
    self.scrubber.value = 0;
    self.publishedLength = NO;
    self.blindTicks = 0;
    self.showingUnreadable = NO;
    self.tracksButton.hidden = YES;

    [self preparePiP:isVideo];

    __weak __typeof(self) weakSelf = self;
    self.ticker = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 2)
                                                            queue:dispatch_get_main_queue()
                                                       usingBlock:^(__unused CMTime time) {
        [weakSelf tick];
    }];

    // Back where it was left, if it was left anywhere worth returning to. Done before
    // playing rather than after, so it does not start at the beginning and jump.
    if (job.position > kSCIResumeFloor) {
        [self.player seekToTime:CMTimeMakeWithSeconds(job.position, 600)
                toleranceBefore:kCMTimeZero
                 toleranceAfter:kCMTimeZero];
    }

    [self.player play];
    self.player.rate = self.speed;
    [self showPlaying:YES];
    [self setChromeHidden:NO animated:NO];
    [self describeToLockScreen];
    [self announce];

    // Read back rather than asserted -- the one call in -load that checks whether what
    // was just handed to iOS actually stuck, for exactly the report that says whether
    // "sound does not show on the lock screen" is a real difference between the two
    // kinds or something else. Video and sound reach -describeToLockScreen the same way,
    // on the same schedule; if the dictionary is missing or wrong for one and not the
    // other, this is where it would show without guessing at a fourth fix blind.
    NSDictionary *published = [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo;
    [SCIYTDiagnostics recordLockScreenState:
        [NSString stringWithFormat:
            @"%@ · title %@ · artwork %@ · category %@ · session claimed %@",
            isVideo ? @"video" : @"audio",
            published[MPMediaItemPropertyTitle] ? @"set" : @"MISSING",
            published[MPMediaItemPropertyArtwork] ? @"set" : @"none",
            [AVAudioSession sharedInstance].category ?: @"?",
            self.claimed ? @"yes" : @"NO"]];
}

- (void)next {
    [self lightHaptic];
    if (self.index + 1 >= self.jobs.count) { [self.player pause]; [self showPlaying:NO]; return; }
    self.index++;
    [self load];
}

- (void)previous {
    [self lightHaptic];
    if (CMTimeGetSeconds(self.player.currentTime) > 3 || self.index == 0) {
        [self seekTo:0];
        return;
    }
    self.index--;
    [self load];
}

- (void)reachedEnd {
    // Watched to the end, so there is nothing to come back to.
    [self current].position = 0;
    [[SCIYTLibrary shared] save];

    if (self.sleepAtEnd) {
        [self cancelSleep];
        [self showPlaying:NO];
        [self describeToLockScreen];
        return;
    }

    if (self.repeatMode == 2) {
        __weak __typeof(self) weakSelf = self;
        [self.player seekToTime:kCMTimeZero toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero
              completionHandler:^(__unused BOOL finished) {
            weakSelf.player.rate = weakSelf.speed;
            [weakSelf showPlaying:YES];
            [weakSelf describeToLockScreen];
        }];
        return;
    }

    if (self.repeatMode == 1 && self.index + 1 >= self.jobs.count) {
        self.index = 0;
        [self load];
        return;
    }
    [self next];
}

/// Off, the whole queue, this one. The symbol says which; the accessibility label says it
/// in words, because a glyph that changes by a dot is not something VoiceOver can describe.
- (void)cycleRepeat {
    self.repeatMode = (self.repeatMode + 1) % 3;
    NSString *symbol = self.repeatMode == 2 ? @"repeat.1" : @"repeat";
    NSString *key = self.repeatMode == 0 ? @"player_repeat_off"
                  : self.repeatMode == 1 ? @"player_repeat_all" : @"player_repeat_one";

    UIImageSymbolConfiguration *weight =
        [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightMedium];
    [self.repeatButton setImage:[UIImage systemImageNamed:symbol withConfiguration:weight]
                       forState:UIControlStateNormal];
    self.repeatButton.tintColor = self.repeatMode == 0 ? [UIColor colorWithWhite:1 alpha:0.75] : SCIAccent();
    self.repeatButton.accessibilityLabel = SCILocalized(key);
    [self lightHaptic];
    [self say:SCILocalized(key)];
}

// MARK: - Other languages and captions

/// Shown only when the file has something to choose: a second sound, or captions.
- (void)refreshTracksButton {
    AVAsset *asset = self.player.currentItem.asset;
    __weak __typeof(self) weakSelf = self;
    [asset loadValuesAsynchronouslyForKeys:@[@"availableMediaCharacteristics"] completionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            __typeof(self) strongSelf = weakSelf;
            if (!strongSelf || strongSelf.player.currentItem.asset != asset) return;
            AVMediaSelectionGroup *audio = [asset mediaSelectionGroupForMediaCharacteristic:AVMediaCharacteristicAudible];
            AVMediaSelectionGroup *text = [asset mediaSelectionGroupForMediaCharacteristic:AVMediaCharacteristicLegible];
            strongSelf.tracksButton.hidden = !(audio.options.count > 1 || text.options.count > 0);
        });
    }];
}

- (void)pickTracks {
    AVPlayerItem *item = self.player.currentItem;
    AVAsset *asset = item.asset;
    AVMediaSelectionGroup *audio = [asset mediaSelectionGroupForMediaCharacteristic:AVMediaCharacteristicAudible];
    AVMediaSelectionGroup *text = [asset mediaSelectionGroupForMediaCharacteristic:AVMediaCharacteristicLegible];

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:nil message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    if (audio.options.count > 1) {
        AVMediaSelectionOption *chosen = [item.currentMediaSelection selectedMediaOptionInMediaSelectionGroup:audio];
        for (AVMediaSelectionOption *option in audio.options) {
            NSString *title = [NSString stringWithFormat:@"%@ · %@%@", SCILocalized(@"player_audio"),
                               option.displayName, option == chosen ? @"  ✓" : @""];
            [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault
                                                    handler:^(__unused UIAlertAction *action) {
                [item selectMediaOption:option inMediaSelectionGroup:audio];
            }]];
        }
    }

    if (text.options.count > 0) {
        AVMediaSelectionOption *chosen = [item.currentMediaSelection selectedMediaOptionInMediaSelectionGroup:text];
        NSString *off = [NSString stringWithFormat:@"%@ · %@%@", SCILocalized(@"player_captions"),
                         SCILocalized(@"player_captions_off"), chosen ? @"" : @"  ✓"];
        [sheet addAction:[UIAlertAction actionWithTitle:off style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            [item selectMediaOption:nil inMediaSelectionGroup:text];
        }]];
        for (AVMediaSelectionOption *option in text.options) {
            // AVFoundation adds a "Forced" twin to every caption track; it only ever shows the
            // lines meant for foreign speech, which is not what anyone opening this list wants.
            if ([option hasMediaCharacteristic:AVMediaCharacteristicContainsOnlyForcedSubtitles]) continue;
            NSString *title = [NSString stringWithFormat:@"%@ · %@%@", SCILocalized(@"player_captions"),
                               option.displayName, option == chosen ? @"  ✓" : @""];
            [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault
                                                    handler:^(__unused UIAlertAction *action) {
                [item selectMediaOption:option inMediaSelectionGroup:text];
            }]];
        }
    }

    [self offer:sheet from:self.tracksButton];
}

- (void)togglePlay {
    [self lightHaptic];
    BOOL playing = (self.player.rate > 0);
    if (playing) {
        [self.player pause];
        [self rememberPosition];
    } else {
        // At the very end of the last item AVPlayer will not play: it has nothing left. Back
        // to the start, as every player does when Play is pressed on a finished video.
        double length = CMTimeGetSeconds(self.player.currentItem.duration);
        if (isfinite(length) && length > 0 && CMTimeGetSeconds(self.player.currentTime) >= length - 0.25) {
            [self.player seekToTime:kCMTimeZero toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
        }
        [SCIYTArbiter oursStarted];
        [SCIYTArbiter pauseHostPlayers];
        self.player.rate = self.speed;
    }
    [self showPlaying:!playing];
    [self describeToLockScreen];
    [self restartLinger];
    [self announce];
}

- (void)showPlaying:(BOOL)playing {
    [self breathe:playing];

    UIImageSymbolConfiguration *weight =
        [UIImageSymbolConfiguration configurationWithPointSize:34 weight:UIImageSymbolWeightMedium];

    // The same two names -buildChrome creates the button with, at the same size. They were
    // the circle-filled pair against a 56-point build there, and this is the place that
    // would have quietly put them back on the first tap.
    [self.playPause setImage:[UIImage systemImageNamed:(playing ? @"pause.fill" : @"play.fill")
                                     withConfiguration:weight]
                    forState:UIControlStateNormal];
}

/// Puts the screen away and leaves the sound where it was.
///
/// This paused, and that was right when closing the player was the same act as stopping it.
/// Since the player started outliving its screen it has been wrong, and wrong in a way that
/// contradicted the comment ten lines below it: closing is not stopping, +stop is stopping.
/// So the chevron dropped you into a mini bar that was already silent, and the only way on
/// was to press play again — which is a handover that does not hand anything over.
///
/// Nothing here touches playback at all now. The position is written down because the app
/// may not survive to write it later, the bar is told to refresh, and the screen goes away
/// from over the top of something that never stopped.
- (void)close {
    [self rememberPosition];
    [self dismissViewControllerAnimated:YES completion:^{
        [self announce];
    }];
}

// MARK: - Picture in picture

- (void)preparePiP:(BOOL)isVideo {
    if (!isVideo || ![AVPictureInPictureController isPictureInPictureSupported]) {
        self.pip = nil;
        self.pipButton.hidden = YES;
        return;
    }

    self.pip = [[AVPictureInPictureController alloc] initWithPlayerLayer:self.layer];
    self.pip.delegate = self;

    // Only from the button, and said explicitly rather than left to the default.
    //
    // iOS will start picture in picture by itself the moment a playing video's app goes to
    // the background, and it was doing exactly that -- leaving a video put it in a floating
    // window nobody asked for. The default for this is meant to be off; relying on that was
    // clearly wrong, and a property this consequential should not be inferred from
    // documentation when one line states it.
    if (@available(iOS 14.2, *)) {
        self.pip.canStartPictureInPictureAutomaticallyFromInline = NO;
    }
    self.pipButton.hidden = NO;
}

- (void)enterPiP {
    if (self.pip.isPictureInPictureActive) {
        [self.pip stopPictureInPicture];
        return;
    }
    [self.pip startPictureInPicture];
}

/// Put back the way it was found.
///
/// Without this the player is left dismissed underneath the little window, and closing the
/// window leaves nothing to go back to.
- (void)pictureInPictureControllerWillStopPictureInPicture:(__unused AVPictureInPictureController *)controller {
    [self setChromeHidden:NO animated:NO];
}

// MARK: - The scrubber

- (void)scrubStarted {
    self.scrubbing = YES;
    [self.linger invalidate];
}

/// The time labels follow the thumb. They used to freeze while it was held, because -tick
/// leaves them alone during a scrub and nothing else wrote them.
- (void)scrubMoved {
    double length = CMTimeGetSeconds(self.player.currentItem.duration);
    if (!isfinite(length) || length <= 0) return;
    double at = self.scrubber.value * length;
    self.elapsed.text = [SCIYTThumbnails clock:at];
    self.remaining.text = [@"-" stringByAppendingString:[SCIYTThumbnails clock:length - at]];
}

- (void)scrubEnded {
    self.scrubbing = NO;

    double length = CMTimeGetSeconds(self.player.currentItem.duration);
    if (!isfinite(length) || length <= 0) return;

    [self seekTo:self.scrubber.value * length];
    [self restartLinger];
}

- (void)seekTo:(double)seconds {
    double length = CMTimeGetSeconds(self.player.currentItem.duration);
    if (!isfinite(length) || length <= 0) return;

    double target = MIN(MAX(seconds, 0), length);

    __weak __typeof(self) weakSelf = self;
    [self.player seekToTime:CMTimeMakeWithSeconds(target, 600)
            toleranceBefore:kCMTimeZero
             toleranceAfter:kCMTimeZero
          completionHandler:^(BOOL finished) {
        if (finished) [weakSelf describeToLockScreen];
    }];
}

- (void)skipBy:(double)seconds {
    [self seekTo:CMTimeGetSeconds(self.player.currentTime) + seconds];
}

- (void)tick {
    double at = CMTimeGetSeconds(self.player.currentTime);
    double length = CMTimeGetSeconds(self.player.currentItem.duration);

    if (!isfinite(length) || length <= 0) {
        // A length that never becomes a number is a file iOS cannot read, and on screen it
        // is an endless "--:--" that says nothing about why. After three seconds it is not
        // slow loading, so the reason is written down once -- with whatever AVFoundation
        // said, which is the part no amount of looking at the tweak would reveal.
        if (++self.blindTicks == 6) {
            AVPlayerItem *item = self.player.currentItem;
            NSString *reason = item.error.localizedDescription;

            [SCIYTDiagnostics recordPlaybackFailure:
                [NSString stringWithFormat:@"%@ — status %ld, %@",
                    [self current].fileName ?: @"?",
                    (long)item.status,
                    reason ?: @"no error given"]];

            self.name.text = SCILocalized(@"player_unreadable");
            self.showingUnreadable = YES;
        }
        return;
    }

    self.blindTicks = 0;

    // A file that turned out readable after all (a slow disk, a download finishing) must
    // not keep wearing the notice written while it looked dead.
    if (self.showingUnreadable) {
        self.showingUnreadable = NO;
        self.name.text = [self current].title;
    }

    if (!self.publishedLength) {
        self.publishedLength = YES;
        [self refreshTracksButton];
        [self describeToLockScreen];
        [self restartLinger];
    }

    if (self.scrubbing) return;

    // Said again about every two seconds while playing.
    //
    // The entry is not ours alone: YouTube writes to the same now-playing centre, and our
    // own player pauses YouTube's, which is exactly the sort of moment its media stack tidies
    // up after itself and clears what it finds there. Publishing at the start and on leaving
    // was still losing races. Four writes a minute of a small dictionary is not a cost worth
    // protecting against, and a lock screen that is simply absent is unanswerable.
    if (++self.sinceAnnounced >= 4) {
        self.sinceAnnounced = 0;
        [self describeToLockScreen];
    }

    self.scrubber.value = (float)(at / length);
    self.elapsed.text = [SCIYTThumbnails clock:at];
    self.remaining.text = [@"-" stringByAppendingString:[SCIYTThumbnails clock:length - at]];
}

// MARK: - Off the screen

- (void)wentAway {
    [self rememberPosition];

    // Claimed again on the way out, every time.
    //
    // The session belongs to YouTube and YouTube manages it constantly -- and our own
    // player pauses YouTube's when it starts, so from the app's point of view nothing is
    // playing and there is no reason to keep a Playback session alive. Setting the category
    // once in -viewDidLoad is therefore not a setting, it is a request that gets overruled
    // the moment the app decides it is idle. This is why a saved video stopped the instant
    // the screen locked.
    [self claimAudio];

    // And said again here, because leaving is exactly when the lock screen is about to be
    // read. It was published when playback started and when the length first arrived, and
    // if anything overwrote the entry in between -- YouTube's own player being paused, for
    // one -- nothing put it back. That is the "sometimes it shows and sometimes it does not".
    [self describeToLockScreen];

    // Picture in picture is the one case where the layer must keep its player: that little
    // window *is* the layer, and handing it back an empty one closes it.
    if (self.pip.isPictureInPictureActive) return;
    if ([self current].kind == SCIYTJobKindVideo) self.layer.player = nil;
}

/// Takes the audio session, or says why not.
- (void)claimAudio {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error = nil;

    // One mode for both, and MoviePlayback because that is the one demonstrably working.
    //
    // 0.23.0 split this: MoviePlayback for video, Default for sound, on the reasoning that
    // processing meant for film dialogue is wrong for music. The reasoning is fine and the
    // result was not -- video kept playing with the screen off and sound stopped, and the
    // mode was the only thing this code did differently between the two. A difference I
    // introduced, present in exactly the broken case and absent from the working one, is
    // the thing to remove before looking anywhere else.
    //
    // Changed back rather than kept and worked around: a tidier sound profile is not worth
    // sound that stops.
    [session setCategory:AVAudioSessionCategoryPlayback
                    mode:AVAudioSessionModeMoviePlayback
                 options:0
                   error:&error];
    if (error) SCILogV(@"player: category refused — %@", error.localizedDescription);

    // Only when it is not already ours. Re-activating a live session is not free -- it can
    // interrupt what is playing through it -- and -wentAway is reached twice on the way to
    // the background, once for resigning active and once for entering it.
    if (session.isOtherAudioPlaying || !self.claimed) {
        error = nil;
        [session setActive:YES error:&error];
        if (error) SCILogV(@"player: session refused — %@", error.localizedDescription);
        self.claimed = (error == nil);
    }
}

- (void)interrupted:(NSNotification *)note {
    NSUInteger kind = [note.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    if (kind != AVAudioSessionInterruptionTypeEnded) return;

    NSUInteger options = [note.userInfo[AVAudioSessionInterruptionOptionKey] unsignedIntegerValue];
    if (!(options & AVAudioSessionInterruptionOptionShouldResume)) return;

    // An interruption that ended while YouTube's player has the floor is not ours to resume.
    if ([SCIYTArbiter owner] == SCIOwnerHost) return;

    [self claimAudio];
    [SCIYTArbiter oursStarted];
    [self.player play];
    self.player.rate = self.speed;
    [self showPlaying:YES];
    [self describeToLockScreen];
}

- (void)cameBack {
    // Reached by two notifications now; handing the layer the player it already has would
    // be a needless re-attach (a visible flicker), so only a detached layer is given one.
    if ([self current].kind == SCIYTJobKindVideo && self.layer.player != self.player) {
        self.layer.player = self.player;
    }
}

// MARK: - Buffering

- (void)observeValueForKeyPath:(NSString *)keyPath
                       ofObject:(__unused id)object
                         change:(__unused NSDictionary *)change
                        context:(__unused void *)context {
    if (![keyPath isEqualToString:@"timeControlStatus"]) return;

    // AVPlayer's own queue for this is not guaranteed to be the main one, and everything
    // the spinner touches is a view.
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL waiting = self.player.timeControlStatus == AVPlayerTimeControlStatusWaitingToPlayAtSpecifiedRate;
        if (waiting) {
            [self.spinner startAnimating];
        } else {
            [self.spinner stopAnimating];
        }
    });
}

// MARK: - The lock screen

- (void)wireRemote {
    MPRemoteCommandCenter *centre = [MPRemoteCommandCenter sharedCommandCenter];

    centre.playCommand.enabled = YES;
    centre.pauseCommand.enabled = YES;
    centre.changePlaybackPositionCommand.enabled = YES;

    // Next and previous, or fifteen seconds -- never both, because iOS will not show both.
    //
    // Claiming the skip pair *replaces* next and previous on the lock screen, which is what
    // 0.15.0 did without meaning to: it added the skips and quietly took away the two
    // buttons that move between saved videos. Track buttons are the default now and the
    // jumps are the setting, which is the way round it should always have been.
    BOOL jumps = SCIPrefEnabled(SCIPrefLockScreenSkip);

    centre.nextTrackCommand.enabled = !jumps;
    centre.previousTrackCommand.enabled = !jumps;
    centre.skipForwardCommand.enabled = jumps;
    centre.skipBackwardCommand.enabled = jumps;
    centre.skipForwardCommand.preferredIntervals = @[@15];
    centre.skipBackwardCommand.preferredIntervals = @[@15];

    __weak __typeof(self) weakSelf = self;

    [centre.playCommand addTarget:self action:@selector(remotePlay:)];
    [centre.pauseCommand addTarget:self action:@selector(remotePause:)];

    // The headphone button and CarPlay's single press. Not wired before, so with YouTube's
    // handler standing back it would have reached nothing at all.
    centre.togglePlayPauseCommand.enabled = YES;
    [centre.togglePlayPauseCommand addTarget:self action:@selector(remoteToggle:)];

    self.positionToken = [centre.changePlaybackPositionCommand
        addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
            if (![SCIYTArbiter oursMayAct]) return MPRemoteCommandHandlerStatusNoActionableNowPlayingItem;
            [SCIYTArbiter oursCommanded];
            MPChangePlaybackPositionCommandEvent *moved =
                (MPChangePlaybackPositionCommandEvent *)event;
            [weakSelf seekTo:moved.positionTime];
            return MPRemoteCommandHandlerStatusSuccess;
        }];

    self.nextToken = [centre.nextTrackCommand
        addTargetWithHandler:^MPRemoteCommandHandlerStatus(__unused MPRemoteCommandEvent *event) {
            if (![SCIYTArbiter oursMayAct]) return MPRemoteCommandHandlerStatusNoActionableNowPlayingItem;
            [SCIYTArbiter oursCommanded];
            [weakSelf next];
            return MPRemoteCommandHandlerStatusSuccess;
        }];

    self.previousToken = [centre.previousTrackCommand
        addTargetWithHandler:^MPRemoteCommandHandlerStatus(__unused MPRemoteCommandEvent *event) {
            if (![SCIYTArbiter oursMayAct]) return MPRemoteCommandHandlerStatusNoActionableNowPlayingItem;
            [SCIYTArbiter oursCommanded];
            [weakSelf previous];
            return MPRemoteCommandHandlerStatusSuccess;
        }];

    self.forwardToken = [centre.skipForwardCommand
        addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
            if (![SCIYTArbiter oursMayAct]) return MPRemoteCommandHandlerStatusNoActionableNowPlayingItem;
            [SCIYTArbiter oursCommanded];
            [weakSelf skipBy:((MPSkipIntervalCommandEvent *)event).interval];
            return MPRemoteCommandHandlerStatusSuccess;
        }];

    self.backwardToken = [centre.skipBackwardCommand
        addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
            if (![SCIYTArbiter oursMayAct]) return MPRemoteCommandHandlerStatusNoActionableNowPlayingItem;
            [SCIYTArbiter oursCommanded];
            [weakSelf skipBy:-((MPSkipIntervalCommandEvent *)event).interval];
            return MPRemoteCommandHandlerStatusSuccess;
        }];
}

- (MPRemoteCommandHandlerStatus)remotePlay:(__unused MPRemoteCommandEvent *)event {
    // The lock screen's button reaches every handler on the shared command centre, YouTube's
    // included. Only the owner of playback answers; the other says so and does nothing.
    if (![SCIYTArbiter oursMayAct]) return MPRemoteCommandHandlerStatusNoActionableNowPlayingItem;
    [SCIYTArbiter oursStarted];
    [SCIYTArbiter pauseHostPlayers];

    // -play resumes at the default rate; the chosen speed is put back, as every other
    // way of starting playback here does, or the lock screen's Play drops 1.5x to 1x.
    [self.player play];
    self.player.rate = self.speed;
    [self showPlaying:YES];
    [self describeToLockScreen];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)remoteToggle:(MPRemoteCommandEvent *)event {
    if (![SCIYTArbiter oursMayAct]) return MPRemoteCommandHandlerStatusNoActionableNowPlayingItem;
    return self.player.rate > 0 ? [self remotePause:event] : [self remotePlay:event];
}

- (MPRemoteCommandHandlerStatus)remotePause:(__unused MPRemoteCommandEvent *)event {
    if (![SCIYTArbiter oursMayAct]) return MPRemoteCommandHandlerStatusNoActionableNowPlayingItem;
    [SCIYTArbiter oursCommanded];
    [self.player pause];
    [self showPlaying:NO];
    [self describeToLockScreen];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (void)describeToLockScreen {
    SCIYTJob *job = [self current];
    if (!job) return;

    // A paused mini bar must not write over what YouTube is playing: that was "the lock screen
    // shows a different video from the one playing".
    if (![SCIYTArbiter oursMayDescribe]) return;

    NSMutableDictionary *now = [NSMutableDictionary dictionary];
    now[MPMediaItemPropertyTitle] = job.title;
    now[MPMediaItemPropertyArtist] = SCILocalized(@"panel_title");
    now[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @(CMTimeGetSeconds(self.player.currentTime));
    now[MPNowPlayingInfoPropertyPlaybackRate] = @(self.player.rate);
    now[MPNowPlayingInfoPropertyDefaultPlaybackRate] = @1;
    now[MPNowPlayingInfoPropertyMediaType] =
        @(job.kind == SCIYTJobKindAudio ? MPNowPlayingInfoMediaTypeAudio
                                        : MPNowPlayingInfoMediaTypeVideo);

    // Where it sits in the queue, which is what turns two arrows into something you can
    // steer by -- "3 of 12" tells you whether pressing next is worth it.
    now[MPNowPlayingInfoPropertyPlaybackQueueIndex] = @(self.index);
    now[MPNowPlayingInfoPropertyPlaybackQueueCount] = @(self.jobs.count);

    double length = CMTimeGetSeconds(self.player.currentItem.duration);
    if (isfinite(length) && length > 0) now[MPMediaItemPropertyPlaybackDuration] = @(length);

    UIImage *still = [SCIYTThumbnails cached:job];
    if (still) {
        // Square, and drawn at whatever size is asked for.
        //
        // The old version declared the still's own bounds and then returned the same picture
        // whatever was requested -- so a 16:9 thumbnail went into a square slot and came back
        // letterboxed, with black above and below, at every size iOS asked for. That is what
        // every saved song looked like on the lock screen.
        //
        // The handler is called on iOS's schedule and more than once, so the result is built
        // once here rather than redrawn per request: the lock screen, Control Centre and the
        // car all ask, and drawing a gradient three times for one track is work nobody sees.
        if (!self.lockArtwork || ![self.lockArtworkFile isEqualToString:job.fileName]) {
            CGFloat side = MAX(still.size.width, still.size.height);
            self.lockArtwork = [SCIYTPalette squareArtwork:still side:side];
            self.lockArtworkFile = job.fileName;
        }
        UIImage *square = self.lockArtwork;

        now[MPMediaItemPropertyArtwork] =
            [[MPMediaItemArtwork alloc] initWithBoundsSize:square.size
                                            requestHandler:^UIImage *(__unused CGSize size) {
                return square;
            }];
    }

    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = now;
}

@end
