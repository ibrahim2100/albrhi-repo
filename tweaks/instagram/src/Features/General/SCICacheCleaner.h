//
//  SCICacheCleaner.h
//  Albrhi for Instagram
//
//  "Clean cache": Instagram's thumbnails, web caches and temporary files, measured first and
//  removed only after the person has seen the size and said yes. What is kept is decided by
//  SCICacheRules.h -- the downloads and their history are never in the count.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCICacheCleaner : NSObject

/// Bytes a clean would free right now. Walks the folder: call it off the main thread.
+ (unsigned long long)reclaimableBytes;

/// Removes it. Returns the bytes freed; `failures` counts entries that could not be removed.
+ (unsigned long long)cleanCountingFailures:(NSUInteger *_Nullable)failures;

/// The whole interaction for a settings row: measure, ask, clean, report. Safe from any thread.
+ (void)presentCleanFlow;

@end

NS_ASSUME_NONNULL_END
