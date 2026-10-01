#import <objc/message.h>
#import <objc/runtime.h>
#import "../../Utils.h"
#import "shared/src/SCIKVC.h"
#import "../../InstagramHeaders.h"
#import "../../Settings/SCIDiagnosticsViewController.h"

///
/// Keeps messages that other people unsend — beta.
///
/// Instagram carries Direct on two stacks, and which one a chat uses is decided
/// server-side, so both have to be covered:
///
///   IGDirectCacheUpdatesApplicator -_applyThreadUpdates:…
///       the older path. Thread updates arrive, each an IGDirectThreadUpdate holding
///       an IGDirectMessageUpdate — a variant whose fields are prefixed by case, so a
///       removal is `_removeMessages_messageKeys`. Emptying that list leaves the
///       update removing nothing.
///
///   MDCoreDelta -match…deleteMessageDelta:…
///       the newer MSYS path. A delta object dispatches to one of five handler
///       blocks by case; substituting the delete-message handler means a delete
///       arriving from the server is simply never applied.
///
/// Both classes and every field named here are byte-identical across the two tested
/// Instagram builds, so one build covers both.
///
/// Deliberately NOT hooked: the outgoing mutation processor,
/// IGDirectMessageOutgoingUpdateRemoveMessagesMutationProcessor. That is an unsend
/// this device performs on its way to the server, and blocking it would leave the
/// message sitting on the recipient's phone — worse than not having the feature.
///
/// Which path a given chat actually uses is reported to Diagnostics rather than
/// assumed, because an earlier version of this hooked one path, recorded nothing,
/// and gave no way to tell whether it had fired at all.
///
/// The applicator and the ivar names came from RyukGram
/// (github.com/faroukbmiled/RyukGram, GPLv3); the code here is Albrhi's own.
///
/// Beta, off by default: pull-to-refresh in the inbox reloads threads from the
/// server, so a message kept only on this device goes with the refresh.
///

/// In UnsentMarker.x: remembers a held key so the message it names is drawn with a mark.
extern void SCIUnsentRememberKey(id key);

static BOOL SCIWantsToKeepUnsent(void) {
    return [SCIUtils getBoolPref:@"keep_unsent_messages"];
}

// MARK: - What is being held

/// The message keys held back so far, and how many.
///
/// Blocking the removal is only half of it. The message stays because Instagram was
/// stopped from taking it away, but nothing here knows *which* messages those are —
/// so nothing can tell the user a refresh is about to lose them, and nothing can mark
/// them apart from ordinary messages later.
///
/// Regram keeps exactly this: a list of ids, their content, and a
/// -clearAllUnsentMessagesAfterRefresh, which is why it can warn before a reload.
/// This is the same idea, kept to what is needed and no more.
static NSMutableOrderedSet *sHeldKeys = nil;
static NSObject *sHeldLock = nil;

static NSObject *SCIHeldLock(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ sHeldLock = [[NSObject alloc] init]; });
    return sHeldLock;
}

static void SCIRememberHeldKeys(NSArray *keys) {
    if (!keys.count) return;

    @synchronized (SCIHeldLock()) {
        if (!sHeldKeys) sHeldKeys = [NSMutableOrderedSet orderedSet];

        for (id key in keys) {
            NSString *text = [key isKindOfClass:[NSString class]] ? key : [key description];
            if (text.length) [sHeldKeys addObject:text];
        }

        // Bounded: a long session should not grow this without limit, and only the
        // recent ones matter for a warning about the refresh about to happen.
        while (sHeldKeys.count > 200) [sHeldKeys removeObjectAtIndex:0];
    }
}

NSInteger SCIHeldUnsendCount(void) {
    @synchronized (SCIHeldLock()) {
        return (NSInteger)sHeldKeys.count;
    }
}

void SCIClearHeldUnsends(void) {
    @synchronized (SCIHeldLock()) {
        [sHeldKeys removeAllObjects];
    }
}

// MARK: - Older path: thread updates

