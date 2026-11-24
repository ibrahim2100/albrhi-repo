//
//  SCITTButtonStyle.h
//  Albrhi for TikTok
//
//  The designs the download button can wear, chosen in Settings › Download.
//
//  **Drawn here, never borrowed.** TikTok's rail is solid white glyphs with no disc behind them, so every design is a solid white shape drawn from
//  paths (a stroke or a fill with the arrow cut out of it) -- the same material as the icons around it, which is what "as if it came native" asks.
//  They are drawn with Core Graphics only, so the shape of each can be measured on the build machine (`tests/host/run.sh`) and so no design depends
//  on which SF Symbols an iOS version carries (the owner's phone is 16.1).
//
//  The first design (`mark`) is the one the button always had and is the default: choosing it removes the key.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

/// How many designs there are. The first is the default.
NSUInteger SCITTButtonStyleCount(void);

/// The stored value for a design (`@"mark"`, `@"arrow"`, …) and the key of its name in the localisation table.
NSString *SCITTButtonStyleID(NSUInteger index);
NSString *SCITTButtonStyleNameKey(NSUInteger index);

/// The design a stored value names; 0 (the default) for nothing stored or a value this build does not know, so an old preference can never leave the
/// button without a glyph.
NSUInteger SCITTButtonStyleIndexForID(NSString *_Nullable identifier);

/// Draws design `index` into a `side` x `side` square at the origin of `context`, in whatever colour is already set as the fill and stroke colour.
/// Cut-outs are made with the clear blend mode, so the context must have an alpha channel. Draws nothing for an index out of range.
void SCITTButtonStyleDraw(NSUInteger index, CGContextRef context, CGFloat side);

/// The text under the button: 0 the tool's name, 1 the word "Download", 2 nothing.
typedef NS_ENUM(NSUInteger, SCITTButtonLabelMode) {
    SCITTButtonLabelName = 0,
    SCITTButtonLabelWord = 1,
    SCITTButtonLabelNone = 2,
};
SCITTButtonLabelMode SCITTButtonLabelModeForID(NSString *_Nullable identifier);

NS_ASSUME_NONNULL_END

#if __has_include(<UIKit/UIKit.h>)
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Design `index` as an image `side` points wide in `color`.
UIImage *SCITTButtonStyleImage(NSUInteger index, CGFloat side, UIColor *color);

/// The same as a template image, for a settings row (the row's own tint colours it, so it follows light and dark).
UIImage *SCITTButtonStylePreview(NSUInteger index, CGFloat side);

/// What is chosen now, read from the preferences.
NSUInteger SCITTButtonStyleCurrent(void);
SCITTButtonLabelMode SCITTButtonLabelCurrent(void);

NS_ASSUME_NONNULL_END
#endif
