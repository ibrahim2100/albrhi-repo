#import <UIKit/UIKit.h>
#import "SCITWTimelineFilter.h"
#import "Prefs.h"
#import "SCILog.h"
#import <objc/runtime.h>
#import <objc/message.h>

@interface TFNItemsDataViewController : UIViewController
- (id)itemAtIndexPath:(id)indexPath;
@end

static BOOL sciItemsPresent = NO;
static NSUInteger sciHidWhoToFollow = 0, sciHidTopics = 0, sciHidTrends = 0;
static NSUInteger sciCellsSeen = 0;

/// Model class names, matched exactly.
///
/// Exactly, and never as a substring of a description: the promoted filter in this same
/// tweak learned that lesson expensively on the YouTube side, where a marker naming an
/// advertisement *inside* a shelf condemned the shelf and every real post in it.
static BOOL SCIMatches(NSString *name, NSArray<NSString *> *wanted) {
    for (NSString *candidate in wanted) {
        if ([name isEqualToString:candidate]) return YES;
    }
    return NO;
}

static NSArray<NSString *> *SCIWhoToFollowModels(void) {
    static NSArray *models = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        models = @[
            @"T1URTTimelineUserItemViewModel",
            @"T1TwitterSwift.URTTimelineCarouselViewModel",
            @"TwitterURT.URTTimelineCarouselViewModel",
        ];
    });
    return models;
}

static NSArray<NSString *> *SCITopicModels(void) {
    static NSArray *models = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        models = @[
            @"T1TwitterSwift.URTTimelineTopicCollectionViewModel",
            @"_TtC10TwitterURT26URTTimelinePromptViewModel",
            @"TwitterURT.URTTimelinePromptViewModel",
        ];
    });
    return models;
}

static NSArray<NSString *> *SCITrendVideoModels(void) {
    static NSArray *models = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        models = @[
            @"TwitterURT.URTTimelineEventSummaryViewModel",
            @"_TtC10TwitterURT32URTTimelineEventSummaryViewModel",
        ];
    });
    return models;
}


// MARK: - Removing items before they become cells

///
/// **The first version hid cells, and a hidden cell is a gap.** `cell.hidden = YES` leaves the
/// row exactly as tall as the data source made it, so every suggestion that was "removed" was
/// an empty band the height of a module -- and on the newer diffable collection-view path X
/// uses in 12.28 and later, the cell hook below is not reached at all. NeoFreeBird, which is
/// written against 12.31, filters the *section data* before it reaches the controller: an item
/// that is not in the array never becomes a cell, a row, or a gap, on either path. This is that
/// approach (NeoFreeBird by orionblur, GPLv3, `src/Hooks/Ads.x`), kept in this tweak's own style:
/// every selector gated on the 12.20 encoding it is hooked with, every removal counted by kind
/// and by which door the data came through.
///
/// The cell hook stays underneath as the fallback for anything this does not recognise, and
/// the two are counted separately -- a report that says "removed 9 from sections, hid 0 as
/// cells" says which one is doing the work.
///

static NSUInteger sciSecRemoved[6];          // promoted, who-to-follow, topics, trends, premium, ads
static NSUInteger sciSecDoorCalls[7];
static NSUInteger sciSecChromeRemoved = 0;
static BOOL sciSecDoorsAttached[2] = {NO, NO};

enum { SCISecPromoted = 0, SCISecWhoToFollow, SCISecTopics, SCISecTrends, SCISecPremium, SCISecAds };

/// Whether a Swift class name -- given as `Module.Class` -- is this object's class, in the form
/// the runtime reports it in: `NSStringFromClass` answers `Module.Class` for a class with an
/// ObjC-visible name and `_TtC<n>Module<n>Class` for one without, and which one a given class
/// uses is not something to guess.
static BOOL SCISecClassIs(NSString *runtimeName, NSString *dotted) {
    if ([runtimeName isEqualToString:dotted]) return YES;

    NSRange dot = [dotted rangeOfString:@"."];
    if (dot.location == NSNotFound) return NO;

    NSString *module = [dotted substringToIndex:dot.location];
    NSString *cls = [dotted substringFromIndex:dot.location + 1];
    NSString *mangled = [NSString stringWithFormat:@"_TtC%lu%@%lu%@",
                         (unsigned long)module.length, module, (unsigned long)cls.length, cls];
    return [runtimeName isEqualToString:mangled];
}

