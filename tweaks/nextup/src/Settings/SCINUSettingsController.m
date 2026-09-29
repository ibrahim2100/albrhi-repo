#import "SCINUSettingsController.h"
#import <Preferences/PSSpecifier.h>
#import <notify.h>
#import "../Localization/SCILocalize.h"
#import "shared/src/Prefs/SCIPanelBadge.h"
#import "shared/src/Prefs/SCIPanelAppCell.h"
#import "shared/src/Prefs/SCIPanelHeader.h"

///
/// Upstream's preference plumbing, used exactly as upstream's own pane used it.
///
/// Two channels, and both are needed. CFPreferences is the persisted value, read
/// reliably when an injected process starts. The notify_state token is the *live* one:
/// a cross-process CFPreferences read is cached and would only pick a toggle up after a
/// respring, so the token is what makes a switch take effect while Music or SpringBoard
/// is already running. Writing one without the other gives a switch that either forgets
/// itself on reboot or does nothing until you respring — upstream documents this and the
/// port keeps it rather than rediscovering it.
///
/// The domain and the bit layout are upstream's, not renamed. The reader
/// (`NUPrefs.m`, shipped unchanged in tweaks/nextup) compiles those names in, so a
/// rebrand here would be a silent disconnect: every switch would write somewhere the
/// tweak never looks. `control` declares Conflicts on com.yves.nextup3 so the two
/// packages can never both be installed and race for the same names.
static NSString *const kNUDomain = @"com.yves.nextup3";
static const char *const kNUStateNotifyName = "com.yves.nextup3.state";

static const uint64_t kNUStateValidBit      = (1ULL << 63);
static const int      kNUStateKnownShift    = 32;

/// Key → bit, mirroring NUStateBitForKey() in the tweak's own NUPrefs.h. Kept as a table
/// so the publish step below cannot drift from the list of switches this page draws.
typedef struct { __unsafe_unretained NSString *key; uint64_t bit; } SCINUToggle;

static const SCINUToggle kSCINUToggles[] = {
    { @"Enabled",             1ULL << 0 },
    { @"enabledMusic",        1ULL << 1 },
    { @"enabledPodcasts",     1ULL << 2 },
    { @"showLockScreen",      1ULL << 3 },
    { @"showDynamicIsland",   1ULL << 4 },
    { @"showControlCenter",   1ULL << 5 },
    { @"enabledYouTubeMusic", 1ULL << 6 },
    { @"enabledSpotify",      1ULL << 7 },
    { @"enabledYouTube",      1ULL << 8 },
    { @"enabledSoundCloud",   1ULL << 9 },
};

static const size_t kSCINUToggleCount = sizeof(kSCINUToggles) / sizeof(kSCINUToggles[0]);

@implementation SCINUSettingsController

// MARK: - Preferences

- (BOOL)sci_readBool:(NSString *)key fallback:(BOOL)fallback {
    // Settings is the writing process, so its own value can be stale in cache without
    // this — upstream's reader passes `fresh:YES` here for the same reason.
    CFPreferencesAppSynchronize((__bridge CFStringRef)kNUDomain);

    CFPropertyListRef value = CFPreferencesCopyAppValue(
        (__bridge CFStringRef)key, (__bridge CFStringRef)kNUDomain);
    if (!value) return fallback;

    BOOL result = (CFGetTypeID(value) == CFBooleanGetTypeID())
        ? CFBooleanGetValue((CFBooleanRef)value) : fallback;
    CFRelease(value);
    return result;
}

