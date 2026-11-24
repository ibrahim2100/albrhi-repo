//
//  SCIYTPush.h
//  Albrhi for YouTube
//
//  Why a copy installed as an IPA gets no notifications -- read off the copy itself.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// What this copy is signed with (its own `application-identifier` and `aps-environment`, read from the running process), what iOS answered when the app
/// asked to register for push, and the permission the person gave -- then one sentence saying which of the three explains missing notifications.
/// Read-only: nothing here asks iOS to register, changes a setting or sends anything anywhere.
NSString *SCIYTPushReport(void);