static id SCISecUnwrap(id item) {
    Class wrapper = NSClassFromString(@"TFNDataViewItem");
    if (wrapper && [item isKindOfClass:wrapper] && [item respondsToSelector:@selector(item)]) {
        return ((id (*)(id, SEL))objc_msgSend)(item, @selector(item));
    }
    return item;
}

/// The status behind a timeline item, read from the `status` ivar `T1URTTimelineStatusItemViewModel`
/// declares (confirmed in X 12.20's class metadata: a Swift stored property, still registered as
/// an ObjC ivar, and not exposed as a method).
static BOOL SCISecStatusItemIsPromoted(id item) {
    Class statusItem = NSClassFromString(@"T1URTTimelineStatusItemViewModel");
    if (!statusItem || ![item isKindOfClass:statusItem]) return NO;

    Ivar ivar = class_getInstanceVariable([item class], "status");
    if (!ivar) return NO;

    id status = object_getIvar(item, ivar);
    SEL promoted = NSSelectorFromString(@"isPromoted");
    return status && [status respondsToSelector:promoted]
        && ((BOOL (*)(id, SEL))objc_msgSend)(status, promoted);
}

static BOOL SCISecHasPromotedContent(id item) {
    Ivar ivar = class_getInstanceVariable([item class], "promotedContent");
    return ivar && object_getIvar(item, ivar) != nil;
}

static BOOL SCISecScribePromoted(id item) {
    SEL scribe = NSSelectorFromString(@"scribeItem");
    if (![item respondsToSelector:scribe]) return NO;

    id dictionary = ((id (*)(id, SEL))objc_msgSend)(item, scribe);
    return [dictionary isKindOfClass:[NSDictionary class]] && dictionary[@"promoted_id"] != nil;
}

/// The decision for one item: which feature removes it, or -1 to keep it.
static NSInteger SCISecVerdict(id rawItem, BOOL promoted, BOOL whoToFollow, BOOL topics,
                               BOOL trends, BOOL premium) {
    id item = SCISecUnwrap(rawItem);
    if (!item) return -1;

    NSString *name = NSStringFromClass([item classForCoder]);
    if (!name.length) return -1;

    if (promoted) {
        if (SCISecStatusItemIsPromoted(item)) return SCISecPromoted;
        if (SCISecClassIs(name, @"TwitterURT.URTTimelineGoogleNativeAdViewModel")) return SCISecAds;
        if ((SCISecClassIs(name, @"TwitterURT.URTTimelineTrendViewModel") ||
             SCISecClassIs(name, @"TwitterURT.URTTimelineEventSummaryViewModel")) &&
            (SCISecScribePromoted(item) || SCISecHasPromotedContent(item))) {
            return SCISecAds;
        }
    }

    if (whoToFollow && SCIMatches(name, SCIWhoToFollowModels())) return SCISecWhoToFollow;
    if (topics && SCIMatches(name, SCITopicModels())) return SCISecTopics;
    if (trends && SCIMatches(name, SCITrendVideoModels())) return SCISecTrends;
    if (premium && SCISecClassIs(name, @"TwitterURT.URTTimelineMessageItemViewModel")) return SCISecPremium;

    return -1;
}

static BOOL SCISecIsModuleChrome(id item, NSString *dotted) {
    id inner = SCISecUnwrap(item);
    return inner && SCISecClassIs(NSStringFromClass([inner classForCoder]), dotted);
}

/// A module is a header, its content, then a footer. When every content row is gone the header
/// and footer have nothing to introduce, and are removed with it -- leaving "Who to follow" over
/// an empty space is the same gap this approach exists to avoid.
static void SCISecMarkEmptiedChrome(NSArray *items, NSMutableIndexSet *removed) {
    NSUInteger count = items.count;
    for (NSUInteger i = 0; i < count; i++) {
        if ([removed containsIndex:i]) continue;
        if (!SCISecIsModuleChrome(items[i], @"TwitterURT.URTModuleHeaderViewModel")) continue;

        NSUInteger content = 0;
        BOOL allRemoved = YES;
        NSUInteger j = i + 1;
        while (j < count &&
               !SCISecIsModuleChrome(items[j], @"TwitterURT.URTModuleHeaderViewModel") &&
               !SCISecIsModuleChrome(items[j], @"TwitterURT.URTModuleFooterViewModel")) {
            content++;
            if (![removed containsIndex:j]) allRemoved = NO;
            j++;
        }

        if (content > 0 && allRemoved) {
            [removed addIndex:i];
            sciSecChromeRemoved++;
            if (j < count && SCISecIsModuleChrome(items[j], @"TwitterURT.URTModuleFooterViewModel")) {
                [removed addIndex:j];
                sciSecChromeRemoved++;
            }
        }
    }
}

