//
//  SCIYTLibrary.h
//  Albrhi for YouTube
//
//  Where downloads live, and what runs them.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>
#import "SCIYTJob.h"
#import "../SCIYTHLS.h"

@class SCIYTRecipe;

NS_ASSUME_NONNULL_BEGIN

/// Posted on the main thread whenever anything is added, finishes, or moves.
extern NSNotificationName const SCIYTLibraryDidChangeNotification;

///
/// The downloads, running and finished.
///
/// Downloading used to be a window: a progress alert in front of YouTube, holding the
/// app still for as long as the transfer took, and a save to Photos at the end whether
/// or not that was wanted. Both of those were decisions the download had no business
/// making.
///
/// So the file stays here. It is written into the app's own folder, it appears in the
/// Download Centre the moment it is asked for, and going to Photos is a button next to
/// it rather than the only possible ending. The progress is a row in that list, which
/// means starting a download costs the user nothing -- they carry on watching.
///
/// The folder is the truth and the index is a convenience: a job whose file has been
/// deleted from underneath reports no URL, and the list drops it. Nothing here assumes
/// the two agree.
///
@interface SCIYTLibrary : NSObject

@property (class, nonatomic, readonly) SCIYTLibrary *shared;

/// Where finished files are kept. Created on first use.
+ (NSURL *)folder;

/// Running first, then finished, newest first. One list, because a download in flight
/// and the file it becomes are the same row at two moments.
@property (nonatomic, readonly) NSArray<SCIYTJob *> *jobs;

/// Starts one, and returns immediately. The row appears at once.
- (SCIYTJob *)startVariant:(SCIHLSVariant *)variant
                      kind:(SCIYTJobKind)kind
                     title:(nullable NSString *)title
                   videoID:(nullable NSString *)videoID
                   isShort:(BOOL)isShort;

/// Queues downloads of videos by recipe: each waits for a free slot, then asks YouTube for fresh
/// addresses and makes the recipe's choice among them. For playlists. Returns their rows, at the
/// top of the list in the order given.
- (NSArray<SCIYTJob *> *)enqueueRecipes:(NSArray<SCIYTRecipe *> *)recipes;

/// Asks a failed download again, picking up the parts it already fetched.
- (void)retry:(SCIYTJob *)job;

/// Continues the downloads the last launch did not finish (called once the app is active).
- (void)resumeInterrupted;

/// A finished save of this video, if there is one.
///
/// Checked before a download starts. Fetching ninety parts of something already on the
/// device is minutes of waiting and a second copy of the same file, and the person asking
/// has no way to know it is already there -- the list is somewhere else.
- (nullable SCIYTJob *)existingJobForVideo:(nullable NSString *)videoID
                                      kind:(SCIYTJobKind)kind;

/// Deletes the file and the row.
- (void)remove:(SCIYTJob *)job;

/// Clears scratch files an interrupted download left in the temporary directory.
- (void)clearScratch;

/// Writes the list to disk.
///
/// Public because the player edits a job without going through this class: it records where
/// playback stopped, on the job itself, and that has to survive the app being killed. Call
/// it on the main thread -- it walks the store, which has one thread for the reason set out
/// in -adopt:for:.
- (void)save;

/// Gives a saved item a new name, on disk and in the list.
///
/// The extension is kept whatever is typed: a saved video renamed to something without one
/// stops being openable by anything, and nobody typing a title is thinking about that.
/// Answers NO if the name is empty or a file of that name is already there.
- (BOOL)rename:(SCIYTJob *)job to:(NSString *)title;

/// Copies a finished download into Photos, leaving ours where it is.
- (void)export:(SCIYTJob *)job completion:(void (^)(BOOL ok, NSString *_Nullable detail))completion;

/// Total size of everything held.
- (long long)totalBytes;

@end

NS_ASSUME_NONNULL_END
