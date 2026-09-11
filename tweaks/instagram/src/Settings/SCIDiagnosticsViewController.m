#import "SCIDiagnosticsViewController.h"
#import "../Compat/SCITitleMatch.h"
#import <objc/runtime.h>
#import "shared/src/SCIPanelGate.h"
#import "SCIFeatureAudit.h"
#import "../Utils.h"
#import "../Localization/SCILocalize.h"
#import "../Tweak.h"
#import "../SCIProject.h"

// Recorded facts. Written from feature code, read on the main thread by the page.
static NSMutableArray<NSString *> *_actionRowClasses = nil;
static NSInteger _lastQualityCount = -1;
static NSString *_lastVideoClass = nil;
static NSInteger _storySeenIntercepts = 0;
static NSString *_storySeenHook = nil;
/// Whether *either* chokepoint is installed -- which is what "is this feature working" means.
static BOOL _storySeenAnyHook = NO;
static NSString *_seenReplay = nil;
static NSArray<NSString *> *_scanResults = nil;
static NSArray<NSString *> *_timestampResults = nil;
static NSString *_lastButtonMediaClass = nil;
static BOOL _buttonEverPressed = NO;
static NSString *_lastDownloadKind = nil;
static NSString *_storyRoute = nil;
static NSMutableArray<NSString *> *_storyClasses = nil;
static NSString *_lastDashXML = nil;
static NSInteger _lastDashRepresentations = 0;
static NSArray<NSString *> *_lastDashCandidates = nil;
static BOOL _dashProbeRan = NO;
static NSMutableArray<NSString *> *_transcodeStages = nil;
static NSMutableDictionary<NSString *, NSNumber *> *_dateFormatterCounts = nil;
static NSMutableArray<NSString *> *_dateFormatterSamples = nil;
static NSInteger _dateHooksInstalled = -1;

// Reels auto-scroll. The point of these is to say which link in the chain breaks:
// gates not found, progress never reported, or the advance running with no effect.
static NSInteger _reelsGatesForced = -1;
static NSInteger _reelsProgressCalls = 0;
static double _reelsProgressMax = 0;
static double _reelsProgressTotal = 0;
static NSString *_reelsProgressClass = nil;
static NSInteger _reelsAdvances = 0;
static NSString *_reelsAdvanceSelector = nil;
static NSInteger _unsendsKept = 0;
static NSMutableArray<NSString *> *_unsendReasons = nil;
static NSMutableArray<NSString *> *_unsendPaths = nil;
static NSArray<SCIFeatureAuditResult *> *_auditResults = nil;
static NSString *_qualityFunnel = nil;
static NSString *_qualityChosen = nil;
static BOOL _reelsFoundController = NO;
static NSString *_audioProbe = nil;
static NSInteger _dateRewrites = 0;
static NSInteger _dateRewritesExact = 0;
static NSMutableArray<NSString *> *_dateRewriteSamples = nil;

@implementation SCIDiagnostics

+ (void)initialize {
    if (self != [SCIDiagnostics class]) return;

    _actionRowClasses = [NSMutableArray array];
}

+ (void)recordActionRowClass:(NSString *)className controlCount:(NSInteger)controlCount {
    if (![className length]) return;

    NSString *entry = [NSString stringWithFormat:@"%@ (%ld controls)", className, (long)controlCount];

    @synchronized (_actionRowClasses) {
        for (NSString *existing in _actionRowClasses) {
            if ([existing hasPrefix:className]) return;
        }

        [_actionRowClasses addObject:entry];
    }
}

+ (void)recordQualityCount:(NSInteger)count forVideoClass:(NSString *)className {
    _lastQualityCount = count;
    _lastVideoClass = [className copy];
}

+ (void)recordDashManifest:(NSString *)xml candidates:(NSArray<NSString *> *)names {
    _dashProbeRan = YES;
    _lastDashXML = [xml copy];
    _lastDashCandidates = [names copy];

    // Counting <Representation> elements is the number that decides whether this
    // is worth building on: more of them than -videoVersions returned means the
    // renditions the quality picker has been missing are here.
    _lastDashRepresentations = 0;

    if (![xml length]) return;

    NSRange search = NSMakeRange(0, xml.length);
    while (search.length) {
        NSRange hit = [xml rangeOfString:@"<Representation" options:0 range:search];
        if (hit.location == NSNotFound) break;

        _lastDashRepresentations++;
        NSUInteger next = hit.location + hit.length;
        search = NSMakeRange(next, xml.length - next);
    }
}

+ (void)recordButtonMediaClass:(NSString *)className {
    _buttonEverPressed = YES;
    _lastButtonMediaClass = [className copy];
}

+ (void)recordTranscodeStage:(NSString *)name ok:(BOOL)ok detail:(NSString *)detail {
    @synchronized (self) {
        // The first stage of a run starts a clean list.
        if (!_transcodeStages || [name isEqualToString:@"download-video"]) {
            _transcodeStages = [NSMutableArray array];
        }
        NSString *line = [NSString stringWithFormat:@"%@ %@%@",
                          ok ? @"✓" : @"✗", name,
                          detail.length ? [@" — " stringByAppendingString:detail] : @""];
        [_transcodeStages addObject:line];
    }
}

