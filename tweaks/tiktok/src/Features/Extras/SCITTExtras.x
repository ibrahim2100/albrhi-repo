//
//  SCITTExtras.x
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "SCITTExtras.h"
#import "../../Prefs.h"
#import "../../Diagnostics/SCITTDiagnostics.h"
#import "../../SCILog.h"
#import "../../Localization/SCILocalize.h"
#import "../Messages/SCITTRecalledStore.h"

///
/// **Where these came from, and what was measured before any of it was written.**
///
/// The three features exist in VibeTok, which is unlicensed and is read here for architecture only
/// -- never for code, the same line this project keeps for every unlicensed TikTok reference. What
/// its hook table gave was a list of *places to look*, and every one of them was then confirmed
/// against the real binary with tools/objc-classes.py before a line was written.
///
/// **That confirmation immediately corrected it.** VibeTok hooks `-isRecalled` on `TIMOMessage`;
/// **that selector does not exist in 46.4.0 at all** -- the property is `recalled` and its getter is
/// `-recalled`. A reference's selector is what worked for its author, not what is in front of you,
/// which is a rule this project has already paid for twice with `downloadAddr` and
/// `bestURLtoDownload`.
///
/// Confirmed on 46.4.0, and again on 45.7.0, so these are stable across two builds rather than
/// true of one:
///
///     AWEUserService              -maxLoginedAccounts        Q16@0:8
///     TIMOMessage                 -recalled                  B16@0:8
///     TTKProfileViewsPresenter    -model                     @16@0:8   (NSMutableArray)
///

@interface AWEUserService : NSObject
@end

@interface TIMOMessage : NSObject
@end

@interface TTKProfileViewsPresenter : NSObject
@end

/// 47.1.0 draws a direct text message in `AWEIMTextMessageCellView` (a view, not a table cell: `AWEIMTextMessageTableViewCell` is not in that
/// build), whose bubble is a `CAShapeLayer` filled by `-p_setBubbleLayerColor`. `-message` and `-cellViewModel` come from its base class
/// `AWEIMMessageBaseCellView`; `AWEIMMessage -serverMessageID` is a `long long`, the same id `TIMOMessage` carries as an `NSNumber`.
@interface AWEIMMessage : NSObject
- (long long)serverMessageID;
@end

@interface AWEIMTextMessageCellView : UIView
- (id)message;
- (id)cellViewModel;
- (CAShapeLayer *)bubbleLayer;
// Added by the hook below (`%property` / `%new`), declared so the hook body can send them.
@property (nonatomic, strong) id albrhiTintOriginal;
- (void)albrhiSyncRecalledTint;
@end

static NSString *sciExtrasState = nil;
static NSUInteger sciVisitorsSeen = 0;

/// The messages whose sender took them back, by `serverMessageID` -- **kept in a file now** (`SCITTRecalledStore`, 0.29.0), so a message
/// stays visible, and stays marked, across launches and not only for the one in which the recall arrived.
///
/// **The hook that hides the recall is also the only thing that knows one happened.** `%orig` answers YES a moment before Albrhi answers NO, so the
/// fact is there to be kept rather than swallowed -- and keeping it is what lets the message be *marked* instead of quietly restored.
/// A message shown as though nothing happened is the tweak deciding something on the reader's behalf without saying so, which is the same
/// objection this project raised about a watch being told it was up to date.
static BOOL sciBubbleTintInstalled = NO;
static NSUInteger sciRecalledSeen = 0, sciRecalledStored = 0, sciTintApplied = 0, sciTintRestored = 0;
static NSString *sciTintState = nil;

/// What the content dictionary turned out to hold, recorded once, and which key was marked.
static NSString *sciContentKeys = nil;
static NSString *sciMarkedKey = nil;
static NSUInteger sciMarkedCount = 0;

/// Where the visitor log lives. TikTok's own defaults, because this runs inside TikTok and the log
/// is only ever read there and by Albrhi's own screen inside the same process.
static NSString *const kSCITTVisitorKey = @"albrhi_tt_visitors";

static BOOL SCITTEncodingMatches(Class cls, NSString *selectorName, NSString *expected) {
    Method method = class_getInstanceMethod(cls, NSSelectorFromString(selectorName));
    if (!method) return NO;

    const char *types = method_getTypeEncoding(method);
    return types && [expected isEqualToString:[NSString stringWithUTF8String:types]];
}

