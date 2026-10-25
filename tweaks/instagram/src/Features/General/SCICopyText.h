//
//  SCICopyText.h
//  Albrhi for Instagram
//
//  The decisions behind "long-press a caption or a comment to copy it", kept apart from the hook so they can be run on
//  the build machine (`tests/host`).
//
//  Pure Foundation, no UIKit.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Whether a text view whose chain of owners is `classNames` (nearest first: the view's superview, its superview, … up to
/// and including the view controller) should offer copy.
///
/// `IGCoreTextView` draws far more than captions and comments (a hundred and ninety-eight classes own one in Instagram
/// 450.1.0): direct-message bubbles, settings rows, banners, toasts, sign-in forms. A long-press on those has its own
/// meaning, so any owner whose name carries one of the listed words keeps the view out. Everything else (feed captions,
/// Reels captions, comments, bios, post detail) is in.
BOOL SCICopyOffered(NSArray<NSString *> *classNames);

/// The text to put on the pasteboard, or nil when there is nothing worth copying: leading and trailing whitespace and
/// newlines trimmed, **the inside untouched** (line breaks, mentions, hashtags and emoji are the caption as written), and
/// the object-replacement character Instagram uses for inline attachments removed.
NSString * _Nullable SCICopyableText(NSString * _Nullable raw);

NS_ASSUME_NONNULL_END
