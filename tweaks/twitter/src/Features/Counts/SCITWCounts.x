#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "SCITWCounts.h"
#import "Prefs.h"
#import "SCILog.h"
#import "Localization/SCILocalize.h"
#import "shared/src/SCIKVC.h"

// Declared because the hook sends `self` messages; a forward declaration cannot be sent any.
@interface T1PostInteractionsViewController : UIViewController
@end

static BOOL sciInteractionsAttached = NO;
static BOOL sciFollowCountAttached = NO;
static BOOL sciPostCountAttached = NO;
static NSUInteger sciTitlesSet = 0, sciLookupsFailed = 0;
static NSUInteger sciFollowTextsChanged = 0, sciPostTextsChanged = 0;

static char SCITWInteractionAccountKey;
static char SCITWInteractionStatusIDKey;

/// "12.4K" as X writes it, for the one place the count has to be abbreviated by us: the
/// post interactions title, where X offers nothing to ask. Locale digits come from the
/// formatter, so an Arabic phone reads Arabic-Indic numerals rather than a mixture.
static NSString *SCITWAbbreviated(long long number) {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    formatter.maximumFractionDigits = 1;

    if (number < 1000) return [formatter stringFromNumber:@(number)] ?: @"0";
    if (number < 1000000) return [[formatter stringFromNumber:@(number / 1000.0)] stringByAppendingString:@"K"];
    if (number < 1000000000) return [[formatter stringFromNumber:@(number / 1000000.0)] stringByAppendingString:@"M"];
    return [[formatter stringFromNumber:@(number / 1000000000.0)] stringByAppendingString:@"B"];
}

static NSString *SCITWFull(long long number) {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    return [formatter stringFromNumber:@(number)] ?: [NSString stringWithFormat:@"%lld", number];
}

static void SCITWSetInteractionTitle(UIViewController *controller, id status) {
    if (!status || ![controller isViewLoaded]) return;

    SEL quoteSelector = NSSelectorFromString(@"quoteCount");
    SEL repostSelector = NSSelectorFromString(@"retweetCount");
    if (![status respondsToSelector:quoteSelector] || ![status respondsToSelector:repostSelector]) return;

    long long quotes = ((long long (*)(id, SEL))objc_msgSend)(status, quoteSelector);
    long long reposts = ((long long (*)(id, SEL))objc_msgSend)(status, repostSelector);

    BOOL whole = [[NSUserDefaults standardUserDefaults] boolForKey:SCIPrefUnroundedQuotes];
    NSString *quoteText = whole ? SCITWFull(quotes) : SCITWAbbreviated(quotes);
    NSString *repostText = whole ? SCITWFull(reposts) : SCITWAbbreviated(reposts);

    controller.navigationItem.title =
        [NSString stringWithFormat:SCILocalized(@"counts_quotes_reposts"), quoteText, repostText];
    sciTitlesSet++;
}


///
/// The post interactions screen's title.
///
/// The account and the status id arrive through the factory the screen is built by, and the
/// screen has no accessor for either -- so they are stored on the instance at construction
/// and used at `-viewDidLoad`, where the status is looked up and the title written.
///
%group PostInteractions

%hook T1PostInteractionsViewController

