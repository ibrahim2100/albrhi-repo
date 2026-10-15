//
//  SCITTFeedFilters.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// Installs the four small answers in this file's group, each only where its class and selectors exist with the encoding they were
/// written against: suggested accounts, "Follows you", longer comments, closed comments.
void SCITTInstallFeedFilters(void);

/// A feed model that is a LIVE item or a suggested-account card, when the matching switch is on. Used by the ad filter, which is where models are built.
BOOL SCITTModelIsFilteredOut(id model);

NSString *SCITTFeedFiltersReport(void);
