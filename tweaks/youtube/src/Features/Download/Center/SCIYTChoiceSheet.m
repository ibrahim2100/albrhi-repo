#import "SCIYTChoiceSheet.h"
#import "../../../Tweak.h"
#import "../../../SCILog.h"
#import "../../../Localization/SCILocalize.h"
#import "../../../Prefs.h"
#import <Photos/Photos.h>

/// YouTube's red, which is also this tweak's accent everywhere else.

///
/// What the picker is showing, which is deliberately *not* SCIYTJobKind.
///
/// The obvious move was a third kind beside Video and Audio. It is the wrong one: that enum
/// is read by the library, the queue, the list and the player, and every one of them tests
/// it as a two-way question -- `kind == Audio ? … : …` appears throughout. A third value
/// makes each of those silently answer "video" for a thumbnail, in four files that never
/// mentioned thumbnails and would not fail to compile.
///
/// So a thumbnail is not a kind of download at all here. Video and sound produce a job that
/// the queue works through; a thumbnail is one image fetched and handed to Photos on the
/// spot, and the sheet closes. Nothing downstream learns a new case.
///
typedef NS_ENUM(NSInteger, SCISheetSection) {
    SCISheetSectionVideo = 0,
    SCISheetSectionAudio,
    SCISheetSectionThumbnail,
    SCISheetSectionWatch
};

// MARK: - A list of tracks to tick

/// Languages of the sound, or captions: a searchable list, because a video can offer sixty-five of
/// them and a sheet is the wrong place to scroll through that. Ticks are kept in a set the sheet owns,
/// so closing this screen loses nothing and the sheet's summary line is always read from the truth.
@interface SCIYTTrackPicker : UITableViewController <UISearchResultsUpdating>
@property (nonatomic, copy) NSArray<NSDictionary *> *items;
@property (nonatomic, copy) NSArray<NSDictionary *> *shown;
@property (nonatomic, strong) NSMutableSet<NSString *> *ticked;
@property (nonatomic) BOOL multiple;
@property (nonatomic, copy) NSString *footer;
@property (nonatomic, copy) void (^changed)(void);
@end

@implementation SCIYTTrackPicker
- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.rowHeight = 52;
    self.shown = self.items;

    if (self.items.count > 8) {
        UISearchController *search = [[UISearchController alloc] initWithSearchResultsController:nil];
        search.searchResultsUpdater = self;
        search.obscuresBackgroundDuringPresentation = NO;
        search.searchBar.placeholder = SCILocalized(@"dl_search");
        self.navigationItem.searchController = search;
        self.navigationItem.hidesSearchBarWhenScrolling = NO;
        self.definesPresentationContext = YES;
    }
}

- (void)updateSearchResultsForSearchController:(UISearchController *)search {
    NSString *query = [search.searchBar.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    if (!query.length) { self.shown = self.items; }
    else {
        NSPredicate *match = [NSPredicate predicateWithBlock:^BOOL(NSDictionary *item, id _) {
            return [item[@"name"] rangeOfString:query options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location != NSNotFound
                || [item[@"lang"] rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound;
        }];
        self.shown = [self.items filteredArrayUsingPredicate:match];
    }
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)section { return (NSInteger)self.shown.count; }
- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)section { return self.footer; }

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    NSDictionary *item = self.shown[(NSUInteger)path.row];
    cell.textLabel.text = item[@"name"];
    cell.detailTextLabel.text = item[@"detail"];
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    BOOL on = [self.ticked containsObject:item[@"id"]];
    cell.accessoryType = on ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    cell.tintColor = SCIAccent();
    cell.accessibilityTraits |= on ? UIAccessibilityTraitSelected : 0;
    return cell;
}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)path {
    NSString *identifier = self.shown[(NSUInteger)path.row][@"id"];
    if (self.multiple) {
        if ([self.ticked containsObject:identifier]) [self.ticked removeObject:identifier]; else [self.ticked addObject:identifier];
    } else {
        [self.ticked removeAllObjects]; [self.ticked addObject:identifier];
    }
    [t reloadData];
    if (self.changed) self.changed();
    if (!self.multiple) [self.navigationController popViewControllerAnimated:YES];
}
@end

