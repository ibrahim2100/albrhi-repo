#import "SCIYTCentrePage.h"
#import "../../../Tweak.h"
#import "SCIYTDownloadList.h"
#import "SCIYTMiniPlayer.h"
#import "SCIYTPlayer.h"
#import "SCIYTJob.h"
#import "SCIYTPlaylistSheet.h"
#import "../../../Localization/SCILocalize.h"


@interface SCIYTCentrePage ()
@property (nonatomic, strong) NSArray<SCIYTDownloadList *> *lists;
@property (nonatomic, strong) SCIYTDownloadList *showing;
@property (nonatomic, strong) NSArray<UIButton *> *chips;
@property (nonatomic, strong) UIView *chipBar;
@property (nonatomic) NSInteger selected;
@property (nonatomic) BOOL dismissable;
@property (nonatomic, strong) SCIYTMiniPlayer *mini;
@property (nonatomic, strong) NSLayoutConstraint *miniHeight;
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *listConstraints;
@end

@implementation SCIYTCentrePage

- (instancetype)initWithDismissButton:(BOOL)dismissable {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _dismissable = dismissable;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = SCILocalized(@"dl_centre_title");

    // Flat, the way the app's own dark mode actually is. The gradient this used to carry
    // read as a mood board -- Apple Music's colour, not YouTube's -- and the ask was for
    // this to look like it belongs to the app, not like a skin over it.
    self.view.backgroundColor = [UIColor colorWithWhite:0.043 alpha:1];

    // A real large title rather than a control standing in the bar's title slot. The bar's
    // own tabs read this way, and a page reached from one of them should look like it grew
    // out of the same navigation stack rather than borrowed the space at the top of it.
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;

    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = self.view.backgroundColor;
    appearance.shadowColor = nil;
    appearance.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor whiteColor]};
    appearance.largeTitleTextAttributes = @{NSForegroundColorAttributeName: [UIColor whiteColor]};
    self.navigationItem.standardAppearance = appearance;
    self.navigationItem.scrollEdgeAppearance = appearance;

    // Video, Shorts, Audio -- video and Shorts are the same SCIYTJobKind and split only by
    // the isShort flag set at the moment a download starts, see SCIYTJob.h. Audio has no
    // Shorts split of its own.
    self.lists = @[[[SCIYTDownloadList alloc] initWithKind:SCIYTJobKindVideo shorts:NO],
                   [[SCIYTDownloadList alloc] initWithKind:SCIYTJobKindVideo shorts:YES],
                   [[SCIYTDownloadList alloc] initWithKind:SCIYTJobKindAudio shorts:NO]];

    [self buildChipBar];

    // A playlist, downloaded whole: its own button, because the video's download button
    // belongs to a video and a playlist is not one.
    UIBarButtonItem *playlist =
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"text.badge.plus"]
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(addPlaylist)];
    playlist.accessibilityLabel = SCILocalized(@"pl_title");

    if (self.dismissable) {
        self.navigationItem.rightBarButtonItems =
            @[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                             target:self
                                                             action:@selector(close)],
              playlist];
    } else {
        self.navigationItem.rightBarButtonItem = playlist;
    }

    [self buildMiniPlayer];
    [self show:self.lists.firstObject];
}

/// A row of pills under the title, the exact shape the app's own filter chips already
/// are: a capsule each, dim and grey until picked, solid white with black text once it
/// is -- not this tweak's accent colour standing in for a selection, but the same colour
/// switch the real filter row already makes.
- (void)addPlaylist {
    [SCIYTPlaylistSheet presentFrom:self];
}

