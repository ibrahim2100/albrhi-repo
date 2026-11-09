//
//  SCISpotifySettingsController.m
//  Albrhi Panel
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCISpotifySettingsController.h"
#import <Preferences/PSSpecifier.h>
#import "../Localization/SCILocalize.h"
#import "../Design/SCIPanelStyle.h"
#import "../Design/SCIPanelCells.h"

/// The tweak's own domain, named identically in tweaks/spotify/src/Prefs.swift. Two spellings of
/// this string is a switch that appears to work and changes nothing.
static NSString *const kSCISpotifyDomain = @"com.albrhi.spotify";

typedef struct { __unsafe_unretained NSString *key; BOOL defaultsTo; } SCISpotifyToggle;

/// Every switch, with the default the *tweak* uses for it — stated here rather than inferred,
/// because a page showing a different default than the tweak applies is a screen stating the
/// opposite of what is happening.
static const SCISpotifyToggle kSCISpotifyToggles[] = {
    { @"spotify_enabled",      NO  },
    { @"spotify_block_ads",    YES },
    { @"spotify_block_upsell", YES },
    // Off: it asks a third-party server about what is playing, and that cost is paid only by
    // somebody who chose it -- the same rule the TikTok tweak's external download switch follows.
    { @"spotify_sponsorblock",  NO  },
};

static const size_t kSCISpotifyToggleCount =
    sizeof(kSCISpotifyToggles) / sizeof(kSCISpotifyToggles[0]);

@implementation SCISpotifySettingsController

- (BOOL)sci_readBool:(NSString *)key {
    CFPreferencesAppSynchronize((__bridge CFStringRef)kSCISpotifyDomain);

    CFPropertyListRef value = CFPreferencesCopyAppValue((__bridge CFStringRef)key,
                                                        (__bridge CFStringRef)kSCISpotifyDomain);
    if (value) {
        BOOL result = (CFGetTypeID(value) == CFBooleanGetTypeID())
            ? CFBooleanGetValue((CFBooleanRef)value) : NO;
        CFRelease(value);
        return result;
    }

    for (size_t i = 0; i < kSCISpotifyToggleCount; i++) {
        if ([key isEqualToString:kSCISpotifyToggles[i].key]) return kSCISpotifyToggles[i].defaultsTo;
    }
    return NO;
}

- (id)spotifyValueForSpecifier:(PSSpecifier *)specifier {
    return @([self sci_readBool:[specifier propertyForKey:@"sciSpotifyKey"]]);
}

- (void)setSpotifyValue:(NSNumber *)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"sciSpotifyKey"];
    if (!key.length) return;

    CFPreferencesSetAppValue((__bridge CFStringRef)key,
                             (__bridge CFPropertyListRef)@(value.boolValue),
                             (__bridge CFStringRef)kSCISpotifyDomain);
    // Written through immediately: left to cfprefsd's own schedule, an app relaunched seconds
    // later reads the old value and the switch looks broken for the one action it exists to be
    // followed by.
    CFPreferencesAppSynchronize((__bridge CFStringRef)kSCISpotifyDomain);

    if ([key isEqualToString:@"spotify_enabled"]) [self reloadSpecifiers];
}