@interface SCIYTChoiceSheet () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) NSArray<SCIHLSVariant *> *variants;
/// The video choices as the sections they are drawn in -- see -buildGroups.
@property (nonatomic, copy) NSArray<NSDictionary *> *groups;
@property (nonatomic, copy) NSString *videoTitle;
@property (nonatomic, copy) NSString *videoID;
@property (nonatomic, copy) void (^chosen)(SCIHLSVariant *, SCIYTJobKind);
@property (nonatomic, copy) void (^watch)(SCIHLSVariant *);
/// The section each segment stands for, in the order the segments are drawn. The thumbnail and
/// watch segments exist only when there is something to build them from, so a segment's index
/// is not its section -- and treating it as one is how the third segment becomes the wrong one.
@property (nonatomic, copy) NSArray<NSNumber *> *segmentSections;
@property (nonatomic) SCIYTJobKind kind;
@property (nonatomic) SCISheetSection section;
@property (nonatomic) BOOL savingThumbnail;
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) UISegmentedControl *picker;

/// What is ticked. Nothing starts until the Download button, so there is room to choose first.
@property (nonatomic, strong) SCIHLSVariant *selected;
@property (nonatomic, strong) NSMutableSet<NSString *> *extraSound;
@property (nonatomic, strong) NSMutableSet<NSString *> *captionIDs;
@property (nonatomic, strong) NSMutableSet<NSString *> *soundOnlyLanguage;
@property (nonatomic, strong) UIView *bar;
@property (nonatomic, strong) UIButton *action;
@end

@implementation SCIYTChoiceSheet

+ (void)presentFrom:(UIViewController *)presenter
           variants:(NSArray<SCIHLSVariant *> *)variants
              title:(NSString *)title
            videoID:(NSString *)videoID
             chosen:(void (^)(SCIHLSVariant *, SCIYTJobKind))chosen {
    [self presentFrom:presenter variants:variants title:title videoID:videoID chosen:chosen watch:nil];
}

+ (void)presentFrom:(UIViewController *)presenter
           variants:(NSArray<SCIHLSVariant *> *)variants
              title:(NSString *)title
            videoID:(NSString *)videoID
             chosen:(void (^)(SCIHLSVariant *, SCIYTJobKind))chosen
              watch:(void (^)(SCIHLSVariant *))watch {

    if (!presenter || !variants.count) return;

    SCIYTChoiceSheet *sheet = [[SCIYTChoiceSheet alloc] init];
    sheet.variants = variants;
    sheet.videoTitle = title;
    sheet.videoID = videoID;
    sheet.chosen = chosen;
    sheet.watch = watch;
    sheet.kind = SCIYTJobKindVideo;
    sheet.section = SCISheetSectionVideo;
    [sheet buildGroups];
    sheet.extraSound = [NSMutableSet set];
    sheet.captionIDs = [NSMutableSet set];
    sheet.soundOnlyLanguage = [NSMutableSet set];
    // The best ordinary quality: what most people mean by "just download it".
    sheet.selected = [sheet.groups.lastObject[@"variants"] firstObject] ?: variants.firstObject;

    UINavigationController *host = [[UINavigationController alloc] initWithRootViewController:sheet];

    // A sheet rather than a full screen: the video stays visible behind it, which is the
    // whole point of not blocking the app any more.
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *presentation = host.sheetPresentationController;
        presentation.detents = @[[UISheetPresentationControllerDetent mediumDetent],
                                 [UISheetPresentationControllerDetent largeDetent]];
        presentation.prefersGrabberVisible = YES;

        // Open tall when there is a lot to choose from. At the medium detent a list of eight
        // qualities plus a header showed three rows and left the rest to be discovered by
        // scrolling -- which read as the 1440p and 4K rows being missing.
        BOOL hasChoices = variants.firstObject.directAudioTracks.count || variants.firstObject.directCaptionTracks.count;
        if (variants.count > 4 || hasChoices) {
            presentation.selectedDetentIdentifier = UISheetPresentationControllerDetentIdentifierLarge;
        }
        presentation.preferredCornerRadius = 22;
    }

    [presenter presentViewController:host animated:YES completion:nil];
}

