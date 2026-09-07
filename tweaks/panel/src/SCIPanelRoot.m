#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>

#import "SCIPanelScan.h"
#import "shared/src/Prefs/SCIPanelBadge.h"
#import "shared/src/Prefs/SCIPanelHeader.h"
#import "shared/src/Prefs/SCIPanelAppCell.h"
#import "SCIPanelDomain.h"
#import "shared/src/Prefs/SCIPanelButtonAction.h"
#import "SCIPanelBackup.h"
#import "SCIPanelUpdate.h"
#import "SCIPanelGuideController.h"
#import "SCIPanelLicence.h"
#import "shared/src/SCILicense.h"
#import "Localization/SCILocalize.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <objc/message.h>
#import <objc/runtime.h>

NSString *SCIVersionString = @"v0.9.38";  // AlbrhiPanel

///
/// Albrhi's own control panel, in the iOS Settings app.
///
/// One switch per app Albrhi patches, and nothing else on the screen. This is the shape
/// DLEasy has and it is the right one: a tweak's settings belong somewhere you can reach
/// without opening the app it changes.
///
/// **The switch does not stop the dylib loading; it stops it doing anything.** Changing what
/// gets injected means editing a root-owned filter file, and a preference bundle runs as
/// `mobile`. Every Albrhi tweak instead reads its settings through one function, that
/// function asks this switch first, and with it off every feature answers %orig — the app
/// behaves exactly as though the tweak were not installed.
///
/// Standing down that way rather than skipping hook installation is deliberate. Hooks are
/// installed from a dozen constructors whose order is undefined, so a gate on installation
/// would sometimes catch half of them and leave the app patched in part. Installed-but-inert
/// has no such state.
///
/// Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
///
@interface SCIPanelRootController : PSListController <UIDocumentPickerDelegate>
@end

