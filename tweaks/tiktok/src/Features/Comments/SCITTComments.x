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

static NSString *sciCommentsState = nil;
static NSUInteger sciSearchAsked = 0, sciSearchChanged = 0;
static NSUInteger sciTranslateAsked = 0, sciTranslateChanged = 0;

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
        @"%@; search icon asked %lu (answer changed %lu); translate button asked %lu (answer changed %lu)",
        sciCommentsState ?: @"not installed",
        (unsigned long)sciSearchAsked, (unsigned long)sciSearchChanged,
        (unsigned long)sciTranslateAsked, (unsigned long)sciTranslateChanged];
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

    sciCommentsState = [NSString stringWithFormat:@"%@%@",
        installed.count ? [@"installed: " stringByAppendingString:[installed componentsJoinedByString:@", "]] : @"nothing installed",
        skipped.count ? [NSString stringWithFormat:@" — skipped: %@", [skipped componentsJoinedByString:@"; "]] : @""];
    SCILogV(@"[Comments] %@", sciCommentsState);
}
