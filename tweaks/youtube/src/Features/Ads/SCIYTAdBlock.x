#import "../../YouTubeHeaders.h"
#import "../../SCILog.h"
#import "../../Prefs.h"
#import "../../SCIYTLaunchGuard.h"
#import "../../Diagnostics/SCIYTDiagnostics.h"

///
/// Ads, removed at three different points, because they arrive by three different
/// routes and stopping one does nothing about the others.
///
///   1. the request   — the client stops telling the server it wants ads
///   2. the feed      — promoted sections are dropped by the server's own identifier
///   3. the player    — pre-roll, mid-roll and stream-stitched ads are refused
///
/// Not one of these hooks touches a view. That is the whole reason to do it this way:
/// of the two tweaks measured against this exact binary, the one hooking view classes
/// had nineteen targets that no longer exist, and the one hooking the model layer had
/// none. A feed renderer's identifier comes from Google's servers, so it survives every
/// rebuild of the app.
///

// MARK: - 1. Never ask for ads

//
// **Not during the launch, and this is where the app stopped starting.**
//
// The trail from a device that would not open reads: our constructor entered, read a preference,
// passed the gate and finished — all inside a tenth of a second — and then nothing at all until
// the launch guard gave up eight seconds later. No tab bar, no feed batch, no player. YouTube was
// busy with its own startup, and the only thing of ours running in that window is a hook.
//
// These two are the only hooks in this tweak that **swallow the call entirely**. `-decorateContext:`
// is what attaches ad capabilities and targeting to an InnerTube request, and skipping it was the
// cheap way to get a response with no ads in it. It is also, at launch, refusing to let the app
// finish preparing the first request it makes — and a startup that never gets its response is a
// splash screen that never goes away.
//
// So the moment is the fix, exactly as it was for the tab bar: during the launch the call goes
// through untouched, and from the first moment the app is active it is skipped as before. What
// that costs is ads in the first response of a cold start, which the feed filter downstream is
// already there to drop.
//
static BOOL SCIMayAlterRequests(void) {
    if (SCIYTStoodDown()) return NO;
    return SCIYTAppIsActive();
}

%hook YTAdsInnerTubeContextDecorator

- (void)decorateContext:(id)context {
    SCIYTLaunchMark(@"ads: decorateContext");

    if (!SCIPrefEnabled(SCIPrefHideAds) || !SCIMayAlterRequests()) {
        %orig;
        return;
    }
}

%end

//
// **The same decision on the class that carries it in 21.41.5.** `YTAdsInnerTubeContextDecorator` is not in that build's binary; the
// class that answers `-decorateContext:` (`v24@0:8@16`) is `YTAdsInnerTubeContextDecoratorImpl`. Found by running tools/objc-diff.py
// --check on this tweak against 21.41.5, which listed the old name among the hooks that attach to nothing. Both names stay: a build
// that has the old one is served by the hook above.
//
%hook YTAdsInnerTubeContextDecoratorImpl

- (void)decorateContext:(id)context {
    SCIYTLaunchMark(@"ads: decorateContext (impl)");

    if (!SCIPrefEnabled(SCIPrefHideAds) || !SCIMayAlterRequests()) {
        %orig;
        return;
    }
}

%end

%hook YTAccountScopedAdsInnerTubeContextDecorator

- (void)decorateContext:(id)context {
    SCIYTLaunchMark(@"ads: decorateContext (account)");

    if (!SCIPrefEnabled(SCIPrefHideAds) || !SCIMayAlterRequests()) {
        %orig;
        return;
    }
}

%end

%hook YTAdShieldUtils

// The fingerprint YouTube collects to detect ad blocking. Emptied rather than left
// alone: a client that reports no ads shown *and* a full signal set is a more
// interesting client than one that reports nothing.
+ (NSDictionary *)spamSignalsDictionary {
    SCIYTLaunchMark(@"ads: spamSignals");

    if (!SCIPrefEnabled(SCIPrefHideAds) || !SCIMayAlterRequests()) {
        return %orig;
    }
    return @{};
}

