#import "SCITTSectionRegistry.h"

NSString *const kSCIKindSwitch = @"switch";
NSString *const kSCIKindLink = @"link";
NSString *const kSCIRowKind = @"kind";
NSString *const kSCIRowTitle = @"title";
NSString *const kSCIRowNote = @"note";
NSString *const kSCIRowIcon = @"icon";
NSString *const kSCIRowColor = @"color";
NSString *const kSCIRowPref = @"pref";
NSString *const kSCIRowWarns = @"warns";
NSString *const kSCIRowDestination = @"destination";
NSString *const kSCIDestinationReport = @"report";
NSString *const kSCIDestinationWelcome = @"welcome";
NSString *const kSCISectionTitle = @"section";
NSString *const kSCISectionIcon = @"sectionIcon";
NSString *const kSCISectionColor = @"sectionColor";
NSString *const kSCISectionRows = @"rows";

/// Order and builder, kept together so they cannot be sorted apart.
@interface SCITTSectionEntry : NSObject
@property (nonatomic, assign) NSInteger order;
@property (nonatomic, copy) NSDictionary *(^builder)(void);
@end

@implementation SCITTSectionEntry
@end

static NSMutableArray<SCITTSectionEntry *> *sciSections = nil;

void SCITTRegisterSection(NSInteger order, NSDictionary *(^builder)(void)) {
    if (!builder) return;

    static dispatch_once_t once;
    dispatch_once(&once, ^{ sciSections = [NSMutableArray array]; });

    SCITTSectionEntry *entry = [[SCITTSectionEntry alloc] init];
    entry.order = order;
    entry.builder = builder;
    [sciSections addObject:entry];
}

NSArray<NSDictionary *> *SCITTSections(void) {
    NSArray<SCITTSectionEntry *> *ordered =
        [sciSections sortedArrayUsingComparator:^NSComparisonResult(SCITTSectionEntry *a, SCITTSectionEntry *b) {
            if (a.order == b.order) return NSOrderedSame;
            return a.order < b.order ? NSOrderedAscending : NSOrderedDescending;
        }];

    NSMutableArray<NSDictionary *> *sections = [NSMutableArray array];
    for (SCITTSectionEntry *entry in ordered) {
        // **A section that builds nothing is not drawn rather than drawn empty.** A file whose
        // feature is unavailable on this build should disappear, not leave a titled blank.
        NSDictionary *section = entry.builder();
        if (section.count) [sections addObject:section];
    }
    return sections;
}