#pragma mark - The account limit

%group SCITTAccounts

%hook AWEUserService

- (unsigned long long)maxLoginedAccounts {
    if (!SCIPrefEnabled(SCIPrefUnlimitedAccounts)) return %orig;

    // Raised, not removed: the app asks how many are allowed and something downstream will size a
    // list from the answer. A number it can hold is a different thing from no answer at all.
    return 99;
}

%end
%end

#pragma mark - A message the sender took back

%group SCITTKeepRecalled

%hook TIMOMessage

- (BOOL)recalled {
    // Called once, on its own line, and the answer reused. `if (%orig)` shares its line with a
    // brace, which this Logos version cannot expand -- check.py caught it here, in code written by
    // the same hand that added the rule two days ago.
    BOOL recalled = %orig;

    if (!SCIPrefEnabled(SCIPrefKeepRecalled)) return recalled;

    if (recalled) {
        // Remembered before it is answered away -- by id only: this getter is asked constantly, and reading the content from here would
        // run the content hook below on every call. The content is taken where the recall is *set* (`-setRecalled:`), once.
        id identifier = [self respondsToSelector:@selector(serverMessageID)]
            ? ((id (*)(id, SEL))objc_msgSend)(self, @selector(serverMessageID)) : nil;
        if ([[SCITTRecalledStore shared] track:identifier content:nil]) sciRecalledSeen++;
    }

    // The message is still here: TikTok received it, then received an instruction to hide it, and
    // hiding is done by the client. Nothing is fetched back from a server -- what is refused is the
    // instruction to stop showing what already arrived.
    return NO;
}

%end
%end

/// **The setter, as well as the getter** -- the lesson written down twice already (`-bypassOnesie`, `AWEAwemeACLItem.watermarkType`): code that
/// reads the ivar directly never passes through a getter hook, while a stored value is true for every reader. This is also the one moment the
/// message still has its own content: it is read here, kept, and only then is NO stored in place of YES.
%group SCITTKeepRecalledSetter

%hook TIMOMessage

- (void)setRecalled:(BOOL)recalled {
    if (!recalled || !SCIPrefEnabled(SCIPrefKeepRecalled)) {
        %orig;
        return;
    }

    id identifier = [self respondsToSelector:@selector(serverMessageID)]
        ? ((id (*)(id, SEL))objc_msgSend)(self, @selector(serverMessageID)) : nil;
    id content = [self respondsToSelector:@selector(content)]
        ? ((id (*)(id, SEL))objc_msgSend)(self, @selector(content)) : nil;
    if ([[SCITTRecalledStore shared] track:identifier content:content]) sciRecalledSeen++;
    if ([[SCITTRecalledStore shared] contentFor:identifier]) sciRecalledStored++;

    %orig(NO);
}

%end
%end

#pragma mark - Saying which ones were taken back

%group SCITTMarkRecalled

%hook TIMOMessage

- (id)content {
    id content = %orig;

    if (!SCIPrefEnabled(SCIPrefKeepRecalled)) return content;

    id identifier = [self respondsToSelector:@selector(serverMessageID)]
        ? ((id (*)(id, SEL))objc_msgSend)(self, @selector(serverMessageID)) : nil;
    if (!identifier || ![[SCITTRecalledStore shared] isTracked:identifier]) return content;

    // What TikTok left of the message after the recall is not what was said. The content kept when the recall arrived is, so it is handed back
    // (a copy of TikTok's own dictionary is never written through, and nothing is stored back into it).
    id kept = [[SCITTRecalledStore shared] contentFor:identifier];
    if ([kept isKindOfClass:[NSDictionary class]]) content = kept;

    // The bubble is tinted (SCITTRecalledBubble below) and that is the mark. Only where it could not be installed does the text itself carry one.
    if (sciBubbleTintInstalled) return content;
    if (![content isKindOfClass:[NSDictionary class]]) return content;

    // Recorded once, so the next release can name the key instead of matching a shape.
    if (!sciContentKeys) {
        sciContentKeys = [[(NSDictionary *)content allKeys] componentsJoinedByString:@", "];
    }

    //
    // **`text` is the key, confirmed on a device rather than matched by shape** (0.19.x: `marked: 1 via key text`), and a shape rule stays
    // underneath it as the fallback for a build that renames it: the first key whose own name contains "text", carrying a string. If nothing
    // matches, **nothing is marked** and the report carries every key there was -- an honest miss that names the fix.
    //
    NSMutableDictionary *marked = [NSMutableDictionary dictionaryWithDictionary:content];
    NSString *badge = SCILocalized(@"recalled_badge");

    NSString *known = content[@"text"];
    if ([known isKindOfClass:[NSString class]]) {
        if ([known hasPrefix:badge]) return content;
        marked[@"text"] = [badge stringByAppendingString:known];
        sciMarkedKey = @"text";
        sciMarkedCount++;
        return marked;
    }

    for (NSString *key in [(NSDictionary *)content allKeys]) {
        if (![key isKindOfClass:[NSString class]]) continue;
        if ([key rangeOfString:@"text" options:NSCaseInsensitiveSearch].location == NSNotFound) continue;

        NSString *value = content[key];
        if (![value isKindOfClass:[NSString class]]) continue;
        if ([value hasPrefix:badge]) return content;   // already marked: idempotent by content

        marked[key] = [badge stringByAppendingString:value];
        sciMarkedKey = key;
        sciMarkedCount++;
        return marked;
    }
    return content;
}

