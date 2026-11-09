//
//  SCIPanelCells.h
//  Albrhi Panel
//
//  The panel's two row kinds, both drawn by hand.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Preferences/PSTableCell.h>
#import <Preferences/PSSwitchTableCell.h>

NS_ASSUME_NONNULL_BEGIN

/// The keys a cell reads off its specifier. Set by the controller when it builds the row.
extern NSString *const SCIPanelRowTileKey;       // UIImage: the 44-point tile at the start
extern NSString *const SCIPanelRowSubtitleKey;   // NSString: the second line
extern NSString *const SCIPanelRowToneKey;       // NSNumber (SCIPanelTone): the colour of the second line
extern NSString *const SCIPanelRowValueKey;      // NSString: a value at the end (version, author)
extern NSString *const SCIPanelRowDestructiveKey;// NSNumber BOOL: the title is red
extern NSString *const SCIPanelRowBusyKey;       // NSNumber BOOL: a spinner at the end

typedef NS_ENUM(NSInteger, SCIPanelTone) { SCIPanelToneQuiet = 0, SCIPanelToneCaution, SCIPanelToneGood, SCIPanelToneBad };

/// A row that is not a switch: a tile, a title, an optional second line, an optional value, and the system's own disclosure or nothing.
@interface SCIPanelRowCell : PSTableCell
@end

/// The same row with the system's switch at the end. The switch, its wiring and its enabled state are `PSSwitchTableCell`'s own and are left to it.
@interface SCIPanelSwitchRowCell : PSSwitchTableCell
@end

NS_ASSUME_NONNULL_END
