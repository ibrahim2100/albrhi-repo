#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "../../Utils.h"
#import "../../Settings/SCIDiagnosticsViewController.h"

///
/// Which door an unsent message leaves by, on the build actually running.
///
/// **Counting, not blocking, and the reason is a report.** Keeping unsent messages works by
/// emptying a removal before Instagram applies it, at the two applicators and the MSYS delta
/// in KeepDeletedMessages.x. On 439 the report said `Removal paths seen: —` -- not one of them
/// was reached -- so the removal is arriving by a route this tweak has never been on, and the
/// only honest next step is to find out which.
///
/// The candidates are the removal entry points in this tweak's own Iris/MSYS reading, plus the
/// ones InstaPlus hooks (read for architecture only; nothing copied). **None of InstaPlus's
/// selectors exist in 410**, measured with tools/objc-classes.py -- not as a method and not
/// even as a string -- so they are either newer than 410 or guesses, and a %hook would have
/// *added* them rather than hooked them. Each is attached here only when the running build
/// declares it, with exactly the signature written below; anything else is listed as absent,
/// so the report says which routes exist before anybody asks which ones fire.
///
/// Every hook passes its call through unchanged. Several of these also run when *this* phone
/// removes a message -- a pending copy replaced by the sent one, an unsend of our own -- and
/// swallowing those would duplicate or strand messages. Which ones fire for somebody else's
/// unsend is the measurement; blocking comes after it, on that route alone.
///

typedef NS_ENUM(NSInteger, SCIWitnessShape) {
    SCIWitnessReturnsObjectOneArg,   // @24@0:8@16
    SCIWitnessVoidOneArg,            // v24@0:8@16
    SCIWitnessVoidTwoArgs,           // v32@0:8@16@24
    SCIWitnessVoidTwoArgsAndBlock,   // v40@0:8@16@24@?32
};

static const char *SCIWitnessEncoding(SCIWitnessShape shape) {
    switch (shape) {
        case SCIWitnessReturnsObjectOneArg: return "@24@0:8@16";
        case SCIWitnessVoidOneArg:          return "v24@0:8@16";
        case SCIWitnessVoidTwoArgs:         return "v32@0:8@16@24";
        case SCIWitnessVoidTwoArgsAndBlock: return "v40@0:8@16@24@?32";
    }
    return "";
}

static BOOL SCIWitnessWanted(void) {
    return [SCIUtils getBoolPref:@"keep_unsent_messages"];
}

/// An Iris thread delta carries its removal in `_removeItem_messageId`, set only for that case.
/// Read as a field: it runs nothing, and a delta of any other kind simply has it nil.
static BOOL SCIIsIrisRemoval(id object) {
    if (!object) return NO;
    Ivar field = class_getInstanceVariable(object_getClass(object), "_removeItem_messageId");
    return field && object_getIvar(object, field) != nil;
}

/// Hooks one candidate if, and only if, this build declares it with the expected signature.
/// Returns NO for an absent or differently-shaped method, which the caller lists as absent.
static BOOL SCIWitness(NSString *className, BOOL classMethod, NSString *selectorName, SCIWitnessShape shape) {
    Class cls = objc_getClass(className.UTF8String);
    if (!cls) return NO;

    Class target = classMethod ? object_getClass(cls) : cls;
    SEL selector = NSSelectorFromString(selectorName);

    // Declared on this class itself, not inherited: hooking an inherited method would hook it
    // for every sibling class too, which is not a measurement of this one.
    BOOL declared = NO;
    unsigned int count = 0;
    Method *list = class_copyMethodList(target, &count);
    for (unsigned int i = 0; list && i < count && !declared; i++) {
        if (method_getName(list[i]) != selector) continue;
        const char *types = method_getTypeEncoding(list[i]);
        declared = types && strcmp(types, SCIWitnessEncoding(shape)) == 0;
    }
    if (list) free(list);
    if (!declared) return NO;

    NSString *label = [NSString stringWithFormat:@"Unsent · %@[%@ %@]",
                       classMethod ? @"+" : @"-", className, selectorName];

    // One cell per hook, so every block calls its own original; freed never, like the hook.
    IMP *orig = calloc(1, sizeof(IMP));
    IMP replacement = NULL;

    switch (shape) {
        case SCIWitnessReturnsObjectOneArg: {
            replacement = imp_implementationWithBlock(^id(id me, id a) {
                if (SCIWitnessWanted()) [SCIDiagnostics privacyCount:label];
                return ((id (*)(id, SEL, id))*orig)(me, selector, a);
            });
            break;
        }
        case SCIWitnessVoidOneArg: {
            replacement = imp_implementationWithBlock(^(id me, id a) {
                if (SCIWitnessWanted()) [SCIDiagnostics privacyCount:label];
                ((void (*)(id, SEL, id))*orig)(me, selector, a);
            });
            break;
        }
        case SCIWitnessVoidTwoArgs: {
            replacement = imp_implementationWithBlock(^(id me, id a, id b) {
                if (SCIWitnessWanted()) [SCIDiagnostics privacyCount:label];
                ((void (*)(id, SEL, id, id))*orig)(me, selector, a, b);
            });
            break;
        }
        case SCIWitnessVoidTwoArgsAndBlock: {
            replacement = imp_implementationWithBlock(^(id me, id a, id b, id block) {
                if (SCIWitnessWanted()) {
                    // Every delta is counted, and the removals among them separately: a count of
                    // deltas with no removals says the channel is live and the unsend is not on it.
                    [SCIDiagnostics privacyCount:label];
                    if (SCIIsIrisRemoval(a) || SCIIsIrisRemoval(b)) {
                        [SCIDiagnostics privacyCount:@"Unsent · Iris delta carrying a removal"];
                    }
                }
                ((void (*)(id, SEL, id, id, id))*orig)(me, selector, a, b, block);
            });
            break;
        }
    }

    MSHookMessageEx(target, selector, replacement, orig);

    // Listed at zero from the start, so "hooked, never reached" is on the page before anything
    // happens rather than being indistinguishable from "not hooked".
    [SCIDiagnostics privacyNote:label value:@"hooked, ×0"];
    return YES;
}