+ (NSDictionary *)spamSignalsDictionaryWithoutIDFA {
    SCIYTLaunchMark(@"ads: spamSignals (no IDFA)");

    if (!SCIPrefEnabled(SCIPrefHideAds) || !SCIMayAlterRequests()) {
        return %orig;
    }
    return @{};
}

%end


// MARK: - 2. Drop promoted sections from the feed

///
/// The identifiers of promoted layouts, as the server itself labels them.
///
/// This is the durable part of ad hiding and the reason it is done by string. These
/// names travel down from Google inside the renderer, so they do not change when the
/// app is rebuilt, when a class is renamed, or when a view is rewritten in Swift --
/// which is exactly how the view-hooking approach ends up with dead features.
///
/// Grouped by what each one actually is, because a bare list invites someone to
/// "clean it up" later without knowing what they are deleting.
///
static NSArray<NSString *> *SCIPromotedIdentifiers(void) {
    static NSArray *identifiers = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        identifiers = @[
            // Measured on the device, not guessed and not read out of the binary.
            //
            // A Sponsored row on Home was selected with FLEX and reported itself as an
            // ELMContainerNode carrying the element `eml.feed_ad_metadata`. That is the
            // first identifier here that came from looking at the thing itself while it was
            // on screen -- the list below it was written from names, which is why it caught
            // nothing across sixty-seven sections, and why widening it from the binary in
            // 0.20.1 caught real videos instead.
            @"feed_ad_metadata",

            // The picture in an ad card, measured the same way. Written out in full rather
            // than as "ad_image": a bare substring would also match load_image and any other
            // word ending in "ad", and this test runs against a section's whole description.
            @"eml.ad_image",

            // Outright ad slots. (feed_ad_metadata is above, with the note on how it was
            // found; it was in this group too and the duplicate is gone.)
            @"brand_promo",
            @"statement_banner",
            @"text_search_ad",

            // Shopping and product placement.
            @"product_carousel",
            @"product_item",
            @"product_engagement_panel",
            @"shopping_carousel",
            @"shopping_item_card_list",

            // The generic layouts promoted content is delivered in. These carry no
            // "ad" in the name and are the ones a hand-written list always misses.
            @"carousel_footered_layout",
            @"carousel_headered_layout",
            @"full_width_portrait_image_layout",
            @"full_width_square_image_layout",
            @"square_image_layout",
            @"landscape_image_wide_button_layout",
            @"text_image_button_layout",
            @"video_display_full_layout",
            @"video_display_full_buttoned_layout",

            // Confirmed from a device report, not read out of the binary: a section
            // carrying ad_slot_logging_data with slot_data.type SLOT_TYPE_IN_FEED and
            // ad_layout_logging_data with layout_data.type
            // LAYOUT_TYPE_VIDEO_DISPLAY_CAROUSEL_BUTTON_GROUP, scattered into Home between
            // ordinary videos -- the shape the "layout has no 'ad' in its name" note above
            // already warned a hand-written list would miss, and it did, until this one.
            @"video_display_carousel_button_group_layout",

            // And the marking the server puts on an ad regardless of what the layout is
            // called, which is what this list should have been matching all along.
            //
            // The entry above was added from a device report naming
            // `video_display_carousel_button_group_layout`. The ad came back, and the report
            // named `video_display_button_group_layout` -- the same layout without the word
            // "carousel". **A list of layout names is a list of the ads that have already got
            // through**, and this one had already predicted that about itself two comments up.
            //
            // `ad_slot_logging_data` is not a layout. It is the ad-serving telemetry Google
            // attaches to something it is charging for, and it sits under
            // `compatibility_options.ad_logging_data` beside a `slot_data { type: SLOT_TYPE_IN_FEED }`.
            // A section that is not an ad has no reason to carry it.
            //
            // **Measured before being trusted, because 0.20.1 emptied the home feed with a
            // substring that was too broad.** The diagnostics page already flags sections on
            // `ad_logging_data`/`ad_slot` for its own sample, and over 66 sections in one
            // report it flagged exactly one: the ad. That is the evidence for this being
            // narrow, and it is why the general marker goes in and no further layout names do.
            @"ad_slot_logging_data",

            // Community posts promoted into the feed.
            @"post_shelf",

        ];
    });
    return identifiers;
}

