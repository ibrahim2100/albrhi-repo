#import "SCIPanelGate.h"
#import "SCILicense.h"
#import <dlfcn.h>

/// The panel's own preference domain. Both sides name it here rather than each spelling it
/// out: a typo on one side is a switch that appears to work and changes nothing.
static NSString *const kSCIPanelDomain = @"com.albrhi.panel";

/// One key per app, so the panel can write a decision about an app it has never seen a
/// tweak for, and so two tweaks in the same app are governed by the same switch — which is
/// what "turn this app off" means to the person reading it.
/// -1 not asked yet, 0 no, 1 yes. See SCIPanelAllowsThisApp for why this is not a dispatch_once.
static int sciGateAnswer = -1;

/// What the very first question of this process was answered with, kept apart from the cache
/// above because it must **not** move when a licence is entered.
///
/// It is what makes "activated" an honest word. A tweak that was allowed when the process started
/// has its hooks installed and comes to life the moment the gate is invalidated; one that was
/// refused installed nothing at `%ctor`, and no licence entered afterwards can put a hook in
/// retroactively. The screen said "close the app and open it again" to everybody because nothing
/// could tell those two apart — and telling somebody to relaunch when they do not have to is a
/// small lie that makes the true version of the sentence easy to ignore.
static int sciGateAtLaunch = -1;

static NSString *SCIPanelKeyForThisApp(void) {
    NSString *bundle = [[NSBundle mainBundle] bundleIdentifier];
    return bundle.length ? [@"app_enabled_" stringByAppendingString:bundle] : nil;
}

/// The short name a licence's `app:` scope uses for the tweak running in this process.
///
/// **From the bundle identifier, because that is the one thing the process knows about itself.**
/// A `#define` per tweak would be one more thing to forget when a tweak is added, and a tweak that
/// forgot it would silently accept a licence issued for a different app.
///
/// nil for anything not in the table, which `SCILicenseCoversProduct` answers as "any licence will
/// do" -- the right direction for a process this file has never heard of.
NSString *SCIPanelProductForThisApp(void) {
    static NSDictionary *table = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        table = @{
            @"com.burbn.instagram":         @"instagram",
            @"com.google.ios.youtube":      @"youtube",
            @"com.atebits.Tweetie2":        @"twitter",
            @"com.zhiliaoapp.musically":    @"tiktok",
        };
    });

    NSString *bundle = [[NSBundle mainBundle] bundleIdentifier];
    return bundle.length ? table[bundle] : nil;
}

/// Where this dylib is, and therefore where the jailbreak is.
///
/// Rootful is "/", rootless "/var/jb", and roothide a directory with a different random
/// name on every device — so a list of candidates is wrong on roothide by construction.
/// dladdr answers with the path this very code was loaded from, and the prefix is three
/// components above <prefix>/Library/MobileSubstrate/DynamicLibraries/X.dylib.
static NSString *SCIJailbreakPrefix(void) {
    Dl_info info = {0};
    if (dladdr((const void *)&SCIPanelKeyForThisApp, &info) == 0 || !info.dli_fname) return @"/";

    NSString *me = [NSString stringWithUTF8String:info.dli_fname];
    NSString *up = [[[me stringByDeletingLastPathComponent]     // DynamicLibraries
                          stringByDeletingLastPathComponent]     // MobileSubstrate
                          stringByDeletingLastPathComponent];    // Library
    return up.stringByDeletingLastPathComponent.length ? up.stringByDeletingLastPathComponent : @"/";
}

/// Where the answer came from, so a diagnostics page can say it.
static NSString *sciGateSource = nil;