+ (void)recordDateFormatter:(NSString *)formatter sample:(NSString *)sample {
    if (!formatter.length) return;

    // These hooks fire constantly while scrolling, so the work here stays to a
    // counter bump and, for the first few calls only, keeping the text.
    @synchronized (self) {
        if (!_dateFormatterCounts) {
            _dateFormatterCounts = [NSMutableDictionary dictionary];
            _dateFormatterSamples = [NSMutableArray array];
        }

        NSNumber *count = _dateFormatterCounts[formatter];
        _dateFormatterCounts[formatter] = @(count.integerValue + 1);

        if (sample.length && sample.length <= 40 && _dateFormatterSamples.count < 10) {
            NSString *entry = [NSString stringWithFormat:@"%@ → \"%@\"", formatter, sample];
            if (![_dateFormatterSamples containsObject:entry]) {
                [_dateFormatterSamples addObject:entry];
            }
        }
    }
}

+ (void)recordAudioMessageProbe:(BOOL)foundMessage
                       audioURL:(NSString *)url
                   messageClass:(NSString *)className {
    if (url.length) {
        // Only the tail: these URLs are long, signed, and the useful part is
        // simply that one exists.
        NSString *tail = url.length > 60 ? [url substringToIndex:60] : url;
        _audioProbe = [NSString stringWithFormat:@"%@ — audio: %@…", className ?: @"?", tail];
    } else {
        _audioProbe = [NSString stringWithFormat:@"%@ — no audio on this message",
                       foundMessage ? (className ?: @"message") : @"no message found"];
    }
}

+ (void)recordDateHooksInstalled:(NSInteger)count {
    _dateHooksInstalled = count;
}

+ (void)recordReelsGatesForced:(NSInteger)count {
    _reelsGatesForced = count;
}

+ (void)recordReelsProgress:(double)progress total:(double)total from:(NSString *)className {
    @synchronized (self) {
        _reelsProgressCalls++;
        if (progress > _reelsProgressMax) _reelsProgressMax = progress;
        _reelsProgressTotal = total;
        if (className.length) _reelsProgressClass = className;
    }
}

+ (void)recordReelsAdvance:(NSString *)selector foundController:(BOOL)found {
    @synchronized (self) {
        _reelsAdvances++;
        _reelsAdvanceSelector = selector ?: @"(none)";
        _reelsFoundController = found;
    }
}

+ (void)recordUnsendKeptWithReason:(NSInteger)reason messageCount:(NSInteger)count {
    @synchronized (self) {
        _unsendsKept++;
        if (!_unsendReasons) _unsendReasons = [NSMutableArray array];

        NSString *entry = [NSString stringWithFormat:@"reason %ld · %@",
                           (long)reason,
                           count < 0 ? @"ivar not found" : [NSString stringWithFormat:@"%ld message(s)", (long)count]];
        if (![_unsendReasons containsObject:entry] && _unsendReasons.count < 6) {
            [_unsendReasons addObject:entry];
        }
    }
}

+ (void)recordUnsendPath:(NSString *)path detail:(NSString *)detail {
    if (!path.length) return;

    @synchronized (self) {
        if (!_unsendPaths) _unsendPaths = [NSMutableArray array];

        NSString *entry = detail.length ? [NSString stringWithFormat:@"%@ (%@)", path, detail] : path;
        if (![_unsendPaths containsObject:entry] && _unsendPaths.count < 6) {
            [_unsendPaths addObject:entry];
        }
    }
}

+ (void)recordQualityFunnelWithVersions:(NSInteger)versions
                        representations:(NSInteger)representations
                              videoReps:(NSInteger)videoReps
                               saveable:(NSInteger)saveable
                               distinct:(NSInteger)distinct
                           transcodable:(NSInteger)transcodable
                                 chosen:(NSString *)chosen {
    @synchronized (self) {
        _qualityFunnel = [NSString stringWithFormat:
                          @"versions %ld · reps %ld · video %ld · saveable %ld · distinct %ld · transcodable %ld",
                          (long)versions, (long)representations, (long)videoReps,
                          (long)saveable, (long)distinct, (long)transcodable];
        _qualityChosen = [chosen copy];
    }
}

+ (void)recordDateRewrite:(NSString *)original exact:(BOOL)exact {
    @synchronized (self) {
        _dateRewrites++;
        if (exact) _dateRewritesExact++;

        if (!_dateRewriteSamples) _dateRewriteSamples = [NSMutableArray array];
        if (original.length && _dateRewriteSamples.count < 6) {
            NSString *entry = [NSString stringWithFormat:@"\"%@\" — %@",
                               original, exact ? @"exact date" : @"inferred from wording"];
            if (![_dateRewriteSamples containsObject:entry]) [_dateRewriteSamples addObject:entry];
        }
    }
}

+ (void)recordDownloadKind:(NSString *)kind {
    _lastDownloadKind = [kind copy];
}

+ (void)recordSeenReplayBegan:(BOOL)began ended:(BOOL)ended {
    _seenReplay = [NSString stringWithFormat:@"begin=%@  end=%@",
                   began ? @"sent" : @"failed", ended ? @"sent" : @"failed"];
}

+ (void)recordStorySearchRoute:(NSString *)route classes:(NSArray<NSString *> *)classNames {
    _storyRoute = [route copy];

    // Accumulated rather than replaced: a story the search missed and one it found are
    // two taps, and keeping only the last would throw away the report worth reading.
    if (classNames.count) {
        if (!_storyClasses) _storyClasses = [NSMutableArray array];
        for (NSString *name in classNames) {
            if (![_storyClasses containsObject:name]) [_storyClasses addObject:name];
        }
    }
}

+ (void)recordStorySeenIntercept {
    _storySeenIntercepts += 1;
}

