//
//  SCITTComments.x
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "SCITTComments.h"
#import "../../Prefs.h"
#import "../../SCILog.h"
#import "../../Localization/SCILocalize.h"
#import "../Download/SCITTDownload.h"
#import "../../UI/SCITTToast.h"
#import "shared/src/SCIKVC.h"

///
/// **Search and translate the comments with TikTok's own code, not a copy of it.**
///
/// The comment panel of TikTok 47.4.0 already contains both. Search: `TTKCommentSearchEntranceComponent` (with
/// `TTKCommentSearchEntranceButton` and the result views `TTKSearchComment…`), shown when `+[TTKABTest searchCommentIconEnabled]` answers
/// yes -- a server-side experiment flag, read by `-[TTKPlayInteractionCommentManager presenterDidBuildCommentVC:]` when the panel is built.
/// Translate: `AWECommentsTranslationController` (batch translation, inline translation, the "show original" label) draws its translate-all
/// button when `-isTranslationButtonDisplayEnabled` is yes.
///
/// Both are the **decision**, so the app builds nothing it was not going to build and the person gets TikTok's own interface, in the right
/// place, in the right language and mirrored on an Arabic phone. The alternative -- a search box and a translator of our own over the loaded
/// comment list -- is a second implementation of something the app does, and was not written for that reason.
///
/// **What this cannot promise, and does not pretend to.** A flag forced here changes the client's question only. If TikTok's server does
/// not serve comment search or translation for the account, the icon can appear and then show nothing, and no tweak can change that. The
/// Status screen counts how many times each question was asked and how many answers this changed (a question that is never asked is a
/// gate on a path nothing takes; an answer that was already yes is a switch that did nothing). **Not run on a device**, and not runnable
/// in the simulator: a signed-out TikTok has no comment panel features to ask for.
///

@interface TTKABTest : NSObject
@end

@interface TTKCommentListRowActionCopyHandler : NSObject
@end

@interface TTKCommentCopyOperation : NSObject
@end


// The Swift class behind the long-press row "Save photo". Named at run time (it is `_TtC17TikTokCommentImpl36CommentListRowActionSavePhotoHandler`).
@interface SCICommentSavePhoto : NSObject
@end

static NSString *sciCommentsState = nil;
static NSUInteger sciSearchAsked = 0, sciSearchChanged = 0;
static NSUInteger sciTranslateAsked = 0, sciTranslateChanged = 0;
static NSUInteger sciCopyCleaned = 0, sciCopyByTail = 0, sciCopyKept = 0;
static NSUInteger sciStickerOffered = 0, sciStickerTapped = 0, sciStickerNoLink = 0;
static NSString *sciCopyLastKept = nil;

// MARK: - The comment under the finger

///
/// **The comment a long-press row acts on is `context.selectedComment`**, on the handler the row belongs to (`TTKCommentListRowActionItemHandler
/// -context`, `TTKCommentListRowActionContext -selectedComment`; `-comment` is the same object for a top-level comment and the *reply* is
/// `selectedComment` when a reply was pressed). Read through the safe accessors: these are the app's own models and a half-built one must
/// answer nil, not trap.
///
static id SCITTCommentOf(id handler) {
    id context = SCISafeValueForKey(handler, @"context");
    return SCISafeValueForKey(context, @"selectedComment") ?: SCISafeValueForKey(context, @"comment");
}

/// The comment being copied right now, set for exactly the length of the Copy row's own action. The Copy handler calls
/// `+[TTKCommentCopyOperation copyContent:tokenText:identifier:]` synchronously from `-handleAction` (seen in the disassembly and in the call
/// trace), so a plain static is a correct scope, not a hope.
static __weak id sciCopyingComment = nil;

// MARK: - Copy a comment without the name in front

