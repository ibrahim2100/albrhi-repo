//
//  SCITTComments.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// Turn on two features TikTok's own comment panel already contains and keeps behind server-side switches: the comment search icon and the
/// "translate all comments" button. Nothing is built here; the app's own code draws and runs both, and whether the server then answers
/// for this account is TikTok's.
void SCITTInstallComments(void);

/// What installed, what stood down and why, and how often each question was asked and how often the answer was changed.
NSString *SCITTCommentsReport(void);
