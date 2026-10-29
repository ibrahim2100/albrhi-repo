//
//  SCITTCache.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Posted on the main queue when the measured size or the last cleaning changes, so an open settings page can redraw its note.
extern NSNotificationName const SCITTCacheDidChange;

/// Reads the "clean at launch" choice and, when it asks for it, starts one cleaning pass in the background.
/// Call once, from the constructor, after the per-app gate.
void SCITTInstallCache(void);

/// Measures `Library/Caches` and `tmp` off the main thread (at most once every ten seconds) and posts `SCITTCacheDidChange`.
void SCITTCacheRefreshSize(void);

/// "Caches 1.2 GB · temporary 8 MB", or "Measuring…" until the first measurement lands. Cheap: never touches the disk.
NSString *SCITTCacheSummary(void);

/// Cleans now: everything in `Library/Caches` and `tmp` that was not written in the last twenty seconds. `done` gets the bytes freed, on the main queue.
void SCITTCacheClearNow(void (^_Nullable done)(unsigned long long freed));

/// The choice, what the last pass did and how long it took, for the Status screen.
NSString *SCITTCacheReport(void);

NS_ASSUME_NONNULL_END