/// Whether a section renderer is promoted content.
///
/// Read from -description rather than by reaching into the protobuf: every YTI* class
/// is a GPBMessage, whose description prints the whole message tree including the
/// element identifier. That needs no field name to be known, and a field name is
/// precisely the kind of thing that changes between builds.
/// One description per section, per batch — the expensive half, kept separate so the caller can
/// hand the same string to the diagnostics rather than paying for it twice.
static NSString *SCIDescribeSection(id section) {
    if (!section) return nil;

    @try {
        return [section description];
    } @catch (NSException *exception) {
        // A section that cannot describe itself is left alone. Hiding something on the
        // strength of a failed read would be worse than showing an ad.
        SCILogV(@"ads: could not describe a section: %@", exception.reason);
        return nil;
    }
}

static BOOL SCITextIsPromoted(NSString *text) {
    if (!text.length) return NO;

    for (NSString *identifier in SCIPromotedIdentifiers()) {
        if ([text containsString:identifier]) {
            SCILogV(@"ads: dropping a section matching %@", identifier);
            return YES;
        }
    }

    return NO;
}

/// Filters one batch of section renderers, whichever entry point delivered it.
///
/// **There is more than one, and hooking only the first is the likeliest reason an ad shows
/// at launch and is gone after a pull to refresh.** `sectionRenderers` is populated by
/// `-addSectionsFromArray:` *and* by `-insertSections:byPosition:error:` and
/// `-insertSections:byRelativePositionInSectionList:error:` — all three confirmed on
/// YouTube 21.34.3, all three taking an array of the same renderers. A feed built through
/// one of the insert paths went past a filter that only watched the add path, and the
/// refresh afterwards came through the add path and looked fixed.
///
/// `where` is carried through into the diagnostics so the next report names the door the
/// ad came in by, rather than saying only that something got through.
static NSArray *SCIFilterSections(NSArray *sections, NSString *where) {
    if (SCIYTStoodDown()) return sections;
    if (!SCIPrefEnabled(SCIPrefHideAds) || !sections.count) return sections;

    //
    // **A time budget, because the test is `-description` and that is not a cheap question.**
    //
    // A section renderer describes itself by writing out its whole subtree, so the cost is the
    // size of the feed rather than the number of sections — and this runs on the main thread,
    // on the first home response, while the app is still showing its logo. Nothing here changed
    // for that to matter: the *response* grew, on Google's side, and one day the arithmetic
    // crossed from slow to a launch that never finished.
    //
    // So the batch gets twelve hundredths of a second. Past that everything left is kept
    // unexamined and the report says so. An ad getting through is a complaint; an app that will
    // not open is not a complaint, it is a broken phone — the same trade the brake below makes
    // for a filter that drops too much.
    //
    static const NSTimeInterval kSCIFilterBudget = 0.12;
    CFAbsoluteTime started = CFAbsoluteTimeGetCurrent();
    NSUInteger examined = 0;

    NSMutableArray *kept = [NSMutableArray arrayWithCapacity:sections.count];

    // Built once and carried, rather than described a second time for the diagnostics sample.
    NSMutableArray<NSString *> *keptTexts = [NSMutableArray array];

    for (id section in sections) {
        if (CFAbsoluteTimeGetCurrent() - started > kSCIFilterBudget) {
            [kept addObject:section];
            continue;
        }

        examined++;

        NSString *text = SCIDescribeSection(section);
        if (!SCITextIsPromoted(text)) {
            [kept addObject:section];

            // Only the first part of the first few, so the report cannot hold megabytes of
            // somebody's feed in memory for the life of the process.
            if (keptTexts.count < 24 && text.length) {
                [keptTexts addObject:text.length > 4000 ? [text substringToIndex:4000] : text];
            }
        }
    }

    if (examined < sections.count) {
        [SCIYTDiagnostics recordFeedBrake:
            [NSString stringWithFormat:@"%@: out of time after %lu of %lu — the rest went through unexamined",
             where, (unsigned long)examined, (unsigned long)sections.count]];
    }

    // The brake.
    //
    // 0.20.1 widened the identifier list and emptied the home feed: the test is a substring
    // match against a section's whole description, and a section's description contains its
    // items -- so a marker that identifies an advertisement *inside* a shelf condemns the
    // shelf and every real video in it. It took a device report to notice, and by then it
    // was released.
    //
    // An identifier that is wrong in that way does not drop a few sections, it drops most
    // of them. So a batch that loses more than a third is not filtering, it is failing, and
    // the whole batch is put back. Ads getting through is a complaint; a blank feed is a
    // broken app, and this is the difference between the two costing a message and costing
    // a release.
    if (sections.count >= 4 && kept.count * 3 < sections.count * 2) {
        [SCIYTDiagnostics recordFeedSections:sections.count dropped:0];
        [SCIYTDiagnostics recordFeedBrake:
            [NSString stringWithFormat:@"%@: refused to drop %lu of %lu — that is not an ad filter",
             where, (unsigned long)(sections.count - kept.count), (unsigned long)sections.count]];
        return sections;
    }

    if (kept.count != sections.count) {
        SCILogV(@"ads: %@ kept %lu of %lu sections",
                where, (unsigned long)kept.count, (unsigned long)sections.count);
    }

    // Counted so "Sponsored is still showing" has an answer. There are three completely
    // different reasons for it and one complaint covers all of them: no hook running at all
    // -- the feed being built somewhere else again -- a hook running and not recognising
    // what it saw, or the batch arriving through a door with no filter on it. A total of
    // zero says the first; a total with nothing dropped says the second; and the entry
    // point recorded beside the count is what separates the third.
    [SCIYTDiagnostics recordFeedSections:sections.count dropped:sections.count - kept.count];
    [SCIYTDiagnostics recordFeedEntryPoint:where
                                      seen:sections.count
                                   dropped:sections.count - kept.count];

    // What is left after filtering -- the sections the identifier list did not recognise.
    // Reported separately from the counts above because a scattered ad on Home is this
    // list still holding one, and the fastest way to find which identifier is missing is
    // to look at what came through right after seeing it happen.
    [SCIYTDiagnostics recordFeedKeptSampleTexts:keptTexts];

    return kept;
}

