#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

///
/// Runtime diagnostics.
///
/// Two features — the inline download button and the quality picker — depend on
/// Instagram class names that vary between builds. When one silently does nothing
/// there is no way to tell *why* from the UI alone, and guessing at class names
/// from a class dump has already produced two wrong fixes.
///
/// This page reports what is actually true on this device: which classes exist,
/// which hooks attached, and what the last download attempt found. Tapping a row
/// copies the whole report so it can be pasted into an issue.
///

@interface SCIDiagnosticsViewController : UITableViewController
@end

///
/// Facts recorded by features at runtime, read back by the page above.
///

@interface SCIDiagnostics : NSObject

/// Called by the inline button each time it attaches to an action row.
+ (void)recordActionRowClass:(NSString *)className controlCount:(NSInteger)controlCount;

/// Called by the downloader with how many distinct renditions a video offered.
+ (void)recordQualityCount:(NSInteger)count forVideoClass:(nullable NSString *)className;

/// Called by the downloader with the raw DASH manifest a video carried, if any.
///
/// Instagram serves video over DASH and the manifest lists renditions that
/// -videoVersions omits, which is the most likely reason the quality picker has
/// come up short. Nothing parses it yet — this records what the device actually
/// receives so a parser can be written against real data rather than a guess.
/// @param xml    the manifest text, or nil when the objects carried none.
/// @param names  every selector on the video and media objects whose name
///               mentions dash or manifest, as reported by the runtime.
///
/// @c names is the useful half when @c xml is nil: an empty list means the
/// field is not exposed on these classes at all and parsing DASH is a dead end,
/// while a populated list names what to read next.
+ (void)recordDashManifest:(nullable NSString *)xml candidates:(nullable NSArray<NSString *> *)names;

/// Called when the story seen-state uploader is intercepted.
/// What the inline button resolved the post's media to, or nil if it found nothing.
+ (void)recordButtonMediaClass:(nullable NSString *)className;

/// Which branch a download took: "video" or "photo". A photo post reported as
/// video means the emptiness check is failing again.
+ (void)recordDownloadKind:(NSString *)kind;

/// Records one stage of an AV1 transcode (download, demux, decode+encode, mux).
/// The pipeline cannot be tested off-device, so a failure has to name its stage
/// here rather than surface as a blank video. A stage named "download-video"
/// begins a fresh run and clears the previous one.
+ (void)recordTranscodeStage:(NSString *)name ok:(BOOL)ok detail:(nullable NSString *)detail;

+ (void)recordStorySeenIntercept;

/// How the story download button reached its item, and every centre-covering view
/// class whose name mentions a story.
///
/// «no media» has two readings that need opposite fixes -- nothing was on screen, or
/// the item was there under a name this build does not share with the one the search
/// was written against. The class list is the half that answers the second without a
/// further round trip, which is the same fix the YouTube scanner needed when its
/// hand-picked filter could not show the name nobody expected.
+ (void)recordStorySearchRoute:(nullable NSString *)route
                       classes:(nullable NSArray<NSString *> *)classNames;

/// The key path a photo story's music was found at, or nil when the dictionary held
/// none. The leaf key is searched rather than named, so this is what says what it is
/// actually called on this build.
+ (void)recordStoryAudio:(nullable NSString *)keyPath;

/// Whether the mark-as-seen button found a section controller to advance with.
/// It used to write this to the log alone, which no report has ever carried.
+ (void)recordStoryAdvanceFound:(BOOL)found;

/// Whether the newer build's Swift seen-state store was found and hooked, and under which
/// runtime name.
///
/// Reported because "no interceptions" has two readings — not attached, or attached and
/// never reached — and they need opposite fixes. Pass nil for `runtimeName` when nothing was
/// found; the row then says so rather than showing a blank that reads as a bug.
+ (void)recordStorySeenHookAttached:(BOOL)attached resolvedTo:(nullable NSString *)runtimeName;

/// Which suppressed delegate calls the mark-as-seen button managed to replay.
/// A green tick with nothing replayed means the receipt never left the device.
+ (void)recordSeenReplayBegan:(BOOL)began ended:(BOOL)ended;

