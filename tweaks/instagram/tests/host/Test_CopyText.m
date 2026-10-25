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
    }
    printf(fails ? "\n%d failed\n" : "\nall passed\n", fails);
    return fails ? 1 : 0;
}
