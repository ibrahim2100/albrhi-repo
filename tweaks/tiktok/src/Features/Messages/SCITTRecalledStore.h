//
//  SCITTRecalledStore.h
//  Albrhi for TikTok
//
//  The direct messages whose sender took them back, kept so they survive the app being closed.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

///
/// **Why this is a file and not a set in memory.** Until 0.29.0 the ids of recalled messages lived in an in-memory set, so a message
/// stayed visible *for that launch*: the next one loaded it from TikTok's own store as recalled again, with whatever TikTok left of its
/// content, and the mark on it was gone with the set. VibeTok keeps a plist keyed by the message's server id and hands the stored content
/// back; this does the same, written from scratch, and adds what that one lacks: a ceiling, a debounce and atomic writes.
///
/// One entry is `{date, content}` under the message's `serverMessageID`. `content` is whatever TikTok's content dictionary held at the moment
/// of the recall **if it can be stored as a property list and is under 16 KB**; otherwise the id is still kept (the message is still
/// *marked*) and the content is simply not. The newest `limit` entries are kept; a log that grows without limit inside somebody's app is
/// the thing this project switched off in NextUp.
///
/// Pure Foundation and no TikTok class, so it has a host test (`tests/host`).
///
@interface SCITTRecalledStore : NSObject

+ (instancetype)shared;

/// `path` is where the plist lives (its folder is created); `limit` is the most entries kept. A unit test passes its own.
- (instancetype)initWithPath:(NSString *)path limit:(NSUInteger)limit;

- (BOOL)isTracked:(nullable id)serverMessageID;

/// The content kept for that id, or nil (never stored, not storable, or tracked by id alone).
- (nullable id)contentFor:(nullable id)serverMessageID;

/// Remembers a message. A nil or empty `content` never replaces content already kept for the same id. Returns YES when the id was new.
/// Cheap for an id already known: the recall getter calls this on every read.
- (BOOL)track:(nullable id)serverMessageID content:(nullable id)content;

- (void)forget:(nullable id)serverMessageID;

@property (nonatomic, readonly) NSUInteger count;

/// Writes now, on the calling thread. The store otherwise writes by itself, two seconds after the last change.
- (void)flush;

@end

NS_ASSUME_NONNULL_END
