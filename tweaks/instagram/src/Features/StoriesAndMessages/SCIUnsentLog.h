#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Posted on the main queue whenever the log changes.
extern NSString * const SCIUnsentLogDidChangeNotification;

///
/// A record of messages somebody unsent -- what they said, who said it, when it was sent and
/// when it was taken back.
///
/// **Keeping an unsent message and recording it are different promises.** Keeping leaves the
/// message in the chat until the next refresh (which removes it, hence the question asked
/// before a refresh); the record is what survives that. It lives in the app's own Application
/// Support folder as one bounded JSON file and goes only when somebody clears it.
///
/// **Where the content comes from, and the limit it implies.** An unsend arrives as a *key*
/// (`IGDirectMessageUpdateMessageKey { _messageServerId, _messageClientContext }`) and nothing
/// else -- no text. The text has to have been seen earlier, so every message that goes through
/// the same update stream is remembered in memory as it arrives (`_insertMessages` and
/// `_replaceMessages_messages` of `IGDirectMessageUpdate`, both read from the real class
/// metadata) and looked up by server id when its removal turns up. A message that arrived
/// before this launch and was never replayed through that stream has no content to look up;
/// it is still logged -- who, when, and that its content was not available -- because an
/// honest "not captured" row is worth more than a silent gap that looks like a complete log.
///
/// What is stored is the text of messages that were *taken back*, never of messages in
/// general: the in-memory cache of everything else is bounded, never written to disk.
///
@interface SCIUnsentLog : NSObject

/// Remembers one message from an insert/replace update, for the moment its removal arrives.
/// Reads declared fields only, never executes anything it cannot see the signature of, and
/// is cheap enough to run on every batch.
+ (void)captureMessage:(nullable id)message;

/// Learns who a participant id belongs to from a thread's metadata (`users`), so a row can
/// say a name rather than a number. Best effort, in memory.
+ (void)learnThreadMetadata:(nullable id)metadata;

/// An unsent message's key has arrived and is being held back: write the row.
+ (void)recordHeldKey:(nullable id)key;

/// Newest first. Each entry is a plain dictionary (see the keys in the implementation).
+ (NSArray<NSDictionary *> *)entries;
+ (NSUInteger)count;
+ (void)removeEntryWithIdentifier:(NSString *)identifier;
+ (void)clear;

/// The whole log as plain text, for the share sheet.
+ (NSString *)exportText;

/// "text" -> the localised word, "Photo" -> photo, anything unknown -> the class name itself.
+ (NSString *)localizedKind:(nullable NSString *)kind;

@end

NS_ASSUME_NONNULL_END
