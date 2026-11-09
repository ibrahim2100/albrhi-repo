#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>

#import "SCIPanelScan.h"
#import "shared/src/Prefs/SCIPanelAppCell.h"
#import "SCIPanelDomain.h"
#import "shared/src/Prefs/SCIPanelButtonAction.h"
#import "SCIPanelBackup.h"
#import "SCIPanelUpdate.h"
#import "SCIPanelGuideController.h"
#import "Design/SCIPanelStyle.h"
#import "Design/SCIPanelCells.h"
#import "Design/SCIPanelHero.h"
#import "Localization/SCILocalize.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <objc/message.h>
#import <objc/runtime.h>

NSString *SCIVersionString = @"v0.11.0";  // AlbrhiPanel

@interface SCIPanelRootController : PSListController <UIDocumentPickerDelegate>
@end

@implementation SCIPanelRootController {
    /// Where the update question stands, shown on its own row and nowhere else (never asked on page load; only on a tap).
    NSInteger _updateState;      // 0 not asked, 1 asking, 2 current, 3 newer published, 4 unreachable, 5 published version known but nothing to compare
    NSString *_updateLatest;
}

/// Named identically in shared/src/SCIPanelGate.m, which is the half that reads it. Two
/// spellings of this string is a switch that appears to work and changes nothing.
static NSString *const kSCIPanelDomain = kSCIPanelPreferenceDomain;

