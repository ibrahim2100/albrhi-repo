//
//  SCITTCopyMenu.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// A dropdown that opens beside the download button and lets the person copy one thing about the video at a time: the video's link, its
/// caption, the sound's link, the account's name, its bio, its profile link. **Each row copies exactly what it says and nothing else**, and
/// shows under its title the text it will copy, so a wrong value is visible before it is chosen.
///
/// Reads only what the model already holds (accessors that answer with an object); nothing is fetched and nothing is sent. A row with
/// nothing behind it is not drawn. `anchor` is the button the menu hangs from.
void SCITTShowCopyMenu(id _Nullable awemeModel, UIView *_Nullable anchor);

/// How many menus were asked for, how many had anything to offer, how many rows were copied, and where the last links came from.
NSString *SCITTCopyReport(void);

NS_ASSUME_NONNULL_END
