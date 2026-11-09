#import "SCIPanelGuideController.h"
#import <Preferences/PSSpecifier.h>

#import "SCIPanelScan.h"
#import "Design/SCIPanelStyle.h"
#import "Design/SCIPanelCells.h"
#import "Localization/SCILocalize.h"

@implementation SCIPanelGuideController

//
// One line per tweak, keyed by the dylib's own name.
//
// Written as literal keys rather than composed at runtime -- `SCILocalized([@"guide_desc_"
// stringByAppendingString:name])` would read the same and would be invisible to check.py's
// localization rules, which is how a table loses a translation without anything failing.
//
- (NSString *)descriptionForTweak:(NSString *)name {
    static NSDictionary *table = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        table = @{
            @"Albrhi":        SCILocalized(@"guide_desc_instagram"),
            @"AlbrhiYT":      SCILocalized(@"guide_desc_youtube"),
            @"AlbrhiTW":      SCILocalized(@"guide_desc_twitter"),
            @"AlbrhiTT":      SCILocalized(@"guide_desc_tiktok"),
            @"AlbrhiSpotify": SCILocalized(@"guide_desc_spotify"),
            @"AlbrhiYTM":     SCILocalized(@"guide_desc_ytmusic"),
            @"AlbrhiNU":      SCILocalized(@"guide_desc_nextup"),
            @"AlbrhiWatch":   SCILocalized(@"guide_desc_watch"),
        };
    });

    // A tweak this page has never been told about still gets a row, saying so. Silence would
    // read as "this one does nothing".
    return table[name] ?: SCILocalized(@"guide_desc_unknown");
}

- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;

    NSMutableArray *specifiers = [NSMutableArray array];

    PSSpecifier *intro = [PSSpecifier preferenceSpecifierNamed:@""
                                                        target:self set:NULL get:NULL detail:Nil cell:PSGroupCell edit:Nil];
    [intro setProperty:SCILocalized(@"guide_intro") forKey:@"footerText"];
    [specifiers addObject:intro];

    NSArray<SCIPanelEntry *> *entries = [SCIPanelScan entries];

    // **One tweak, one card**: the app's tile and name with where its version stands on the second line, and what the tweak does underneath.
    // It used to be a header and two value rows per tweak ("Verified against", "On this phone") -- two lines of a table to say one fact. The
    // fact is the comparison, and it is now a sentence in the colour that says whether to care: green when the phone has what the tweak was
    // verified on, amber when it does not (a caution -- a newer app usually still works), quiet when the app is not installed.
    for (SCIPanelEntry *entry in entries) {
        PSSpecifier *group = [PSSpecifier preferenceSpecifierNamed:@""
                                                            target:self set:NULL get:NULL detail:Nil cell:PSGroupCell edit:Nil];
        [group setProperty:[self descriptionForTweak:entry.tweakName] forKey:@"footerText"];
        [specifiers addObject:group];

        PSSpecifier *row = [PSSpecifier preferenceSpecifierNamed:entry.appName
                                                          target:self set:NULL get:NULL detail:Nil cell:PSTitleValueCell edit:Nil];
        [row setProperty:[SCIPanelRowCell class] forKey:@"cellClass"];
        [row setProperty:@68 forKey:@"height"];
        [row setProperty:SCIPanelTileForEntry(entry, SCIPanelTileSide) forKey:SCIPanelRowTileKey];

        NSString *line;
        SCIPanelTone tone = SCIPanelToneQuiet;
        if (!entry.appInstalled) {
            line = SCILocalized(@"versions_not_installed");
        } else if (entry.testedVersion.length && entry.appVersion.length && [entry runsTestedVersion]) {
            line = [NSString stringWithFormat:SCILocalized(@"guide_line_match"), entry.appVersion];
            tone = SCIPanelToneGood;
        } else if (entry.testedVersion.length && entry.appVersion.length) {
            line = [NSString stringWithFormat:SCILocalized(@"guide_line_differ"), entry.appVersion, entry.testedVersion];
            tone = SCIPanelToneCaution;
        } else if (entry.testedVersion.length) {
            line = [NSString stringWithFormat:SCILocalized(@"guide_line_tested_only"), entry.testedVersion];
        } else {
            line = entry.appVersion.length ? entry.appVersion : SCILocalized(@"versions_unknown");
        }
        [row setProperty:line forKey:SCIPanelRowSubtitleKey];
        [row setProperty:@(tone) forKey:SCIPanelRowToneKey];
        [specifiers addObject:row];
    }

    if (!entries.count) {
        PSSpecifier *none = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"apps_none")
                                                           target:self set:NULL get:NULL detail:Nil cell:PSGroupCell edit:Nil];
        [specifiers addObject:none];
    }

    // Assigned to the ivar, never only returned. PSListController reads _specifiers directly in places an override's return value never reaches,
    // and a page that skipped this shipped as a black screen once already.
    _specifiers = specifiers;
    return _specifiers;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = SCILocalized(@"guide_title");
}

@end
