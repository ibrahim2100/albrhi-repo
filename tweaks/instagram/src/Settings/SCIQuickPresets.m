#import "SCIQuickPresets.h"
#import "../Utils.h"
#import "../InstagramHeaders.h"
#import "../Localization/SCILocalize.h"

///
/// A shortcut opens a sheet listing exactly the switches it covers, each with its
/// own toggle, and applies nothing until the sheet is confirmed.
///
/// The first version applied a fixed set the moment it was tapped. That is faster to
/// build and worse to use: the whole point of a shortcut is that the user has not
/// read which switches it moves, so it either has to show them or ask blind. Showing
/// them turns the shortcut into what people actually want — a short page of the four
/// or five settings that case is about, gathered from across five pages.
///
/// Switches outside the list are never touched, so this is never a reset.
///

@interface SCIPresetItem : NSObject
@property (nonatomic, copy) NSString *defaultsKey;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, assign) BOOL wanted;   ///< what the sheet will write
@end

@implementation SCIPresetItem
@end


@interface SCIPresetSheetController : UIViewController
@property (nonatomic, copy) NSString *presetTitle;
@property (nonatomic, copy) NSString *symbolName;
@property (nonatomic, strong) NSArray<SCIPresetItem *> *items;
@property (nonatomic, assign) BOOL allState;   ///< what "set them all" means here
@property (nonatomic, strong) NSArray<UISwitch *> *toggles;
@property (nonatomic, strong) UIView *card;
@end

@implementation SCIPresetSheetController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.45];

    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backgroundTapped:)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];

    [self buildCard];
}

