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
    SCISheetSectionThumbnail
};

@interface SCIYTChoiceSheet () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) NSArray<SCIHLSVariant *> *variants;
/// The video choices as the sections they are drawn in -- see -buildGroups.
@property (nonatomic, copy) NSArray<NSDictionary *> *groups;
@property (nonatomic, copy) NSString *videoTitle;
@property (nonatomic, copy) NSString *videoID;
@property (nonatomic, copy) void (^chosen)(SCIHLSVariant *, SCIYTJobKind);
@property (nonatomic) SCIYTJobKind kind;
@property (nonatomic) SCISheetSection section;
@property (nonatomic) BOOL savingThumbnail;
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) UISegmentedControl *picker;
@end

@implementation SCIYTChoiceSheet

+ (void)presentFrom:(UIViewController *)presenter
           variants:(NSArray<SCIHLSVariant *> *)variants
              title:(NSString *)title
            videoID:(NSString *)videoID
             chosen:(void (^)(SCIHLSVariant *, SCIYTJobKind))chosen {

    if (!presenter || !variants.count) return;

    SCIYTChoiceSheet *sheet = [[SCIYTChoiceSheet alloc] init];
    sheet.variants = variants;
    sheet.videoTitle = title;
    sheet.videoID = videoID;
    sheet.chosen = chosen;
    sheet.kind = SCIYTJobKindVideo;
    sheet.section = SCISheetSectionVideo;
    [sheet buildGroups];

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
        if (variants.count > 4) {
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
    NSArray *variants = self.groups[(NSUInteger)indexPath.section][@"variants"];
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

    if (self.videoID.length) [sections addObject:SCILocalized(@"dl_kind_thumb")];

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
        [self.table.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    [self buildHeader];
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
    self.section = (SCISheetSection)self.picker.selectedSegmentIndex;

    // kind still answers the two-way question the callback is typed on. A thumbnail never
    // reaches that callback at all, so it leaves kind alone rather than inventing a value
    // for it.
    if (self.section == SCISheetSectionAudio) self.kind = SCIYTJobKindAudio;
    else if (self.section == SCISheetSectionVideo) self.kind = SCIYTJobKindVideo;

    [self.table reloadData];
}

- (void)dismissSheet {
    [self dismissViewControllerAnimated:YES completion:nil];
}

// MARK: - The list

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (self.section == SCISheetSectionVideo) ? (NSInteger)self.groups.count : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Sound has no sizes to choose between: there is one soundtrack, and offering seven
    // identical rows of it would be a menu pretending to be a decision. A thumbnail has
    // one picture, for the same reason.
    if (self.section != SCISheetSectionVideo) return 1;
    return (NSInteger)[self.groups[(NSUInteger)section][@"variants"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (self.section) {
        case SCISheetSectionAudio:     return SCILocalized(@"dl_sound_header");
        case SCISheetSectionThumbnail: return SCILocalized(@"dl_thumb_header");
        case SCISheetSectionVideo:     break;
    }
    return self.groups[(NSUInteger)section][@"title"];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
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
        cell.textLabel.text = SCILocalized(@"dl_sound_only");
        cell.detailTextLabel.text = SCILocalized(@"dl_sound_small");
        cell.imageView.image = [UIImage systemImageNamed:@"music.note"];
        cell.imageView.tintColor = SCIAccent();
        return cell;
    }

    SCIHLSVariant *variant = [self variantAtIndexPath:indexPath];
    cell.textLabel.text = [variant label];
    cell.imageView.image = [UIImage systemImageNamed:@"film"];
    cell.imageView.tintColor = SCIAccent();

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

    // The soundtrack is the same whichever quality row it hangs off, so audio takes the first
    // ordinary variant rather than whatever happens to be on top (which may be a 4K one).
    SCIHLSVariant *variant = (self.section == SCISheetSectionAudio)
        ? ([self.groups.lastObject[@"variants"] firstObject] ?: self.variants.firstObject)
        : [self variantAtIndexPath:indexPath];

    void (^chosen)(SCIHLSVariant *, SCIYTJobKind) = self.chosen;
    SCIYTJobKind kind = self.kind;

    [self dismissViewControllerAnimated:YES completion:^{
        if (chosen) chosen(variant, kind);
    }];
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