+ (void)recordStorySeenHookAttached:(BOOL)attached resolvedTo:(NSString *)runtimeName {
    //
    // **This line named the chokepoint that is missing and said nothing about the one doing the
    // work, so a healthy 410 read as a broken feature.**
    //
    // The receipt is withheld at two places: `IGStorySeenStateUploader -networker`, which both
    // tested builds have, and `IGStoryPendingSeenStateStore -_uploadSeenState:`, which only the
    // newer Swift build has. A device on 410 therefore reports the second as absent -- correctly,
    // and with no consequence, because the first is installed and is what stops the upload there.
    //
    // A report that names an absence without naming the presence beside it is a report that
    // invites a fix for something that is not broken. Both are stated now.
    //
    BOOL uploaderHere = (objc_getClass("IGStorySeenStateUploader") != Nil);
    NSString *uploader = uploaderHere ? @"IGStorySeenStateUploader -networker: installed"
                                      : @"IGStorySeenStateUploader: not in this build";

    NSString *store;
    if (attached && runtimeName.length) {
        store = [NSString stringWithFormat:@"%@ -_uploadSeenState:: installed", runtimeName];
    } else if (runtimeName.length) {
        // The class is here and the method is not. A different failure from the class being
        // absent, needing a different fix, so it is said differently.
        store = [NSString stringWithFormat:@"%@: no -_uploadSeenState: on this build", runtimeName];
    } else {
        store = SCILocalized(@"diag_story_hook_missing");
    }

    _storySeenHook = [NSString stringWithFormat:@"%@ · %@", uploader, store];
    _storySeenAnyHook = uploaderHere || attached;
}

// MARK: - Live hierarchy scan

+ (void)collectCandidatesIn:(UIView *)view into:(NSMutableArray<NSString *> *)out depth:(NSInteger)depth {
    if (!view || depth > 40) return;

    NSInteger controlCount = 0;
    NSMutableArray<NSString *> *identifiers = [NSMutableArray array];

    for (UIView *subview in view.subviews) {
        if (![subview isKindOfClass:[UIControl class]]) continue;
        if (subview.hidden || CGRectIsEmpty(subview.frame)) continue;

        controlCount++;

        if ([subview.accessibilityIdentifier length]) {
            [identifiers addObject:subview.accessibilityIdentifier];
        }
    }

    // A post action row is a short, wide strip holding three or more buttons.
    BOOL looksLikeRow = (controlCount >= 3)
        && (CGRectGetHeight(view.bounds) < 120.0)
        && (CGRectGetWidth(view.bounds) > 180.0);

    // Or anything explicitly labelled with the buttons we care about.
    BOOL hasTellingIdentifier = NO;
    for (NSString *identifier in identifiers) {
        NSString *lower = identifier.lowercaseString;

        if ([lower containsString:@"like"] || [lower containsString:@"save"] || [lower containsString:@"comment"]) {
            hasTellingIdentifier = YES;
            break;
        }
    }

    if (looksLikeRow || hasTellingIdentifier) {
        NSString *entry = [NSString stringWithFormat:@"%@ — %ld controls%@",
                           NSStringFromClass([view class]),
                           (long)controlCount,
                           identifiers.count ? [NSString stringWithFormat:@" [%@]", [identifiers componentsJoinedByString:@", "]] : @""];

        if (![out containsObject:entry]) [out addObject:entry];
    }

    for (UIView *subview in view.subviews) {
        [self collectCandidatesIn:subview into:out depth:depth + 1];
    }
}

/// Does this text read like a timestamp Instagram would render?
/// Matches the compact relative forms ("2h", "5 d", "3w"), the worded ones, and
/// month-name dates. Deliberately loose — a false positive costs one noisy line
/// in a report, a false negative costs a whole round of guessing.
+ (BOOL)looksLikeTimestamp:(NSString *)text {
    if (text.length == 0 || text.length > 40) return NO;

    static NSRegularExpression *pattern = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        //
        // **The scanner did not recognise this tweak's own output, and said "no match" while
        // printing it.**
        //
        // A device report listed `1mo – 01:04:39 AM` and `6d – 06:16:07 PM` among the labels it
        // had found, with 330 exact date swaps recorded above them, and still concluded that
        // nothing matched. The pattern was anchored with `$` after the unit -- written for
        // Instagram's own bare `1mo`, and never revisited when the custom-format feature began
        // appending a time to it. So the one screen meant to prove the feature works was the one
        // screen that could not see it working.
        //
        // The anchor now allows a separator and whatever follows, which still refuses `12.2K`,
        // `185` and `5/6` because none of them is a number followed by a time unit.
        //
        pattern = [NSRegularExpression regularExpressionWithPattern:
                   @"^\\s*\\d+\\s*(s|m|h|d|w|y|mo)\\b\\s*([–—\\-·•|,]\\s*.*)?$"
                   @"|ago|منذ|قبل"
                   @"|^(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)"
                                                            options:NSRegularExpressionCaseInsensitive
                                                              error:nil];
    });

    return [pattern firstMatchInString:text options:0 range:NSMakeRange(0, text.length)] != nil;
}

/// The chain of classes above a view, which is where the model-bearing cell lives.
/// The label itself only holds text; something further up holds the post.
+ (NSString *)ancestryOf:(UIView *)view levels:(NSInteger)levels {
    NSMutableArray<NSString *> *chain = [NSMutableArray array];
    UIView *cursor = view.superview;

    while (cursor && chain.count < (NSUInteger)levels) {
        [chain addObject:NSStringFromClass([cursor class])];
        cursor = cursor.superview;
    }
    return chain.count ? [chain componentsJoinedByString:@" ← "] : @"—";
}