static NSArray *SCISecFiltered(NSArray *sections, NSUInteger door) {
    if (![sections isKindOfClass:[NSArray class]]) return sections;
    if (door < 7) sciSecDoorCalls[door]++;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL promoted = [defaults boolForKey:SCIPrefHidePromoted];
    BOOL whoToFollow = [defaults boolForKey:SCIPrefHideWhoToFollow];
    BOOL topics = [defaults boolForKey:SCIPrefHideTopics];
    BOOL trends = [defaults boolForKey:SCIPrefHideTrendVideos];
    BOOL premium = [defaults boolForKey:SCIPrefHidePremiumOffer];
    if (!(promoted || whoToFollow || topics || trends || premium)) return sections;

    BOOL modified = NO;
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:sections.count];

    for (id section in sections) {
        if (![section isKindOfClass:[NSArray class]]) {
            [result addObject:section];
            continue;
        }

        NSArray *items = section;
        NSMutableIndexSet *removed = [NSMutableIndexSet indexSet];
        NSUInteger kinds[6] = {0, 0, 0, 0, 0, 0};

        for (NSUInteger i = 0; i < items.count; i++) {
            NSInteger verdict = SCISecVerdict(items[i], promoted, whoToFollow, topics, trends, premium);
            if (verdict >= 0) {
                [removed addIndex:i];
                kinds[verdict]++;
            }
        }

        if (!removed.count) {
            [result addObject:section];
            continue;
        }

        SCISecMarkEmptiedChrome(items, removed);
        for (int k = 0; k < 6; k++) sciSecRemoved[k] += kinds[k];

        NSMutableArray *kept = [items mutableCopy];
        [kept removeObjectsAtIndexes:removed];
        modified = YES;

        // A section with nothing left is dropped rather than kept empty: an empty section is
        // a header-less gap on a collection view.
        if (kept.count) [result addObject:kept];
    }

    return modified ? result : sections;
}

%group SectionDoorsCore

%hook TFNItemsDataViewController

- (void)setSections:(NSArray *)sections restoreScrollPosition:(BOOL)restore {
    %orig(SCISecFiltered(sections, 0), restore);
}

- (void)updateSections:(NSArray *)sections
    reconfigureItemIdentifiers:(NSArray *)identifiers
              withRowAnimation:(long long)animation
                    completion:(id)completion {
    %orig(SCISecFiltered(sections, 1), identifiers, animation, completion);
}

%end

%end


%group SectionDoorsExtra

%hook TFNItemsDataViewController

- (void)setSections:(NSArray *)sections {
    %orig(SCISecFiltered(sections, 2));
}

- (void)updateSections:(NSArray *)sections {
    %orig(SCISecFiltered(sections, 3));
}

- (void)updateSections:(NSArray *)sections completion:(id)completion {
    %orig(SCISecFiltered(sections, 4), completion);
}

- (void)updateSections:(NSArray *)sections withRowAnimation:(long long)animation {
    %orig(SCISecFiltered(sections, 5), animation);
}

- (void)updateSections:(NSArray *)sections withRowAnimation:(long long)animation completion:(id)completion {
    %orig(SCISecFiltered(sections, 6), animation, completion);
}

%end

%end


%group TimelineFilter

%hook TFNItemsDataViewController

- (id)tableViewCellForItem:(id)item atIndexPath:(id)indexPath {
    UITableViewCell *cell = %orig;
    if (!cell) return cell;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL wantsAny = [defaults boolForKey:SCIPrefHideWhoToFollow] ||
                    [defaults boolForKey:SCIPrefHideTopics] ||
                    [defaults boolForKey:SCIPrefHideTrendVideos];
    if (!wantsAny) return cell;

    // The model is asked for rather than inferred from the cell. A cell is reused and says
    // nothing about what it is showing; the item at this index path is the thing itself.
    id model = nil;
    @try {
        model = [self itemAtIndexPath:indexPath];
    } @catch (__unused NSException *exception) {
        return cell;
    }
    if (!model) return cell;

    sciCellsSeen++;
    NSString *name = NSStringFromClass([model classForCoder]);
    if (!name.length) return cell;

    if ([defaults boolForKey:SCIPrefHideWhoToFollow] && SCIMatches(name, SCIWhoToFollowModels())) {
        cell.hidden = YES;
        sciHidWhoToFollow++;
        return cell;
    }
    if ([defaults boolForKey:SCIPrefHideTopics] && SCIMatches(name, SCITopicModels())) {
        cell.hidden = YES;
        sciHidTopics++;
        return cell;
    }
    if ([defaults boolForKey:SCIPrefHideTrendVideos] && SCIMatches(name, SCITrendVideoModels())) {
        cell.hidden = YES;
        sciHidTrends++;
        return cell;
    }

    // Shown on the way through as well as hidden. Cells are reused, so the same instance
    // that hid a suggestion is handed an ordinary post on the next scroll -- writing only
    // the hiding branch is how a working filter starts eating the timeline.
    cell.hidden = NO;
    return cell;
}

