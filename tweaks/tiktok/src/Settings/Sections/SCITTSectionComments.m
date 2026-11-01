//
//  SCITTSectionComments.m
//  Albrhi for TikTok
//
//  TikTok's own comment search and translation, switched on; copying a comment without the name; saving a comment's sticker.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "../SCITTStatus.h"
#import "../SCITTReport.h"
#import "../SCITTBadge.h"
#import "../../Tweak.h"
#import "../../Prefs.h"
#import "../../Localization/SCILocalize.h"
#import "../SCITTSectionRegistry.h"

@interface SCITTSectionComments : NSObject
@end

@implementation SCITTSectionComments

+ (void)load {
    SCITTRegisterSection(42, ^NSDictionary *{
        NSDictionary *(^row)(NSString *, NSString *, NSString *, NSString *, UIColor *) =
            ^NSDictionary *(NSString *pref, NSString *title, NSString *note, NSString *icon, UIColor *color) {
            return @{
                kSCIRowKind: kSCIKindSwitch,
                kSCIRowPref: pref,
                kSCIRowTitle: title,
                kSCIRowNote: note,
                kSCIRowIcon: icon,
                kSCIRowColor: color,
            };
        };
        return @{
            kSCISectionIcon: @"text.bubble.fill",
            kSCISectionColor: [UIColor systemTealColor],
            kSCISectionTitle: SCILocalized(@"section_comments"),
            kSCISectionRows: @[
                row(SCIPrefCommentSearch, SCILocalized(@"row_comment_search"), SCILocalized(@"row_comment_search_note"), @"magnifyingglass", [UIColor systemTealColor]),
                row(SCIPrefCommentTranslate, SCILocalized(@"row_comment_translate"), SCILocalized(@"row_comment_translate_note"), @"character.bubble.fill", [UIColor systemBlueColor]),
                row(SCIPrefCommentCleanCopy, SCILocalized(@"row_comment_clean_copy"), SCILocalized(@"row_comment_clean_copy_note"), @"doc.on.doc.fill", [UIColor systemIndigoColor]),
                row(SCIPrefCommentSaveSticker, SCILocalized(@"row_comment_save_sticker"), SCILocalized(@"row_comment_save_sticker_note"), @"arrow.down.to.line", [UIColor systemGreenColor]),
            ],
        };
    });
}

@end
