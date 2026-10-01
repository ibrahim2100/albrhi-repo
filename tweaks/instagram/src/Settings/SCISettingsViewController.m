#import "SCISettingsViewController.h"
#import "../SCILog.h"
#import "../Tweak.h"   // SCIVersionString
#import "SCIQuickPresets.h"

static char rowStaticRef[] = "row";

@interface SCISettingsViewController () <UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, copy) NSArray *sections;
@property (nonatomic) BOOL reduceMargin;

// Search: a flat index of every leaf setting across the whole tree, and the
// filtered sections shown while a query is active.
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, copy) NSArray<SCISetting *> *searchIndex;
@property (nonatomic, copy) NSArray *filteredSections;

@end

///

@implementation SCISettingsViewController

- (instancetype)initWithTitle:(NSString *)title sections:(NSArray *)sections reduceMargin:(BOOL)reduceMargin {
    self = [super init];
    
    if (self) {
        self.title = title;
        self.reduceMargin = reduceMargin;
        
        // Exclude development cells from release builds
        NSMutableArray *mutableSections = [sections mutableCopy];
        
        [mutableSections enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSDictionary *section, NSUInteger index, BOOL *stop) {
        
            if ([section[@"header"] hasPrefix:@"_"] && [section[@"footer"] hasPrefix:@"_"]) {
                if (![[SCIUtils IGVersionString] isEqualToString:@"0.0.0"]) {
                    [mutableSections removeObjectAtIndex:index];
                }
            }

            else if ([section[@"header"] isEqualToString:@"Experimental"]) {
                if (![[SCIUtils IGVersionString] hasSuffix:@"-dev"]) {
                    [mutableSections removeObjectAtIndex:index];
                }
            }
            
        }];
        
        self.sections = [mutableSections copy];
    }
    
    
    return self;
}

- (instancetype)init {
    return [self initWithTitle:[SCITweakSettings title] sections:[SCITweakSettings sections] reduceMargin:YES];
}

/// Redrawn on every appearance, so a checklist row counts what is on *now*: its screen opens above
/// this one, a switch is changed there, and coming back has to show it.
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationController.navigationBar.prefersLargeTitles = NO;
    self.view.backgroundColor = UIColor.systemBackgroundColor;

    // Albrhi accent — tint interactive elements with the brand colour
    UIColor *accent = [SCIUtils SCIColor_Primary];
    self.view.tintColor = accent;
    self.navigationController.navigationBar.tintColor = accent;

    // Right-to-left layout when the active language is Arabic
    UISemanticContentAttribute semantic = [SCILocalize isRTL]
        ? UISemanticContentAttributeForceRightToLeft
        : UISemanticContentAttributeForceLeftToRight;
    self.view.semanticContentAttribute = semantic;

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.contentInset = UIEdgeInsetsMake(self.reduceMargin ? -30 : -10, 0, 0, 0);
    self.tableView.delegate = self;
    self.tableView.semanticContentAttribute = semantic;
    self.tableView.tintColor = accent;

    [self.view addSubview:self.tableView];

    // Brand header on the root page — a small identity card above the list.
    if (self.reduceMargin) {
        self.tableView.tableHeaderView = [self brandHeaderView];
    }

    // Search only on the root page — sub-pages are already short lists.
    if (self.reduceMargin) {
        self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
        self.searchController.searchResultsUpdater = self;
        self.searchController.obscuresBackgroundDuringPresentation = NO;
        self.searchController.searchBar.placeholder = SCILocalized(@"p_search_placeholder");
        self.searchController.searchBar.tintColor = accent;
        self.searchController.searchBar.semanticContentAttribute = semantic;
        self.navigationItem.searchController = self.searchController;
        self.navigationItem.hidesSearchBarWhenScrolling = NO;
        self.definesPresentationContext = YES;
    }
}

// MARK: - Brand header