@implementation SCIPanelRootController

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

    // **Two kinds of row, and mixing them read as one kind badly.**
    //
    // An app row is a switch: "does Albrhi touch Instagram". A tweak row pushes to a page and
    // is not about an app at all -- Albrhi NextUp runs across SpringBoard and five media apps,
    // and Albrhi CarPlay across SpringBoard and Camera. Sorted in among the apps they read as
    // apps this project patches, which is the same misreading `SCIPanelGroupIdentifier` was
    // added to fix one level down: it collapsed seven rows into one, and the one was still
    // sitting in the wrong list.
    //
    // Split by what the entry declares rather than by a name list here, so a tweak that adds a
    // page tomorrow lands in the right section without this file being edited.
    NSMutableArray<SCIPanelEntry *> *entries = [NSMutableArray array];
    NSMutableArray<SCIPanelEntry *> *features = [NSMutableArray array];
    for (SCIPanelEntry *entry in scanned) {
        //
        // **A page is not what decides the section; being about one app is.**
        //
        // The Tweaks section exists for a tweak that runs *across* apps -- NextUp reads five media
        // apps, Watch answers inside SpringBoard and the Watch app -- where an app row would have
        // to pick one of them to be about. A tweak that patches exactly one app belongs with the
        // apps it is listed beside, whether or not it also wants a page: Albrhi for Spotify is
        // collapsed into a group only so it can carry two switches, and that is a fact about its
        // settings, not about what it patches.
        //
        // The icon is what says which case this is, because the scan sets it only when the filter
        // named one real installed app.
        //
        if (entry.detailControllerClassName.length && !entry.appIcon) [features addObject:entry];
        else [entries addObject:entry];
    }

    //
    // **The master switch, above everything it governs.**
    //
    // Its own group, because it is not one of the apps: it decides whether any of them are asked
    // about at all. When an app update breaks something, this is one handle instead of eight --
    // and the moment it is needed is the worst moment to be hunting through rows.
    //
    PSSpecifier *masterGroup = [PSSpecifier preferenceSpecifierNamed:@""
                                                             target:self
                                                                set:NULL
                                                                get:NULL
                                                             detail:Nil
                                                               cell:PSGroupCell
                                                               edit:Nil];
    [masterGroup setProperty:SCILocalized(@"master_footer") forKey:@"footerText"];
    [specifiers addObject:masterGroup];

    //
    // **When the gate is holding everything down, say so at the top and say why.**
    //
    // "Stand down" means every tweak installs no hooks at all, so the apps behave exactly as if
    // Albrhi were not there -- which from the outside is indistinguishable from a broken install.
    // Somebody whose YouTube stopped hiding ads will not think "ah, my licence": they will think
    // the tweak is broken, and the switches below will all be showing ON while nothing happens,
    // which is a screen actively lying.
    //
    // So it goes above the master switch, before anything it governs, and it is a row you can
    // tap straight into the Licence page rather than a sentence in a footer nobody reads.
    //
    if (SCILicenseIsEnforced() && !SCILicenseAllows()) {
        PSSpecifier *halted =
            [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"lic_halted")
                                           target:self
                                              set:NULL
                                              get:NULL
                                           detail:[SCIPanelLicenceController class]
                                             cell:PSLinkCell
                                             edit:Nil];
        [halted setProperty:SCILicenseStatusLine() forKey:@"subtitle"];
        [halted setProperty:SCIPanelBadgeImage(@"exclamationmark.triangle.fill",
                                               [UIColor systemOrangeColor])
                     forKey:@"iconImage"];
        [specifiers addObject:halted];
    }

    PSSpecifier *master = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"master_title")
                                                         target:self
                                                            set:@selector(setMaster:forSpecifier:)
                                                            get:@selector(isMasterOn:)
                                                         detail:Nil
                                                           cell:PSSwitchCell
                                                           edit:Nil];
    [specifiers addObject:master];

    PSSpecifier *group = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"section_apps")
                                                        target:self
                                                           set:NULL
                                                           get:NULL
                                                        detail:Nil
                                                          cell:PSGroupCell
                                                          edit:Nil];
    // **A row that cannot act must not look as though it does.** With the master off, every
    // switch below is still drawn at whatever it was set to, and every one of them is being
    // ignored -- so the footer says so rather than leaving the page to imply otherwise.
    // The gate outranks the master switch in what this footer says, because it outranks it in
    // what actually happens: a row switched on under a closed gate patches nothing.
    [group setProperty:((SCILicenseIsEnforced() && !SCILicenseAllows())
                            ? SCILocalized(@"apps_footer_halted")
                        : [[self isMasterOn:nil] boolValue] ? SCILocalized(@"apps_footer")
                                                          : SCILocalized(@"apps_footer_master_off"))
                forKey:@"footerText"];
    [specifiers addObject:group];

    if (!entries.count) {
        PSSpecifier *none = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"apps_none")
                                                           target:self
                                                              set:NULL
                                                              get:NULL
                                                           detail:Nil
                                                             cell:PSTitleValueCell
                                                             edit:Nil];
        [specifiers addObject:none];
    }

    for (SCIPanelEntry *entry in entries) {
        //
        // **An app row that owns a page pushes to it instead of carrying a switch.**
        //
        // Giving it both would be two controls for one thing: the master switch already lives on
        // the page, and a switch here would write `app_enabled_<bundleid>`, which a tweak gated on
        // its own master never reads -- a switch that moves and changes nothing, which this project
        // has shipped once and does not intend to again.
        //
        if (entry.detailControllerClassName.length) {
            Class detailClass = NSClassFromString(entry.detailControllerClassName);

            // Same reasoning as the Tweaks section below: a row whose page is missing is drawn,
            // dimmed and explained. Installing a tweak before the panel update that carries its
            // page is an ordinary Tuesday, and silence is the worst possible answer to it.
            PSSpecifier *link = [PSSpecifier preferenceSpecifierNamed:entry.appName
                                                               target:self
                                                                  set:NULL
                                                                  get:NULL
                                                               detail:detailClass
                                                                 cell:(detailClass ? PSLinkCell
                                                                                   : PSTitleValueCell)
                                                                 edit:Nil];
            if (!detailClass) {
                [link setProperty:@NO forKey:@"enabled"];
                [link setProperty:SCILocalized(@"tweak_page_missing") forKey:@"sciSubtitle"];
                [link setProperty:@YES forKey:@"sciSubtitleIsWarning"];
                [link setProperty:[SCIPanelAppCell class] forKey:@"cellClass"];
            }

            [link setProperty:entry.bundleIdentifier forKey:@"sciBundleIdentifier"];
            if (entry.appIcon) [link setProperty:entry.appIcon forKey:@"iconImage"];

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

        // An app that is not on the phone gets a switch that cannot be moved.
        // Offering a live switch for an app you do not have is offering a control
        // over nothing.
        if (!entry.appInstalled) {
            [row setProperty:@NO forKey:@"enabled"];
        }

        [row setProperty:entry.bundleIdentifier forKey:@"sciBundleIdentifier"];

        // Everything the versions section used to say, on the row it is about.
        //
        // The cell class is only set on switch rows: a row that pushes to its own page is a
        // PSLinkCell and giving it a switch cell's class would replace the disclosure
        // chevron with a switch that controls nothing.
        BOOL warn = NO;
        NSString *subtitle = [self subtitleForEntry:entry warning:&warn];
        if (subtitle.length) {
            [row setProperty:subtitle forKey:@"sciSubtitle"];
            [row setProperty:@(warn) forKey:@"sciSubtitleIsWarning"];
            // A Class, not its name.
            //
            // This was set to the string @"SCIPanelAppCell", and Preferences takes this
            // property as a Class and sends class messages to it -- so it messaged an
            // NSString and Settings died the moment the page was opened. The name reads
            // identically in the source and is a completely different object.
            [row setProperty:[SCIPanelAppCell class] forKey:@"cellClass"];
        }

        // The app's own icon, so the list is scanned by eye rather than read.
        //
        // Two rows of text that differ by one word are two rows a person has to read;
        // the Instagram glyph and the YouTube glyph are told apart before reading starts.
        // Nil is fine and means no picture, never a blank space where one was promised.
        if (entry.appIcon) [row setProperty:entry.appIcon forKey:@"iconImage"];

        [specifiers addObject:row];
    }

    // The tweaks that own a page, under the apps they run across.
    if (features.count) {
        PSSpecifier *featureGroup =
            [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"section_tweaks")
                                           target:self
                                              set:NULL
                                              get:NULL
                                           detail:Nil
                                             cell:PSGroupCell
                                             edit:Nil];
        [featureGroup setProperty:SCILocalized(@"tweaks_footer") forKey:@"footerText"];
        [specifiers addObject:featureGroup];

        for (SCIPanelEntry *entry in features) {
            Class detailClass = NSClassFromString(entry.detailControllerClassName);

            //
            // **A row whose page is missing is shown and explained, not hidden.**
            //
            // The first version of this skipped the row outright, and that was wrong in the more
            // common direction. Two different situations produce a nil detail class:
            //
            //  - The tweak is *gone* and its filter plist outlived the package -- Albrhi CarPlay,
            //    removed from this repository, whose `AlbrhiCP.plist` still sits beside a dylib on
            //    anyone who installed it. A row here would be a door drawn on a wall.
            //  - The tweak is *newer than the panel*. Albrhi Watch ships as its own package while
            //    its page lives in this bundle, so installing the tweak before the suite update
            //    that carries the page is an ordinary Tuesday -- and hiding the row then tells
            //    somebody who just installed a tweak that it did not install.
            //
            // The second is the one people actually meet, and silence is the worst possible answer
            // to it. So the row is drawn, dimmed, and says why -- which is also true of the first
            // case and costs nothing there.
            //
            if (!detailClass) {
                PSSpecifier *stale = [PSSpecifier preferenceSpecifierNamed:entry.appName
                                                                    target:self
                                                                       set:NULL
                                                                       get:NULL
                                                                    detail:Nil
                                                                      cell:PSTitleValueCell
                                                                      edit:Nil];
                [stale setProperty:@NO forKey:@"enabled"];
                [stale setProperty:SCILocalized(@"tweak_page_missing") forKey:@"sciSubtitle"];
                [stale setProperty:@YES forKey:@"sciSubtitleIsWarning"];
                [stale setProperty:[SCIPanelAppCell class] forKey:@"cellClass"];
                [stale setProperty:SCIPanelBadgeForGroup(entry.bundleIdentifier)
                            forKey:@"iconImage"];
                [specifiers addObject:stale];
                continue;
            }
            PSSpecifier *row = [PSSpecifier preferenceSpecifierNamed:entry.appName
                                                              target:self
                                                                 set:NULL
                                                                 get:NULL
                                                              detail:detailClass
                                                                cell:PSLinkCell
                                                                edit:Nil];
            [row setProperty:entry.bundleIdentifier forKey:@"sciBundleIdentifier"];

            // Its own mark, drawn here. These rows had no icon at all: the scan reads an app
            // icon by bundle identifier, and a group identifier names a tweak rather than an
            // app, so nothing was ever found for them.
            // The app's own icon when the group named one app, the drawn badge otherwise. A
            // grouped row is not automatically iconless -- it is iconless when there is no app to
            // take an icon from, which is a different condition and now asked separately.
            [row setProperty:(entry.appIcon ?: SCIPanelBadgeForGroup(entry.bundleIdentifier))
                      forKey:@"iconImage"];
            [specifiers addObject:row];
        }
    }

    //
    // Guide, update, backup: three things that are about Albrhi itself rather than about any one
    // app, kept together above "About" for that reason.
    //
    PSSpecifier *toolsGroup = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"section_tools")
                                                             target:self
                                                                set:NULL
                                                                get:NULL
                                                             detail:Nil
                                                               cell:PSGroupCell
                                                               edit:Nil];
    [toolsGroup setProperty:SCILocalized(@"tools_footer") forKey:@"footerText"];
    [specifiers addObject:toolsGroup];

    // One row, showing the state in a sentence. The four facts and two actions behind it are a
    // page of their own -- interleaving them with the per-app switches would make two screens
    // out of one, which is the mistake TikTok's settings screen already cost a release.
    PSSpecifier *licence = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"lic_title")
                                                          target:self
                                                             set:NULL
                                                             get:NULL
                                                          detail:[SCIPanelLicenceController class]
                                                            cell:PSLinkCell
                                                            edit:Nil];
    [licence setProperty:SCILicenseStatusLine() forKey:@"subtitle"];
    [specifiers addObject:licence];

    PSSpecifier *guide = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"guide_title")
                                                        target:self
                                                           set:NULL
                                                           get:NULL
                                                        detail:[SCIPanelGuideController class]
                                                          cell:PSLinkCell
                                                          edit:Nil];
    [specifiers addObject:guide];

    PSSpecifier *update = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"update_check")
                                                         target:self
                                                            set:NULL
                                                            get:NULL
                                                         detail:Nil
                                                           cell:PSButtonCell
                                                           edit:Nil];
    SCISetButtonAction(update, @selector(checkForUpdate));
    [specifiers addObject:update];

    PSSpecifier *backup = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"backup_export")
                                                         target:self
                                                            set:NULL
                                                            get:NULL
                                                         detail:Nil
                                                           cell:PSButtonCell
                                                           edit:Nil];
    SCISetButtonAction(backup, @selector(exportSettings));
    [specifiers addObject:backup];

    PSSpecifier *restore = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"backup_import")
                                                          target:self
                                                             set:NULL
                                                             get:NULL
                                                          detail:Nil
                                                            cell:PSButtonCell
                                                            edit:Nil];
    SCISetButtonAction(restore, @selector(importSettings));
    [specifiers addObject:restore];

    PSSpecifier *about = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"section_about")
                                                        target:self
                                                           set:NULL
                                                           get:NULL
                                                        detail:Nil
                                                          cell:PSGroupCell
                                                          edit:Nil];
    [about setProperty:SCILocalized(@"about_note") forKey:@"footerText"];
    [specifiers addObject:about];

    [specifiers addObject:[self valueRow:SCILocalized(@"about_version")
                                   value:[self displayedVersion]]];
    [specifiers addObject:[self valueRow:SCILocalized(@"about_author")
                                   value:SCILocalized(@"about_author_name")]];

    // Respring, in its own group so a destructive-looking button is never a mis-tap away
    // from a row that does nothing.
    PSSpecifier *restartGroup = [PSSpecifier preferenceSpecifierNamed:@""
                                                               target:self
                                                                  set:NULL
                                                                  get:NULL
                                                               detail:Nil
                                                                 cell:PSGroupCell
                                                                 edit:Nil];
    [restartGroup setProperty:SCILocalized(@"respring_note") forKey:@"footerText"];
    [specifiers addObject:restartGroup];

    PSSpecifier *respring = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"respring")
                                                           target:self
                                                              set:NULL
                                                              get:NULL
                                                           detail:Nil
                                                             cell:PSButtonCell
                                                             edit:Nil];
    SCISetButtonAction(respring, @selector(confirmRespring));
    [respring setProperty:@YES forKey:@"isDestructive"];
    [specifiers addObject:respring];

    // The name at the end, in the last footer, where a signature belongs.
    //
    // A value row already says who made it; this is the other thing — the licence and the
    // credit SCInsta is owed, which is a condition of using it and not a courtesy. Both
    // are in the package metadata too, and both being visible on the device matters more
    // than either being tidy.
    PSSpecifier *signature = [PSSpecifier preferenceSpecifierNamed:@""
                                                            target:self
                                                               set:NULL
                                                               get:NULL
                                                            detail:Nil
                                                              cell:PSGroupCell
                                                              edit:Nil];
    [signature setProperty:SCILocalized(@"about_signature") forKey:@"footerText"];
    [specifiers addObject:signature];

    _specifiers = specifiers;
    return _specifiers;
}

