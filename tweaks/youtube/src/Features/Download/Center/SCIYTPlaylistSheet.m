#import "SCIYTPlaylistSheet.h"
#import "SCIYTLibrary.h"
#import "../SCIYTPlaylist.h"
#import "../SCIYTRecipe.h"
#import "../../../Tweak.h"
#import "../../../Localization/SCILocalize.h"

/// The most videos one batch takes. Five hundred is ten pages of the answer and more downloading
/// than anyone starts in one go; a longer list says so and offers the first five hundred.
static const NSUInteger kSCILimit = 500;

typedef NS_ENUM(NSInteger, SCIPlaylistStage) { SCIPlaylistStageInput, SCIPlaylistStageLoading, SCIPlaylistStageReady };

@interface SCIYTPlaylistSheet () <UITextFieldDelegate>
@property (nonatomic) SCIPlaylistStage stage;
@property (nonatomic, strong) UITextField *field;
@property (nonatomic, copy) NSString *message;        ///< why the last load failed, or nil
@property (nonatomic, copy) NSString *playlistTitle;
@property (nonatomic, copy) NSString *playlistTotal;
@property (nonatomic, copy) NSArray<NSString *> *videoIDs;
@property (nonatomic) BOOL soundOnly;
@property (nonatomic) NSInteger maxHeight;            ///< 0 = the tallest there is
@property (nonatomic) BOOL skipSaved;
@property (nonatomic) BOOL expanded;
@end

@implementation SCIYTPlaylistSheet

+ (void)presentFrom:(UIViewController *)presenter {
    SCIYTPlaylistSheet *sheet = [[SCIYTPlaylistSheet alloc] initWithStyle:UITableViewStyleInsetGrouped];
    UINavigationController *host = [[UINavigationController alloc] initWithRootViewController:sheet];
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *presentation = host.sheetPresentationController;
        presentation.detents = @[[UISheetPresentationControllerDetent mediumDetent], [UISheetPresentationControllerDetent largeDetent]];
        presentation.prefersGrabberVisible = YES;
        presentation.preferredCornerRadius = 22;
    }
    [presenter presentViewController:host animated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = SCILocalized(@"pl_title");
    self.maxHeight = 720;
    self.skipSaved = YES;
    self.videoIDs = @[];

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(close)];

    self.field = [[UITextField alloc] init];
    self.field.placeholder = SCILocalized(@"pl_placeholder");
    self.field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.field.autocorrectionType = UITextAutocorrectionTypeNo;
    self.field.keyboardType = UIKeyboardTypeURL;
    self.field.returnKeyType = UIReturnKeyGo;
    self.field.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.field.textAlignment = NSTextAlignmentNatural;
    self.field.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;   // a link is Latin
    self.field.delegate = self;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fieldChanged:)
                                                 name:UITextFieldTextDidChangeNotification object:self.field];

}

/// A pasted link that is a playlist's loads without another tap.
- (void)fieldChanged:(NSNotification *)note {
    if (self.stage != SCIPlaylistStageInput) return;
    NSString *text = self.field.text ?: @"";
    if (text.length > 20 && [SCIYTPlaylist playlistIDFromText:text reason:nil]) [self load];
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }

// MARK: - Loading

- (void)load {
    [self.field resignFirstResponder];

    NSString *reason = nil;
    NSString *identifier = [SCIYTPlaylist playlistIDFromText:self.field.text ?: @"" reason:&reason];
    if (!identifier) {
        self.message = reason ?: SCILocalized(@"pl_why_bad");
        self.stage = SCIPlaylistStageInput;
        [self refresh];
        return;
    }

    self.message = nil;
    self.stage = SCIPlaylistStageLoading;
    [self refresh];

    __weak __typeof(self) weakSelf = self;
    [SCIYTPlaylist loadPlaylistID:identifier limit:kSCILimit completion:^(NSArray<NSString *> *ids, NSString *title, NSString *total, NSString *failure) {
        __typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.videoIDs = ids;
        strongSelf.playlistTitle = title;
        strongSelf.playlistTotal = total;
        strongSelf.message = failure;
        strongSelf.stage = ids.count ? SCIPlaylistStageReady : SCIPlaylistStageInput;
        [strongSelf refresh];
    }];
}

- (BOOL)textFieldShouldReturn:(UITextField *)field { [self load]; return NO; }

- (void)refresh {
    BOOL ready = (self.stage == SCIPlaylistStageReady);
    UIBarButtonItem *item = [[UIBarButtonItem alloc]
        initWithTitle:[NSString stringWithFormat:SCILocalized(@"pl_download_n"), (long)self.videoIDs.count]
                style:UIBarButtonItemStyleDone target:self action:@selector(start)];
    item.tintColor = SCIAccent();
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    self.toolbarItems = @[flex, item, flex];
    if (ready && !self.expanded) {
        self.expanded = YES;
        if (@available(iOS 15.0, *)) {
            self.navigationController.sheetPresentationController.selectedDetentIdentifier = UISheetPresentationControllerDetentIdentifierLarge;
        }
    }
    [self.navigationController setToolbarHidden:!ready animated:YES];
    [self.tableView reloadData];
}

// MARK: - Starting