+ (id)viewControllerWithAccount:(id)account statusID:(long long)statusID
                   statusUserID:(long long)statusUserID initialTab:(long long)initialTab {
    id controller = %orig;
    if (controller) {
        objc_setAssociatedObject(controller, &SCITWInteractionAccountKey, account,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(controller, &SCITWInteractionStatusIDKey, @(statusID),
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return controller;
}

- (void)viewDidLoad {
    %orig;
    if (![[NSUserDefaults standardUserDefaults] boolForKey:SCIPrefShowQuotes]) return;

    id account = objc_getAssociatedObject(self, &SCITWInteractionAccountKey);
    NSNumber *statusID = objc_getAssociatedObject(self, &SCITWInteractionStatusIDKey);
    if (!account || !statusID) return;

    id model = SCISafeValueForKey(account, @"model");
    SEL lookup = NSSelectorFromString(@"lookUpStatusForID:completionBlock:");
    if (!model || ![model respondsToSelector:lookup]) {
        sciLookupsFailed++;
        return;
    }

    __weak T1PostInteractionsViewController *weakSelf = self;
    void (^completion)(id) = ^(id status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            SCITWSetInteractionTitle(weakSelf, status);
        });
    };
    ((void (*)(id, SEL, long long, id))objc_msgSend)(model, lookup, statusID.longLongValue, completion);
}

%end

%end


/// Where X's abbreviated form of `count` sits inside a string X built, and the whole number to
/// put there instead. Done as a replacement of the abbreviation X itself used
/// (`-tfs_twitterAbbreviated`) rather than a rebuild of the sentence, so the label's wording,
/// direction and styling stay whatever X made them. NSNotFound where there is nothing to
/// change -- already whole, not abbreviated, or the abbreviation is not in the text.
static NSRange SCITWAbbreviationRange(NSString *text, NSNumber *count, NSString **fullOut) {
    SEL abbreviate = NSSelectorFromString(@"tfs_twitterAbbreviated");
    if (![count respondsToSelector:abbreviate]) return NSMakeRange(NSNotFound, 0);

    NSString *abbreviated = ((id (*)(id, SEL))objc_msgSend)(count, abbreviate);
    NSString *full = SCITWFull(count.longLongValue);

    if (![abbreviated isKindOfClass:[NSString class]] || !abbreviated.length || !full.length ||
        [abbreviated isEqualToString:full]) {
        return NSMakeRange(NSNotFound, 0);
    }

    if (fullOut) *fullOut = full;
    return [text rangeOfString:abbreviated];
}

%group FollowCount

%hook T1ProfileFriendsFollowingViewModel

- (id)_t1_followCountTextWithLabel:(id)label singularLabel:(id)singularLabel
                             count:(NSNumber *)count highlighted:(BOOL)highlighted {
    id original = %orig;
    if (![[NSUserDefaults standardUserDefaults] boolForKey:SCIPrefUnroundedCounts]) return original;
    if (![count isKindOfClass:[NSNumber class]] || ![original isKindOfClass:[NSAttributedString class]]) {
        return original;
    }

    NSString *full = nil;
    NSRange range = SCITWAbbreviationRange([original string], count, &full);
    if (range.location == NSNotFound) return original;

    NSMutableAttributedString *expanded = [original mutableCopy];
    [expanded replaceCharactersInRange:range withString:full];
    sciFollowTextsChanged++;
    return [expanded copy];
}

%end

%end

%group PostCount

%hook T1ProfileDisplayNormalMainContentProvider

- (id)_tweetsSubtitle {
    id original = %orig;
    if (![[NSUserDefaults standardUserDefaults] boolForKey:SCIPrefUnroundedCounts]) return original;
    if (![original isKindOfClass:[NSString class]]) return original;

    id viewModel = SCISafeValueForKey(self, @"viewModel");
    NSNumber *count = SCISafeValueForKey(viewModel, @"tweetCount");
    if (![count isKindOfClass:[NSNumber class]]) return original;

    NSString *full = nil;
    NSRange range = SCITWAbbreviationRange(original, count, &full);
    if (range.location == NSNotFound) return original;

    sciPostTextsChanged++;
    return [original stringByReplacingCharactersInRange:range withString:full];
}

%end

%end


static BOOL SCITWAnswers(NSString *className, NSString *selectorName, const char *encoding, BOOL classMethod) {
    Class cls = NSClassFromString(className);
    if (!cls) return NO;

    Method method = classMethod ? class_getClassMethod(cls, NSSelectorFromString(selectorName))
                                : class_getInstanceMethod(cls, NSSelectorFromString(selectorName));
    if (!method) return NO;

    const char *actual = method_getTypeEncoding(method);
    return actual && strcmp(actual, encoding) == 0;
}

NSString *SCITWCountsReport(void) {
    return [NSString stringWithFormat:
        @"counts: post interactions %@ (%lu title(s), %lu lookup(s) failed) · follow counts %@ (%lu changed) · post count %@ (%lu changed)",
        sciInteractionsAttached ? @"attached" : @"not attached",
        (unsigned long)sciTitlesSet, (unsigned long)sciLookupsFailed,
        sciFollowCountAttached ? @"attached" : @"not attached", (unsigned long)sciFollowTextsChanged,
        sciPostCountAttached ? @"attached" : @"not attached", (unsigned long)sciPostTextsChanged];
}

void SCITWInstallCounts(void) {
    if (SCITWAnswers(@"T1PostInteractionsViewController",
                     @"viewControllerWithAccount:statusID:statusUserID:initialTab:",
                     "@48@0:8@16q24q32q40", YES) &&
        SCITWAnswers(@"T1PostInteractionsViewController", @"viewDidLoad", "v16@0:8", NO)) {
        %init(PostInteractions);
        sciInteractionsAttached = YES;
    }

    if (SCITWAnswers(@"T1ProfileFriendsFollowingViewModel",
                     @"_t1_followCountTextWithLabel:singularLabel:count:highlighted:",
                     "@44@0:8@16@24@32B40", NO)) {
        %init(FollowCount);
        sciFollowCountAttached = YES;
    }

    if (SCITWAnswers(@"T1ProfileDisplayNormalMainContentProvider", @"_tweetsSubtitle", "@16@0:8", NO)) {
        %init(PostCount);
        sciPostCountAttached = YES;
    }

    SCILogV(@"counts: %@", SCITWCountsReport());
}
