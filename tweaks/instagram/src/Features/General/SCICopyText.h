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

/// `text` without a leading account name, given how long the name's styled run is.
///
/// A caption in the feed is one string, `<account> <caption>`, with the account in a heavier font. `nameLength` is the length
/// of that first run as the caller measured it (0 when the first run is not heavier than the next, which means no name).
/// Only a plausible name is dropped: no whitespace inside it, it ends at whitespace (or the run took the space with it),
/// and something is left after it. Anything else returns `text` unchanged -- copying the account too is a nuisance, losing
/// part of a caption is a bug.
NSString *SCICopyDropLeadingName(NSString *text, NSUInteger nameLength);


// MARK: - A ledger of what the long-press did, for the diagnostics page

/// A long-press arrived at the window recognizer and the setting was on.
void SCICopyNoteLongPress(void);

/// A text view was found under the finger, and what it put on the pasteboard.
/// `detail` says how the text was read (what was stripped and the first styled runs), so a report can show why a name stayed.
void SCICopyNoteCopied(NSString *viewClass, NSUInteger length, NSString * _Nullable detail);

/// Nothing was copied, and why: no text view under the finger (with the chain of classes that *was* there, which is what a
/// comment drawn by something other than `IGCoreTextView` looks like), a view the exclusion list keeps out, or no text.
void SCICopyNoteMiss(NSString *reason, NSString * _Nullable chain);

/// Which way a long press was noticed: the gesture recognizer (`NO`) or the touch timer (`YES`). Counted separately, so a
/// report says whether the recognizer ever fires inside a screen where the timer does.
void SCICopyNoteSource(BOOL fromTouchTimer);

/// What became of a touch the timer was following: 0 began, 1 lifted before the half second, 2 moved away, 3 cancelled by the system.
void SCICopyNoteTouch(int kind);

/// A comment cell was bound to its model: the model's class, and whether its text could be read. Counted so a report says
/// whether the comment path ever had anything to work with.
void SCICopyNoteBind(NSString *modelClass, BOOL hadText);

/// Where the window recognizer was attached (class names), once each.
void SCICopyNoteAttached(NSString *windowClass);

/// The ledger as report lines (counts, then the last copy and the last few misses, newest first).
NSArray<NSString *> *SCICopyReportLines(void);

NS_ASSUME_NONNULL_END