+ (void)collectTimestampsIn:(UIView *)view
                       into:(NSMutableArray<NSString *> *)out
                     sample:(NSMutableArray<NSString *> *)sample
                      depth:(NSInteger)depth {
    // 40, matching the action-row scanner. The first version stopped at 14 and so
    // never reached the feed's labels at all — the scan came back empty not because
    // there was nothing to find but because it never looked deep enough.
    if (!view || depth > 40) return;

    // Not only UILabel: Instagram draws some text in its own classes, and asking
    // whether a view answers -text catches those too.
    NSString *text = nil;
    if ([view respondsToSelector:@selector(text)]) {
        @try {
            id value = [view performSelector:@selector(text)];
            if ([value isKindOfClass:[NSString class]]) text = value;
        } @catch (__unused id e) {}
    }
    if (!text.length) text = view.accessibilityLabel;

    if (text.length) {
        if ([self looksLikeTimestamp:text] && out.count < 10) {
            NSString *entry = [NSString stringWithFormat:@"\"%@\" — %@ ← %@",
                               text,
                               NSStringFromClass([view class]),
                               [self ancestryOf:view levels:3]];
            if (![out containsObject:entry]) [out addObject:entry];
        }
        // Short text is collected regardless so the report can still show what a
        // timestamp reads as when the pattern misses it. The cap was 14 and filled
        // with the stories tray and like counts before the scan ever reached a post
        // header, which is exactly where the timestamp lives.
        else if (text.length <= 24 && sample.count < 60) {
            NSString *entry = [NSString stringWithFormat:@"\"%@\" — %@",
                               text, NSStringFromClass([view class])];
            if (![sample containsObject:entry]) [sample addObject:entry];
        }
    }

    for (UIView *child in view.subviews) {
        [self collectTimestampsIn:child into:out sample:sample depth:depth + 1];
    }
}

+ (NSArray<NSString *> *)scanForTimestampLabels {
    NSMutableArray<NSString *> *out = [NSMutableArray array];
    NSMutableArray<NSString *> *sample = [NSMutableArray array];

    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        // Behind the settings sheet is the feed, which is what we want to read.
        if (window.rootViewController.presentedViewController) {
            [self collectTimestampsIn:window.rootViewController.view into:out sample:sample depth:0];
        } else {
            [self collectTimestampsIn:window into:out sample:sample depth:0];
        }
    }

    if (out.count) return out;

    // Nothing matched the pattern. Rather than report "none found" — which says
    // only that the guess was wrong — hand back what the labels actually say, so
    // the next attempt is aimed at real text instead of another guess.
    NSMutableArray<NSString *> *fallback = [NSMutableArray array];
    [fallback addObject:SCILocalized(@"diag_ts_sample_header")];
    [fallback addObjectsFromArray:sample];
    return fallback;
}

+ (NSArray<NSString *> *)scanForActionRowCandidates {
    NSMutableArray<NSString *> *out = [NSMutableArray array];

    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        // Skip the settings sheet itself — it is full of controls and would drown
        // the result in noise.
        if (window.rootViewController.presentedViewController) {
            [self collectCandidatesIn:window.rootViewController.view into:out depth:0];
        } else {
            [self collectCandidatesIn:window into:out depth:0];
        }
    }

    return out;
}

@end

@implementation SCIDiagnosticsViewController

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = SCILocalized(@"diag_title");
    self.view.tintColor = [SCIUtils SCIColor_Primary];

    self.navigationItem.rightBarButtonItems = @[
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"doc.on.doc"]
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(copyReport)],
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"checklist"]
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(runFeatureAudit)],
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"magnifyingglass"]
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(runScan)],
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"exclamationmark.bubble"]
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(reportIssue)]
    ];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self.tableView reloadData];
}

// MARK: - Report model

/// Classes the inline download button tries to attach to.
- (NSArray<NSString *> *)actionRowCandidates {
    return @[@"IGUFIButtonBarView", @"IGSocialUFIView.IGSocialUFIView", @"IGSocialUFIView.IGSocialUFIButtonView"];
}

