//
//  SCITTStatus.m
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCITTStatus.h"
#import "SCITTSectionRegistry.h"
#import "SCITTChoiceList.h"
#import "SCITTRowIcon.h"
#import "SCITTReport.h"
#import "../UI/SCITTWelcome.h"
#import "../Tweak.h"
#import "../Prefs.h"
#import "../Localization/SCILocalize.h"
#import "../Features/Storage/SCITTCache.h"
#import "shared/src/SCIPanelGate.h"

// MARK: - The identity header

///
/// **The only custom cell on the screen.** Everything else is a plain list cell, so it draws, highlights, separates and
/// mirrors in right-to-left exactly the way TikTok's own Settings does -- that was the point of the redesign, and the
/// reason the cards, the two-column grid and the coloured icon wells are gone.
///
/// The header is centred and sits on the page rather than in a card: the mark, the name, the versions and one line that
/// says how much is switched on. When the panel has the tweak switched off for TikTok the line says that instead, in
/// orange, because a screen of switches that are being ignored is worse than an empty one.
///
@interface SCITTHeader : UICollectionViewCell
@property (nonatomic, strong) UILabel *name;
@property (nonatomic, strong) UILabel *versions;
@property (nonatomic, strong) UILabel *state;
@end

@implementation SCITTHeader

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;

    // The mark is the download glyph on the accent: the arrow on the feed button and on the banner, so the
    // identity is the same in three places, and not TikTok's own music note, which would be borrowing a mark.
    UIView *mark = [[UIView alloc] init];
    mark.backgroundColor = SCIAccent();
    mark.layer.cornerRadius = 17;
    mark.layer.cornerCurve = kCACornerCurveContinuous;
    UIImageView *glyph = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:@"arrow.down"
                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:28 weight:UIImageSymbolWeightBold]]];
    glyph.tintColor = [UIColor whiteColor];
    glyph.translatesAutoresizingMaskIntoConstraints = NO;
    [mark addSubview:glyph];

    self.name = [[UILabel alloc] init];
    self.name.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    self.name.textColor = [UIColor labelColor];
    self.name.textAlignment = NSTextAlignmentCenter;

    self.versions = [[UILabel alloc] init];
    self.versions.font = [UIFont monospacedDigitSystemFontOfSize:12.5 weight:UIFontWeightRegular];
    self.versions.textColor = [UIColor secondaryLabelColor];
    self.versions.textAlignment = NSTextAlignmentCenter;

    self.state = [[UILabel alloc] init];
    self.state.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    self.state.textAlignment = NSTextAlignmentCenter;
    self.state.numberOfLines = 0;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[mark, self.name, self.versions, self.state]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 4;
    [stack setCustomSpacing:12 afterView:mark];
    [stack setCustomSpacing:10 afterView:self.versions];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    mark.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [mark.widthAnchor constraintEqualToConstant:68],
        [mark.heightAnchor constraintEqualToConstant:68],
        [glyph.centerXAnchor constraintEqualToAnchor:mark.centerXAnchor],
        [glyph.centerYAnchor constraintEqualToAnchor:mark.centerYAnchor],
        [stack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [stack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12],
        [stack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:24],
        [stack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-24],
    ]];
    return self;
}

@end

// MARK: - The screen

@interface SCITTStatus () <UICollectionViewDataSource, UICollectionViewDelegate>
@property (nonatomic, strong) UICollectionView *collection;
@property (nonatomic, strong) NSArray<NSDictionary *> *sections;

/// The section this page is showing, or nil for the root. One controller does both: the list, the switches and the
/// navigation are the same either way.
@property (nonatomic, strong, nullable) NSDictionary *focus;

@property (nonatomic, strong) UICollectionViewCellRegistration *headerRegistration;
@property (nonatomic, strong) UICollectionViewCellRegistration *categoryRegistration;
@property (nonatomic, strong) UICollectionViewCellRegistration *optionRegistration;
@property (nonatomic, strong) UISelectionFeedbackGenerator *haptic;
@end

