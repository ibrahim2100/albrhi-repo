#import <substrate.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../../Settings/SCIDiagnosticsViewController.h"
#import "../../Compat/SCIResolve.h"

///
/// Watches stories without telling their author.
///
/// The distinction that matters here, and that the previous version got wrong: a
/// story being *seen* is two separate things. Instagram keeps a local record — which
/// is what greys out the ring and stops a story coming back round — and it uploads a
/// receipt, which is what the author sees. Only the second one is anybody else's
/// business.
///
/// The version before this emptied IGStorySeenState as it was built. That object
/// backs both jobs, so it silenced the author *and* wiped the local record, which is
/// why stories kept reappearing until the eye button was pressed. Nothing is done to
/// it now; the local record fills exactly as Instagram intends.
///
/// The upload is blocked instead, at each build's own chokepoint:
///
///   IGStorySeenStateUploader's `_networker`   both builds — the request has no
///                                             networker to go out on
///   IGStoryPendingSeenStateStore -_uploadSeenState:   the newer build's Swift store,
///                                             found through SCIResolveClass
///
/// **The field, not the getter, and a 439 report is what said so.** This used to hook
/// `-networker` and return nil. The report read `IGStorySeenStateUploader -networker:
/// installed` and `Seen receipts blocked: 0` side by side while the receipts went out —
/// installed, and never once asked. The uploader declares three methods (`init`,
/// `-networker`, `.cxx_destruct`), so its upload is written elsewhere and reads `_networker`
/// straight out of the object, which no getter hook sees. It is the bypassOnesie lesson from
/// the YouTube tweak, one app over: **a stored value is true for every reader; a getter
/// override is true only for the readers that ask.**
///
/// So the field itself is cleared while hiding is on and put back while it is off, and the
/// eye button restores it for the moment it needs. The field is found by *identity* — the ivar
/// holding the very object `-initWithUserSessionPK:networker:` was handed — rather than by
/// its name, so a build that renames it is still found, and a build where nothing matches
/// says so instead of pretending. InstaPlus reaches the same conclusion by refusing to build
/// the uploader at all (read for architecture only; nothing copied), which cannot be undone
/// for one story when the eye is pressed, and cannot be undone at all without a relaunch.
///
/// Every request that goes out is also looked at once, at `IGNetworkDispatcher` — the head
/// of Instagram's network layer chain — and any whose path mentions "seen" is counted, with
/// the path. Looked at, never changed: that line exists so that if a receipt still leaves by
/// some route nobody has found yet, the report names the route in one round.
///

/// Set by the eye button in StorySeenButton.x. While true the receipt is let
/// through, so the story being watched right now does register with its author.
extern BOOL storySeenOverrideEnabled;

/// Posted when a seen receipt is actually allowed out.
NSString * const SCIStorySeenSentNotification = @"SCIStorySeenSent";

/// Whether the receipt should be blocked right now.
static BOOL SCIShouldBlockSeenReceipt(void) {
    if (![SCIUtils getBoolPref:@"no_seen_receipt"]) return NO;

    return !storySeenOverrideEnabled;
}

// MARK: - The uploader's way out

// A seen report being *built* while the override is on means the eye was pressed and
// this one is going out. Announced from here as well as from the uploader below: that
// class is three methods deep and its -networker is evidently not asked for on every
// build, which is why the button never turned green. This object is constructed on
// both, so the signal arrives either way. Nothing is changed — %orig is untouched.
%hook IGStorySeenState

- (id)initWithReelSeenDictionary:(id)reelSeen
              liveSeenDictionary:(id)liveSeen
           reelSkippedDictionary:(id)reelSkipped
           liveSkippedDictionary:(id)liveSkipped
                 containerModule:(id)containerModule
                    pushCategory:(id)pushCategory
                    forceSeenIds:(id)forceSeenIds {

    if (storySeenOverrideEnabled && [SCIUtils getBoolPref:@"no_seen_receipt"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:SCIStorySeenSentNotification
                                                            object:nil];

        // How many reels the receipt the eye lets out actually carries. One is the story on
        // screen; more means the stories watched while hidden were queued and are leaving with
        // it -- which would make the eye a way of undoing the setting, and is worth knowing
        // from a number rather than from somebody noticing.
        NSUInteger reels = [reelSeen isKindOfClass:[NSDictionary class]] ? [(NSDictionary *)reelSeen count] : 0;
        [SCIDiagnostics privacyNote:@"Story views · reels in the last eye-pressed receipt"
                              value:[NSString stringWithFormat:@"%lu", (unsigned long)reels]];
    }

    return %orig;
}

%end

// MARK: - The uploader's field

