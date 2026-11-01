//
//  SCITTSearchHistory.x
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "SCITTSearchHistory.h"
#import "../../Prefs.h"
#import "../../SCILog.h"

///
/// **Hiding the search history is not forbidding it, and not erasing it.**
///
/// The history keeps being written exactly as before -- turning the switch off brings back everything, including what was searched while
/// it was on. What changes is what the *readers* are told: `TTKSearchHistoryManager`'s public `fetch…` family and the shop search's
/// `TTKECSearchHistoryManager -getHistoryKeywords…` answer an empty array, so the search page draws no history and the suggestion
/// request (`AWESearchSugManager +addHistoryWords:historyTimers:toParams:`, `TTKECSearchSugViewModel -addHistoryWords:toParams:`) is
/// sent without the person's past queries in it.
///
/// **The write path was kept out of it on purpose.** The manager's own `p_…` methods (`p_fetchHistoriesInfoWithKey:filterType:`,
/// `p_historyListFromFileForKey:filterType:`) are what saving and deleting read, and they are not hooked: an empty answer there would let
/// a save overwrite the stored list with one entry. The public family is what the callers outside the manager use
/// (`AWESearchViewController -searchBarTextFieldTouchDown:`, `AWESearchSugViewController`, `TTKECSearchEntryAdapterCache`,
/// `AWEHotSearchManager`, `TTKGeneralSearchPlaceholderViewController -p_lynxHistoryWords`), measured with `callers.py` on 47.4.0.
///
/// The answer is an empty **mutable** array: a caller that appends to what it was handed must not meet an immutable one.
///
/// Not hidden: the history of the messages search (`AWEIMSearchHistoryDataManager`), the profile search
/// (`TTKProfileSearchHistoryManager`) and the inbox search (`TTKInboxSearchHistoryDataManager`). Their getters (`historys`,
/// `historyModels`, `userRecords`) are also what their own `saveHistory:` merges into, so an empty answer would erase on the next save.
///
/// Not run on a device.
///

static NSString *sciSearchState = nil;
static NSUInteger sciSearchReads = 0;

static BOOL SCITTSearchHas(Class cls, const char *selector, const char *encoding) {
    if (!cls) return NO;
    Method method = class_getInstanceMethod(cls, sel_registerName(selector));
    const char *types = method ? method_getTypeEncoding(method) : NULL;
    return types && strcmp(types, encoding) == 0;
}

%group SCITTSearchHistoryGroup
%hook TTKSearchHistoryManager

- (id)fetchHistoriesWordsWithKey:(id)key {
    if (!SCIPrefEnabled(SCIPrefHideSearchHistory)) return %orig;
    sciSearchReads++;
    return [NSMutableArray array];
}

- (id)fetchHistoriesWordsWithKey:(id)key filterType:(unsigned long long)filter {
    if (!SCIPrefEnabled(SCIPrefHideSearchHistory)) return %orig;
    sciSearchReads++;
    return [NSMutableArray array];
}

- (id)fetchHistoriesWordsWithKey:(id)key historyType:(long long)type {
    if (!SCIPrefEnabled(SCIPrefHideSearchHistory)) return %orig;
    sciSearchReads++;
    return [NSMutableArray array];
}

- (id)fetchHistoryWordsForKey:(id)key {
    if (!SCIPrefEnabled(SCIPrefHideSearchHistory)) return %orig;
    sciSearchReads++;
    return [NSMutableArray array];
}

- (id)fetchHistoryWordsForKey:(id)key historyType:(long long)type {
    if (!SCIPrefEnabled(SCIPrefHideSearchHistory)) return %orig;
    sciSearchReads++;
    return [NSMutableArray array];
}

- (id)fetchHistoryWordsForKey:(id)key historyType:(long long)type maxCount:(long long)count {
    if (!SCIPrefEnabled(SCIPrefHideSearchHistory)) return %orig;
    sciSearchReads++;
    return [NSMutableArray array];
}

- (id)fetchHistoryWordsForKey:(id)key historyType:(long long)type rootEnterFromType:(long long)root {
    if (!SCIPrefEnabled(SCIPrefHideSearchHistory)) return %orig;
    sciSearchReads++;
    return [NSMutableArray array];
}

- (id)fetchHistoryWordsForKey:(id)key historyType:(long long)type rootEnterFromType:(long long)root maxCount:(long long)count {
    if (!SCIPrefEnabled(SCIPrefHideSearchHistory)) return %orig;
    sciSearchReads++;
    return [NSMutableArray array];
}

- (id)fetchHistoryWordsForKey:(id)key maxCount:(long long)count {
    if (!SCIPrefEnabled(SCIPrefHideSearchHistory)) return %orig;
    sciSearchReads++;
    return [NSMutableArray array];
}

- (id)fetchHistoryWordsForKey:(id)key maxCount:(long long)count filterType:(unsigned long long)filter {
    if (!SCIPrefEnabled(SCIPrefHideSearchHistory)) return %orig;
    sciSearchReads++;
    return [NSMutableArray array];
}

- (id)fetchHistoryTimerForKey:(id)key maxCount:(long long)count {
    if (!SCIPrefEnabled(SCIPrefHideSearchHistory)) return %orig;
    sciSearchReads++;
    return [NSMutableArray array];
}

