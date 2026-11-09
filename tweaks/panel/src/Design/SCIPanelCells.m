//
//  SCIPanelCells.m
//  Albrhi Panel
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCIPanelCells.h"
#import "SCIPanelStyle.h"
#import <Preferences/PSSpecifier.h>

NSString *const SCIPanelRowTileKey = @"sciTile";
NSString *const SCIPanelRowSubtitleKey = @"sciSubtitle";
NSString *const SCIPanelRowToneKey = @"sciTone";
NSString *const SCIPanelRowValueKey = @"sciValue";
NSString *const SCIPanelRowDestructiveKey = @"sciDestructive";
NSString *const SCIPanelRowBusyKey = @"sciBusy";

///
/// **Both row kinds draw the same row, so they share one body.**
///
/// `PSTableCell` places its title and icon by rules that change with the iOS version, with the switch and with the icon's own size -- which is
/// how the apps list came to have icons the size of the rows and a title squeezed against them. These rows own their subviews and lay them out
/// from the cell's own content size: the tile at the start, the text beside it, and whatever the system puts at the end (the switch, the
/// disclosure) outside the content view where UIKit already keeps it. The title `PSTableCell` still draws is hidden, not fought.
///
/// Laid out in left-to-right coordinates and mirrored once, at the end, for a right-to-left phone.
///
@interface SCIPanelRowBody : NSObject
@property (nonatomic, weak) UITableViewCell *cell;
@property (nonatomic, strong) UIImageView *tile;
@property (nonatomic, strong) UILabel *title, *subtitle, *value;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
- (instancetype)initWithCell:(UITableViewCell *)cell;
- (void)applySpecifier:(PSSpecifier *)specifier enabled:(BOOL)enabled;
- (void)layout;
@end

@implementation SCIPanelRowBody

- (instancetype)initWithCell:(UITableViewCell *)cell {
    if (!(self = [super init])) return nil;
    _cell = cell;

    _tile = [[UIImageView alloc] init];
    _tile.contentMode = UIViewContentModeScaleAspectFit;
    _title = [[UILabel alloc] init];
    _title.font = SCIPanelRoundedFont(17, UIFontWeightSemibold);
    _title.textColor = [UIColor labelColor];
    _title.adjustsFontSizeToFitWidth = YES;
    _title.minimumScaleFactor = 0.8;
    _subtitle = [[UILabel alloc] init];
    _subtitle.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    _subtitle.textColor = [UIColor secondaryLabelColor];
    _subtitle.adjustsFontSizeToFitWidth = YES;
    _subtitle.minimumScaleFactor = 0.82;
    _value = [[UILabel alloc] init];
    _value.font = [UIFont monospacedDigitSystemFontOfSize:15 weight:UIFontWeightMedium];
    _value.textColor = [UIColor secondaryLabelColor];
    _value.textAlignment = NSTextAlignmentRight;
    _value.adjustsFontSizeToFitWidth = YES;
    _value.minimumScaleFactor = 0.7;
    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _spinner.hidesWhenStopped = YES;

    for (UIView *view in @[_tile, _title, _subtitle, _value, _spinner]) [cell.contentView addSubview:view];
    return self;
}

- (void)applySpecifier:(PSSpecifier *)specifier enabled:(BOOL)enabled {
    UITableViewCell *cell = self.cell;
    // What PSTableCell drew, taken away rather than overwritten: it re-applies its own on every refresh.
    cell.textLabel.hidden = YES;
    cell.detailTextLabel.hidden = YES;
    cell.imageView.hidden = YES;
    cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];

    self.tile.image = [specifier propertyForKey:SCIPanelRowTileKey];
    self.title.text = specifier.name;
    BOOL destructive = [[specifier propertyForKey:SCIPanelRowDestructiveKey] boolValue];
    self.title.textColor = destructive ? [UIColor systemRedColor] : [UIColor labelColor];

    NSString *subtitle = [specifier propertyForKey:SCIPanelRowSubtitleKey];
    self.subtitle.text = subtitle;
    self.subtitle.hidden = !subtitle.length;
    switch ([[specifier propertyForKey:SCIPanelRowToneKey] integerValue]) {
        case SCIPanelToneCaution: self.subtitle.textColor = [UIColor systemOrangeColor]; break;
        case SCIPanelToneGood: self.subtitle.textColor = [UIColor systemGreenColor]; break;
        case SCIPanelToneBad: self.subtitle.textColor = [UIColor systemRedColor]; break;
        default: self.subtitle.textColor = [UIColor secondaryLabelColor]; break;
    }

    NSString *value = [specifier propertyForKey:SCIPanelRowValueKey];
    self.value.text = value;
    self.value.hidden = !value.length;

    if ([[specifier propertyForKey:SCIPanelRowBusyKey] boolValue]) [self.spinner startAnimating]; else [self.spinner stopAnimating];

    // A row that cannot act is drawn quieter, not removed.
    CGFloat alpha = enabled ? 1 : 0.55;
    self.tile.alpha = alpha;
    self.title.alpha = alpha;
    self.subtitle.alpha = enabled ? 1 : 0.85;
    [cell setNeedsLayout];
}

