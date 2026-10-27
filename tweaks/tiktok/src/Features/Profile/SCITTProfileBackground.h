//
//  SCITTProfileBackground.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// Opens TikTok's own profile-background editor, which is in the binary and shipped switched off.
///
/// Two small things, each installed only where the build declares the class and selector with the expected type
/// encoding: the experiment flag that says this device is in the test group, and a stand-in for the profile's
/// background component while the editor looks for it. Nothing here draws, uploads or stores a background.
void SCITTInstallProfileBackground(void);

/// What installed, what stood down and why, and how many times each of the two answered.
NSString *SCITTProfileBackgroundReport(void);
