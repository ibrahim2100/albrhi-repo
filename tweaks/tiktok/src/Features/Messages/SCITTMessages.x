//
//  SCITTMessages.x
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <string.h>
#import "SCITTMessages.h"
#import "../../Prefs.h"
#import "../../SCILog.h"
#import "../../Localization/SCILocalize.h"
#import "../../UI/SCITTSheet.h"
#import "../../Diagnostics/SCITTDiagnostics.h"
#import "shared/src/SCIKVC.h"

///
/// **Three direct-message switches, from VibeTok's table and re-measured against TikTok 47.1.0's own class metadata.** VibeTok is unlicensed and
/// is read for architecture only (CLAUDE.md §2): what was taken is the list of places to look. The owner allowed copying; a licence is the
/// author's to give, so nothing was copied and every body below is written here.
///
///   TIMInputStatusManager          -sendInputStatusWithConversationID:inputStatus:   v28@0:8@16i24
///   AWEIMMessageDeletionComponent  -deleteMessageForMe:                                v24@0:8@16
///   AWEIMMessageDeletionComponent  -recallMessageForEveryone:                          v24@0:8@16
///   AWEIMMessageDataController     -undoDeleteMessage:completion:                     v32@0:8@16@?24
///
/// **A different door from the reference's, on purpose.** VibeTok asks before `AWEIMMessageDataController -recallMessage:completion:`, a data-layer
/// call (a caller scan of 47.1.0 shows it reached from `-deleteMessageForMe:` among others). The two methods of the *component* are what a tap on
/// "Delete for me" and on "Unsend" run, so the question is asked where the person acted and cannot be put by anything that is not a tap.
///

@interface TIMInputStatusManager : NSObject
@end

@interface AWEIMMessageDeletionComponent : NSObject
- (void)deleteMessageForMe:(id)message;
- (void)recallMessageForEveryone:(id)message;
@end

@interface AWEIMMessageDataController : NSObject
- (void)undoDeleteMessage:(id)message completion:(id)completion;
@end

/// Raised only while a confirmed action is replayed, on the main thread (every one of these is a tap handler).
static BOOL sciDeleteReplaying = NO;

static NSUInteger sciTypingSeen = 0, sciTypingWithheld = 0;
static NSUInteger sciDeleteAsked = 0, sciDeleteAllowed = 0, sciUnsendAsked = 0, sciUnsendAllowed = 0;
static NSUInteger sciUndoOffered = 0, sciUndoTapped = 0, sciUndoNoController = 0, sciUndoNoMessage = 0;
static NSString *sciMessagesState = nil;

/// A string-or-nil answer from an object-returning accessor, asked only when the object declares it.
static NSString *SCITTTextFrom(id object, NSString *name) {
    if (!object) return nil;
    SEL selector = NSSelectorFromString(name);
    Method method = class_getInstanceMethod(object_getClass(object), selector);
    const char *types = method ? method_getTypeEncoding(method) : NULL;
    if (!types || types[0] != '@') return nil;
    id value = ((id (*)(id, SEL))objc_msgSend)(object, selector);
    return [value isKindOfClass:[NSString class]] && [(NSString *)value length] ? value : nil;
}