/// Splits the choices into what is drawn as separate sections.
///
/// 1440p and 4K come from YouTube only as AV1, which behaves differently from everything else on
/// the list -- it needs a capable player, or a conversion that takes minutes. Mixed into one list
/// with the same kind of row they read as ordinary qualities, and the sentence explaining the
/// difference had to be squeezed into a row's detail label, where it crushed the title. Their own
/// section gives them a heading and room for that sentence, and puts them first: the tallest
/// is where somebody who turned them on looks.
- (void)buildGroups {
    NSMutableArray<SCIHLSVariant *> *high = [NSMutableArray array];
    NSMutableArray<SCIHLSVariant *> *standard = [NSMutableArray array];
    for (SCIHLSVariant *variant in self.variants) {
        [([variant.codecs.lowercaseString containsString:@"av01"] ? high : standard) addObject:variant];
    }

    NSMutableArray<NSDictionary *> *groups = [NSMutableArray array];
    if (high.count) {
        [groups addObject:@{
            @"title": SCILocalized(@"dl_hires_header"),
            @"footer": SCILocalized(SCIPrefEnabled(SCIPrefConvertAV1) ? @"dl_av1_convert_hint" : @"dl_av1_hint"),
            @"variants": high,
        }];
    }
    if (standard.count) {
        [groups addObject:@{ @"title": SCILocalized(@"dl_quality_header"), @"variants": standard }];
    }
    self.groups = groups;
}

