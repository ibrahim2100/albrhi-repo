//
//  SCIYTWindow.h
//  Albrhi for YouTube
//
//  The app's key window and the view controller on top of it, found in one place.
//
//  This lookup had been written out ten times in this tweak, each a little different (one
//  walked scenes, two the legacy `-windows`, one skipped a controller being dismissed), and a
//  fix to one -- a presenter that must not land on a sheet on its way out -- reached none of
//  the others. `tools/check.py` (rule 25) now fails a second copy of the walk in a tweak that
//  has this helper.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

/// The key window: the scenes' first, then the legacy `-windows` list. Nil before any exists.
UIWindow *SCIYTKeyWindow(void);

/// The key window's root view controller, or nil.
UIViewController *SCIYTRootViewController(void);

/// The controller a new sheet should be presented from: the root, followed down through
/// whatever it is presenting, skipping one that is being dismissed. Nil when there is no window.
UIViewController *SCIYTTopViewController(void);
