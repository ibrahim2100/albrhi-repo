#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <string.h>
#import "SCITWChat.h"
#import "Prefs.h"
#import "SCILog.h"

///
/// Typing indicator.
///
/// X's chat has one persistent websocket (`chat-ws.x.com`). The typing heartbeat is a
/// periodic frame on it; the same socket also carries delivery, read receipts and presence,
/// so it cannot be refused as a whole. Only the outgoing frame with the heartbeat's own
/// shape is dropped and everything else passes through untouched -- the one rule that
/// keeps this from becoming "chat is broken".
///
/// The shape, measured by NeoFreeBird against X 12.31 from frames captured while typing: a
/// Thrift TBinaryProtocol struct whose second field -- the one that carries message text on
/// a real send -- is an empty string. Message bodies themselves go over a separate HTTP
/// write and never touch `-sendMessage:` on this socket, so the empty field reliably marks
/// the heartbeat:
///
///   0c 0001                  STRUCT, field 1 (envelope)
///     0b 0002 00000000        STRING, field 2, len = 0   <- always empty on the ping
///
/// **That is a reference tweak's measurement of a newer build, not one made here**, so a
/// frame that is dropped is counted next to the number of frames seen on the chat socket:
/// "0 of 0" means the socket was never found, "0 of 400" means the shape did not match on
/// this build, and neither looks like the other in a bare "it still shows typing".
///

static BOOL sciTypingInstalled = NO;
static BOOL sciTypingSwizzled = NO;
static NSUInteger sciChatSocketsTagged = 0;
static NSUInteger sciChatFramesSeen = 0;
static NSUInteger sciChatFramesDropped = 0;

static BOOL sciScreenshotInstalled = NO;
static NSUInteger sciScreenshotObserversRefused = 0;

static void *SCITWChatSocketTagKey = &SCITWChatSocketTagKey;

static const uint8_t SCITWTypingFramePrefix[] = {0x0c, 0x00, 0x01, 0x0b, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00};

static BOOL SCITWIsChatSocketURL(NSURL *url) {
    return url && [url.host isEqualToString:@"chat-ws.x.com"];
}

static BOOL SCITWIsTypingFrame(NSData *data) {
    if (data.length < sizeof(SCITWTypingFramePrefix)) return NO;
    return memcmp(data.bytes, SCITWTypingFramePrefix, sizeof(SCITWTypingFramePrefix)) == 0;
}

typedef void (*SCITWSendIMP)(id, SEL, NSURLSessionWebSocketMessage *, void (^)(NSError *));
static SCITWSendIMP sciOriginalSend = NULL;

static void SCITWSendReplacement(id self, SEL _cmd, NSURLSessionWebSocketMessage *message,
                                 void (^completion)(NSError *)) {
    if (objc_getAssociatedObject(self, SCITWChatSocketTagKey) && message.data) {
        sciChatFramesSeen++;
        if (SCITWIsTypingFrame(message.data)) {
            sciChatFramesDropped++;
            // Reported as sent. The caller is waiting for a completion, and a socket that never
            // answers is a spinner or a retry loop on X's side, not a silent drop.
            if (completion) completion(nil);
            return;
        }
    }
    sciOriginalSend(self, _cmd, message, completion);
}

/// The private class behind a websocket task is not `NSURLSessionWebSocketTask`; it is whatever
/// the runtime made, so its method is replaced on the instance's real class the first time one
/// is seen -- after checking that the method is really there with the shape expected.
static void SCITWSwizzleSendIfNeeded(NSURLSessionWebSocketTask *task) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Class real = object_getClass(task);
        SEL selector = @selector(sendMessage:completionHandler:);
        Method method = class_getInstanceMethod(real, selector);
        if (!method) return;

        const char *encoding = method_getTypeEncoding(method);
        if (!encoding || strcmp(encoding, "v32@0:8@16@?24") != 0) return;

        sciOriginalSend = (SCITWSendIMP)method_getImplementation(method);
        method_setImplementation(method, (IMP)SCITWSendReplacement);
        sciTypingSwizzled = YES;
    });
}