- (SCIHLSVariant *)variantAtIndexPath:(NSIndexPath *)indexPath {
    // Watch lists the ordinary qualities only -- one section, the last group -- so its section
    // index is not the groups' index.
    NSDictionary *group = (self.section == SCISheetSectionWatch) ? self.groups.lastObject
                                                                 : self.groups[(NSUInteger)indexPath.section];
    NSArray *variants = group[@"variants"];
    return variants[(NSUInteger)indexPath.row];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = SCILocalized(@"dl_choose_title");
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                       target:self
                                                       action:@selector(dismissSheet)];

    // Sound or pictures. A segmented control rather than two drawn cards: it is the
    // control iOS already uses for exactly this question, it is legible in both themes
    // without a line of styling, and it cannot lay itself out wrongly.
    // The third segment only exists when there is a video id to build a thumbnail URL
    // from. Offering it without one would be a row that can only ever fail, which is worse
    // than not offering it: a control that is present and dead reads as a broken tweak.
    NSMutableArray<NSString *> *sections = [@[
        SCILocalized(@"dl_kind_video"),
        SCILocalized(@"dl_kind_audio")
    ] mutableCopy];
    NSMutableArray<NSNumber *> *kinds = [@[@(SCISheetSectionVideo), @(SCISheetSectionAudio)] mutableCopy];

    if (self.videoID.length) {
        [sections addObject:SCILocalized(@"dl_kind_thumb")];
        [kinds addObject:@(SCISheetSectionThumbnail)];
    }

    // Watching needs a standard (non-AV1) quality to fetch and somebody to hand it to.
    SCIHLSVariant *ordinary = [self.groups.lastObject[@"variants"] firstObject];
    if (self.watch && ordinary && ![ordinary.codecs.lowercaseString containsString:@"av01"]) {
        [sections addObject:SCILocalized(@"watch_tab")];
        [kinds addObject:@(SCISheetSectionWatch)];
    }
    self.segmentSections = kinds;

    self.picker = [[UISegmentedControl alloc] initWithItems:sections];
    self.picker.selectedSegmentIndex = 0;
    self.picker.selectedSegmentTintColor = SCIAccent();
    [self.picker setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]}
                               forState:UIControlStateSelected];
    [self.picker addTarget:self action:@selector(kindChanged)
          forControlEvents:UIControlEventValueChanged];

    self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.table];

    [NSLayoutConstraint activateConstraints:@[
        [self.table.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.table.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.table.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];

    [self buildBar];
    [self buildHeader];
    [self refreshAction];
}

/// The Download button, pinned under the list on a material so rows scroll beneath it. One
/// control, one place: the choices above only ever change what it will do.
- (void)buildBar {
    self.bar = [[UIView alloc] init];
    self.bar.translatesAutoresizingMaskIntoConstraints = NO;
    self.bar.backgroundColor = [UIColor systemBackgroundColor];
    [self.view addSubview:self.bar];

    UIView *line = [[UIView alloc] init];
    line.backgroundColor = [UIColor separatorColor];
    line.translatesAutoresizingMaskIntoConstraints = NO;
    [self.bar addSubview:line];

    self.action = [UIButton buttonWithType:UIButtonTypeSystem];
    self.action.translatesAutoresizingMaskIntoConstraints = NO;
    self.action.backgroundColor = SCIAccent();
    self.action.tintColor = [UIColor whiteColor];
    self.action.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    [self.action setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.action.layer.cornerRadius = 14;
    self.action.layer.cornerCurve = kCACornerCurveContinuous;
    [self.action addTarget:self action:@selector(startDownload) forControlEvents:UIControlEventTouchUpInside];
    [self.bar addSubview:self.action];

    [NSLayoutConstraint activateConstraints:@[
        [self.bar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.bar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.bar.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.table.bottomAnchor constraintEqualToAnchor:self.bar.topAnchor],

        [line.topAnchor constraintEqualToAnchor:self.bar.topAnchor],
        [line.leadingAnchor constraintEqualToAnchor:self.bar.leadingAnchor],
        [line.trailingAnchor constraintEqualToAnchor:self.bar.trailingAnchor],
        [line.heightAnchor constraintEqualToConstant:1 / UIScreen.mainScreen.scale],

        [self.action.topAnchor constraintEqualToAnchor:self.bar.topAnchor constant:12],
        [self.action.leadingAnchor constraintEqualToAnchor:self.bar.leadingAnchor constant:20],
        [self.action.trailingAnchor constraintEqualToAnchor:self.bar.trailingAnchor constant:-20],
        [self.action.heightAnchor constraintEqualToConstant:50],
        [self.action.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-8],
    ]];
}

// MARK: - What is ticked

- (NSArray<NSDictionary *> *)soundTracks { return self.variants.firstObject.directAudioTracks ?: @[]; }
- (NSArray<NSDictionary *> *)captionTracks { return self.variants.firstObject.directCaptionTracks ?: @[]; }

- (NSDictionary *)originalSound {
    for (NSDictionary *t in [self soundTracks]) if ([t[@"default"] boolValue]) return t;
    return [self soundTracks].firstObject;
}

- (NSArray<NSDictionary *> *)tickedExtraSound {
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *t in [self soundTracks]) {
        if (![t[@"default"] boolValue] && [self.extraSound containsObject:t[@"id"]]) [out addObject:t];
    }
    return out;
}

- (NSArray<NSDictionary *> *)tickedCaptions {
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *t in [self captionTracks]) if ([self.captionIDs containsObject:t[@"id"]]) [out addObject:t];
    return out;
}

/// What the Download button will fetch, in bytes, when the direct route knows (zero otherwise).
- (long long)plannedBytes {
    SCIHLSVariant *v = self.selected;
    if (self.section == SCISheetSectionAudio) {
        NSString *chosen = self.soundOnlyLanguage.anyObject;
        for (NSDictionary *t in [self soundTracks]) if ([t[@"id"] isEqualToString:chosen]) return [t[@"bytes"] longLongValue];
        return v.directAudioBytes;
    }
    long long total = v.directVideoBytes + v.directAudioBytes;
    for (NSDictionary *t in [self tickedExtraSound]) total += [t[@"bytes"] longLongValue];
    return total;
}

- (void)refreshAction {
    BOOL showing = (self.section == SCISheetSectionVideo || self.section == SCISheetSectionAudio);
    self.bar.hidden = !showing;
    if (!showing) return;

    long long bytes = [self plannedBytes];
    NSString *title = SCILocalized(@"dl_action_download");
    if (bytes > 0) {
        title = [NSString stringWithFormat:SCILocalized(@"dl_action_download_size"),
                 [NSByteCountFormatter stringFromByteCount:bytes countStyle:NSByteCountFormatterCountStyleFile]];
    }
    [self.action setTitle:title forState:UIControlStateNormal];
    self.action.accessibilityLabel = title;
}

