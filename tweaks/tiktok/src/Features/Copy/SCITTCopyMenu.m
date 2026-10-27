//
//  SCITTCopyMenu.m
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCITTCopyMenu.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import "../../UI/SCITTSheet.h"
#import "../../UI/SCITTToast.h"
#import "../../Localization/SCILocalize.h"

///
/// **A menu of our own, on the button of our own, because TikTok's long-press panel is not ours to extend.**
///
/// A reference tweak adds rows to the feed's own long-press panel (`TTKShareLongPressFeedAdapter` and its registry). That panel is built
/// from a view model several classes deep and was never read for this file; the download button is this tweak's, its sheet is this
/// tweak's, and the model behind a video (`AWEAwemeModel`) is already what every other feature here reads. The fields below are read from
/// 47.1.0's class metadata, each with an `@` return:
///
///   AWEAwemeModel   -author -> AWEUserModel -uniqueIDForShow / -signature
///   AWEAwemeModel   -music  -> AWEMusicModel -shareInfo -> AWEShareInfoModel -shareUrl
///   AWEAwemeModel   -descriptionString, -shareURL
///
/// **Not run on a device.** A field that comes back empty is a row that is not drawn, and the report counts how often that happened.
///

static NSUInteger sciCopyAsked = 0, sciCopyOffered = 0, sciCopyCopied = 0, sciCopyEmpty = 0;

/// An object-returning accessor, asked only when the object has it and declares it as returning an object.
static id SCITTObjectFor(id object, NSString *name) {
    if (!object) return nil;
    SEL selector = NSSelectorFromString(name);
    Method method = class_getInstanceMethod(object_getClass(object), selector);
    const char *types = method ? method_getTypeEncoding(method) : NULL;
    if (!types || types[0] != '@') return nil;
    return ((id (*)(id, SEL))objc_msgSend)(object, selector);
}

static NSString *SCITTTextOf(id value) {
    NSString *text = nil;
    if ([value isKindOfClass:[NSString class]]) text = value;
    else if ([value isKindOfClass:[NSURL class]]) text = [(NSURL *)value absoluteString];
    text = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return text.length ? text : nil;
}

static void SCITTCopyToPasteboard(NSString *text) {
    [UIPasteboard generalPasteboard].string = text;
    sciCopyCopied++;
    [SCITTToast noticeWithText:SCILocalized(@"copy_done") symbol:@"doc.on.doc.fill"];
}

void SCITTShowCopyMenu(id awemeModel) {
    sciCopyAsked++;
    if (!awemeModel || ![SCITTSheet canPresent]) {
        sciCopyEmpty++;
        return;
    }

    id user = SCITTObjectFor(awemeModel, @"author") ?: SCITTObjectFor(awemeModel, @"getAuthorModel");
    NSString *username = SCITTTextOf(SCITTObjectFor(user, @"uniqueIDForShow"));
    NSString *bio = SCITTTextOf(SCITTObjectFor(user, @"signature"));

    id music = SCITTObjectFor(awemeModel, @"music") ?: SCITTObjectFor(awemeModel, @"getMusicModel");
    NSString *musicLink = SCITTTextOf(SCITTObjectFor(SCITTObjectFor(music, @"shareInfo"), @"shareUrl"));

    NSString *postLink = SCITTTextOf(SCITTObjectFor(awemeModel, @"shareURL"));
    if (!postLink) postLink = SCITTTextOf(SCITTObjectFor(SCITTObjectFor(awemeModel, @"shareInfo"), @"shareUrl"));
    NSString *description = SCITTTextOf(SCITTObjectFor(awemeModel, @"descriptionString"));

    NSMutableArray<SCITTSheetAction *> *actions = [NSMutableArray array];
    void (^add)(NSString *, NSString *, NSString *) = ^(NSString *titleKey, NSString *symbol, NSString *text) {
        if (!text) return;
        [actions addObject:[SCITTSheetAction title:SCILocalized(titleKey) symbol:symbol primary:NO handler:^{
            SCITTCopyToPasteboard(text);
        }]];
    };

    add(@"copy_username", @"person.fill", username);
    add(@"copy_bio", @"text.alignleft", bio);
    add(@"copy_music", @"music.note", musicLink);

    if (description || postLink) {
        NSMutableArray<NSString *> *parts = [NSMutableArray array];
        if (username) [parts addObject:[@"@" stringByAppendingString:username]];
        if (description) [parts addObject:description];
        if (postLink) [parts addObject:postLink];
        add(@"copy_info", @"doc.text.fill", [parts componentsJoinedByString:@"\n"]);
    }

    if (!actions.count) {
        sciCopyEmpty++;
        [SCITTToast noticeWithText:SCILocalized(@"copy_nothing") symbol:@"questionmark.circle"];
        return;
    }

    sciCopyOffered++;
    [SCITTSheet showTitle:SCILocalized(@"copy_title")
                  message:nil
                   symbol:@"doc.on.doc"
                  actions:actions
                   cancel:SCILocalized(@"photos_cancel")];
}

NSString *SCITTCopyReport(void) {
    return [NSString stringWithFormat:@"menus asked %lu, offered %lu, nothing to offer %lu, rows copied %lu",
            (unsigned long)sciCopyAsked, (unsigned long)sciCopyOffered, (unsigned long)sciCopyEmpty, (unsigned long)sciCopyCopied];
}