/// Rebuilt on every appearance rather than cached for the life of the process.
///
/// Settings keeps a preference bundle loaded after its page is closed, so a cached list
/// would still show a tweak that has since been uninstalled.
- (NSArray *)specifiers {
    NSArray<SCIPanelEntry *> *scanned = [SCIPanelScan entries];
    NSMutableArray *specifiers = [NSMutableArray array];
    const CGFloat side = SCIPanelTileSide;

    // **Two kinds of row, split by what the entry declares and never by a name list here**, so a tweak that adds a page tomorrow lands in the
    // right section without this file being edited. An app row is "does Albrhi touch Instagram"; a tweak row is a tweak that runs *across*
    // apps (NextUp reads five media apps, Watch answers inside SpringBoard and the Watch app) and has a page of its own. A tweak that patches
    // exactly one app belongs with the apps even when it also owns a page -- the icon says which case it is, because the scan sets it only
    // when the filter named one real installed app.
    NSMutableArray<SCIPanelEntry *> *entries = [NSMutableArray array];
    NSMutableArray<SCIPanelEntry *> *features = [NSMutableArray array];
    for (SCIPanelEntry *entry in scanned) {
        if (entry.detailControllerClassName.length && !SCIPanelIsKnownApp(entry.bundleIdentifier) && !entry.appInstalled) [features addObject:entry];
        else [entries addObject:entry];
    }

    BOOL masterOn = [[self isMasterOn:nil] boolValue];
    NSInteger on = 0;
    for (SCIPanelEntry *entry in entries) {
        if (entry.detailControllerClassName.length || !entry.appInstalled) continue;
        if ([[self isOnForSpecifierWithIdentifier:entry.bundleIdentifier] boolValue]) on++;
    }

    //
    // The master switch, above everything it governs. Its own group because it is not one of the apps: it decides whether any of them are
    // asked about at all. When an app update breaks something this is one handle instead of eight -- and the moment it is needed is the worst
    // moment to be hunting through rows. Its second line says what the switch is doing *now*.
    //
    [specifiers addObject:[self groupNamed:@"" footer:SCILocalized(@"master_footer")]];
    PSSpecifier *master = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"master_title")
                                                         target:self
                                                            set:@selector(setMaster:forSpecifier:)
                                                            get:@selector(isMasterOn:)
                                                         detail:Nil
                                                           cell:PSSwitchCell
                                                           edit:Nil];
    [master setProperty:[SCIPanelSwitchRowCell class] forKey:@"cellClass"];
    [master setProperty:@72 forKey:@"height"];
    [master setProperty:masterOn
        ? SCIPanelSymbolTile(@"power", [UIColor colorWithRed:0.30 green:0.85 blue:0.48 alpha:1], [UIColor colorWithRed:0.10 green:0.66 blue:0.36 alpha:1], side)
        : SCIPanelSymbolTile(@"power", [UIColor colorWithRed:0.62 green:0.62 blue:0.68 alpha:1], [UIColor colorWithRed:0.42 green:0.42 blue:0.48 alpha:1], side)
                 forKey:SCIPanelRowTileKey];
    [master setProperty:(!masterOn ? SCILocalized(@"master_status_off")
                                   : (on > 0 ? (on == 1 ? SCILocalized(@"master_status_one") : [NSString stringWithFormat:SCILocalized(@"master_status_on"), (long)on])
                                             : SCILocalized(@"master_status_none")))
                 forKey:SCIPanelRowSubtitleKey];
    [master setProperty:@(masterOn && on > 0 ? SCIPanelToneGood : SCIPanelToneQuiet) forKey:SCIPanelRowToneKey];
    [specifiers addObject:master];

    //
    // The apps. **Every row carries an icon, installed or not**: the phone's own when it gave one, otherwise a tile drawn here in the app's
    // colours (SCIPanelAppTile) -- so a list never has a hole where a picture was promised and every row is the same size.
    //
    [specifiers addObject:[self groupNamed:SCILocalized(@"section_apps")
                                    footer:(masterOn ? SCILocalized(@"apps_footer") : SCILocalized(@"apps_footer_master_off"))]];

    if (!entries.count) {
        PSSpecifier *none = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"apps_none")
                                                           target:self set:NULL get:NULL detail:Nil cell:PSTitleValueCell edit:Nil];
        [none setProperty:[SCIPanelRowCell class] forKey:@"cellClass"];
        [none setProperty:@64 forKey:@"height"];
        [none setProperty:SCIPanelSymbolTile(@"questionmark", [UIColor colorWithWhite:0.6 alpha:1], [UIColor colorWithWhite:0.42 alpha:1], side) forKey:SCIPanelRowTileKey];
        [specifiers addObject:none];
    }

    for (SCIPanelEntry *entry in entries) {
        UIImage *tile = SCIPanelTileForEntry(entry, side);

        // An app row that owns a page pushes to it instead of carrying a switch. Giving it both would be two controls for one thing: the
        // master switch already lives on the page, and a switch here would write `app_enabled_<bundleid>`, which a tweak gated on its own
        // master never reads -- a switch that moves and changes nothing, which this project has shipped once.
        if (entry.detailControllerClassName.length) {
            Class detailClass = NSClassFromString(entry.detailControllerClassName);
            PSSpecifier *link = [PSSpecifier preferenceSpecifierNamed:entry.appName
                                                               target:self set:NULL get:NULL
                                                               detail:detailClass
                                                                 cell:(detailClass ? PSLinkCell : PSTitleValueCell)
                                                                 edit:Nil];
            [link setProperty:[SCIPanelRowCell class] forKey:@"cellClass"];
            [link setProperty:@64 forKey:@"height"];
            [link setProperty:tile forKey:SCIPanelRowTileKey];
            [link setProperty:entry.bundleIdentifier forKey:@"sciBundleIdentifier"];
            if (!detailClass) {
                // Installing a tweak before the panel update that carries its page is an ordinary Tuesday: the row is drawn, dimmed and
                // explained, and silence is the worst possible answer to it.
                [link setProperty:@NO forKey:@"enabled"];
                [link setProperty:SCILocalized(@"tweak_page_missing") forKey:SCIPanelRowSubtitleKey];
                [link setProperty:@(SCIPanelToneCaution) forKey:SCIPanelRowToneKey];
            }
            [specifiers addObject:link];
            continue;
        }

        PSSpecifier *row = [PSSpecifier preferenceSpecifierNamed:entry.appName
                                                          target:self
                                                             set:@selector(setOn:forSpecifier:)
                                                             get:@selector(isOnForSpecifier:)
                                                          detail:Nil
                                                            cell:PSSwitchCell
                                                            edit:Nil];
        // An app that is not on the phone gets a switch that cannot be moved: a live switch for an app you do not have is a control over nothing.
        if (!entry.appInstalled) [row setProperty:@NO forKey:@"enabled"];

        [row setProperty:entry.bundleIdentifier forKey:@"sciBundleIdentifier"];
        // A Class, not its name: Preferences sends class messages to this property and a string there killed Settings once.
        [row setProperty:[SCIPanelSwitchRowCell class] forKey:@"cellClass"];
        [row setProperty:@64 forKey:@"height"];
        [row setProperty:tile forKey:SCIPanelRowTileKey];

        // No second line: the versions and the "tested on" notes live in the Guide, where they are about one tweak at a time. An app that is not
        // installed is a dimmed row with a switch that cannot be moved, and the footer says what that means.
        [specifiers addObject:row];
    }

    // The tweaks that own a page, under the apps they run across.
    if (features.count) {
        [specifiers addObject:[self groupNamed:SCILocalized(@"section_tweaks") footer:SCILocalized(@"tweaks_footer")]];

        for (SCIPanelEntry *entry in features) {
            Class detailClass = NSClassFromString(entry.detailControllerClassName);
            UIImage *tile = SCIPanelTileForEntry(entry, side);

            // A row whose page is missing is shown and explained, not hidden: the tweak may be gone with its filter plist left behind (a door
            // drawn on a wall), or newer than the panel (Watch ships on its own while its page lives in this bundle) -- the second is the one
            // people meet, and hiding the row then tells somebody who just installed a tweak that it did not install.
            PSSpecifier *row = [PSSpecifier preferenceSpecifierNamed:entry.appName
                                                              target:self set:NULL get:NULL
                                                              detail:detailClass
                                                                cell:(detailClass ? PSLinkCell : PSTitleValueCell)
                                                                edit:Nil];
            [row setProperty:[SCIPanelRowCell class] forKey:@"cellClass"];
            [row setProperty:@64 forKey:@"height"];
            [row setProperty:tile forKey:SCIPanelRowTileKey];
            [row setProperty:entry.bundleIdentifier forKey:@"sciBundleIdentifier"];
            if (!detailClass) {
                [row setProperty:@NO forKey:@"enabled"];
                [row setProperty:SCILocalized(@"tweak_page_missing") forKey:SCIPanelRowSubtitleKey];
                [row setProperty:@(SCIPanelToneCaution) forKey:SCIPanelRowToneKey];
            }
            [specifiers addObject:row];
        }
    }

    //
    // **Updates: one section, about Albrhi as a whole.** It used to be a button among the tools that answered in an alert; it is its own
    // section now, shows where the question stands on the row itself, and is still only ever asked on a tap -- never on page load.
    //
    [specifiers addObject:[self groupNamed:SCILocalized(@"section_updates") footer:SCILocalized(@"updates_footer")]];
    PSSpecifier *update = [PSSpecifier preferenceSpecifierNamed:[NSString stringWithFormat:SCILocalized(@"update_row_title"), [self displayedVersion]]
                                                         target:self set:NULL get:NULL detail:Nil cell:PSButtonCell edit:Nil];
    SCISetButtonAction(update, @selector(checkForUpdate));
    [update setProperty:[SCIPanelRowCell class] forKey:@"cellClass"];
    [update setProperty:@68 forKey:@"height"];
    UIColor *updateTop = [UIColor colorWithRed:0.30 green:0.62 blue:1 alpha:1], *updateBottom = [UIColor colorWithRed:0.16 green:0.40 blue:0.92 alpha:1];
    NSString *updateSymbol = @"arrow.triangle.2.circlepath";
    NSString *updateLine = SCILocalized(@"update_idle");
    SCIPanelTone updateTone = SCIPanelToneQuiet;
    switch (_updateState) {
        case 1: updateLine = SCILocalized(@"update_checking"); break;
        case 2: updateLine = SCILocalized(@"update_inline_current"); updateTone = SCIPanelToneGood; updateSymbol = @"checkmark.seal.fill";
                updateTop = [UIColor colorWithRed:0.30 green:0.85 blue:0.48 alpha:1]; updateBottom = [UIColor colorWithRed:0.10 green:0.66 blue:0.36 alpha:1]; break;
        case 3: updateLine = [NSString stringWithFormat:SCILocalized(@"update_inline_available"), _updateLatest ?: @""]; updateTone = SCIPanelToneCaution; updateSymbol = @"arrow.down.circle.fill";
                updateTop = [UIColor colorWithRed:1 green:0.66 blue:0.22 alpha:1]; updateBottom = [UIColor colorWithRed:0.95 green:0.45 blue:0.10 alpha:1]; break;
        case 4: updateLine = SCILocalized(@"update_inline_unreachable"); updateTone = SCIPanelToneBad; updateSymbol = @"wifi.exclamationmark";
                updateTop = [UIColor colorWithRed:1 green:0.45 blue:0.40 alpha:1]; updateBottom = [UIColor colorWithRed:0.86 green:0.25 blue:0.22 alpha:1]; break;
        case 5: updateLine = [NSString stringWithFormat:SCILocalized(@"update_inline_latest_only"), _updateLatest ?: @""]; break;
        default: break;
    }
    [update setProperty:SCIPanelSymbolTile(updateSymbol, updateTop, updateBottom, side) forKey:SCIPanelRowTileKey];
    [update setProperty:updateLine forKey:SCIPanelRowSubtitleKey];
    [update setProperty:@(updateTone) forKey:SCIPanelRowToneKey];
    [update setProperty:@(_updateState == 1) forKey:SCIPanelRowBusyKey];
    [specifiers addObject:update];

    //
    // The guide and the backup: things about Albrhi itself rather than about any one app.
    //
    [specifiers addObject:[self groupNamed:SCILocalized(@"section_tools") footer:SCILocalized(@"tools_footer")]];

    PSSpecifier *guide = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"guide_title")
                                                        target:self set:NULL get:NULL detail:[SCIPanelGuideController class] cell:PSLinkCell edit:Nil];
    [guide setProperty:[SCIPanelRowCell class] forKey:@"cellClass"];
    [guide setProperty:@64 forKey:@"height"];
    [guide setProperty:SCIPanelSymbolTile(@"book.fill", [UIColor colorWithRed:0.27 green:0.80 blue:0.78 alpha:1], [UIColor colorWithRed:0.10 green:0.58 blue:0.62 alpha:1], side) forKey:SCIPanelRowTileKey];
    [specifiers addObject:guide];

    PSSpecifier *backup = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"backup_export")
                                                         target:self set:NULL get:NULL detail:Nil cell:PSButtonCell edit:Nil];
    SCISetButtonAction(backup, @selector(exportSettings));
    [backup setProperty:[SCIPanelRowCell class] forKey:@"cellClass"];
    [backup setProperty:@64 forKey:@"height"];
    [backup setProperty:SCIPanelSymbolTile(@"square.and.arrow.up.fill", [UIColor colorWithRed:0.62 green:0.46 blue:1 alpha:1], [UIColor colorWithRed:0.42 green:0.30 blue:0.86 alpha:1], side) forKey:SCIPanelRowTileKey];
    [specifiers addObject:backup];

    PSSpecifier *restore = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"backup_import")
                                                          target:self set:NULL get:NULL detail:Nil cell:PSButtonCell edit:Nil];
    SCISetButtonAction(restore, @selector(importSettings));
    [restore setProperty:[SCIPanelRowCell class] forKey:@"cellClass"];
    [restore setProperty:@64 forKey:@"height"];
    [restore setProperty:SCIPanelSymbolTile(@"square.and.arrow.down.fill", [UIColor colorWithRed:0.95 green:0.45 blue:0.72 alpha:1], [UIColor colorWithRed:0.82 green:0.26 blue:0.54 alpha:1], side) forKey:SCIPanelRowTileKey];
    [specifiers addObject:restore];

    [specifiers addObject:[self groupNamed:SCILocalized(@"section_about") footer:nil]];
    [specifiers addObject:[self valueRow:SCILocalized(@"about_version") value:[self displayedVersion] symbol:@"number.circle.fill"]];
    [specifiers addObject:[self valueRow:SCILocalized(@"about_author") value:SCILocalized(@"about_author_name") symbol:@"person.crop.circle.fill"]];

    // Respring, in its own group so a destructive-looking button is never a mis-tap away from a row that does nothing.
    [specifiers addObject:[self groupNamed:@"" footer:SCILocalized(@"respring_note")]];
    PSSpecifier *respring = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"respring")
                                                           target:self set:NULL get:NULL detail:Nil cell:PSButtonCell edit:Nil];
    SCISetButtonAction(respring, @selector(confirmRespring));
    [respring setProperty:[SCIPanelRowCell class] forKey:@"cellClass"];
    [respring setProperty:@64 forKey:@"height"];
    [respring setProperty:@YES forKey:SCIPanelRowDestructiveKey];
    [respring setProperty:SCIPanelSymbolTile(@"arrow.clockwise", [UIColor colorWithRed:1 green:0.45 blue:0.40 alpha:1], [UIColor colorWithRed:0.86 green:0.25 blue:0.22 alpha:1], side) forKey:SCIPanelRowTileKey];
    [specifiers addObject:respring];

    // The name at the end, in the last footer, where a signature belongs: the licence and the credit SCInsta is owed, which is a condition of
    // using it and not a courtesy. Both are in the package metadata too, and both being visible on the device matters more than either being tidy.
    [specifiers addObject:[self groupNamed:@"" footer:SCILocalized(@"about_signature")]];

    _specifiers = specifiers;
    return _specifiers;
}