- (void)startDownload {
    SCIHLSVariant *variant = (self.section == SCISheetSectionAudio)
        ? ([self.groups.lastObject[@"variants"] firstObject] ?: self.variants.firstObject)
        : self.selected;
    if (!variant) return;

    if (self.section == SCISheetSectionAudio) {
        // Sound only: the language chosen replaces the original as the one fetched. No extras.
        NSString *chosen = self.soundOnlyLanguage.anyObject;
        for (NSDictionary *t in [self soundTracks]) {
            if ([t[@"id"] isEqualToString:chosen] && ![t[@"default"] boolValue]) {
                variant.directAudioURL = t[@"url"];
                variant.directAudioBytes = [t[@"bytes"] longLongValue];
            }
        }
        variant.chosenExtraAudios = @[];
        variant.chosenCaptions = @[];
    } else {
        variant.chosenExtraAudios = [self tickedExtraSound];
        variant.chosenCaptions = [self tickedCaptions];
    }

    void (^chosen)(SCIHLSVariant *, SCIYTJobKind) = self.chosen;
    SCIYTJobKind kind = self.kind;
    [self dismissViewControllerAnimated:YES completion:^{ if (chosen) chosen(variant, kind); }];
}

- (NSString *)soundSummary {
    NSUInteger n = [self tickedExtraSound].count;
    return n ? [NSString stringWithFormat:@"%@ + %lu", SCILocalized(@"dl_original"), (unsigned long)n] : SCILocalized(@"dl_original");
}

- (NSString *)captionSummary {
    NSArray *ticked = [self tickedCaptions];
    if (!ticked.count) return SCILocalized(@"dl_none");
    NSString *first = ticked[0][@"name"];
    return ticked.count == 1 ? first : [NSString stringWithFormat:@"%@ +%lu", first, (unsigned long)(ticked.count - 1)];
}

- (void)pushPickerFor:(NSArray<NSDictionary *> *)items title:(NSString *)title ticked:(NSMutableSet<NSString *> *)ticked
             multiple:(BOOL)multiple footer:(NSString *)footer {
    SCIYTTrackPicker *picker = [[SCIYTTrackPicker alloc] initWithStyle:UITableViewStyleInsetGrouped];
    picker.title = title;
    picker.items = items;
    picker.ticked = ticked;
    picker.multiple = multiple;
    picker.footer = footer;
    __weak __typeof(self) weakSelf = self;
    picker.changed = ^{ [weakSelf.table reloadData]; [weakSelf refreshAction]; };
    [self.navigationController pushViewController:picker animated:YES];
}

/// The kind picker and the video's name, above the list.
///
/// Measured once and set as the table's header rather than pinned above it: a header
/// sized by systemLayoutSizeFittingSize has no relationship to anything outside the
/// table, so there is no constraint that can be unsatisfiable.
- (void)buildHeader {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12;
    stack.layoutMarginsRelativeArrangement = YES;
    stack.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(16, 20, 8, 20);

    if (self.videoTitle.length) {
        UILabel *name = [[UILabel alloc] init];
        name.text = self.videoTitle;
        name.numberOfLines = 2;
        name.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        name.textColor = [UIColor labelColor];
        [stack addArrangedSubview:name];
    }

    [stack addArrangedSubview:self.picker];

    stack.frame = CGRectMake(0, 0, self.view.bounds.size.width,
        [stack systemLayoutSizeFittingSize:CGSizeMake(self.view.bounds.size.width, 0)
            withHorizontalFittingPriority:UILayoutPriorityRequired
                  verticalFittingPriority:UILayoutPriorityFittingSizeLevel].height);

    self.table.tableHeaderView = stack;
}

- (void)kindChanged {
    NSInteger index = self.picker.selectedSegmentIndex;
    self.section = (index >= 0 && (NSUInteger)index < self.segmentSections.count)
        ? (SCISheetSection)self.segmentSections[(NSUInteger)index].integerValue
        : SCISheetSectionVideo;

    // kind still answers the two-way question the callback is typed on. A thumbnail never
    // reaches that callback at all, so it leaves kind alone rather than inventing a value
    // for it.
    if (self.section == SCISheetSectionAudio) self.kind = SCIYTJobKindAudio;
    else if (self.section == SCISheetSectionVideo) self.kind = SCIYTJobKindVideo;

    [self.table reloadData];
    [self refreshAction];
}

