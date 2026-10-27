//
//  SCITTButton.h
//  Albrhi for TikTok
//
//  The download button in the feed itself, not only a list to come back to later.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

/// Whether a hold began on one of this tweak's download buttons (or something inside one), and if so opens the copy menu for the video it
/// belongs to. Asked by the window's touch follower (`SCITTHold.x`); NO when the switch is off or the view is not one of ours.
BOOL SCITTCopyHoldOnDownloadButton(UIView *hit);

/// Hooks the feed cell and its interaction rail so a download button sits beside
/// like, comment and share on the video that is actually on screen. Safe to call
/// unconditionally.
void SCITTInstallButton(void);

/// Which rail actually attached, and how many buttons have been placed -- for the
/// status screen's own report.
NSString *SCITTButtonReport(void);

/// Where the publish date stopped, stage by stage: reached, switched off, no date on the item, or
/// drawn — and the last one drawn. "It did not appear" is four different faults and one sentence.
NSString *SCITTDateReport(void);
