#import "SCIYTDownloadList.h"
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import "../../../Tweak.h"
#import "SCIYTLibrary.h"
#import "SCIYTPlayer.h"
#import "SCIYTThumbnails.h"
#import "SCIYTRowCell.h"
#import "../../../SCILog.h"
#import "../../../Prefs.h"
#import "../../../Localization/SCILocalize.h"


@interface SCIYTDownloadList ()
@property (nonatomic) SCIYTJobKind kind;
@property (nonatomic) BOOL shorts;
@property (nonatomic, strong) NSArray<SCIYTJob *> *rows;
@end

@implementation SCIYTDownloadList

- (instancetype)initWithKind:(SCIYTJobKind)kind shorts:(BOOL)shorts {
    // Plain, not inset-grouped -- the app's own scrolling lists are edge to edge, and the
    // grouped style adds a second set of side margins on top of the row's own, doubling
    // up the gutter and pushing the thumbnail in from where the app would put it.
    self = [super initWithStyle:UITableViewStylePlain];
    if (!self) return nil;

    _kind = kind;
    _shorts = shorts && kind == SCIYTJobKindVideo;

    NSString *titleKey = self.shorts ? @"dl_kind_shorts"
                        : (kind == SCIYTJobKindVideo) ? @"dl_kind_video" : @"dl_kind_audio";
    NSString *symbol = self.shorts ? @"bolt.fill"
                     : (kind == SCIYTJobKindVideo) ? @"film" : @"music.note";

    self.title = SCILocalized(titleKey);
    self.tabBarItem = [[UITabBarItem alloc]
        initWithTitle:self.title
                image:[UIImage systemImageNamed:symbol]
                  tag:kind];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Plain, not inset-grouped, and with nothing drawn between rows.
    //
    // The grouping chrome was doing the job the cards now do, and doing both is a box inside
    // a box. Separators go for the same reason: a card already says where one thing ends.
    self.tableView.rowHeight = [SCIYTRowCell heightForKind:self.kind];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.contentInset = UIEdgeInsetsMake(6, 0, 24, 0);

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reload)
                                                 name:SCIYTLibraryDidChangeNotification
                                               object:nil];
    [self reload];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }

- (void)reload {
    NSMutableArray<SCIYTJob *> *mine = [NSMutableArray array];
    for (SCIYTJob *job in [SCIYTLibrary shared].jobs) {
        if (job.kind != self.kind) continue;

        // Only checked for video: audio has no Shorts split, and a Short saved as sound
        // belongs with every other saved sound rather than nowhere at all.
        if (self.kind == SCIYTJobKindVideo && job.isShort != self.shorts) continue;

        [mine addObject:job];
    }
    self.rows = mine;
    [self.tableView reloadData];

    // Stills and lengths are made after the list is on screen, never while it is being
    // drawn: opening thirty assets to fill a table is how a list arrives late.
    for (SCIYTJob *job in mine) {
        if (job.state != SCIYTJobStateDone) continue;
        [SCIYTThumbnails prepare:job completion:^(UIImage *image) {
            [self.tableView reloadData];
        }];
    }
}

// MARK: - Rows

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)MAX(self.rows.count, (NSUInteger)1);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!self.rows.count) return [self emptyCell];

    SCIYTRowCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row"];
    if (!cell) {
        cell = [[SCIYTRowCell alloc] initWithStyle:UITableViewCellStyleDefault
                                   reuseIdentifier:@"row"];
    }

    SCIYTJob *job = self.rows[(NSUInteger)indexPath.row];
    [cell fillWith:job
           artwork:[SCIYTThumbnails cached:job]
           playing:[[SCIYTPlayer nowPlaying] isEqual:job]];

    return cell;
}

