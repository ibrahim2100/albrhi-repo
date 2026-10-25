#import "SCICopyText.h"

/// Words in an owner's class name that mark a text view as something other than a caption, a comment or a bio.
/// Matched as substrings, case-sensitively, because Instagram's own names are consistently capitalised
/// (`IGDirectTextMessageBubbleView`, `IGBannerViewV2`).
static NSArray<NSString *> *SCICopyExcluded(void) {
    static NSArray<NSString *> *words;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        words = @[
            @"IGDirect",          // message bubbles, the thread, the inbox: they have their own copy in the message menu
            @"Settings",          // account and privacy rows
            @"Banner", @"Toast",  // transient notices
            @"Alert", @"Dialog",
            @"Composer",          // the thing being typed into
            @"Survey", @"Nux", @"NUX", @"Upsell",
            @"TabBar", @"NavigationBar", @"Button",
            @"Typeahead", @"Keyboard",
            @"Registration", @"Login", @"Onboarding", @"Password", @"CodeConfirmation", @"CodeVerification",
        ];
    });
    return words;
}

BOOL SCICopyOffered(NSArray<NSString *> *classNames) {
    for (NSString *name in classNames) {
        for (NSString *word in SCICopyExcluded()) {
            if ([name containsString:word]) return NO;
        }
    }
    return YES;
}

NSString *SCICopyableText(NSString *raw) {
    if (![raw isKindOfClass:[NSString class]] || !raw.length) return nil;

    // U+FFFC stands for an inline image or view inside an attributed string; on a pasteboard it is a visible box.
    NSString *text = [raw stringByReplacingOccurrencesOfString:@"￼" withString:@""];
    text = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return text.length ? text : nil;
}
