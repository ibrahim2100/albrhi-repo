//
//  SCIYTChapterSheet.m
//  Albrhi for YouTube
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCIYTChapterSheet.h"
#import "SCIYTThumbnails.h"
#import "../../../Tweak.h"
#import "../../../Localization/SCILocalize.h"

@interface SCIYTChapterSheet ()
@property (nonatomic, copy) NSArray<NSDictionary *> *chapters;
@property (nonatomic) NSInteger current;
@property (nonatomic, copy) void (^jump)(double);
@end

@implementation SCIYTChapterSheet

+ (void)presentFrom:(UIViewController *)presenter chapters:(NSArray<NSDictionary *> *)chapters current:(NSInteger)current jump:(void (^)(double))jump {
    SCIYTChapterSheet *sheet = [[SCIYTChapterSheet alloc] initWithStyle:UITableViewStyleInsetGrouped];
    sheet.chapters = chapters;
    sheet.current = current;
    sheet.jump = jump;
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
    self.title = SCILocalized(@"chapters_title");
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(close)];
}

- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return (NSInteger)self.chapters.count; }

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section { return SCILocalized(@"chapters_note"); }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    NSDictionary *chapter = self.chapters[(NSUInteger)path.row];
    BOOL now = (path.row == self.current);
    NSString *title = [chapter[@"title"] length] ? chapter[@"title"] : [NSString stringWithFormat:SCILocalized(@"chapters_untitled"), (long)path.row + 1];
    cell.textLabel.text = title;
    cell.textLabel.numberOfLines = 2;
    cell.textLabel.font = [UIFont systemFontOfSize:16 weight:now ? UIFontWeightBold : UIFontWeightRegular];
    cell.textLabel.textColor = now ? SCIAccent() : [UIColor labelColor];
    cell.detailTextLabel.text = [SCIYTThumbnails clock:[chapter[@"start"] doubleValue]];
    cell.detailTextLabel.font = [UIFont monospacedDigitSystemFontOfSize:15 weight:UIFontWeightRegular];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    double start = [self.chapters[(NSUInteger)path.row][@"start"] doubleValue];
    [self dismissViewControllerAnimated:YES completion:^{ if (self.jump) self.jump(start); }];
}

@end