/// A group header. `name` empty draws none.
- (PSSpecifier *)groupNamed:(NSString *)name footer:(NSString *)footer {
    PSSpecifier *group = [PSSpecifier preferenceSpecifierNamed:name target:self set:NULL get:NULL detail:Nil cell:PSGroupCell edit:Nil];
    if (footer.length) [group setProperty:footer forKey:@"footerText"];
    return group;
}

/// A row showing a fixed value on the right.
///
/// **The getter is not optional, and that is what was wrong.** Setting the `value`
/// property and passing `get:NULL` reads like it should work and produces a row with the
/// title and an empty space — "Made by" with nobody's name after it. A PSTitleValueCell
/// asks its specifier for a value through the get selector; with none there is nothing
/// to ask and nothing is what it draws. Every value row on this page was blank for it.
- (PSSpecifier *)valueRow:(NSString *)title value:(NSString *)value symbol:(NSString *)symbol {
    PSSpecifier *row = [PSSpecifier preferenceSpecifierNamed:title
                                                      target:self
                                                         set:NULL
                                                         get:@selector(fixedValue:)
                                                      detail:Nil
                                                        cell:PSTitleValueCell
                                                        edit:Nil];
    [row setProperty:(value ?: @"") forKey:@"value"];
    [row setProperty:(value ?: @"") forKey:SCIPanelRowValueKey];
    [row setProperty:[SCIPanelRowCell class] forKey:@"cellClass"];
    [row setProperty:@56 forKey:@"height"];
    [row setProperty:SCIPanelSymbolTile(symbol, [UIColor colorWithRed:0.62 green:0.62 blue:0.70 alpha:1], [UIColor colorWithRed:0.42 green:0.42 blue:0.52 alpha:1], SCIPanelTileSide - 8) forKey:SCIPanelRowTileKey];
    return row;
}

