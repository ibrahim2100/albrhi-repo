//
//  SCITTProfileBackground.x
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "SCITTProfileBackground.h"
#import "../../Prefs.h"
#import "../../SCILog.h"

///
/// **The profile-background editor is already in TikTok; the app keeps it behind a server-side experiment.**
///
/// A small unlicensed tweak (`ProfileBanner`, by Nasser | NoTimeToChill) showed the idea -- four hooks, no code
/// carried over: this file was written from what TikTok 47.1.0's own binary says, read with
/// tools/objc-classes.py, a caller scan and `strings`, and the reference's table was only the list of places to look.
///
/// What the binary says:
///
///   * The feature is complete -- `TTKProfileBackgroundService`, a coordinator, crop, photo and video preview,
///     an education tooltip, an edit request and result -- and `TIKTOKProfileEditMainViewController` carries the
///     buttons and the cover view (`p_didTapProfileBackgroundChangeButton`, `p_runProfileBackgroundFlowWithBgInfo:
///     sourceView:`, ivars `_hasProfileBackgroundComponent`, `_hasProfileBackground`, `_profileBackgroundInfo`).
///   * Whether it is offered is decided by the server. `+[TTKABTest profileBgInAllowList]` and
///     `+profileBgEnableConsumptionGroup` (both `q16@0:8`) are read by one caller only,
///     `-[TTKProfileComponentDataController getRequestParamsWithParams:isCurrentUser:]`: **they are sent to
///     TikTok as parameters of the profile request**, which is what makes the answer the server's and not a local
///     switch. Forcing the first to 1 is telling TikTok this device is on the allow list.
///   * The editor shows the background controls when `p_resolveProfileBackgroundSnapshot` finds a
///     `TTKProfileComponentResponseModel -profileBackground` (a `TTKProfileBaseComponentModel`, whose only field is
///     the `bizData` dictionary) in the profile response. When the server did not send one, nothing appears.
///
/// So there are two hooks, and **each is a cost somebody should know about**:
///
///   1. The allow-list answer is sent to TikTok. That is something untrue about the device, the same kind of
///      thing the region choice is, and the row says so. It is off until somebody turns it on.
///   2. While -p_resolveProfileBackgroundSnapshot runs on this thread, and only then, a response with no background
///      component answers with an empty one, so the editor's controls exist. If TikTok's servers refuse the upload
///      for this account the editor will say so itself; nothing here pretends otherwise.
///
/// **Not run on a device.** Every class and encoding below was read from 47.1.0; whether the server accepts the
/// change for a given account is not something this machine can answer.
///

@interface TTKProfileBaseComponentModel : NSObject
- (void)setBizData:(id)bizData;
@end

static NSString *sciPBGState = nil;
static NSUInteger sciPBGAllowAnswered = 0, sciPBGComponentSupplied = 0, sciPBGEditorResolves = 0;

/// How many editor snapshot resolves are on this thread's stack. Thread-local: a background load of somebody else's
/// profile must never be handed a stand-in because the editor happens to be resolving on the main thread.
static _Thread_local NSUInteger sciPBGEditorDepth = 0;

static BOOL SCITTPBGHas(Class cls, BOOL meta, const char *selector, const char *encoding) {
    if (!cls) return NO;
    Method method = class_getInstanceMethod(meta ? object_getClass(cls) : cls, sel_registerName(selector));
    const char *types = method ? method_getTypeEncoding(method) : NULL;
    return types && strcmp(types, encoding) == 0;
}

%group SCITTProfileBgFlag
%hook TTKABTest
+ (long long)profileBgInAllowList {
    if (!SCIPrefEnabled(SCIPrefProfileBackground)) return %orig;
    sciPBGAllowAnswered++;
    return 1;
}
%end
%end

%group SCITTProfileBgEditor
%hook TIKTOKProfileEditMainViewController
- (void)p_resolveProfileBackgroundSnapshot {
    sciPBGEditorResolves++;
    sciPBGEditorDepth++;
    %orig;
    sciPBGEditorDepth--;
}
%end
%end

%group SCITTProfileBgComponent
%hook TTKProfileComponentResponseModel
- (id)profileBackground {
    id real = %orig;
    if (real || sciPBGEditorDepth == 0 || !SCIPrefEnabled(SCIPrefProfileBackground)) return real;

    Class componentClass = NSClassFromString(@"TTKProfileBaseComponentModel");
    id stand = [[componentClass alloc] init];
    if (!stand) return real;
    // An empty dictionary, not nil: the component exists and carries no background of its own yet.
    [stand setBizData:@{}];
    sciPBGComponentSupplied++;
    return stand;
}
%end
%end

NSString *SCITTProfileBackgroundReport(void) {
    return [NSString stringWithFormat:@"%@; switch %@; allow-list answered: %lu; editor opened: %lu; stand-in component given: %lu",
            sciPBGState ?: @"not installed",
            SCIPrefEnabled(SCIPrefProfileBackground) ? @"on" : @"off",
            (unsigned long)sciPBGAllowAnswered, (unsigned long)sciPBGEditorResolves, (unsigned long)sciPBGComponentSupplied];
}

void SCITTInstallProfileBackground(void) {
    NSMutableArray<NSString *> *installed = [NSMutableArray array];
    NSMutableArray<NSString *> *skipped = [NSMutableArray array];

    // The three decide separately: a build without one class must not cost the other two. Class methods are read from the
    // metaclass, and a hook on a selector the class does not declare would *add* it, so each waits for its encoding.
    if (SCITTPBGHas(NSClassFromString(@"TTKABTest"), YES, "profileBgInAllowList", "q16@0:8")) {
        %init(SCITTProfileBgFlag);
        [installed addObject:@"+TTKABTest profileBgInAllowList"];
    } else {
        [skipped addObject:@"+TTKABTest profileBgInAllowList"];
    }

    if (SCITTPBGHas(NSClassFromString(@"TIKTOKProfileEditMainViewController"), NO, "p_resolveProfileBackgroundSnapshot", "v16@0:8")) {
        %init(SCITTProfileBgEditor);
        [installed addObject:@"-p_resolveProfileBackgroundSnapshot"];
    } else {
        [skipped addObject:@"TIKTOKProfileEditMainViewController -p_resolveProfileBackgroundSnapshot"];
    }

    Class component = NSClassFromString(@"TTKProfileBaseComponentModel");
    if (SCITTPBGHas(NSClassFromString(@"TTKProfileComponentResponseModel"), NO, "profileBackground", "@16@0:8")
        && SCITTPBGHas(component, NO, "setBizData:", "v24@0:8@16")) {
        %init(SCITTProfileBgComponent);
        [installed addObject:@"-profileBackground (stand-in)"];
    } else {
        [skipped addObject:@"TTKProfileComponentResponseModel -profileBackground"];
    }

    sciPBGState = [NSString stringWithFormat:@"%@%@",
        installed.count ? [@"installed: " stringByAppendingString:[installed componentsJoinedByString:@", "]] : @"nothing installed",
        skipped.count ? [NSString stringWithFormat:@" — skipped: %@", [skipped componentsJoinedByString:@"; "]] : @""];
    SCILogV(@"[ProfileBackground] %@", sciPBGState);
}
