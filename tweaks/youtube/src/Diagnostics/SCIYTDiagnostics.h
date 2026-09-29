#import <UIKit/UIKit.h>

///
/// Runtime truth about this build, and about the last video the player was handed.
///
/// Instagram's equivalent page exists because two features were "fixed" repeatedly
/// against classes that were never instantiated. YouTube starts with the same page
/// for a sharper reason: how downloading can work at all depends on which stream
/// path a given build and account actually receives, and that is not readable from
/// the binary. It has to be printed from a real device.
///
@interface SCIYTDiagnostics : NSObject

/// Recorded by the playback hooks, read by the page. Nil until a video plays.
+ (void)recordPlayerResponse:(id)response;
+ (void)recordVideo:(id)video;

/// The player response captured from the overlay — a YTIPlayerResponse, and a third
/// place the formats might carry links. Held since 0.1.0 for the report, and never read
/// by the downloader until it turned out that which streaming data you ask is the whole
/// question.
+ (id)lastPlayerResponse;
+ (NSString *)lastVideoID;

/// The video the captured player response belongs to -- which is the video its HLS playlist
/// is for, and not necessarily the one playing or the last MLVideo built.
+ (NSString *)responseVideoID;

/// The stream object captured for one particular video, or nil.
///
/// Keyed rather than latest-only, because in Shorts the newest capture belongs to the clip
/// being preloaded and the one wanted is the capture before it.
+ (id)streamingDataForVideoID:(NSString *)videoID;

/// The title captured for one particular video.
///
/// Keyed for the same reason the streams are: the newest title belongs to the clip being
/// preloaded, so naming a saved Short after it gives the right video the wrong name.
+ (NSString *)titleForVideoID:(NSString *)videoID;

/// A player response filed under the video it belongs to.
///
/// A second source for a clip whose streams have not been filed yet -- the first Short of a
/// session, in practice. The claim this once carried, that Shorts never builds an MLVideo,
/// was wrong: it builds one a clip ahead, and the store was failing for another reason.
+ (void)recordResponse:(id)response forVideo:(NSString *)videoID;
+ (id)responseForVideoID:(NSString *)videoID;

/// What -didReceiveResponse: actually handed over, whether or not it could be used.
///
/// Kept because "nothing was filed" has three causes that need three different fixes, and
/// the report could not tell them apart.
+ (void)recordShortsResponse:(NSString *)detail;
+ (NSString *)shortsResponseState;

/// The video the player actually activated, which is not always the last MLVideo made.
///
/// A report showed SponsorBlock working on VTBoGy0EynQ while this page reported
/// XDRKSAqd4AA as the last video: MLVideo objects are created for videos the app is
/// preloading as well as the one on screen, and the download was asking YouTube about
/// whichever came last rather than the one being watched. Two ids, two different videos,
/// and a download that could only fail.
+ (void)recordActiveVideoID:(NSString *)videoID;
+ (NSString *)activeVideoID;

/// What the format request did, client by client. Recorded so a failure says which one
/// was asked and what it answered, instead of one sentence covering every cause.
///
/// Safe to call from any thread, which it has to be: the download records from its own
/// queues while the report is being rendered on the main one.
+ (void)recordStreamAttempt:(NSString *)line;
+ (void)clearStreamAttempts;

/// A snapshot of the lines recorded so far. Whoever enumerates must hold a copy.
+ (NSArray<NSString *> *)attempts;
+ (NSString *)lastVideoTitle;

/// Recorded by the settings hooks: the groups YouTube's settings screen is built
/// from, with the type of each. Those numbers cannot be read out of the binary, and
/// getting the wrong one is why 0.1.0 showed no section at all.
+ (void)recordSettingsGroups:(NSArray *)groups;

/// Recorded when the panel could not be built. It is caught rather than allowed to
/// reach the app, so it has to be written down somewhere or the failure is invisible.
+ (void)recordPanelFailure:(NSString *)reason;

/// The last thing SponsorBlock did, in one line.
///
/// Added because 0.3.0 shipped unable to read a video ID and there was no way to see
/// that from the phone: the feature simply never fired, which looks identical to "no
/// segments exist for this video" and to "the hook did not attach". Three different
/// faults with one symptom is exactly what this page exists to separate.
+ (void)recordSponsorState:(NSString *)state;

/// Which progress-bar class the markers were drawn on, and how many.
///
/// Separate from the state above because they answer different questions: that one says
/// whether segments were found, this one says whether the bar was. Three bar classes are
/// hooked and only one of them exists in any given build -- this reports which.
+ (void)recordMarkerBar:(NSString *)className count:(NSInteger)count;

/// What happened when the Downloads tab tried to attach, and then to draw itself.
///
/// 0.18.0 reported nothing about the tab at all, so "the icon did not appear" had no
/// answer in the report -- it could not even say whether a tab was built.
+ (void)recordTabState:(NSString *)state;
+ (NSString *)tabState;

