//
//  SCITTBrowse.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// Seven small answers to questions TikTok's own code asks, each behind its own switch and installed only where the build declares the class
/// and the selector with the encoding it was written against: links in Safari, the warning label, the TikBot button, a muted video's sound,
/// advancing at the end of a video, starting on Following and the bio's length. Each decides on its own, so a build missing one class costs
/// that feature and no other.
void SCITTInstallBrowse(void);

/// What installed, what stood down and why, and how many times each one answered.
NSString *SCITTBrowseReport(void);