%end
%end

#pragma mark - Tinting the bubble of a message that was taken back

/// **The mark is the bubble's colour, and the first thing every redraw does is ask whether this is still the right message.** A cell is reused
/// (CLAUDE.md 4.5: a recycled cell is never removed from its window), so a tint put on a bubble and never taken off would follow the cell to
/// the next message it shows. The colour the app had is kept on the cell (`albrhiTintOriginal`) and put back whenever the message in it is not a
/// recalled one. Two doors, both confirmed on 47.1.0: the app's own colour write (`-p_setBubbleLayerColor`, which also means the colour just
/// written is the new original) and the bind that fills a reused cell (`-p_configWithCellViewModel:oldCellViewModel:`).
///
/// **Not seen on a screen:** a direct message needs an account, which the simulator copy does not have. A custom chat wallpaper draws the
/// bubble as an image (`bubbleImageView`) and a gradient bubble draws over the shape; those are not tinted.
%group SCITTRecalledBubble

%hook AWEIMTextMessageCellView

%property (nonatomic, strong) id albrhiTintOriginal;

%new(v@:)
- (void)albrhiSyncRecalledTint {
    BOOL recalled = NO;
    if (SCIPrefEnabled(SCIPrefKeepRecalled)) {
        id message = [self message] ?: [[self cellViewModel] message];
        if ([message respondsToSelector:@selector(serverMessageID)]) {
            recalled = [[SCITTRecalledStore shared] isTracked:@([(AWEIMMessage *)message serverMessageID])];
        }
    }

    CAShapeLayer *layer = [self bubbleLayer];
    if (![layer isKindOfClass:[CAShapeLayer class]]) return;

    if (recalled) {
        if (!self.albrhiTintOriginal) self.albrhiTintOriginal = layer.fillColor ? (__bridge id)layer.fillColor : (id)[NSNull null];
        layer.fillColor = [UIColor colorWithRed:0.93 green:0.30 blue:0.32 alpha:0.9].CGColor;
        sciTintApplied++;
    } else if (self.albrhiTintOriginal) {
        id original = self.albrhiTintOriginal;
        layer.fillColor = [original isKindOfClass:[NSNull class]] ? NULL : (__bridge CGColorRef)original;
        self.albrhiTintOriginal = nil;
        sciTintRestored++;
    }
}

- (void)p_setBubbleLayerColor {
    %orig;
    // The app has just written the real colour: whatever was remembered as "the original" is stale.
    self.albrhiTintOriginal = nil;
    [self albrhiSyncRecalledTint];
}

- (void)p_configWithCellViewModel:(id)viewModel oldCellViewModel:(id)oldViewModel {
    %orig;
    [self albrhiSyncRecalledTint];
}

%end
%end

#pragma mark - Who looked at the profile

%group SCITTVisitors

%hook TTKProfileViewsPresenter

