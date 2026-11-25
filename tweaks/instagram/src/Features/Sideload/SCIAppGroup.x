//
//  SCIAppGroup.x
//  Albrhi for Instagram
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "SCIAppGroup.h"

///
/// **The second half of "signed in until the app is closed".** The first half is the keychain (`SCIKeychain.m`). The other place Instagram keeps what
/// it needs across launches is its *app group*, `group.com.burbn.instagram`: a shared folder and a shared `NSUserDefaults` suite. A re-signed copy
/// does not hold that group, so `-[NSFileManager containerURLForSecurityApplicationGroupIdentifier:]` answers nil and a group suite does not persist
/// (cfprefsd refuses it); Instagram then loses what it wrote there, and code that expects a folder reads nil. The same two places are where the
/// public `zxPluginsInject` shim (the "sideload fix" RyukGram ships; unlicensed, read for architecture only, nothing copied) redirects: the group's
/// folder becomes a folder inside the app, and a group suite is opened over that folder.
///
/// Here, **only when the system answers "no container"** (a group the app really holds is left alone, so a store build, a jailbreak or a correctly
/// signed copy see no difference). The folder is `<Application Support>/AlbrhiAppGroups/<group>`.
///

static NSObject *SCIAppGroupLock(void) {
    static NSObject *lock;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ lock = [[NSObject alloc] init]; });
    return lock;
}

static NSMutableDictionary<NSString *, id> *sReal;          // group -> the real container, or NSNull when the system gave none
static NSMutableOrderedSet<NSString *> *sFallbackGroups;
static NSUInteger sAsked = 0, sGiven = 0, sDefaultsRedirected = 0, sDefaultsSeen = 0;
static NSString *sState = nil;

NSURL *SCIAppGroupFallbackContainer(NSString *group) {
    NSString *base = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
    if (!base.length || !group.length) return nil;
    NSString *path = [[base stringByAppendingPathComponent:@"AlbrhiAppGroups"] stringByAppendingPathComponent:group];
    [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:NULL];
    return [NSURL fileURLWithPath:path isDirectory:YES];
}

/// Did the system give this group a container? Asked once per group; asking goes through the hook below, which writes the answer down.
static BOOL SCIGroupIsHeld(NSString *group) {
    @synchronized (SCIAppGroupLock()) { if (sReal[group]) return ![sReal[group] isKindOfClass:[NSNull class]]; }
    (void)[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:group];
    @synchronized (SCIAppGroupLock()) { return sReal[group] && ![sReal[group] isKindOfClass:[NSNull class]]; }
}

%group SCIAppGroupFiles
%hook NSFileManager

- (NSURL *)containerURLForSecurityApplicationGroupIdentifier:(NSString *)group {
    NSURL *real = %orig;
    if (![group isKindOfClass:[NSString class]] || !group.length) return real;
    @synchronized (SCIAppGroupLock()) {
        if (!sReal) sReal = [NSMutableDictionary dictionary];
        sReal[group] = real ?: (id)[NSNull null];
        sAsked++;
    }
    if (real) return real;
    NSURL *ours = SCIAppGroupFallbackContainer(group);
    if (!ours) return real;
    @synchronized (SCIAppGroupLock()) {
        sGiven++;
        if (!sFallbackGroups) sFallbackGroups = [NSMutableOrderedSet orderedSet];
        [sFallbackGroups addObject:group];
    }
    return ours;
}

%end
%end

// The shared-defaults suite. `-initWithSuiteName:` reaches this private initialiser with the group's container; for a group the app does not hold
// there is none, and the suite then never reaches disk. It is installed only where the class declares exactly this selector.
%group SCIAppGroupDefaults
%hook NSUserDefaults

- (id)_initWithSuiteName:(NSString *)suiteName container:(NSURL *)container {
    if ([suiteName isKindOfClass:[NSString class]] && [suiteName hasPrefix:@"group."]) {
        @synchronized (SCIAppGroupLock()) { sDefaultsSeen++; }
        if (!SCIGroupIsHeld(suiteName)) {
            NSURL *ours = SCIAppGroupFallbackContainer(suiteName);
            if (ours) {
                @synchronized (SCIAppGroupLock()) { sDefaultsRedirected++; }
                return %orig(suiteName, ours);
            }
        }
    }
    return %orig;
}

%end
%end

void SCIAppGroupInstall(void) {
    if (sState) return;
    NSMutableArray<NSString *> *done = [NSMutableArray array];
    %init(SCIAppGroupFiles);
    [done addObject:@"NSFileManager group container"];

    Method init = class_getInstanceMethod([NSUserDefaults class], NSSelectorFromString(@"_initWithSuiteName:container:"));
    const char *types = init ? method_getTypeEncoding(init) : NULL;
    if (types && strncmp(types, "@", 1) == 0) {
        %init(SCIAppGroupDefaults);
        [done addObject:@"NSUserDefaults group suite"];
    } else {
        [done addObject:[NSString stringWithFormat:@"NSUserDefaults group suite SKIPPED (%@)", types ? [NSString stringWithUTF8String:types] : @"selector absent"]];
    }
    sState = [@"installed: " stringByAppendingString:[done componentsJoinedByString:@", "]];
}

NSArray<NSString *> *SCIAppGroupReportLines(void) {
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    [lines addObject:sState ? [@"app groups " stringByAppendingString:sState] : @"app groups: not installed (a jailbreak package: the app is signed the way the store signed it)"];
    if (!sState) return lines;
    NSUInteger asked, given, seen, redirected; NSArray *groups;
    @synchronized (SCIAppGroupLock()) { asked = sAsked; given = sGiven; seen = sDefaultsSeen; redirected = sDefaultsRedirected; groups = sFallbackGroups.array ?: @[]; }
    [lines addObject:[NSString stringWithFormat:@"group folders asked for %lu, answered with none by the system and given one of ours %lu; group defaults suites opened %lu, pointed at our folder %lu",
                      (unsigned long)asked, (unsigned long)given, (unsigned long)seen, (unsigned long)redirected]];
    if (groups.count) [lines addObject:[@"groups the signature does not hold: " stringByAppendingString:[groups componentsJoinedByString:@", "]]];
    return lines;
}
