//
//  SCIYTQueueSheet.m
//  Albrhi for YouTube
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCIYTQueueSheet.h"
#import "SCIYTPlayer.h"
#import "SCIYTJob.h"
#import "SCIYTThumbnails.h"
#import "../../../Tweak.h"
#import "../../../Prefs.h"
#import "../../../Localization/SCILocalize.h"

@interface SCIYTQueueSheet ()
@property (nonatomic, copy) NSArray<SCIYTJob *> *jobs;
@property (nonatomic) NSUInteger playing;
@end

@implementation SCIYTQueueSheet

+ (void)presentFrom:(UIViewController *)presenter {
    SCIYTQueueSheet *sheet = [[SCIYTQueueSheet alloc] initWithStyle:UITableViewStyleInsetGrouped];
    UINavigationController *host = [[UINavigationController alloc] initWithRootViewController:sheet];
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *presentation = host.sheetPresentationController;
        presentation.detents = @[[UISheetPresentationControllerDetent mediumDetent], [UISheetPresentationControllerDetent largeDetent]];
        presentation.prefersGrabberVisible = YES;
    }
    [presenter presentViewController:host animated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = SCILocalized(@"player_queue");
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(close)];
    // Always in editing mode: the handles to move a row and the buttons to take it out are the
    // whole point of the screen, and a tap still jumps to the row.
    self.tableView.editing = YES;
    self.tableView.allowsSelectionDuringEditing = YES;
    [self pull];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changed)
                                                 name:SCIYTPlaybackDidChangeNotification object:nil];
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }

- (void)pull {
    self.jobs = [SCIYTPlayer queueJobs];
    self.playing = [SCIYTPlayer queueIndex];
}

/// Something else changed the queue (the next track began): follow it, unless a row is being dragged.
- (void)changed {
    NSArray *before = self.jobs;
    NSUInteger was = self.playing;
    [self pull];
    if (![before isEqualToArray:self.jobs] || was != self.playing) [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(__unused UITableView *)tableView { return 1; }

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(__unused NSInteger)section {
    return (NSInteger)self.jobs.count;
}

- (NSString *)tableView:(__unused UITableView *)tableView titleForFooterInSection:(__unused NSInteger)section {
    NSString *note = SCILocalized(@"player_queue_note");
    if ([SCIYTPlayer queueShuffled]) note = [note stringByAppendingFormat:@"\n%@", SCILocalized(@"player_queue_shuffle_note")];
    return note;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"row"];
    SCIYTJob *job = self.jobs[(NSUInteger)path.row];
    BOOL now = ((NSUInteger)path.row == self.playing);
    cell.textLabel.text = job.title;
    cell.textLabel.numberOfLines = 2;
    cell.textLabel.font = [UIFont systemFontOfSize:16 weight:now ? UIFontWeightBold : UIFontWeightRegular];
    cell.textLabel.textColor = now ? SCIAccent() : [UIColor labelColor];
    cell.detailTextLabel.text = now ? SCILocalized(@"player_queue_now") : job.quality;
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    cell.showsReorderControl = YES;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    [SCIYTPlayer queueJumpTo:(NSUInteger)path.row];
    [self pull];
    [tableView reloadData];
}

- (BOOL)tableView:(__unused UITableView *)tableView canMoveRowAtIndexPath:(__unused NSIndexPath *)path { return YES; }

- (void)tableView:(__unused UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)from toIndexPath:(NSIndexPath *)to {
    [SCIYTPlayer queueMoveFrom:(NSUInteger)from.row to:(NSUInteger)to.row];
    [self pull];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)path {
    if (style != UITableViewCellEditingStyleDelete) return;
    [SCIYTPlayer queueRemoveAt:(NSUInteger)path.row];
    [self pull];
    if (!self.jobs.count) { [self close]; return; }
    [tableView reloadData];
}

@end
