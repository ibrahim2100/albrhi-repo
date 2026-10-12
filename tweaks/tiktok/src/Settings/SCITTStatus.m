//
//  SCITTStatus.m
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCITTStatus.h"
#import "SCITTSectionRegistry.h"
#import "SCITTBadge.h"
#import "SCITTReport.h"
#import "../UI/SCITTWelcome.h"
#import "../Tweak.h"
#import "../Prefs.h"
#import "../Localization/SCILocalize.h"
#import "shared/src/SCIPanelGate.h"

// MARK: - Cards

///
/// **One cell class per shape, and three shapes is the whole screen.**
///
/// The old screen drew everything with `UITableViewCellStyleSubtitle` and an image view, which is
/// why every row looked like every other row whether it was a switch, a link or a heading. A card
/// that holds a switch and a card that opens a page are different things and now look different.
///

/// The identity card: the mark, the name, the version, and how much is switched on.
@interface SCITTHeroCard : UICollectionViewCell
@property (nonatomic, strong) UILabel *title;
@property (nonatomic, strong) UILabel *subtitle;
@property (nonatomic, strong) UILabel *tally;
@property (nonatomic, strong) UIView *warning;
@property (nonatomic, strong) UILabel *warningText;
@end

@implementation SCITTHeroCard

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return self;

    self.contentView.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    self.contentView.layer.cornerRadius = 22;
    self.contentView.layer.cornerCurve = kCACornerCurveContinuous;

    // The mark is the download glyph on an accent disc: the same arrow as the button in the feed
    // and the icon on the saving banner. Three places, one identity -- and deliberately not
    // TikTok's own music note, which would be borrowing somebody else's mark.
    UIView *disc = [[UIView alloc] init];
    disc.backgroundColor = SCIAccent();
    disc.layer.cornerRadius = 15;
    disc.layer.cornerCurve = kCACornerCurveContinuous;
    disc.translatesAutoresizingMaskIntoConstraints = NO;

    UIImageView *glyph = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:@"arrow.down"
                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:15
                                                                                 weight:UIImageSymbolWeightBold]]];
    glyph.tintColor = [UIColor whiteColor];
    glyph.translatesAutoresizingMaskIntoConstraints = NO;
    [disc addSubview:glyph];

    self.title = [[UILabel alloc] init];
    self.title.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    self.title.textColor = [UIColor labelColor];
    self.title.translatesAutoresizingMaskIntoConstraints = NO;

    self.subtitle = [[UILabel alloc] init];
    self.subtitle.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightMedium];
    self.subtitle.textColor = [UIColor secondaryLabelColor];
    self.subtitle.translatesAutoresizingMaskIntoConstraints = NO;

    self.tally = [[UILabel alloc] init];
    self.tally.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    self.tally.textColor = SCIAccent();
    self.tally.translatesAutoresizingMaskIntoConstraints = NO;

    self.warning = [[UIView alloc] init];
    self.warning.backgroundColor = [[UIColor systemRedColor] colorWithAlphaComponent:0.14];
    self.warning.layer.cornerRadius = 12;
    self.warning.layer.cornerCurve = kCACornerCurveContinuous;
    self.warning.translatesAutoresizingMaskIntoConstraints = NO;
    self.warning.hidden = YES;

    self.warningText = [[UILabel alloc] init];
    self.warningText.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    self.warningText.textColor = [UIColor systemRedColor];
    self.warningText.numberOfLines = 0;
    self.warningText.translatesAutoresizingMaskIntoConstraints = NO;
    [self.warning addSubview:self.warningText];

    for (UIView *view in @[disc, self.title, self.subtitle, self.tally, self.warning]) {
        [self.contentView addSubview:view];
    }

    [NSLayoutConstraint activateConstraints:@[
        [disc.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18],
        [disc.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:18],
        [disc.widthAnchor constraintEqualToConstant:30],
        [disc.heightAnchor constraintEqualToConstant:30],
        [glyph.centerXAnchor constraintEqualToAnchor:disc.centerXAnchor],
        [glyph.centerYAnchor constraintEqualToAnchor:disc.centerYAnchor],

        [self.title.leadingAnchor constraintEqualToAnchor:disc.trailingAnchor constant:12],
        [self.title.centerYAnchor constraintEqualToAnchor:disc.centerYAnchor],
        [self.title.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-18],

        [self.subtitle.leadingAnchor constraintEqualToAnchor:disc.leadingAnchor],
        [self.subtitle.topAnchor constraintEqualToAnchor:disc.bottomAnchor constant:12],

        [self.tally.leadingAnchor constraintEqualToAnchor:disc.leadingAnchor],
        [self.tally.topAnchor constraintEqualToAnchor:self.subtitle.bottomAnchor constant:4],

        [self.warning.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18],
        [self.warning.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18],
        [self.warning.topAnchor constraintEqualToAnchor:self.tally.bottomAnchor constant:12],
        [self.warning.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-18],

        [self.warningText.leadingAnchor constraintEqualToAnchor:self.warning.leadingAnchor constant:12],
        [self.warningText.trailingAnchor constraintEqualToAnchor:self.warning.trailingAnchor constant:-12],
        [self.warningText.topAnchor constraintEqualToAnchor:self.warning.topAnchor constant:10],
        [self.warningText.bottomAnchor constraintEqualToAnchor:self.warning.bottomAnchor constant:-10],
    ]];

    // With no warning the card ends under the tally, so the empty banner does not leave a gap.
    NSLayoutConstraint *tight = [self.tally.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-18];
    tight.priority = UILayoutPriorityDefaultHigh;
    tight.active = YES;

    return self;
}

