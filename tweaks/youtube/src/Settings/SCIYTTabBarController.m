#import "SCIYTTabBarController.h"
#import "../Features/Tabs/SCIYTTabBar.h"
#import "../Features/Tabs/SCIYTHistoryTab.h"
#import "../Localization/SCILocalize.h"
#import "../UI/SCIYTWindow.h"

@interface SCIYTTabBarController ()
@property (nonatomic, strong) NSMutableArray<NSString *> *active;
@property (nonatomic, strong) NSMutableArray<NSString *> *inactive;
@property (nonatomic, strong) UIStackView *preview;
@end

@implementation SCIYTTabBarController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) [self buildLists];
    return self;
}

/// The stored arrangement, reconciled against what the bar has actually been handed.
///
/// Reconciled rather than trusted, because the two can disagree in both directions: YouTube
/// can add a tab this list has never heard of, and an account change can take one away. A
/// stored identifier no longer seen is dropped from the screen (it costs nothing to keep in
/// the preference, and the arranger ignores what it cannot find); a seen identifier the
/// stored order does not mention joins the active list at the end, which is exactly where
/// the arranger would put it.
- (void)buildLists {
    // History is offered whether or not it has ever been seen, because it cannot be seen
    // until it is switched on -- it is a tab this tweak adds, not one YouTube handed over.
    // Everything else on this screen is something the bar actually reported.
    NSMutableArray<NSString *> *candidates =
        [NSMutableArray arrayWithArray:SCIYTTabBarSeenIdentifiers()];
    if (![candidates containsObject:SCIYTHistoryPivot]) [candidates addObject:SCIYTHistoryPivot];
    NSArray<NSString *> *seen = candidates;
    NSArray<NSString *> *storedOrder = SCIYTTabBarActiveOrder();
    NSArray<NSString *> *storedHidden = SCIYTTabBarHiddenIdentifiers();

    self.active = [NSMutableArray array];
    self.inactive = [NSMutableArray array];

    for (NSString *identifier in storedOrder) {
        if ([seen containsObject:identifier]) [self.active addObject:identifier];
    }
    for (NSString *identifier in seen) {
        if ([self.active containsObject:identifier]) continue;

        // A tab YouTube handed over defaults to active -- it is already in the bar, and a
        // fresh install should change nothing. History defaults the other way for the same
        // reason: YouTube did not put it there, so switching it on is a deliberate act.
        BOOL defaultsOff = [identifier isEqualToString:SCIYTHistoryPivot];
        if ([storedHidden containsObject:identifier] || defaultsOff) {
            [self.inactive addObject:identifier];
        } else {
            [self.active addObject:identifier];
        }
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = SCILocalized(@"set_tabs_arrange");

    // Always editing. The reorder control is the entire interface, and making somebody
    // press Edit first to discover that is a screen that looks like it does nothing.
    self.tableView.editing = YES;
    self.tableView.allowsSelectionDuringEditing = NO;

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:SCILocalized(@"done")
                                         style:UIBarButtonItemStyleDone
                                        target:self
                                        action:@selector(finish)];
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:SCILocalized(@"tabs_reset")
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(reset)];

    self.tableView.tableHeaderView = [self buildPreview];
}

/// A sketch of the bar, above the lists.
///
/// **A sketch and not a copy, deliberately.** The icons are SF Symbols chosen here, not
/// YouTube's own artwork — the real icons come from a `YTIIcon` whose `iconType` enum is not
/// readable from the binary, which is the same reason the Download Centre tab paints its
/// mark rather than setting one. So this shows *order and count*, which is what is being
/// edited, and does not pretend to show the finished bar.
- (UIView *)buildPreview {
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 92)];

    UILabel *caption = [[UILabel alloc] init];
    caption.text = SCILocalized(@"tabs_preview");
    caption.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    caption.textColor = [UIColor secondaryLabelColor];
    caption.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:caption];

    UIView *bar = [[UIView alloc] init];
    bar.backgroundColor = [UIColor secondarySystemBackgroundColor];
    bar.layer.cornerRadius = 14;
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:bar];

    self.preview = [[UIStackView alloc] init];
    self.preview.axis = UILayoutConstraintAxisHorizontal;
    self.preview.distribution = UIStackViewDistributionFillEqually;
    self.preview.alignment = UIStackViewAlignmentCenter;
    self.preview.translatesAutoresizingMaskIntoConstraints = NO;
    [bar addSubview:self.preview];

    [NSLayoutConstraint activateConstraints:@[
        [caption.topAnchor constraintEqualToAnchor:container.topAnchor constant:4],
        [caption.leadingAnchor constraintEqualToAnchor:container.layoutMarginsGuide.leadingAnchor],
        [bar.topAnchor constraintEqualToAnchor:caption.bottomAnchor constant:6],
        [bar.leadingAnchor constraintEqualToAnchor:container.layoutMarginsGuide.leadingAnchor],
        [bar.trailingAnchor constraintEqualToAnchor:container.layoutMarginsGuide.trailingAnchor],
        [bar.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-8],
        [self.preview.topAnchor constraintEqualToAnchor:bar.topAnchor constant:8],
        [self.preview.bottomAnchor constraintEqualToAnchor:bar.bottomAnchor constant:-8],
        [self.preview.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor constant:8],
        [self.preview.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor constant:-8],
    ]];

    [self refreshPreview];
    return container;
}

