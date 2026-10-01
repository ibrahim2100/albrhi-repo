#import "SCIUnsentLog.h"
#import <objc/runtime.h>
#import "../../Utils.h"
#import "shared/src/SCIKVC.h"
#import "../../Localization/SCILocalize.h"
#import "../../Settings/SCIDiagnosticsViewController.h"

NSString * const SCIUnsentLogDidChangeNotification = @"SCIUnsentLogDidChange";

// Bounds, because a record that grows without limit is a cost somebody pays for a long time
// before they notice, and a file nobody can read is worth nothing.
static const NSUInteger kSCICacheLimit = 2500;       // messages remembered in memory
static const NSUInteger kSCILogLimit = 600;          // rows kept on disk
static const NSUInteger kSCILogByteLimit = 768 * 1024;
static const NSUInteger kSCITextLimit = 3000;        // characters kept of one message

// Entry keys.
static NSString * const kID      = @"id";        // the message's server id -- also the dedupe key
static NSString * const kClient  = @"client";
static NSString * const kSender  = @"sender";    // participant id
static NSString * const kName    = @"name";      // username when it was learned in time
static NSString * const kSent    = @"sent";      // seconds since 1970, 0 when unknown
static NSString * const kDeleted = @"deleted";
static NSString * const kKind    = @"kind";      // Text, Photo, Link, ...
static NSString * const kText    = @"text";
static NSString * const kThread  = @"thread";
static NSString * const kHeld    = @"captured";  // YES when the content was found

static NSObject *sLock;
static NSMutableDictionary<NSString *, NSDictionary *> *sCache;   // server/client id -> record
static NSMutableArray<NSString *> *sCacheOrder;
static NSMutableDictionary<NSString *, NSString *> *sNames;       // participant id -> username
static NSMutableArray<NSDictionary *> *sEntries;                  // newest first
static BOOL sLoaded = NO;
static BOOL sWritePending = NO;
static NSString *sOwnPk = nil;

static dispatch_queue_t SCIUnsentQueue(void) {
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ queue = dispatch_queue_create("com.albrhi.unsentlog", DISPATCH_QUEUE_SERIAL); });
    return queue;
}

static NSString *SCIUnsentPath(void) {
    NSString *support = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
    return [[support stringByAppendingPathComponent:@"Albrhi"] stringByAppendingPathComponent:@"unsent-log.json"];
}

static NSString *SCIString(id value) {
    if ([value isKindOfClass:[NSString class]]) return [(NSString *)value length] ? value : nil;
    if ([value isKindOfClass:[NSNumber class]]) return [value stringValue];
    return nil;
}

@implementation SCIUnsentLog

+ (void)initialize {
    if (self != [SCIUnsentLog class]) return;
    sLock = [[NSObject alloc] init];
    sCache = [NSMutableDictionary dictionary];
    sCacheOrder = [NSMutableArray array];
    sNames = [NSMutableDictionary dictionary];
    sEntries = [NSMutableArray array];
}

// MARK: - Storage

+ (void)loadIfNeeded {
    @synchronized (sLock) {
        if (sLoaded) return;
        sLoaded = YES;

        NSData *data = [NSData dataWithContentsOfFile:SCIUnsentPath()];
        if (!data.length) return;

        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![json isKindOfClass:[NSArray class]]) return;

        for (id row in (NSArray *)json) {
            if ([row isKindOfClass:[NSDictionary class]] && SCIString(row[kID])) [sEntries addObject:row];
        }
    }
}

/// One write at a time, a couple of seconds after the last change: a burst of unsends is one
/// file write, and a write happens only because something changed.
+ (void)scheduleWrite {
    @synchronized (sLock) {
        if (sWritePending) return;
        sWritePending = YES;
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), SCIUnsentQueue(), ^{
        NSArray *snapshot;
        @synchronized (sLock) {
            sWritePending = NO;
            snapshot = [sEntries copy];
        }

        // Trimmed oldest-first until it fits. The ceiling is stated rather than hit silently:
        // the screen's footer says how many rows exist and the file never exceeds the limit.
        NSData *data = nil;
        NSMutableArray *rows = [snapshot mutableCopy];
        while (rows.count) {
            data = [NSJSONSerialization dataWithJSONObject:rows options:0 error:nil];
            if (data.length <= kSCILogByteLimit) break;
            [rows removeLastObject];   // newest first, so the last is the oldest
        }

        NSString *path = SCIUnsentPath();
        [[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent]
                                  withIntermediateDirectories:YES attributes:nil error:nil];
        if (!rows.count) {
            [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        } else {
            [data writeToFile:path options:NSDataWritingAtomic error:nil];
        }
    });
}

