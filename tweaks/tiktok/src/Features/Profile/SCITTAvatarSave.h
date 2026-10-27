//
//  SCITTAvatarSave.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// A Save button on the screen TikTok opens when somebody taps a profile picture. Installed only where `TTKEnlargeAvatarViewController`
/// declares `-configWithUserModel:` and `-viewDidAppear:` with the encodings it was written against.
void SCITTInstallAvatarSave(void);

/// What installed, how many screens got the button, and how many saves were asked and with how many links.
NSString *SCITTAvatarSaveReport(void);
