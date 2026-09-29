//
//  SCILocalize.m
//  Albrhi for Spotify
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCILocalize.h"

NSString *SCIVersionString = @"v0.2.5";  // AlbrhiSpotify

///
/// Short, because almost everything a person reads about this tweak is drawn by Albrhi Panel and
/// lives in the panel's own tables. What is here is what the tweak itself might have to say.
///
static NSDictionary *_enTable = nil;
static NSDictionary *_arTable = nil;

static void SCIBuildTables(void) {
    _enTable = @{
    };

    _arTable = @{
    };
}

NSString *SCILocalized(NSString *key) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{ SCIBuildTables(); });

    BOOL arabic = [[NSLocale preferredLanguages].firstObject hasPrefix:@"ar"];
    NSString *value = arabic ? _arTable[key] : _enTable[key];
    return value ?: (_enTable[key] ?: key);
}
