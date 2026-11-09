//
//  SCITTRecalledStore.m
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCITTRecalledStore.h"

static const NSUInteger kSCITTRecalledContentLimit = 16 * 1024;
static const NSTimeInterval kSCITTRecalledDebounce = 2.0;

@implementation SCITTRecalledStore {
    NSString *_path;
    NSUInteger _limit;
    NSMutableDictionary<NSString *, NSDictionary *> *_items;
    NSMutableArray<NSString *> *_order;   // oldest first
    BOOL _dirty;
    BOOL _writeScheduled;
    dispatch_queue_t _queue;
}

+ (instancetype)shared {
    static SCITTRecalledStore *store;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *base = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject
                         ?: NSTemporaryDirectory();
        store = [[SCITTRecalledStore alloc] initWithPath:[base stringByAppendingPathComponent:@"AlbrhiTikTok/recalled.plist"]
                                                   limit:500];
    });
    return store;
}

- (instancetype)initWithPath:(NSString *)path limit:(NSUInteger)limit {
    if (!(self = [super init])) return nil;
    _path = [path copy];
    _limit = MAX((NSUInteger)1, limit);
    _items = [NSMutableDictionary dictionary];
    _order = [NSMutableArray array];
    _queue = dispatch_queue_create("com.albrhi.tiktok.recalled", DISPATCH_QUEUE_SERIAL);
    [self load];
    return self;
}

/// TikTok's id is an NSNumber (`TIMOMessage`) or a long long (`AWEIMMessage`); both end as the same decimal string.
static NSString *SCITTKeyFor(id identifier) {
    if ([identifier isKindOfClass:[NSNumber class]]) return [(NSNumber *)identifier stringValue];
    if ([identifier isKindOfClass:[NSString class]] && [(NSString *)identifier length]) return identifier;
    return nil;
}

- (void)load {
    NSDictionary *file = [NSDictionary dictionaryWithContentsOfFile:_path];
    if (![file isKindOfClass:[NSDictionary class]]) return;
    NSDictionary *items = file[@"items"];
    NSArray *order = file[@"order"];
    if (![items isKindOfClass:[NSDictionary class]] || ![order isKindOfClass:[NSArray class]]) return;
    for (id key in order) {
        if (![key isKindOfClass:[NSString class]]) continue;
        NSDictionary *entry = items[key];
        if (![entry isKindOfClass:[NSDictionary class]]) continue;
        _items[key] = entry;
        [_order addObject:key];
    }
    while (_order.count > _limit) {
        [_items removeObjectForKey:_order.firstObject];
        [_order removeObjectAtIndex:0];
    }
}

- (BOOL)isTracked:(id)serverMessageID {
    NSString *key = SCITTKeyFor(serverMessageID);
    if (!key) return NO;
    @synchronized (self) { return _items[key] != nil; }
}

- (id)contentFor:(id)serverMessageID {
    NSString *key = SCITTKeyFor(serverMessageID);
    if (!key) return nil;
    @synchronized (self) { return _items[key][@"content"]; }
}

- (NSUInteger)count {
    @synchronized (self) { return _items.count; }
}

/// A value that can be written to a property list and is not large. Anything else is not stored: the message is still marked.
static BOOL SCITTStorable(id content) {
    if (!content) return NO;
    if (![NSPropertyListSerialization propertyList:content isValidForFormat:NSPropertyListBinaryFormat_v1_0]) return NO;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:content format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
    return data && data.length <= kSCITTRecalledContentLimit;
}

static BOOL SCITTHasContent(id content) {
    if ([content respondsToSelector:@selector(count)]) return [(id)content count] > 0;
    if ([content respondsToSelector:@selector(length)]) return [(id)content length] > 0;
    return content != nil;
}

- (BOOL)track:(id)serverMessageID content:(id)content {
    NSString *key = SCITTKeyFor(serverMessageID);
    if (!key) return NO;

    BOOL keepContent = SCITTHasContent(content) && SCITTStorable(content);

    @synchronized (self) {
        NSDictionary *existing = _items[key];
        if (existing) {
            // Known already. The only change worth a write is content arriving for an id that had none.
            if (!keepContent || existing[@"content"]) return NO;
            NSMutableDictionary *merged = [existing mutableCopy];
            merged[@"content"] = content;
            _items[key] = merged;
            _dirty = YES;
            [self scheduleWrite];
            return NO;
        }

        NSMutableDictionary *entry = [NSMutableDictionary dictionaryWithObject:[NSDate date] forKey:@"date"];
        if (keepContent) entry[@"content"] = content;
        _items[key] = entry;
        [_order addObject:key];
        while (_order.count > _limit) {
            [_items removeObjectForKey:_order.firstObject];
            [_order removeObjectAtIndex:0];
        }
        _dirty = YES;
        [self scheduleWrite];
        return YES;
    }
}

- (void)forget:(id)serverMessageID {
    NSString *key = SCITTKeyFor(serverMessageID);
    if (!key) return;
    @synchronized (self) {
        if (!_items[key]) return;
        [_items removeObjectForKey:key];
        [_order removeObject:key];
        _dirty = YES;
        [self scheduleWrite];
    }
}

/// Called with the lock held. One write per burst: the recall getter can be asked many times in a second.
- (void)scheduleWrite {
    if (_writeScheduled) return;
    _writeScheduled = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kSCITTRecalledDebounce * NSEC_PER_SEC)), _queue, ^{
        [self flush];
    });
}

- (void)flush {
    NSDictionary *snapshot = nil;
    @synchronized (self) {
        _writeScheduled = NO;
        if (!_dirty) return;
        _dirty = NO;
        snapshot = @{ @"v": @1, @"order": [_order copy], @"items": [_items copy] };
    }
    NSString *folder = [_path stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
    // Atomic: a write that is cut short (the app is killed) leaves the previous file, never half of a new one.
    [snapshot writeToFile:_path atomically:YES];
}

@end