- (void)buildCard {
    UIColor *accent = [SCIUtils SCIColor_Primary];

    UIVisualEffectView *blur = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterial]];
    blur.translatesAutoresizingMaskIntoConstraints = NO;

    self.card = [[UIView alloc] init];
    self.card.translatesAutoresizingMaskIntoConstraints = NO;
    self.card.layer.cornerRadius = 26;
    self.card.layer.cornerCurve = kCACornerCurveContinuous;
    self.card.clipsToBounds = YES;
    [self.view addSubview:self.card];
    [self.card addSubview:blur];

    UIView *grabber = [[UIView alloc] init];
    grabber.translatesAutoresizingMaskIntoConstraints = NO;
    grabber.backgroundColor = [UIColor.systemGrayColor colorWithAlphaComponent:0.5];
    grabber.layer.cornerRadius = 2.5;
    [self.card addSubview:grabber];

    UIView *badge = [[UIView alloc] init];
    badge.translatesAutoresizingMaskIntoConstraints = NO;
    badge.backgroundColor = [accent colorWithAlphaComponent:0.15];
    badge.layer.cornerRadius = 22;
    [self.card addSubview:badge];

    UIImageView *icon = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:(self.symbolName.length ? self.symbolName : @"slider.horizontal.3")
                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:19 weight:UIImageSymbolWeightSemibold]]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = accent;
    [badge addSubview:icon];

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = self.presetTitle;
    title.font = [UIFont systemFontOfSize:19 weight:UIFontWeightBold];
    title.textAlignment = NSTextAlignmentCenter;
    [self.card addSubview:title];

    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = SCILocalized(@"preset_sheet_body");
    subtitle.font = [UIFont systemFontOfSize:12.5];
    subtitle.textColor = UIColor.secondaryLabelColor;
    subtitle.textAlignment = NSTextAlignmentCenter;
    subtitle.numberOfLines = 0;
    [self.card addSubview:subtitle];

    // The switches themselves, scrollable so a long preset does not push the buttons
    // off a small screen.
    UIStackView *rows = [[UIStackView alloc] init];
    rows.translatesAutoresizingMaskIntoConstraints = NO;
    rows.axis = UILayoutConstraintAxisVertical;
    rows.spacing = 2;

    NSMutableArray<UISwitch *> *collected = [NSMutableArray array];
    for (NSUInteger i = 0; i < self.items.count; i++) {
        [rows addArrangedSubview:[self rowForItem:self.items[i] index:i collecting:collected]];
    }
    self.toggles = collected;

    UIScrollView *scroller = [[UIScrollView alloc] init];
    scroller.translatesAutoresizingMaskIntoConstraints = NO;
    scroller.showsVerticalScrollIndicator = YES;
    [scroller addSubview:rows];
    [self.card addSubview:scroller];

    UIButton *setAll = [UIButton buttonWithType:UIButtonTypeSystem];
    setAll.translatesAutoresizingMaskIntoConstraints = NO;
    [setAll setTitle:SCILocalized(self.allState ? @"preset_all_on" : @"preset_all_off")
            forState:UIControlStateNormal];
    [setAll setTitleColor:accent forState:UIControlStateNormal];
    setAll.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [setAll addTarget:self action:@selector(setAllTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.card addSubview:setAll];

    UIButton *apply = [self buttonWithTitle:SCILocalized(@"preset_apply")
                                 background:accent
                                  textColor:UIColor.whiteColor
                                     action:@selector(applyTapped)];

    UIButton *cancel = [self buttonWithTitle:SCILocalized(@"confirm_no")
                                  background:[UIColor.systemGrayColor colorWithAlphaComponent:0.18]
                                   textColor:UIColor.labelColor
                                      action:@selector(cancelTapped)];

    UIStackView *buttons = [[UIStackView alloc] initWithArrangedSubviews:@[cancel, apply]];
    buttons.translatesAutoresizingMaskIntoConstraints = NO;
    buttons.axis = UILayoutConstraintAxisHorizontal;
    buttons.distribution = UIStackViewDistributionFillEqually;
    buttons.spacing = 10;
    [self.card addSubview:buttons];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;

    // Capped so a long list scrolls instead of covering the whole screen.
    NSLayoutConstraint *listHeight = [scroller.heightAnchor constraintEqualToConstant:MIN(self.items.count * 46.0, 260.0)];

    [NSLayoutConstraint activateConstraints:@[
        [self.card.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:10],
        [self.card.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-10],
        [self.card.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-10],

        [blur.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor],
        [blur.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor],
        [blur.topAnchor constraintEqualToAnchor:self.card.topAnchor],
        [blur.bottomAnchor constraintEqualToAnchor:self.card.bottomAnchor],

        [grabber.centerXAnchor constraintEqualToAnchor:self.card.centerXAnchor],
        [grabber.topAnchor constraintEqualToAnchor:self.card.topAnchor constant:8],
        [grabber.widthAnchor constraintEqualToConstant:38],
        [grabber.heightAnchor constraintEqualToConstant:5],

        [badge.centerXAnchor constraintEqualToAnchor:self.card.centerXAnchor],
        [badge.topAnchor constraintEqualToAnchor:grabber.bottomAnchor constant:14],
        [badge.widthAnchor constraintEqualToConstant:44],
        [badge.heightAnchor constraintEqualToConstant:44],

        [icon.centerXAnchor constraintEqualToAnchor:badge.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:badge.centerYAnchor],

        [title.topAnchor constraintEqualToAnchor:badge.bottomAnchor constant:12],
        [title.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor constant:20],
        [title.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-20],

        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:4],
        [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [subtitle.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],

        [setAll.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:6],
        [setAll.centerXAnchor constraintEqualToAnchor:self.card.centerXAnchor],

        [scroller.topAnchor constraintEqualToAnchor:setAll.bottomAnchor constant:8],
        [scroller.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor constant:14],
        [scroller.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-14],
        listHeight,

        [rows.topAnchor constraintEqualToAnchor:scroller.topAnchor],
        [rows.bottomAnchor constraintEqualToAnchor:scroller.bottomAnchor],
        [rows.leadingAnchor constraintEqualToAnchor:scroller.leadingAnchor],
        [rows.trailingAnchor constraintEqualToAnchor:scroller.trailingAnchor],
        [rows.widthAnchor constraintEqualToAnchor:scroller.widthAnchor],

        [buttons.topAnchor constraintEqualToAnchor:scroller.bottomAnchor constant:14],
        [buttons.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor constant:14],
        [buttons.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-14],
        [buttons.heightAnchor constraintEqualToConstant:48],
        [buttons.bottomAnchor constraintEqualToAnchor:self.card.bottomAnchor constant:-18]
    ]];
}

- (UIView *)rowForItem:(SCIPresetItem *)item index:(NSUInteger)index collecting:(NSMutableArray<UISwitch *> *)collected {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = item.title;
    label.font = [UIFont systemFontOfSize:15];
    label.numberOfLines = 2;
    [row addSubview:label];

    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.translatesAutoresizingMaskIntoConstraints = NO;
    toggle.on = item.wanted;
    toggle.onTintColor = [SCIUtils SCIColor_Primary];
    toggle.tag = (NSInteger)index;
    [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
    [row addSubview:toggle];
    [collected addObject:toggle];

    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintEqualToConstant:46],
        [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:6],
        [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [label.trailingAnchor constraintEqualToAnchor:toggle.leadingAnchor constant:-10],
        [toggle.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-6],
        [toggle.centerYAnchor constraintEqualToAnchor:row.centerYAnchor]
    ]];

    return row;
}

- (UIButton *)buttonWithTitle:(NSString *)title
                   background:(UIColor *)background
                    textColor:(UIColor *)textColor
                       action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = background;
    button.layer.cornerRadius = 15;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:textColor forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