- (id)fixedValue:(PSSpecifier *)specifier {
    return [specifier propertyForKey:@"value"] ?: @"";
}

/// The number to put in front of someone.
///
/// What dpkg says is installed, which is the combined package they chose. This bundle's
/// own `SCIVersionString` only when nothing can be read — and then it is shown with the
/// component's name attached, because "0.6.0" on its own is a number that matches nothing
/// they have ever seen.
- (NSString *)displayedVersion {
    NSString *installed = [SCIPanelScan installedSuiteVersion];
    if (installed.length) return installed;

    return [NSString stringWithFormat:SCILocalized(@"about_version_panel"), SCIVersionString];
}

// MARK: - Respring

- (void)confirmRespring {
    UIAlertController *ask =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"respring")
                                            message:SCILocalized(@"respring_confirm")
                                     preferredStyle:UIAlertControllerStyleAlert];

    [ask addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];

    [ask addAction:[UIAlertAction actionWithTitle:SCILocalized(@"respring")
                                            style:UIAlertActionStyleDestructive
                                          handler:^(UIAlertAction *action) {
        [self respring];
    }]];

    [self presentViewController:ask animated:YES completion:nil];
}

/// Asks the system to restart SpringBoard.
///
/// **Not `killall SpringBoard`.** This bundle runs as `mobile` inside Settings and has no
/// business signalling another process even if it were permitted — the supported route is
/// to ask FrontBoard for a relaunch, which is the same one the Settings app itself uses
/// when a language changes.
///
/// Every class and selector here is looked up at runtime and checked. A respring button
/// that does nothing is a disappointment; a preference bundle that throws while Settings
/// is showing it is a Settings app that closes.
- (void)respring {
    Class actionClass = NSClassFromString(@"SBSRelaunchAction");
    Class serviceClass = NSClassFromString(@"FBSSystemService");

    SEL make = NSSelectorFromString(@"actionWithReason:options:targetURL:");
    SEL shared = NSSelectorFromString(@"sharedService");
    SEL send = NSSelectorFromString(@"sendActions:withResult:");

    if (!actionClass || !serviceClass ||
        ![actionClass respondsToSelector:make] || ![serviceClass respondsToSelector:shared]) {
        [self sayRespringFailed];
        return;
    }

    @try {
        // Option 4 is RelaunchActionOptionsFadeToBlackTransition, which is what a respring
        // looks like everywhere else on the system.
        id action = ((id (*)(id, SEL, id, NSUInteger, id))objc_msgSend)(
            actionClass, make, @"Albrhi", (NSUInteger)4, nil);

        id service = ((id (*)(id, SEL))objc_msgSend)(serviceClass, shared);
        if (!action || !service || ![service respondsToSelector:send]) {
            [self sayRespringFailed];
            return;
        }

        ((void (*)(id, SEL, id, id))objc_msgSend)(
            service, send, [NSSet setWithObject:action], nil);
    } @catch (__unused NSException *exception) {
        [self sayRespringFailed];
    }
}