/// Walks the live view hierarchy behind the settings sheet looking for anything
/// shaped like a post action row — a view holding several buttons in a line.
///
/// Class-dump names tell you what *exists* in the binary, not what Instagram
/// actually renders. This reports what is on screen right now, which is the only
/// way to know where the download button belongs.
+ (NSArray<NSString *> *)scanForActionRowCandidates;

/// Walks the live hierarchy for labels whose text reads like a timestamp ("2h",
/// "5 d", "January 5") and reports each one's class and its owning superview.
///
/// The custom date format needs somewhere to attach, and Instagram's timestamp
/// classes are not in any header we have. Rather than guess a name — the mistake
/// this project keeps paying for — this reports what is actually on screen, so
/// the hook can be written against a verified class.
+ (NSArray<NSString *> *)scanForTimestampLabels;

/// Called from the date hooks with the formatter that ran and what it produced.
///
/// Which Foundation formatter Instagram uses decides whether custom dates can
/// reach every surface at once. Counting the calls and keeping a few samples
/// answers that from the device instead of from assumption.
+ (void)recordDateFormatter:(NSString *)formatter sample:(nullable NSString *)sample;

/// Called when a timestamp was rewritten. @c exact says whether the real date was
/// found on the model or inferred from Instagram's wording, which is the
/// difference between showing the true minute and showing an approximation.
+ (void)recordDateRewrite:(NSString *)original exact:(BOOL)exact;

/// How many of Instagram's NSDate formatting selectors were found and hooked.
/// Zero means this build names them differently and the feature cannot work,
/// which is worth knowing before hunting anywhere else.
+ (void)recordDateHooksInstalled:(NSInteger)count;

/// What the voice-message probe could resolve when a message menu opened.
/// Whether the URL is reachable decides if saving voice notes is worth wiring a
/// button for, or whether the chain has to be found another way.
+ (void)recordAudioMessageProbe:(BOOL)foundMessage
                       audioURL:(nullable NSString *)url
                   messageClass:(nullable NSString *)className;

/// How many reels auto-scroll gates were found and forced. Zero means this build
/// names them differently.
+ (void)recordReelsGatesForced:(NSInteger)count;

/// Every playback-progress update seen on a reel cell, with the highest progress
/// reached. Whether this fires at all decides where the auto-scroll trigger has to
/// live — a count of zero means the progress indicator is not the signal to use.
+ (void)recordReelsProgress:(double)progress total:(double)total from:(nullable NSString *)className;

/// One attempt to move to the next reel: which selector was used and whether the
/// feed controller was found at all.
+ (void)recordReelsAdvance:(nullable NSString *)selector foundController:(BOOL)found;

/// One unsend that was held back, with the removal reason Instagram gave and how
/// many messages it covered. The reason tells apart a message someone else unsent
/// from one unsent here, which decides whether both should be kept; the values are
/// worth observing rather than assuming.
+ (void)recordUnsendKeptWithReason:(NSInteger)reason messageCount:(NSInteger)count;

/// Which message-removal path Instagram actually used, recorded whether or not
/// anything was held back. Direct runs on two stacks and which one a chat uses is a
/// server decision, so a feature that touches removals has to say which path it saw
/// rather than leave a silent zero meaning either "never fired" or "nothing to do".
+ (void)recordUnsendPath:(NSString *)path detail:(nullable NSString *)detail;

/// Every stage of resolving a video's quality, counted separately.
///
/// A quality picker was built three times against this pipeline and each one offered
/// a single option. One total could never say why: whether the manifest carried few
/// renditions, whether parsing dropped them, or whether they were all in a codec iOS
/// refuses to save. These are the numbers that decide whether a picker is worth
/// building at all, and on which source.
+ (void)recordQualityFunnelWithVersions:(NSInteger)versions
                        representations:(NSInteger)representations
                              videoReps:(NSInteger)videoReps
                               saveable:(NSInteger)saveable
                               distinct:(NSInteger)distinct
                           transcodable:(NSInteger)transcodable
                                 chosen:(nullable NSString *)chosen;

@end

NS_ASSUME_NONNULL_END
