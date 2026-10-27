//
//  SCITTHold.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// Follows a single finger held for half a second from `-[UIWindow sendEvent:]` and decides what the hold was on: one of this tweak's
/// download buttons (the copy menu), or text on a profile (copied). Does nothing while the "Hold to copy" switch is off.
void SCITTInstallHold(void);

/// Holds begun, what each landed on, and -- for the last one that matched nothing -- the class chain under the finger, so a miss names itself.
NSString *SCITTHoldReport(void);