- (void)sayRespringFailed {
    UIAlertController *note =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"respring")
                                            message:SCILocalized(@"respring_failed")
                                     preferredStyle:UIAlertControllerStyleAlert];
    [note addAction:[UIAlertAction actionWithTitle:SCILocalized(@"ok")
                                             style:UIAlertActionStyleDefault
                                           handler:nil]];
    [self presentViewController:note animated:YES completion:nil];
}

/// The same question -isOnForSpecifier: answers, asked about an identifier instead of a row.
///
/// The header needs the count before any specifier exists to ask. Sharing this one reader is
/// what stops the pill and the switches from drifting apart -- the panel already answers this
/// question in three places across two processes, and CLAUDE.md records what the third one
/// cost when it was missed.
- (NSNumber *)isOnForSpecifierWithIdentifier:(NSString *)identifier {
    if (!identifier.length) return @NO;

    CFPropertyListRef value = CFPreferencesCopyAppValue(
        (__bridge CFStringRef)[@"app_enabled_" stringByAppendingString:identifier],
        (__bridge CFStringRef)kSCIPanelDomain);

    if (!value) return @NO;

    BOOL on = (CFGetTypeID(value) == CFBooleanGetTypeID())
        ? CFBooleanGetValue((CFBooleanRef)value) : NO;
    CFRelease(value);
    return @(on);
}

