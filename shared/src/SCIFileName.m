//
//  SCIFileName.m
//  Albrhi -- shared
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCIFileName.h"

static const NSUInteger kSCIFileNameDefaultBytes = 120;

/// Cuts to at most `limit` UTF-8 bytes on a character boundary.
static NSString *SCIFileNameCut(NSString *text, NSUInteger limit) {
    if ([text lengthOfBytesUsingEncoding:NSUTF8StringEncoding] <= limit) return text;
    NSMutableString *out = [NSMutableString string];
    NSUInteger used = 0;
    NSUInteger index = 0;
    while (index < text.length) {
        NSRange range = [text rangeOfComposedCharacterSequenceAtIndex:index];
        NSString *piece = [text substringWithRange:range];
        NSUInteger bytes = [piece lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
        if (used + bytes > limit) break;
        [out appendString:piece];
        used += bytes;
        index = NSMaxRange(range);
    }
    return out;
}

NSString *SCIFileNameClean(NSString *text, NSUInteger maxBytes) {
    if (![text isKindOfClass:[NSString class]] || !text.length) return @"";
    NSMutableString *work = [text mutableCopy];

    // Links first (their slashes and colons are the worst offenders), then the characters a name may not hold.
    NSRegularExpression *links = [NSRegularExpression regularExpressionWithPattern:@"(https?://|www\\.)\\S+" options:NSRegularExpressionCaseInsensitive error:NULL];
    [links replaceMatchesInString:work options:0 range:NSMakeRange(0, work.length) withTemplate:@" "];

    NSMutableCharacterSet *bad = [NSMutableCharacterSet controlCharacterSet];
    [bad formUnionWithCharacterSet:[NSCharacterSet newlineCharacterSet]];
    [bad addCharactersInString:@"/\\:*?\"<>|"];
    // Bidi controls and zero-width characters: invisible, and they reorder an Arabic name or make two names look equal.
    [bad addCharactersInString:@"​‌‍‎‏‪‫‬‭‮⁦⁧⁨⁩﻿⁠"];
    NSString *joined = [[work componentsSeparatedByCharactersInSet:bad] componentsJoinedByString:@" "];

    // A trailing run of hashtags is metadata, not a title.
    NSRegularExpression *tags = [NSRegularExpression regularExpressionWithPattern:@"(\\s*[#＃]\\S+)+\\s*$" options:0 error:NULL];
    NSMutableString *tagless = [joined mutableCopy];
    [tags replaceMatchesInString:tagless options:0 range:NSMakeRange(0, tagless.length) withTemplate:@""];
    if (tagless.length) joined = tagless;   // a caption that is only hashtags keeps them rather than becoming empty

    // Collapse every run of whitespace to one space.
    NSMutableArray<NSString *> *words = [NSMutableArray array];
    for (NSString *word in [joined componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]) {
        if (word.length) [words addObject:word];
    }
    NSString *cleaned = [words componentsJoinedByString:@" "];

    cleaned = SCIFileNameCut(cleaned, maxBytes ?: kSCIFileNameDefaultBytes);

    // A cut can leave a dangling separator; a leading dot would hide the file, a trailing dot or space is refused by some filesystems.
    NSCharacterSet *edge = [NSCharacterSet characterSetWithCharactersInString:@". -_ "];
    while (cleaned.length && [edge characterIsMember:[cleaned characterAtIndex:0]]) cleaned = [cleaned substringFromIndex:1];
    while (cleaned.length && [edge characterIsMember:[cleaned characterAtIndex:cleaned.length - 1]]) cleaned = [cleaned substringToIndex:cleaned.length - 1];
    return cleaned;
}

NSString *SCIFileNameBuild(NSString *account, NSString *caption, NSString *identifier, NSString *extension, NSString *fallback) {
    NSString *ext = [extension isKindOfClass:[NSString class]] ? [[extension stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@". "]] lowercaseString] : @"";
    // An extension is ASCII letters and digits; anything else was never an extension.
    NSCharacterSet *notExt = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
    if ([ext rangeOfCharacterFromSet:notExt].location != NSNotFound || ext.length > 8) ext = @"";
    NSString *suffix = ext.length ? [@"." stringByAppendingString:ext] : @"";

    NSString *user = SCIFileNameClean(account, 40);
    if ([user hasPrefix:@"@"]) user = [user substringFromIndex:1];
    user = [user stringByReplacingOccurrencesOfString:@" " withString:@"_"];
    NSString *who = user.length ? [@"@" stringByAppendingString:user] : @"";

    // The id keeps the name unique; a very long one is cut from the front (the end of an id is the part that changes).
    NSString *ident = SCIFileNameClean(identifier, 64);
    ident = [ident stringByReplacingOccurrencesOfString:@" " withString:@""];
    if (ident.length > 16) ident = [ident substringFromIndex:ident.length - 16];

    // The caption gets whatever room the other parts leave in the 120-byte budget.
    NSUInteger fixed = [who lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + [ident lengthOfBytesUsingEncoding:NSUTF8StringEncoding]
                     + [suffix lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 6;   // two " - " separators
    NSUInteger room = kSCIFileNameDefaultBytes > fixed ? kSCIFileNameDefaultBytes - fixed : 0;
    NSString *title = room >= 8 ? SCIFileNameClean(caption, MIN(room, (NSUInteger)60)) : @"";

    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    if (who.length) [parts addObject:who];
    if (title.length) [parts addObject:title];
    if (ident.length) [parts addObject:ident];

    NSString *base = [parts componentsJoinedByString:@" - "];
    if (!base.length) base = SCIFileNameClean(fallback, 80);
    if (!base.length) base = @"Albrhi";
    return [base stringByAppendingString:suffix];
}