- (PSSpecifier *)spotifyGroupTitled:(NSString *)title footer:(NSString *)footer {
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

- (PSSpecifier *)spotifySwitchTitled:(NSString *)title
                                 key:(NSString *)key
                              symbol:(NSString *)symbol
                                 top:(UIColor *)top
                              bottom:(UIColor *)bottom {
    PSSpecifier *row = [PSSpecifier preferenceSpecifierNamed:title
                                                      target:self
                                                         set:@selector(setSpotifyValue:specifier:)
                                                         get:@selector(spotifyValueForSpecifier:)
                                                      detail:Nil
                                                        cell:PSSwitchCell
                                                        edit:Nil];
    [row setProperty:key forKey:@"sciSpotifyKey"];
    // The same row the main page draws: a 44-point tile, the title, the system's switch.
    [row setProperty:[SCIPanelSwitchRowCell class] forKey:@"cellClass"];
    [row setProperty:@64 forKey:@"height"];
    if (symbol.length) [row setProperty:SCIPanelSymbolTile(symbol, top, bottom, SCIPanelTileSide) forKey:SCIPanelRowTileKey];
    return row;
}

- (NSArray *)specifiers {
    NSMutableArray *specifiers = [NSMutableArray array];

    //
    // **What this tweak is not, before what it is.**
    //
    // The ad blocking is carried over from a tweak whose own description offers Spotify Premium
    // for free. This one does not do that, and somebody who installs it expecting it should read
    // that here rather than discover it by trying to skip a track.
    //
    BOOL enabled = [self sci_readBool:@"spotify_enabled"];
    NSString *state = enabled ? SCILocalized(@"spotify_gate_on") : SCILocalized(@"spotify_gate_off");

    [specifiers addObject:[self spotifyGroupTitled:nil footer:SCILocalized(@"spotify_no_premium")]];

    PSSpecifier *master = [self spotifySwitchTitled:SCILocalized(@"spotify_master")
                                                key:@"spotify_enabled"
                                             symbol:@"power"
                                                top:enabled ? [UIColor colorWithRed:0.30 green:0.85 blue:0.48 alpha:1] : [UIColor colorWithRed:0.62 green:0.62 blue:0.68 alpha:1]
                                             bottom:enabled ? [UIColor colorWithRed:0.10 green:0.66 blue:0.36 alpha:1] : [UIColor colorWithRed:0.42 green:0.42 blue:0.48 alpha:1]];
    [master setProperty:@72 forKey:@"height"];
    [master setProperty:state forKey:SCIPanelRowSubtitleKey];
    [master setProperty:@(enabled ? SCIPanelToneGood : SCIPanelToneQuiet) forKey:SCIPanelRowToneKey];
    [specifiers addObject:master];

    [specifiers addObject:[self spotifyGroupTitled:SCILocalized(@"spotify_ads_section")
                                            footer:SCILocalized(@"spotify_ads_footer")]];

    [specifiers addObject:[self spotifySwitchTitled:SCILocalized(@"spotify_block_ads")
                                                key:@"spotify_block_ads"
                                             symbol:@"speaker.slash.fill"
                                                top:[UIColor colorWithRed:0.30 green:0.85 blue:0.48 alpha:1]
                                             bottom:[UIColor colorWithRed:0.10 green:0.66 blue:0.36 alpha:1]]];

    [specifiers addObject:[self spotifySwitchTitled:SCILocalized(@"spotify_block_upsell")
                                                key:@"spotify_block_upsell"
                                             symbol:@"rectangle.slash.fill"
                                                top:[UIColor colorWithRed:0.27 green:0.80 blue:0.78 alpha:1]
                                             bottom:[UIColor colorWithRed:0.10 green:0.58 blue:0.62 alpha:1]]];

    [specifiers addObject:[self spotifyGroupTitled:SCILocalized(@"spotify_podcast_section")
                                            footer:SCILocalized(@"spotify_sponsorblock_footer")]];

    [specifiers addObject:[self spotifySwitchTitled:SCILocalized(@"spotify_sponsorblock")
                                                key:@"spotify_sponsorblock"
                                             symbol:@"forward.end.fill"
                                                top:[UIColor colorWithRed:1 green:0.66 blue:0.22 alpha:1]
                                             bottom:[UIColor colorWithRed:0.95 green:0.45 blue:0.10 alpha:1]]];

    [specifiers addObject:[self spotifyGroupTitled:nil footer:SCILocalized(@"spotify_credit")]];

    // Assigned to the ivar, not just returned: PSListController reads _specifiers directly in
    // places an override's return value never reaches, and a page that only returns its list
    // opens to a black screen -- which this project shipped once already.
    _specifiers = specifiers;
    return _specifiers;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = SCILocalized(@"spotify_master");
}

@end