/// Rebuild the whole state word from the freshly written plist, stamp it valid, publish
/// and signal. A port of NUPrefsPublishState(); the word is rebuilt from scratch rather
/// than toggled bit-by-bit so a switch can never leave the token disagreeing with what
/// is actually stored.
- (void)sci_publishState {
    uint64_t mask = kNUStateValidBit;
    uint64_t known = 0;

    for (size_t i = 0; i < kSCINUToggleCount; i++) {
        // The same split the rows read with: the master is opt-in, everything else keeps
        // upstream's fail-open YES. Publishing a different default than the rows display
        // would put the token and the screen in disagreement the first time this runs,
        // before any value has actually been stored.
        BOOL optIn = [kSCINUToggles[i].key isEqualToString:@"Enabled"];
        if ([self sci_readBool:kSCINUToggles[i].key fallback:!optIn]) mask |= kSCINUToggles[i].bit;
        known |= kSCINUToggles[i].bit;
    }

    // The known-keys half says "the writer knew this key"; a value bit whose known bit is
    // clear makes the reader fall back to CFPreferences instead of trusting a zero.
    mask |= (known << kNUStateKnownShift);

    int token = -1;
    if (notify_register_check(kNUStateNotifyName, &token) == NOTIFY_STATUS_OK && token != -1) {
        notify_set_state(token, mask);
        notify_cancel(token);
    }
    notify_post(kNUStateNotifyName);
}

- (void)sci_writeBool:(BOOL)value forKey:(NSString *)key {
    CFPreferencesSetAppValue((__bridge CFStringRef)key,
                             (__bridge CFPropertyListRef)@(value),
                             (__bridge CFStringRef)kNUDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)kNUDomain);

    // Persisted first, published second: the publish step re-reads the plist, so doing it
    // the other way round would broadcast the value this write was about to replace.
    [self sci_publishState];
}

// MARK: - Specifier plumbing

/// The switch's own key travels on the specifier, so adding a row costs one entry here
/// and nothing anywhere else — no second `if` ladder mapping a tag back to a key, which
/// is where this project has put a switch on the wrong preference before.
/// The master reads NO when nothing is stored; every other switch reads YES.
///
/// This has to agree exactly with `NUMasterEnabled()` in the tweak, which is opt-in for
/// the reason written there. A page that showed the master as on while the tweak read it
/// as off would be a screen stating the opposite of what is happening — worse than
/// either default on its own.
- (id)nuValueForSpecifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"sciNUKey"];

    // **The default travels on the row, rather than being inferred from its key here.**
    //
    // It used to read `[key isEqualToString:@"Enabled"]`, which is a list of opt-in keys written
    // as a comparison -- correct while there was exactly one, and quietly wrong the moment a
    // second arrived: the diagnostic log would have defaulted *on*, which is the failure that
    // switch exists to prevent. A row that states its own default cannot be added wrongly.
    NSNumber *fallback = [specifier propertyForKey:@"sciNUDefault"];
    return @([self sci_readBool:key fallback:fallback ? fallback.boolValue : YES]);
}

- (void)setNuValue:(NSNumber *)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"sciNUKey"];
    if (!key.length) return;
    [self sci_writeBool:value.boolValue forKey:key];

    // The switches are drawn by Preferences and the header by this file, so moving the master
    // has to tell the header -- otherwise the pill keeps saying "on" while the switch under it
    // is off, which is the screen-disagreeing-with-itself failure this page was already fixed
    // for once. The rebuild is skipped internally unless the state actually changed.
    if ([key isEqualToString:@"Enabled"]) [self viewDidLayoutSubviews];
}

- (PSSpecifier *)nuGroupTitled:(NSString *)title footer:(NSString *)footer {
    PSSpecifier *group = [PSSpecifier preferenceSpecifierNamed:(title ?: @"")
                                                         target:self
                                                            set:NULL
                                                            get:NULL
                                                         detail:Nil
                                                           cell:PSGroupCell
                                                           edit:Nil];
    if (footer.length) [group setProperty:footer forKey:@"footerText"];
    return group;
}

- (PSSpecifier *)nuSwitchTitled:(NSString *)title
                            key:(NSString *)key
                         symbol:(NSString *)symbol
                          tint:(UIColor *)tint {
    return [self nuSwitchTitled:title key:key symbol:symbol tint:tint support:nil];
}