/// Empties one message update's removal list.
static void SCIDefuseMessageUpdate(id messageUpdate) {
    if (!messageUpdate) return;

    Ivar keysIvar = class_getInstanceVariable([messageUpdate class], "_removeMessages_messageKeys");
    if (!keysIvar) return;

    id keys = object_getIvar(messageUpdate, keysIvar);
    if (![keys isKindOfClass:[NSArray class]] || [(NSArray *)keys count] == 0) return;

    NSInteger count = (NSInteger)[(NSArray *)keys count];

    // Why the removal was issued. Reported rather than acted on: which value means
    // someone else's unsend is worth observing before anything depends on it. Read
    // straight from the ivar because it is a plain integer — both builds encode it
    // `q` — and object_getIvar would misread a scalar as an object pointer.
    NSInteger reason = -1;
    Ivar reasonIvar = class_getInstanceVariable([messageUpdate class], "_removeMessages_reason");
    if (reasonIvar) {
        char *base = (char *)(__bridge void *)messageUpdate;
        reason = *(NSInteger *)(base + ivar_getOffset(reasonIvar));
    }

    // Noted before the list is emptied, since afterwards there is nothing to note.
    SCIRememberHeldKeys(keys);
    for (id key in (NSArray *)keys) SCIUnsentRememberKey(key);

    // The shape of one key -- its class and field names, never its values -- once per launch.
    // A log of unsent messages has to find each message from its key, and which fields a key
    // carries on this build is the thing that decides how; recorded so the next round is built
    // on the device's answer rather than on Regram's newer build.
    static dispatch_once_t keyShapeOnce;
    id firstKey = [(NSArray *)keys firstObject];
    if (firstKey) dispatch_once(&keyShapeOnce, ^{
        NSMutableArray<NSString *> *names = [NSMutableArray array];
        unsigned int fieldCount = 0;
        Ivar *fields = class_copyIvarList(object_getClass(firstKey), &fieldCount);
        for (unsigned int i = 0; fields && i < fieldCount && names.count < 10; i++) {
            [names addObject:@(ivar_getName(fields[i]))];
        }
        if (fields) free(fields);
        [SCIDiagnostics recordUnsendPath:@"key shape"
                                  detail:[NSString stringWithFormat:@"%@ {%@}",
                                          NSStringFromClass(object_getClass(firstKey)),
                                          [names componentsJoinedByString:@","]]];
    });

    // Written straight into the field it was read from: no setter to guess, no KVC, and the
    // object's own ARC ownership honoured.
    object_setIvarWithStrongDefault(messageUpdate, keysIvar, @[]);

    [SCIDiagnostics recordUnsendKeptWithReason:reason messageCount:count];
    SCILogV(@"[Albrhi] Held back an unsend of %ld message(s), reason %ld", (long)count, (long)reason);
}

