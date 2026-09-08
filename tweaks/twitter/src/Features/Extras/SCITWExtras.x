#import <UIKit/UIKit.h>
#import "SCITWExtras.h"
#import "Prefs.h"
#import "SCILog.h"

@interface T1StandardStatusAttachmentViewAdapter : NSObject
@property (nonatomic, assign, readonly) NSUInteger attachmentType;
@end

static BOOL sciOn(NSString *key) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

static BOOL sciUndoPresent = NO, sciBioPresent = NO, sciUploadPresent = NO;
static BOOL sciAttachmentPresent = NO, sciTypeaheadPresent = NO;
static BOOL sciRecentViewPresent = NO, sciRecentStorePresent = NO;
static NSUInteger sciUndoForced = 0, sciBioForced = 0, sciUploadForced = 0;
static NSUInteger sciFullFramed = 0, sciQueriesWithheld = 0, sciRTLForced = 0;
static NSUInteger sciResultsWithheld = 0, sciUsersWithheld = 0, sciStoresRefused = 0;


%group ExtrasUndo

%hook TFNTwitterToastNudgeExperimentModel

/// The toast that offers to take a post back. X decides whether to show it from an
/// experiment; this answers yes when asked to.
- (BOOL)shouldShowShowUndoTweetSentToast {
    if (!sciOn(SCIPrefUndoPost)) return %orig;
    sciUndoForced++;
    return YES;
}

%end

%end


%group ExtrasBio

%hook TFNTwitterCanonicalUser

- (BOOL)isProfileBioTranslatable {
    if (!sciOn(SCIPrefBioTranslate)) return %orig;
    sciBioForced++;
    return YES;
}

%end

%end


%group ExtrasUpload

%hook TTMUploadConfiguration

/// Not the upload quality itself -- whether X shows the setting that controls it. The class
/// is `TTMUploadConfiguration` here; BHTwitter names `TFNTwitterMediaUploadConfiguration`,
/// which is not in this build, and taking its name on trust is exactly the mistake this
/// project has three entries in CLAUDE.md about.
- (BOOL)photoUploadHighQualityImagesSettingIsVisible {
    if (!sciOn(SCIPrefHighQualityUpload)) return %orig;
    sciUploadForced++;
    return YES;
}

%end

%end


%group ExtrasAttachment

%hook T1StandardStatusAttachmentViewAdapter

/// A single photo drawn whole instead of cropped to a strip.
///
/// Only for attachment type 2, which is what keeps this from touching a video, a card or a
/// multi-photo grid -- three things a display type of 1 would mean something else for.
- (NSUInteger)displayType {
    if (!sciOn(SCIPrefFullFrameImages)) return %orig;
    if (self.attachmentType != 2) return %orig;

    sciFullFramed++;
    return 1;
}

%end

%end


%group ExtrasTypeahead

%hook TTSSearchTypeaheadViewController

/// Withheld at the setter rather than emptied at the view.
///
/// The class is `TTSSearchTypeaheadViewController` in this build --
/// `T1SearchTypeaheadViewController` is gone -- and `-setRecentQueries:` is a better point
/// than the `-viewDidLoad` a reference tweak uses: nothing downstream is ever handed a list
/// to draw and then asked to un-draw it.
- (void)setRecentQueries:(NSArray *)queries {
    if (!sciOn(SCIPrefNoSearchHistory)) {
        %orig;
        return;
    }
    sciQueriesWithheld++;
    %orig(@[]);
}

/// The accounts half of the same strip.
///
/// A search history is not only what was typed: X keeps the profiles that were searched for
/// beside the words, in two more arrays on this same controller. Emptying one of the three and
/// calling the feature done is why the row went on appearing — **"no search history" is a promise
/// about a surface, and the surface had three inputs.** Both are declared `NSArray`, read off the
/// class's own metadata rather than assumed.
- (void)setRecentUsers:(NSArray *)users {
    if (!sciOn(SCIPrefNoSearchHistory)) {
        %orig;
        return;
    }
    sciUsersWithheld++;
    %orig(@[]);
}

- (void)setRecentUserIDs:(NSArray *)identifiers {
    if (!sciOn(SCIPrefNoSearchHistory)) {
        %orig;
        return;
    }
    %orig(@[]);
}

%end

%end


///
/// **The list the eye actually sees is a different view controller, and that is the whole bug.**
///
/// `TTSSearchTypeaheadViewController` owns a `recentSearchViewController` of its own — a
/// `TTSRecentSearchTypeaheadViewController`, with its own adapter and its own `results` — and
/// that is what draws the row of recent searches. The old hook emptied the parent's
/// `recentQueries` and never touched the child that renders, so the tweak reported queries
/// withheld while the strip sat there in full: a counter moving on a path that is not the path.
///
/// `results` is declared `NSArray` on that class, so `@[]` is its own type rather than a guess.
///
%group ExtrasRecentSearchView

%hook TTSRecentSearchTypeaheadViewController

- (void)setResults:(NSArray *)results {
    if (!sciOn(SCIPrefNoSearchHistory)) {
        %orig;
        return;
    }
    sciResultsWithheld++;
    %orig(@[]);
}

%end

%end