%hook YTInnerTubeCollectionViewController

// Filtered on the way in, so the sections are never built into views at all -- as opposed
// to hiding cells afterwards, which leaves gaps in the feed where the cell used to be.
- (void)addSectionsFromArray:(NSArray *)sections {
    %orig(SCIFilterSections(sections, @"add"));
}

- (BOOL)insertSections:(NSArray *)sections byPosition:(int)position error:(id *)error {
    return %orig(SCIFilterSections(sections, @"insert"), position, error);
}

- (BOOL)insertSections:(NSArray *)sections
        byRelativePositionInSectionList:(id)list
                                  error:(id *)error {
    return %orig(SCIFilterSections(sections, @"insert-relative"), list, error);
}

%end


// MARK: - 3. Refuse ads in the player

%hook YTIPlayerResponse

- (BOOL)isMonetized {
    if (!SCIPrefEnabled(SCIPrefHideAds)) {
        return %orig;
    }
    return NO;
}

- (id)adIntroRenderer {
    if (!SCIPrefEnabled(SCIPrefHideAds)) {
        return %orig;
    }
    return nil;
}

- (BOOL)hasAdLoggingData {
    if (!SCIPrefEnabled(SCIPrefHideAds)) {
        return %orig;
    }
    return NO;
}

// Mid-roll ads: the cuepoints are where the player is told it may interrupt.
- (BOOL)isCuepointAdsEnabled {
    if (!SCIPrefEnabled(SCIPrefHideAds)) {
        return %orig;
    }
    return NO;
}

// Dynamic ad insertion: ads stitched into the video stream itself by the server,
// which no feed filter and no view hook can reach. This gate is the only way to
// refuse them.
- (BOOL)isDAIEnabledPlayback {
    if (!SCIPrefEnabled(SCIPrefHideAds)) {
        return %orig;
    }
    return NO;
}

%end

%hook YTLocalPlaybackController

- (id)createAdsPlaybackCoordinator {
    if (!SCIPrefEnabled(SCIPrefHideAds)) {
        return %orig;
    }

    // The last line of defence, and the bluntest: with no coordinator there is nothing
    // to play an ad even if one arrived past all three checks above.
    return nil;
}

%end
