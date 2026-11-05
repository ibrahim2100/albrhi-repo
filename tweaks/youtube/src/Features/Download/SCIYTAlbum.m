//
//  SCIYTAlbum.m
//  Albrhi for YouTube
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCIYTAlbum.h"

static NSString *SCIClean(NSString *text, NSUInteger limit) {
    NSMutableCharacterSet *illegal = [NSMutableCharacterSet characterSetWithCharactersInString:@"/\\?%*|\"<>:"];
    [illegal formUnionWithCharacterSet:[NSCharacterSet controlCharacterSet]];
    [illegal formUnionWithCharacterSet:[NSCharacterSet newlineCharacterSet]];
    NSString *clean = [[(text ?: @"") componentsSeparatedByCharactersInSet:illegal] componentsJoinedByString:@" "];
    // Runs of spaces the cleaning left, and a leading dot that would hide the file.
    while ([clean containsString:@"  "]) clean = [clean stringByReplacingOccurrencesOfString:@"  " withString:@" "];
    clean = [clean stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    while ([clean hasPrefix:@"."]) clean = [clean substringFromIndex:1];
    if (clean.length > limit) clean = [[clean substringToIndex:limit] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    return clean;
}

@implementation SCIYTAlbum

+ (NSArray<NSDictionary *> *)orderedTracks:(NSArray<NSDictionary *> *)tracks {
    return [tracks sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        NSInteger na = [a[@"track"] integerValue], nb = [b[@"track"] integerValue];
        BOOL ha = na > 0, hb = nb > 0;
        if (ha && hb && na != nb) return na < nb ? NSOrderedAscending : NSOrderedDescending;
        if (ha != hb) return ha ? NSOrderedAscending : NSOrderedDescending;
        return [a[@"title"] ?: @"" compare:b[@"title"] ?: @"" options:NSCaseInsensitiveSearch | NSNumericSearch];
    }];
}

+ (NSString *)fileNameForTrack:(NSInteger)track of:(NSInteger)total title:(NSString *)title extension:(NSString *)extension {
    NSString *name = SCIClean(title, 90);
    if (!name.length) name = @"Track";
    NSString *tail = extension.length ? [@"." stringByAppendingString:extension] : @"";
    if (track <= 0) return [name stringByAppendingString:tail];
    NSInteger biggest = MAX(total, track);
    NSString *digits = [NSString stringWithFormat:@"%ld", (long)biggest];
    NSInteger width = MAX(2, (NSInteger)digits.length);
    return [NSString stringWithFormat:@"%0*ld %@%@", (int)width, (long)track, name, tail];
}

+ (NSString *)folderNameForAlbum:(NSString *)album {
    NSString *name = SCIClean(album, 80);
    return name.length ? name : @"Album";
}

@end
