//
//  SCIYTJob.h
//  Albrhi for YouTube
//
//  One download: what it is, where it got to, and where it ended up.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SCIYTJobKind) {
    SCIYTJobKindVideo,
    SCIYTJobKindAudio
};

typedef NS_ENUM(NSInteger, SCIYTJobState) {
    SCIYTJobStateWorking,
    SCIYTJobStateDone,
    SCIYTJobStateFailed
};

///
/// A download, running or finished.
///
/// The same object is both, which is the whole reason the progress can leave the screen:
/// a running download is a row in the centre rather than a window in front of the app,
/// and when it finishes the row becomes the file. Nothing has to be handed over.
///
/// Coded to disk, so the library survives the app closing. The `state` written out is
/// always Done -- a job still working when YouTube quits did not finish, and pretending
/// otherwise would leave a row pointing at a file that was never written.
///
@interface SCIYTJob : NSObject <NSSecureCoding>

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy, nullable) NSString *videoID;

/// "1080p", or the bitrate for sound. Shown under the title.
@property (nonatomic, copy, nullable) NSString *quality;

@property (nonatomic) SCIYTJobKind kind;
@property (nonatomic) SCIYTJobState state;

/// Whether this came from Shorts rather than an ordinary video.
///
/// Not a third `SCIYTJobKind` -- a Short still plays through the same video engine an
/// ordinary video does, so the playback code needs nothing new. It is a browsing fact
/// only: the Centre lists it separately, and its row draws the picture in the tall shape
/// Shorts actually are rather than stretched into a landscape frame it never had.
@property (nonatomic) BOOL isShort;

/// 0 to 1 while working.
@property (nonatomic) double progress;

/// The file's name inside the library folder, not a full path.
///
/// A path would be wrong by the next launch: iOS moves an app's container between
/// updates and every absolute path stored in it goes stale. The folder is found again
/// each time and the name looked up inside it.
@property (nonatomic, copy, nullable) NSString *fileName;

@property (nonatomic) long long bytes;

/// How long it plays, in seconds. Zero until it has been measured once.
///
/// Stored rather than asked each time: a list of thirty rows would otherwise open thirty
/// assets on the main thread to draw itself, and a raw AAC file has to be read through
/// before it will say.
@property (nonatomic) double duration;

/// Where playback had reached when it was last left, in seconds.
///
/// Kept per file rather than per session, so closing the app and coming back a day later
/// still offers the place you stopped. Zero means the start, which is also what a file that
/// was watched to the end resets to -- finishing something is not the same as pausing in it.
@property (nonatomic) double position;
@property (nonatomic, copy) NSDate *createdAt;
@property (nonatomic, copy, nullable) NSString *failure;

/// Whether it has been copied out to Photos. Kept so the row can say so, and so a
/// second tap does not make a second copy.
@property (nonatomic) BOOL exported;

/// Why the automatic copy to Photos was refused, when it was.
///
/// **The switch being on and the copy failing looked exactly like the switch being off:
/// nothing in Photos and nothing said.** The refusal went to the log alone, and no log
/// has ever reached a user -- so "it does not save to Photos" arrived as one complaint
/// covering a setting nobody had turned on, a permission iOS had denied, and a host app
/// that declares no reason to add to the library. Three different fixes, one silence.
@property (nonatomic, copy, nullable) NSString *exportFailure;

+ (instancetype)jobWithTitle:(NSString *)title
                     quality:(nullable NSString *)quality
                        kind:(SCIYTJobKind)kind
                     videoID:(nullable NSString *)videoID;

/// Where the file is now, or nil if it is gone.
- (nullable NSURL *)fileURL;

/// "1080p · 42.3 MB", "Sound · 4.1 MB", "Downloading 62%", "Failed — …".
- (NSString *)statusLine;

@end

NS_ASSUME_NONNULL_END
