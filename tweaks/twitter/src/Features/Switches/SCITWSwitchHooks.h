//
//  SCITWSwitchHooks.h
//  Albrhi for Twitter
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// Hooks whichever of X's three switch providers this build actually has, and records
/// which. Safe to call when none of them exist: it attaches nothing and says so in the
/// diagnostics report rather than failing.
///
/// Called once, from the constructor, after the panel switch has been consulted.
void SCITWInstallSwitchHooks(void);

/// Which of the typed-getter groups and the wrapper attached, and which did not and why.
NSString *SCITWSwitchHooksReport(void);