- (id)fetchHistoryTimerForKey:(id)key maxCount:(long long)count filterType:(unsigned long long)filter {
    if (!SCIPrefEnabled(SCIPrefHideSearchHistory)) return %orig;
    sciSearchReads++;
    return [NSMutableArray array];
}

- (id)fetchMultipleHistoriesWordsWithKey:(id)key filterType:(unsigned long long)filter {
    if (!SCIPrefEnabled(SCIPrefHideSearchHistory)) return %orig;
    sciSearchReads++;
    return [NSMutableArray array];
}

- (id)fetchMultipleHistoriesWordsWithKey:(id)key filterType:(unsigned long long)filter maxCount:(long long)count {
    if (!SCIPrefEnabled(SCIPrefHideSearchHistory)) return %orig;
    sciSearchReads++;
    return [NSMutableArray array];
}

%end
%end

// The shop search keeps its own history, behind its own manager.
%group SCITTSearchHistoryShop
%hook TTKECSearchHistoryManager

- (id)getHistoryKeywordsWithRootEnterFromType:(long long)root enableShowCount:(BOOL)show {
    if (!SCIPrefEnabled(SCIPrefHideSearchHistory)) return %orig;
    sciSearchReads++;
    return [NSMutableArray array];
}

- (id)getHistoryKeywordsWithRootEnterFromType:(long long)root enableShowCount:(BOOL)show showMaxCount:(long long)max {
    if (!SCIPrefEnabled(SCIPrefHideSearchHistory)) return %orig;
    sciSearchReads++;
    return [NSMutableArray array];
}

%end
%end

NSString *SCITTSearchHistoryReport(void) {
    return [NSString stringWithFormat:@"%@; reads answered with nothing %lu",
        sciSearchState ?: @"not installed", (unsigned long)sciSearchReads];
}

void SCITTInstallSearchHistory(void) {
    NSMutableArray<NSString *> *installed = [NSMutableArray array];
    NSMutableArray<NSString *> *skipped = [NSMutableArray array];

    // Fifteen reads on one class, declared together or not at all: a half-installed set would hide the history on one surface and not on
    // the next, which reads as a switch that works sometimes.
    static const struct { const char *selector; const char *encoding; } kReads[] = {
        {"fetchHistoriesWordsWithKey:", "@24@0:8@16"},
        {"fetchHistoriesWordsWithKey:filterType:", "@32@0:8@16Q24"},
        {"fetchHistoriesWordsWithKey:historyType:", "@32@0:8@16q24"},
        {"fetchHistoryWordsForKey:", "@24@0:8@16"},
        {"fetchHistoryWordsForKey:historyType:", "@32@0:8@16q24"},
        {"fetchHistoryWordsForKey:historyType:maxCount:", "@40@0:8@16q24q32"},
        {"fetchHistoryWordsForKey:historyType:rootEnterFromType:", "@40@0:8@16q24q32"},
        {"fetchHistoryWordsForKey:historyType:rootEnterFromType:maxCount:", "@48@0:8@16q24q32q40"},
        {"fetchHistoryWordsForKey:maxCount:", "@32@0:8@16q24"},
        {"fetchHistoryWordsForKey:maxCount:filterType:", "@40@0:8@16q24Q32"},
        {"fetchHistoryTimerForKey:maxCount:", "@32@0:8@16q24"},
        {"fetchHistoryTimerForKey:maxCount:filterType:", "@40@0:8@16q24Q32"},
        {"fetchMultipleHistoriesWordsWithKey:filterType:", "@32@0:8@16Q24"},
        {"fetchMultipleHistoriesWordsWithKey:filterType:maxCount:", "@40@0:8@16Q24q32"},
    };
    Class manager = NSClassFromString(@"TTKSearchHistoryManager");
    BOOL all = manager != Nil;
    NSString *missing = nil;
    for (size_t i = 0; all && i < sizeof(kReads) / sizeof(kReads[0]); i++) {
        if (!SCITTSearchHas(manager, kReads[i].selector, kReads[i].encoding)) {
            all = NO;
            missing = [NSString stringWithUTF8String:kReads[i].selector];
        }
    }
    if (all) {
        %init(SCITTSearchHistoryGroup);
        [installed addObject:@"search history"];
    } else {
        [skipped addObject:[NSString stringWithFormat:@"TTKSearchHistoryManager (%@)", missing ?: @"class absent"]];
    }

    Class shop = NSClassFromString(@"TTKECSearchHistoryManager");
    if (SCITTSearchHas(shop, "getHistoryKeywordsWithRootEnterFromType:enableShowCount:", "@28@0:8q16B24")
        && SCITTSearchHas(shop, "getHistoryKeywordsWithRootEnterFromType:enableShowCount:showMaxCount:", "@36@0:8q16B24q28")) {
        %init(SCITTSearchHistoryShop);
        [installed addObject:@"shop search history"];
    } else {
        [skipped addObject:@"TTKECSearchHistoryManager"];
    }

    sciSearchState = [NSString stringWithFormat:@"%@%@",
        installed.count ? [@"installed: " stringByAppendingString:[installed componentsJoinedByString:@", "]] : @"nothing installed",
        skipped.count ? [NSString stringWithFormat:@" — skipped: %@", [skipped componentsJoinedByString:@"; "]] : @""];
    SCILogV(@"[SearchHistory] %@", sciSearchState);
}
