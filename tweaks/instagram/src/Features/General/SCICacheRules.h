//
//  SCICacheRules.h
//  Albrhi for Instagram
//
//  What "clean the cache" must never touch.
//
//  This tweak keeps its own files in the app's Caches folder, beside Instagram's: the download
//  history (`albrhi-downloads.plist`) and every finished download, named `<UUID>.<extension>`.
//  A cache cleaner that emptied the folder would delete what somebody saved, which is the one
//  thing a switch must not do (CLAUDE.md §2). So the cleaner asks this first, and keeps
//  whatever answers YES. Pure Foundation, so `tests/host` can run it.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// YES for a top-level Caches entry that belongs to this tweak and must be kept.
BOOL SCICacheNameIsOurs(NSString *name);

/// An entry modified this recently is probably in use (a download being written, a video being
/// played) and is skipped whatever it is.
extern const NSTimeInterval SCICacheRecentlyUsedSeconds;

NS_ASSUME_NONNULL_END
