//
//  SCIYTDirect.h
//  Albrhi for YouTube
//
//  The direct route: ask YouTube for a video as a client it still serves plain files to, and
//  fetch those files.
//
//  **This is the method YTKACE (MIT, github.com/itzzace/ytkace) calls "direct", carried over
//  as a method rather than as code** -- the request shape is the one it documents, the rest is
//  written against this project's own downloader.
//
//  **Why it is the first route and the playlist the second.** The playlist route reads a
//  manifest the *app* was handed, which is a thing YouTube changes whenever it changes the app;
//  the direct route is a request this tweak makes itself, to a client (visionOS) that has no
//  reason to be migrated off plain files, and it needs neither the app's own state nor a
//  signature solver -- those URLs carry no `n` challenge, which was checked by fetching a file
//  from one, not assumed. Updating YouTube cannot move anything this route depends on.
//
//  **It is anonymous.** The only identity on the request is a visitor id YouTube hands out to
//  anybody who asks, from `/guide`; no cookie, no authorisation header, nothing from the signed
//  in account. The price of that is stated rather than hidden: a video that needs an account
//  -- age-restricted, private, members only -- is refused here, and the download falls through
//  to the playlist route, which carries the app's own session.
//
//  Only what iOS can put in an .mp4 without re-encoding is offered: H.264 up to 1080p and
//  AAC. 1440p and 4K are VP9 and AV1 at YouTube, and offering them would produce a file that
//  saves perfectly and then will not play.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>
#import "SCIYTHLS.h"

@interface SCIYTDirect : NSObject

/// True once this route has failed for the video during this launch, so the caller goes
/// straight to the playlist instead of asking a second time for the same refusal.
+ (BOOL)hasFailedForVideo:(NSString *)videoID;

/// The qualities the direct route can offer for a video, best first. Delivered on the main
/// queue; an empty array always comes with a sentence saying why.
+ (void)variantsForVideo:(NSString *)videoID
              completion:(void (^)(NSArray<SCIHLSVariant *> *variants, NSString *failure))completion;

/// Fetches one quality and hands back a finished .mp4.
+ (void)downloadVariant:(SCIHLSVariant *)variant
               progress:(void (^)(double fraction))progress
             completion:(void (^)(NSURL *file, NSString *failure))completion;

/// Fetches the sound alone and hands back a finished .m4a.
+ (void)downloadAudioFor:(SCIHLSVariant *)variant
                progress:(void (^)(double fraction))progress
              completion:(void (^)(NSURL *file, NSString *failure))completion;

@end
