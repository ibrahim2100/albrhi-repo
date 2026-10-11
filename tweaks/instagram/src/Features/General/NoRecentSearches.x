#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../../Compat/SCIResolve.h"
#import <objc/runtime.h>

// Disable logging of searches at server-side
%group SCIgIGSearchEntityRouter

%hook IGSearchEntityRouter
- (id)initWithUserSession:(id)arg1 analyticsModule:(id)arg2 shouldAddToRecents:(BOOL)shouldAddToRecents {
    if ([SCIUtils getBoolPref:@"no_recent_searches"]) {
        SCILogV(@"[SCInsta] Disabling recent searches");

        shouldAddToRecents = false;
    }
    
    return %orig(arg1, arg2, shouldAddToRecents);
}
%end

%end


// Most in-app search bars
%group SCIgIGRecentSearchStore

%hook IGRecentSearchStore
- (id)initWithDiskManager:(id)arg1 recentSearchStoreConfiguration:(id)arg2 {
    if ([SCIUtils getBoolPref:@"no_recent_searches"]) {
        SCILogV(@"[SCInsta] Disabling recent searches");

        return nil;
    }

    return %orig;
}
- (BOOL)addItem:(id)arg1 {
    if ([SCIUtils getBoolPref:@"no_recent_searches"]) {
        SCILogV(@"[SCInsta] Disabling recent searches");

        return nil;
    }

    return %orig;
}
%end

%end


// Recent dm message recipients search bar
%hook IGDirectRecipientRecentSearchStorage
- (id)initWithDiskManager:(id)arg1 directCache:(id)arg2 userStore:(id)arg3 currentUser:(id)arg4 featureSets:(id)arg5 {
    if ([SCIUtils getBoolPref:@"no_recent_searches"]) {
        SCILogV(@"[SCInsta] Disabling recent searches");

        return nil;
    }

    return %orig;
}
%end

///
/// **410's initialiser for the same storage has other arguments** -- `initWithDiskManager:directRepo:
/// userMap:currentUser:launcherSet:` -- so the hook above never attached on 410 and the recent
/// recipients of the DM search bar kept being saved. Installed only where the class declares exactly this
/// selector, so 439 and 441 (which have the other signature) are not touched.
///
%group SCIgDirectRecentStorage410
%hook IGDirectRecipientRecentSearchStorage
- (id)initWithDiskManager:(id)arg1 directRepo:(id)arg2 userMap:(id)arg3 currentUser:(id)arg4 launcherSet:(id)arg5 {
    if ([SCIUtils getBoolPref:@"no_recent_searches"]) {
        SCILogV(@"[SCInsta] Disabling recent searches (410 recipient storage)");

        return nil;
    }

    return %orig;
}
%end
%end

%ctor {
    // The hooks outside the groups below. Logos writes this call itself for
    // a file with no %ctor -- and stops the moment there is one, so leaving
    // it out would silence every hook this file did not need to convert.
    %init;

    Class searchEntityRouter = SCIResolveClass(@"IGSearchEntityRouter");
    if (searchEntityRouter) %init(SCIgIGSearchEntityRouter, IGSearchEntityRouter = searchEntityRouter);
    Class recentSearchStore = SCIResolveClass(@"IGRecentSearchStore");
    if (recentSearchStore) %init(SCIgIGRecentSearchStore, IGRecentSearchStore = recentSearchStore);

    Class recipientStorage = SCIResolveClass(@"IGDirectRecipientRecentSearchStorage");
    SEL variant410 = NSSelectorFromString(@"initWithDiskManager:directRepo:userMap:currentUser:launcherSet:");
    if (recipientStorage && class_getInstanceMethod(recipientStorage, variant410)) {
        %init(SCIgDirectRecentStorage410, IGDirectRecipientRecentSearchStorage = recipientStorage);
    }
}