///
/// **What Copy puts on the pasteboard, and why the first attempt at this missed it.** The text handed to the copy operation is
/// `@<nickname>: <comment>` (measured: `@Sophie_rose 🥀: imagine it's a mom spider ...`). The 0.19.14 version removed a leading name with a
/// pattern for "word characters then a colon", and a TikTok nickname is not a word: it carries spaces, flags, emoji and Arabic marks
/// (`ابولين وليان🇾🇪🇦🇪 العامري`, `SULTAN🫅🏾`). So the name is not *recognised* here, it is *known*: the model of the comment being copied says
/// its author's nickname and its own text, and the prefix removed is exactly `@` + that nickname + the colon that follows it.
///
/// Conservative in two ways, because a wrong cut is worse than an untouched copy. A prefix that is not exactly the known name is not
/// removed; the fallback is the comment's own `content` when the copied text ends with it and what comes before it ends in a colon (the
/// shape changed, the comment did not). And a copy that would be left empty is left alone.
///
// host-test:begin copyname
static NSString *SCITTCopyWithoutName(NSString *copied, id comment, BOOL *outByTail) {
    if (![copied isKindOfClass:[NSString class]] || !copied.length || !comment) return nil;

    NSString *nickname = SCISafeValueForKey(SCISafeValueForKey(comment, @"author"), @"nickname");
    NSString *own = SCISafeValueForKey(comment, @"content");

    NSString *rest = nil;
    if ([nickname isKindOfClass:[NSString class]] && nickname.length) {
        NSString *tag = [@"@" stringByAppendingString:nickname];
        if ([copied hasPrefix:tag]) {
            NSString *after = [copied substringFromIndex:tag.length];
            NSCharacterSet *colons = [NSCharacterSet characterSetWithCharactersInString:@":\uFF1A"];
            if (after.length && [colons characterIsMember:[after characterAtIndex:0]]) {
                rest = [[after substringFromIndex:1] stringByTrimmingCharactersInSet:
                        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
            }
        }
    }

    if (!rest && [own isKindOfClass:[NSString class]] && own.length && [copied hasSuffix:own] && copied.length > own.length) {
        NSString *head = [[copied substringToIndex:copied.length - own.length] stringByTrimmingCharactersInSet:
                          [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (head.length && head.length <= 120 && ([head hasSuffix:@":"] || [head hasSuffix:@"\uFF1A"])) {
            rest = own;
            if (outByTail) *outByTail = YES;
        }
    }

    return rest.length ? rest : nil;
}
// host-test:end copyname

%group SCITTCommentCopy

%hook TTKCommentListRowActionCopyHandler

- (void)handleAction {
    if (!SCIPrefEnabled(SCIPrefCommentCleanCopy)) {
        %orig;
        return;
    }
    sciCopyingComment = SCITTCommentOf(self);
    %orig;
    sciCopyingComment = nil;
}

%end

%hook TTKCommentCopyOperation

+ (void)copyContent:(id)content tokenText:(id)token identifier:(id)identifier {
    id comment = sciCopyingComment;
    if (!comment || !SCIPrefEnabled(SCIPrefCommentCleanCopy)) {
        %orig;
        return;
    }

    BOOL byTail = NO;
    NSString *clean = SCITTCopyWithoutName(content, comment, &byTail);
    if (!clean) {
        // Said, not hidden: the copy went through with the name, and the Status screen shows how long the text was and that it was left.
        sciCopyKept++;
        sciCopyLastKept = [NSString stringWithFormat:@"%lu characters, name not matched", (unsigned long)([content isKindOfClass:[NSString class]] ? [(NSString *)content length] : 0)];
        %orig;
        return;
    }

    sciCopyCleaned++;
    if (byTail) sciCopyByTail++;
    %orig(clean, token, identifier);
}

%end
%end

// MARK: - Save a comment's sticker

///
/// **TikTok's long-press panel already has a row for a comment's picture, and it is the right place for ours.** The panel is a list of row
/// handlers (`TTKCommentListRowAction…Handler`, one class each: Report, Translate, Copy, and the Swift `…SavePhotoHandler`,
/// `…SaveStickerHandler`, `…PhotoToStickerHandler`); each answers three gates (`isBasicRequirementEnabled`, `isInteractionEnabled`,
/// `isManagementEnabled`) and the panel then draws a cell from the handler's own `longPressTitle` and `longPressIconImage` and calls
/// `didSelectedCell` on a tap (measured with a call trace on 47.1.0). **The `TUXActionSheetAction` a handler also builds
/// (`makeActionItem`, through `TTKCommentListRowActionItemFactory`) is the older action-sheet style, which this panel does not draw:** the
/// first version of this hooked that and the row appeared with TikTok's title and a tap that reached nothing of ours.
///
/// **What TikTok offers for a sticker is "Save sticker", which adds it to the account's sticker favourites and saves nothing to Photos.** "Save
/// photo" is for a comment that carries a *photo* (`imageList`) and only when its author allows it (`allowDownloadPhoto`). A sticker is a
/// library item (a model `hasSticker`, `stickerData`), not somebody's own picture, so the Save-photo handler is answered YES for a sticker
/// comment and its title, icon and action are replaced for that comment alone. Nothing is bypassed: a *photo* comment is not touched, and
/// its author's choice still decides.
///
/// The links are the sticker's own (`stickerData.animatedUrl` and `.staticUrl`, each in three sizes, each an `AWEURLModel` with an
/// `originURLList`), handed to the same saver as a photo post -- which measures them, takes the largest that decodes, and keeps an animated
/// WebP moving as a GIF.
///
static BOOL SCITTIsStickerComment(id comment) {
    if (!comment) return NO;
    return SCISafeBoolForKey(comment, @"hasSticker")
        && !SCISafeBoolForKey(comment, @"hasImage")
        && !SCISafeBoolForKey(comment, @"isLivePhotoComment");
}

static NSArray<NSURL *> *SCITTStickerLinks(id comment) {
    id data = SCISafeValueForKey(comment, @"stickerData");
    if (!data) return @[];

    NSMutableArray<NSURL *> *links = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    // Largest size first, the animated one before the still of the same size; the saver measures them anyway and this is only the order it
    // meets ties in.
    for (NSString *size in @[@"highResolutionURL", @"midResolutionURL", @"lowResolutionURL"]) {
        for (NSString *kind in @[@"animatedUrl", @"staticUrl"]) {
            id model = SCISafeValueForKey(SCISafeValueForKey(data, kind), size);
            id list = SCISafeValueForKey(model, @"originURLList");
            if (![list isKindOfClass:[NSArray class]]) continue;
            for (id entry in (NSArray *)list) {
                if (![entry isKindOfClass:[NSString class]] || [seen containsObject:entry]) continue;
                NSURL *url = [NSURL URLWithString:entry];
                if (!url || !([url.scheme isEqualToString:@"https"] || [url.scheme isEqualToString:@"http"])) continue;
                [seen addObject:entry];
                [links addObject:url];
            }
        }
    }
    return links;
}

/// The row's icon: the system's "save" arrow, in the colour of the other rows' icons (black on the light panel, white on the dark one), **not a
/// template image** -- a template takes the app's tint, which is blue here, and every neighbouring icon is plain. Built once, with a dark variant
/// registered on it so the right one is drawn whichever way the phone is set.
static UIImage *SCITTStickerRowIcon(void) {
    static UIImage *icon = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        UIImageSymbolConfiguration *size = [UIImageSymbolConfiguration configurationWithPointSize:19 weight:UIImageSymbolWeightRegular];
        UIImage *base = [UIImage systemImageNamed:@"arrow.down.to.line" withConfiguration:size];
        UIImage *light = [base imageWithTintColor:[UIColor blackColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
        UIImage *dark = [base imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
        if (light && dark) {
            [light.imageAsset registerImage:dark withTraitCollection:[UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleDark]];
        }
        icon = light ?: base;
    });
    return icon;
}

%group SCITTCommentSticker
%hook SCICommentSavePhoto

- (BOOL)isBasicRequirementEnabled {
    BOOL original = %orig;
    if (original || !SCIPrefEnabled(SCIPrefCommentSaveSticker)) return original;
    if (!SCITTIsStickerComment(SCITTCommentOf(self))) return original;
    sciStickerOffered++;
    return YES;
}

- (BOOL)isInteractionEnabled {
    BOOL original = %orig;
    if (original || !SCIPrefEnabled(SCIPrefCommentSaveSticker)) return original;
    return SCITTIsStickerComment(SCITTCommentOf(self));
}

- (id)longPressTitle {
    if (SCIPrefEnabled(SCIPrefCommentSaveSticker) && SCITTIsStickerComment(SCITTCommentOf(self))) return SCILocalized(@"comment_sticker_save");
    return %orig;
}

- (id)longPressIconImage {
    if (SCIPrefEnabled(SCIPrefCommentSaveSticker) && SCITTIsStickerComment(SCITTCommentOf(self))) return SCITTStickerRowIcon();
    return %orig;
}

- (void)didSelectedCell {
    id comment = SCITTCommentOf(self);
    if (!SCIPrefEnabled(SCIPrefCommentSaveSticker) || !SCITTIsStickerComment(comment)) {
        %orig;
        return;
    }

    sciStickerTapped++;
    NSArray<NSURL *> *links = SCITTStickerLinks(comment);
    if (!links.count) {
        sciStickerNoLink++;
        SCITTRecordDownload(@"comment sticker — the model offered no link");
        [SCITTToast noticeWithText:SCILocalized(@"comment_sticker_none") symbol:@"exclamationmark.circle"];
        return;
    }
    // One picture offered several ways: the saver measures them, takes the largest it can read, and says which.
    [SCITTDownload savePhotos:@[links]];
}

%end
%end

%group SCITTCommentSearch
%hook TTKABTest

+ (BOOL)searchCommentIconEnabled {
    BOOL original = %orig;
    if (!SCIPrefEnabled(SCIPrefCommentSearch)) return original;
    sciSearchAsked++;
    if (!original) sciSearchChanged++;
    return YES;
}

%end
%end

%group SCITTCommentTranslate
%hook AWECommentsTranslationController

- (BOOL)isTranslationButtonDisplayEnabled {
    BOOL original = %orig;
    if (!SCIPrefEnabled(SCIPrefCommentTranslate)) return original;
    sciTranslateAsked++;
    if (!original) sciTranslateChanged++;
    return YES;
}

%end
%end

NSString *SCITTCommentsReport(void) {
    return [NSString stringWithFormat:
        @"%@; search icon asked %lu (answer changed %lu); translate button asked %lu (answer changed %lu); "
        @"copy without the name: cleaned %lu (by the comment's own text %lu), left as TikTok wrote it %lu%@; "
        @"sticker row: offered %lu, tapped %lu, no link %lu",
        sciCommentsState ?: @"not installed",
        (unsigned long)sciSearchAsked, (unsigned long)sciSearchChanged,
        (unsigned long)sciTranslateAsked, (unsigned long)sciTranslateChanged,
        (unsigned long)sciCopyCleaned, (unsigned long)sciCopyByTail, (unsigned long)sciCopyKept,
        sciCopyLastKept ? [NSString stringWithFormat:@" (last: %@)", sciCopyLastKept] : @"",
        (unsigned long)sciStickerOffered, (unsigned long)sciStickerTapped, (unsigned long)sciStickerNoLink];
}

void SCITTInstallComments(void) {
    NSMutableArray<NSString *> *installed = [NSMutableArray array];
    NSMutableArray<NSString *> *skipped = [NSMutableArray array];

    Class abtest = NSClassFromString(@"TTKABTest");
    Method search = abtest ? class_getClassMethod(abtest, sel_registerName("searchCommentIconEnabled")) : NULL;
    const char *searchTypes = search ? method_getTypeEncoding(search) : NULL;
    if (searchTypes && strcmp(searchTypes, "B16@0:8") == 0) {
        %init(SCITTCommentSearch);
        [installed addObject:@"comment search"];
    } else {
        [skipped addObject:@"+[TTKABTest searchCommentIconEnabled]"];
    }

    Class translation = NSClassFromString(@"AWECommentsTranslationController");
    Method translate = translation ? class_getInstanceMethod(translation, sel_registerName("isTranslationButtonDisplayEnabled")) : NULL;
    const char *translateTypes = translate ? method_getTypeEncoding(translate) : NULL;
    if (translateTypes && strcmp(translateTypes, "B16@0:8") == 0) {
        %init(SCITTCommentTranslate);
        [installed addObject:@"comment translation"];
    } else {
        [skipped addObject:@"AWECommentsTranslationController -isTranslationButtonDisplayEnabled"];
    }

    // Copy without the name: both ends of it are checked, because the first scopes the second.
    Class copyHandler = NSClassFromString(@"TTKCommentListRowActionCopyHandler");
    Class copyOperation = NSClassFromString(@"TTKCommentCopyOperation");
    Method handle = copyHandler ? class_getInstanceMethod(copyHandler, sel_registerName("handleAction")) : NULL;
    Method operation = copyOperation ? class_getClassMethod(copyOperation, sel_registerName("copyContent:tokenText:identifier:")) : NULL;
    const char *handleTypes = handle ? method_getTypeEncoding(handle) : NULL;
    const char *operationTypes = operation ? method_getTypeEncoding(operation) : NULL;
    if (handleTypes && strcmp(handleTypes, "v16@0:8") == 0 && operationTypes && strcmp(operationTypes, "v40@0:8@16@24@32") == 0) {
        %init(SCITTCommentCopy);
        [installed addObject:@"copy without the name"];
    } else {
        [skipped addObject:@"TTKCommentListRowActionCopyHandler -handleAction / +[TTKCommentCopyOperation copyContent:tokenText:identifier:]"];
    }

    // The sticker row: the Swift handler whose gates, title, icon and tap are answered for a sticker comment.
    Class savePhoto = NSClassFromString(@"_TtC17TikTokCommentImpl36CommentListRowActionSavePhotoHandler");
    static const struct { const char *selector; const char *encoding; } kRow[] = {
        {"isBasicRequirementEnabled", "B16@0:8"},
        {"isInteractionEnabled", "B16@0:8"},
        {"longPressTitle", "@16@0:8"},
        {"longPressIconImage", "@16@0:8"},
        {"didSelectedCell", "v16@0:8"},
    };
    BOOL rowOK = savePhoto != Nil;
    NSString *rowMissing = nil;
    for (size_t i = 0; rowOK && i < sizeof(kRow) / sizeof(kRow[0]); i++) {
        Method m = class_getInstanceMethod(savePhoto, sel_registerName(kRow[i].selector));
        const char *types = m ? method_getTypeEncoding(m) : NULL;
        if (!types || strcmp(types, kRow[i].encoding) != 0) {
            rowOK = NO;
            rowMissing = [NSString stringWithUTF8String:kRow[i].selector];
        }
    }
    if (rowOK) {
        %init(SCITTCommentSticker, SCICommentSavePhoto = savePhoto);
        [installed addObject:@"comment sticker row"];
    } else {
        [skipped addObject:[NSString stringWithFormat:@"…CommentListRowActionSavePhotoHandler (%@)", rowMissing ?: @"class absent"]];
    }

    sciCommentsState = [NSString stringWithFormat:@"%@%@",
        installed.count ? [@"installed: " stringByAppendingString:[installed componentsJoinedByString:@", "]] : @"nothing installed",
        skipped.count ? [NSString stringWithFormat:@" — skipped: %@", [skipped componentsJoinedByString:@"; "]] : @""];
    SCILogV(@"[Comments] %@", sciCommentsState);
}
