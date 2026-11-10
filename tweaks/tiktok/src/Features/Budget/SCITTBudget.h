//
//  SCITTBudget.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// A daily limit on videos and minutes, asked on a card (shared/src/SCIWatchBudget). Installed only when one of the two limits is chosen.
void SCITTInstallBudget(void);

NSString *SCITTBudgetReport(void);