/// What each tweak was built against, beside what is on the phone.
///
/// The section exists because "it stopped working after an update" is the single most
/// common thing anyone reports, and this is the page that can answer it without a report
/// being written at all. A row reads "410.1.0 · tested" when they agree and
/// "412.0.0 · tested on 410.1.0" when they do not.
///
/// Nothing is disabled on a mismatch. Nothing is pinned to a version number anywhere in
/// this project and a newer app usually works fine; the point is to show the one fact
/// that explains it when it does not.
///
/// What a row says under the app's name.
///
/// This was a whole second section that listed every app again to state two version
/// numbers. Two passes down the same list to answer one question about one app -- and the
/// switch was in the first pass while the reason you might want to move it was in the
/// second. It is one line under the name now, and the section is gone.
///
/// Every string it can produce is the one the old section used; nothing here changes what
/// is said, only where. Returns nil when there is genuinely nothing to say, and the cell
/// hides the line rather than reserving an empty one.
- (NSString *)subtitleForEntry:(SCIPanelEntry *)entry warning:(BOOL *)warning {
    if (warning) *warning = NO;

    // A row with its own settings page speaks for itself there, and never declares a tested
    // app version -- it does not target one real app the way the others do.
    if (entry.detailControllerClassName.length) return nil;

    if (!entry.appInstalled) return SCILocalized(@"versions_not_installed");

    if (!entry.appVersion.length && !entry.testedVersion.length) {
        return SCILocalized(@"versions_unknown");
    }
    if (!entry.appVersion.length) {
        // Nothing to compare against. The tested version is still worth stating: it is what
        // this tweak is for.
        return [NSString stringWithFormat:SCILocalized(@"versions_tested_only"),
                entry.testedVersion];
    }
    if (!entry.testedVersion.length) return entry.appVersion;

    if ([entry runsTestedVersion]) {
        return [NSString stringWithFormat:SCILocalized(@"versions_match"), entry.appVersion];
    }

    // The one case worth colouring: this build has not been verified against the app on the
    // phone. A caution, not a fault -- see the cell for why it is amber and not red.
    if (warning) *warning = YES;
    return [NSString stringWithFormat:SCILocalized(@"versions_differ"),
            entry.appVersion, entry.testedVersion];
}