/// Walks what the applicator was handed. Deliberately narrow: collections, a thread
/// update's one message update, or a message update itself. An earlier version also
/// followed every object-typed ivar of anything Instagram-shaped, which meant reading
/// arbitrary ivars on every batch of updates — a good way to touch something that
/// does not survive being read, and the likely cause of a crash around GIFs.
static void SCIDefuseThreadUpdates(id updates, NSInteger depth) {
    // Four, not two: on 410 the chain is array → IGDirectCacheThreadUpdate → threadUpdates
    // array → IGDirectThreadUpdate → its message update. Two stopped at the second hop, which
    // is one of the two reasons a real unsend was never reached.
    if (!updates || depth > 4) return;

    if ([updates isKindOfClass:[NSArray class]] || [updates isKindOfClass:[NSSet class]]) {
        for (id element in updates) SCIDefuseThreadUpdates(element, depth + 1);
        return;
    }

    if ([updates isKindOfClass:[NSDictionary class]]) {
        for (id element in [(NSDictionary *)updates allValues]) SCIDefuseThreadUpdates(element, depth + 1);
        return;
    }

    Class cls = [updates class];

    if (class_getInstanceVariable(cls, "_removeMessages_messageKeys")) {
        SCIDefuseMessageUpdate(updates);
        return;
    }

    Ivar messageUpdate = class_getInstanceVariable(cls, "_messageUpdate");
    if (messageUpdate) {
        SCIDefuseMessageUpdate(object_getIvar(updates, messageUpdate));
        return;
    }

    // IGDirectCacheThreadUpdate, what the cache applicator is actually handed on 410.
    //
    // **The report named it and said it had nothing in it: `IGDirectCacheThreadUpdate {}`.**
    // It declares no ivars, no properties and one method, `+internal_classInfo` -- a generated
    // model whose fields are described in a table and whose getters are resolved at runtime,
    // so they are in no method list for the search below to find. The table itself sits in the
    // binary's strings as three neighbours, `threadUpdates`, `mutationIds`, `sequenceIds`, and
    // the first is the list of IGDirectThreadUpdate this walker already knows how to defuse.
    // Regram 6.3 (read for architecture only; nothing copied) asks for exactly that name.
    //
    // SCISafeValueForKey rather than a direct send: it answers for a dynamically resolved getter
    // through -methodSignatureForSelector:, and returns nil rather than guessing on a build
    // where the name is gone.
    id nested = SCISafeValueForKey(updates, @"threadUpdates");
    if (nested) {
        [SCIDiagnostics recordUnsendPath:@"threadUpdates" detail:NSStringFromClass([nested class])];
        SCIDefuseThreadUpdates(nested, depth + 1);
        return;
    }

    // Fields found by declared type rather than by name.
    //
    // The name was the problem. This looked for `_messageUpdate`, which is what
    // IGDirectThreadUpdate calls it — but what actually arrives is
    // IGDirectCacheThreadUpdate, a Swift class whose field names are not ours to
    // guess. Its type encoding still says what it holds, and a field declared as an
    // IGDirect…MessageUpdate is the one worth following whatever it is called.
    //
    // Still narrow: only object fields whose type names a message or thread update
    // are read. The version that read every object field of anything Instagram-shaped
    // was slow and the likely cause of a crash around GIFs.
    BOOL followed = NO;

    unsigned int count = 0;
    Ivar *fields = class_copyIvarList(cls, &count);

    for (unsigned int i = 0; fields && i < count; i++) {
        const char *encoding = ivar_getTypeEncoding(fields[i]);
        if (!encoding || encoding[0] != '@') continue;

        NSString *type = @(encoding);
        if ([type rangeOfString:@"MessageUpdate"].location == NSNotFound
            && [type rangeOfString:@"ThreadUpdate"].location == NSNotFound) {
            continue;
        }

        followed = YES;
        SCIDefuseThreadUpdates(object_getIvar(updates, fields[i]), depth + 1);
    }

    if (fields) free(fields);
    if (followed) return;

    // No usable fields — which is what a Swift class looks like from here. Its stored
    // properties are reachable as zero-argument getters instead, so those are tried:
    // any that returns an object gets walked, exactly as a field would have been.
    //
    // Confined to getters whose name mentions an update, and to objects that return
    // one, so this is not a sweep of everything the class can do.
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);

    for (unsigned int i = 0; methods && i < methodCount; i++) {
        SEL selector = method_getName(methods[i]);
        NSString *name = NSStringFromSelector(selector);

        if ([name rangeOfString:@":"].location != NSNotFound) continue;
        if ([name rangeOfString:@"pdate" options:NSCaseInsensitiveSearch].location == NSNotFound) continue;

        // Object-returning only: calling a getter that hands back a scalar and
        // treating the result as an object is how a tweak crashes an app.
        // method_copyReturnType allocates, and this runs on every batch of updates,
        // so it is freed rather than leaked a few bytes at a time.
        char *returnType = method_copyReturnType(methods[i]);
        BOOL returnsObject = (returnType && returnType[0] == '@');
        free(returnType);

        if (!returnsObject) continue;

        id value = nil;
        @try {
            value = ((id (*)(id, SEL))objc_msgSend)(updates, selector);
        } @catch (__unused id error) { continue; }

        if (value && value != updates) {
            followed = YES;
            SCIDefuseThreadUpdates(value, depth + 1);
        }
    }
    if (methods) free(methods);
    if (followed) return;

    // Nothing matched, so report the object *and its object fields*. The class name
    // alone already moved this forward once — it named IGDirectCacheThreadUpdate
    // where IGDirectThreadUpdate was assumed — and if the search by type misses too,
    // the field list says what is actually in there instead of inviting another
    // guess. Names only, capped, and only when nothing matched, so it costs nothing
    // in the normal case.
    NSMutableArray<NSString *> *shape = [NSMutableArray array];

    unsigned int total = 0;
    Ivar *all = class_copyIvarList(cls, &total);

    for (unsigned int i = 0; all && i < total && shape.count < 6; i++) {
        const char *encoding = ivar_getTypeEncoding(all[i]);
        if (encoding && encoding[0] == '@') [shape addObject:@(ivar_getName(all[i]))];
    }
    if (all) free(all);

    // The last report came back with no fields at all, which rules out reading this
    // through ivars entirely. A Swift class exposes its stored properties as methods
    // rather than as ivars, so the methods are what to look at — and a getter
    // returning the update is as good a way in as a field would have been.
    unsigned int reportCount = 0;
    Method *reportMethods = class_copyMethodList(cls, &reportCount);

    for (unsigned int i = 0; reportMethods && i < reportCount && shape.count < 14; i++) {
        NSString *name = NSStringFromSelector(method_getName(reportMethods[i]));

        // Getters only: no arguments, and not the memory-management plumbing.
        if ([name rangeOfString:@":"].location != NSNotFound) continue;
        if ([name hasPrefix:@"."] || [name isEqualToString:@"dealloc"]) continue;

        [shape addObject:name];
    }
    if (reportMethods) free(reportMethods);

    [SCIDiagnostics recordUnsendPath:@"unmatched"
                              detail:[NSString stringWithFormat:@"%@ {%@}",
                                      NSStringFromClass(cls),
                                      [shape componentsJoinedByString:@","]]];
}