///
/// **The version each app was built against, on the app's own row.**
///
/// This is the one fact that explains a row going blank after an app update, and it lived
/// nowhere a user could see it -- the provider is written against a specific build's private
/// classes, so "YouTube Music 9.28.4" is not trivia, it is the line somebody reads when the row
/// stops appearing. The apps list on the root page already carries exactly this shape for the
/// same reason, down to the cell class: a version under a name, in the row it is about, instead
/// of a second section repeating the list.
///
- (PSSpecifier *)nuSwitchTitled:(NSString *)title
                            key:(NSString *)key
                         symbol:(NSString *)symbol
                          tint:(UIColor *)tint
                        support:(NSString *)support {
    return [self nuSwitchTitled:title key:key symbol:symbol tint:tint support:support
                     defaultsTo:![key isEqualToString:@"Enabled"]];
}

- (PSSpecifier *)nuSwitchTitled:(NSString *)title
                            key:(NSString *)key
                         symbol:(NSString *)symbol
                          tint:(UIColor *)tint
                        support:(NSString *)support
                     defaultsTo:(BOOL)defaultsTo {
    PSSpecifier *row = [PSSpecifier preferenceSpecifierNamed:title
                                                       target:self
                                                          set:@selector(setNuValue:specifier:)
                                                          get:@selector(nuValueForSpecifier:)
                                                       detail:Nil
                                                         cell:PSSwitchCell
                                                         edit:Nil];
    [row setProperty:key forKey:@"sciNUKey"];
    [row setProperty:@(defaultsTo) forKey:@"sciNUDefault"];

    // A mark per row, the same 29-point badge the root list gives this tweak.
    //
    // Nine switches whose titles are three surfaces and five app names is a page read
    // top to bottom every time; with a mark on each, the row wanted is found before the
    // reading starts. The apps carry a symbol for what they play rather than a brand
    // glyph -- an app's own icon is not this bundle's to draw, and a wrong-looking
    // imitation is worse than an honest symbol.
    if (symbol.length) [row setProperty:SCIPanelBadgeImage(symbol, tint) forKey:@"iconImage"];

    if (support.length) {
        [row setProperty:support forKey:@"sciSubtitle"];
        // A Class, not its name: Preferences takes this property as a Class and sends class
        // messages to it, and handing it an NSString killed Settings once already.
        [row setProperty:[SCIPanelAppCell class] forKey:@"cellClass"];
    }
    return row;
}

// MARK: - The page