- (void)start {
    NSMutableArray<SCIYTRecipe *> *recipes = [NSMutableArray array];
    SCIYTJobKind kind = self.soundOnly ? SCIYTJobKindAudio : SCIYTJobKindVideo;

    for (NSString *video in self.videoIDs) {
        if (self.skipSaved && [[SCIYTLibrary shared] existingJobForVideo:video kind:kind]) continue;
        SCIYTRecipe *recipe = [[SCIYTRecipe alloc] init];
        recipe.videoID = video;
        recipe.audioOnly = self.soundOnly;
        recipe.maxHeight = self.maxHeight;
        [recipes addObject:recipe];
    }

    if (!recipes.count) {
        self.message = SCILocalized(@"pl_all_saved");
        [self refresh];
        return;
    }

    [[SCIYTLibrary shared] enqueueRecipes:recipes];
    [self dismissViewControllerAnimated:YES completion:nil];
}

// MARK: - The list

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.stage == SCIPlaylistStageReady ? 3 : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.stage != SCIPlaylistStageReady) return 3;      // the link, Paste, and Load
    switch (section) {
        case 0: return 2;                                    // what was found, and the link again
        case 1: return self.soundOnly ? 1 : 6;               // video / sound, and the qualities
        default: return 1;                                   // skip what is saved
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (self.stage != SCIPlaylistStageReady) return SCILocalized(@"pl_header_link");
    return section == 1 ? SCILocalized(@"pl_header_quality") : nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (self.stage != SCIPlaylistStageReady) {
        if (self.stage == SCIPlaylistStageLoading) return SCILocalized(@"pl_loading");
        return self.message ?: SCILocalized(@"pl_hint");
    }
    if (section == 0 && self.videoIDs.count >= kSCILimit) return [NSString stringWithFormat:SCILocalized(@"pl_truncated"), (long)kSCILimit];
    if (section == 0 && self.message.length) return self.message;
    if (section == 2) return SCILocalized(@"pl_queue_note");
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.tintColor = SCIAccent();

    if (self.stage != SCIPlaylistStageReady) {
        if (indexPath.row == 0) {
            self.field.frame = CGRectInset(cell.contentView.bounds, 16, 0);
            self.field.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [cell.contentView addSubview:self.field];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else if (indexPath.row == 1) {
            // Reading the pasteboard shows iOS's own "would like to paste" box, so it happens only
            // when this is tapped -- never on its own when the sheet opens.
            cell.textLabel.text = SCILocalized(@"pl_paste");
            cell.imageView.image = [UIImage systemImageNamed:@"doc.on.clipboard"];
            cell.imageView.tintColor = SCIAccent();
        } else {
            cell.textLabel.text = SCILocalized(self.stage == SCIPlaylistStageLoading ? @"pl_loading_short" : @"pl_load");
            cell.textLabel.textColor = SCIAccent();
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
            if (self.stage == SCIPlaylistStageLoading) {
                UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
                [spinner startAnimating];
                cell.accessoryView = spinner;
            }
        }
        return cell;
    }

    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = self.playlistTitle.length ? self.playlistTitle : SCILocalized(@"pl_title");
            cell.textLabel.numberOfLines = 2;
            NSString *found = [NSString stringWithFormat:SCILocalized(@"pl_found"), (long)self.videoIDs.count];
            cell.detailTextLabel.text = (self.playlistTotal.length && self.playlistTotal.integerValue != (NSInteger)self.videoIDs.count)
                ? [NSString stringWithFormat:@"%@ / %@", found, self.playlistTotal] : found;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else {
            cell.textLabel.text = SCILocalized(@"pl_another");
            cell.textLabel.textColor = SCIAccent();
        }
        return cell;
    }

    if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            UISegmentedControl *kind = [[UISegmentedControl alloc] initWithItems:@[SCILocalized(@"dl_kind_video"), SCILocalized(@"dl_kind_audio")]];
            kind.selectedSegmentIndex = self.soundOnly ? 1 : 0;
            kind.selectedSegmentTintColor = SCIAccent();
            [kind setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]} forState:UIControlStateSelected];
            [kind addTarget:self action:@selector(kindChanged:) forControlEvents:UIControlEventValueChanged];
            kind.frame = CGRectInset(cell.contentView.bounds, 16, 6);
            kind.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [cell.contentView addSubview:kind];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            return cell;
        }
        NSInteger heights[] = {0, 1080, 720, 480, 360};
        NSInteger height = heights[indexPath.row - 1];
        cell.textLabel.text = height ? [NSString stringWithFormat:@"%ldp", (long)height] : SCILocalized(@"pl_best");
        cell.accessoryType = (self.maxHeight == height) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        return cell;
    }

    cell.textLabel.text = SCILocalized(@"pl_skip_saved");
    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.on = self.skipSaved;
    toggle.onTintColor = SCIAccent();
    [toggle addTarget:self action:@selector(skipChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (void)kindChanged:(UISegmentedControl *)sender { self.soundOnly = (sender.selectedSegmentIndex == 1); [self.tableView reloadData]; }
- (void)skipChanged:(UISwitch *)sender { self.skipSaved = sender.on; }

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (self.stage != SCIPlaylistStageReady) {
        if (self.stage != SCIPlaylistStageInput) return;
        if (indexPath.row == 1) {
            NSString *clip = [UIPasteboard generalPasteboard].string;
            if (clip.length) { self.field.text = clip; [self load]; }
        } else if (indexPath.row == 2) {
            [self load];
        }
        return;
    }
    if (indexPath.section == 0 && indexPath.row == 1) {
        self.stage = SCIPlaylistStageInput;
        self.message = nil;
        [self refresh];
        [self.field becomeFirstResponder];
        return;
    }
    if (indexPath.section == 1 && indexPath.row >= 1) {
        NSInteger heights[] = {0, 1080, 720, 480, 360};
        self.maxHeight = heights[indexPath.row - 1];
        [tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone];
    }
}

@end