/// What the saved-media player actually handed the lock screen, once per track started.
///
/// Reported because "the lock screen does not show" has looked, on paper, like it should
/// be impossible for one kind and not the other: video and sound go through the same
/// -describeToLockScreen, on the same schedule, with the same session category. If the
/// dictionary really is being built and handed over the same way for both, the fault is
/// downstream of this tweak -- and if it is not, this line is where that would show.
+ (void)recordLockScreenState:(NSString *)state;
+ (NSString *)lockScreenState;

/// What a captured player response answers for a cluster of ad-slot selectors that two
/// independently reference tweaks touch and this one does not yet — playerAdsArray,
/// adPlacementsArray, adSlotsArray, adSlotRenderer, adParams, adNextParams, adBreakParams.
/// Every one of them is confirmed as a real selector on this build from the same class
/// dump the rest of this file's ad-blocking reasoning is measured from; what is not yet
/// known is which class answers which, or what shape the answer takes -- an array with
/// items in it, an array that is always empty, a message that is always nil. This probes
/// -respondsToSelector: one name at a time and reads back only the class and count of
/// whatever answers, the same discipline the X tweak's follow-badge rewrite was built on:
/// one confirmed selector, guarded, never a blind -valueForKey: sweep.
+ (void)recordAdSlotProbe:(NSString *)state;
+ (NSString *)adSlotProbeState;

/// A short excerpt of every section the feed filter chose to *keep* on its last pass —
/// not the ones it dropped, the ones it let through. Reported because the complaint this
/// answers is scattered ads on Home while scrolling, which is the feed filter missing a
/// section rather than the player showing one, and the fastest way to find what it missed
/// is to look at what it did not drop right after seeing one slip through.
/// The kept sections, **already described**.
///
/// It used to take the sections themselves and call `-description` on each one — a second full
/// description of every section in the batch, on top of the one the filter had just built to
/// test it. A section renderer's description is its whole subtree as text, so on a large home
/// feed that was tens of megabytes of string building on the main thread, twice, while the app
/// was still showing its logo. The filter builds each text once now and hands it here.
+ (void)recordFeedKeptSampleTexts:(NSArray<NSString *> *)texts;
+ (NSString *)feedKeptSampleState;

/// What the Shorts save button did, or why there is none.
+ (void)recordShortsButton:(NSString *)state;
+ (NSString *)shortsButtonState;

/// What happened the last time YouTube's own download button was tapped.
///
/// A tally, not a snapshot of the last event: "seen" and "answered" have different causes
/// and a single line naming only the most recent one cannot tell them apart. Empty until a
/// tap reaches the hook at all, which is itself the answer when the class is not drawn.
+ (void)recordNativeDownloadButton:(NSString *)state;
+ (NSString *)nativeDownloadButtonState;

/// The last thing that happened at that button, kept apart from the counts above.
///
/// A status and an event do not share a variable: the counts are rewritten on every view
/// built, which is on every video you scroll to, so a note about the one tap that mattered
/// would be erased by the next swipe. This project has made that exact mistake twice, in
/// two tweaks, after writing it down once.
+ (void)recordNativeDownloadNote:(NSString *)note;
+ (NSString *)nativeDownloadNote;

/// The save button inside YouTube's own player controls.
///
/// Its own line, because for eight releases it had none: the one record it wrote went into
/// `-recordMarkerBar:`, the SponsorBlock progress-bar slot, so an unconfirmed feature's only
/// evidence was filed under an unrelated heading and no report ever showed it.
+ (void)recordOverlayButton:(NSString *)state;

/// The Save button in YouTube's own action row -- rows seen, renderers added, views found, taps.
///
/// Its own slot, not shared with the player overlay's. The overlay button spent eight releases
/// recording into the SponsorBlock marker line, so no report ever mentioned it and nobody could
/// confirm anything: a diagnostic filed under another feature's heading reads as covered.
+ (void)recordActionRow:(NSString *)state;
+ (NSString *)actionRowState;

/// The bar cell that really draws the row on this build, and whether a button went into it.
+ (void)recordActionBar:(NSString *)state;
+ (NSString *)actionBarState;

/// Walks the live view hierarchy and writes down what is actually on screen.
///
/// **Every placement question in this tweak has been answered twice: once from a class dump and
/// once, correctly, from the device.** A dump says what exists in the binary; it does not say
/// what the app builds, and this project has now shipped three features aimed at classes that
/// were never constructed on the phone in front of it. Instagram has had this page's equivalent
/// for a year and it is what ended the guessing there.
///
/// Run it with a video open. It records the classes under the player -- anything whose name
/// carries Action, Slim, Metadata, ELM or Button -- with each one's frame, capped so the report
/// stays readable.
+ (void)scanWatchPage;
+ (NSString *)watchScanState;

/// Asks for a scan the next time a player is on screen.
///
/// **Running it from the settings screen scanned the settings screen.** A full-screen presentation
/// takes the presenting hierarchy out of the window once the transition finishes, so the watch page
/// was not there to be looked at: the first report back listed a navigation bar's buttons and
/// nothing else, which is an accurate scan of the wrong screen. The request is remembered instead,
/// and the scan runs from the player's own overlay -- a moment when what is being asked about is
/// certainly on screen.
/// Scans the tree `view` belongs to, from its topmost ancestor down.
///
/// **Not the key window, and that distinction is the whole of two failed scans.** Our settings
/// screen is presented full screen, which takes YouTube's hierarchy out of the window — so a scan
/// of the window described the settings table, twice, accurately. A view that is off the window
/// still has its own root, and that root is the watch page.
+ (void)scanFromView:(UIView *)view;

