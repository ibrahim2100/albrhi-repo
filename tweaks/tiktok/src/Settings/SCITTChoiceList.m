//
//  SCITTChoiceList.m
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCITTChoiceList.h"

static NSInteger SCITTChoiceIndex(NSArray<NSDictionary *> *options, NSString *pref) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    id stored = [defaults objectForKey:pref];
    for (NSUInteger i = 0; i < options.count; i++) {
        id value = options[i][@"value"];
        if ([value isKindOfClass:NSString.class]) {
            NSString *have = [stored isKindOfClass:NSString.class] ? stored : @"";
            if ([have caseInsensitiveCompare:value] == NSOrderedSame) return (NSInteger)i;
        } else if ([value isKindOfClass:NSNumber.class]) {
            double have = [stored isKindOfClass:NSNumber.class] ? [stored doubleValue] : 0;
            if (have <= 0) have = [value doubleValue] == [options.firstObject[@"value"] doubleValue] ? [value doubleValue] : have;
            if (fabs(have - [value doubleValue]) < 0.001) return (NSInteger)i;
        }
    }
    return -1;
}

NSString *SCITTChoiceCurrentTitle(NSArray<NSDictionary *> *options, NSString *pref) {
    NSInteger index = SCITTChoiceIndex(options, pref);
    return index >= 0 ? options[(NSUInteger)index][@"title"] : @"";
}

@interface SCITTChoiceList ()
@property (nonatomic, copy) NSString *pref;
@property (nonatomic, copy) NSArray<NSDictionary *> *options;
@property (nonatomic, copy) NSString *footer;
@end

@implementation SCITTChoiceList

- (instancetype)initWithTitle:(NSString *)title pref:(NSString *)pref options:(NSArray<NSDictionary *> *)options footer:(NSString *)footer {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        self.title = title;
        self.pref = pref;
        self.options = options;
        self.footer = footer;
    }
    return self;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return (NSInteger)self.options.count; }

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section { return self.footer; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"choice"] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"choice"];
    cell.textLabel.text = self.options[(NSUInteger)indexPath.row][@"title"];
    cell.accessoryType = indexPath.row == SCITTChoiceIndex(self.options, self.pref) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if (indexPath.row == 0) {
        [defaults removeObjectForKey:self.pref];                       // the default is the absence of a choice
    } else {
        id value = self.options[(NSUInteger)indexPath.row][@"value"];
        if ([value isKindOfClass:NSString.class]) [defaults setObject:value forKey:self.pref];
        else [defaults setDouble:[value doubleValue] forKey:self.pref];
    }
    [self.navigationController popViewControllerAnimated:YES];
}

@end
