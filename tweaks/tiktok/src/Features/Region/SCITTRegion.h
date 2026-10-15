//
//  SCITTRegion.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// Installs the region answers, each group only where its class and selectors exist with the expected encoding.
void SCITTInstallRegion(void);

/// What installed, what stood down and why, and how many questions were answered with the chosen country.
NSString *SCITTRegionReport(void);