/// Flips every switch to what this shortcut is for — on for most, off for the one
/// about silencing prompts. The one-tap behaviour the first version had, kept as a
/// choice rather than as the only outcome.
- (void)setAllTapped {
    for (NSUInteger i = 0; i < self.items.count && i < self.toggles.count; i++) {
        self.items[i].wanted = self.allState;
        [self.toggles[i] setOn:self.allState animated:YES];
    }

    [[[UISelectionFeedbackGenerator alloc] init] selectionChanged];
}

- (void)toggleChanged:(UISwitch *)sender {
    if (sender.tag < 0 || (NSUInteger)sender.tag >= self.items.count) return;

    self.items[(NSUInteger)sender.tag].wanted = sender.isOn;
    [[[UISelectionFeedbackGenerator alloc] init] selectionChanged];
}

// MARK: - Presentation

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.view layoutIfNeeded];
    self.card.transform = CGAffineTransformMakeTranslation(0, self.card.bounds.size.height + 40);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [UIView animateWithDuration:0.42 delay:0 usingSpringWithDamping:0.82
          initialSpringVelocity:0.5 options:0 animations:^{
        self.card.transform = CGAffineTransformIdentity;
    } completion:nil];
}

// MARK: - Answers

- (void)applyTapped {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    NSInteger changed = 0;
    for (SCIPresetItem *item in self.items) {
        if ([SCIUtils getBoolPref:item.defaultsKey] == item.wanted) continue;

        [defaults setBool:item.wanted forKey:item.defaultsKey];
        changed++;
    }

    [[[UINotificationFeedbackGenerator alloc] init] notificationOccurred:UINotificationFeedbackTypeSuccess];

    NSInteger count = changed;
    [self dismissViewControllerAnimated:YES completion:^{
        [SCIUtils showToastForDuration:2.0
                                 title:[NSString stringWithFormat:SCILocalized(@"preset_applied"), (long)count]];
    }];
}

- (void)cancelTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)backgroundTapped:(UITapGestureRecognizer *)tap {
    if (CGRectContainsPoint(self.card.frame, [tap locationInView:self.view])) return;

    [self cancelTapped];
}

@end


@implementation SCIQuickPresets

+ (CGFloat)shortcutsHeight { return 74.0; }

// MARK: - What each shortcut gathers

/// defaults key → the title already used for that switch on its own settings page,
/// so a feature is never named two different things in two places.
+ (NSArray<NSArray<NSString *> *> *)entriesForPreset:(NSString *)preset {
    if ([preset isEqualToString:@"private"]) {
        return @[
            @[@"no_seen_receipt",         @"p_sm_seen_t"],
            @[@"disable_typing_status",   @"p_sm_typing_t"],
            @[@"remove_screenshot_alert", @"p_sm_screenshot_t"],
            @[@"remove_lastseen",         @"p_sm_markseen_t"],
            @[@"no_recent_searches",      @"p_general_norecent_t"],
            @[@"unlimited_replay",        @"p_sm_replay_t"]
        ];
    }

    if ([preset isEqualToString:@"clean"]) {
        return @[
            @[@"hide_ads",                @"p_general_ads_t"],
            @[@"hide_meta_ai",            @"p_general_metaai_t"],
            @[@"no_suggested_users",      @"p_general_nosuggusers_t"],
            @[@"no_suggested_post",       @"p_feed_nosuggposts_t"],
            @[@"no_suggested_reels",      @"p_feed_nosuggreels_t"],
            @[@"no_suggested_chats",      @"p_general_nosuggchats_t"],
            @[@"hide_trending_searches",  @"p_general_trending_t"],
            @[@"hide_notes_tray",         @"p_general_hidenotes_t"]
        ];
    }

    if ([preset isEqualToString:@"downloads"]) {
        return @[
            @[@"inline_download_button",  @"inline_download_title"],
            @[@"story_download_button",   @"p_story_dl_title"],
            @[@"dm_media_save_button",    @"p_dm_save_t"],
            @[@"carousel_download_choice",@"p_carousel_choice_t"],
            @[@"dl_use_queue",            @"dl_use_queue_title"],
            @[@"dw_save_to_camera",       @"dw_save_to_camera_title"]
        ];
    }

    return @[
        @[@"like_confirm",             @"p_cf_like_t"],
        @[@"like_confirm_reels",       @"p_cf_likereels_t"],
        @[@"post_comment_confirm",     @"p_cf_comment_t"],
        @[@"refresh_reel_confirm",     @"p_reels_refresh_t"],
        @[@"refresh_chats_confirm",    @"p_cf_refreshchats_t"],
        @[@"call_confirm",             @"p_cf_call_t"],
        @[@"shh_mode_confirm",         @"p_cf_shh_t"],
        @[@"sticker_interact_confirm", @"p_cf_sticker_t"],
        @[@"repost_confirm",           @"p_cf_repost_t"]
    ];
}