+ (void)changed {
    [self scheduleWrite];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:SCIUnsentLogDidChangeNotification object:nil];
    });
}

// MARK: - Learning

+ (NSString *)ownPk {
    if (sOwnPk) return sOwnPk;

    @try {
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (![window respondsToSelector:@selector(userSession)]) continue;
            id session = SCISafeValueForKey(window, @"userSession");
            id user = session ? SCISafeValueForKey(session, @"user") : nil;
            NSString *pk = user ? (SCIString(SCISafeValueForKey(user, @"pk")) ?: SCIString(SCISafeValueForKey(user, @"userID"))) : nil;
            if (pk) { sOwnPk = pk; return pk; }
        }
    } @catch (__unused id e) {}

    return nil;
}

+ (void)learnThreadMetadata:(id)metadata {
    if (!metadata) return;

    id users = SCISafeValueForKey(metadata, @"users");
    if (![users isKindOfClass:[NSArray class]]) return;

    NSUInteger learned = 0;
    for (id user in (NSArray *)users) {
        NSString *pk = SCIString(SCISafeValueForKey(user, @"pk")) ?: SCIString(SCISafeValueForKey(user, @"userID"));
        NSString *name = SCIString(SCISafeValueForKey(user, @"username"));
        if (!pk || !name) continue;

        @synchronized (sLock) {
            if (![sNames[pk] isEqualToString:name]) { sNames[pk] = name; learned++; }
        }
    }
    if (learned) [SCIDiagnostics privacyCount:@"Unsent log · participant names learned"];
}

// MARK: - Capture

static NSString *SCIKindOf(id message, id content) {
    // A published message (what the cache stores) keeps its payload in one variant object whose
    // fields are named for the case they carry; whichever is filled says what the message is.
    if (content) {
        static const struct { const char *field; NSString *kind; } cases[] = {
            { "text_string", @"Text" }, { "media", @"Media" }, { "reshare_attachment", @"Post" },
            { "link_linkContext", @"Link" }, { "xma", @"Share" }, { "pollMessage", @"Poll" },
            { "progressiveImage", @"Photo" }, { "threadActivity", @"Activity" },
        };
        for (size_t i = 0; i < sizeof(cases) / sizeof(cases[0]); i++) {
            if (SCISafeValueForKey(content, @(cases[i].field))) return cases[i].kind;
        }
    }

    NSString *name = NSStringFromClass(object_getClass(message));
    return [name hasPrefix:@"IGDirect"] ? [name substringFromIndex:8] : name;
}

+ (void)noteShapeOf:(id)message {
    // The class of what the update carries, and which of the fields this reads it answered --
    // once per class, so the first report says what the stream really holds instead of what the
    // metadata suggested it might.
    static NSMutableSet<NSString *> *seen;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ seen = [NSMutableSet set]; });

    NSString *cls = NSStringFromClass(object_getClass(message));
    @synchronized (seen) {
        if ([seen containsObject:cls] || seen.count >= 10) return;
        [seen addObject:cls];
    }

    id text = SCISafeValueForKey(message, @"text");
    id inner = SCISafeValueForKey(message, @"message");
    id metadata = inner ? SCISafeValueForKey(inner, @"metadata") : SCISafeValueForKey(message, @"metadata");
    id key = metadata ? SCISafeValueForKey(metadata, @"key") : nil;
    id content = SCISafeValueForKey(message, @"content");
    [SCIDiagnostics recordUnsendPath:@"insert element"
                              detail:[NSString stringWithFormat:@"%@ · text %@ · .message %@ · metadata %@ · key %@ · content %@",
                                      cls, text ? @"yes" : @"no", inner ? NSStringFromClass([inner class]) : @"no",
                                      metadata ? NSStringFromClass([metadata class]) : @"no",
                                      key ? NSStringFromClass([key class]) : @"no",
                                      content ? NSStringFromClass([content class]) : @"no"]];
}

