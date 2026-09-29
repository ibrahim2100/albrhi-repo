//
//  NUAlbrhi.m
//  Albrhi NextUp
//
//  What this port adds to upstream, kept in one file so the rest of the tree stays a
//  clean copy of NextUp 3 and can still be diffed against it.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//  Ported from NextUp 3 by Yves (github.com/Yves000/NextUp3), also GPLv3.
//

#import <Foundation/Foundation.h>

/// The version this build was made from, kept in step with `control` by tools/check.py.
///
/// Upstream has no equivalent — it reads its version from the package alone — so this is
/// the port's own, and it tracks the *port's* number rather than NextUp 3's. The
/// CHANGELOG records which upstream release each one is built from, which is the number
/// that actually matters when comparing behaviour against Yves's repository.
NSString *SCIVersionString = @"v0.3.0";  // AlbrhiNU
