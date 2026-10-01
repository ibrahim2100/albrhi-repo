#import "SCIUnsentLogViewController.h"
#import "../Utils.h"
#import "../Localization/SCILocalize.h"
#import "../Features/StoriesAndMessages/SCIUnsentLog.h"

// Row layout: who and when on the first line, what was said under it. A row is as tall as its
// text -- a long message is the thing this screen exists to show.

@interface SCIUnsentLogViewController ()
@property (nonatomic, copy) NSArray<NSDictionary *> *rows;
@property (nonatomic, strong) NSDateFormatter *formatter;
@end

@implementation SCIUnsentLogViewController

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = SCILocalized(@"unsent_log_title");
    self.view.tintColor = [SCIUtils SCIColor_Primary];

    BOOL rtl = [SCILocalize isRTL];
    if (rtl) self.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;

    // The formatter is told which language the sentence is in. NSDateFormatter follows the
    // system locale, while this screen's language is the tweak's own setting -- two settings,
    // not one, and a date in the wrong one is a line carrying two scripts.
    self.formatter = [[NSDateFormatter alloc] init];
    self.formatter.locale = [NSLocale localeWithLocaleIdentifier:rtl ? @"ar" : @"en_US"];
    self.formatter.dateStyle = NSDateFormatterMediumStyle;
    self.formatter.timeStyle = NSDateFormatterShortStyle;

    // Automatic dimension needs an estimate or every row stays one line.
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 72;

    UIBarButtonItem *share = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"square.and.arrow.up"]
                                                              style:UIBarButtonItemStylePlain
                                                             target:self action:@selector(shareTapped)];
    UIBarButtonItem *clear = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"trash"]
                                                              style:UIBarButtonItemStylePlain
                                                             target:self action:@selector(clearTapped)];
    clear.tintColor = [UIColor systemRedColor];
    self.navigationItem.rightBarButtonItems = @[share, clear];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reload)
                                                 name:SCIUnsentLogDidChangeNotification object:nil];
    [self reload];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)reload {
    self.rows = [SCIUnsentLog entries];

    UILabel *empty = nil;
    if (!self.rows.count) {
        empty = [[UILabel alloc] init];
        empty.text = SCILocalized(@"unsent_log_empty");
        empty.textColor = [UIColor secondaryLabelColor];
        empty.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
        empty.textAlignment = NSTextAlignmentCenter;
        empty.numberOfLines = 0;
        empty.layoutMargins = UIEdgeInsetsMake(0, 32, 0, 32);
    }
    self.tableView.backgroundView = empty;
    self.navigationItem.rightBarButtonItems.firstObject.enabled = self.rows.count > 0;
    self.navigationItem.rightBarButtonItems.lastObject.enabled = self.rows.count > 0;

    [self.tableView reloadData];
}

// MARK: - Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.rows.count;
}

- (NSString *)titleForRow:(NSDictionary *)row {
    // FSI…PDI around a name: a Latin username beside Arabic words and digits is read as one
    // left-to-right run by the bidi algorithm unless something says where it ends.
    NSString *me = [SCIUtils currentUsername];
    NSString *name = row[@"name"];
    NSString *who;
    if (name.length) who = name;
    else if (row[@"sender"]) who = [NSString stringWithFormat:@"%@ %@", SCILocalized(@"unsent_log_user"), row[@"sender"]];
    else who = SCILocalized(@"unsent_log_unknown_sender");
    if (me.length && [who isEqualToString:me]) who = SCILocalized(@"unsent_log_you");
    return [NSString stringWithFormat:@"⁨%@⁩", who];
}

- (NSString *)detailForRow:(NSDictionary *)row {
    NSString *text = row[@"text"];
    if (text.length) return text;
    if ([row[@"captured"] boolValue]) return [NSString stringWithFormat:@"[%@]", [SCIUnsentLog localizedKind:row[@"kind"]]];
    return SCILocalized(@"unsent_log_not_captured");
}

- (NSString *)whenForRow:(NSDictionary *)row {
    NSTimeInterval sent = [row[@"sent"] doubleValue];
    NSString *deleted = [self.formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:[row[@"deleted"] doubleValue]]];
    if (sent <= 0) return [NSString stringWithFormat:@"%@ %@", SCILocalized(@"unsent_log_deleted"), deleted];

    NSString *sentText = [self.formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:sent]];
    return [NSString stringWithFormat:@"%@ ⁨%@⁩ · %@ ⁨%@⁩",
            SCILocalized(@"unsent_log_sent"), sentText, SCILocalized(@"unsent_log_deleted"), deleted];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"row"];
        cell.textLabel.numberOfLines = 0;
        cell.detailTextLabel.numberOfLines = 0;
    }

    NSDictionary *row = self.rows[indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"%@\n%@", [self titleForRow:row], [self whenForRow:row]];
    cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    cell.textLabel.textColor = [UIColor secondaryLabelColor];

    cell.detailTextLabel.text = [self detailForRow:row];
    cell.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    cell.detailTextLabel.textColor = [row[@"text"] length] ? [UIColor labelColor] : [UIColor tertiaryLabelColor];
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (!self.rows.count) return nil;
    return [NSString stringWithFormat:SCILocalized(@"unsent_log_footer"), (long)self.rows.count];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSDictionary *row = self.rows[indexPath.row];
    [UIPasteboard generalPasteboard].string = [self detailForRow:row];
    [SCIUtils showToastForDuration:1.4 title:SCILocalized(@"unsent_log_copied")];
}

// A swipe never performs its first action on a full swipe: removing a row is the one thing
// here that cannot be undone, and a gesture that fires it without stopping is how a record
// gets thinner without anybody deciding it should.
- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *row = self.rows[indexPath.row];
    UIContextualAction *remove = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                         title:SCILocalized(@"unsent_log_remove")
                                                                       handler:^(__unused UIContextualAction *action,
                                                                                 __unused UIView *view,
                                                                                 void (^done)(BOOL)) {
        [SCIUnsentLog removeEntryWithIdentifier:row[@"id"]];
        done(YES);
    }];
    UISwipeActionsConfiguration *config = [UISwipeActionsConfiguration configurationWithActions:@[remove]];
    config.performsFirstActionWithFullSwipe = NO;
    return config;
}

// MARK: - Bar

- (void)shareTapped {
    NSString *text = [SCIUnsentLog exportText];
    if (!text.length) return;

    UIActivityViewController *sheet = [[UIActivityViewController alloc] initWithActivityItems:@[text] applicationActivities:nil];
    sheet.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItems.firstObject;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)clearTapped {
    [SCIUtils showConfirmation:^{ [SCIUnsentLog clear]; }
                         title:SCILocalized(@"unsent_log_clear_confirm")];
}

@end