/// The message's own words, shortened, for the question and for the undo sheet. Nil for a message that is not text (a photo, a sticker).
static NSString *SCITTPreview(id message) {
    NSString *text = SCITTTextFrom(message, @"text") ?: SCITTTextFrom(message, @"displayText");
    if (!text) return nil;
    text = [text stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    return text.length > 120 ? [[text substringToIndex:120] stringByAppendingString:@"…"] : text;
}

/// Asks, and calls `proceed` on yes. **When there is nowhere to ask, the action happens** -- a confirmation that cannot be presented must not become
/// a silent refusal (the same rule as the like and follow questions): the tap the person made is the best answer left.
static void SCITTAskBeforeDelete(NSString *titleKey, id message, BOOL unsend, void (^proceed)(void)) {
    if (![SCITTSheet canPresent]) {
        proceed();
        return;
    }
    if (unsend) sciUnsendAsked++; else sciDeleteAsked++;

    [SCITTSheet showTitle:SCILocalized(titleKey)
                  message:SCITTPreview(message)
                   symbol:unsend ? @"arrow.uturn.backward.circle.fill" : @"trash.fill"
                  actions:@[
        [SCITTSheetAction title:SCILocalized(@"confirm_yes")
                         symbol:@"checkmark"
                        primary:YES
                        handler:^{
            if (unsend) sciUnsendAllowed++; else sciDeleteAllowed++;
            proceed();
        }],
    ]
                   cancel:SCILocalized(@"photos_cancel")];
}

/// After a message was deleted for the person, offers to take it back through TikTok's own `-undoDeleteMessage:completion:` -- the call TikTok
/// itself reaches from this component. **Whether TikTok restores a message it just deleted for me is not known from this machine** (no account in
/// the simulator copy): the sheet says "asked", never "restored", and the report counts offers and taps.
static void SCITTOfferUndo(id component, id argument) {
    if (!SCIPrefEnabled(SCIPrefUndoDelete) || !argument || ![SCITTSheet canPresent]) return;

    // **What `-undoDeleteMessage:completion:` is handed must be an `AWEIMMessage`, and the argument of the component's method is not known to be
    // one** (it is typed `id`, and an object of another class sent into the data controller is a crash, not a refusal). Taken as is when it is
    // one, else through the two accessors a cell view model declares for its message (`-message`, `-getUnderlyingMessage`, both `@16@0:8`);
    // anything else offers nothing and is counted.
    Class messageClass = NSClassFromString(@"AWEIMMessage");
    id message = [argument isKindOfClass:messageClass] ? argument : nil;
    if (!message) {
        for (NSString *name in @[@"message", @"getUnderlyingMessage"]) {
            SEL selector = NSSelectorFromString(name);
            Method method = class_getInstanceMethod(object_getClass(argument), selector);
            const char *types = method ? method_getTypeEncoding(method) : NULL;
            if (!types || strcmp(types, "@16@0:8") != 0) continue;
            id candidate = ((id (*)(id, SEL))objc_msgSend)(argument, selector);
            if ([candidate isKindOfClass:messageClass]) { message = candidate; break; }
        }
    }
    if (!message) {
        sciUndoNoMessage++;
        return;
    }

    id controller = SCISafeValueForKey(component, @"dataController");
    if (![controller respondsToSelector:@selector(undoDeleteMessage:completion:)]) {
        sciUndoNoController++;
        return;
    }
    sciUndoOffered++;

    // After the original has finished, so the sheet never opens in the middle of TikTok removing the row.
    dispatch_async(dispatch_get_main_queue(), ^{
        [SCITTSheet showTitle:SCILocalized(@"undo_deleted_title")
                      message:SCITTPreview(message)
                       symbol:@"arrow.uturn.backward.circle.fill"
                      actions:@[
            [SCITTSheetAction title:SCILocalized(@"undo_action")
                             symbol:@"arrow.uturn.backward"
                            primary:YES
                            handler:^{
                sciUndoTapped++;
                [(AWEIMMessageDataController *)controller undoDeleteMessage:message completion:nil];
            }],
        ]
                       cancel:SCILocalized(@"undo_close")];
    });
}

%group SCITTTypingGroup
%hook TIMInputStatusManager

- (void)sendInputStatusWithConversationID:(id)conversationID inputStatus:(int)status {
    sciTypingSeen++;
    if (!SCIPrefEnabled(SCIPrefHideTyping)) {
        %orig;
        return;
    }
    // Not called at all: nothing is sent, and nothing false is sent in its place. The other person's "typing…" simply never starts.
    sciTypingWithheld++;
    [SCITTDiagnostics recordPrivacyAnswer:@"typing indicator withheld"];
}

%end
%end

%group SCITTDeleteGroup
%hook AWEIMMessageDeletionComponent

- (void)deleteMessageForMe:(id)message {
    if (!sciDeleteReplaying && SCIPrefEnabled(SCIPrefConfirmDelete)) {
        SCITTAskBeforeDelete(@"confirm_delete_title", message, NO, ^{
            sciDeleteReplaying = YES;
            [self deleteMessageForMe:message];
            sciDeleteReplaying = NO;
        });
        return;
    }
    %orig;
    SCITTOfferUndo(self, message);
}

- (void)recallMessageForEveryone:(id)message {
    if (!sciDeleteReplaying && SCIPrefEnabled(SCIPrefConfirmDelete)) {
        SCITTAskBeforeDelete(@"confirm_unsend_title", message, YES, ^{
            sciDeleteReplaying = YES;
            [self recallMessageForEveryone:message];
            sciDeleteReplaying = NO;
        });
        return;
    }
    %orig;
}

%end
%end

NSString *SCITTMessagesReport(void) {
    return [NSString stringWithFormat:
            @"%@; typing: asked %lu, withheld %lu; delete: asked %lu, allowed %lu; unsend: asked %lu, allowed %lu; undo: offered %lu, tapped %lu, no controller %lu, argument was no message %lu",
            sciMessagesState ?: @"not installed",
            (unsigned long)sciTypingSeen, (unsigned long)sciTypingWithheld,
            (unsigned long)sciDeleteAsked, (unsigned long)sciDeleteAllowed,
            (unsigned long)sciUnsendAsked, (unsigned long)sciUnsendAllowed,
            (unsigned long)sciUndoOffered, (unsigned long)sciUndoTapped, (unsigned long)sciUndoNoController, (unsigned long)sciUndoNoMessage];
}

static BOOL SCITTMessagesHas(Class cls, const char *selector, const char *encoding) {
    Method method = cls ? class_getInstanceMethod(cls, sel_registerName(selector)) : NULL;
    const char *types = method ? method_getTypeEncoding(method) : NULL;
    return types && strcmp(types, encoding) == 0;
}

void SCITTInstallMessages(void) {
    NSMutableArray<NSString *> *installed = [NSMutableArray array];
    NSMutableArray<NSString *> *skipped = [NSMutableArray array];

    if (SCITTMessagesHas(NSClassFromString(@"TIMInputStatusManager"), "sendInputStatusWithConversationID:inputStatus:", "v28@0:8@16i24")) {
        %init(SCITTTypingGroup);
        [installed addObject:@"TIMInputStatusManager -sendInputStatus…"];
    } else {
        [skipped addObject:@"TIMInputStatusManager -sendInputStatusWithConversationID:inputStatus:"];
    }

    Class deletion = NSClassFromString(@"AWEIMMessageDeletionComponent");
    if (SCITTMessagesHas(deletion, "deleteMessageForMe:", "v24@0:8@16") && SCITTMessagesHas(deletion, "recallMessageForEveryone:", "v24@0:8@16")) {
        %init(SCITTDeleteGroup);
        [installed addObject:@"AWEIMMessageDeletionComponent -deleteMessageForMe: / -recallMessageForEveryone:"];
    } else {
        [skipped addObject:@"AWEIMMessageDeletionComponent -deleteMessageForMe: / -recallMessageForEveryone:"];
    }

    sciMessagesState = [NSString stringWithFormat:@"%@%@",
        installed.count ? [@"installed: " stringByAppendingString:[installed componentsJoinedByString:@", "]] : @"nothing installed",
        skipped.count ? [@" — skipped: " stringByAppendingString:[skipped componentsJoinedByString:@"; "]] : @""];
    SCILogV(@"[Messages] %@", sciMessagesState);
}