- (void)dismissSheet {
    [self dismissViewControllerAnimated:YES completion:nil];
}

// MARK: - The list

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Video: the quality groups, then one section of choices (languages, captions) when there are any.
    // (Watch is a single section: the ordinary qualities.)
    if (self.section == SCISheetSectionVideo) return (NSInteger)self.groups.count + ([self extrasRowCount] ? 1 : 0);
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Sound has no sizes to choose between: there is one soundtrack, and offering seven
    // identical rows of it would be a menu pretending to be a decision. A thumbnail has
    // one picture, for the same reason.
    if (self.section == SCISheetSectionWatch) return (NSInteger)[self.groups.lastObject[@"variants"] count];
    if (self.section == SCISheetSectionAudio) return 1 + ([self soundTracks].count ? 1 : 0);
    if (self.section != SCISheetSectionVideo) return 1;
    if ((NSUInteger)section >= self.groups.count) return [self extrasRowCount];
    return (NSInteger)[self.groups[(NSUInteger)section][@"variants"] count];
}

/// Rows in the choices section of the video tab: languages of the sound, and captions.
- (NSInteger)extrasRowCount {
    return ([self soundTracks].count ? 1 : 0) + ([self captionTracks].count ? 1 : 0);
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (self.section == SCISheetSectionVideo && (NSUInteger)section >= self.groups.count) return SCILocalized(@"dl_also_save");
    switch (self.section) {
        case SCISheetSectionAudio:     return SCILocalized(@"dl_sound_header");
        case SCISheetSectionThumbnail: return SCILocalized(@"dl_thumb_header");
        case SCISheetSectionWatch:     return SCILocalized(@"watch_header");
        case SCISheetSectionVideo:     break;
    }
    return self.groups[(NSUInteger)section][@"title"];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (self.section == SCISheetSectionWatch) return SCILocalized(@"watch_footer");
    if (self.section == SCISheetSectionVideo && (NSUInteger)section >= self.groups.count) return SCILocalized(@"dl_tracks_footer");
    return self.section == SCISheetSectionVideo ? self.groups[(NSUInteger)section][@"footer"] : nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                   reuseIdentifier:nil];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    if (self.section == SCISheetSectionThumbnail) {
        cell.textLabel.text = SCILocalized(@"dl_thumb_save");
        cell.detailTextLabel.text = SCILocalized(@"dl_thumb_where");
        cell.imageView.image = [UIImage systemImageNamed:@"photo"];
        cell.imageView.tintColor = SCIAccent();

        // Spinning while it fetches, and unselectable meanwhile. A second tap would start a
        // second fetch and hand Photos the same picture twice.
        if (self.savingThumbnail) {
            UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
                initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
            [spinner startAnimating];
            cell.accessoryView = spinner;
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
        return cell;
    }

    if (self.section == SCISheetSectionAudio) {
        if (indexPath.row == 0) {
            cell.textLabel.text = SCILocalized(@"dl_sound_only");
            cell.detailTextLabel.text = SCILocalized(@"dl_sound_small");
            cell.imageView.image = [UIImage systemImageNamed:@"music.note"];
            cell.imageView.tintColor = SCIAccent();
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else {
            NSString *chosen = self.soundOnlyLanguage.anyObject;
            NSDictionary *track = nil;
            for (NSDictionary *t in [self soundTracks]) if ([t[@"id"] isEqualToString:chosen]) track = t;
            cell.textLabel.text = SCILocalized(@"dl_language");
            cell.detailTextLabel.text = track[@"name"] ?: SCILocalized(@"dl_original");
            cell.imageView.image = [UIImage systemImageNamed:@"globe"];
            cell.imageView.tintColor = SCIAccent();
        }
        return cell;
    }

    if (self.section == SCISheetSectionVideo && (NSUInteger)indexPath.section >= self.groups.count) {
        BOOL soundRow = ([self soundTracks].count && indexPath.row == 0);
        cell.textLabel.text = SCILocalized(soundRow ? @"dl_audio_languages" : @"dl_captions");
        cell.detailTextLabel.text = soundRow ? [self soundSummary] : [self captionSummary];
        cell.imageView.image = [UIImage systemImageNamed:(soundRow ? @"waveform" : @"captions.bubble")];
        cell.imageView.tintColor = SCIAccent();
        return cell;
    }

    SCIHLSVariant *variant = [self variantAtIndexPath:indexPath];
    cell.textLabel.text = [variant label];
    cell.imageView.image = [UIImage systemImageNamed:(self.section == SCISheetSectionWatch ? @"play.rectangle.fill" : @"film")];
    cell.imageView.tintColor = SCIAccent();

    // A quality is chosen, not started: the tick says which one the button below will fetch.
    if (self.section == SCISheetSectionVideo) {
        BOOL on = (variant == self.selected);
        cell.accessoryType = on ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        cell.tintColor = SCIAccent();
        if (on) cell.accessibilityTraits |= UIAccessibilityTraitSelected;
    }

    // How big it will be: exact when the direct route knows the byte counts YouTube declared,
    // and otherwise roughly, from the bitrate a playlist states. "About 190 MB" is the
    // difference between choosing 1080p deliberately and choosing it by accident on a phone plan.
    // (A converted 4K ends up larger than the AV1 it came from; the figure is the download.)
    long long bytes = variant.directVideoBytes + variant.directAudioBytes;
    if (bytes > 0) {
        cell.detailTextLabel.text = [NSByteCountFormatter stringFromByteCount:bytes
                                                                    countStyle:NSByteCountFormatterCountStyleFile];
    } else if (variant.bandwidth > 0) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f Mbps", variant.bandwidth / 1000000.0];
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (self.section == SCISheetSectionThumbnail) {
        [self saveThumbnail];
        return;
    }

    if (self.section == SCISheetSectionWatch) {
        SCIHLSVariant *picked = [self variantAtIndexPath:indexPath];
        void (^watch)(SCIHLSVariant *) = self.watch;
        [self dismissViewControllerAnimated:YES completion:^{
            if (watch) watch(picked);
        }];
        return;
    }

    if (self.section == SCISheetSectionAudio) {
        if (indexPath.row == 1) {
            // One language for the sound-only file, the original unless another is picked.
            if (!self.soundOnlyLanguage.count && [self originalSound]) [self.soundOnlyLanguage addObject:[self originalSound][@"id"]];
            NSMutableArray *items = [NSMutableArray array];
            for (NSDictionary *t in [self soundTracks]) {
                [items addObject:@{@"id": t[@"id"], @"lang": t[@"lang"], @"name": t[@"name"],
                    @"detail": [NSByteCountFormatter stringFromByteCount:[t[@"bytes"] longLongValue] countStyle:NSByteCountFormatterCountStyleFile]}];
            }
            [self pushPickerFor:items title:SCILocalized(@"dl_language") ticked:self.soundOnlyLanguage multiple:NO footer:nil];
        }
        return;
    }

    // The choices section: languages of the sound and captions, each in its own list.
    if ((NSUInteger)indexPath.section >= self.groups.count) {
        BOOL soundRow = ([self soundTracks].count && indexPath.row == 0);
        NSMutableArray *items = [NSMutableArray array];
        if (soundRow) {
            NSDictionary *original = [self originalSound];
            for (NSDictionary *t in [self soundTracks]) {
                if ([t isEqual:original]) continue;   // always kept, so not a choice
                [items addObject:@{@"id": t[@"id"], @"lang": t[@"lang"], @"name": t[@"name"],
                    @"detail": [NSByteCountFormatter stringFromByteCount:[t[@"bytes"] longLongValue] countStyle:NSByteCountFormatterCountStyleFile]}];
            }
            [self pushPickerFor:items title:SCILocalized(@"dl_audio_languages") ticked:self.extraSound multiple:YES
                         footer:[NSString stringWithFormat:SCILocalized(@"dl_original_kept"), original[@"name"] ?: @""]];
        } else {
            for (NSDictionary *t in [self captionTracks]) {
                [items addObject:@{@"id": t[@"id"], @"lang": t[@"lang"], @"name": t[@"name"],
                    @"detail": [t[@"auto"] boolValue] ? SCILocalized(@"dl_auto_generated") : @""}];
            }
            [self pushPickerFor:items title:SCILocalized(@"dl_captions") ticked:self.captionIDs multiple:YES footer:nil];
        }
        return;
    }

    // A quality row selects; the button starts.
    self.selected = [self variantAtIndexPath:indexPath];
    [tableView reloadData];
    [self refreshAction];
}

// MARK: - The thumbnail

/// Fetches the video's cover and hands it to Photos.
///
/// Off the main thread, because +dataWithContentsOfURL: blocks until the picture arrives and
/// doing that on the main thread freezes the sheet mid-tap. The two sizes are tried in the
/// same order and for the same reason the cover cache does (see Center/thumbnails): not
/// maximum-resolution still, and YouTube answers a missing one with a small grey placeholder
/// rather than a 404 -- so the width is the test, not the status code.
- (void)saveThumbnail {
    if (self.savingThumbnail || !self.videoID.length) return;

    self.savingThumbnail = YES;
    [self.table reloadData];

    NSString *videoID = self.videoID;
    __weak __typeof(self) weakSelf = self;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        UIImage *cover = nil;

        for (NSString *name in @[@"maxresdefault", @"hqdefault"]) {
            NSString *text = [NSString stringWithFormat:@"https://i.ytimg.com/vi/%@/%@.jpg",
                              videoID, name];
            NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:text]];
            UIImage *image = data.length ? [UIImage imageWithData:data] : nil;

            if (image.size.width >= 200) { cover = image; break; }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (!cover) { [weakSelf finishedThumbnail:NO message:SCILocalized(@"dl_thumb_failed")]; return; }
            [weakSelf handToPhotos:cover];
        });
    });
}

