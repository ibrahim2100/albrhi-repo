//
//  SCIMediaSniff.h
//  Albrhi
//
//  What a downloaded file *is*, read from its first bytes. A CDN that answers `200 OK` with an HTML
//  error page, a JSON refusal or a login wall is indistinguishable from a real download until the
//  bytes are looked at: the file lands on disk with the right name and the right extension and cannot
//  be played, and the person finds out later, in Photos or a player, with no reason given. (The idea
//  and the rule -- refuse a *document*, never demand a recognised container -- are OmniGet's
//  `media_signature.rs`, GPL-3.0; this is a rewrite.)
//
//  Conservative on purpose: only a file that opens like a document, or is empty, is refused. Subtitles,
//  pictures and anything this does not recognise pass, because a check that must recognise every good
//  file rejects good files.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SCIMediaKind) {
    SCIMediaKindUnknown = 0,    ///< binary this does not recognise (allowed)
    SCIMediaKindMP4,            ///< ISO base media with `ftyp`
    SCIMediaKindFragmentedMP4,  ///< `styp` / `moof` (a DASH or HLS fragment)
    SCIMediaKindWebM,           ///< Matroska / WebM
    SCIMediaKindMP3,            ///< `ID3` tag or a bare frame sync
    SCIMediaKindAAC,            ///< ADTS
    SCIMediaKindMPEGTS,         ///< transport stream packets (`0x47` every 188 bytes)
    SCIMediaKindImage,          ///< JPEG, PNG, GIF, WebP, HEIC
    SCIMediaKindDocument,       ///< HTML, XML, JSON or other plain text: an error page, not media
    SCIMediaKindEmpty,          ///< no bytes at all
};

/// The kind of what `head` begins like. `head` is the first bytes of a file (64 are enough, 512 find a
/// transport stream's second packet).
SCIMediaKind SCIMediaSniff(NSData *head);

/// Whether this kind is something a download must never end as.
BOOL SCIMediaKindIsRefused(SCIMediaKind kind);

/// A short English word for a kind, for the log: "an HTML or text page", "an empty file".
NSString *SCIMediaKindDescription(SCIMediaKind kind);

/// Reads the first bytes of a file and sniffs them. Unreadable counts as `Unknown`, not as a refusal.
SCIMediaKind SCIMediaSniffFile(NSURL *file);

/// YES when the file is acceptable as a finished download (anything but a document or nothing).
/// `kind` receives what was seen.
BOOL SCIMediaFileLooksFinished(NSURL *file, SCIMediaKind * _Nullable kind);

NS_ASSUME_NONNULL_END