/// The row shown when there is nothing saved.
///
/// A cell rather than a background view, because a table with one centred label in it and a
/// table with rows in it should not be two different screens -- the switch at the top stays
/// where it is, and only the contents change.
- (UITableViewCell *)emptyCell {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                                   reuseIdentifier:nil];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    cell.imageView.image = [UIImage systemImageNamed:
        self.shorts ? @"bolt" : self.kind == SCIYTJobKindVideo ? @"film.stack" : @"music.note.list"];
    cell.imageView.tintColor = [UIColor colorWithWhite:1 alpha:0.25];

    cell.textLabel.text = SCILocalized(@"dl_centre_empty");
    cell.textLabel.textColor = [UIColor colorWithWhite:1 alpha:0.7];
    cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];

    cell.detailTextLabel.text = SCILocalized(@"dl_centre_empty_hint");
    cell.detailTextLabel.textColor = [UIColor colorWithWhite:1 alpha:0.4];
    cell.detailTextLabel.numberOfLines = 0;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (!self.rows.count) return;

    SCIYTJob *job = self.rows[(NSUInteger)indexPath.row];
    if (job.state != SCIYTJobStateDone) return;

    if (![job fileURL]) { [[SCIYTLibrary shared] remove:job]; return; }

    // Everything that is playable in this list, in the order it is shown. The row that
    // was tapped is where it starts, and next runs down the rest.
    NSMutableArray<SCIYTJob *> *queue = [NSMutableArray array];
    NSUInteger start = 0;
    for (SCIYTJob *candidate in self.rows) {
        if (candidate.state != SCIYTJobStateDone) continue;
        if (candidate == job) start = queue.count;
        [queue addObject:candidate];
    }

    // An AV1 file this iPhone cannot decode would open a player that shows nothing. Said first,
    // with the way out: the file is intact, and an app that can play it is one share away.
    if ([self fileIsAV1ThisDeviceCannotPlay:[job fileURL]]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:SCILocalized(@"dl_av1_unplayable_title")
                                                                       message:SCILocalized(@"dl_av1_unplayable_msg")
                                                                preferredStyle:UIAlertControllerStyleAlert];
        NSURL *file = [job fileURL];
        [alert addAction:[UIAlertAction actionWithTitle:SCILocalized(@"dl_share") style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            UIActivityViewController *sheet = [[UIActivityViewController alloc] initWithActivityItems:@[file] applicationActivities:nil];
            sheet.popoverPresentationController.sourceView = self.view;
            sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
            [self presentViewController:sheet animated:YES completion:nil];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:SCILocalized(@"ok") style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    [SCIYTPlayer presentFrom:self jobs:queue start:start];
}

/// Whether the file's picture is AV1 and this device has no AV1 decoder. Read from the file's
/// own track description, not from the title or the quality label a person could have renamed.
- (BOOL)fileIsAV1ThisDeviceCannotPlay:(NSURL *)url {
    if (!url) return NO;

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    for (AVAssetTrack *track in [asset tracksWithMediaType:AVMediaTypeVideo]) {
        for (id description in track.formatDescriptions) {
            CMFormatDescriptionRef format = (__bridge CMFormatDescriptionRef)description;
            if (CMFormatDescriptionGetMediaSubType(format) == kCMVideoCodecType_AV1) {
                return !VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1);
            }
        }
    }
    return NO;
}