- (NSArray *)specifiers {
    NSMutableArray *specifiers = [NSMutableArray array];

    [specifiers addObject:[self nuGroupTitled:nil footer:SCILocalized(@"nextup_master_footer")]];
    [specifiers addObject:[self nuSwitchTitled:SCILocalized(@"nextup_master")
                                           key:@"Enabled"
                                        symbol:@"power"
                                          tint:SCIPanelAccent()]];

    [specifiers addObject:[self nuGroupTitled:SCILocalized(@"nextup_where_section")
                                        footer:SCILocalized(@"nextup_where_footer")]];
    [specifiers addObject:[self nuSwitchTitled:SCILocalized(@"nextup_lock_screen")
                                           key:@"showLockScreen"
                                        symbol:@"lock.fill"
                                          tint:[UIColor systemIndigoColor]]];
    [specifiers addObject:[self nuSwitchTitled:SCILocalized(@"nextup_dynamic_island")
                                           key:@"showDynamicIsland"
                                        symbol:@"iphone"
                                          tint:[UIColor systemTealColor]]];
    [specifiers addObject:[self nuSwitchTitled:SCILocalized(@"nextup_control_center")
                                           key:@"showControlCenter"
                                        symbol:@"switch.2"
                                          tint:[UIColor systemBlueColor]]];

    [specifiers addObject:[self nuGroupTitled:SCILocalized(@"nextup_apps_section")
                                        footer:SCILocalized(@"nextup_apps_footer")]];
    [specifiers addObject:[self nuSwitchTitled:SCILocalized(@"nextup_app_music")
                                           key:@"enabledMusic"
                                        symbol:@"music.note"
                                          tint:[UIColor systemPinkColor]
                                       support:SCILocalized(@"nextup_support_music")]];
    [specifiers addObject:[self nuSwitchTitled:SCILocalized(@"nextup_app_podcasts")
                                           key:@"enabledPodcasts"
                                        symbol:@"mic.fill"
                                          tint:[UIColor systemPurpleColor]
                                       support:SCILocalized(@"nextup_support_podcasts")]];
    [specifiers addObject:[self nuSwitchTitled:SCILocalized(@"nextup_app_youtube")
                                           key:@"enabledYouTube"
                                        symbol:@"play.rectangle.fill"
                                          tint:[UIColor systemRedColor]
                                       support:SCILocalized(@"nextup_support_youtube")]];
    [specifiers addObject:[self nuSwitchTitled:SCILocalized(@"nextup_app_youtube_music")
                                           key:@"enabledYouTubeMusic"
                                        symbol:@"music.note.list"
                                          tint:[UIColor systemRedColor]
                                       support:SCILocalized(@"nextup_support_youtube_music")]];
    [specifiers addObject:[self nuSwitchTitled:SCILocalized(@"nextup_app_spotify")
                                           key:@"enabledSpotify"
                                        symbol:@"waveform"
                                          tint:[UIColor systemGreenColor]
                                       support:SCILocalized(@"nextup_support_spotify")]];
    [specifiers addObject:[self nuSwitchTitled:SCILocalized(@"nextup_app_soundcloud")
                                           key:@"enabledSoundCloud"
                                        symbol:@"cloud.fill"
                                          tint:[UIColor systemOrangeColor]
                                       support:SCILocalized(@"nextup_support_soundcloud")]];

    [specifiers addObject:[self nuGroupTitled:SCILocalized(@"nextup_advanced_section")
                                        footer:SCILocalized(@"nextup_log_footer")]];
    [specifiers addObject:[self nuSwitchTitled:SCILocalized(@"nextup_log")
                                           key:@"verboseLogging"
                                        symbol:@"doc.text.magnifyingglass"
                                          tint:[UIColor systemGrayColor]
                                       support:nil
                                    defaultsTo:NO]];

    [specifiers addObject:[self nuGroupTitled:nil footer:SCILocalized(@"nextup_credit")]];

    // Assigned to the ivar, not just returned. PSListController's own machinery reads
    // _specifiers directly in places an override's return value never reaches, and a page
    // that only returns its list opens to a black screen — which this project has already
    // shipped once, on CarPlay's page.
    _specifiers = specifiers;
    return _specifiers;
}

// MARK: - The header

/// Fitted here, not in -viewDidLoad, for the reason the root page documents: a table header has
/// to be given a frame, and the width to fit it to is not final until the view has been laid out.
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    UITableView *table = self.table;
    CGFloat width = table.bounds.size.width;
    if (width <= 0) return;

    BOOL on = [self sci_readBool:@"Enabled" fallback:NO];

    // Rebuilt when the width changes *or* the master does -- the pill is a live statement and a
    // header cached on width alone would keep saying "on" after the switch under it was moved.
    if (table.tableHeaderView
        && ABS(table.tableHeaderView.frame.size.width - width) < 0.5
        && table.tableHeaderView.tag == (on ? 1 : 2)) {
        return;
    }

    UIView *header = [SCIPanelHeader pageHeaderForWidth:width
                                                 symbol:@"music.note.list"
                                                   tint:SCIPanelAccent()
                                                  title:SCILocalized(@"nextup_title")
                                               subtitle:SCILocalized(@"nextup_page_subtitle")
                                                  state:SCILocalized(on ? @"nextup_state_on"
                                                                        : @"nextup_state_off")
                                                     on:on];
    header.tag = on ? 1 : 2;
    table.tableHeaderView = header;
}

@end