// MARK: - The realtime channel

// Where an unsend actually arrives.
//
// Everything before this hooked IGDirectCacheUpdatesApplicator — the cache's own
// applicator — and Diagnostics kept reporting nothing held back, because a message
// someone else unsends does not come through the cache. It comes down Instagram's
// realtime channel, Iris, and that has its own applicator with a one-argument apply.
// The class and the signature are identical on both tested builds.
//
// The earliest version of this feature, back in 3.1, hooked IGDirectRealtimeIrisThreadDelta
// — the right channel, the wrong method. Disabling it moved the search away from the
// channel entirely, and three attempts were spent on the wrong side of it.
//
// Regram hooks both applicators and reads the same two ivars, which is what pointed
// back here.
%hook IGDirectRealtimeIrisDeltaApplicator

- (void)_applyThreadUpdates:(id)updates {
    if (SCIWantsToKeepUnsent()) {
        [SCIDiagnostics recordUnsendPath:@"iris applyThreadUpdates" detail:NSStringFromClass([updates class])];
        SCIDefuseThreadUpdates(updates, 0);
    }

    %orig;
}

%end

%hook IGDirectCacheUpdatesApplicator

// The older build.
- (void)_applyThreadUpdates:(id)updates completion:(id)completion {
    if (SCIWantsToKeepUnsent()) {
        [SCIDiagnostics recordUnsendPath:@"applyThreadUpdates" detail:NSStringFromClass([updates class])];
        SCIDefuseThreadUpdates(updates, 0);
    }

    %orig;
}

// The newer build, which carries a user-access argument as well.
- (void)_applyThreadUpdates:(id)updates completion:(id)completion userAccess:(id)userAccess {
    if (SCIWantsToKeepUnsent()) {
        [SCIDiagnostics recordUnsendPath:@"applyThreadUpdates+access" detail:NSStringFromClass([updates class])];
        SCIDefuseThreadUpdates(updates, 0);
    }

    %orig;
}

%end

// MARK: - Newer path: MSYS deltas

%hook MDCoreDelta

// The delta dispatches to whichever of these five handlers matches its case.
// Replacing the delete-message handler with one that only records means a delete
// arriving from the server is never applied, while every other case is passed
// through untouched — reactions, new messages and thread deletes all behave.
- (void)matchAddMessageDelta:(id)addMessage
           deleteThreadDelta:(id)deleteThread
         createReactionDelta:(id)createReaction
          deleteMessageDelta:(id)deleteMessage
         deleteReactionDelta:(id)deleteReaction {

    if (!SCIWantsToKeepUnsent() || !deleteMessage) {
        %orig;
        return;
    }

    void (^swallow)(id) = ^(__unused id delta) {
        [SCIDiagnostics recordUnsendPath:@"MSYS deleteMessageDelta" detail:@"held back"];
        SCILogV(@"[Albrhi] Held back an MSYS message delete");
    };

    %orig(addMessage, deleteThread, createReaction, swallow, deleteReaction);
}

%end

// MARK: - Asking before a refresh throws them away

// A pull-to-refresh reloads threads from the server, and anything kept only on this
// device goes with it. That was first written in the setting's description, then as a toast
// *after* the refresh had already happened -- which tells somebody what they lost at the one
// moment they can no longer do anything about it.
//
// It is a question before the refresh now. Two cases ask:
//
//   * messages are being kept and some are held (SCIHeldUnsendCount() > 0) -- always, in
//     words that say how many would go, because this is the refresh that costs something;
//   * the plain switch "confirm chats refresh" is on -- for anyone who just does not want the
//     inbox reloading under a stray pull, the same shape as the reels one.
//
// Regram guards the same moment -- it has a reload alert and a
// -clearAllUnsentMessagesAfterRefresh -- which is what makes its version of this feature feel
// deliberate rather than fragile.
//
// **The two builds spell the selector differently** (`-_pullToRefreshIfPossible` on 410,
// `-pullToRefreshIfPossible` on the newer one), and a hook on the wrong spelling is a hook that
// never fires -- which is why the warning did not appear on 410 at all for a release. Both are
// hooked; each build has one of them.
//
// **The answer is a replay, not `%orig` captured in a block**: confirming sets a flag naming
// this object and sends the same selector again, and the hook lets a flagged call through. A
// second pull while the question is up is dropped rather than queued -- two sheets for one
// refresh is the dialog arriving twice. **If the question cannot be put up the refresh goes
// ahead**: "ask me first" must never turn into "refreshing is broken".
//
// Cancelling has to *end the pull*, or the spinner stays on the inbox for good: the
// refresh control is told it finished, through the inbox's own
// -refreshControlDidEndFinishLoadingAnimation: (v24@0:8@16 on 410) and the `_refreshControl`
// ivar, both read from the class metadata and both checked before use.
//
// Counted: asked, confirmed, cancelled, dropped as a duplicate, and which spelling fired --
// so if somebody says the sheet never appears, the report says whether the pull reached us.