- (NSArray<NSDictionary *> *)sections {
    NSMutableArray<NSDictionary *> *rows = [NSMutableArray array];

    // Which action-row classes exist in this build at all.
    for (NSString *name in [self actionRowCandidates]) {
        BOOL exists = (NSClassFromString(name) != nil);

        [rows addObject:@{
            @"title": name,
            @"detail": exists ? SCILocalized(@"diag_class_present") : SCILocalized(@"diag_class_absent"),
            @"ok": @(exists)
        }];
    }

    NSMutableArray<NSDictionary *> *attached = [NSMutableArray array];

    @synchronized (_actionRowClasses) {
        for (NSString *entry in _actionRowClasses) {
            [attached addObject:@{@"title": entry, @"detail": SCILocalized(@"diag_attached"), @"ok": @YES}];
        }
    }

    [attached addObject:@{
        @"title": SCILocalized(@"diag_button_media"),
        @"detail": !_buttonEverPressed ? SCILocalized(@"diag_button_unpressed")
                                       : (_lastButtonMediaClass ?: SCILocalized(@"diag_button_nomedia")),
        @"ok": @(_lastButtonMediaClass != nil)
    }];

    if (attached.count == 1) {
        [attached addObject:@{
            @"title": SCILocalized(@"diag_none_attached"),
            @"detail": SCILocalized(@"diag_none_attached_hint"),
            @"ok": @NO
        }];
    }

    NSString *qualityDetail;
    BOOL qualityOK = NO;

    if (_lastQualityCount < 0) {
        qualityDetail = SCILocalized(@"diag_quality_never");
    }
    else if (_lastQualityCount <= 1) {
        qualityDetail = [NSString stringWithFormat:SCILocalized(@"diag_quality_single"), (long)_lastQualityCount];
    }
    else {
        qualityDetail = [NSString stringWithFormat:SCILocalized(@"diag_quality_multi"), (long)_lastQualityCount];
        qualityOK = YES;
    }

    [rows addObject:@{
        @"title": SCILocalized(@"inline_download_title"),
        @"detail": [SCIUtils getBoolPref:@"inline_download_button"] ? SCILocalized(@"diag_on") : SCILocalized(@"diag_off"),
        @"ok": @([SCIUtils getBoolPref:@"inline_download_button"])
    }];

    return @[
        @{@"header": SCILocalized(@"diag_section_classes"), @"rows": rows},
        @{@"header": SCILocalized(@"diag_section_attached"), @"rows": attached},
        @{@"header": SCILocalized(@"diag_section_quality"), @"rows": @[
            @{@"title": SCILocalized(@"diag_quality_last"), @"detail": qualityDetail, @"ok": @(qualityOK)},
            @{@"title": SCILocalized(@"dw_save_to_camera_title"),
              @"detail": [SCIUtils getBoolPref:@"dw_save_to_camera"] ? SCILocalized(@"diag_on") : SCILocalized(@"diag_off"),
              @"ok": @([SCIUtils getBoolPref:@"dw_save_to_camera"])},
            @{@"title": SCILocalized(@"diag_download_kind"),
              @"detail": _lastDownloadKind ?: @"—",
              @"ok": @(_lastDownloadKind != nil)},
            @{@"title": SCILocalized(@"diag_quality_funnel"),
              @"detail": _qualityFunnel ?: @"—",
              @"ok": @(_qualityFunnel != nil)},
            @{@"title": SCILocalized(@"diag_quality_chosen"),
              @"detail": _qualityChosen ?: @"—",
              @"ok": @(_qualityChosen != nil)},
            @{@"title": SCILocalized(@"diag_quality_source"),
              @"detail": _lastVideoClass ?: @"—",
              @"ok": @(_lastVideoClass != nil)}
        ]},
        @{@"header": SCILocalized(@"diag_section_story"), @"rows": @[
            @{@"title": SCILocalized(@"diag_story_route"),
              @"detail": _storyRoute ?: @"\u2014",
              @"ok": @(_storyRoute != nil)},
            @{@"title": SCILocalized(@"diag_story_classes"),
              @"detail": (_storyClasses.count
                          ? [_storyClasses componentsJoinedByString:@"\n"]
                          : SCILocalized(@"diag_story_classes_none")),
              @"ok": @(_storyClasses.count > 0)}
        ]},
        @{@"header": SCILocalized(@"diag_section_dash"), @"rows": [self dashRows]},
        @{@"header": SCILocalized(@"diag_section_transcode"), @"rows": [self transcodeRows]},
        @{@"header": SCILocalized(@"diag_section_scan"), @"rows": [self scanRows]},
        @{@"header": SCILocalized(@"diag_section_audit"), @"rows": [self featureAuditRows]},
        @{@"header": SCILocalized(@"diag_section_reels"), @"rows": [self reelsAutoScrollRows]},
        @{@"header": SCILocalized(@"diag_section_titles"), @"rows": [self titleMatchRows]},
        @{@"header": SCILocalized(@"diag_section_daterewrite"), @"rows": [self dateRewriteRows]},
        @{@"header": SCILocalized(@"diag_section_audio"), @"rows": [self audioRows]},
        @{@"header": SCILocalized(@"diag_section_dateformat"), @"rows": [self dateFormatterRows]},
        @{@"header": SCILocalized(@"diag_section_timestamps"), @"rows": [self timestampRows]},
        @{@"header": SCILocalized(@"diag_section_stories"), @"rows": @[
            @{@"title": SCILocalized(@"diag_seen_replay"),
              @"detail": _seenReplay ?: @"—",
              @"ok": @(_seenReplay != nil)},
            @{@"title": SCILocalized(@"diag_story_intercepts"),
              @"detail": [NSString stringWithFormat:@"%ld", (long)_storySeenIntercepts],
              @"ok": @(_storySeenIntercepts > 0)},
            @{@"title": SCILocalized(@"diag_story_hook"),
              @"detail": _storySeenHook ?: @"—",
              // Green when *either* chokepoint is installed. Judging this by the newer build's
              // store alone marked a perfectly working 410 as a fault.
              @"ok": @(_storySeenAnyHook)}
        ]},
        @{@"header": SCILocalized(@"diag_section_env"), @"rows": @[
            // What the panel's switch is doing in this app, and how that was decided.
            //
            // "the switch does nothing" has several explanations that look identical from
            // in here -- never written, written where this process cannot see it, or read
            // correctly and set to on -- and they need different fixes.
            @{@"title": SCILocalized(@"diag_panel_switch"),
              @"detail": SCIPanelGateReport(),
              @"ok": @YES},
            @{@"title": @"Albrhi", @"detail": SCIVersionString, @"ok": @YES},
            @{@"title": @"Instagram", @"detail": [SCIUtils IGVersionString], @"ok": @YES},
            @{@"title": @"iOS", @"detail": [[UIDevice currentDevice] systemVersion], @"ok": @YES}
        ]}
    ];
}

