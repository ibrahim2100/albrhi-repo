//
//  SCIYTAlbum.h
//  Albrhi for YouTube
//
//  A playlist saved as sounds is an album: tagged with its name and each track's place (see
//  SCIFMetadata), and shareable as one set -- the tracks in order, named "01 Title.m4a" -- so a
//  music library on a Mac (AirDrop, then Music) or any player that reads folders takes them as an
//  album rather than a pile of files.
//
//  **iOS does not let an app put files into the Music app's library**; there is no public way, and
//  a tweak inside YouTube's sandbox cannot reach the library's database. Sharing the tagged files is
//  what can be done honestly.
//
//  Pure: dictionaries in, names and order out, so a host test runs the code that ships.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIYTAlbum : NSObject

/// Tracks (`@{@"title": NSString, @"track": NSNumber (0 = none), ...}`) in album order: by track
/// number, those without one after, ties and the unnumbered by title (natural, case-insensitive).
+ (NSArray<NSDictionary *> *)orderedTracks:(NSArray<NSDictionary *> *)tracks;

/// "01 Title.m4a": the number padded to the width the album needs (at least two digits), the title
/// cleaned of the characters a file name cannot hold and cut to a length every file system takes.
/// A track without a number is just "Title.m4a".
+ (NSString *)fileNameForTrack:(NSInteger)track of:(NSInteger)total title:(NSString *)title extension:(NSString *)extension;

/// The folder name for an album: cleaned the same way, "Album" when it is empty.
+ (NSString *)folderNameForAlbum:(nullable NSString *)album;

@end

NS_ASSUME_NONNULL_END
