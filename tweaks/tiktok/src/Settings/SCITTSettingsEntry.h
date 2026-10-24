//
//  SCITTSettingsEntry.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// A row at the top of TikTok's own Settings screen that opens Albrhi's. The two-finger hold stays.
void SCITTInstallSettingsEntry(void);

NSString *SCITTSettingsEntryReport(void);

/// YES once the row hook is attached. The two-finger hold opens the settings regardless of its switch while this is NO,
/// so a build where the row cannot be installed still has a way in.
BOOL SCITTSettingsEntryInstalled(void);
