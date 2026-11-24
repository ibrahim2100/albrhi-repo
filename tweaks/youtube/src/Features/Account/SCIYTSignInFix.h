//
//  SCIYTSignInFix.h
//  Albrhi for YouTube
//
//  Signing in to Google from a copy of YouTube that was installed as an IPA and signed by somebody who is not Google.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// What the repair saw and did, for the diagnostics page: whose signature this copy carries, where the sign-in library keeps its keychain items,
/// and how many times each repair ran. Key names and counts only -- never a value, a token or an address.
NSString *SCIYTSignInReport(void);
