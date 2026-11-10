//
//  SCICard.h
//  Albrhi -- shared
//
//  A small message card of our own, drawn in a window of our own.
//
//  **Why not UIAlertController.** In TikTok on an Arabic account every system controller presented over the app comes out mirrored (glyphs
//  reversed -- the Files sheet, the Reminders sheet, a plain alert; measured in the simulator with stock TikTok, no tweak involved). Labels and buttons on
//  a view of ours are not touched by that, so anything Albrhi has to *say* is said on this card. Vertical layout only, so left-to-right and
//  right-to-left cannot reorder a thing.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Shows the card. `buttons` are titles top to bottom; `primary` is the one drawn filled (or -1); `chosen` gets the index tapped and the card is
/// already gone when it runs (so it may show another). Returns NO when there is no scene to show it in yet.
FOUNDATION_EXPORT BOOL SCICardShow(NSString *title, NSString *_Nullable message, NSArray<NSString *> *buttons, NSInteger primary,
                                   void (^_Nullable chosen)(NSInteger index));

/// Whether a card is on screen.
FOUNDATION_EXPORT BOOL SCICardIsShowing(void);

/// True when the system language is Arabic (the cards of Albrhi speak Arabic then, English otherwise).
FOUNDATION_EXPORT BOOL SCICardArabic(void);

NS_ASSUME_NONNULL_END