- (NSString *)keyFor:(PSSpecifier *)specifier {
    return [@"app_enabled_" stringByAppendingString:
        [specifier propertyForKey:@"sciBundleIdentifier"]];
}

- (id)isOnForSpecifier:(PSSpecifier *)specifier {
    CFPropertyListRef value = CFPreferencesCopyAppValue(
        (__bridge CFStringRef)[self keyFor:specifier], (__bridge CFStringRef)kSCIPanelDomain);

    // Never written means off, and this **must** match SCIPanelGate's reading exactly.
    //
    // These are two separate answers to one question -- the panel decides what the switch
    // looks like, the gate decides whether the dylib does anything -- and they are read in
    // different processes from different code. Leaving this one at YES while the gate moved
    // to NO would draw every switch on while every tweak stayed off: the worst of the two
    // possible bugs, because the screen would be actively lying rather than merely
    // surprising. The reasoning for opt-in is written out once, in SCIPanelGate.h.
    if (!value) return @NO;

    BOOL on = (CFGetTypeID(value) == CFBooleanGetTypeID())
        ? CFBooleanGetValue((CFBooleanRef)value) : NO;
    CFRelease(value);
    return @(on);
}

- (void)setOn:(NSNumber *)value forSpecifier:(PSSpecifier *)specifier {
    CFPreferencesSetAppValue((__bridge CFStringRef)[self keyFor:specifier],
                             (__bridge CFPropertyListRef)@(value.boolValue),
                             (__bridge CFStringRef)kSCIPanelDomain);

    // Written through immediately. Left to its own schedule, cfprefsd can hold this long
    // enough that relaunching the app -- exactly what someone does next -- reads the old
    // value and the switch looks broken.
    CFPreferencesAppSynchronize((__bridge CFStringRef)kSCIPanelDomain);

    // No alert. A dialog after every flip of a switch is a page that talks over its own controls; what the person needs to know -- that the app
    // must be reopened -- is said once, under the list. The count in the card above is what changed, so that is redrawn.
    [self reloadSpecifiers];
    [self refreshHero];
}

