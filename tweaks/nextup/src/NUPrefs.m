#import "NUPrefs.h"
#import <os/lock.h>
#import <notify.h>

#pragma mark - notify_state token

// One registration per process for the shared toggle word. Registering with
// notify_register_check gives a token usable for both get_state and set_state; the
// STATE itself is global to the name, so Settings' set_state is visible here.
static int NUStateToken(void) {
    static int token = -1;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        if (notify_register_check(kNUStateNotify, &token) != NOTIFY_STATUS_OK) token = -1;
    });
    return token;
}

static BOOL NUStateRead(uint64_t *out) {
    int t = NUStateToken();
    if (t == -1) return NO;
    uint64_t s = 0;
    if (notify_get_state(t, &s) != NOTIFY_STATUS_OK) return NO;
    *out = s;
    return YES;
}

#pragma mark - CFPreferences fallback (persisted; reliable at process start)

// Cached so the token-invalid path (pre-publish / just after reboot) doesn't hit cfprefsd
// on every layout. Once Settings publishes the token, reads never reach here.
static NSMutableDictionary<NSString *, NSNumber *> *gCFCache;
static os_unfair_lock gLock = OS_UNFAIR_LOCK_INIT;

// `fresh`: Settings must CFPreferencesAppSynchronize before reading (its own writes);
// passive readers must not (cross-process cache).
static BOOL NUReadCF(NSString *key, BOOL def, BOOL fresh) {
    if (!fresh) {
        os_unfair_lock_lock(&gLock);
        if (!gCFCache) gCFCache = [NSMutableDictionary new];
        NSNumber *c = gCFCache[key];
        if (c) { BOOL v = c.boolValue; os_unfair_lock_unlock(&gLock); return v; }
        os_unfair_lock_unlock(&gLock);
    } else {
        CFPreferencesAppSynchronize(CFSTR(kNUPrefsDomain));
    }
    Boolean present = false;
    Boolean value = CFPreferencesGetAppBooleanValue((__bridge CFStringRef)key,
                                                    CFSTR(kNUPrefsDomain), &present);
    BOOL result = present ? (BOOL)value : def;
    if (!fresh) {
        os_unfair_lock_lock(&gLock);
        gCFCache[key] = @(result);
        os_unfair_lock_unlock(&gLock);
    }
    return result;
}

#pragma mark - Public

BOOL NUPrefBool(NSString *key, BOOL def) {
    uint64_t s = 0;
    if (NUStateRead(&s) && (s & kNUStateValidBit)) {
        uint64_t bit = NUStateBitForKey(key);
        // Only trust bits the publisher knew — see kNUStateKnownShift in NUPrefs.h.
        if (bit && (s & (bit << kNUStateKnownShift))) return (s & bit) != 0;
    }
    return NUReadCF(key, def, /*fresh=*/NO);
}

///
/// **Opt-in, and this is the port's own change to upstream's behaviour.**
///
/// NextUp 3 fails open: no plist means every switch reads YES, so a fresh install works
/// immediately. That is right for a tweak somebody installed on purpose, one app, one
/// feature — and it is the reading this repository already abandoned once, for a reason
/// that applies here harder than it did there. `SCIPanelGate.h` states it: absence must
/// read as *off*, because Albrhi installs across apps the user never asked about.
///
/// This one injects into SpringBoard and five media apps and draws into the Lock Screen.
/// Defaulting all of that on the moment the package lands is the opposite of what this
/// project promises, and it was reported as wrong on the first install.
///
/// Only the master is flipped. The surfaces and the per-app switches keep upstream's
/// YES, so turning the one switch on gives a working tweak rather than a scavenger hunt
/// through nine more — and turning it off still stops everything, which is what the
/// switch is for.
BOOL NUMasterEnabled(void) { return NUPrefBool(@"Enabled", NO); }

void NUPrefsObserve(dispatch_block_t onChange) {
    static int token;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        notify_register_dispatch(kNUStateNotify, &token, dispatch_get_main_queue(), ^(int t) {
            os_unfair_lock_lock(&gLock);
            [gCFCache removeAllObjects]; // token drives reads now; drop any stale fallback too
            os_unfair_lock_unlock(&gLock);
            if (onChange) onChange();
        });
    });
}

void NUPrefsPublishState(void) {
    // Build the word from the freshly-written plist (this is Settings' own process, so the
    // read is reliable), stamp it valid, publish, and signal.
    uint64_t mask = kNUStateValidBit;
    // **`NO`, matching `NUMasterEnabled()` above — and publishing `YES` here defeated it
    // entirely.** A published bit outranks the CFPreferences default: `NUPrefBool` trusts any
    // bit the publisher stamped as known, and only falls back to the caller's default when the
    // word says nothing about that key. So on a fresh install, with nothing ever written to the
    // plist, SpringBoard's own `%ctor` re-seed published master = 1 and every reader in every
    // process then read the master as on. The opt-in default two dozen lines above was
    // unreachable, which is the whole of what 0.1.1 set out to change.
    //
    // The re-seed's own comment names the failure it must not cause -- "NUPrefBool would fall
    // back to the fail-open default" -- while supplying that same fail-open default itself. Any
    // default written here has to be the one the reader would have used, or the two disagree
    // precisely when nothing is stored, which is the only moment a default matters at all.
    if (NUReadCF(@"Enabled",           NO,  /*fresh=*/YES)) mask |= kNUStateMaster;
    if (NUReadCF(@"enabledMusic",      YES, YES))           mask |= kNUStateAppMusic;
    if (NUReadCF(@"enabledPodcasts",   YES, YES))           mask |= kNUStateAppPodcasts;
    if (NUReadCF(@"enabledYouTubeMusic", YES, YES))         mask |= kNUStateAppYouTubeMusic;
    if (NUReadCF(@"enabledYouTube",    YES, YES))           mask |= kNUStateAppYouTube;
    if (NUReadCF(@"enabledSpotify",    YES, YES))           mask |= kNUStateAppSpotify;
    if (NUReadCF(@"enabledSoundCloud", YES, YES))           mask |= kNUStateAppSoundCloud;
    if (NUReadCF(@"showLockScreen",    YES, YES))           mask |= kNUStateLockScreen;
    if (NUReadCF(@"showDynamicIsland", YES, YES))           mask |= kNUStateDynamicIsland;
    if (NUReadCF(@"showControlCenter", YES, YES))           mask |= kNUStateControlCenter;
    // Stamp every key this build knows into the known-keys mask (see kNUStateKnownShift in NUPrefs.h).
    mask |= (kNUStateMaster | kNUStateAppMusic | kNUStateAppPodcasts
             | kNUStateAppYouTubeMusic | kNUStateAppYouTube | kNUStateAppSpotify
             | kNUStateAppSoundCloud
             | kNUStateLockScreen | kNUStateDynamicIsland
             | kNUStateControlCenter) << kNUStateKnownShift;

    int t = NUStateToken();
    if (t != -1) notify_set_state(t, mask);
    notify_post(kNUStateNotify);
}