///
/// Reads the switch the panel wrote.
///
/// **CFPreferences alone did not work, and that is what this file is really about.** The
/// panel runs inside the Settings app and writes the domain there; this code runs inside
/// Instagram or YouTube, which are sandboxed, and a sandboxed process asking cfprefsd for
/// another application's domain is answered with nothing rather than with an error. So the
/// tweak read an absence, and an absence means "on" — which is exactly what was reported:
/// the switch moved, and nothing changed in the app.
///
/// The file is therefore read directly. On a jailbroken device the sandbox permits it, and
/// unlike the daemon it cannot quietly decide the question belongs to a different container.
/// CFPreferences is still tried first because where it does work it is the cheaper answer
/// and it sees a value that has been written but not yet flushed to disk.
///
/// Whether Albrhi Panel is on this device at all.
///
/// **Asked so that a tweak never provisions an identity the panel is going to provision.** On a
/// jailbreak the licence lives in the panel's domain and one activation covers every tweak; the
/// per-app fallback exists only for a dylib injected into an IPA, where that domain cannot be
/// read. Deciding between the two by "did my write come back" is not enough on its own: a
/// sandboxed write is *redirected* into the app's own container, and reading it back there
/// succeeds — so an app that provisioned before the panel did would take an identity of its own
/// and quietly stop sharing the phone's licence.
///
/// The panel's own preference file answers it. Its presence means a panel wrote something here,
/// which means this device has one and the identity is its business.
BOOL SCIPanelIsInstalled(void) {
    NSString *leaf = [NSString stringWithFormat:@"var/mobile/Library/Preferences/%@.plist",
                      kSCIPanelDomain];

    NSMutableArray<NSString *> *candidates = [NSMutableArray array];
    [candidates addObject:[@"/" stringByAppendingPathComponent:leaf]];

    NSString *prefix = SCIJailbreakPrefix();
    if (prefix.length > 1) [candidates addObject:[prefix stringByAppendingPathComponent:leaf]];

    for (NSString *path in candidates) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) return YES;
    }
    return NO;
}

/// Whichever plist type the panel actually wrote for this key -- an NSNumber for a
/// switch, an NSString for something like the preferred-microphone choice -- or nil
/// once every place this looks has been checked and nothing is there.
///
/// Both SCIPanelReadBool and SCIPanelReadString go through this one lookup rather than
/// each repeating the CFPreferences-then-file dance: the shape of *where* an answer can
/// be found does not depend on the shape of the answer itself, and two copies of that
/// two-step lookup are two places for the fallback path to drift out of sync.
static id SCIPanelCopyRawValue(NSString *key) {
    // 1. The daemon. Correct where the sandbox allows it, and free when it does not.
    CFPropertyListRef value = CFPreferencesCopyAppValue(
        (__bridge CFStringRef)key, (__bridge CFStringRef)kSCIPanelDomain);

    if (value) {
        sciGateSource = @"preferences daemon";
        return (__bridge_transfer id)value;
    }

    // 2. The file itself. The panel writes through CFPreferences from the Settings app, so
    //    the plist lands in the real /var/mobile tree; the jailbreak-prefixed path is tried
    //    as well because a rootless or roothide bootstrap can put it under its own root.
    NSString *leaf = [NSString stringWithFormat:@"var/mobile/Library/Preferences/%@.plist",
                      kSCIPanelDomain];

    NSMutableArray<NSString *> *candidates = [NSMutableArray array];
    [candidates addObject:[@"/" stringByAppendingPathComponent:leaf]];

    NSString *prefix = SCIJailbreakPrefix();
    if (prefix.length > 1) {
        [candidates addObject:[prefix stringByAppendingPathComponent:leaf]];
    }

    for (NSString *path in candidates) {
        NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:path];
        id stored = plist[key];
        if (stored) {
            sciGateSource = path;
            return stored;
        }
    }

    // Nothing written anywhere. Said as its own answer rather than folded into the
    // fallback: "never switched off" and "switched off and unreadable" are the two
    // explanations this whole file exists to separate.
    sciGateSource = [NSString stringWithFormat:@"nothing written (looked in %lu places)",
                     (unsigned long)candidates.count];
    return nil;
}

BOOL SCIPanelReadBool(NSString *key, BOOL fallback) {
    id value = SCIPanelCopyRawValue(key);
    return [value isKindOfClass:[NSNumber class]] ? [value boolValue] : fallback;
}

NSString *SCIPanelReadString(NSString *key, NSString *fallback) {
    id value = SCIPanelCopyRawValue(key);
    return [value isKindOfClass:[NSString class]] ? value : fallback;
}

double SCIPanelReadNumber(NSString *key, double fallback) {
    id value = SCIPanelCopyRawValue(key);
    return [value isKindOfClass:[NSNumber class]] ? [value doubleValue] : fallback;
}