@implementation SCITTStatus

+ (void)present {
    SCITTStatus *screen = [[SCITTStatus alloc] init];

    UINavigationController *host = [[UINavigationController alloc] initWithRootViewController:screen];
    host.modalPresentationStyle = UIModalPresentationPageSheet;
    host.view.tintColor = SCIAccent();

    // The foreground scene's key window first: 47.1.0 runs on UIScene, where `-[UIApplication windows]` lists
    // every scene's windows and its key one need not be the one on screen. The application-wide list stays as
    // the fallback for a build or a moment (launch, a scene being torn down) with no active scene.
    UIWindow *key = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]] || scene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isKeyWindow) { key = window; break; }
        }
        if (key) break;
    }
    if (!key) {
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (window.isKeyWindow) { key = window; break; }
        }
    }

    UIViewController *top = key.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    if (!top) return;

    // Opened from the row in TikTok's Settings while already open from the hold, or the other way round:
    // present once.
    if ([top isKindOfClass:[UINavigationController class]] &&
        [((UINavigationController *)top).viewControllers.firstObject isKindOfClass:[SCITTStatus class]]) return;

    [top presentViewController:host animated:YES completion:nil];
}

// MARK: Layout

/// A plain full-width item for the header, and the system's inset-grouped list for everything else. The list layout is
/// the system's own, which is the whole reason this screen looks like a Settings screen.
- (UICollectionViewLayout *)buildLayout {
    __weak typeof(self) weakSelf = self;
    return [[UICollectionViewCompositionalLayout alloc] initWithSectionProvider:
        ^NSCollectionLayoutSection *(NSInteger index, id<NSCollectionLayoutEnvironment> environment) {
        typeof(self) self = weakSelf;

        if (self && !self.focus && index == 0) {
            NSCollectionLayoutSize *size = [NSCollectionLayoutSize
                sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                       heightDimension:[NSCollectionLayoutDimension estimatedDimension:170]];
            NSCollectionLayoutItem *item = [NSCollectionLayoutItem itemWithLayoutSize:[NSCollectionLayoutSize
                sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                       heightDimension:[NSCollectionLayoutDimension estimatedDimension:170]]];
            NSCollectionLayoutGroup *group = [NSCollectionLayoutGroup verticalGroupWithLayoutSize:size subitems:@[item]];
            return [NSCollectionLayoutSection sectionWithGroup:group];
        }

        UICollectionLayoutListConfiguration *list =
            [[UICollectionLayoutListConfiguration alloc] initWithAppearance:UICollectionLayoutListAppearanceInsetGrouped];
        list.backgroundColor = [UIColor clearColor];
        return [NSCollectionLayoutSection sectionWithListConfiguration:list layoutEnvironment:environment];
    }];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // A live number in a row's note (the cache size) arrives after the page is drawn; the sections are rebuilt and the list redrawn when it does.
    __weak typeof(self) weakCache = self;
    [[NSNotificationCenter defaultCenter] addObserverForName:SCITTCacheDidChange object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        typeof(self) strong = weakCache;
        if (!strong || !strong.isViewLoaded) return;
        strong.sections = SCITTSections();
        [strong.collection reloadData];
    }];

    self.sections = SCITTSections();
    self.title = self.focus ? self.focus[kSCISectionTitle] : SCILocalized(@"title");
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.haptic = [[UISelectionFeedbackGenerator alloc] init];

    // Inline on both: the large title repeated the name the header already shows, and TikTok's own pages are inline.
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.navigationController.navigationBar.prefersLargeTitles = NO;

    // Only the root closes the sheet; a pushed page has a back chevron already.
    if (!self.focus) {
        self.navigationItem.rightBarButtonItem =
            [[UIBarButtonItem alloc] initWithTitle:SCILocalized(@"done")
                                             style:UIBarButtonItemStyleDone
                                            target:self
                                            action:@selector(dismissSelf)];
    }

    self.collection = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:[self buildLayout]];
    self.collection.backgroundColor = [UIColor clearColor];
    self.collection.alwaysBounceVertical = YES;
    self.collection.dataSource = self;
    self.collection.delegate = self;
    self.collection.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.collection];
    [NSLayoutConstraint activateConstraints:@[
        [self.collection.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.collection.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.collection.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.collection.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];

    __weak typeof(self) weakSelf = self;

    self.headerRegistration = [UICollectionViewCellRegistration registrationWithCellClass:[SCITTHeader class]
        configurationHandler:^(SCITTHeader *cell, NSIndexPath *indexPath, id item) {
        typeof(self) self = weakSelf;
        if (!self) return;
        cell.name.text = SCILocalized(@"title");
        cell.versions.text = [NSString stringWithFormat:@"%@ · TikTok %@", SCIVersionString,
            [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"?"];

        // The gate has the last word over every switch below, so when it is closed the header says so rather than
        // leaving a screen full of switches that are being ignored.
        if (SCIPanelAllowsThisApp()) {
            NSInteger on = 0, total = 0;
            for (NSDictionary *section in self.sections) {
                NSInteger sectionOn = 0, sectionTotal = 0;
                [self countOn:&sectionOn of:&sectionTotal in:section[kSCISectionRows]];
                on += sectionOn; total += sectionTotal;
            }
            cell.state.text = [NSString stringWithFormat:SCILocalized(@"hero_tally"), (long)on, (long)total];
            cell.state.textColor = SCIAccent();
        } else {
            cell.state.text = SCILocalized(@"gate_off");
            cell.state.textColor = [UIColor systemOrangeColor];
        }
    }];

    // One row per registered section: icon, name, "3/5", and the chevron.
    self.categoryRegistration = [UICollectionViewCellRegistration registrationWithCellClass:[UICollectionViewListCell class]
        configurationHandler:^(UICollectionViewListCell *cell, NSIndexPath *indexPath, NSDictionary *section) {
        typeof(self) self = weakSelf;
        if (!self) return;

        UIListContentConfiguration *content = [UIListContentConfiguration cellConfiguration];
        content.text = section[kSCISectionTitle];
        content.image = SCITTRowIcon(section[kSCISectionIcon] ?: @"square.grid.2x2");
        content.imageProperties.tintColor = [UIColor labelColor];
        content.imageProperties.reservedLayoutSize = CGSizeMake(30, 30);
        content.imageProperties.maximumSize = CGSizeMake(24, 24);
        content.imageToTextPadding = 12;
        cell.contentConfiguration = content;

        NSInteger on = 0, total = 0;
        [self countOn:&on of:&total in:section[kSCISectionRows]];
        NSMutableArray *accessories = [NSMutableArray array];
        if (total > 0) {
            UICellAccessoryLabel *count = [[UICellAccessoryLabel alloc] initWithText:
                [NSString stringWithFormat:@"%ld/%ld", (long)on, (long)total]];
            count.font = [UIFont monospacedDigitSystemFontOfSize:15 weight:UIFontWeightRegular];
            [accessories addObject:count];
        }
        [accessories addObject:[[UICellAccessoryDisclosureIndicator alloc] init]];
        cell.accessories = accessories;
    }];

    // One option: icon, name, what it does underneath, and the switch / the current value / the chevron.
    self.optionRegistration = [UICollectionViewCellRegistration registrationWithCellClass:[UICollectionViewListCell class]
        configurationHandler:^(UICollectionViewListCell *cell, NSIndexPath *indexPath, NSDictionary *row) {
        typeof(self) self = weakSelf;
        if (!self) return;

        UIListContentConfiguration *content = [UIListContentConfiguration subtitleCellConfiguration];
        content.text = row[kSCIRowTitle];
        content.textProperties.numberOfLines = 0;
        content.secondaryText = row[kSCIRowNote];
        content.secondaryTextProperties.numberOfLines = 0;
        content.secondaryTextProperties.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
        content.secondaryTextProperties.color = [row[kSCIRowWarns] boolValue] ? [UIColor systemOrangeColor]
                                                                                : [UIColor secondaryLabelColor];
        content.textToSecondaryTextVerticalPadding = 3;
        content.image = SCITTRowIcon(row[kSCIRowIcon]);
        content.imageProperties.tintColor = [UIColor labelColor];
        content.imageProperties.reservedLayoutSize = CGSizeMake(30, 30);
        content.imageProperties.maximumSize = CGSizeMake(24, 24);
        content.imageToTextPadding = 12;
        cell.contentConfiguration = content;

        NSString *kind = row[kSCIRowKind];
        BOOL isChoice = [kind isEqualToString:kSCIKindChoice];
        BOOL isLink = [kind isEqualToString:kSCIKindLink];
        BOOL isAction = [kind isEqualToString:kSCIKindAction];

        if (isAction) {
            // Nothing at the end: a row that acts is told apart by its tint and its note, not by a control that would invite a second kind of tap.
            content.textProperties.color = SCIAccent();
            cell.contentConfiguration = content;
            cell.accessories = @[];
        } else if (isChoice) {
            // The current value leads the second line, in the label colour: what is chosen is the first thing anybody
            // opening this row wants to know. (As a trailing label it squeezed the text beside it into a narrow column.)
            NSString *current = SCITTChoiceCurrentTitle(row[kSCIRowOptions], row[kSCIRowPref]);
            if (current.length) {
                UIFont *noteFont = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
                NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:current attributes:@{
                    NSFontAttributeName: [UIFont systemFontOfSize:noteFont.pointSize weight:UIFontWeightSemibold],
                    NSForegroundColorAttributeName: SCIAccent(),
                }];
                if ([row[kSCIRowNote] length]) {
                    [text appendAttributedString:[[NSAttributedString alloc] initWithString:[@"\n" stringByAppendingString:row[kSCIRowNote]] attributes:@{
                        NSFontAttributeName: noteFont,
                        NSForegroundColorAttributeName: [UIColor secondaryLabelColor],
                    }]];
                }
                content.secondaryAttributedText = text;
                cell.contentConfiguration = content;
            }
            cell.accessories = @[[[UICellAccessoryDisclosureIndicator alloc] init]];
        } else if (isLink) {
            cell.accessories = @[[[UICellAccessoryDisclosureIndicator alloc] init]];
        } else {
            // A new switch each time the cell is configured, so a recycled cell never carries the previous row's
            // handler (the old screen kept one switch per cell and re-pointed it by tag).
            NSString *pref = row[kSCIRowPref];
            UISwitch *toggle = [[UISwitch alloc] init];
            toggle.onTintColor = SCIAccent();
            toggle.on = pref.length ? SCIPrefEnabled(pref) : NO;
            [toggle addAction:[UIAction actionWithHandler:^(UIAction *action) {
                if (!pref.length) return;
                [[NSUserDefaults standardUserDefaults] setBool:toggle.isOn forKey:pref];
                [weakSelf.haptic selectionChanged];
            }] forControlEvents:UIControlEventValueChanged];
            UICellAccessoryCustomView *accessory =
                [[UICellAccessoryCustomView alloc] initWithCustomView:toggle placement:UICellAccessoryPlacementTrailing];
            accessory.maintainsFixedSize = YES;
            cell.accessories = @[accessory];
        }
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // Rebuilt on return rather than cached: a switch changed on a section page must be reflected by the count on the
    // row that opened it.
    self.sections = SCITTSections();
    [self.collection reloadData];
    SCITTCacheRefreshSize();
}

- (void)dismissSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

// MARK: Data

- (NSArray<NSDictionary *> *)rowsForSection {
    return self.focus ? self.focus[kSCISectionRows] : nil;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return self.focus ? 1 : 2;   // the header, then the list of categories
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    if (self.focus) return (NSInteger)[self rowsForSection].count;
    return section == 0 ? 1 : (NSInteger)self.sections.count;
}

/// How many switches in a section are on, and how many there are.
- (void)countOn:(NSInteger *)on of:(NSInteger *)total in:(NSArray<NSDictionary *> *)rows {
    *on = 0; *total = 0;
    for (NSDictionary *row in rows) {
        NSString *pref = row[kSCIRowPref];
        if (!pref.length) continue;
        if ([row[kSCIRowKind] isEqualToString:kSCIKindChoice]) continue;   // a choice is a value, not an on/off
        (*total)++;
        if (SCIPrefEnabled(pref)) (*on)++;
    }
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    if (!self.focus && indexPath.section == 0) {
        return [collectionView dequeueConfiguredReusableCellWithRegistration:self.headerRegistration
                                                                forIndexPath:indexPath item:@YES];
    }

    if (!self.focus) {
        NSDictionary *section = (NSUInteger)indexPath.item < self.sections.count ? self.sections[(NSUInteger)indexPath.item] : @{};
        return [collectionView dequeueConfiguredReusableCellWithRegistration:self.categoryRegistration
                                                                forIndexPath:indexPath item:section];
    }

    NSArray<NSDictionary *> *rows = [self rowsForSection];
    NSDictionary *row = (NSUInteger)indexPath.item < rows.count ? rows[(NSUInteger)indexPath.item] : @{};
    return [collectionView dequeueConfiguredReusableCellWithRegistration:self.optionRegistration
                                                            forIndexPath:indexPath item:row];
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    return self.focus || indexPath.section != 0;   // the header is not a row
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [collectionView deselectItemAtIndexPath:indexPath animated:YES];

    // At the root, a category opens its own page.
    if (!self.focus) {
        if (indexPath.section != 1) return;
        if (indexPath.item < 0 || indexPath.item >= (NSInteger)self.sections.count) return;

        SCITTStatus *page = [[SCITTStatus alloc] init];
        page.focus = self.sections[(NSUInteger)indexPath.item];
        [self.navigationController pushViewController:page animated:YES];
        return;
    }

    NSArray<NSDictionary *> *rows = [self rowsForSection];
    if (indexPath.item < 0 || indexPath.item >= (NSInteger)rows.count) return;

    NSDictionary *row = rows[(NSUInteger)indexPath.item];
    NSString *kind = row[kSCIRowKind];

    if ([kind isEqualToString:kSCIKindAction]) {
        void (^action)(void) = row[kSCIRowAction];
        if (action) action();
        return;
    }

    if ([kind isEqualToString:kSCIKindChoice]) {
        SCITTChoiceList *list = [[SCITTChoiceList alloc] initWithTitle:row[kSCIRowTitle] pref:row[kSCIRowPref]
                                                               options:row[kSCIRowOptions] footer:row[kSCIRowChoiceFooter]];
        [self.navigationController pushViewController:list animated:YES];
        return;
    }

    if ([kind isEqualToString:kSCIKindLink]) {
        if ([row[kSCIRowDestination] isEqualToString:kSCIDestinationWelcome]) {
            // Dismissed first: the welcome screen draws into the key window, so leaving this sheet up would put it
            // behind the settings it was asked for from.
            [self dismissViewControllerAnimated:YES completion:^{ [SCITTWelcome show]; }];
        } else if ([row[kSCIRowDestination] isEqualToString:kSCIDestinationReport]) {
            [self.navigationController pushViewController:[[SCITTReport alloc] init] animated:YES];
        }
        return;
    }

    // A switch row: the whole row is the control, as in every native list, not only the small switch at its end.
    UICollectionViewListCell *cell = (UICollectionViewListCell *)[collectionView cellForItemAtIndexPath:indexPath];
    for (UICellAccessory *accessory in cell.accessories) {
        if (![accessory isKindOfClass:[UICellAccessoryCustomView class]]) continue;
        UIView *view = ((UICellAccessoryCustomView *)accessory).customView;
        if ([view isKindOfClass:[UISwitch class]]) {
            UISwitch *toggle = (UISwitch *)view;
            [toggle setOn:!toggle.isOn animated:YES];
            [toggle sendActionsForControlEvents:UIControlEventValueChanged];
        }
    }
}

@end