- (UIView *)brandHeaderView {
    UIColor *accent = [SCIUtils SCIColor_Primary];

    CGFloat width = CGRectGetWidth(self.view.bounds);
    // Top inset included: the search bar sits directly above this view and the
    // card was starting under it.
    CGFloat topInset = 14.0;
    CGFloat cardHeight = 104.0 + topInset;
    CGFloat height = cardHeight + [SCIQuickPresets shortcutsHeight];

    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    header.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    // A card rather than loose text: the settings are a list of grey rows, and the
    // identity was reading as one more of them.
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [accent colorWithAlphaComponent:0.12];
    card.layer.cornerRadius = 20.0;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    [header addSubview:card];

    UIView *badge = [[UIView alloc] init];
    badge.translatesAutoresizingMaskIntoConstraints = NO;
    badge.backgroundColor = accent;
    badge.layer.cornerRadius = 15.0;
    badge.layer.cornerCurve = kCACornerCurveContinuous;
    [card addSubview:badge];

    UIImageView *glyph = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:@"sparkles"
                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20.0 weight:UIImageSymbolWeightBold]]];
    glyph.translatesAutoresizingMaskIntoConstraints = NO;
    glyph.tintColor = [UIColor whiteColor];
    glyph.contentMode = UIViewContentModeScaleAspectFit;
    [badge addSubview:glyph];

    UILabel *name = [[UILabel alloc] init];
    name.translatesAutoresizingMaskIntoConstraints = NO;
    name.text = @"Albrhi";
    name.font = [UIFont systemFontOfSize:26.0 weight:UIFontWeightBold];
    name.textColor = [UIColor labelColor];
    [card addSubview:name];

    UILabel *version = [[UILabel alloc] init];
    version.translatesAutoresizingMaskIntoConstraints = NO;
    version.text = [NSString stringWithFormat:@"%@  ·  Instagram %@", SCIVersionString, [SCIUtils IGVersionString]];
    version.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    version.textColor = [UIColor secondaryLabelColor];
    [card addSubview:version];

    UIView *shortcuts = [SCIQuickPresets shortcutsViewWithWidth:width];
    shortcuts.frame = CGRectMake(0, cardHeight, width, [SCIQuickPresets shortcutsHeight]);
    shortcuts.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [header addSubview:shortcuts];

    [NSLayoutConstraint activateConstraints:@[
        [card.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16.0],
        [card.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16.0],
        [card.topAnchor constraintEqualToAnchor:header.topAnchor constant:topInset + 8.0],
        [card.heightAnchor constraintEqualToConstant:cardHeight - topInset - 16.0],

        [badge.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [badge.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [badge.widthAnchor constraintEqualToConstant:46.0],
        [badge.heightAnchor constraintEqualToConstant:46.0],

        [glyph.centerXAnchor constraintEqualToAnchor:badge.centerXAnchor],
        [glyph.centerYAnchor constraintEqualToAnchor:badge.centerYAnchor],

        [name.leadingAnchor constraintEqualToAnchor:badge.trailingAnchor constant:14.0],
        [name.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
        [name.bottomAnchor constraintEqualToAnchor:card.centerYAnchor constant:2.0],

        [version.leadingAnchor constraintEqualToAnchor:name.leadingAnchor],
        [version.trailingAnchor constraintEqualToAnchor:name.trailingAnchor],
        [version.topAnchor constraintEqualToAnchor:name.bottomAnchor constant:2.0]
    ]];

    return header;
}

// MARK: - Search

// Which sections the table shows right now: the filtered results while searching,
// otherwise the full tree.
- (NSArray *)activeSections {
    if (self.searchController.isActive && self.searchController.searchBar.text.length) {
        return self.filteredSections ?: @[];
    }
    return self.sections;
}

// Every searchable leaf across the whole tree, flattened once. Navigation rows are
// kept (so a page name is findable) and also recursed into.
- (NSArray<SCISetting *> *)flattenSections:(NSArray *)sections {
    NSMutableArray<SCISetting *> *out = [NSMutableArray array];
    for (NSDictionary *section in sections) {
        for (SCISetting *row in section[@"rows"]) {
            if (row.type == SCITableCellNavigation && row.navSections.count > 0) {
                [out addObject:row];
                [out addObjectsFromArray:[self flattenSections:row.navSections]];
            } else {
                [out addObject:row];
            }
        }
    }
    return out;
}

/// The words a setting is worth finding by, beyond the ones printed on it.
///
/// Searching only the visible text means the word you reach for has to be the word
/// the row happens to use. Someone typing "حفظ" wants the download rows; someone
/// typing "ads" in an Arabic interface finds nothing at all, and vice versa. Neither
/// is a spelling mistake — they are simply different names for the same thing.
///
/// Each entry is one idea: everything on the line finds everything else on it, in
/// both languages. Matching is on the row's own text, so nothing has to be tagged.
+ (NSArray<NSArray<NSString *> *> *)synonymGroups {
    static NSArray<NSArray<NSString *> *> *groups = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        groups = @[
            @[@"download", @"save", @"تحميل", @"تنزيل", @"حفظ"],
            @[@"video", @"reel", @"reels", @"فيديو", @"ريل", @"ريلز", @"مقطع"],
            @[@"photo", @"image", @"picture", @"صورة", @"صور"],
            @[@"story", @"stories", @"قصة", @"قصص", @"ستوري"],
            @[@"message", @"messages", @"dm", @"direct", @"chat", @"رسالة", @"رسائل", @"خاص", @"محادثة"],
            @[@"seen", @"receipt", @"read", @"مشاهدة", @"قراءة", @"مقروء", @"إيصال"],
            @[@"hide", @"remove", @"block", @"إخفاء", @"اخفاء", @"حذف", @"منع"],
            @[@"ad", @"ads", @"sponsored", @"إعلان", @"إعلانات", @"اعلانات", @"ممول"],
            @[@"quality", @"resolution", @"1080", @"2k", @"جودة", @"دقة", @"وضوح"],
            @[@"date", @"time", @"clock", @"تاريخ", @"وقت", @"توقيت", @"ساعة"],
            @[@"theme", @"colour", @"color", @"dark", @"oled", @"سمة", @"لون", @"مظهر", @"داكن", @"أسود"],
            @[@"icon", @"أيقونة", @"ايقونة", @"شعار"],
            @[@"confirm", @"ask", @"alert", @"تأكيد", @"تاكيد", @"سؤال", @"تنبيه"],
            @[@"privacy", @"private", @"hidden", @"خصوصية", @"خفي", @"سري"],
            @[@"typing", @"كتابة", @"يكتب"],
            @[@"audio", @"sound", @"music", @"voice", @"صوت", @"صوتي", @"موسيقى", @"أغنية"],
            @[@"backup", @"restore", @"export", @"import", @"نسخة", @"نسخ", @"استعادة", @"تصدير", @"استيراد"],
            @[@"language", @"arabic", @"english", @"لغة", @"عربي", @"إنجليزي"],
            @[@"profile", @"account", @"user", @"حساب", @"ملف", @"بروفايل"],
            @[@"feed", @"home", @"timeline", @"صفحة", @"رئيسية", @"تغذية"],
            @[@"comment", @"comments", @"تعليق", @"تعليقات"],
            @[@"like", @"إعجاب", @"اعجاب", @"لايك"],
            @[@"follow", @"follower", @"following", @"متابعة", @"متابع", @"يتابع"]
        ];
    });

    return groups;
}

