//
//  SCIKeychain.h
//  Albrhi for Instagram
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// For an Instagram that was re-signed (sideloaded): asks the keychain again, in the app's own access group, when it refuses a request for a group
/// the new signature does not hold. Installed only in the standalone build; does nothing to a call the keychain accepts.
void SCIKeychainInstall(void);

/// What the keychain answered this launch, call by call: how many requests, how many were refused for entitlement, how many were asked again and
/// how many of those worked, the app's own default group and the last group that was refused.
NSArray<NSString *> *SCIKeychainReportLines(void);