static void SCITWTagIfChatSocket(NSURLSessionWebSocketTask *task, NSURL *url) {
    if (task && SCITWIsChatSocketURL(url)) {
        objc_setAssociatedObject(task, SCITWChatSocketTagKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        sciChatSocketsTagged++;
    }
}

%group TypingIndicator

%hook NSURLSession

- (NSURLSessionWebSocketTask *)webSocketTaskWithURL:(NSURL *)url {
    NSURLSessionWebSocketTask *task = %orig;
    SCITWSwizzleSendIfNeeded(task);
    SCITWTagIfChatSocket(task, url);
    return task;
}

- (NSURLSessionWebSocketTask *)webSocketTaskWithURL:(NSURL *)url protocols:(NSArray<NSString *> *)protocols {
    NSURLSessionWebSocketTask *task = %orig;
    SCITWSwizzleSendIfNeeded(task);
    SCITWTagIfChatSocket(task, url);
    return task;
}

- (NSURLSessionWebSocketTask *)webSocketTaskWithRequest:(NSURLRequest *)request {
    NSURLSessionWebSocketTask *task = %orig;
    SCITWSwizzleSendIfNeeded(task);
    SCITWTagIfChatSocket(task, request.URL);
    return task;
}

%end

%end


///
/// Screenshot and screen-recording detection.
///
/// X finds out through two notifications, and an observer that is never registered is an
/// observer that never hears. Registration is refused rather than the delivery filtered,
/// because the latter would leave the app believing it had subscribed. `-isCaptured` is
/// answered the same way for the code that asks the screen directly instead of waiting.
///
/// This touches every observer in the process, not only X's chat -- there is one process
/// and these are the only two names -- and it is the reason the group is attached only when
/// the switch was on at launch.
///

static void (^SCITWEmptyObserver(void))(NSNotification *) {
    return ^(NSNotification *note) {};
}

%group ScreenshotDetection

%hook NSNotificationCenter

- (id)addObserverForName:(NSNotificationName)name
                  object:(id)object
                   queue:(NSOperationQueue *)queue
              usingBlock:(void (^)(NSNotification *note))block {
    if ([name isEqualToString:UIApplicationUserDidTakeScreenshotNotification] ||
        [name isEqualToString:UIScreenCapturedDidChangeNotification]) {
        sciScreenshotObserversRefused++;
        // An empty block rather than nil: the caller keeps the token and removes it later, and a
        // missing one would be a crash in somebody else's code.
        void (^empty)(NSNotification *) = SCITWEmptyObserver();
        id token = %orig(name, object, queue, empty);
        return token;
    }
    id token = %orig;
    return token;
}

- (void)addObserver:(id)observer selector:(SEL)selector name:(NSNotificationName)name object:(id)object {
    if ([name isEqualToString:UIApplicationUserDidTakeScreenshotNotification] ||
        [name isEqualToString:UIScreenCapturedDidChangeNotification]) {
        sciScreenshotObserversRefused++;
        return;
    }
    %orig;
}

%end

%hook UIScreen

- (BOOL)isCaptured {
    return NO;
}

%end

%end


NSString *SCITWChatReport(void) {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];

    if (!sciTypingInstalled) {
        [parts addObject:@"typing indicator: off (or off when X was opened)"];
    } else {
        [parts addObject:[NSString stringWithFormat:
            @"typing indicator: hooked%@ · %lu chat socket(s) · %lu frame(s) seen · %lu heartbeat(s) dropped",
            sciTypingSwizzled ? @"" : @" (socket class never seen or its method differs)",
            (unsigned long)sciChatSocketsTagged, (unsigned long)sciChatFramesSeen,
            (unsigned long)sciChatFramesDropped]];
    }

    if (!sciScreenshotInstalled) {
        [parts addObject:@"screenshot detection: off (or off when X was opened)"];
    } else {
        [parts addObject:[NSString stringWithFormat:
            @"screenshot detection: hooked · %lu observer(s) refused",
            (unsigned long)sciScreenshotObserversRefused]];
    }

    return [parts componentsJoinedByString:@"\n"];
}

void SCITWInstallChat(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if ([defaults boolForKey:SCIPrefHideTyping]) {
        %init(TypingIndicator);
        sciTypingInstalled = YES;
    }

    if ([defaults boolForKey:SCIPrefBlockScreenshotDetect]) {
        %init(ScreenshotDetection);
        sciScreenshotInstalled = YES;
    }

    SCILogV(@"chat: typing %d screenshot %d", sciTypingInstalled, sciScreenshotInstalled);
}
