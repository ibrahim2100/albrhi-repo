//
//  SCITTCopyMenu.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Offers to copy what the video's own model already holds -- the account's name and bio, the sound's link, the post's link and text --
/// on the tweak's own sheet. Reads accessors only where the object answers them with an object (`@`) return; **nothing is fetched** and
/// nothing is sent anywhere. Rows with nothing behind them are not drawn. Called from a long press on the download button.
void SCITTShowCopyMenu(id _Nullable awemeModel);

/// How many menus were asked for, how many had anything to offer, and how many rows were copied.
NSString *SCITTCopyReport(void);

NS_ASSUME_NONNULL_END
