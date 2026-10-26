// Which text views offer copy, and what they put on the pasteboard.
#import <Foundation/Foundation.h>
#import "Features/General/SCICopyText.h"

static int fails = 0;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); fails++; } else printf("ok   %s\n", #c); } while (0)

int main(void) {
    @autoreleasepool {
        // Where it is offered: captions, comments, bios, post detail, Reels.
        CHECK(SCICopyOffered(@[@"IGFeedItemTextCell", @"UICollectionView", @"IGFeedViewController"]));
        CHECK(SCICopyOffered(@[@"_TtC17IGCommentCellView24IGCommentCellContentView", @"_TtC17IGCommentCellView17IGCommentCellView", @"IGCommentGroupTextCell"]));
        CHECK(SCICopyOffered(@[@"IGFeedItemHeaderCoreTextView", @"IGProfileViewController"]));
        CHECK(SCICopyOffered(@[]));   // nothing known about the owners: allowed, the view is a core-text view

        // Where it is not: a direct-message bubble, settings, a banner, a form.
        CHECK(!SCICopyOffered(@[@"IGDirectTextMessageBubbleView", @"IGDirectMessageCell"]));
        CHECK(!SCICopyOffered(@[@"IGDSAlertDialogView"]));
        CHECK(!SCICopyOffered(@[@"IGBannerViewV2", @"IGViewController"]));
        CHECK(!SCICopyOffered(@[@"IGAccountDetailedPrivacySwitchRowView", @"IGSettingsViewController"]));
        CHECK(!SCICopyOffered(@[@"IGChangePasswordView_NEW"]));
        CHECK(!SCICopyOffered(@[@"IGSocialUFIView.IGSocialUFIButtonView", @"IGFeedItemUFICell"]));   // the action bar under a post
        CHECK(!SCICopyOffered(@[@"IGUFIInteractionCountsView"]));
        // One excluded owner anywhere up the chain is enough.
        CHECK(!SCICopyOffered(@[@"IGFeedItemTextCell", @"UIView", @"IGDirectInboxViewController"]));

        // What is copied.
        CHECK([SCICopyableText(@"  Hello world \n") isEqualToString:@"Hello world"]);
        CHECK([SCICopyableText(@"line one\nline two") isEqualToString:@"line one\nline two"]);
        CHECK([SCICopyableText(@"#tag @user ✨") isEqualToString:@"#tag @user ✨"]);
        CHECK([SCICopyableText(@"a￼b") isEqualToString:@"ab"]);
        CHECK([SCICopyableText(@"مرحبا بالعالم") isEqualToString:@"مرحبا بالعالم"]);

        // What is not.
        CHECK(SCICopyableText(nil) == nil);
        CHECK(SCICopyableText(@"") == nil);
        CHECK(SCICopyableText(@"   \n\t ") == nil);
        CHECK(SCICopyableText(@"￼") == nil);
        CHECK(SCICopyableText((NSString *)[NSNull null]) == nil);

        // A leading account name is dropped when it is plausibly one, and only then.
        CHECK([SCICopyDropLeadingName(@"ibrahim hello world", 7) isEqualToString:@" hello world"]);
        CHECK([SCICopyDropLeadingName(@"ibrahim hello\nworld", 8) isEqualToString:@"hello\nworld"]);   // the run carried its space
        CHECK([SCICopyDropLeadingName(@"two words here", 9) isEqualToString:@"two words here"]);        // a name has no space inside
        CHECK([SCICopyDropLeadingName(@"ibrahimhello", 7) isEqualToString:@"ibrahimhello"]);            // not followed by a separator
        CHECK([SCICopyDropLeadingName(@"ibrahim", 7) isEqualToString:@"ibrahim"]);                       // nothing would be left
        CHECK([SCICopyDropLeadingName(@"ibrahim   ", 7) isEqualToString:@"ibrahim   "]);
        CHECK([SCICopyDropLeadingName(@"hello world", 0) isEqualToString:@"hello world"]);
        CHECK(SCICopyDropLeadingName(@"", 3).length == 0);
        CHECK(SCICopyDropLeadingName((NSString *)[NSNull null], 3) != nil);
        CHECK([SCICopyableText(SCICopyDropLeadingName(@"sara￼ nice photo", 5)) isEqualToString:@"nice photo"]);   // a badge after the name
    }
    printf(fails ? "\n%d failed\n" : "\nall passed\n", fails);
    return fails ? 1 : 0;
}
