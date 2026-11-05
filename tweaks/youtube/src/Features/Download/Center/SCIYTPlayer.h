//
//  SCIYTPlayer.h
//  Albrhi for YouTube
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>
#import "SCIYTJob.h"

NS_ASSUME_NONNULL_BEGIN

/// Posted whenever what is playing, or whether it is playing, changes.
extern NSNotificationName const SCIYTPlaybackDidChangeNotification;

///
/// The player for saved downloads. One screen, both kinds.
///
/// Written rather than borrowed, and that is a decision worth stating. AVPlayerViewController
/// gives a play button and a scrubber and nothing else: there is no supported way to put a
/// "next" in its transport bar, and a list of saved videos with no way to move through it is
/// a file opener, not a player.
///
/// So the controls are ours: previous, play, next, a scrubber, both times. The same screen
/// serves sound, with the video's own still standing in for artwork, because the only real
/// difference between the two is whether there is a picture to show.
///
/// **It keeps playing when the app leaves the screen.** The audio session is Playback, the
/// lock screen is given the title and the artwork, and its buttons are wired to the same
/// queue — so skipping from the lock screen skips here. For video that needs one more
/// thing: iOS stops a layer that is not on screen, so the player is taken off the layer
/// when the app goes to the background and given back when it returns. The sound never
/// stops; only the picture is put down while nobody is looking at it.
///
@interface SCIYTPlayer : UIViewController

/// Opens the list at one of its rows. The whole list is the queue, so next and previous
/// mean what they say.
+ (void)presentFrom:(UIViewController *)presenter
               jobs:(NSArray<SCIYTJob *> *)jobs
              start:(NSUInteger)index;

///
/// There is one of these, and closing it does not end it.
///
/// It used to be built per tap and torn down on dismissal, which made "close the player"
/// and "stop the music" the same action -- so browsing the list meant silence. The instance
/// outlives the screen now: dismissing hides it, and what carries on playing is what the
/// mini bar at the bottom of the Centre is showing.
///
/// It is ended by -stop, and by nothing else. That is what the mini bar's close button
/// does, and it is the only place the audio session is handed back.
///
+ (nullable SCIYTPlayer *)current;

/// Whether something is loaded and worth showing a mini bar for.
+ (BOOL)isActive;

/// What is playing, or nil.
+ (nullable SCIYTJob *)nowPlaying;

/// Whether it is playing rather than paused.
+ (BOOL)isPlaying;

/// Play or pause, from outside. For the mini bar.
+ (void)toggle;

/// Ends playback and lets everything go.
+ (void)stop;

/// YouTube's player started audibly: pause ours (SCIYTArbiter decides when).
+ (void)pauseForHost;

/// Takes the audio session back if our player is the one playing. Returns whether it was.
+ (BOOL)reclaimAudioIfPlaying;

/// How far through, from 0 to 1, or 0 when that is not known yet.
///
/// A number rather than the AVPlayer itself. The mini bar needs one fact and handing it the
/// player to get that fact would make every private thing on this class its business too.
+ (double)progress;

/// Brings the full screen back, from the mini bar.
+ (void)reopenFrom:(UIViewController *)presenter;

// MARK: - Used by the player's own sheets (queue, captions)

/// The queue, the row that is playing, and whether the order is being shuffled.
+ (NSArray<SCIYTJob *> *)queueJobs;
+ (NSUInteger)queueIndex;
+ (BOOL)queueShuffled;
+ (void)queueJumpTo:(NSUInteger)row;
+ (void)queueMoveFrom:(NSUInteger)from to:(NSUInteger)to;
+ (void)queueRemoveAt:(NSUInteger)row;

/// The caption languages the playing file carries (`@{@"lang", @"name"}`), the size multiplier and the
/// timing offset (seconds the captions are shown later than the file says; negative = earlier), and
/// a .srt of one language with that offset applied.
+ (NSArray<NSDictionary *> *)captionLanguages;
+ (nullable NSString *)secondCaptionLanguage;
+ (void)setSecondCaptionLanguage:(nullable NSString *)language;   ///< nil = none
+ (double)captionScale;
+ (void)setCaptionScale:(double)scale;
+ (double)captionDelay;
+ (void)setCaptionDelay:(double)seconds;
+ (void)exportCaptionsFor:(NSString *)language completion:(void (^)(NSURL * _Nullable file, NSString * _Nullable failure))completion;

@end

NS_ASSUME_NONNULL_END