/// Every uploader built this session, weakly — normally one per signed-in account.
static NSHashTable *sUploaders = nil;
static const void *kSCIRealNetworker = &kSCIRealNetworker;
static NSString *sNetworkerIvarName = nil;

/// The object ivar of `object` currently holding `value`, found by identity.
///
/// object_getIvar on an object-typed ivar reads a pointer and runs nothing, which is why this
/// is safe to do on a class this code does not own: no getter, no KVC, no Swift accessor.
static Ivar SCIIvarHolding(id object, id value) {
    for (Class cls = object_getClass(object); cls && cls != [NSObject class]; cls = class_getSuperclass(cls)) {
        unsigned int count = 0;
        Ivar *fields = class_copyIvarList(cls, &count);
        Ivar found = NULL;

        for (unsigned int i = 0; fields && i < count && !found; i++) {
            const char *type = ivar_getTypeEncoding(fields[i]);
            if (!type || type[0] != '@') continue;
            if (object_getIvar(object, fields[i]) == value) found = fields[i];
        }

        if (fields) free(fields);
        if (found) return found;
    }
    return NULL;
}

/// Puts every known uploader's networker where it belongs right now: gone while receipts are
/// being withheld, back while they are not. Called whenever that answer can change -- a new
/// uploader, the eye button, the setting itself.
void SCIStorySeenSyncUploaders(void) {
    if (!sUploaders) return;

    BOOL block = SCIShouldBlockSeenReceipt();
    NSArray *uploaders;
    @synchronized (sUploaders) { uploaders = sUploaders.allObjects; }

    for (id uploader in uploaders) {
        id real = objc_getAssociatedObject(uploader, kSCIRealNetworker);
        if (!real || !sNetworkerIvarName) continue;

        Ivar field = class_getInstanceVariable(object_getClass(uploader), sNetworkerIvarName.UTF8String);
        if (!field) continue;

        id want = block ? nil : real;
        if (object_getIvar(uploader, field) == want) continue;

        // WithStrongDefault: the uploader was compiled under ARC and owns this field strongly,
        // so the old value is released and the new one retained exactly as its own code would.
        object_setIvarWithStrongDefault(uploader, field, want);
        [SCIDiagnostics privacyCount:block ? @"Story views · networker cleared" : @"Story views · networker restored"];
    }
}

%hook IGStorySeenStateUploader