+ (void)captureMessage:(id)message {
    if (!message) return;

    // Two shapes are understood and the first report says which one arrives: a typed message
    // (`IGDirectText` ... -- `.text` and `.message`, the generated `IGDirectUIMessage` that holds
    // the metadata), or the generated message itself (`.metadata`).
    id inner = SCISafeValueForKey(message, @"message");
    id metadata = inner ? SCISafeValueForKey(inner, @"metadata") : SCISafeValueForKey(message, @"metadata");
    if (!metadata) metadata = SCISafeValueForKey(message, @"messageMetadata");

    // A published message carries its ids on the metadata itself (`serverId`, `clientContext`,
    // `serverTimestamp`) and its words in `content` (`_text_string`); the UI shape carries them on
    // a `key`. Both are asked, because which one the update stream holds is the first thing the
    // report will say.
    id content = SCISafeValueForKey(message, @"content");
    id key = metadata ? SCISafeValueForKey(metadata, @"key") : nil;
    NSString *serverId = SCIString(SCISafeValueForKey(key, @"serverId"))
        ?: SCIString(SCISafeValueForKey(metadata, @"serverId"))
        ?: SCIString(SCISafeValueForKey(message, @"messageId"));
    NSString *clientId = SCIString(SCISafeValueForKey(key, @"clientId"))
        ?: SCIString(SCISafeValueForKey(metadata, @"clientContext"));
    if (!serverId && !clientId) {
        [SCIDiagnostics privacyCount:@"Unsent log · inserted message with no id"];
        [self noteShapeOf:message];
        return;
    }

    NSString *text = SCIString(SCISafeValueForKey(message, @"text"))
        ?: (content ? SCIString(SCISafeValueForKey(content, @"text_string")) : nil);
    if (text.length > kSCITextLimit) text = [text substringToIndex:kSCITextLimit];

    id sent = metadata ? (SCISafeValueForKey(metadata, @"sentDate") ?: SCISafeValueForKey(metadata, @"serverTimestamp")) : nil;
    NSTimeInterval sentAt = [sent isKindOfClass:[NSDate class]] ? [(NSDate *)sent timeIntervalSince1970] : 0;

    NSMutableDictionary *record = [NSMutableDictionary dictionary];
    if (serverId) record[kID] = serverId;
    if (clientId) record[kClient] = clientId;
    record[kKind] = SCIKindOf(message, content);
    if (text) record[kText] = text;
    record[kSent] = @(sentAt);
    NSString *sender = metadata ? SCIString(SCISafeValueForKey(metadata, @"senderPk")) : nil;
    if (sender) record[kSender] = sender;
    NSString *thread = metadata ? SCIString(SCISafeValueForKey(metadata, @"threadId")) : nil;
    if (thread) record[kThread] = thread;

    @synchronized (sLock) {
        for (NSString *identifier in @[serverId ?: @"", clientId ?: @""]) {
            if (!identifier.length) continue;
            if (!sCache[identifier]) [sCacheOrder addObject:identifier];
            sCache[identifier] = record;
        }
        while (sCacheOrder.count > kSCICacheLimit) {
            [sCache removeObjectForKey:sCacheOrder.firstObject];
            [sCacheOrder removeObjectAtIndex:0];
        }
    }

    [SCIDiagnostics privacyCount:text ? @"Unsent log · messages remembered (with text)"
                                      : @"Unsent log · messages remembered (no text)"];
    [self noteShapeOf:message];
}

// MARK: - The row

