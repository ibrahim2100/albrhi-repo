//
//  SCITTSectionConfirm.m
//  Albrhi for TikTok
//
//  Actions that ask before they happen.
//
//  **One section, one file, registered by itself.** It was a block inside a 220-line array
//  literal in SCITTStatus.m; adding a row meant editing the middle of that list and deleting
//  a feature meant counting braces. Nothing outside this file knows the section exists --
//  see SCITTSectionRegistry.h for why that is the point.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "../SCITTStatus.h"
#import "../SCITTReport.h"
#import "../SCITTBadge.h"
#import "../../UI/SCITTWelcome.h"
#import "../../Tweak.h"
#import "../../Prefs.h"
#import "../../Localization/SCILocalize.h"
#import <objc/runtime.h>
#import "../SCITTSectionRegistry.h"

@interface SCITTSectionConfirm : NSObject
@end

@implementation SCITTSectionConfirm

+ (void)load {
    SCITTRegisterSection(50, ^NSDictionary *{
        return @{
            // Its own section rather than a row under Watching: these two do not change what TikTok
            // shows, they change what a tap does -- the only feature here that stands between the
            // user and an action they are already making.
            kSCISectionIcon: @"checkmark.shield.fill",
            kSCISectionColor: [UIColor systemGreenColor],
            kSCISectionTitle: SCILocalized(@"section_confirm"),
            kSCISectionRows: @[
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefConfirmLike,
                    kSCIRowTitle: SCILocalized(@"row_confirm_like"),
                    kSCIRowNote: SCILocalized(@"row_confirm_like_note"),
                    kSCIRowIcon: @"heart.fill",
                    kSCIRowColor: [UIColor systemRedColor],
                },
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefConfirmFollow,
                    kSCIRowTitle: SCILocalized(@"row_confirm_follow"),
                    kSCIRowNote: SCILocalized(@"row_confirm_follow_note"),
                    kSCIRowIcon: @"person.badge.plus",
                    kSCIRowColor: [UIColor systemPinkColor],
                },
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefConfirmCommentLike,
                    kSCIRowTitle: SCILocalized(@"row_confirm_comment_like"),
                    kSCIRowNote: SCILocalized(@"row_confirm_comment_like_note"),
                    kSCIRowIcon: @"text.bubble.fill",
                    kSCIRowColor: [UIColor systemRedColor],
                },
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefConfirmCommentDislike,
                    kSCIRowTitle: SCILocalized(@"row_confirm_comment_dislike"),
                    kSCIRowNote: SCILocalized(@"row_confirm_comment_dislike_note"),
                    kSCIRowIcon: @"hand.thumbsdown.fill",
                    kSCIRowColor: [UIColor systemOrangeColor],
                },
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefConfirmDelete,
                    kSCIRowTitle: SCILocalized(@"row_confirm_delete"),
                    kSCIRowNote: SCILocalized(@"row_confirm_delete_note"),
                    kSCIRowIcon: @"trash.fill",
                    kSCIRowColor: [UIColor systemRedColor],
                },
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefUndoDelete,
                    kSCIRowTitle: SCILocalized(@"row_undo_delete"),
                    kSCIRowNote: SCILocalized(@"row_undo_delete_note"),
                    kSCIRowIcon: @"arrow.uturn.backward.circle.fill",
                    kSCIRowColor: [UIColor systemOrangeColor],
                },
            ],
        };
    });
}

@end
