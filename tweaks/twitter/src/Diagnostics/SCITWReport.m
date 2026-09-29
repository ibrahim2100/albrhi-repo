#import "SCITWReport.h"
#import "Tweak.h"
#import "Prefs.h"
#import "Features/Switches/SCITWSwitches.h"
#import "Features/Switches/SCITWFeatures.h"
#import "Features/Media/SCITWImmersiveButton.h"
#import "Features/Ads/SCITWPromotedFilter.h"
#import "Features/Confirm/SCITWRepostConfirm.h"
#import "Features/Media/SCITWAvatarSave.h"
#import "Features/Playback/SCITWPictureInPicture.h"
#import "Features/Tabs/SCITWTabEntries.h"
#import "Features/Spaces/SCITWSpacesBar.h"
#import "Features/Links/SCITWLinks.h"
#import "Features/Timeline/SCITWTimelineFilter.h"
#import "Features/Actions/SCITWActionRow.h"
#import "Features/Extras/SCITWExtras.h"
#import "Features/Profile/SCITWProfileCopy.h"
#import "Features/Lock/SCITWAppLock.h"

NSString *SCITWReportText(void) {
    NSMutableString *text = [NSMutableString string];

    [text appendFormat:@"Albrhi for X %@\n", SCIVersionString];
    [text appendFormat:@"app %@ (%@)\n",
        [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"?",
        [[NSBundle mainBundle] bundleIdentifier] ?: @"?"];
    [text appendFormat:@"written %@\n\n", [NSDate date]];

    // The panel switch first, because when it is off everything below is empty and the
    // reason has to be at the top rather than inferred from an absence.
    [text appendFormat:@"panel gate: %@\n", SCIPanelGateReport()];

    NSArray<NSString *> *providers = [SCITWSwitches attachedProviders];
    [text appendFormat:@"providers hooked: %@\n",
        providers.count ? [providers componentsJoinedByString:@", "] : @"NONE"];

    // The button, before the switches, because it is what gets reported about.
    //
    // A page that describes three hundred feature switches in detail and says nothing at
    // all about whether the download button attached is a page that answers the question
    // nobody asked. This line is the one somebody writing in about a missing button needs
    // to paste, and until now there was nothing to paste.
    [text appendFormat:@"immersive button: %@\n", SCITWImmersiveButtonReport()];
    [text appendFormat:@"promoted-tweet filter: %@\n", SCITWPromotedFilterReport()];
    [text appendFormat:@"repost confirm: %@\n", SCITWRepostConfirmReport()];
    [text appendFormat:@"avatar save: %@\n", SCITWAvatarSaveReport()];
    [text appendFormat:@"picture-in-picture: %@\n", SCITWPictureInPictureReport()];
    [text appendFormat:@"in-video button: %@\n", SCITWInVideoButtonReport()];
    [text appendFormat:@"%@\n", SCITWTabEntriesReport()];
    [text appendFormat:@"%@\n", SCITWSpacesBarReport()];
    [text appendFormat:@"%@\n", SCITWLinksReport()];
    [text appendFormat:@"%@\n", SCITWTimelineFilterReport()];
    [text appendFormat:@"%@\n", SCITWActionRowReport()];
    [text appendFormat:@"%@\n", SCITWExtrasReport()];
    [text appendFormat:@"%@\n", SCITWProfileCopyReport()];
    [text appendFormat:@"%@\n", SCITWAppLockReport()];

    NSArray<SCITWSwitchRecord *> *records = [SCITWSwitches records];
    [text appendFormat:@"switches seen: %lu over %lu questions\n\n",
        (unsigned long)records.count, (unsigned long)[SCITWSwitches totalAsked]];

    // The named features, before the raw keys. A report that lists forty forced keys and
    // does not say they came from one switch reads as somebody having set forty things by
    // hand, and the first question back is always "what did you actually turn on".
    NSMutableArray<NSString *> *on = [NSMutableArray array];
    for (SCITWFeature *feature in [SCITWFeatures all]) {
        if ([SCITWFeatures isOn:feature]) [on addObject:feature.identifier];
    }
    [text appendFormat:@"features on: %@\n\n",
        on.count ? [on componentsJoinedByString:@", "] : @"none"];

    //
    // **What each switched-on feature actually did, key by key.**
    //
    // "The option does not work" has three different causes and the list above cannot tell them
    // apart: the feature is off; it is on and the app never asks that key; or it is on, the app
    // asks, the override is applied — and the thing on screen is not decided by that key at all.
    // Only the third means the key is wrong, and only the third is worth a new hook.
    //
    // This project has written the same rule twice already, about a diagnostic that recorded the
    // last event instead of a tally and about a counter sitting off the path that runs. **A report
    // that cannot separate causes sends the next release at the wrong one** -- which is exactly
    // what happened to the TikTok download button for three releases.
    //
    for (SCITWFeature *feature in [SCITWFeatures all]) {
        if (![SCITWFeatures isOn:feature]) continue;

        [text appendFormat:@"  %@:\n", feature.identifier];

        for (NSString *key in feature.keys) {
            SCITWSwitchRecord *seen = nil;
            for (SCITWSwitchRecord *record in [SCITWSwitches records]) {
                if ([record.key isEqualToString:key]) { seen = record; break; }
            }

            NSNumber *wanted = feature.keys[key];

            if (!seen) {
                [text appendFormat:@"    %@ — never asked\n", key];
            } else {
                [text appendFormat:@"    %@ — asked %lu, app said %@, we answer %@\n",
                    key, (unsigned long)seen.asked,
                    seen.appAnswer ? @"on" : @"off",
                    wanted.boolValue ? @"on" : @"off"];
            }
        }
    }

    [text appendString:@"\n"];

    NSDictionary<NSString *, NSNumber *> *overrides = [SCITWSwitches allOverrides];
    NSDictionary<NSString *, NSNumber *> *fromFeatures = [SCITWSwitches featureOverrides];

    // Overridden keys are listed twice on purpose: once here as their own short list, and
    // again in place below. The short list is what someone pastes into a bug report, and
    // hunting for five changed rows in four hundred is how a report arrives without them.
    [text appendFormat:@"changed by the user: %lu\n", (unsigned long)overrides.count];
    for (NSString *key in [[overrides allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
        [text appendFormat:@"  %@ = %@\n", key, overrides[key].boolValue ? @"on" : @"off"];
    }

    [text appendString:@"\n--- every switch seen, most asked first ---\n"];
    for (SCITWSwitchRecord *record in records) {
        // Hand-set beats a feature, exactly as the hot path decides it. Written the same
        // way in both places rather than summarised here: a report that disagrees with the
        // code it describes is worse than no report, because it is believed.
        NSNumber *byHand = overrides[record.key];
        NSNumber *byFeature = fromFeatures[record.key];
        NSNumber *effective = byHand ?: byFeature;

        NSString *note = @"";
        if (effective) {
            note = [NSString stringWithFormat:@"  -> %@ (%@)",
                effective.boolValue ? @"on" : @"off",
                byHand ? @"by hand" : @"feature"];
        }

        [text appendFormat:@"%7lu  %@  %@%@\n",
            (unsigned long)record.asked,
            record.appAnswer ? @"on " : @"off",
            record.key,
            note];
    }

    return text;
}

NSString *SCITWWriteReport(void) {
    NSString *documents = [NSSearchPathForDirectoriesInDomains(
        NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    if (!documents.length) return nil;

    NSString *name = @"AlbrhiTW-report.txt";
    NSString *path = [documents stringByAppendingPathComponent:name];

    // A ceiling, like every other report file in this repository: nothing here should be able to
    // grow past a megabyte however long the recorder has been running.
    NSString *text = SCITWReportText();
    const NSUInteger kMaxBytes = 1000 * 1000;
    if ([text lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > kMaxBytes) {
        text = [[text substringToIndex:MIN(text.length, kMaxBytes / 3)]
                stringByAppendingString:@"\n\n--- report cut at 1 MB ---\n"];
    }

    NSError *error = nil;
    BOOL wrote = [text writeToFile:path
                                     atomically:YES
                                       encoding:NSUTF8StringEncoding
                                          error:&error];

    return wrote ? name : nil;
}
