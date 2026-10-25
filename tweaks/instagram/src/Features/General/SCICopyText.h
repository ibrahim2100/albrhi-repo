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


// MARK: - A ledger of what the long-press did, for the diagnostics page

/// A long-press arrived at the window recognizer and the setting was on.
void SCICopyNoteLongPress(void);

/// A text view was found under the finger, and what it put on the pasteboard.
void SCICopyNoteCopied(NSString *viewClass, NSUInteger length);

/// Nothing was copied, and why: no text view under the finger (with the chain of classes that *was* there, which is what a
/// comment drawn by something other than `IGCoreTextView` looks like), a view the exclusion list keeps out, or no text.
void SCICopyNoteMiss(NSString *reason, NSString * _Nullable chain);

/// Where the window recognizer was attached (class names), once each.
void SCICopyNoteAttached(NSString *windowClass);

/// The ledger as report lines (counts, then the last copy and the last few misses, newest first).
NSArray<NSString *> *SCICopyReportLines(void);

NS_ASSUME_NONNULL_END