- (NSArray<NSDictionary *> *)dashRows {
    if (!_dashProbeRan) {
        return @[@{@"title": SCILocalized(@"diag_dash_none"),
                   @"detail": SCILocalized(@"diag_dash_hint"),
                   @"ok": @NO}];
    }

    NSMutableArray<NSDictionary *> *rows = [NSMutableArray array];

    // Distinct from "never ran": the probe reached these objects and they had
    // nothing. Which candidates the runtime offered decides what happens next.
    if (!_lastDashXML) {
        [rows addObject:@{@"title": SCILocalized(@"diag_dash_empty"),
                          @"detail": SCILocalized(@"diag_dash_empty_hint"),
                          @"ok": @NO}];
    }

    [rows addObject:@{@"title": SCILocalized(@"diag_dash_candidates"),
                      @"detail": _lastDashCandidates.count
                          ? [_lastDashCandidates componentsJoinedByString:@", "]
                          : SCILocalized(@"diag_dash_no_candidates"),
                      @"ok": @(_lastDashCandidates.count > 0)}];

    if (!_lastDashXML) return rows;

    [rows addObject:@{@"title": SCILocalized(@"diag_dash_found"),
                      @"detail": [NSString stringWithFormat:@"%lu B", (unsigned long)_lastDashXML.length],
                      @"ok": @YES}];

    // Set against the quality count above, this is the whole question: a larger
    // number here is the ladder -videoVersions has been hiding.
    [rows addObject:@{@"title": SCILocalized(@"diag_dash_reps"),
                      @"detail": [NSString stringWithFormat:@"%ld", (long)_lastDashRepresentations],
                      @"ok": @(_lastDashRepresentations > 0)}];

    // The ladder tagged by codec is what decides which phase applies: an H.264 or
    // HEVC video rep higher than 720p is a free win phase one already takes; an
    // AV1-only ladder is what phase two's transcoder exists for.
    NSInteger saveable = 0;
    for (NSDictionary *rep in [SCIUtils dashRepresentationsFromXML:_lastDashXML]) {
        if (![rep[@"type"] isEqualToString:@"video"]) continue;

        NSString *family = rep[@"family"];
        BOOL ok = [family isEqualToString:@"h264"] || [family isEqualToString:@"hevc"];
        if (ok) saveable++;

        [rows addObject:@{
            @"title": [NSString stringWithFormat:@"%@×%@",
                       rep[@"width"], rep[@"height"]],
            @"detail": [NSString stringWithFormat:@"%@ · %.1f Mbps%@",
                        [family length] ? family : rep[@"codecs"],
                        [rep[@"bandwidth"] doubleValue] / 1000000.0,
                        ok ? @"" : SCILocalized(@"diag_dash_needs_transcode")],
            @"ok": @(ok)
        }];
    }

    [rows addObject:@{@"title": SCILocalized(@"diag_dash_saveable"),
                      @"detail": [NSString stringWithFormat:@"%ld", (long)saveable],
                      @"ok": @(saveable > 0)}];

    // Enough of the XML to confirm on screen that it is a real manifest. The
    // full text goes into the copied report instead: these cells self-size, and
    // a manifest pasted whole would push everything below it off the page.
    NSUInteger excerptLength = MIN((NSUInteger)180, _lastDashXML.length);
    NSString *excerpt = [_lastDashXML substringToIndex:excerptLength];

    [rows addObject:@{@"title": SCILocalized(@"diag_dash_excerpt"),
                      @"detail": excerpt,
                      @"ok": @YES}];

    return rows;
}

- (NSArray<NSDictionary *> *)transcodeRows {
    @synchronized ([SCIDiagnostics class]) {
        if (!_transcodeStages.count) {
            return @[@{@"title": SCILocalized(@"diag_transcode_none"),
                       @"detail": SCILocalized(@"diag_transcode_hint"),
                       @"ok": @NO}];
        }

        NSMutableArray<NSDictionary *> *rows = [NSMutableArray array];
        for (NSString *line in _transcodeStages) {
            [rows addObject:@{@"title": line,
                              @"detail": @"",
                              @"ok": @([line hasPrefix:@"✓"])}];
        }
        return rows;
    }
}

- (NSArray<NSDictionary *> *)scanRows {
    if (!_scanResults) {
        return @[@{@"title": SCILocalized(@"diag_scan_prompt"),
                   @"detail": SCILocalized(@"diag_scan_hint"),
                   @"ok": @NO}];
    }

    if (!_scanResults.count) {
        return @[@{@"title": SCILocalized(@"diag_scan_empty"),
                   @"detail": SCILocalized(@"diag_scan_hint"),
                   @"ok": @NO}];
    }

    NSMutableArray<NSDictionary *> *rows = [NSMutableArray array];
    for (NSString *entry in _scanResults) {
        [rows addObject:@{@"title": entry, @"detail": @"", @"ok": @YES}];
    }

    return rows;
}

// MARK: - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self sections].count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[self sections][section][@"rows"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [self sections][section][@"header"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];

    NSDictionary *row = [self sections][indexPath.section][@"rows"][indexPath.row];

    UIListContentConfiguration *config = [UIListContentConfiguration subtitleCellConfiguration];
    config.text = row[@"title"];
    config.secondaryText = row[@"detail"];
    config.textProperties.font = [UIFont monospacedSystemFontOfSize:13.0 weight:UIFontWeightRegular];
    config.secondaryTextProperties.color = [UIColor secondaryLabelColor];

    BOOL ok = [row[@"ok"] boolValue];
    config.image = [UIImage systemImageNamed:ok ? @"checkmark.circle.fill" : @"exclamationmark.circle.fill"];
    config.imageProperties.tintColor = ok ? [UIColor systemGreenColor] : [UIColor systemOrangeColor];

    cell.contentConfiguration = config;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    return cell;
}

