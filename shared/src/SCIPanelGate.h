//
//  SCIPanelGate.h
//  Shared by every Albrhi tweak.
//
//  Whether this tweak is switched on for the app it has just been loaded into.
//
//  Albrhi Panel lists the apps on the device and offers a switch per app. The switch
//  cannot change what gets *injected* — rewriting a tweak's filter file needs root, and a
//  preference bundle runs as `mobile` — so it changes what the injected code *does*. The
//  dylib still loads; with the switch off it answers every preference as NO and every
//  feature stands down.
//
//  This is the same shape DLEasy uses, and the reason is the same: its filter names twenty
//  apps and cannot name a twenty-first, so per-app control had to be a runtime question.
//
//  **The preference is read through CFPreferences, not by opening the file.** A tweak runs
//  inside a sandboxed app and cannot read another process's plist off disk; cfprefsd sits
//  outside the sandbox and is reachable from inside it, which is why every tweak with a
//  settings bundle uses this call and not NSDictionary+contentsOfFile.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/// NO until the panel has been used to switch this app on.
///
/// **Opt-in, and this is a reversal of what it used to be.** Absence used to read as YES,
/// on the argument that somebody who installed a tweak deliberately should not have it
/// silently disabled. That argument was sound while a package meant one tweak for one app.
/// `com.albrhi` ended it: one install now carries Instagram, YouTube, X and Locket, and
/// reading silence as consent modifies four apps that the install never asked about.
///
/// Nothing is patched until it is asked for. A fresh install therefore does nothing visible
/// until Settings › Albrhi is opened — which the panel states plainly rather than leaving
/// anyone to wonder why their app looks untouched.
///
/// The answer persists by itself: the value lives in the panel's plist, which dpkg leaves
/// alone on upgrade and `suite/DEBIAN/preinst` does not remove. On stays on across updates;
/// a deliberate off stays off.
///
/// Read once and kept. The value is consulted on paths that run during layout and playback,
/// and a cross-process preference lookup on each of those would show. Changing the switch
/// therefore takes effect when the app is next launched, which the panel says plainly rather
/// than leaving anyone to wonder.
/// Albrhi's single master switch, written by the panel and read by every tweak.
///
/// Defaults to YES: an absent value means nobody has pulled the handle, not that everything
/// should stand down. The per-app switch, which defaults to NO, answers a different question --
/// see SCIPanelAllowsApp.
BOOL SCIPanelMasterEnabled(void);


/// The short name this process's tweak is known by in a licence's `app:` scope, or nil.
NSString *SCIPanelProductForThisApp(void);

/// Whether Albrhi Panel is installed on this device — read from its preference file rather than
/// from a write that may have been redirected into this app's own container.
BOOL SCIPanelIsInstalled(void);

/// Forgets the gate's cached answer.
///
/// The gate is asked once and remembered, which is right for a jailbreak — the switch and the
/// licence are set in the panel before the app opens. In a standalone or injected build the app is
/// opened first, unlicensed, and freezing that answer meant a licence entered afterwards changed
/// nothing until the app was killed. Call this whenever a licence is entered or removed.
void SCIPanelGateInvalidate(void);

BOOL SCIPanelAllowsThisApp(void);

/// Whether this process was allowed when it started — which decides whether a licence entered now
/// needs the app reopened. Hooks a `%ctor` did not install cannot appear retroactively; hooks that
/// are already in place start deciding differently the moment the gate is invalidated.
BOOL SCIPanelGateWasAllowedAtLaunch(void);

/// How that answer was arrived at, for a diagnostics page.
///
/// "The switch does nothing" has several explanations that look identical from the app —
/// the preference was never written, or it was written where this process cannot see it,
/// or it was read correctly and says on. They need different fixes, and the first version
/// of this could not tell them apart, which is why the switch appeared to do nothing and
/// nothing said why.
///
/// Returns something like "off (file: /var/mobile/…)" or "on (nothing written)".
NSString *SCIPanelGateReport(void);

/// The same question as SCIPanelAllowsThisApp, for an identity other than the process
/// asking it.
///
/// Written for Albrhi CarPlay, which is one dylib loaded into two processes
/// (SpringBoard and Camera) but one tweak in the panel's list, with one switch. The
/// per-app key SCIPanelAllowsThisApp derives from `[[NSBundle mainBundle]
/// bundleIdentifier]` would split it into two answers -- "is SpringBoard on" and "is
/// Camera on" -- for a question that only has one meaning. This asks about a name
/// instead of the calling process, so both sides of that dylib ask about the same key:
/// "app_enabled_com.albrhi.carplay", regardless of which of the two processes is asking.
///
/// Uncached, unlike SCIPanelAllowsThisApp: it is called for more than one identity in
/// principle, and a single process only ever calls it once at %ctor time, so the cost of
/// asking cfprefsd again is not worth a second cache to get wrong.
BOOL SCIPanelAllowsApp(NSString *identifier);

/// A preference the panel wrote for something other than the per-app on/off switch --
/// CarPlay's recording-audio toggle, say. Same domain, same cross-sandbox path as the
/// switch above; a different key because it answers a different question.
BOOL SCIPanelReadBool(NSString *key, BOOL fallback);

/// As above, for a preference that is not a plain on/off choice -- CarPlay's preferred
/// microphone is a string ("iphone", "car" or "automatic"), not a boolean.
NSString *SCIPanelReadString(NSString *key, NSString *fallback);

/// The same, for a number.
///
/// A `double` rather than an integer because the two things read this way are a duration in days
/// and a Unix timestamp, and a timestamp does not fit an `int` on every architecture this builds
/// for. Absent, or stored as something that is not a number, reads as `fallback`.
double SCIPanelReadNumber(NSString *key, double fallback);

#ifdef __cplusplus
}
#endif