/// The same permission dance the saved-video export already does, and for the same reason
/// it documents in the library: asking a host whose Info.plist carries no usage description
/// does not fail, it ends the process.
- (void)handToPhotos:(UIImage *)cover {
    NSBundle *host = [NSBundle mainBundle];
    if (![host objectForInfoDictionaryKey:@"NSPhotoLibraryAddUsageDescription"] &&
        ![host objectForInfoDictionaryKey:@"NSPhotoLibraryUsageDescription"]) {
        [self finishedThumbnail:NO message:SCILocalized(@"dl_no_photos_access")];
        return;
    }

    __weak __typeof(self) weakSelf = self;

    [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly
                                               handler:^(PHAuthorizationStatus status) {
        if (status != PHAuthorizationStatusAuthorized && status != PHAuthorizationStatusLimited) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf finishedThumbnail:NO message:SCILocalized(@"dl_no_permission")];
            });
            return;
        }

        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetChangeRequest creationRequestForAssetFromImage:cover];
        } completionHandler:^(BOOL success, NSError *error) {
            // Photos answers on its own queue and everything below touches the view.
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!success) SCILogV(@"thumbnail: %@", error.localizedDescription);
                [weakSelf finishedThumbnail:success
                                    message:success ? SCILocalized(@"dl_thumb_saved")
                                                    : SCILocalized(@"dl_thumb_failed")];
            });
        }];
    }];
}

/// Says what happened, and closes only when it worked.
///
/// A failure leaves the sheet open on purpose: dismissing on the way out of an error means
/// the message and the screen it explains disappear together, and the user is returned to a
/// video with no idea whether anything was saved.
- (void)finishedThumbnail:(BOOL)saved message:(NSString *)message {
    self.savingThumbnail = NO;
    [self.table reloadData];

    UIAlertController *note =
        [UIAlertController alertControllerWithTitle:nil
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];

    __weak __typeof(self) weakSelf = self;
    [note addAction:[UIAlertAction actionWithTitle:SCILocalized(@"ok")
                                             style:UIAlertActionStyleDefault
                                           handler:^(__unused UIAlertAction *action) {
        if (saved) [weakSelf dismissViewControllerAnimated:YES completion:nil];
    }]];

    [self presentViewController:note animated:YES completion:nil];
}

@end
