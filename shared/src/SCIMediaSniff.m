//
//  SCIMediaSniff.m
//  Albrhi
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCIMediaSniff.h"

static BOOL SCIHas(const uint8_t *b, NSUInteger n, NSUInteger at, const char *tag, NSUInteger len) {
    return at + len <= n && memcmp(b + at, tag, len) == 0;
}

/// Whether the leading bytes read as text that starts a document: optional BOM and whitespace, then `<`
/// (HTML or XML), `{` or `[` (JSON), or a few words error pages begin with. A binary file has a control
/// byte or a high byte early; a document does not.
static BOOL SCILooksLikeDocument(const uint8_t *b, NSUInteger n) {
    NSUInteger i = 0;
    if (n >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF) i = 3;       // UTF-8 BOM
    while (i < n && (b[i] == ' ' || b[i] == '\t' || b[i] == '\r' || b[i] == '\n')) i++;
    if (i >= n) return NO;
    if (b[i] != '<' && b[i] != '{' && b[i] != '[' && !(b[i] >= 'A' && b[i] <= 'z')) return NO;

    // Plain text: the first 32 bytes are printable ASCII or whitespace. (Binary media almost always
    // has a zero or a control byte in its first handful; an `ftyp` box starts with four size bytes.)
    NSUInteger limit = MIN(n, i + 32);
    for (NSUInteger k = i; k < limit; k++) {
        uint8_t c = b[k];
        if (c == '\t' || c == '\n' || c == '\r') continue;
        if (c < 0x20 || c > 0x7E) return NO;
    }
    if (b[i] == '<' || b[i] == '{' || b[i] == '[') return YES;

    // A bare word start: only the ones an error body begins with, so a subtitle file starting "WEBVTT"
    // or "1" (SRT) is not caught.
    static const char *const words[] = { "Access Denied", "Forbidden", "Not Found", "Bad Request", "Error", "error", "Unauthorized", "Too Many Requests", "Service Unavailable", "Bad Gateway" };
    for (NSUInteger w = 0; w < sizeof(words) / sizeof(words[0]); w++) {
        size_t len = strlen(words[w]);
        if (i + len <= n && memcmp(b + i, words[w], len) == 0) return YES;
    }
    return NO;
}

SCIMediaKind SCIMediaSniff(NSData *head) {
    const uint8_t *b = head.bytes;
    NSUInteger n = head.length;
    if (n == 0) return SCIMediaKindEmpty;

    // ISO base media: the box type sits at offset 4.
    if (n >= 8) {
        if (SCIHas(b, n, 4, "ftyp", 4)) return SCIMediaKindMP4;
        if (SCIHas(b, n, 4, "styp", 4) || SCIHas(b, n, 4, "moof", 4) || SCIHas(b, n, 4, "sidx", 4)) return SCIMediaKindFragmentedMP4;
        if (SCIHas(b, n, 4, "moov", 4) || SCIHas(b, n, 4, "mdat", 4) || SCIHas(b, n, 4, "free", 4) || SCIHas(b, n, 4, "wide", 4)) return SCIMediaKindMP4;
    }
    if (n >= 4 && b[0] == 0x1A && b[1] == 0x45 && b[2] == 0xDF && b[3] == 0xA3) return SCIMediaKindWebM;
    if (n >= 3 && SCIHas(b, n, 0, "ID3", 3)) return SCIMediaKindMP3;
    if (n >= 2 && b[0] == 0xFF && (b[1] & 0xF6) == 0xF0) return SCIMediaKindAAC;     // ADTS: layer bits 00
    if (n >= 2 && b[0] == 0xFF && (b[1] & 0xE0) == 0xE0) return SCIMediaKindMP3;     // MPEG audio frame sync

    // Transport stream: 0x47 at 0, and again 188 bytes on when there is room to see it.
    if (b[0] == 0x47 && (n < 189 || b[188] == 0x47)) return SCIMediaKindMPEGTS;

    if (n >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return SCIMediaKindImage;
    if (n >= 8 && SCIHas(b, n, 0, "\x89PNG", 4)) return SCIMediaKindImage;
    if (n >= 4 && (SCIHas(b, n, 0, "GIF8", 4))) return SCIMediaKindImage;
    if (n >= 12 && SCIHas(b, n, 0, "RIFF", 4) && SCIHas(b, n, 8, "WEBP", 4)) return SCIMediaKindImage;

    if (SCILooksLikeDocument(b, n)) return SCIMediaKindDocument;
    return SCIMediaKindUnknown;
}

BOOL SCIMediaKindIsRefused(SCIMediaKind kind) {
    return kind == SCIMediaKindDocument || kind == SCIMediaKindEmpty;
}

NSString *SCIMediaKindDescription(SCIMediaKind kind) {
    switch (kind) {
        case SCIMediaKindDocument: return @"an HTML or text page";
        case SCIMediaKindEmpty: return @"an empty file";
        case SCIMediaKindMP4: return @"an MP4";
        case SCIMediaKindFragmentedMP4: return @"a fragmented MP4";
        case SCIMediaKindWebM: return @"a WebM";
        case SCIMediaKindMP3: return @"MP3 audio";
        case SCIMediaKindAAC: return @"AAC audio";
        case SCIMediaKindMPEGTS: return @"an MPEG transport stream";
        case SCIMediaKindImage: return @"a picture";
        default: return @"a file of unknown kind";
    }
}

SCIMediaKind SCIMediaSniffFile(NSURL *file) {
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingFromURL:file error:nil];
    if (!handle) return SCIMediaKindUnknown;
    NSData *head = nil;
    @try { head = [handle readDataOfLength:512]; } @catch (__unused NSException *exception) { head = nil; }
    [handle closeFile];
    return head ? SCIMediaSniff(head) : SCIMediaKindUnknown;
}

BOOL SCIMediaFileLooksFinished(NSURL *file, SCIMediaKind *kind) {
    SCIMediaKind seen = SCIMediaSniffFile(file);
    if (kind) *kind = seen;
    return !SCIMediaKindIsRefused(seen);
}
