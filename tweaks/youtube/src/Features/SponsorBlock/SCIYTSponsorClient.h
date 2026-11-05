#import <Foundation/Foundation.h>

///
/// One segment of a video that somebody has marked as skippable.
///
@interface SCISponsorSegment : NSObject
@property (nonatomic, copy) NSString *category;
@property (nonatomic, copy) NSString *uuid;
@property (nonatomic, assign) NSTimeInterval start;
@property (nonatomic, assign) NSTimeInterval end;
/// `skip` (the ones acted on live), `chapter` (a named stretch of the video) or `poi` (a single point,
/// the highlight). Only a saved file's lookup returns the last two.
@property (nonatomic, copy) NSString *actionType;
/// A chapter's name, when the submitter gave one.
@property (nonatomic, copy) NSString *title;
@end


///
/// Asks sponsor.ajay.app which parts of a video are sponsored.
///
/// Segment data comes from the SponsorBlock database and is licensed CC BY-NC-SA 4.0.
/// The attribution is not decoration: it is a licence condition, and it is shown in the
/// settings screen the same way SCInsta's authorship is shown on the Instagram side.
///
/// **The video ID is never sent.** SponsorBlock offers two endpoints: one takes the
/// video ID, the other takes the first four characters of its SHA-256 and returns the
/// segments of every video whose hash starts the same way. The first is simpler and
/// tells a third party exactly what you are watching, every time you watch something.
/// For a tweak whose Instagram half exists to stop an app reporting what you look at,
/// that was not a real choice.
///
/// The cost is honest and paid locally: the hashed endpoint returns the raw submissions
/// rather than the server's curated pick, so the filtering by votes and action type that
/// the server would have done happens here instead.
///
@interface SCIYTSponsorClient : NSObject

/// Looks up a video's segments, already filtered to the categories the user enabled.
/// The completion runs on the main queue, always, and may receive an empty array.
+ (void)segmentsForVideo:(NSString *)videoID
              completion:(void (^)(NSArray<SCISponsorSegment *> *segments))completion;

/// The same lookup for a file that will be played later: the segments of **every** category,
/// asked for only when SponsorBlock is on and at least one category is switched on (someone who
/// wants none of it makes no request). The player then skips only the categories that are on
/// *when it plays*, so a category switched on after the download applies to it too.
+ (void)segmentsForSavedVideo:(NSString *)videoID
                   completion:(void (^)(NSArray<SCISponsorSegment *> *segments))completion;

/// The segments of a saved file with what the live lookup leaves out: `chapter` (the community's
/// named chapters) and `poi_highlight` (the one moment worth jumping to) come back beside the skips,
/// told apart by `actionType`. Asked for under the same condition as `segmentsForSavedVideo:`.
+ (void)annotatedSegmentsForSavedVideo:(NSString *)videoID
                            completion:(void (^)(NSArray<SCISponsorSegment *> *segments))completion;

/// Whether SponsorBlock is on and at least one category is.
+ (BOOL)anyCategoryEnabled;

/// Whether this category's switch is on right now (and SponsorBlock itself).
+ (BOOL)categoryIsEnabled:(NSString *)category;

/// A human name for a category, for the notice shown after a skip.
+ (NSString *)displayNameForCategory:(NSString *)category;

@end