- (id)model {
    id visitors = %orig;
    if (!SCIPrefEnabled(SCIPrefVisitorLog)) return visitors;

    //
    // **Recorded as they arrive, and never merged back into TikTok's own list.**
    //
    // The reference keeps its cache and hands a combined array back to the app, which is what makes
    // somebody who has since blocked you still appear in TikTok's own screen. That is not done
    // here: feeding objects the app did not create back into a list it is about to render is the
    // same shape of thing that crashed the Watch app -- a view told an item exists and reading
    // something out of it. Albrhi keeps its own record and shows it on its own screen instead.
    //
    // The effect a person actually asked for survives that: a visitor seen once is remembered, so a
    // block afterwards does not erase what was already delivered.
    //
    if (![visitors isKindOfClass:[NSArray class]] || ![visitors count]) return visitors;

    NSMutableArray *log = [NSMutableArray arrayWithArray:
        [[NSUserDefaults standardUserDefaults] arrayForKey:kSCITTVisitorKey] ?: @[]];

    for (id entry in (NSArray *)visitors) {
        // Only a description is kept -- a name and the moment it was seen. Holding TikTok's own
        // objects would keep them alive past the screen that made them, and a tweak that changes an
        // app's object lifetimes has stopped being an observer.
        NSString *name = [entry respondsToSelector:@selector(nickname)]
            ? [entry performSelector:@selector(nickname)] : nil;
        if (![name isKindOfClass:[NSString class]] || !name.length) continue;

        if ([log.firstObject isEqualToString:name]) continue;
        [log removeObject:name];
        [log insertObject:name atIndex:0];
        sciVisitorsSeen++;
    }

    // Bounded, because a log that grows without limit inside somebody's app is the thing this
    // project switched off in Albrhi NextUp.
    while (log.count > 200) [log removeLastObject];

    [[NSUserDefaults standardUserDefaults] setObject:log forKey:kSCITTVisitorKey];
    return visitors;
}

%end
%end

#pragma mark - Installation

NSArray<NSString *> *SCITTVisitorLog(void) {
    return [[NSUserDefaults standardUserDefaults] arrayForKey:kSCITTVisitorKey] ?: @[];
}

NSString *SCITTExtrasReport(void) {
    return [NSString stringWithFormat:
            @"%@; visitors remembered: %lu (%lu seen this launch); recalled messages kept in the file: %lu (new this launch %lu, with content %lu), marked by text: %lu%@%@; bubble tint: %@ (applied %lu, put back %lu)",
            sciExtrasState ?: @"not installed",
            (unsigned long)SCITTVisitorLog().count, (unsigned long)sciVisitorsSeen,
            (unsigned long)[SCITTRecalledStore shared].count, (unsigned long)sciRecalledSeen, (unsigned long)sciRecalledStored,
            (unsigned long)sciMarkedCount,
            sciMarkedKey ? [@" via key " stringByAppendingString:sciMarkedKey] : @"",
            sciContentKeys ? [@"; content keys: " stringByAppendingString:sciContentKeys] : @"",
            sciTintState ?: @"not installed", (unsigned long)sciTintApplied, (unsigned long)sciTintRestored];
}

//
// **Never reported as online.**
//
// Confirmed against this device's own 46.4.0 binary rather than against a reference tweak's list:
// four chokepoints on `AWEIMActivityStatusReportManager`, each with its encoding read before a hook
// was written. The two `-p_report…` calls are where a status actually leaves the phone; the two
// booleans above them are what decides whether it is worth sending. Refusing all four is the
// difference between "the report was suppressed once" and "there is nothing to suppress".
//
// This is the same shape as the three privacy switches already here: **a report is withheld from
// leaving the device, and the server is never told anything untrue.** Nothing here claims to be
// offline; it simply stops announcing.
//
%group SCITTHideOnline

%hook AWEIMActivityStatusReportManager

- (BOOL)p_enableReportOnlineStatus {
    if (!SCIPrefEnabled(SCIPrefHideOnline)) return %orig;
    return NO;
}

- (BOOL)canFetchAsReportCurrentUserActivityStatus {
    if (!SCIPrefEnabled(SCIPrefHideOnline)) return %orig;
    return NO;
}

- (void)p_reportActivityStatusIfNeededWithParams:(id)params {
    if (!SCIPrefEnabled(SCIPrefHideOnline)) {
        %orig;
        return;
    }
    [SCITTDiagnostics recordPrivacyAnswer:@"online status withheld (if-needed)"];
}

- (void)p_reportActivityStatusWithParams:(id)params {
    if (!SCIPrefEnabled(SCIPrefHideOnline)) {
        %orig;
        return;
    }
    [SCITTDiagnostics recordPrivacyAnswer:@"online status withheld"];
}

