//
//  SCIYTCodecFilter.h
//  Albrhi for YouTube
//
//  H.264 only, for a phone that cannot show anything else.
//
//  **The measured cause.** On 21.33.6 / iOS 16 a regular video played a second or two and
//  stopped with "Something went wrong". Two reports of failing videos and one of a working
//  video, with the 1.39.3/1.39.4 probe, said exactly why:
//
//    * the failing videos offered **three formats per resolution** (itags 134/243/396 at 360p:
//      H.264, VP9, AV1) and the player handed **VP9** (`vp09`) samples to the display layer;
//    * the layer answered `AVFoundationErrorDomain -11839` "Cannot Decode -- the decoder
//      required for this media is busy", under `NSOSStatusErrorDomain -12913`
//      (`kVTVideoDecoderNotAvailableNowErr`), fifty times;
//    * the video that played was **H.264 only** (six formats, `avc1`), and a working session
//      enqueued `avc1` without one failure.
//
//  The app declares VP9 (and, with `populateSwAv1MediaCapabilities`, software AV1) as playable;
//  on this phone VP9 is not. So the player is offered formats it cannot show and chooses one.
//
//  **The fix is at the list, not at the screen.** The stream list the player is handed
//  (`YTIPlayerResponse -streamingData` → `adaptiveFormatsArray`) has its VP9 and AV1 *video*
//  entries removed -- once per response, only when at least one H.264 video remains -- so the
//  adaptive player has nothing else to choose. Audio is untouched. The price is the price of
//  H.264: no 1440p or 4K (YouTube serves those only as VP9/AV1), which is why this is a switch
//  and not a default, and why it **turns itself on only after the display layer has failed on
//  VP9 or AV1 on this phone** and says so.
//
//  Nothing here tells YouTube anything untrue: it narrows what the *player* may pick from, the
//  same thing a "prefer H.264" setting does on the web.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// Called by the probe's display-layer observer: a decode failed, and `subtype` is the
/// four-character codec of the last compressed sample handed to the layer. Switches the filter
/// on (once, persistently) when it was VP9 or AV1 and the automatic switch allows it.
void SCIYTCodecFilterDecodeFailed(uint32_t subtype);

NSString *SCIYTCodecFilterReport(void);