/// Asks the runtime whether each feature's target is still here. Cheap enough to run
/// on a tap: it looks classes and methods up, and calls none of them.
- (void)runFeatureAudit {
    _auditResults = [SCIFeatureAudit run];

    [[[UINotificationFeedbackGenerator alloc] init] notificationOccurred:UINotificationFeedbackTypeSuccess];
    [self.tableView reloadData];
}

- (void)runScan {
    _scanResults = [SCIDiagnostics scanForActionRowCandidates];
    _timestampResults = [SCIDiagnostics scanForTimestampLabels];

    [[[UINotificationFeedbackGenerator alloc] init] notificationOccurred:UINotificationFeedbackTypeSuccess];
    [self.tableView reloadData];
}

- (NSArray<NSDictionary *> *)audioRows {
    @synchronized ([SCIDiagnostics class]) {
        if (!_audioProbe.length) {
            return @[@{@"title": SCILocalized(@"diag_audio_none"),
                       @"detail": SCILocalized(@"diag_audio_hint"),
                       @"ok": @NO}];
        }
        return @[@{@"title": _audioProbe, @"detail": @"", @"ok": @YES}];
    }
}

- (NSArray<NSDictionary *> *)featureAuditRows {
    if (!_auditResults) {
        return @[@{@"title": SCILocalized(@"audit_prompt"),
                   @"detail": SCILocalized(@"audit_hint"),
                   @"ok": @YES}];
    }

    NSMutableArray<NSDictionary *> *rows = [NSMutableArray array];

    [rows addObject:@{@"title": SCILocalized(@"audit_result_title"),
                      @"detail": [SCIFeatureAudit summaryForResults:_auditResults],
                      @"ok": @YES}];

    // Anything still attached is the uninteresting case, so the ones that are not
    // come first — those are the features an Instagram update has quietly broken.
    NSMutableArray<NSDictionary *> *missing = [NSMutableArray array];
    NSMutableArray<NSDictionary *> *present = [NSMutableArray array];

    for (SCIFeatureAuditResult *result in _auditResults) {
        NSDictionary *row = @{@"title": result.feature,
                              @"detail": result.detail ?: @"—",
                              @"ok": @(result.attached)};
        [(result.attached ? present : missing) addObject:row];
    }

    [rows addObjectsFromArray:missing];
    [rows addObjectsFromArray:present];

    return rows;
}

- (NSArray<NSDictionary *> *)reelsAutoScrollRows {
    @synchronized ([SCIDiagnostics class]) {
        NSMutableArray<NSDictionary *> *rows = [NSMutableArray array];

        [rows addObject:@{@"title": SCILocalized(@"diag_reels_gates"),
                          @"detail": _reelsGatesForced < 0 ? @"—"
                                     : [NSString stringWithFormat:@"%ld", (long)_reelsGatesForced],
                          @"ok": @(_reelsGatesForced > 0)}];

        // Whether the progress indicator reports at all, and how far it gets. A max
        // that never approaches the end means the trigger threshold can never be met.
        [rows addObject:@{@"title": SCILocalized(@"diag_reels_progress"),
                          @"detail": _reelsProgressCalls == 0 ? @"0"
                                     : [NSString stringWithFormat:@"%ld · max %.3f · %.1fs · %@",
                                        (long)_reelsProgressCalls, _reelsProgressMax, _reelsProgressTotal,
                                        _reelsProgressClass ?: @"—"],
                          @"ok": @(_reelsProgressCalls > 0)}];

        [rows addObject:@{@"title": SCILocalized(@"diag_unsend_paths"),
                          @"detail": _unsendPaths.count ? [_unsendPaths componentsJoinedByString:@", "] : @"—",
                          @"ok": @(_unsendPaths.count > 0)}];

        [rows addObject:@{@"title": SCILocalized(@"diag_unsend_kept"),
                          @"detail": _unsendsKept == 0 ? @"0"
                                     : [NSString stringWithFormat:@"%ld · %@", (long)_unsendsKept,
                                        [_unsendReasons componentsJoinedByString:@", "]],
                          @"ok": @(_unsendsKept > 0)}];

        [rows addObject:@{@"title": SCILocalized(@"diag_reels_advance"),
                          @"detail": _reelsAdvances == 0 ? @"0"
                                     : [NSString stringWithFormat:@"%ld · %@ · vc %@",
                                        (long)_reelsAdvances, _reelsAdvanceSelector ?: @"—",
                                        _reelsFoundController ? @"yes" : @"no"],
                          @"ok": @(_reelsAdvances > 0 && _reelsFoundController)}];

        return rows;
    }
}

- (NSArray<NSDictionary *> *)dateRewriteRows {
    @synchronized ([SCIDiagnostics class]) {
        NSMutableArray<NSDictionary *> *rows = [NSMutableArray array];

        // The attach count answers "is this even possible on this build" before
        // any question about whether the format looks right.
        [rows addObject:@{@"title": SCILocalized(@"diag_dr_hooks"),
                          @"detail": _dateHooksInstalled < 0 ? @"—"
                                     : [NSString stringWithFormat:@"%ld", (long)_dateHooksInstalled],
                          @"ok": @(_dateHooksInstalled > 0)}];

        if (_dateRewrites == 0) {
            [rows addObject:@{@"title": SCILocalized(@"diag_dr_none"),
                              @"detail": SCILocalized(@"diag_dr_hint"),
                              @"ok": @NO}];
            return rows;
        }

        [rows addObject:@{@"title": SCILocalized(@"diag_dr_count"),
                          @"detail": [NSString stringWithFormat:@"%ld (%ld exact)",
                                      (long)_dateRewrites, (long)_dateRewritesExact],
                          @"ok": @YES}];
        for (NSString *sample in _dateRewriteSamples) {
            [rows addObject:@{@"title": sample, @"detail": @"", @"ok": @YES}];
        }
        return rows;
    }
}

