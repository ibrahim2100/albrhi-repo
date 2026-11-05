//
//  SCIYTParts.h
//  Albrhi for YouTube
//
//  Fetching a playlist's parts several at a time, and joining them in the right order.
//
//  The sequential fetcher this replaces was correct and slow. Ninety-odd parts, each waiting
//  for the one before it to finish, means paying the round trip to Google ninety times end to
//  end -- and on a phone that latency, not the bandwidth, is most of the wait.
//
//  **Order is guaranteed by construction, not by arrival.** That distinction is the whole
//  design. Parts arrive in whatever order the network returns them, so nothing here appends
//  to a shared handle: each part is written to its own file named after its index, and the
//  join reads those names in numeric order. There is no code path in which a part can be
//  placed after a later one, because no code path decides placement at all.
//
//  That matters more than it might sound. A misordered video is not a failure that announces
//  itself -- it downloads, it saves, it appears in the list, and it is wrong only when
//  watched. This project has already spent nine releases on one silent wrong-answer bug and
//  does not need a second.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIYTParts : NSObject

/// Fetches every address and hands back the files, in the order the addresses were given.
///
/// The completion carries either the ordered files or a message, never both and never
/// neither. Any part that cannot be fetched after its retries fails the whole run, and the
/// scratch folder is cleared before the message is delivered -- a half-fetched video is not
/// worth keeping and would only be found later by the sweep.
+ (void)fetch:(NSArray<NSString *> *)addresses
     progress:(void (^)(double fraction))progress
   completion:(void (^)(NSArray<NSURL *> *ordered, NSURL *folder, NSString *error))completion;

/// The same, kept on disk: the parts of run `runIdentifier` live in `+folderForRun:` and survive the
/// app being closed. Parts already there with the size the plan expects are not fetched again, the
/// system's tasks of an earlier attempt are cancelled, and a failure leaves the folder for the next try.
/// `sizes` gives each part's expected byte count (nil to accept any), index for index with `addresses`.
+ (void)fetch:(NSArray<NSString *> *)addresses
        sizes:(nullable NSArray<NSNumber *> *)sizes
runIdentifier:(nullable NSString *)runIdentifier
     progress:(void (^)(double fraction))progress
   completion:(void (^)(NSArray<NSURL *> *ordered, NSURL *folder, NSString *error))completion;

/// Harness only: an ordinary session instead of the system's background one (see the .m).
+ (void)useForegroundSessionForHarness;

/// Where resumable runs keep their parts, and the folder of one.
+ (NSURL *)resumableRoot;
+ (NSURL *)folderForRun:(NSString *)identifier;

/// Stops a resumable run for good and deletes what it had fetched.
+ (void)abandonRun:(NSString *)identifier;

/// How many parts of a run are on disk.
+ (NSUInteger)partsOnDiskForRun:(NSString *)identifier;

/// Joins parts into one file, in the order given, and removes the folder afterwards.
///
/// Written through a handle rather than gathered: a 1080p video is a couple of hundred
/// megabytes and a phone should not be asked to hold that twice to concatenate it.
+ (nullable NSURL *)join:(NSArray<NSURL *> *)ordered
               extension:(NSString *)extension
                  folder:(nullable NSURL *)folder;

@end

NS_ASSUME_NONNULL_END