+ (void)recordHeldKey:(id)key {
    if (!key) return;

    NSString *serverId = nil, *clientId = nil;
    Ivar a = class_getInstanceVariable(object_getClass(key), "_messageServerId");
    Ivar b = class_getInstanceVariable(object_getClass(key), "_messageClientContext");
    if (a) serverId = SCIString(object_getIvar(key, a));
    if (b) clientId = SCIString(object_getIvar(key, b));
    if (!serverId && !clientId) {
        [SCIDiagnostics privacyCount:@"Unsent log · key carried no id"];
        return;
    }

    [self loadIfNeeded];

    NSDictionary *found = nil;
    @synchronized (sLock) {
        found = (serverId ? sCache[serverId] : nil) ?: (clientId ? sCache[clientId] : nil);

        // The same removal can be delivered more than once. One row per message.
        NSString *identifier = serverId ?: clientId;
        for (NSDictionary *row in sEntries) {
            if ([row[kID] isEqualToString:identifier]) {
                [SCIDiagnostics privacyCount:@"Unsent log · duplicate removal ignored"];
                return;
            }
        }
    }

    NSMutableDictionary *entry = [NSMutableDictionary dictionary];
    entry[kID] = serverId ?: clientId;
    if (clientId) entry[kClient] = clientId;
    entry[kDeleted] = @([[NSDate date] timeIntervalSince1970]);
    entry[kHeld] = @(found != nil);

    if (found) {
        for (NSString *field in @[kKind, kText, kSent, kSender, kThread]) {
            if (found[field]) entry[field] = found[field];
        }
        NSString *sender = found[kSender];
        if (sender) {
            @synchronized (sLock) {
                if (sNames[sender]) entry[kName] = sNames[sender];
            }
        }
        [SCIDiagnostics privacyCount:found[kText] ? @"Unsent log · row written (with text)"
                                                  : @"Unsent log · row written (content not text)"];
    } else {
        [SCIDiagnostics privacyCount:@"Unsent log · row written (message never seen this launch)"];
    }

    @synchronized (sLock) {
        [sEntries insertObject:entry atIndex:0];
        while (sEntries.count > kSCILogLimit) [sEntries removeLastObject];
    }
    [self changed];
}

// MARK: - Reading

+ (NSArray<NSDictionary *> *)entries {
    [self loadIfNeeded];
    @synchronized (sLock) { return [sEntries copy]; }
}

+ (NSUInteger)count {
    [self loadIfNeeded];
    @synchronized (sLock) { return sEntries.count; }
}

+ (void)removeEntryWithIdentifier:(NSString *)identifier {
    [self loadIfNeeded];
    @synchronized (sLock) {
        for (NSDictionary *row in [sEntries copy]) {
            if ([row[kID] isEqualToString:identifier]) [sEntries removeObject:row];
        }
    }
    [self changed];
}

+ (void)clear {
    [self loadIfNeeded];
    @synchronized (sLock) { [sEntries removeAllObjects]; }
    [self changed];
}

+ (NSString *)localizedKind:(NSString *)kind {
    if (!kind.length) return SCILocalized(@"unsent_kind_message");

    NSString *lower = kind.lowercaseString;
    struct { const char *needle; NSString *key; } table[] = {
        { "text",     @"unsent_kind_text" },
        { "photo",    @"unsent_kind_photo" },
        { "video",    @"unsent_kind_video" },
        { "audio",    @"unsent_kind_voice" },
        { "voice",    @"unsent_kind_voice" },
        { "animated", @"unsent_kind_gif" },
        { "gif",      @"unsent_kind_gif" },
        { "sticker",  @"unsent_kind_sticker" },
        { "like",     @"unsent_kind_like" },
        { "link",     @"unsent_kind_link" },
        { "reel",     @"unsent_kind_reel" },
        { "post",     @"unsent_kind_post" },
        { "story",    @"unsent_kind_story" },
        { "location", @"unsent_kind_location" },
        { "media",    @"unsent_kind_media" },
    };
    for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++) {
        if ([lower containsString:@(table[i].needle)]) return SCILocalized(table[i].key);
    }
    return kind;
}

+ (NSString *)exportText {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:[SCILocalize isRTL] ? @"ar" : @"en_US"];
    formatter.dateStyle = NSDateFormatterMediumStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;

    NSMutableString *out = [NSMutableString string];
    for (NSDictionary *row in [self entries]) {
        NSString *who = row[kName] ?: row[kSender] ?: @"?";
        NSDate *sent = [row[kSent] doubleValue] > 0 ? [NSDate dateWithTimeIntervalSince1970:[row[kSent] doubleValue]] : nil;
        NSDate *deleted = [NSDate dateWithTimeIntervalSince1970:[row[kDeleted] doubleValue]];

        [out appendFormat:@"%@  ·  %@%@\n", who,
         sent ? [NSString stringWithFormat:@"%@ → ", [formatter stringFromDate:sent]] : @"",
         [formatter stringFromDate:deleted]];
        [out appendFormat:@"%@\n\n", row[kText] ?: [NSString stringWithFormat:@"[%@]", [self localizedKind:row[kKind]]]];
    }
    return out;
}

@end