%end

%end


NSString *SCITWTimelineFilterReport(void) {
    if (!sciItemsPresent) return @"timeline filter: TFNItemsDataViewController not in this build";

    return [NSString stringWithFormat:
            @"timeline filter: sections [%@] removed promoted %lu · ads %lu · suggestions %lu · topics %lu · trend videos %lu · offers %lu · empty module chrome %lu (doors %lu/%lu/%lu/%lu/%lu/%lu/%lu) | "
            @"cell fallback: %lu cell(s) seen · suggestions %lu · topics %lu · trend videos %lu",
            sciSecDoorsAttached[0] ? (sciSecDoorsAttached[1] ? @"core+extra" : @"core") : (sciSecDoorsAttached[1] ? @"extra only" : @"not attached"),
            (unsigned long)sciSecRemoved[SCISecPromoted], (unsigned long)sciSecRemoved[SCISecAds],
            (unsigned long)sciSecRemoved[SCISecWhoToFollow], (unsigned long)sciSecRemoved[SCISecTopics],
            (unsigned long)sciSecRemoved[SCISecTrends], (unsigned long)sciSecRemoved[SCISecPremium],
            (unsigned long)sciSecChromeRemoved,
            (unsigned long)sciSecDoorCalls[0], (unsigned long)sciSecDoorCalls[1],
            (unsigned long)sciSecDoorCalls[2], (unsigned long)sciSecDoorCalls[3],
            (unsigned long)sciSecDoorCalls[4], (unsigned long)sciSecDoorCalls[5],
            (unsigned long)sciSecDoorCalls[6],
            (unsigned long)sciCellsSeen, (unsigned long)sciHidWhoToFollow,
            (unsigned long)sciHidTopics, (unsigned long)sciHidTrends];
}

/// Whether `TFNItemsDataViewController` answers every selector with the encoding it will be
/// hooked with. All or nothing per group, because a `%hook` on a method the class does not
/// declare adds it.
static BOOL SCISecAnswers(NSArray<NSArray<NSString *> *> *pairs) {
    Class cls = NSClassFromString(@"TFNItemsDataViewController");
    if (!cls) return NO;

    for (NSArray<NSString *> *pair in pairs) {
        Method method = class_getInstanceMethod(cls, NSSelectorFromString(pair[0]));
        if (!method) return NO;
        const char *encoding = method_getTypeEncoding(method);
        if (!encoding || strcmp(encoding, pair[1].UTF8String) != 0) return NO;
    }
    return YES;
}

void SCITWInstallTimelineFilter(void) {
    sciItemsPresent = (NSClassFromString(@"TFNItemsDataViewController") != nil);
    if (!sciItemsPresent) {
        SCILogV(@"timeline filter: TFNItemsDataViewController not in this build");
        return;
    }

    // Encodings read from X 12.20's class metadata. The two the reference tweak hooks on 12.31
    // are the core; the other five are the same data arriving by other doors.
    if (SCISecAnswers(@[@[@"setSections:restoreScrollPosition:", @"v28@0:8@16B24"],
                        @[@"updateSections:reconfigureItemIdentifiers:withRowAnimation:completion:", @"v48@0:8@16@24q32@?40"]])) {
        %init(SectionDoorsCore);
        sciSecDoorsAttached[0] = YES;
    }

    if (SCISecAnswers(@[@[@"setSections:", @"v24@0:8@16"],
                        @[@"updateSections:", @"v24@0:8@16"],
                        @[@"updateSections:completion:", @"v32@0:8@16@?24"],
                        @[@"updateSections:withRowAnimation:", @"v32@0:8@16q24"],
                        @[@"updateSections:withRowAnimation:completion:", @"v40@0:8@16q24@?32"]])) {
        %init(SectionDoorsExtra);
        sciSecDoorsAttached[1] = YES;
    }

    %init(TimelineFilter);
    SCILogV(@"timeline filter attached");
}