/// Every word worth trying for this query — the query itself, plus anything that
/// means the same. A query matching no group searches for exactly what was typed.
+ (NSArray<NSString *> *)termsForQuery:(NSString *)query {
    NSMutableArray<NSString *> *terms = [NSMutableArray arrayWithObject:query];

    for (NSArray<NSString *> *group in [self synonymGroups]) {
        BOOL inGroup = NO;
        for (NSString *word in group) {
            // Prefix rather than equality, so "تحمي" on the way to "تحميل" already
            // works and a search narrows as it is typed instead of only at the end.
            if ([word rangeOfString:query options:NSCaseInsensitiveSearch].location == 0
                || [query rangeOfString:word options:NSCaseInsensitiveSearch].location == 0) {
                inGroup = YES;
                break;
            }
        }

        if (inGroup) [terms addObjectsFromArray:group];
    }

    return terms;
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *query = [searchController.searchBar.text stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceCharacterSet]];

    if (!query.length) {
        self.filteredSections = nil;
        [self.tableView reloadData];
        return;
    }

    if (!self.searchIndex) self.searchIndex = [self flattenSections:self.sections];

    NSArray<NSString *> *terms = [SCISettingsViewController termsForQuery:query];

    NSMutableArray<SCISetting *> *matches = [NSMutableArray array];
    for (SCISetting *row in self.searchIndex) {
        BOOL hit = NO;

        for (NSString *term in terms) {
            if (row.title.length && [row.title rangeOfString:term options:NSCaseInsensitiveSearch].location != NSNotFound) {
                hit = YES;
                break;
            }
            if (row.subtitle.length && [row.subtitle rangeOfString:term options:NSCaseInsensitiveSearch].location != NSNotFound) {
                hit = YES;
                break;
            }
        }

        if (hit) [matches addObject:row];
    }

    self.filteredSections = matches.count ? @[@{@"header": @"", @"rows": matches}] : @[];
    [self.tableView reloadData];
}

