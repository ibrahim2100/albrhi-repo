//
//  SCIYTPoProbe.h
//  Albrhi for YouTube
//
//  What YouTube's own proof-of-origin machinery is doing, written down.
//
//  **Why this exists.** On 21.33.6 a regular video plays a second or two and stops with
//  "Something went wrong" -- stock app, no tweak, signed in or out, Shorts fine. Searching for
//  the mechanism found it described for other clients: YouTube's SABR stream carries a
//  `STREAM_PROTECTION_STATUS` that goes from `ATTESTATION_PENDING` to `ATTESTATION_REQUIRED`,
//  at which point the server stops sending media and the player raises a generic error
//  (shy1132/VacuumTube#189; yt-dlp's PO Token Guide). The iOS app mints that token itself, with
//  Google's native attestation (`IGDManager`, the "iosguard" JavaScript VM, and
//  `YTProofOfOriginTokenManager`) -- all of it in the 21.34.3 binary, read with
//  `tools/objc-classes.py`.
//
//  That is a theory about *this* phone until something measures it. This is the measurement:
//  was a token minted, how long is it, did the media layer hear a stream-protection status,
//  did the attestation challenge fail and with what error, and what do the app's own feature
//  flags say about the whole path. **Read-only.** It changes no answer, forges nothing, stores
//  no token (lengths only) and sends nothing anywhere; each hook counts and calls the original.
//
//  Every selector is hooked only when the class declares it with the encoding read from
//  21.34.3; what did not attach is named in the report.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NSString *SCIYTPoProbeReport(void);
