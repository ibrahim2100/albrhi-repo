//
//  SCIFileName.h
//  Albrhi -- shared
//
//  One readable name for a saved file: "@account - the start of the caption - id.ext".
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

///
/// Builds a file name a person can recognise in Files or in a share sheet. Pure Foundation, no app class, so it is host-tested.
///
/// **What it guarantees** (each from a way a name can fail on iOS, not from taste):
///   * no path separators, colons, quotes, wildcards, control characters or bidi marks -- any of them breaks a path or flips an Arabic name;
///   * never starts with a dot (a hidden file) and never ends with a dot or a space;
///   * at most `maxBytes` of UTF-8 for the whole name *including* the extension (the filesystem limit is 255; the default leaves room for a "-2");
///   * cut on a whole character, never through an emoji or a letter with its marks;
///   * links are dropped from the caption and so is a trailing run of hashtags (they are noise in a file name);
///   * with nothing usable the name still ends with the id, and with no id at all it is `fallback` -- never empty.
///
FOUNDATION_EXPORT NSString *SCIFileNameBuild(NSString *_Nullable account,
                                             NSString *_Nullable caption,
                                             NSString *_Nullable identifier,
                                             NSString *_Nullable extension,
                                             NSString *fallback);

/// The same cleaning on its own, for a name that is not built from those parts (a video's title, say).
FOUNDATION_EXPORT NSString *SCIFileNameClean(NSString *_Nullable text, NSUInteger maxBytes);

NS_ASSUME_NONNULL_END
