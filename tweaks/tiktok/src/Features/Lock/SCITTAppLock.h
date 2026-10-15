//
//  SCITTAppLock.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// Observes the app leaving and returning. Safe to call once; the switch is read on every event.
void SCITTInstallAppLock(void);

NSString *SCITTAppLockReport(void);
