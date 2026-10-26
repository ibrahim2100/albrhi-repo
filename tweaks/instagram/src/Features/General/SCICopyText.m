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

NSString *SCICopyDropLeadingName(NSString *text, NSUInteger nameLength) {
    if (![text isKindOfClass:[NSString class]] || nameLength == 0 || nameLength >= text.length) return text;

    NSCharacterSet *space = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSString *name = [text substringToIndex:nameLength];
    NSUInteger end = name.length;
    while (end > 0 && [space characterIsMember:[name characterAtIndex:end - 1]]) end--;
    if (end == 0) return text;
    NSString *bare = [name substringToIndex:end];
    if ([bare rangeOfCharacterFromSet:space].location != NSNotFound) return text;

    // The run either carried its separator, or the next character is one.
    BOOL separated = end < name.length || [space characterIsMember:[text characterAtIndex:nameLength]];
    if (!separated) return text;

    NSString *rest = [text substringFromIndex:nameLength];
    return SCICopyableText(rest) ? rest : text;
}

// MARK: - Ledger

static NSUInteger sciPresses = 0, sciCopies = 0, sciMisses = 0;
static NSMutableArray<NSString *> *sciWindows = nil;
static NSString *sciLastCopy = nil;
static NSUInteger sciBinds = 0, sciBindsWithText = 0;
static NSString *sciBindModel = nil;
static NSMutableArray<NSString *> *sciRecentMisses = nil;

void SCICopyNoteLongPress(void) { sciPresses++; }

void SCICopyNoteCopied(NSString *viewClass, NSUInteger length, NSString *detail) {
    sciCopies++;
    sciLastCopy = [NSString stringWithFormat:@"%@, %lu characters%@", viewClass, (unsigned long)length,
                   detail.length ? [@" · " stringByAppendingString:detail] : @""];
}

void SCICopyNoteMiss(NSString *reason, NSString *chain) {
    sciMisses++;
    if (!sciRecentMisses) sciRecentMisses = [NSMutableArray array];
    [sciRecentMisses insertObject:chain.length ? [NSString stringWithFormat:@"%@ — %@", reason, chain] : reason atIndex:0];
    while (sciRecentMisses.count > 4) [sciRecentMisses removeLastObject];
}

void SCICopyNoteBind(NSString *modelClass, BOOL hadText) {
    sciBinds++;
    if (hadText) sciBindsWithText++;
    sciBindModel = modelClass;
}

void SCICopyNoteAttached(NSString *windowClass) {
    if (!sciWindows) sciWindows = [NSMutableArray array];
    [sciWindows addObject:windowClass];
}

NSArray<NSString *> *SCICopyReportLines(void) {
    NSMutableArray *lines = [NSMutableArray array];
    [lines addObject:[NSString stringWithFormat:@"windows with the recognizer: %@",
                      sciWindows.count ? [sciWindows componentsJoinedByString:@", "] : @"none yet"]];
    [lines addObject:[NSString stringWithFormat:@"long-presses seen: %lu · copied: %lu · nothing to copy: %lu",
                      (unsigned long)sciPresses, (unsigned long)sciCopies, (unsigned long)sciMisses]];
    [lines addObject:[NSString stringWithFormat:@"comment cells bound: %lu (with text: %lu) · model class: %@",
                      (unsigned long)sciBinds, (unsigned long)sciBindsWithText, sciBindModel ?: @"none seen"]];
    if (sciLastCopy) [lines addObject:[@"last copy: " stringByAppendingString:sciLastCopy]];
    for (NSString *miss in sciRecentMisses) [lines addObject:[@"miss: " stringByAppendingString:miss]];
    return lines;
}