// MARK: - Swipes

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {

    if (!self.rows.count) return nil;
    SCIYTJob *job = self.rows[(NSUInteger)indexPath.row];

    UIContextualAction *remove =
        [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                title:SCILocalized(@"delete")
                                              handler:^(UIContextualAction *action,
                                                        UIView *source,
                                                        void (^done)(BOOL)) {
        // Asked first. A swipe is easy to make by accident on a list you are scrolling,
        // and what it destroys took minutes to fetch and cannot be recovered -- the file is
        // gone from the device, not moved to a bin.
        [self confirmDelete:job then:^{
            [SCIYTThumbnails forget:job];
            [[SCIYTLibrary shared] remove:job];
        }];
        done(YES);
    }];

    if (job.state != SCIYTJobStateDone) {
        return [UISwipeActionsConfiguration configurationWithActions:@[remove]];
    }

    UIContextualAction *share =
        [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                title:SCILocalized(@"dl_share")
                                              handler:^(UIContextualAction *action,
                                                        UIView *source,
                                                        void (^done)(BOOL)) {
        [self share:job from:source];
        done(YES);
    }];
    share.backgroundColor = [UIColor systemBlueColor];

    UIContextualAction *photos =
        [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                title:SCILocalized(@"dl_to_photos")
                                              handler:^(UIContextualAction *action,
                                                        UIView *source,
                                                        void (^done)(BOOL)) {
        [[SCIYTLibrary shared] export:job completion:^(BOOL ok, NSString *detail) {
            if (!ok) {
                [self say:detail ?: SCILocalized(@"dl_failed")];
                return;
            }

            // Kept in both places unless asked otherwise. Photos is where a video goes to
            // be kept; the Centre is where it goes to be played -- and deciding for someone
            // that they wanted only one of those is not this tweak's call. The switch is
            // there for anyone who does not want two copies of everything.
            if (!SCIPrefEnabled(SCIPrefTidyAfterPhotos)) {
                [self say:SCILocalized(@"dl_saved")];
                return;
            }

            [SCIYTThumbnails forget:job];
            [[SCIYTLibrary shared] remove:job];
            [self say:SCILocalized(@"dl_saved_and_removed")];
        }];
        done(YES);
    }];
    photos.backgroundColor = SCIAccent();

    UIContextualAction *rename =
        [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                title:SCILocalized(@"dl_rename")
                                              handler:^(UIContextualAction *action,
                                                        UIView *source,
                                                        void (^done)(BOOL)) {
        [self askToRename:job];
        done(YES);
    }];
    rename.backgroundColor = [UIColor systemGrayColor];

    // Sound has no place in Photos, so that action is not offered for it at all rather
    // than offered and then refused.
    return (self.kind == SCIYTJobKindAudio)
        ? [UISwipeActionsConfiguration configurationWithActions:@[remove, rename, share]]
        : [UISwipeActionsConfiguration configurationWithActions:@[remove, rename, photos, share]];
}

/// Asks before destroying something, and says what.
///
/// Named rather than generic: "Delete this?" beside a list of forty saves is a question
/// nobody can answer confidently. The title is in the message.
- (void)confirmDelete:(SCIYTJob *)job then:(void (^)(void))go {
    UIAlertController *ask = [UIAlertController
        alertControllerWithTitle:SCILocalized(@"dl_delete_title")
                         message:[NSString stringWithFormat:SCILocalized(@"dl_delete_body"),
                                  job.title ?: @""]
                  preferredStyle:UIAlertControllerStyleAlert];

    [ask addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];

    [ask addAction:[UIAlertAction actionWithTitle:SCILocalized(@"delete")
                                            style:UIAlertActionStyleDestructive
                                          handler:^(__unused UIAlertAction *action) {
        if (go) go();
    }]];

    [self presentViewController:ask animated:YES completion:nil];
}

- (void)askToRename:(SCIYTJob *)job {
    UIAlertController *ask =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"dl_rename")
                                            message:nil
                                     preferredStyle:UIAlertControllerStyleAlert];

    [ask addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.text = job.title;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;

        // Selected rather than left with the caret at the end. Renaming usually means
        // replacing, and making someone hold backspace through a YouTube title is a small
        // cruelty.
        field.selectedTextRange = [field textRangeFromPosition:field.beginningOfDocument
                                                    toPosition:field.endOfDocument];
    }];

    __weak __typeof(self) weakSelf = self;
    [ask addAction:[UIAlertAction actionWithTitle:SCILocalized(@"ok")
                                            style:UIAlertActionStyleDefault
                                          handler:^(__unused UIAlertAction *action) {
        NSString *typed = ask.textFields.firstObject.text;
        if (![[SCIYTLibrary shared] rename:job to:typed]) {
            [weakSelf say:SCILocalized(@"dl_rename_failed")];
        }
    }]];

    [ask addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];

    [self presentViewController:ask animated:YES completion:nil];
}

- (void)share:(SCIYTJob *)job from:(UIView *)source {
    NSURL *file = [job fileURL];
    if (!file) return;

    UIActivityViewController *sheet =
        [[UIActivityViewController alloc] initWithActivityItems:@[file] applicationActivities:nil];

    UIView *anchor = source ?: self.view;
    sheet.popoverPresentationController.sourceView = anchor;
    sheet.popoverPresentationController.sourceRect =
        CGRectMake(CGRectGetMidX(anchor.bounds), CGRectGetMidY(anchor.bounds), 1, 1);

    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)say:(NSString *)message {
    if (!message.length) return;

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"dl_title")
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:SCILocalized(@"ok")
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