// MARK: - The master switch

//
// Read and written here, and read by every tweak through SCIPanelMasterEnabled(). Two answers
// to one question in two processes -- exactly the shape that made a per-app switch draw itself
// on while the gate held it off -- so the default below and the gate's default are the same
// value for the same stated reason: absent means nobody has pulled the handle.
//
- (id)isMasterOn:(PSSpecifier *)specifier {
    CFPropertyListRef value = CFPreferencesCopyAppValue(CFSTR("albrhi_master_enabled"),
                                                        (__bridge CFStringRef)kSCIPanelPreferenceDomain);
    if (!value) return @YES;

    BOOL on = (CFGetTypeID(value) == CFBooleanGetTypeID())
        ? CFBooleanGetValue((CFBooleanRef)value) : YES;
    CFRelease(value);
    return @(on);
}

- (void)setMaster:(NSNumber *)value forSpecifier:(PSSpecifier *)specifier {
    CFPreferencesSetAppValue(CFSTR("albrhi_master_enabled"),
                             (__bridge CFPropertyListRef)@(value.boolValue),
                             (__bridge CFStringRef)kSCIPanelPreferenceDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)kSCIPanelPreferenceDomain);

    // The apps footer states whether the switches below it are being obeyed, so it is stale the
    // instant this changes. Rebuilt rather than edited: this page is built in one pass and a
    // second, partial update of it is how two descriptions of one state start to disagree.
    [self reloadSpecifiers];
    [self refreshHero];
}

// MARK: - Backup