@end

/// A category on the root grid: an icon in its own tinted square, a name, and a count.
@interface SCITTCategoryCard : UICollectionViewCell
@property (nonatomic, strong) UIImageView *icon;
@property (nonatomic, strong) UIView *iconWell;
@property (nonatomic, strong) UILabel *title;
@property (nonatomic, strong) UILabel *count;
@end

@implementation SCITTCategoryCard

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return self;

    self.contentView.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    self.contentView.layer.cornerRadius = 18;
    self.contentView.layer.cornerCurve = kCACornerCurveContinuous;

    self.iconWell = [[UIView alloc] init];
    self.iconWell.layer.cornerRadius = 11;
    self.iconWell.layer.cornerCurve = kCACornerCurveContinuous;
    self.iconWell.translatesAutoresizingMaskIntoConstraints = NO;

    self.icon = [[UIImageView alloc] init];
    self.icon.contentMode = UIViewContentModeScaleAspectFit;
    self.icon.translatesAutoresizingMaskIntoConstraints = NO;
    [self.iconWell addSubview:self.icon];

    self.title = [[UILabel alloc] init];
    self.title.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    self.title.textColor = [UIColor labelColor];
    self.title.numberOfLines = 2;
    self.title.translatesAutoresizingMaskIntoConstraints = NO;

    self.count = [[UILabel alloc] init];
    self.count.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    self.count.textColor = [UIColor secondaryLabelColor];
    self.count.translatesAutoresizingMaskIntoConstraints = NO;

    for (UIView *view in @[self.iconWell, self.title, self.count]) [self.contentView addSubview:view];

    [NSLayoutConstraint activateConstraints:@[
        [self.iconWell.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:14],
        [self.iconWell.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:14],
        [self.iconWell.widthAnchor constraintEqualToConstant:34],
        [self.iconWell.heightAnchor constraintEqualToConstant:34],

        [self.icon.centerXAnchor constraintEqualToAnchor:self.iconWell.centerXAnchor],
        [self.icon.centerYAnchor constraintEqualToAnchor:self.iconWell.centerYAnchor],
        [self.icon.widthAnchor constraintEqualToConstant:18],
        [self.icon.heightAnchor constraintEqualToConstant:18],

        [self.title.leadingAnchor constraintEqualToAnchor:self.iconWell.leadingAnchor],
        [self.title.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
        [self.title.topAnchor constraintEqualToAnchor:self.iconWell.bottomAnchor constant:10],

        [self.count.leadingAnchor constraintEqualToAnchor:self.iconWell.leadingAnchor],
        [self.count.topAnchor constraintEqualToAnchor:self.title.bottomAnchor constant:2],
        [self.count.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-14],
    ]];

    return self;
}

/// The press state, because a card that opens a page should say so when it is touched.
- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [UIView animateWithDuration:0.12 animations:^{
        self.contentView.transform = highlighted ? CGAffineTransformMakeScale(0.97, 0.97)
                                                 : CGAffineTransformIdentity;
    }];
}

@end

/// One option: icon, name, what it does, and the switch that does it.
@interface SCITTOptionCard : UICollectionViewCell
@property (nonatomic, strong) UIImageView *icon;
@property (nonatomic, strong) UIView *iconWell;
@property (nonatomic, strong) UILabel *title;
@property (nonatomic, strong) UILabel *note;
@property (nonatomic, strong) UISwitch *toggle;
@property (nonatomic, strong) UIImageView *chevron;
@end