/// What "turn the whole shortcut on" means for it. Everything is switched on, except
/// "No prompts", which is entirely about switching things off.
+ (BOOL)proposedStateForPreset:(NSString *)preset {
    return ![preset isEqualToString:@"quiet"];
}

// MARK: - The row of shortcuts

+ (UIView *)shortcutsViewWithWidth:(CGFloat)width {
    UIScrollView *scroller = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, width, [self shortcutsHeight])];
    scroller.showsHorizontalScrollIndicator = NO;
    scroller.alwaysBounceHorizontal = YES;

    NSArray<NSArray<NSString *> *> *presets = @[
        @[@"private",   @"lock.fill",              @"preset_private"],
        @[@"clean",     @"wand.and.stars",         @"preset_clean"],
        @[@"downloads", @"arrow.down.circle.fill", @"preset_downloads"],
        @[@"quiet",     @"bell.slash.fill",        @"preset_quiet"]
    ];

    CGFloat x = 16.0;
    for (NSArray<NSString *> *preset in presets) {
        UIButton *chip = [self chipWithSymbol:preset[1] title:SCILocalized(preset[2])];
        [chip addTarget:self action:@selector(chipTapped:) forControlEvents:UIControlEventTouchUpInside];

        // The identifier carries the preset; the symbol is recovered from the table
        // above when the sheet is opened.
        chip.accessibilityIdentifier = preset[0];

        CGSize size = [chip sizeThatFits:CGSizeMake(CGFLOAT_MAX, 40)];
        CGFloat chipWidth = MAX(size.width + 28.0, 96.0);

        chip.frame = CGRectMake(x, 17.0, chipWidth, 40.0);
        [scroller addSubview:chip];

        x += chipWidth + 8.0;
    }

    scroller.contentSize = CGSizeMake(x + 8.0, [self shortcutsHeight]);
    return scroller;
}

+ (UIButton *)chipWithSymbol:(NSString *)symbol title:(NSString *)title {
    UIButton *chip = [UIButton buttonWithType:UIButtonTypeSystem];

    chip.backgroundColor = [[SCIUtils SCIColor_Primary] colorWithAlphaComponent:0.14];
    chip.layer.cornerRadius = 20.0;
    chip.layer.cornerCurve = kCACornerCurveContinuous;
    chip.tintColor = [SCIUtils SCIColor_Primary];

    [chip setTitle:title forState:UIControlStateNormal];
    [chip setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    chip.titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];

    UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:13.0 weight:UIImageSymbolWeightSemibold];
    [chip setImage:[UIImage systemImageNamed:symbol withConfiguration:config] forState:UIControlStateNormal];

    chip.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 12);
    chip.imageEdgeInsets = UIEdgeInsetsMake(0, -4, 0, 4);
    chip.titleEdgeInsets = UIEdgeInsetsMake(0, 4, 0, -4);

    return chip;
}

+ (NSString *)symbolForPreset:(NSString *)preset {
    if ([preset isEqualToString:@"private"]) return @"lock.fill";
    if ([preset isEqualToString:@"clean"]) return @"wand.and.stars";
    if ([preset isEqualToString:@"downloads"]) return @"arrow.down.circle.fill";
    return @"bell.slash.fill";
}

+ (void)chipTapped:(UIButton *)sender {
    NSString *preset = sender.accessibilityIdentifier;
    if (!preset.length) return;

    NSMutableArray<SCIPresetItem *> *items = [NSMutableArray array];
    for (NSArray<NSString *> *entry in [self entriesForPreset:preset]) {
        SCIPresetItem *item = [[SCIPresetItem alloc] init];
        item.defaultsKey = entry[0];
        item.title = SCILocalized(entry[1]);

        // Each switch opens at what it is actually set to right now. The first
        // version opened them all at what the shortcut proposed, which made the
        // sheet a one-way door: it always looked the same however things stood, and
        // reopening it never showed what had been applied. Reading the real value
        // makes it a page you can come back to and change either way.
        item.wanted = [SCIUtils getBoolPref:item.defaultsKey];
        [items addObject:item];
    }

    SCIPresetSheetController *sheet = [[SCIPresetSheetController alloc] init];
    sheet.presetTitle = [sender titleForState:UIControlStateNormal] ?: @"";
    sheet.allState = [self proposedStateForPreset:preset];
    sheet.symbolName = [self symbolForPreset:preset];
    sheet.items = items;
    sheet.modalPresentationStyle = UIModalPresentationOverFullScreen;
    sheet.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;

    [topMostController() presentViewController:sheet animated:YES completion:nil];
}

@end