static __weak id sRefreshPassThrough = nil;
static BOOL sRefreshAsking = NO;
static CFAbsoluteTime sRefreshAskedAt = 0;

static BOOL SCIWantsRefreshQuestion(NSInteger *held) {
    NSInteger count = SCIWantsToKeepUnsent() ? SCIHeldUnsendCount() : 0;
    if (held) *held = count;
    return count > 0 || [SCIUtils getBoolPref:@"refresh_chats_confirm"];
}

static void SCIEndInboxRefresh(id inbox) {
    Ivar field = class_getInstanceVariable(object_getClass(inbox), "_refreshControl");
    id control = field ? object_getIvar(inbox, field) : nil;
    SEL done = sel_registerName("refreshControlDidEndFinishLoadingAnimation:");
    if (control && [inbox respondsToSelector:done]) {
        ((void (*)(id, SEL, id))objc_msgSend)(inbox, done, control);
    }
}

/// YES when this call was consumed (a question is up, or one is already); NO when the original
/// should run now.
static BOOL SCIAskBeforeRefresh(id inbox, SEL selector) {
    if (sRefreshPassThrough == inbox) {
        sRefreshPassThrough = nil;
        return NO;
    }

    NSInteger held = 0;
    if (!SCIWantsRefreshQuestion(&held)) return NO;

    // A question that was put up and never answered must not block refreshing for good: the
    // sheet is presented with a bounded number of retries, and one that never gets presented
    // would leave this flag set with nothing on screen to clear it. Ten seconds is long enough
    // that a second pull during a real question is a duplicate and short enough that a lost
    // one costs a pull, not the feature.
    if (sRefreshAsking && CFAbsoluteTimeGetCurrent() - sRefreshAskedAt < 10) {
        [SCIDiagnostics privacyCount:@"Inbox refresh · second pull dropped while asking"];
        return YES;
    }

    sRefreshAsking = YES;
    sRefreshAskedAt = CFAbsoluteTimeGetCurrent();
    [SCIDiagnostics privacyCount:held > 0 ? @"Inbox refresh · asked (messages held)"
                                          : @"Inbox refresh · asked"];

    NSString *title = held > 0
        ? [NSString stringWithFormat:SCILocalized(@"confirm_refresh_chats_unsent"), (long)held]
        : SCILocalized(@"confirm_refresh_chats");

    __weak id weakInbox = inbox;
    [SCIUtils showConfirmation:^{
        sRefreshAsking = NO;
        id target = weakInbox;
        if (!target) return;

        [SCIDiagnostics privacyCount:@"Inbox refresh · confirmed"];

        // They are about to be gone from the chat, so counting them any longer would make the
        // next question a lie.
        if (held > 0) SCIClearHeldUnsends();

        sRefreshPassThrough = target;
        ((void (*)(id, SEL))objc_msgSend)(target, selector);
        sRefreshPassThrough = nil;
    }
                 cancelHandler:^{
        sRefreshAsking = NO;
        id target = weakInbox;
        if (!target) return;

        [SCIDiagnostics privacyCount:@"Inbox refresh · cancelled"];
        SCIEndInboxRefresh(target);
    }
                         title:title];

    return YES;
}

%hook IGDirectInboxViewController

// The newer build.
- (void)pullToRefreshIfPossible {
    [SCIDiagnostics privacyCount:@"Inbox refresh · pull reached -pullToRefreshIfPossible"];
    if (SCIAskBeforeRefresh(self, _cmd)) return;

    %orig;
}

// The older build.
- (void)_pullToRefreshIfPossible {
    [SCIDiagnostics privacyCount:@"Inbox refresh · pull reached -_pullToRefreshIfPossible"];
    if (SCIAskBeforeRefresh(self, _cmd)) return;

    %orig;
}

%end