- (void)layout {
    UIView *content = self.cell.contentView;
    CGFloat W = content.bounds.size.width, H = content.bounds.size.height;
    if (W <= 0 || H <= 0) return;

    const CGFloat lead = 16, gap = 14;
    // The text always starts after a full-size slot, and a smaller tile (the About rows) is centred in it, so every row's text lines up.
    CGFloat slot = SCIPanelTileSide;
    CGFloat side = self.tile.image ? MIN(self.tile.image.size.width, slot) : slot;
    CGFloat textX = lead + slot + gap;
    CGFloat tail = self.value.hidden ? 12 : 20;

    self.tile.frame = CGRectMake(lead + floor((slot - side) / 2), floor((H - side) / 2), side, side);

    CGFloat valueWidth = 0;
    if (!self.value.hidden) {
        valueWidth = MIN(ceil([self.value sizeThatFits:CGSizeMake(W, H)].width), W * 0.45);
        self.value.frame = CGRectMake(W - tail - valueWidth, floor((H - 22) / 2), valueWidth, 22);
    }
    CGFloat spinnerWidth = 0;
    if (self.spinner.isAnimating) {
        spinnerWidth = 20;
        self.spinner.frame = CGRectMake(W - tail - 20, floor((H - 20) / 2), 20, 20);
    }

    CGFloat textWidth = MAX(W - textX - tail - valueWidth - spinnerWidth - (valueWidth ? 8 : 0), 0);
    if (self.subtitle.hidden) {
        self.title.frame = CGRectMake(textX, floor((H - 22) / 2), textWidth, 22);
    } else {
        CGFloat pair = 22 + 2 + 17;
        CGFloat top = floor((H - pair) / 2);
        self.title.frame = CGRectMake(textX, top, textWidth, 22);
        self.subtitle.frame = CGRectMake(textX, top + 24, textWidth, 17);
    }

    // Mirrored once, for a right-to-left phone: the frames above are left-to-right.
    if (self.cell.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft) {
        for (UIView *view in @[self.tile, self.title, self.subtitle, self.value, self.spinner]) {
            CGRect frame = view.frame;
            frame.origin.x = W - CGRectGetMaxX(frame);
            view.frame = frame;
        }
        self.title.textAlignment = NSTextAlignmentRight;
        self.subtitle.textAlignment = NSTextAlignmentRight;
        self.value.textAlignment = NSTextAlignmentLeft;
    } else {
        self.title.textAlignment = NSTextAlignmentLeft;
        self.subtitle.textAlignment = NSTextAlignmentLeft;
        self.value.textAlignment = NSTextAlignmentRight;
    }
}

@end


@implementation SCIPanelRowCell {
    SCIPanelRowBody *_body;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    if (!(self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier])) return nil;
    _body = [[SCIPanelRowBody alloc] initWithCell:self];
    return self;
}

- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
    [super refreshCellContentsWithSpecifier:specifier];
    [_body applySpecifier:specifier enabled:[[specifier propertyForKey:@"enabled"] ?: @YES boolValue]];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [_body layout];
}

@end


@implementation SCIPanelSwitchRowCell {
    SCIPanelRowBody *_body;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    if (!(self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier])) return nil;
    _body = [[SCIPanelRowBody alloc] initWithCell:self];
    return self;
}

- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
    [super refreshCellContentsWithSpecifier:specifier];
    [_body applySpecifier:specifier enabled:[[specifier propertyForKey:@"enabled"] ?: @YES boolValue]];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [_body layout];
}

@end
