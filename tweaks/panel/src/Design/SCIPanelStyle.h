//
//  SCIPanelStyle.h
//  Albrhi Panel
//
//  The panel's own look: one palette, one tile language, one set of marks.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// The side of the rounded tile every row starts with.
extern const CGFloat SCIPanelTileSide;

/// The panel's two accents. The orange is the mark's own; the indigo is the hero's.
UIColor *SCIPanelOrange(void);
UIColor *SCIPanelIndigo(void);

/// A title font in the rounded system design where the device has it -- the one choice that makes the page read as Albrhi's own and not as a
/// stock Settings list.
UIFont *SCIPanelRoundedFont(CGFloat size, UIFontWeight weight);

/// **The icon of an app, whether or not the app is installed.**
///
/// The app's own icon, scaled to a tile, when the phone gave one. When it did not (the app is not installed, or the private call that reads
/// icons is gone) a tile **drawn here**: the brand's own colours and a simple mark in the same rounded-square shape. They are stand-ins, not the
/// apps' artwork -- nothing of another company's is shipped inside this package -- and they exist so that a row never has a hole where a picture
/// was promised, nor a different size from its neighbours.
UIImage *SCIPanelAppTile(NSString *bundleIdentifier, UIImage *_Nullable realIcon, CGFloat side);

/// A tile with an SF Symbol on a gradient, for the rows that are not apps.
UIImage *SCIPanelSymbolTile(NSString *symbolName, UIColor *top, UIColor *bottom, CGFloat side);

/// The colour pair a tool's tile uses, by what it is.
void SCIPanelTonesForGroup(NSString *groupIdentifier, NSString *_Nullable *_Nonnull symbol, UIColor *_Nullable *_Nonnull top, UIColor *_Nullable *_Nonnull bottom);

@class SCIPanelEntry;

/// The apps this panel knows by their bundle identifier (the Spotify group identifier included): these are listed with the apps even when their
/// tweak owns a settings page.
BOOL SCIPanelIsKnownApp(NSString *identifier);

/// The tile for one scanned entry: an app's own icon when the phone really gave one, the drawn stand-in when it did not, and a symbol tile for
/// a tweak that runs across apps. The system returns a generic "no icon" picture for an app it does not know instead of nil, so a non-nil
/// answer is compared with that placeholder before it is believed.
UIImage *SCIPanelTileForEntry(SCIPanelEntry *entry, CGFloat side);

NS_ASSUME_NONNULL_END