- (void)buildChipBar {
    self.chipBar = [[UIView alloc] init];
    self.chipBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.chipBar];

    NSArray<NSString *> *titles = @[SCILocalized(@"dl_kind_video"),
                                     SCILocalized(@"dl_kind_shorts"),
                                     SCILocalized(@"dl_kind_audio")];

    NSMutableArray<UIButton *> *chips = [NSMutableArray array];
    UIButton *previous = nil;

    for (NSUInteger i = 0; i < titles.count; i++) {
        UIButton *chip = [UIButton buttonWithType:UIButtonTypeSystem];
        [chip setTitle:titles[i] forState:UIControlStateNormal];
        chip.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        chip.tag = (NSInteger)i;
        chip.contentEdgeInsets = UIEdgeInsetsMake(8, 16, 8, 16);
        chip.layer.cornerCurve = kCACornerCurveContinuous;
        chip.translatesAutoresizingMaskIntoConstraints = NO;
        [chip addTarget:self action:@selector(chipTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.chipBar addSubview:chip];

        [NSLayoutConstraint activateConstraints:@[
            [chip.topAnchor constraintEqualToAnchor:self.chipBar.topAnchor],
            [chip.bottomAnchor constraintEqualToAnchor:self.chipBar.bottomAnchor],
            previous
                ? [chip.leadingAnchor constraintEqualToAnchor:previous.trailingAnchor constant:8]
                : [chip.leadingAnchor constraintEqualToAnchor:self.chipBar.leadingAnchor constant:16],
        ]];

        [chips addObject:chip];
        previous = chip;
    }

    self.chips = chips;
    self.selected = 0;
    [self restyleChips];

    [NSLayoutConstraint activateConstraints:@[
        [self.chipBar.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [self.chipBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.chipBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.chipBar.heightAnchor constraintEqualToConstant:36],
    ]];
}

- (void)restyleChips {
    for (UIButton *chip in self.chips) {
        BOOL on = chip.tag == self.selected;
        chip.backgroundColor = on ? [UIColor whiteColor] : [UIColor colorWithWhite:1 alpha:0.12];
        [chip setTitleColor:(on ? [UIColor blackColor] : [UIColor whiteColor])
                   forState:UIControlStateNormal];

        // Sized after the colour is set, not before -- the corner radius is half of
        // whatever height auto layout actually gave the button, measured rather than
        // guessed at the point sizes above suggest.
        [chip layoutIfNeeded];
        chip.layer.cornerRadius = chip.bounds.size.height / 2;
    }
}

- (void)chipTapped:(UIButton *)sender {
    if (sender.tag == self.selected) return;
    self.selected = sender.tag;
    [self restyleChips];

    if ((NSUInteger)self.selected < self.lists.count) {
        [self show:self.lists[(NSUInteger)self.selected]];
    }
}


/// The strip along the bottom, and the room it takes from the list.
///
/// Added to the page rather than to each list, because the lists are swapped and a bar that
/// belonged to one would vanish on switching to the other while its music kept playing.
- (void)buildMiniPlayer {
    self.mini = [[SCIYTMiniPlayer alloc] initWithFrame:CGRectZero];
    self.mini.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.mini];

    self.miniHeight = [self.mini.heightAnchor constraintEqualToConstant:0];

    [NSLayoutConstraint activateConstraints:@[
        [self.mini.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.mini.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.mini.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        self.miniHeight,
    ]];

    // The list gets its last rows back when the bar goes away. A strip overlapping the final
    // row is the sort of thing that is invisible until the row you want is the last one.
    __weak __typeof(self) weakSelf = self;
    self.mini.miniPlayerVisibilityChanged = ^(BOOL visible) {
        weakSelf.miniHeight.constant = visible ? 62 : 0;
        [weakSelf inset:visible ? 62 : 0];
    };

    // Applied once here as well. The bar decides whether to show itself while it is being
    // built, which is before this block exists to be told -- so opening the Centre with
    // something already playing would leave a bar of no height with music coming out of it.
    BOOL playing = [SCIYTPlayer isActive];
    self.miniHeight.constant = playing ? 62 : 0;
    [self inset:playing ? 62 : 0];
}

- (void)inset:(CGFloat)bottom {
    for (SCIYTDownloadList *list in self.lists) {
        UIEdgeInsets insets = list.tableView.contentInset;
        insets.bottom = bottom;
        list.tableView.contentInset = insets;
        list.tableView.verticalScrollIndicatorInsets = insets;
    }
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

/// Swaps which list is on screen, as a proper child.
///
/// Containment and not just -addSubview:, because a list is a view controller with a table
/// that wants to know when it appeared -- added as a bare view it never receives that, and
/// the rows come back stale after the first switch.
- (void)show:(SCIYTDownloadList *)list {
    if (self.showing == list) return;

    if (self.showing) {
        [self.showing willMoveToParentViewController:nil];
        [self.showing.view removeFromSuperview];
        [self.showing removeFromParentViewController];
    }

    if (self.listConstraints) [NSLayoutConstraint deactivateConstraints:self.listConstraints];

    [self addChildViewController:list];
    list.view.translatesAutoresizingMaskIntoConstraints = NO;

    // Under the mini bar, which was added first and would otherwise end up behind every list
    // swapped in after it -- playing, tappable in theory, and invisible.
    if (self.mini) {
        [self.view insertSubview:list.view belowSubview:self.mini];
    } else {
        [self.view addSubview:list.view];
    }

    self.listConstraints = @[
        [list.view.topAnchor constraintEqualToAnchor:self.chipBar.bottomAnchor constant:8],
        [list.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [list.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [list.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ];
    [NSLayoutConstraint activateConstraints:self.listConstraints];

    [list didMoveToParentViewController:self];

    self.showing = list;
}

@end
