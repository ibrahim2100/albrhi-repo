//
//  SCIYTFailure.h
//  Albrhi for YouTube
//
//  Why a download failed, said in one sentence that also says what to do. A person does not read
//  "LOGIN_REQUIRED: Sign in to confirm you're not a bot" or "-1009"; they read "failed" and give up
//  or file a report. Each cause carries one action, written into the sentence ("... then tap to try
//  again"), because a cause with no action is only a better-written error. (The shape -- named root
//  causes, one remedy each, most specific first -- is OmniGet's `root_cause.rs`, GPL-3.0.)
//
//  Pure: text and numbers in, a cause out, so a host test runs the code that ships.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SCIYTFailureCause) {
    SCIYTFailureUnknown = 0,
    SCIYTFailureSignIn,        ///< YouTube asks for a sign-in or a "not a bot" check
    SCIYTFailureAge,           ///< age-restricted
    SCIYTFailureUnavailable,   ///< private, removed, or members-only
    SCIYTFailureRegion,        ///< not available in this country
    SCIYTFailureDiskFull,      ///< no room on the phone
    SCIYTFailureOffline,       ///< no connection, or it dropped
    SCIYTFailureExpired,       ///< the address timed out (403 / 410)
    SCIYTFailureThrottled,     ///< too many requests (429 / 503)
    SCIYTFailureBadFile,       ///< the server sent a page, not a video
    SCIYTFailureNoFormats,     ///< YouTube offered nothing this route can save
    SCIYTFailureLive,          ///< a live stream or a premiere not yet started
};

@interface SCIYTFailure : NSObject

/// What `text` (a playability reason, an NSError description, or a note of ours) and an HTTP status
/// (0 when none) say. The most specific cause wins; an unrecognised one is `Unknown`.
+ (SCIYTFailureCause)causeForText:(nullable NSString *)text status:(NSInteger)status;

/// The cause of an NSError (domain and code first, its text second).
+ (SCIYTFailureCause)causeForError:(nullable NSError *)error;

/// The localisation key of the sentence for a cause, and the sentence.
+ (NSString *)keyForCause:(SCIYTFailureCause)cause;
+ (NSString *)messageForCause:(SCIYTFailureCause)cause;

/// `message` when it already names a cause, else the sentence for whatever `reason` says; `fallback`
/// when nothing is recognised.
+ (NSString *)sentenceForReason:(nullable NSString *)reason fallback:(NSString *)fallback;

@end

NS_ASSUME_NONNULL_END