/// A row showing a fixed value on the right.
///
/// **The getter is not optional, and that is what was wrong.** Setting the `value`
/// property and passing `get:NULL` reads like it should work and produces a row with the
/// title and an empty space — "Made by" with nobody's name after it. A PSTitleValueCell
/// asks its specifier for a value through the get selector; with none there is nothing
/// to ask and nothing is what it draws. Every value row on this page was blank for it.
- (PSSpecifier *)valueRow:(NSString *)title value:(NSString *)value {
    PSSpecifier *row = [PSSpecifier preferenceSpecifierNamed:title
                                                      target:self
                                                         set:NULL
                                                         get:@selector(fixedValue:)
                                                      detail:Nil
                                                        cell:PSTitleValueCell
                                                        edit:Nil];
    [row setProperty:(value ?: @"") forKey:@"value"];
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

    UIAlertController *note =
        [UIAlertController alertControllerWithTitle:specifier.name
                                            message:SCILocalized(@"switch_restart")
                                     preferredStyle:UIAlertControllerStyleAlert];
    [note addAction:[UIAlertAction actionWithTitle:SCILocalized(@"ok")
                                             style:UIAlertActionStyleDefault
                                           handler:nil]];
    [self presentViewController:note animated:YES completion:nil];
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

    [self say:specifier.name message:SCILocalized(@"switch_restart")];
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
    [self say:SCILocalized(@"update_check") message:SCILocalized(@"update_asking")];

    SCIPanelCheckForUpdate(^(NSString *latest, NSString *installed, BOOL newer) {
        // The alert already on screen is this page's own; dismissing it first means the answer
        // never arrives behind something the user has to clear before reading it.
        [self dismissViewControllerAnimated:YES completion:^{
            NSString *message;

            if (!latest.length) {
                message = SCILocalized(@"update_unreachable");
            } else if (newer) {
                message = [NSString stringWithFormat:SCILocalized(@"update_available"), latest, installed];
            } else if (!installed.length) {
                // No dpkg to ask is not "up to date" -- it is a sideloaded device, where the
                // published version is still the answer to what was asked.
                message = [NSString stringWithFormat:SCILocalized(@"update_latest_only"), latest];
            } else {
                message = [NSString stringWithFormat:SCILocalized(@"update_current"), installed];
            }

            [self say:SCILocalized(@"update_check") message:message];
        }];
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

/// The header is fitted here rather than in -viewDidLoad.
///
/// A table header has to be given a frame, and the width to fit it to is the table's —
/// which is not final until the view has been laid out. Fitting it in -viewDidLoad gives
/// it the width of a view that has not been sized yet, and the header comes out either
/// clipped or floating in the middle of the page.
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    UITableView *table = self.table;
    CGFloat width = table.bounds.size.width;
    if (width <= 0) return;

    // Rebuilt only when the width actually changed -- on rotation, on an iPad split.
    // -viewDidLayoutSubviews runs constantly, and building a view on each pass would
    // rebuild the header while the user is scrolling past it.
    if (table.tableHeaderView && ABS(table.tableHeaderView.frame.size.width - width) < 0.5) return;

    // Counted here rather than cached, so the pill can never disagree with the switches
    // below it -- -viewWillAppear reloads the specifiers on every return to this page, and
    // a header holding its own tally would keep yesterday's answer.
    // **Apps only, now that the tweaks with their own page sit in their own section.**
    //
    // The pill answers "how much of this is switched on", and it sat above a list of app
    // switches while counting rows that are not app switches at all: Albrhi NextUp keeps its
    // state in its own preference domain and never touches the panel's key, so it counted as
    // off forever and the total it was measured against included it. A tally whose denominator
    // holds rows the numerator cannot reach is wrong in both halves at once.
    NSInteger on = 0, total = 0;
    for (SCIPanelEntry *entry in [SCIPanelScan entries]) {
        if (entry.detailControllerClassName.length) continue;
        if (!entry.appInstalled) continue;
        total++;
        if ([[self isOnForSpecifierWithIdentifier:entry.bundleIdentifier] boolValue]) on++;
    }

    UIView *header = [SCIPanelHeader viewForWidth:width
                                          version:[self displayedVersion]
                                               on:on
                                               of:total];
    if (header) table.tableHeaderView = header;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadSpecifiers];
}

@end