@implementation SCITTOptionCard

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return self;

    self.contentView.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    self.contentView.layer.cornerRadius = 16;
    self.contentView.layer.cornerCurve = kCACornerCurveContinuous;

    self.iconWell = [[UIView alloc] init];
    self.iconWell.layer.cornerRadius = 9;
    self.iconWell.layer.cornerCurve = kCACornerCurveContinuous;
    self.iconWell.translatesAutoresizingMaskIntoConstraints = NO;

    self.icon = [[UIImageView alloc] init];
    self.icon.contentMode = UIViewContentModeScaleAspectFit;
    self.icon.translatesAutoresizingMaskIntoConstraints = NO;
    [self.iconWell addSubview:self.icon];

    self.title = [[UILabel alloc] init];
    self.title.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    self.title.textColor = [UIColor labelColor];
    self.title.numberOfLines = 0;
    self.title.translatesAutoresizingMaskIntoConstraints = NO;

    self.note = [[UILabel alloc] init];
    self.note.font = [UIFont systemFontOfSize:13];
    self.note.textColor = [UIColor secondaryLabelColor];
    self.note.numberOfLines = 0;
    self.note.translatesAutoresizingMaskIntoConstraints = NO;

    self.toggle = [[UISwitch alloc] init];
    self.toggle.onTintColor = SCIAccent();
    self.toggle.translatesAutoresizingMaskIntoConstraints = NO;

    self.chevron = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:@"chevron.right"
                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:13
                                                                                 weight:UIImageSymbolWeightSemibold]]];
    self.chevron.tintColor = [UIColor tertiaryLabelColor];
    self.chevron.translatesAutoresizingMaskIntoConstraints = NO;
    self.chevron.hidden = YES;

    for (UIView *view in @[self.iconWell, self.title, self.note, self.toggle, self.chevron]) {
        [self.contentView addSubview:view];
    }

    [NSLayoutConstraint activateConstraints:@[
        [self.iconWell.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:14],
        [self.iconWell.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:14],
        [self.iconWell.widthAnchor constraintEqualToConstant:30],
        [self.iconWell.heightAnchor constraintEqualToConstant:30],

        [self.icon.centerXAnchor constraintEqualToAnchor:self.iconWell.centerXAnchor],
        [self.icon.centerYAnchor constraintEqualToAnchor:self.iconWell.centerYAnchor],
        [self.icon.widthAnchor constraintEqualToConstant:16],
        [self.icon.heightAnchor constraintEqualToConstant:16],

        [self.title.leadingAnchor constraintEqualToAnchor:self.iconWell.trailingAnchor constant:12],
        [self.title.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:14],
        [self.title.trailingAnchor constraintEqualToAnchor:self.toggle.leadingAnchor constant:-12],

        [self.note.leadingAnchor constraintEqualToAnchor:self.title.leadingAnchor],
        [self.note.trailingAnchor constraintEqualToAnchor:self.toggle.leadingAnchor constant:-12],
        [self.note.topAnchor constraintEqualToAnchor:self.title.bottomAnchor constant:3],
        [self.note.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-14],

        [self.toggle.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-14],
        [self.toggle.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],

        [self.chevron.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [self.chevron.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
    ]];

    return self;
}

@end

// MARK: - The screen

@interface SCITTStatus () <UICollectionViewDataSource, UICollectionViewDelegate>
@property (nonatomic, strong) UICollectionView *collection;
@property (nonatomic, strong) NSArray<NSDictionary *> *sections;

/// The section this page is showing, or nil for the root. One controller does both, because the
/// card drawing and the switch handling are the same either way.
@property (nonatomic, strong, nullable) NSDictionary *focus;
@end

@implementation SCITTStatus

+ (void)present {
    SCITTStatus *screen = [[SCITTStatus alloc] init];

    UINavigationController *host = [[UINavigationController alloc] initWithRootViewController:screen];
    host.modalPresentationStyle = UIModalPresentationPageSheet;
    host.view.tintColor = SCIAccent();

    UIWindow *key = nil;
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window.isKeyWindow) { key = window; break; }
    }

    UIViewController *top = key.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;

    [top presentViewController:host animated:YES completion:nil];
}

// MARK: Layout