%end

%end

//
// **A video that has finished does not start again — and the first attempt hooked the wrong thing.**
//
// 0.19.11 hooked `AWEFeedCellViewController -playerWillLoopPlaying:` and the video kept repeating,
// reported immediately. Reading the binary properly showed why: **that selector is an announcement,
// not a decision.** Around twenty classes implement it -- caption managers, view-count managers,
// danmaku, preload, clear-mode records -- because it is how the player tells everyone it is about
// to loop. Refusing one listener's copy of the news changes nothing about the news.
//
// The decision lives on TikTok's playback engine: `TTVideoEnginePlayer`, `TTVideoEngineOwnPlayer`
// and `TTVideoEngineSYSAVPlayer` each own `looping` (`B16@0:8`) with `-setLooping:` (`v20@0:8B16`),
// and `TTVideoEngineAdapter` carries the setter too.
//
// **Both ends are answered, for the reason this project already wrote down twice** -- once for
// `-bypassOnesie` in the YouTube tweak and once for TikTok's own watermark: code that reads an
// ivar directly never passes through a getter hook, while a stored value is true for every reader.
// So the setter refuses to store YES, and the getter refuses to report it.
//
%group SCITTNoLoop

%hook TTVideoEnginePlayer

- (void)setLooping:(BOOL)looping {
    if (SCIPrefEnabled(SCIPrefNoLoop)) {
        %orig(NO);
        return;
    }
    %orig;
}

- (BOOL)looping {
    if (!SCIPrefEnabled(SCIPrefNoLoop)) return %orig;
    return NO;
}

%end

%end

%group SCITTNoLoopOwn

%hook TTVideoEngineOwnPlayer

- (void)setLooping:(BOOL)looping {
    if (SCIPrefEnabled(SCIPrefNoLoop)) {
        %orig(NO);
        return;
    }
    %orig;
}

- (BOOL)looping {
    if (!SCIPrefEnabled(SCIPrefNoLoop)) return %orig;
    return NO;
}

%end

%end

%group SCITTNoLoopSystem

%hook TTVideoEngineSYSAVPlayer

- (void)setLooping:(BOOL)looping {
    if (SCIPrefEnabled(SCIPrefNoLoop)) {
        %orig(NO);
        return;
    }
    %orig;
}

- (BOOL)looping {
    if (!SCIPrefEnabled(SCIPrefNoLoop)) return %orig;
    return NO;
}

%end

%end

%group SCITTNoLoopAdapter

%hook TTVideoEngineAdapter

- (void)setLooping:(BOOL)looping {
    if (SCIPrefEnabled(SCIPrefNoLoop)) {
        %orig(NO);
        return;
    }
    %orig;
}

%end

%end