- (id)initWithUserSessionPK:(id)pk networker:(id)networker {
    id uploader = %orig;
    if (!uploader || !networker) return uploader;

    Ivar field = SCIIvarHolding(uploader, networker);
    [SCIDiagnostics privacyCount:@"Story views · uploaders built"];

    if (!field) {
        // Said rather than assumed: every later "0 blocked" means something different when
        // the field was never found.
        [SCIDiagnostics privacyNote:@"Story views · networker field" value:@"not found — nothing holds the networker it was given"];
        return uploader;
    }

    sNetworkerIvarName = @(ivar_getName(field));
    [SCIDiagnostics privacyNote:@"Story views · networker field" value:sNetworkerIvarName];

    // Kept strongly beside the uploader, so taking it out of the field cannot free it.
    objc_setAssociatedObject(uploader, kSCIRealNetworker, networker, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    static dispatch_once_t once;
    dispatch_once(&once, ^{ sUploaders = [NSHashTable weakObjectsHashTable]; });
    @synchronized (sUploaders) { [sUploaders addObject:uploader]; }

    SCIStorySeenSyncUploaders();
    return uploader;
}

// Kept for any reader that does ask: it costs nothing, and the field alone would leave a
// getter caller holding the real networker.
- (id)networker {
    if (!SCIShouldBlockSeenReceipt()) {
        // Blocking is on but this one is being let through — the eye was pressed.
        // Announced so the button can show that the receipt really went, rather than
        // just that a tap was registered.
        if ([SCIUtils getBoolPref:@"no_seen_receipt"]) {
            [[NSNotificationCenter defaultCenter] postNotificationName:SCIStorySeenSentNotification
                                                                object:nil];
        }
        return %orig;
    }

    [SCIDiagnostics recordStorySeenIntercept];
    [SCIDiagnostics privacyCount:@"Story views · -networker asked, withheld"];
    SCILogV(@"[Albrhi] Withheld the networker a story seen receipt needed");

    return nil;
}

%end

// MARK: - The newer build's Swift store

// -_uploadSeenState: is where the newer build hands a batch of seen state off to be
// sent. Swallowing it leaves the batch collected locally and unsent — the ring still
// greys out, which is the whole point of not emptying the seen state itself.
//
// Bound at runtime rather than by %hook because Logos cannot name a Swift class, and
// skipped where the method is absent rather than added as one nothing calls.
static void (*orig_uploadSeenState)(id, SEL, id);

static void sci_uploadSeenState(id self, SEL _cmd, id seenState) {
    if (SCIShouldBlockSeenReceipt()) {
        [SCIDiagnostics recordStorySeenIntercept];
        [SCIDiagnostics privacyCount:@"Story views · Swift store upload swallowed"];
        SCILogV(@"[Albrhi] Swallowed a story seen upload");
        return;
    }

    if (orig_uploadSeenState) orig_uploadSeenState(self, _cmd, seenState);
}

// MARK: - Every request, looked at once

// Passive by design: %orig always runs, with the arguments it was given. Blocking here would
// mean returning no request token to a network layer whose callers were never written to get
// none, which is a crash waiting on the right caller -- the uploader's field is the block, and
// this is the witness.
%group SCIStorySeenWitness

%hook IGNetworkDispatcher

- (id)startRequest:(id)request policy:(id)policy callbacks:(id)callbacks {
    if ([SCIUtils getBoolPref:@"no_seen_receipt"] && [request respondsToSelector:@selector(URL)]) {
        NSURL *url = ((NSURL *(*)(id, SEL))objc_msgSend)(request, @selector(URL));
        NSString *path = [url isKindOfClass:[NSURL class]] ? url.path : nil;

        if (path && [path rangeOfString:@"seen" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            NSString *state = SCIShouldBlockSeenReceipt() ? @"went out while hidden" : @"went out, eye pressed";
            [SCIDiagnostics privacyCount:[NSString stringWithFormat:@"Request %@ · %@", state, path]];
        }
    }

    return %orig;
}

%end

%end

static void SCIStartSeenWitness(void) {
    static BOOL started = NO;
    if (started) return;

    Class dispatcher = objc_getClass("IGNetworkDispatcher");
    if (!dispatcher || !class_getInstanceMethod(dispatcher, @selector(startRequest:policy:callbacks:))) return;

    started = YES;
    %init(SCIStorySeenWitness);
    [SCIDiagnostics privacyNote:@"Story views · request witness" value:@"IGNetworkDispatcher -startRequest:policy:callbacks:"];
}

%ctor {
    @autoreleasepool {
        // Named because this file now has a %group: Logos only initialises the ungrouped hooks
        // by itself when there is no group to be told about, and says so as a build error.
        %init;

        // The dispatcher lives in FBSharedFramework. Asked for at load, and once more after
        // launch: a class the app certainly has can answer nil to a constructor that runs before
        // its image is registered, and "not in this build" and "asked too early" look the same.
        SCIStartSeenWitness();
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                          object:nil queue:nil
                                                      usingBlock:^(__unused NSNotification *note) {
            SCIStartSeenWitness();
            if (!objc_getClass("IGNetworkDispatcher")) {
                [SCIDiagnostics privacyNote:@"Story views · request witness" value:@"IGNetworkDispatcher: not in this build"];
            }
        }];

        // The setting can change while the app runs; the uploaders' field follows it.
        [[NSNotificationCenter defaultCenter] addObserverForName:NSUserDefaultsDidChangeNotification
                                                          object:nil queue:nil
                                                      usingBlock:^(__unused NSNotification *note) {
            SCIStorySeenSyncUploaders();
        }];

        // The known runtime name first, then a search if it stops matching.
        //
        // The literal is correct for 439 and 441 and was verified against both binaries, so
        // it is kept and tried first -- an answer already in hand beats a search that might
        // not find one. What the search adds is the build where the module moves: those
        // numbers are the lengths of the module and class names, so the literal alone would
        // stop matching with no error and no crash, and the receipt would quietly go out
        // again. Replacing the literal *with* the search, rather than putting it in front,
        // is what broke the reels download button.
        Class store = SCIResolveClassWithHint(@"IGStoryPendingSeenStateStore",
            @"_TtC26IGStoryPendingSeenStateKit28IGStoryPendingSeenStateStore");
        SEL upload = NSSelectorFromString(@"_uploadSeenState:");

        BOOL attached = NO;
        if (store && class_getInstanceMethod(store, upload)) {
            MSHookMessageEx(store, upload, (IMP)sci_uploadSeenState, (IMP *)&orig_uploadSeenState);
            attached = YES;
        }

        // Said whether it worked or not, and this is the point of it.
        //
        // Before this, a report showing no interceptions had two readings -- the hook is not
        // attached, or it is attached and the upload never came through it -- and those need
        // opposite fixes. The same ambiguity in the YouTube tweak's SABR section cost three
        // releases of guessing before the line that separated them was added.
        [SCIDiagnostics recordStorySeenHookAttached:attached
                                        resolvedTo:SCIResolvedNameFor(@"IGStoryPendingSeenStateStore")];
    }
}
