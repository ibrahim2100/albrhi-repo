//
//  SCITWCounts.h
//  Albrhi for X
//
//  Numbers X rounds, shown whole -- and two it does not show at all.
//
//  A post's quote and repost counts are not on the post: they are behind "View post
//  interactions", and X shows neither as a number anywhere you can read without tapping into
//  each list. The title of that screen is the one place there is room for them. Follower,
//  following and post counts are shown abbreviated ("12.4K"), and the exact number is
//  something people look at their own profile for.
//
//  Taken from NeoFreeBird (orionblur, GPLv3, `src/Hooks/PostInteractions.x` and `Profile.x`),
//  with one change that matters on this phone: its title was English only. It is localised here.
//
//  Every hook is attached only when the class answers the selector with the encoding it is
//  hooked with, and each counts what it did.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NSString *SCITWCountsReport(void);
void SCITWInstallCounts(void);