static void SCIInstallUnsendWitness(void) {
    static BOOL installed = NO;
    if (installed) return;
    installed = YES;

    struct { const char *cls; BOOL meta; const char *sel; SCIWitnessShape shape; } candidates[] = {
        // This tweak's own Iris/MSYS reading, confirmed in 410.
        { "IGDirectRealtimeIrisDeltaApplicator", NO, "_fetchThreadDeltaUpdates:delta:threadUpdatesBlock:", SCIWitnessVoidTwoArgsAndBlock },
        { "MDCoreDelta", YES, "deleteMessageDelta:", SCIWitnessReturnsObjectOneArg },
        // InstaPlus's list -- absent from 410, so this is where 439 says whether they exist.
        { "IGDirectRealtimeIrisThreadDelta", YES, "removeItemWithMessageId:", SCIWitnessReturnsObjectOneArg },
        { "IGDirectRealtimeIrisThreadDelta", YES, "removeMessageWithMessageId:", SCIWitnessReturnsObjectOneArg },
        { "IGDirectMessageUpdate", YES, "removeMessageWithMessageId:", SCIWitnessReturnsObjectOneArg },
        { "IGDirectPublishedMessageSet", NO, "removeMessageWithClientContext:", SCIWitnessReturnsObjectOneArg },
        { "IGDirectPublishedMessageSet", NO, "removeMessageWithServerId:", SCIWitnessReturnsObjectOneArg },
        { "IGDirectThread", NO, "removeMessage:", SCIWitnessVoidOneArg },
        { "IGDirectThread", NO, "removeMessageWithId:", SCIWitnessVoidOneArg },
        { "IGDirectCache", NO, "removeMessageWithId:fromThreadId:", SCIWitnessVoidTwoArgs },
        { "IGDirectCache", NO, "removeMessageWithServerId:fromThreadId:", SCIWitnessVoidTwoArgs },
    };

    NSMutableArray<NSString *> *absent = [NSMutableArray array];
    for (size_t i = 0; i < sizeof(candidates) / sizeof(candidates[0]); i++) {
        NSString *cls = @(candidates[i].cls);
        NSString *sel = @(candidates[i].sel);
        if (!SCIWitness(cls, candidates[i].meta, sel, candidates[i].shape)) {
            [absent addObject:[NSString stringWithFormat:@"%@[%@ %@]", candidates[i].meta ? @"+" : @"-", cls, sel]];
        }
    }

    [SCIDiagnostics privacyNote:@"Unsent · not in this build"
                          value:absent.count ? [absent componentsJoinedByString:@", "] : @"none — every candidate is hooked"];
}

__attribute__((constructor)) static void SCIUnsendWitnessInit(void) {
    // After launch rather than at load: the classes live in the app's own image, and a
    // constructor can run before that image's classes are registered -- which reads as "absent"
    // for a class the app certainly has.
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil queue:nil
                                                  usingBlock:^(__unused NSNotification *note) {
        SCIInstallUnsendWitness();
    }];
}