- (NSArray<NSDictionary *> *)dateFormatterRows {
    @synchronized ([SCIDiagnostics class]) {
        if (!_dateFormatterCounts.count) {
            return @[@{@"title": SCILocalized(@"diag_df_none"),
                       @"detail": SCILocalized(@"diag_df_hint"),
                       @"ok": @NO}];
        }

        NSMutableArray<NSDictionary *> *rows = [NSMutableArray array];

        // The count is the answer: a formatter Instagram never calls cannot carry
        // the custom format, however plausible it looked.
        for (NSString *name in [_dateFormatterCounts.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            [rows addObject:@{@"title": name,
                              @"detail": [NSString stringWithFormat:@"%@ calls", _dateFormatterCounts[name]],
                              @"ok": @YES}];
        }
        for (NSString *sample in _dateFormatterSamples) {
            [rows addObject:@{@"title": sample, @"detail": @"", @"ok": @YES}];
        }
        return rows;
    }
}

- (NSArray<NSDictionary *> *)timestampRows {
    if (!_timestampResults) {
        return @[@{@"title": SCILocalized(@"diag_ts_prompt"),
                   @"detail": SCILocalized(@"diag_scan_hint"),
                   @"ok": @NO}];
    }
    if (!_timestampResults.count) {
        return @[@{@"title": SCILocalized(@"diag_ts_empty"),
                   @"detail": SCILocalized(@"diag_ts_hint"),
                   @"ok": @NO}];
    }

    NSMutableArray<NSDictionary *> *rows = [NSMutableArray array];
    for (NSString *entry in _timestampResults) {
        [rows addObject:@{@"title": entry, @"detail": @"", @"ok": @YES}];
    }
    return rows;
}

// MARK: - Report

/// The diagnostics report as plain text. Shared by the copy button and the issue
/// reporter, so a filed bug always carries exactly what the page shows.
///
/// The surfaces that recognise a row by the English words printed on it.
///
/// Thirteen comparisons here match a title against an English literal, inherited from
/// SCInsta -- and Instagram translates those titles, so on a phone that is not in English
/// none of them ever matches and the switch looks broken rather than inapplicable. There is
/// no confirmed identifier on these view models to match instead, so rather than guess one
/// or delete a feature that works for somebody, the counts are shown: `12 seen, 0 matched`
/// under a line naming the app's own language says exactly what is happening.
- (NSArray *)titleMatchRows {
    NSMutableArray *rows = [NSMutableArray array];
    for (NSString *line in SCIEnglishTitleReport()) {
        [rows addObject:@{@"title": @"", @"detail": line, @"ok": @YES}];
    }
    return rows;
}

- (NSString *)reportText {
    NSMutableString *report = [NSMutableString stringWithFormat:@"Albrhi %@ diagnostics\n", SCIVersionString];

    for (NSDictionary *section in [self sections]) {
        [report appendFormat:@"\n[%@]\n", section[@"header"]];

        for (NSDictionary *row in section[@"rows"]) {
            [report appendFormat:@"  %@: %@\n", row[@"title"], row[@"detail"]];
        }
    }

    // Verbatim, and last so it never buries the rest. The point of capturing a
    // manifest is to read its real attribute names; an excerpt cannot show the
    // full rendition ladder, which is the number that decides whether parsing
    // DASH gains anything over -videoVersions.
    if (_lastDashXML.length) {
        [report appendFormat:@"\n[DASH manifest — verbatim]\n%@\n", _lastDashXML];
    }

    return [report copy];
}

- (void)copyReport {
    [UIPasteboard generalPasteboard].string = [self reportText];

    [[[UINotificationFeedbackGenerator alloc] init] notificationOccurred:UINotificationFeedbackTypeSuccess];
    [SCIUtils showToastForDuration:1.6 title:SCILocalized(@"diag_copied")];
}

/// Opens a new GitHub issue with the report already filled in.
///
/// A tester who hits a problem otherwise has nowhere to go, and "it doesn't work"
/// costs a round trip to turn into something actionable. This makes the useful
/// version of the report the path of least resistance.
- (void)reportIssue {
    // Built line by line rather than as one format string: the report is fenced as a
    // code block so GitHub renders it verbatim.
    NSMutableString *body = [NSMutableString string];
    [body appendFormat:@"%@\n\n", SCILocalized(@"diag_issue_what")];
    [body appendFormat:@"%@\n\n", SCILocalized(@"diag_issue_steps")];
    [body appendFormat:@"```\n%@\n```\n", [self reportText]];

    NSCharacterSet *allowed = [NSCharacterSet URLQueryAllowedCharacterSet];
    NSString *encodedBody = [body stringByAddingPercentEncodingWithAllowedCharacters:allowed];
    NSString *encodedTitle = [[NSString stringWithFormat:@"[%@] ", SCIVersionString]
                              stringByAddingPercentEncodingWithAllowedCharacters:allowed];

    NSString *urlString = [NSString stringWithFormat:@"%@?title=%@&body=%@",
                           SCIIssuesURL, encodedTitle, encodedBody];

    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) return;

    // The report is also on the clipboard, in case the browser truncates the URL.
    [UIPasteboard generalPasteboard].string = [self reportText];

    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

@end