///
/// **And the other half of the report was "it is still being recorded", which no display hook can
/// answer.** `TTSRecentSearchesDatastore` is where a search is written down, and it says so in its
/// own two selectors. Refusing the write is the honest layer: nothing downstream is handed a
/// half-built list to un-draw, which is the distinction the Watch tweak paid a crash for.
///
/// **`-storeRecentSearchUserID:` takes `q`, a long long, not an object** — read from the encoding
/// (`v24@0:8q16`) rather than assumed from the name, which is the mistake that crashed TikTok
/// twice. Declaring it `NSNumber *` here would take an integer as a pointer.
///
/// What this does not do is erase what is already stored: the class offers `clearRecentSearches`
/// and calling it would delete a person's data because they turned a switch on. The display hooks
/// above cover what is already there; deleting it is a decision for whoever owns the phone.
///
%group ExtrasRecentSearchStore

%hook TTSRecentSearchesDatastore

- (void)storeRecentSearchQuery:(id)query {
    if (!sciOn(SCIPrefNoSearchHistory)) {
        %orig;
        return;
    }
    sciStoresRefused++;
}

- (void)storeRecentSearchUserID:(long long)identifier {
    if (!sciOn(SCIPrefNoSearchHistory)) {
        %orig;
        return;
    }
    sciStoresRefused++;
}

%end

%end


%group ExtrasRTL

%hook NSParagraphStyle

+ (NSWritingDirection)defaultWritingDirectionForLanguage:(id)language {
    if (!sciOn(SCIPrefDisableRTL)) return %orig;
    sciRTLForced++;
    return NSWritingDirectionLeftToRight;
}

%end

%end


NSString *SCITWExtrasReport(void) {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];

    if (!sciUndoPresent) [parts addObject:@"undo: class absent"];
    else [parts addObject:[NSString stringWithFormat:@"undo %lu", (unsigned long)sciUndoForced]];

    if (!sciBioPresent) [parts addObject:@"bio: class absent"];
    else [parts addObject:[NSString stringWithFormat:@"bio %lu", (unsigned long)sciBioForced]];

    if (!sciUploadPresent) [parts addObject:@"upload: class absent"];
    else [parts addObject:[NSString stringWithFormat:@"upload %lu", (unsigned long)sciUploadForced]];

    if (!sciAttachmentPresent) [parts addObject:@"full frame: class absent"];
    else [parts addObject:[NSString stringWithFormat:@"full frame %lu", (unsigned long)sciFullFramed]];

    // **Three surfaces, three lines.** One number covering all of them is what let this feature
    // report success while the row it exists to hide stayed on screen: the queries were being
    // withheld and counted, and the list being drawn came from somewhere else entirely.
    if (!sciTypeaheadPresent) [parts addObject:@"typeahead: class absent"];
    else [parts addObject:[NSString stringWithFormat:@"queries %lu · users %lu",
                           (unsigned long)sciQueriesWithheld, (unsigned long)sciUsersWithheld]];

    if (!sciRecentViewPresent) [parts addObject:@"recent view: class absent"];
    else [parts addObject:[NSString stringWithFormat:@"drawn lists withheld %lu",
                           (unsigned long)sciResultsWithheld]];

    if (!sciRecentStorePresent) [parts addObject:@"recent store: class absent"];
    else [parts addObject:[NSString stringWithFormat:@"writes refused %lu",
                           (unsigned long)sciStoresRefused]];

    [parts addObject:[NSString stringWithFormat:@"ltr %lu", (unsigned long)sciRTLForced]];

    return [@"extras: " stringByAppendingString:[parts componentsJoinedByString:@" · "]];
}

void SCITWInstallExtras(void) {
    sciUndoPresent = (NSClassFromString(@"TFNTwitterToastNudgeExperimentModel") != nil);
    if (sciUndoPresent) {
        %init(ExtrasUndo);
    }

    sciBioPresent = (NSClassFromString(@"TFNTwitterCanonicalUser") != nil);
    if (sciBioPresent) {
        %init(ExtrasBio);
    }

    sciUploadPresent = (NSClassFromString(@"TTMUploadConfiguration") != nil);
    if (sciUploadPresent) {
        %init(ExtrasUpload);
    }

    sciAttachmentPresent = (NSClassFromString(@"T1StandardStatusAttachmentViewAdapter") != nil);
    if (sciAttachmentPresent) {
        %init(ExtrasAttachment);
    }

    sciTypeaheadPresent = (NSClassFromString(@"TTSSearchTypeaheadViewController") != nil);
    if (sciTypeaheadPresent) {
        %init(ExtrasTypeahead);
    }

    // Each class decides for itself. A build that renames one of them loses that surface and
    // keeps the others, and the report says which — rather than one flag standing for three.
    sciRecentViewPresent = (NSClassFromString(@"TTSRecentSearchTypeaheadViewController") != nil);
    if (sciRecentViewPresent) {
        %init(ExtrasRecentSearchView);
    }

    sciRecentStorePresent = (NSClassFromString(@"TTSRecentSearchesDatastore") != nil);
    if (sciRecentStorePresent) {
        %init(ExtrasRecentSearchStore);
    }

    // No presence check: NSParagraphStyle is Foundation's and is always there.
    %init(ExtrasRTL);

    SCILogV(@"extras: undo %d, bio %d, upload %d, attachment %d, typeahead %d, "
            @"recent view %d, recent store %d",
            sciUndoPresent, sciBioPresent, sciUploadPresent,
            sciAttachmentPresent, sciTypeaheadPresent,
            sciRecentViewPresent, sciRecentStorePresent);
}
