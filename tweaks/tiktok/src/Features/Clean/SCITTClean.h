//
//  SCITTClean.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// Six switches, each refusing one question TikTok's own code asks: the feed surveys, Tako (TikTok's AI assistant) in the feed, the search
/// page and the comments, the floating promotion badges, the bulletin-board cards, and the sensitive-content overlay. Each gate is installed
/// only where the build declares the class and the selector with the encoding it was written against, and each decides on its own.
void SCITTInstallClean(void);

/// What installed, what stood down and why, and how many times each switch refused.
NSString *SCITTCleanReport(void);