- (void)refreshPreview {
    for (UIView *view in self.preview.arrangedSubviews) [view removeFromSuperview];

    for (NSString *identifier in self.active) {
        UIStackView *column = [[UIStackView alloc] init];
        column.axis = UILayoutConstraintAxisVertical;
        column.alignment = UIStackViewAlignmentCenter;
        column.spacing = 2;

        UIImageView *icon = [[UIImageView alloc]
            initWithImage:[UIImage systemImageNamed:SCIYTTabBarSymbolFor(identifier)]];
        icon.tintColor = [UIColor labelColor];
        icon.contentMode = UIViewContentModeScaleAspectFit;
        [icon.heightAnchor constraintEqualToConstant:20].active = YES;

        UILabel *label = [[UILabel alloc] init];
        label.text = SCIYTTabBarDisplayName(identifier);
        label.font = [UIFont systemFontOfSize:9];
        label.textColor = [UIColor secondaryLabelColor];
        label.textAlignment = NSTextAlignmentCenter;
        label.adjustsFontSizeToFitWidth = YES;
        label.minimumScaleFactor = 0.7;

        [column addArrangedSubview:icon];
        [column addArrangedSubview:label];
        [self.preview addArrangedSubview:column];
    }
}

- (void)finish {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)reset {
    SCIYTTabBarSetActiveOrder(@[], @[]);
    [self buildLists];
    [self.tableView reloadData];
    [self refreshPreview];
}

/// Saved on every change rather than on Done, so a screen dismissed by swiping it away --
/// which is how a sheet is usually closed -- does not quietly throw the arrangement out.
- (void)save {
    SCIYTTabBarSetActiveOrder([self.active copy], [self.inactive copy]);
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? (NSInteger)self.active.count : (NSInteger)self.inactive.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return SCILocalized(section == 0 ? @"tabs_active" : @"tabs_inactive");
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 1) return SCILocalized(@"tabs_inactive_note");
    if (!SCIYTTabBarSeenIdentifiers().count) return SCILocalized(@"tabs_empty_note");
    return SCILocalized(@"tabs_max_note");
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"tab"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:@"tab"];
    }

    NSArray<NSString *> *list = indexPath.section == 0 ? self.active : self.inactive;
    NSString *identifier = list[(NSUInteger)indexPath.row];

    cell.textLabel.text = SCIYTTabBarDisplayName(identifier);
    // The raw identifier under the name, always. It is what the arranger matches on, so a
    // report saying "seen: FEshorts" and a row saying "Shorts" have to be visibly the same
    // thing -- and for a tab this build has no name for, it is the only label there is.
    cell.detailTextLabel.text = identifier;
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    cell.showsReorderControl = YES;
    return cell;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
           editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    // No delete badge. Nothing here is deleted -- a tab is moved between two lists, and an
    // interface offering to delete one would be promising something it cannot do.
    return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

/// Refuses a move that would empty the active list or take it past six.
///
/// Refused at the proposal rather than undone after the fact: the row simply will not go,
/// which reads as a limit, where accepting the drop and snapping it back reads as a bug.
- (NSIndexPath *)tableView:(UITableView *)tableView
targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)from
       toProposedIndexPath:(NSIndexPath *)proposed {
    if (from.section == 0 && proposed.section == 1 && self.active.count <= 1) return from;
    if (from.section == 1 && proposed.section == 0 && self.active.count >= SCIYTTabBarMaximum) {
        return from;
    }
    return proposed;
}

- (void)tableView:(UITableView *)tableView
moveRowAtIndexPath:(NSIndexPath *)from
      toIndexPath:(NSIndexPath *)to {
    NSMutableArray<NSString *> *source = from.section == 0 ? self.active : self.inactive;
    NSMutableArray<NSString *> *destination = to.section == 0 ? self.active : self.inactive;

    NSString *identifier = source[(NSUInteger)from.row];
    [source removeObjectAtIndex:(NSUInteger)from.row];

    NSUInteger index = MIN((NSUInteger)to.row, destination.count);
    [destination insertObject:identifier atIndex:index];

    [self save];
    [self refreshPreview];
}

#pragma mark - Presenting

+ (void)present {
    UIViewController *top = SCIYTTopViewController();
    if (!top) return;

    SCIYTTabBarController *controller = [[SCIYTTabBarController alloc] init];
    UINavigationController *navigation =
        [[UINavigationController alloc] initWithRootViewController:controller];
    [top presentViewController:navigation animated:YES completion:nil];
}

@end