BOOL SCIPanelAllowsApp(NSString *identifier) {
    // No identity, no question, no injection. Consistent with the opt-in reading below,
    // and it cannot strand anyone: the injection filters bind by bundle identifier, so a
    // process with none was never going to load this dylib in the first place.
    if (!identifier.length) return NO;

    // **Absent reads as off, and this is a reversal.**
    //
    // It used to read as on, and the argument was that a device which never opened the
    // panel should keep the tweak it installed deliberately. That argument holds for
    // somebody who installed one tweak for one app. It stopped holding when com.albrhi
    // became the front door: installing it now patches Instagram, YouTube, X and Locket at
    // once, and reading silence as consent means four apps are modified by an install that
    // asked about none of them.
    //
    // So nothing is patched until it is asked for. The cost is real and is accepted: a
    // fresh install does nothing visible until the panel is opened, and the panel says so.
    // The cost of the other reading was worse and less visible.
    //
    // Persistence needs no code. The value lives in the panel's own plist, which dpkg does
    // not touch on upgrade and suite/DEBIAN/preinst does not remove -- so once switched on
    // it stays on across every update, and a deliberate off stays off just as firmly.
    // The master switch is asked first, so one handle really does stop everything rather than
    // stopping the tweaks that happen to route through the other entry point.
    if (!SCIPanelMasterEnabled()) return NO;

    return SCIPanelReadBool([@"app_enabled_" stringByAppendingString:identifier], NO);
}

//
// **One switch above all the others, and it is read where every tweak already asks.**
//
// When an app update breaks something, the answer today is eight switches or removing the
// package -- and that is the worst moment to be hunting for either. This is one value, read in
// the same call every tweak already makes, so nothing per-tweak had to change to honour it.
//
// **It defaults to on, and that is not the opt-in reading being reversed.** The per-app switch
// answers "did anyone ask for this app to be patched", where silence must not mean yes. This
// answers "has the user pulled the handle", and silence there means they have not -- an absent
// value that read as off would switch off every working install on the day it shipped.
//
BOOL SCIPanelMasterEnabled(void) {
    return SCIPanelReadBool(@"albrhi_master_enabled", YES);
}