///
/// **A layout per section rather than one for the screen.**
///
/// The identity card is full width and sized to its own contents; the categories are a two-column
/// grid; an option is a full-width card that grows with its note. A table view can express exactly
/// one of those three, which is why the old screen made all three look the same.
///
- (UICollectionViewLayout *)buildLayout {
    UICollectionViewCompositionalLayoutConfiguration *configuration =
        [[UICollectionViewCompositionalLayoutConfiguration alloc] init];
    configuration.interSectionSpacing = 14;

    __weak typeof(self) weakSelf = self;

    UICollectionViewCompositionalLayout *layout = [[UICollectionViewCompositionalLayout alloc]
        initWithSectionProvider:^NSCollectionLayoutSection *(NSInteger index,
                                                            id<NSCollectionLayoutEnvironment> environment) {
        typeof(self) self = weakSelf;
        if (!self) return nil;

        BOOL grid = (!self.focus && index == 1);

        NSCollectionLayoutSize *itemSize = [NSCollectionLayoutSize
            sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:grid ? 0.5 : 1.0]
                   heightDimension:[NSCollectionLayoutDimension estimatedDimension:grid ? 116 : 84]];
        NSCollectionLayoutItem *item = [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

        NSCollectionLayoutSize *groupSize = [NSCollectionLayoutSize
            sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                   heightDimension:[NSCollectionLayoutDimension estimatedDimension:grid ? 116 : 84]];

        NSCollectionLayoutGroup *group = grid
            ? [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:groupSize subitem:item count:2]
            : [NSCollectionLayoutGroup verticalGroupWithLayoutSize:groupSize subitems:@[item]];
        group.interItemSpacing = [NSCollectionLayoutSpacing fixedSpacing:12];

        NSCollectionLayoutSection *section = [NSCollectionLayoutSection sectionWithGroup:group];
        section.interGroupSpacing = 12;
        section.contentInsets = NSDirectionalEdgeInsetsMake(0, 16, 0, 16);
        return section;
    } configuration:configuration];

    return layout;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.sections = SCITTSections();
    self.title = self.focus ? self.focus[kSCISectionTitle] : SCILocalized(@"title");
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];

    self.navigationItem.largeTitleDisplayMode = self.focus
        ? UINavigationItemLargeTitleDisplayModeNever
        : UINavigationItemLargeTitleDisplayModeAlways;
    self.navigationController.navigationBar.prefersLargeTitles = !self.focus;

    // Only the root closes the sheet; a pushed page has a back chevron already.
    if (!self.focus) {
        self.navigationItem.rightBarButtonItem =
            [[UIBarButtonItem alloc] initWithTitle:SCILocalized(@"done")
                                             style:UIBarButtonItemStyleDone
                                            target:self
                                            action:@selector(dismissSelf)];
    }

    self.collection = [[UICollectionView alloc] initWithFrame:self.view.bounds
                                       collectionViewLayout:[self buildLayout]];
    self.collection.backgroundColor = [UIColor clearColor];
    self.collection.alwaysBounceVertical = YES;
    self.collection.contentInset = UIEdgeInsetsMake(12, 0, 28, 0);
    self.collection.dataSource = self;
    self.collection.delegate = self;
    self.collection.translatesAutoresizingMaskIntoConstraints = NO;

    [self.collection registerClass:[SCITTHeroCard class] forCellWithReuseIdentifier:@"hero"];
    [self.collection registerClass:[SCITTCategoryCard class] forCellWithReuseIdentifier:@"category"];
    [self.collection registerClass:[SCITTOptionCard class] forCellWithReuseIdentifier:@"option"];

    [self.view addSubview:self.collection];
    [NSLayoutConstraint activateConstraints:@[
        [self.collection.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.collection.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.collection.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.collection.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // Rebuilt on return rather than cached: a switch changed on a section page must be reflected
    // by the count on the card that opened it.
    self.sections = SCITTSections();
    [self.collection reloadData];
}

- (void)dismissSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

// MARK: Data

- (NSArray<NSDictionary *> *)rowsForSection {
    return self.focus ? self.focus[kSCISectionRows] : nil;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return self.focus ? 1 : 2;   // identity, then the grid of categories
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
        (*total)++;
        if (SCIPrefEnabled(pref)) (*on)++;
    }
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {

    // The identity card, at the top of the root and nowhere else.
    if (!self.focus && indexPath.section == 0) {
        SCITTHeroCard *card = [collectionView dequeueReusableCellWithReuseIdentifier:@"hero" forIndexPath:indexPath];
        card.title.text = SCILocalized(@"title");
        card.subtitle.text = [NSString stringWithFormat:@"%@ · TikTok %@", SCIVersionString,
            [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"?"];

        NSInteger on = 0, total = 0;
        for (NSDictionary *section in self.sections) {
            NSInteger sectionOn = 0, sectionTotal = 0;
            [self countOn:&sectionOn of:&sectionTotal in:section[kSCISectionRows]];
            on += sectionOn; total += sectionTotal;
        }
        card.tally.text = [NSString stringWithFormat:SCILocalized(@"hero_tally"), (long)on, (long)total];

        // The gate has the last word over every switch above, so when it is closed the card says
        // so rather than leaving a screen full of switches that are being ignored.
        BOOL allowed = SCIPanelAllowsThisApp();
        card.warning.hidden = allowed;
        card.warningText.text = allowed ? nil : SCILocalized(@"gate_off");
        return card;
    }

    // A category on the root grid.
    if (!self.focus) {
        SCITTCategoryCard *card = [collectionView dequeueReusableCellWithReuseIdentifier:@"category" forIndexPath:indexPath];
        NSDictionary *section = self.sections[(NSUInteger)indexPath.item];
        NSArray<NSDictionary *> *rows = section[kSCISectionRows];

        card.title.text = section[kSCISectionTitle];

        NSInteger on = 0, total = 0;
        [self countOn:&on of:&total in:rows];
        card.count.text = total > 0
            ? [NSString stringWithFormat:SCILocalized(@"hero_tally"), (long)on, (long)total]
            : [NSString stringWithFormat:SCILocalized(@"section_count"), (unsigned long)rows.count];

        UIColor *tint = section[kSCISectionColor] ?: SCIAccent();
        card.iconWell.backgroundColor = [tint colorWithAlphaComponent:0.16];
        card.icon.image = [UIImage systemImageNamed:(section[kSCISectionIcon] ?: @"square.grid.2x2.fill")
                                  withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:16
                                                                                                   weight:UIImageSymbolWeightSemibold]];
        card.icon.tintColor = tint;
        return card;
    }

    // An option inside a section.
    SCITTOptionCard *card = [collectionView dequeueReusableCellWithReuseIdentifier:@"option" forIndexPath:indexPath];
    NSArray<NSDictionary *> *rows = [self rowsForSection];
    if (indexPath.item < 0 || indexPath.item >= (NSInteger)rows.count) return card;

    NSDictionary *row = rows[(NSUInteger)indexPath.item];

    card.title.text = row[kSCIRowTitle];
    card.note.text = row[kSCIRowNote];
    card.note.textColor = [row[kSCIRowWarns] boolValue] ? [UIColor systemOrangeColor]
                                                        : [UIColor secondaryLabelColor];

    UIColor *tint = row[kSCIRowColor] ?: SCIAccent();
    card.iconWell.backgroundColor = [tint colorWithAlphaComponent:0.16];
    card.icon.image = [UIImage systemImageNamed:(row[kSCIRowIcon] ?: @"circle.fill")
                              withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14
                                                                                                weight:UIImageSymbolWeightSemibold]];
    card.icon.tintColor = tint;

    BOOL isLink = [row[kSCIRowKind] isEqualToString:kSCIKindLink];
    card.toggle.hidden = isLink;
    card.chevron.hidden = !isLink;

    if (!isLink) {
        NSString *pref = row[kSCIRowPref];
        card.toggle.on = pref.length ? SCIPrefEnabled(pref) : NO;
        card.toggle.tag = indexPath.item;
        [card.toggle removeTarget:self action:NULL forControlEvents:UIControlEventValueChanged];
        [card.toggle addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged];
    }

    return card;
}

- (void)toggled:(UISwitch *)toggle {
    NSArray<NSDictionary *> *rows = [self rowsForSection];
    NSInteger index = toggle.tag;
    if (index < 0 || index >= (NSInteger)rows.count) return;

    NSString *pref = rows[(NSUInteger)index][kSCIRowPref];
    if (!pref.length) return;

    [[NSUserDefaults standardUserDefaults] setBool:toggle.isOn forKey:pref];
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
    if (![row[kSCIRowKind] isEqualToString:kSCIKindLink]) return;

    if ([row[kSCIRowDestination] isEqualToString:kSCIDestinationWelcome]) {
        // Dismissed first: the welcome screen draws into the key window, so leaving this sheet up
        // would put it behind the settings it was asked for from.
        [self dismissViewControllerAnimated:YES completion:^{ [SCITTWelcome show]; }];
        return;
    }

    if ([row[kSCIRowDestination] isEqualToString:kSCIDestinationReport]) {
        [self.navigationController pushViewController:[[SCITTReport alloc] init] animated:YES];
    }
}

@end