- (void)exportSettings {
    NSURL *file = SCIPanelBackupWrite();
    if (!file) {
        [self say:SCILocalized(@"backup_export") message:SCILocalized(@"backup_failed")];
        return;
    }

    UIActivityViewController *share =
        [[UIActivityViewController alloc] initWithActivityItems:@[file] applicationActivities:nil];

    // An iPad presents this from a popover and refuses without an anchor. Settings is a split
    // view there, so the row that was tapped is not reachable from here -- the view itself is.
    share.popoverPresentationController.sourceView = self.view;
    share.popoverPresentationController.sourceRect =
        CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);

    [self presentViewController:share animated:YES completion:nil];
}

- (void)importSettings {
    UIDocumentPickerViewController *picker =
        [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypePropertyList, UTTypeData]];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller
didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSInteger restored = SCIPanelBackupRestore(urls.firstObject);

    if (restored < 0) {
        [self say:SCILocalized(@"backup_import") message:SCILocalized(@"backup_not_ours")];
        return;
    }

    [self reloadSpecifiers];
    [self say:SCILocalized(@"backup_import")
      message:[NSString stringWithFormat:SCILocalized(@"backup_restored"), (long)restored]];
}

// MARK: - Updates

- (void)checkForUpdate {
    if (_updateState == 1) return;
    _updateState = 1;
    [self reloadSpecifiers];

    SCIPanelCheckForUpdate(^(NSString *latest, NSString *installed, BOOL newer) {
        // The answer is written on the row, where the question was asked: no alert to clear, nothing to read behind something else.
        _updateLatest = latest;
        if (!latest.length) _updateState = 4;                 // the question went unanswered -- deliberately not "up to date"
        else if (newer) _updateState = 3;
        else if (!installed.length) _updateState = 5;         // a sideloaded device: the published version is still the answer to what was asked
        else _updateState = 2;
        [self reloadSpecifiers];
    });
}

// MARK: -

/// One alert, one place. Four callers building their own is four chances to forget the button.
- (void)say:(NSString *)title message:(NSString *)message {
    UIAlertController *note = [UIAlertController alertControllerWithTitle:title
                                                                 message:message
                                                          preferredStyle:UIAlertControllerStyleAlert];
    [note addAction:[UIAlertAction actionWithTitle:SCILocalized(@"ok")
                                             style:UIAlertActionStyleDefault
                                           handler:nil]];
    [self presentViewController:note animated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = SCILocalized(@"panel_title");
}

/// The header is fitted here rather than in -viewDidLoad: a table header has to be given a frame, and the width to fit it to is the table's,
/// which is not final until the view has been laid out.
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self refreshHero];
}

/// Rebuilds the card when what it says changed (the width, the version, how many apps are on, the master switch), and only then:
/// -viewDidLayoutSubviews runs constantly, and building a view on each pass would rebuild the card while somebody is scrolling past it.
/// The tally is counted here, not cached, so the card can never disagree with the switches under it.
- (void)refreshHero {
    UITableView *table = self.table;
    CGFloat width = table.bounds.size.width;
    if (width <= 0) return;

    NSInteger on = 0, total = 0;
    for (SCIPanelEntry *entry in [SCIPanelScan entries]) {
        if (entry.detailControllerClassName.length) continue;
        if (!entry.appInstalled) continue;
        total++;
        if ([[self isOnForSpecifierWithIdentifier:entry.bundleIdentifier] boolValue]) on++;
    }
    BOOL masterOn = [[self isMasterOn:nil] boolValue];

    NSString *key = [NSString stringWithFormat:@"%.1f|%@|%ld|%ld|%d", width, [self displayedVersion], (long)on, (long)total, masterOn];
    if (table.tableHeaderView && [objc_getAssociatedObject(table, "sciHeroKey") isEqualToString:key]) return;

    UIView *header = [SCIPanelHero viewForWidth:width version:[self displayedVersion] on:on of:total masterOn:masterOn];
    if (!header) return;
    table.tableHeaderView = header;
    objc_setAssociatedObject(table, "sciHeroKey", key, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadSpecifiers];
}

@end
