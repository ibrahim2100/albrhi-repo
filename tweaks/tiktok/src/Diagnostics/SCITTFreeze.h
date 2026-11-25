//
//  SCITTFreeze.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// Starts the freeze watchdog: a background timer asks the main thread once a second to answer, and when it has not answered for three seconds
/// while the app is in front it records where the main thread is standing (a few stack samples, read without running any code on it) and which
/// views the last touches landed on. Nothing is written unless a stall lasts five seconds or taps look dead.
void SCITTInstallFreeze(void);

/// What the watchdog has seen this launch, and the evidence file the previous launch left, if any.
NSString *SCITTFreezeReport(void);