void SCITTInstallExtras(void) {
    NSMutableArray<NSString *> *installed = [NSMutableArray array];
    NSMutableArray<NSString *> *skipped = [NSMutableArray array];

    //
    // **Each of the three decides for itself.** A build missing one of these classes must install
    // the other two rather than stand down entirely -- a gate narrower than what it guards fails
    // silently in the direction of doing less, which this project has now written down twice.
    //
    Class accounts = NSClassFromString(@"AWEUserService");
    if (accounts && SCITTEncodingMatches(accounts, @"maxLoginedAccounts", @"Q16@0:8")) {
        %init(SCITTAccounts);
        [installed addObject:@"-maxLoginedAccounts"];
    } else {
        [skipped addObject:@"AWEUserService -maxLoginedAccounts"];
    }

    Class message = NSClassFromString(@"TIMOMessage");
    if (message && SCITTEncodingMatches(message, @"recalled", @"B16@0:8")) {
        %init(SCITTKeepRecalled);
        [installed addObject:@"-recalled"];
    } else {
        [skipped addObject:@"TIMOMessage -recalled"];
    }

    if (message && SCITTEncodingMatches(message, @"setRecalled:", @"v20@0:8B16")) {
        %init(SCITTKeepRecalledSetter);
        [installed addObject:@"-setRecalled:"];
    } else {
        [skipped addObject:@"TIMOMessage -setRecalled:"];
    }

    // The bubble: every selector this reads or hooks asked of the build first, and the text badge stays as the fallback if any is missing.
    Class cellView = NSClassFromString(@"AWEIMTextMessageCellView");
    if (cellView
        && SCITTEncodingMatches(cellView, @"p_setBubbleLayerColor", @"v16@0:8")
        && SCITTEncodingMatches(cellView, @"p_configWithCellViewModel:oldCellViewModel:", @"v32@0:8@16@24")
        && SCITTEncodingMatches(cellView, @"bubbleLayer", @"@16@0:8")
        && SCITTEncodingMatches(cellView, @"message", @"@16@0:8")
        && SCITTEncodingMatches(NSClassFromString(@"AWEIMMessage") ?: [NSObject class], @"serverMessageID", @"q16@0:8")) {
        %init(SCITTRecalledBubble);
        sciBubbleTintInstalled = YES;
        sciTintState = @"installed: AWEIMTextMessageCellView";
        [installed addObject:@"AWEIMTextMessageCellView (recalled bubble tint)"];
    } else {
        sciTintState = cellView ? @"stood down: a selector is missing or differently typed; the text badge marks instead"
                                : @"stood down: AWEIMTextMessageCellView absent; the text badge marks instead";
        [skipped addObject:@"AWEIMTextMessageCellView (recalled bubble tint)"];
    }

    if (message && SCITTEncodingMatches(message, @"content", @"@16@0:8")) {
        %init(SCITTMarkRecalled);
        [installed addObject:@"-content (recalled mark)"];
    } else {
        [skipped addObject:@"TIMOMessage -content"];
    }

    Class online = NSClassFromString(@"AWEIMActivityStatusReportManager");
    if (online && SCITTEncodingMatches(online, @"p_enableReportOnlineStatus", @"B16@0:8")
               && SCITTEncodingMatches(online, @"p_reportActivityStatusWithParams:", @"v24@0:8@16")) {
        %init(SCITTHideOnline);
        [installed addObject:@"-p_report… (hide online)"];
    } else {
        [skipped addObject:@"AWEIMActivityStatusReportManager -p_report…"];
    }

    //
    // Four engine classes, each asked for itself: a build may carry any subset, and a %hook on a
    // class that is not there never attaches while a %hook on a method a class does not declare
    // *adds* one -- which would be inventing an API nobody calls.
    //
    struct { const char *name; const char *selector; const char *encoding; int group; } loops[] = {
        { "TTVideoEnginePlayer",      "setLooping:", "v20@0:8B16", 0 },
        { "TTVideoEngineOwnPlayer",   "setLooping:", "v20@0:8B16", 1 },
        { "TTVideoEngineSYSAVPlayer", "setLooping:", "v20@0:8B16", 2 },
        { "TTVideoEngineAdapter",     "setLooping:", "v20@0:8B16", 3 },
    };

    for (size_t i = 0; i < sizeof(loops) / sizeof(loops[0]); i++) {
        Class engine = NSClassFromString(@(loops[i].name));
        if (!engine || !SCITTEncodingMatches(engine, @(loops[i].selector), @(loops[i].encoding))) {
            [skipped addObject:[NSString stringWithFormat:@"%s -setLooping:", loops[i].name]];
            continue;
        }

        switch (loops[i].group) {
            case 0: %init(SCITTNoLoop); break;
            case 1: %init(SCITTNoLoopOwn); break;
            case 2: %init(SCITTNoLoopSystem); break;
            case 3: %init(SCITTNoLoopAdapter); break;
        }
        [installed addObject:[NSString stringWithFormat:@"%s -setLooping: (no loop)", loops[i].name]];
    }

    Class presenter = NSClassFromString(@"TTKProfileViewsPresenter");
    if (presenter && SCITTEncodingMatches(presenter, @"model", @"@16@0:8")) {
        %init(SCITTVisitors);
        [installed addObject:@"-model (visitor log)"];
    } else {
        [skipped addObject:@"TTKProfileViewsPresenter -model"];
    }

    sciExtrasState = [NSString stringWithFormat:@"%@%@",
        installed.count ? [@"installed: " stringByAppendingString:
                              [installed componentsJoinedByString:@", "]]
                        : @"nothing installed",
        skipped.count ? [NSString stringWithFormat:@" — skipped: %@",
                            [skipped componentsJoinedByString:@"; "]]
                      : @""];

    SCILogV(@"[Extras] %@", sciExtrasState);
}