BOOL SCIPanelAllowsThisApp(void) {
#ifdef SCI_SELFCONTAINED
    // The opt-in reading above is right for com.albrhi, which installs four apps' worth
    // of hooks in one go -- silence should not read as consent for all of them at once.
    // A self-contained sideload build is the case that reasoning was never about: one
    // tweak, chosen and installed deliberately, for one app, on a device that may have no
    // jailbreak on it at all. Albrhi Panel is a jailbreak package (PreferenceLoader has no
    // sideloaded equivalent this project ships), so it can never be installed there, the
    // switch can never be turned on, and the opt-in gate below would refuse forever --
    // every hook standing down on every single launch, silently, which is exactly what a
    // real report of "nothing works, not even the welcome screen" turned out to be.
    //
    // So this asks nothing and answers yes unconditionally, restoring the older
    // "installed it deliberately" reading for the one case that is still true of.
    //
    // **Corrected: the panel is not applicable, and the licence still is.**
    //
    // The paragraph above is right about the per-app switch and was wrong to answer the whole
    // question with it. `SCIPanelAllowsThisApp()` is the one gate every tweak here calls, so
    // returning YES from it skipped the licence as well -- and the builds that take this branch
    // are exactly the ones sold on their own and injected into an IPA, where there is no panel to
    // enter a key in either. `SCILicenseUI` is that missing screen, and this is the gate it feeds.
    //
    if (!SCILicenseAllowsProduct(SCIPanelProductForThisApp())) {
        sciGateSource = [NSString stringWithFormat:@"licence — %@", SCILicenseStatusLine()];
        return NO;
    }

    sciGateSource = @"self-contained build — licensed";
    return YES;
#else
    //
    // **Answered once, and answerable again — which it was not, and that is a real bug this
    // shipped with.**
    //
    // A `dispatch_once` here means the first question of the process decides for its whole life.
    // On a jailbreak that was harmless: the switch and the licence are both set in the panel,
    // before the app is opened. On a standalone or injected build it is exactly wrong — the app
    // is opened *first*, unlicensed, this answers no, and the answer is then frozen. Entering a
    // key on the licence screen changes nothing at all until the app is killed and reopened.
    //
    // What that looks like from the outside is precisely what was reported: activate, then toggle
    // any setting and nothing happens. Instagram and YouTube ask this gate inside every
    // preference read, so every setting reads as off; TikTok and X ask it once in `%ctor` and
    // install no hooks at all.
    //
    // So the answer is cached rather than frozen, and `SCIPanelGateInvalidate()` drops it. The
    // hooks a `%ctor` did not install still cannot appear retroactively -- the licence screen says
    // to reopen the app for that -- but every tweak that reads its preferences through this gate
    // starts working the moment a licence is entered.
    //
    if (sciGateAnswer >= 0) return sciGateAnswer == 1;

    // `__block`, because the decision is written from inside the block below. The block itself is
    // kept rather than flattened into straight-line code so the early `return`s inside it stay
    // exactly as they were when this was a dispatch_once -- rewriting eight exits into a chain of
    // ifs is how a gate quietly changes meaning.
    __block BOOL allowed = NO;
    {
        void (^decide)(void) = ^{
        if (!SCIPanelMasterEnabled()) {
            sciGateSource = @"master switch is off";
            return;
        }

        NSString *key = SCIPanelKeyForThisApp();
        if (!key) return;   // no bundle id to ask about; stays off, as above

        if (!SCIPanelReadBool(key, NO)) return;

        //
        // **The licence, asked here and nowhere else.**
        //
        // Every tweak in this repository already calls this one function before installing a
        // single hook, so the licence needed no change in any of them -- the same reason the
        // master switch was put here rather than added to eight `%ctor`s.
        //
        // `SCILicenseAllows()` answers YES whenever enforcement is switched off, which is the
        // shipped default, so this line changes nothing for anybody until a key exists to
        // enter. And the check-in that can revoke a key is started, never waited on: a
        // licence check that can hold up a launch will one day hold up every launch.
        //
        //
        // **Off the launch, like everything else this project has had to move.**
        //
        // The call is asynchronous and always has been, but starting it means building a URL
        // session inside whatever moment the gate is first asked -- which for a tweak whose
        // preferences are read from a `%ctor` is the launch itself. Five reports from a device
        // that would not open show our constructor finishing and then nothing of ours running at
        // all, so nothing here is proven to be the cause; what is true is that this is the last
        // thing we do in a window the app has not finished, and this project's own rule is that
        // a tweak does not belong in that window.
        //
        // A minute after the app is active is soon enough: the licence is good for seven days and
        // the grace period is a day, so nothing about it is urgent to the second.
        //
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60 * NSEC_PER_SEC)),
                       dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            SCILicenseCheckInIfDue();
        });

        // Scope, not merely validity: a licence issued for one tweak must not switch on the
        // other three. `SCILicenseAllowsProduct` answers both halves, and answers the second one
        // as yes for a licence whose scope this build does not recognise.
        if (!SCILicenseAllowsProduct(SCIPanelProductForThisApp())) {
            sciGateSource = [NSString stringWithFormat:@"licence — %@", SCILicenseStatusLine()];
            return;
        }

            allowed = YES;
        };

        decide();
    }

    sciGateAnswer = allowed ? 1 : 0;
    if (sciGateAtLaunch < 0) sciGateAtLaunch = sciGateAnswer;
    return allowed;
#endif
}

//
// Forgets the cached answer, so the next question is asked afresh.
//
// Called when a licence is entered or removed. Nothing else invalidates it: the per-app switch is
// set in the panel, which is a different process, and a tweak that re-read it constantly would be
// asking cfprefsd about another application's domain on every preference read.
BOOL SCIPanelGateWasAllowedAtLaunch(void) {
    // Never asked at all is not the same as refused: a screen reached before anything queried the
    // gate should not claim the tweak stood down. The honest answer for "unknown" is the cautious
    // one, since telling somebody to relaunch costs them a moment and not doing so costs them a
    // feature they think is broken.
    return sciGateAtLaunch == 1;
}

void SCIPanelGateInvalidate(void) {
    sciGateAnswer = -1;
}

NSString *SCIPanelGateReport(void) {
    // Asked through the gate so the answer and the account of it can never disagree.
    BOOL allowed = SCIPanelAllowsThisApp();

    return [NSString stringWithFormat:@"%@ — %@",
            allowed ? @"on" : @"off",
            sciGateSource ?: @"not consulted"];
}