// The "hold ☰ to reopen settings" alert that used to fire here is now a row on the
// welcome screen, which is a better place to say it and doesn't ambush the user on
// the way out.

// MARK: - UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SCISetting *row = [self activeSections][indexPath.section][@"rows"][indexPath.row];
    if (!row) return nil;
    
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    UIListContentConfiguration *cellContentConfig = cell.defaultContentConfiguration;
    
    cellContentConfig.text = row.title;
    
    // Subtitle -- from the block when the row has one (a checklist's count), otherwise the string.
    NSString *subtitle = row.subtitleBlock ? row.subtitleBlock() : row.subtitle;
    if (subtitle.length) {
        cellContentConfig.secondaryText = subtitle;
        cellContentConfig.textToSecondaryTextVerticalPadding = 4.5;
    }
    
    // Icon
    if (row.icon != nil) {
        cellContentConfig.image = [row.icon image];
        cellContentConfig.imageProperties.tintColor = row.icon.color;
    }
    
    // Image url
    if (row.imageUrl != nil) {
        [self loadImageFromURL:row.imageUrl atIndexPath:indexPath forTableView:tableView];
        
        cellContentConfig.imageToTextPadding = 14;
    }
    
    switch (row.type) {
        case SCITableCellStatic: {
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            break;
        }
            
        case SCITableCellLink: {
            cellContentConfig.textProperties.color = [UIColor systemBlueColor];
            cellContentConfig.textProperties.font = [UIFont systemFontOfSize:[UIFont preferredFontForTextStyle:UIFontTextStyleBody].pointSize
                                                                      weight:UIFontWeightMedium];
            
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            
            UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"safari"]];
            imageView.tintColor = [UIColor systemGray3Color];
            cell.accessoryView = imageView;
            
            break;
        }
            
        case SCITableCellSwitch: {
            UISwitch *toggle = [UISwitch new];
            toggle.on = [[NSUserDefaults standardUserDefaults] boolForKey:row.defaultsKey];
            toggle.onTintColor = [SCIUtils SCIColor_Primary];
            
            objc_setAssociatedObject(toggle, rowStaticRef, row, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            
            [toggle addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
            
            cell.accessoryView = toggle;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            break;
        }
            
        case SCITableCellStepper: {
            UIStepper *stepper = [UIStepper new];
            stepper.minimumValue = row.min;
            stepper.maximumValue = row.max;
            stepper.stepValue = row.step;
            stepper.value = [[NSUserDefaults standardUserDefaults] doubleForKey:row.defaultsKey];
            
            objc_setAssociatedObject(stepper, rowStaticRef, row, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            
            [stepper addTarget:self
                        action:@selector(stepperChanged:)
              forControlEvents:UIControlEventValueChanged];
            
            // Template subtitle
            if (row.subtitle.length) {
                cellContentConfig.secondaryText = [self formatString:row.subtitle withValue:stepper.value label:row.label singularLabel:row.singularLabel];
            }
            
            cell.accessoryView = stepper;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            break;
        }
            
        case SCITableCellButton: {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            break;
        }
            
        case SCITableCellMenu: {
            UIButton *menuButton = [UIButton buttonWithType:UIButtonTypeSystem];
            [menuButton setTitle:@"•••" forState:UIControlStateNormal];
            menuButton.menu = [row menuForButton:menuButton];
            menuButton.showsMenuAsPrimaryAction = YES;
            menuButton.titleLabel.font = [UIFont systemFontOfSize:[UIFont preferredFontForTextStyle:UIFontTextStyleBody].pointSize
                                                           weight:UIFontWeightMedium];
            
            UIButtonConfiguration *config = menuButton.configuration ?: [UIButtonConfiguration plainButtonConfiguration];
            menuButton.configuration.contentInsets = NSDirectionalEdgeInsetsMake(8, 8, 8, 8);
            menuButton.configuration = config;

            [menuButton sizeToFit];
            
            cell.accessoryView = menuButton;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            break;
        }
            
        case SCITableCellNavigation: {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            break;
        }
    }
    
    cell.contentConfiguration = cellContentConfig;

    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[self activeSections][section][@"rows"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [self activeSections][section][@"header"];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return [self activeSections][section][@"footer"];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self activeSections].count;
}

// MARK: - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    SCISetting *row = [self activeSections][indexPath.section][@"rows"][indexPath.row];
    if (!row) return;

    // Navigating away from a search result: dismiss the search so the pushed page
    // and the back stack behave normally.
    if (row.type == SCITableCellNavigation && self.searchController.isActive) {
        self.searchController.active = NO;
    }

    if (row.type == SCITableCellLink) {
        [[UIApplication sharedApplication] openURL:row.url options:@{} completionHandler:nil];
    }
    else if (row.type == SCITableCellButton) {
        if (row.action != nil) {
            row.action();
        }
    }
    else if (row.type == SCITableCellNavigation) {
        if (row.navSections.count > 0) {
            UIViewController *vc = [[SCISettingsViewController alloc] initWithTitle:row.title sections:row.navSections reduceMargin:NO];
            vc.title = row.title;
            [self.navigationController pushViewController:vc animated:YES];
        }
        else if (row.navViewController) {
            [self.navigationController pushViewController:row.navViewController animated:YES];
        }
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

// MARK: - Actions

- (void)switchChanged:(UISwitch *)sender {
    SCISetting *row = objc_getAssociatedObject(sender, rowStaticRef);
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:row.defaultsKey];
    
    SCILogV(@"Switch changed: %@", sender.isOn ? @"ON" : @"OFF");
    
    if (row.requiresRestart) {
        [SCIUtils showRestartConfirmation];
    }
}

- (void)stepperChanged:(UIStepper *)sender {
    SCISetting *row = objc_getAssociatedObject(sender, rowStaticRef);
    [[NSUserDefaults standardUserDefaults] setDouble:sender.value forKey:row.defaultsKey];
    
    SCILogV(@"Stepper changed: %f", sender.value);
    
    [self reloadCellForView:sender];
}

- (void)menuChanged:(UICommand *)command {
    NSDictionary *properties = command.propertyList;
    
    [[NSUserDefaults standardUserDefaults] setValue:properties[@"value"] forKey:properties[@"defaultsKey"]];
    
    SCILogV(@"Menu changed: %@", command.propertyList[@"value"]);
    
    [self reloadCellForView:command.sender animated:YES];
    
    if (properties[@"requiresRestart"]) {
        [SCIUtils showRestartConfirmation];
    }
}

// MARK: - Helper

- (NSString *)formatString:(NSString *)template withValue:(double)value label:(NSString *)label singularLabel:(NSString *)singularLabel {
    // Singular or plural labels
    NSString *applicableLabel = fabs(value - 1.0) < 0.00001 ? singularLabel : label;
    
    // Force value to 0 to prevent it being -0
    if (fabs(value) < 0.00001) {
        value = 0.0;
    }

    // Get correct decimal value based on step value
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    formatter.minimumFractionDigits = 0;
    formatter.maximumFractionDigits = [SCIUtils decimalPlacesInDouble:value];

    NSString *stringValue = [formatter stringFromNumber:@(value)];

    return [NSString stringWithFormat:template, stringValue, applicableLabel];
}

- (void)reloadCellForView:(UIView *)view animated:(BOOL)animated {
    UITableViewCell *cell = (UITableViewCell *)view.superview;
    while (cell && ![cell isKindOfClass:[UITableViewCell class]]) {
        cell = (UITableViewCell *)cell.superview;
    }
    if (!cell) return;

    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    if (!indexPath) return;
    
    [self.tableView reloadRowsAtIndexPaths:@[indexPath]
                          withRowAnimation:animated ? UITableViewRowAnimationAutomatic : UITableViewRowAnimationNone];
}
- (void)reloadCellForView:(UIView *)view {
    [self reloadCellForView:view animated:NO];
}

- (void)loadImageFromURL:(NSURL *)url atIndexPath:(NSIndexPath *)indexPath forTableView:(UITableView *)tableView
{
    if (!url) return;

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url
                                                             completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
    {
        if (!data || error) return;

        UIImage *image = [UIImage imageWithData:data];
        if (!image) return;

        dispatch_async(dispatch_get_main_queue(), ^{
            UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
            if (!cell) return;

            UIListContentConfiguration *config = (UIListContentConfiguration *)cell.contentConfiguration;
            config.image = image;
            config.imageProperties.maximumSize = CGSizeMake(45, 45);
            cell.contentConfiguration = config;
        });
    }];

    [task resume];
}

@end