+ (void)requestWatchScan;
+ (BOOL)watchScanRequested;

/// The real method list of one class, read from the runtime on the device.
///
/// **This is `tools/objc-classes.py`, run where it matters.** That tool reads a binary somebody
/// downloaded; this reads the build in front of the person reporting. Three features in this
/// tweak have now been written against selectors confirmed in one YouTube build and absent from
/// another, and each cost a release to discover -- `-createActionViewsFromSupportedRenderers:`
/// is confirmed in 21.34.3 and the class on 21.30.5 was never asked whether it answers it.
+ (NSString *)methodsOfClassNamed:(NSString *)name;
+ (NSString *)overlayButtonState;

/// What the last tap on that button actually tried to save. Its own slot: the line above is
/// rewritten on every clip and buried this every time.
+ (void)recordShortsSave:(NSString *)detail;
+ (NSString *)shortsSaveState;

/// Why a saved file would not open, straight from AVFoundation.
+ (void)recordPlaybackFailure:(NSString *)detail;
+ (NSString *)playbackFailures;

/// When the feed filter refused to run because it would have dropped too much.
+ (void)recordFeedBrake:(NSString *)detail;

/// Whether an ad page in Shorts was seen, and refused.
+ (void)recordShortsAd:(NSString *)detail;

/// The runtime-installed ad gates, one line each: whether it attached on this build and how
/// many times it has acted. `status` is written once at install (hooked, absent class, absent
/// method, or the encoding it found instead), and `-countAdGate:` moves the tally -- kept as
/// two acts because a gate that is hooked and never reached and a gate that is absent are two
/// different faults that one number reads identically.
+ (void)registerAdGate:(NSString *)label status:(NSString *)status;
+ (void)countAdGate:(NSString *)label;
+ (NSString *)adGateState;
+ (NSString *)shortsAdState;

/// How much of the feed this run saw, and how much of it was dropped as promoted.
+ (void)recordFeedSections:(NSUInteger)seen dropped:(NSUInteger)dropped;
+ (NSString *)feedState;

/// Which entry point delivered a batch of feed sections, and what happened to it.
///
/// `sectionRenderers` is filled by three different methods, and a filter on one of them
/// leaves the other two open -- which is what an ad appearing at launch and vanishing after
/// a pull to refresh looks like. Tallied per door, so the next report names it instead of
/// only saying that something got through.
+ (void)recordFeedEntryPoint:(NSString *)where
                        seen:(NSUInteger)seen
                     dropped:(NSUInteger)dropped;
+ (NSString *)feedEntryPoints;

/// Whether YouTube's own two SABR gates were consulted, and what was answered.
///
/// This is the whole of the SABR investigation until a report comes back. SABR is why every
/// format in this build has no URL, and why downloading takes ninety requests and a demuxer
/// instead of one GET. Two gates exist for it; whether they are ever read cannot be settled
/// from the binary, and forcing something that is never read would change nothing while
/// looking exactly like a fix.
///
/// So: with the setting off these count and nothing else, and this line says whether there
/// is anything here worth pursuing at all.
+ (void)recordSabrGate:(NSString *)gate original:(BOOL)original forced:(BOOL)forced;

/// Whether the two classes exist in this build, recorded at load.
///
/// Separate from the counts above, because "never consulted" and "not in this version" are
/// different answers that need different next steps and a counter cannot tell them apart.
+ (void)recordSabrClasses:(BOOL)reloadContext onesie:(BOOL)onesie;

+ (NSString *)sabrState;

/// The whole report as text: what the file holds and the copy button copies.
+ (NSString *)report;

/// The same report, bounded for the screen.
///
/// The full player response is a protobuf printed as text and runs to hundreds of
/// kilobytes on a real video. Handing that to a UITextView in one string is what made
/// this page take YouTube down when opened — and a crash inside the page that exists
/// to explain crashes is the worst one there is. The file keeps everything.
+ (NSString *)reportForDisplay;

/// YouTube's own version, for the identity card and the report.
+ (NSString *)appVersion;

/// Whether every class the features hook is actually present.
///
/// Read by the identity card so the answer is the first thing on the settings screen
/// rather than something to go looking for. Earlier versions buried it -- 0.1.0 put it
/// behind the very thing that had failed.
+ (BOOL)featuresAttached;

/// Writes the report to a file inside the app's own container, and returns its path.
///
/// 0.1.0 put the only way to read a diagnostic *inside* the settings section, so when
/// that section failed to appear there was no way to find out why -- the one failure
/// the page exists to explain was the one it could not explain. This is the way out
/// that does not depend on any hook having worked.
+ (NSString *)writeReportToFile;

+ (UIViewController *)viewController;

@end
