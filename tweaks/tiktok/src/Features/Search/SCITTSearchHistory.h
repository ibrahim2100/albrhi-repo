//
//  SCITTSearchHistory.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// Hide the search history: what TikTok's search page is *told* about the history is emptied, and what TikTok keeps is not touched.
void SCITTInstallSearchHistory(void);

/// What installed, what stood down and why, and how many times a read was answered with nothing.
NSString *SCITTSearchHistoryReport(void);
