//
//  SCIYTClients.h
//  Albrhi for YouTube
//
//  Which InnerTube clients the direct route asks, in order, and when to go on to the next.
//
//  Measured on 2026-11-05 from this project's build machine, for six videos: the visionOS client
//  answered with direct URLs for all six *with* a visitor id, and `LOGIN_REQUIRED` for five of six
//  without one; the iOS client at version 20.10.4 and the Android VR client at 1.60.19 answered with
//  direct URLs up to 2160p with no visitor id at all, and every one of those URLs gave a plain 200
//  and the right bytes for a `&range=` request. The iOS client at the *current* app version (21.41.5)
//  answered with no URLs at all (server-driven streaming only), so the older version number is
//  deliberate. These are the clients yt-dlp falls back through too (OmniGet's `SABR_CLIENT_CASCADE`,
//  GPL-3.0, names `ios` and `android` among them); the table is data so a client that stops working
//  is a one-line change.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIYTClients : NSObject

/// The clients in the order they are tried: `@{@"name", @"client": dictionary for the request's
/// context, @"agent": User-Agent, @"visitor": BOOL (send a visitor id)}`.
+ (NSArray<NSDictionary *> *)all;

/// Whether an answer that did list formats looks like YouTube holding the quality back: the tallest
/// picture is 360p or less for something that runs two minutes or more. A short or old video can
/// honestly have nothing better, which is why the next client is only *tried* and the best of the
/// answers is kept.
+ (BOOL)looksDegradedMaxHeight:(NSInteger)maxHeight seconds:(double)seconds;

/// Whether a refusal says another client might answer (a sign-in demand, an unplayable status, no
/// formats) rather than the video being gone for everyone (removed, private, region-locked).
+ (BOOL)refusalMayDifferByClient:(nullable NSString *)playabilityStatus reason:(nullable NSString *)reason;

@end

NS_ASSUME_NONNULL_END
