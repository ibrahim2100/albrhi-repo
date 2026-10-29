#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "SCITTButton.h"
#import "SCITTMedia.h"
#import "SCITTDownload.h"
#import "../Copy/SCITTCopyMenu.h"
#import "../../TikTokHeaders.h"
#import "../../Prefs.h"
#import "../../Localization/SCILocalize.h"
#import "../../SCILog.h"

///
/// A button in the feed itself, beside like/comment/share -- and only one at a time.
///
/// **Both surfaces attached and placed real buttons** (a device report showed a cell
/// overlay placing 3 and the interaction rail placing 9), which proved the classes and
/// the hook points right. What it also showed was 4-6 buttons on screen scattered
/// across it at once -- because TikTok keeps more than one cell alive at a time for
/// smooth scrolling (the current one and its prefetched neighbours), and this file was
/// showing a button on *every* alive cell's own rail rather than only the one actually
/// on screen. Reported directly, and it is a real bug independent of anything about
/// class names.
///
/// **The cell-overlay surface is dropped.** It was the fallback for a build where the
/// rail turned out not to exist; this device's own report already proved the rail does,
/// so carrying a second surface only doubled the scatter for no benefit. One surface,
/// arranged in the rail beside TikTok's own icons -- which is also what was asked for.
///
/// **Visibility is now restricted to whichever rail is actually centred in its own
/// window.** Every alive cell's rail still runs `-layoutSubviews`, but only the one
/// whose vertical centre sits within a quarter of the screen's height of the window's
/// own centre shows its button; every other alive rail hides its own. Comparing centres
/// in window coordinates costs nothing TikTok's view hierarchy does not already have
/// (`-convertRect:toView:`) and needs no knowledge of which cell TikTok itself
/// considers "current."
///

@interface TTKFeedInteractionStackView : UIStackView
@end

@interface TTKFeedRightInteractionStackView : UIStackView
@end

/// YES once any cell button has been placed, which is what makes the rail stand down.
///
/// Declared up here rather than beside the cell hook: SCITTPlaceRailButton reads it and is
/// defined earlier in the file, and C does not care that the two belong together.
static BOOL sciCellSurfaceWorks = NO;

static const NSInteger kSCIRailButtonTag = 0x5C17;
static const void *kSCIItemKey = &kSCIItemKey;

static BOOL sciRailPresent = NO;

/// Decided once at install, not discovered at the first successful placement.
///
/// The previous arrangement let whichever surface happened to run first become the owner, which
/// is how a video ended up with two buttons and how the rail's own fixes were never reached.
/// Ownership is a decision, so it is made in one place before anything is on screen.
static BOOL sciRailIsOwner = NO;
static NSString *sciRailName = nil;
static NSUInteger sciRailButtonsPlaced = 0;

/// What the rail actually contained when the button was placed, and whether share was
/// found in it -- so a build whose icon naming does not match says so rather than
/// silently landing the button somewhere odd.
static NSString *sciRailContents = nil;

/// How the button entered the rail, in the rail's own terms.
///
/// This replaced a `BOOL` reading "one before last" or "appended at end", which had become a
/// sentence the code could no longer make false: the position is index 0 now, and a flag nothing
/// ever sets to YES reports the other branch forever. A diagnostic that cannot disagree with the
/// code is worse than no diagnostic, because it is read as confirmation.
static NSString *sciRailPlacement = nil;


/// A few points to the right of where the stack puts it, and a transform rather than a constraint.
///
/// The rail's own icons are wider than this button's disc — TikTok's like icon carries a counter
/// under it — so the stack centres the button on a column that reads slightly left of the artwork
/// beside it. A translation moves the drawing without touching the layout, so the slot the stack
/// measured stays exactly the size it measured, and nothing about the arrangement shifts.
static const CGFloat kSCIRailNudgeX = 0;
/// Where TikTok centres its own icons and counts inside a rail item that is 80 points wide (measured on the live hierarchy, 47.1.0: the 32-point icon box
/// of like, comment, bookmark and share starts at 33.7 and the 49-point count label at 25). Not the item's midpoint, which is why a centred glyph looked off.
static const CGFloat kSCIRailIconCenterX = 49.67;

/// The button's resting transform, in one place because the press animation has to return to it.
///
/// A press that ends at `CGAffineTransformIdentity` would quietly undo the nudge the first time
/// anybody tapped — the button would jump left and stay there — which is the kind of bug that
/// looks like a placement failure and is not one.
static inline CGAffineTransform SCITTRailRest(void) {
    return CGAffineTransformMakeTranslation(kSCIRailNudgeX, 0);
}

/// Defined below, beside the placement it also serves -- declared here because the tap handler above
/// it needs the same answer.
static SCITTMediaItem *SCITTItemForRail(UIView *rail);

/// The tag the publish-date label carries, so a recycled cell finds its own rather than adding a
/// second one. Same reason the button has one: a cell is reused, and a view added on every pass is
/// a stack of views nobody owns.
static const NSInteger kSCIDateTag = 0x5344;

/// **Each stage counts itself, because "the date did not appear" was true four ways.**
///
/// The placer is not reached at all, the switch is off, the item carries no date, or it was drawn
/// and something else is on top of it. One number cannot say which -- that is the lesson the stamp
/// counters in Albrhi Watch cost, and this file already learned it once with `raw -> parsed ->
/// deduped` in the quality picker.
static NSUInteger sciDateCalls = 0;
static NSUInteger sciDateOff = 0;
static NSUInteger sciDateNoHost = 0;
static NSUInteger sciDateNoDate = 0;
static NSUInteger sciDatePlaced = 0;
static NSUInteger sciDateAboveName = 0;     // drawn above the account name, in the info column
static NSUInteger sciDateBeside = 0;        // laid out beside the account name (the rest of the author-row draws went above the row)
static NSUInteger sciDateOnRail = 0;        // no author row found: drawn over the download button, as before
static BOOL sciDateRetrying = NO;           // inside a retry: its counter must not be reset by its own call
static NSString *sciDateAuthorWhy = nil;    // why the last search for the author row found nothing
static NSString *sciDateLast = nil;

///
/// The publish date, drawn under Albrhi's own button.
///
/// **In a frame this code owns, which is the whole reason it can be drawn at all.** TikTok's rails
/// rebuild their arranged subviews and sweep guests out -- that is written down in CLAUDE.md at the
/// cost of a release -- so the label is placed on the same host as the button, at a frame computed
/// from the button's, and never handed to a stack.
///
/// It is refreshed rather than recreated: `-configWithModel:` fires on every reuse, and a label
/// added each time is a pile of labels on one cell.
///
///
/// **Called from every place a button is bound to an item, not from one of them.**
///
/// The first version hooked this into the cell path alone, and a device answered
/// `0 call(s)`: the button on that build is placed by the *rail* path, which binds its item
/// somewhere else entirely. Three sites bind an item to a button, and the truthful signal is the
/// binding itself -- so the label follows all three rather than whichever one was read first.
///
/// This is the same fault as the publish date being read on one of four routes that build an item,
/// one release earlier and in the same feature. **A value or a view attached on one path out of
/// several is attached on none of the others**, and this file has now paid for that twice.
///
//
// **A position computed once is a position computed too early, and that is what "some videos are
// perfect and some are not" was.**
//
// The geometry below reads `button.frame` and `host.window`. Neither is settled when the model is
// bound: on the rail path the button is an *arranged* subview, so its frame is `CGRectZero` until
// the stack lays out, and a cell being configured on its way onto the screen may not be in a
// window yet -- which skips the on-screen clamp entirely and leaves the label centred on a button
// that is nowhere. Both produce exactly the reported split: right on the cells that had already
// laid out when they were bound, and the old wrong position on the ones that had not.
//
// This project has written the same lesson down once before, about a constraint built from
// `bounds` at construction time. **A frame is a measurement, and a measurement taken before the
// thing exists is not a smaller error -- it is a different number entirely.** So the label carries
// the button it belongs to and re-measures whenever it is laid out or enters a window, which is
// precisely when those two values become true.
//
@interface SCITTDateLabel : UILabel
@property (nonatomic, weak) UIView *sciButton;
/// The feed's author row (`AWEPlayInteractionAuthorView`) when the label is drawn above the account name; nil when it is drawn over the button.
@property (nonatomic, weak) UIView *sciAuthor;
/// What the label was last bound to, so that a bind that found no author row yet can be made again a moment later.
@property (nonatomic, strong) SCITTMediaItem *sciItem;
@property (nonatomic, assign) NSInteger sciRetries;
/// When non-zero: the x, inside the item the label sits above, that the label is centred on (TikTok's icons are not centred in their 80-point items).
@property (nonatomic, assign) CGFloat sciIconCenterX;
@end

static void SCITTLayoutDateLabel(UILabel *label, UIView *button);
static void SCITTPlaceDateLabel(UIView *host, UIView *button, SCITTMediaItem *item);

@implementation SCITTDateLabel

- (void)didMoveToWindow {
    [super didMoveToWindow];
    SCITTLayoutDateLabel(self, self.sciButton);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    // Re-measuring here is safe because the geometry is a function of the button's frame alone:
    // running it a second time on an unchanged button yields the same rectangle, and the guard in
    // the layout function refuses to set a frame it already has. A layout pass that settles
    // nothing therefore stops after one.
    SCITTLayoutDateLabel(self, self.sciButton);
}

@end

/// The view controller a view is drawn by: the first one up its responder chain.
static UIViewController *SCITTControllerOfView(UIView *view) {
    UIResponder *responder = view;
    for (NSInteger i = 0; responder && i < 30; i++, responder = responder.nextResponder) {
        if ([responder isKindOfClass:[UIViewController class]]) return (UIViewController *)responder;
    }
    return nil;
}

/// TikTok's author row for the video this button belongs to: the nearest ancestor of the button that holds one, searched downward and bounded
/// (a cell is a few hundred views). The row is `AWEPlayInteractionAuthorView`, its container `TTKFeedPassthroughStackView`, in the info column
/// at the bottom left that also holds the caption (read off the live hierarchy in the simulator, 47.1.0). Nil when it is not there.
static UIView *SCITTFindAuthorView(UIView *button) {
    static Class authorClass = Nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ authorClass = NSClassFromString(@"AWEPlayInteractionAuthorView"); });
    if (!authorClass || !button) { sciDateAuthorWhy = @"the author row class is not in this build"; return nil; }

    // **Only the row that belongs to the same controller as the button.** Climbing far enough reaches a container that also holds the
    // next and the previous video's cells, and the first row found there could be a neighbour's: a date over somebody else's name.
    UIViewController *owner = SCITTControllerOfView(button);
    if (!owner) { sciDateAuthorWhy = @"the button has no view controller above it"; return nil; }

    NSUInteger mismatched = 0, visited = 0;
    UIView *ancestor = button.superview;
    for (NSInteger up = 0; ancestor && up < 8; up++, ancestor = ancestor.superview) {
        NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:ancestor];
        NSUInteger seen = 0;
        for (NSUInteger i = 0; i < queue.count && seen < 4000; i++, seen++) {
            UIView *view = queue[i];
            visited++;
            if ([view isKindOfClass:authorClass]) {
                if (SCITTControllerOfView(view) == owner) return view;
                mismatched++;
                continue;   // another video's row: not this button's, and nothing below it is either
            }
            // The sticker layers fill the whole screen with views that never hold an account name.
            NSString *name = NSStringFromClass([view class]);
            if ([name hasPrefix:@"ACCSticker"] || [name hasPrefix:@"TTKSticker"] || [name isEqualToString:@"TTKFeedRightInteractionStackView"]) continue;
            for (UIView *child in view.subviews) [queue addObject:child];
        }
    }
    sciDateAuthorWhy = [NSString stringWithFormat:@"not found after %lu views (%lu belonged to another controller)", (unsigned long)visited, (unsigned long)mismatched];
    return nil;
}

/// The country flag: its own small label over the download button, in the rail (the one frame this code owns there), centred on the button by the
/// same layout the date used when it lived there. nil text hides it.
static const NSInteger kSCIFlagTag = 0x5345;
static void SCITTPlaceFlagLabel(UIView *host, UIView *button, NSString *text) {
    SCITTDateLabel *flag = (SCITTDateLabel *)[host viewWithTag:kSCIFlagTag];
    if (!text.length || !host || !button) { flag.hidden = YES; return; }

    // **Above the top of the column, over the profile picture.** The download button is now an item between bookmark and share, so the room
    // above it belongs to the bookmark's count; the free room is above the first item, centred on the icons' own column.
    UIView *anchor = button;
    if ([host isKindOfClass:[UIStackView class]]) {
        for (UIView *item in ((UIStackView *)host).arrangedSubviews) {
            if (item.tag != kSCIRailButtonTag && !item.hidden) { anchor = item; break; }
        }
    }
    if (![flag isKindOfClass:[SCITTDateLabel class]]) {
        [flag removeFromSuperview];
        flag = [[SCITTDateLabel alloc] initWithFrame:CGRectZero];
        flag.tag = kSCIFlagTag;
        flag.textAlignment = NSTextAlignmentCenter;
        flag.font = [UIFont systemFontOfSize:20];
        flag.numberOfLines = 1;
        flag.userInteractionEnabled = NO;
        [host addSubview:flag];
    }
    flag.text = text;
    flag.hidden = NO;
    flag.sciButton = anchor;
    flag.sciAuthor = nil;
    flag.sciIconCenterX = kSCIRailIconCenterX;
    SCITTLayoutDateLabel(flag, anchor);
}

static void SCITTPlaceDateLabel(UIView *host, UIView *button, SCITTMediaItem *item) {
    //
    // **Counted first, because a counter behind a guard counts successes and not calls.**
    //
    // A device answered `0 call(s)` while this function was being called on every video: the guard
    // below returned before the counter, so a path that ran constantly reported never running. That
    // is the third time this project has met the same family -- the watermark counter on the setter
    // this build never calls, the last-event snapshot, and now this -- and the rule it keeps
    // arriving at is one line: **before believing a zero, check that the counter sits on the path
    // that executes.**
    //
    sciDateCalls++;

    //
    // **The label goes where the button lives, and nowhere else.**
    //
    // `button.frame` is expressed in the coordinates of the button's *own* superview. This function
    // was handed a `host` that on two of its three call sites is a different view -- so the frame
    // was read in one space and drawn in another, and the label leaned by exactly the offset
    // between them. On one phone that offset is small; on another it puts the day outside the app.
    //
    // A rectangle only means something in the space it was measured in. The anchor is the button's
    // superview here, whatever the caller passed.
    //
    if (button.superview) host = button.superview;
    if (!host) host = button.superview;
    if (!host || !button) {
        sciDateNoHost++;
        return;
    }

    // **Above the account name when the feed's author row can be found, over the button when it cannot.** The row is TikTok's, so it is only
    // asked where it is and never moved: the label is a sibling of it, in the same container, at a frame this code computes from the row's.
    UIView *author = SCITTFindAuthorView(button);
    UIView *labelHost = author.superview ?: host;
    SCITTDateLabel *label = (SCITTDateLabel *)[labelHost viewWithTag:kSCIDateTag];
    if (author && host != labelHost) {
        // The one drawn over the button by an earlier bind of this cell would be a second date.
        [[host viewWithTag:kSCIDateTag] removeFromSuperview];
    }

    // The date and the stats line share this label: it is the one frame this code owns over a video, and a second label would be a second
    // thing to place against the same button.
    BOOL dateOn = SCIPrefEnabled(SCIPrefVideoDate);
    BOOL statsOn = SCIPrefEnabled(SCIPrefVideoStats);
    BOOL wantDate = dateOn && item.posted;
    BOOL wantStats = statsOn && item.stats.length;

    if (!dateOn && !statsOn) {
        sciDateOff++;
        label.hidden = YES;
        SCITTPlaceFlagLabel(button.superview, button, nil);
        return;
    }

    if (!wantDate && !wantStats) {
        sciDateNoDate++;
        label.hidden = YES;
        SCITTPlaceFlagLabel(button.superview, button, nil);
        return;
    }

    if (![label isKindOfClass:[SCITTDateLabel class]]) {
        [label removeFromSuperview];
        label = [[SCITTDateLabel alloc] initWithFrame:CGRectZero];
        label.tag = kSCIDateTag;
        label.textAlignment = NSTextAlignmentCenter;
        label.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
        label.textColor = [UIColor whiteColor];
        // **Two lines and the long form, as it was.** 0.19.5 shortened this while fixing a
        // position, and nobody had asked for it -- the date read better with the month named and
        // the time under it. Changing what was not reported is its own kind of regression, and the
        // width it needs is the placement's problem to solve, not the format's.
        label.numberOfLines = 3;
        label.userInteractionEnabled = NO;

        // The same shadow TikTok gives its own rail text, so a white label stays readable over a
        // bright frame of video.
        label.layer.shadowColor = [UIColor blackColor].CGColor;
        label.layer.shadowOffset = CGSizeMake(0, 1);
        label.layer.shadowOpacity = 0.6;
        label.layer.shadowRadius = 2;

        [labelHost addSubview:label];
    }

    // One formatter, kept: building an NSDateFormatter is expensive and this runs on every cell
    // that scrolls past.
    static NSDateFormatter *formatter = nil;
    static NSDateFormatter *dateOnly = nil;
    static NSDateFormatter *timeOnly = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // The phone's language and region, but the Gregorian calendar and Western digits: an Arabic phone in Saudi Arabia answers with the
        // Hijri calendar and Arabic-Indic digits ("٦ جمادى الأولى، ١٤٤٨"), a date nobody compares with the post counts TikTok draws in Western
        // digits beside it, and the long form was cut off before the time. Language stays Arabic: "6 مايو 2026".
        NSString *base = [[NSLocale currentLocale].localeIdentifier componentsSeparatedByString:@"@"].firstObject;
        NSLocale *dateLocale = [NSLocale localeWithLocaleIdentifier:[base stringByAppendingString:@"@calendar=gregorian;numbers=latn"]];
        NSCalendar *gregorian = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterMediumStyle;
        formatter.timeStyle = NSDateFormatterShortStyle;
        // The phone's own locale, so an Arabic device reads an Arabic date without this file
        // deciding what a date looks like.
        formatter.locale = dateLocale;
        formatter.calendar = gregorian;

        // The same two halves on their own, which is how the join between them is found below.
        dateOnly = [[NSDateFormatter alloc] init];
        dateOnly.dateStyle = NSDateFormatterMediumStyle;
        dateOnly.timeStyle = NSDateFormatterNoStyle;
        dateOnly.locale = dateLocale;
        dateOnly.calendar = gregorian;

        timeOnly = [[NSDateFormatter alloc] init];
        timeOnly.dateStyle = NSDateFormatterNoStyle;
        timeOnly.timeStyle = NSDateFormatterShortStyle;
        timeOnly.locale = dateLocale;
        timeOnly.calendar = gregorian;
    });

    //
    // **The break goes before the join word, and the join word is not "at".**
    //
    // One line is too long, and the two lines wanted are the date and then `at <time>` under it.
    // Writing that as `date + "\n at " + time` would hard-code an English word into a label that
    // deliberately follows the phone's own locale -- an Arabic device joins with a different word
    // entirely, and some locales use no word at all.
    //
    // So the separator is *measured* rather than named: the combined string minus the date half
    // and minus the time half is whatever this locale puts between them. Anything that does not
    // decompose that way -- an unfamiliar locale, a time string that appears twice -- falls back
    // to the combined string untouched, which is exactly what shipped before and merely long.
    //
    NSString *text = wantDate ? [formatter stringFromDate:item.posted] : @"";
    NSString *head = wantDate ? [dateOnly stringFromDate:item.posted] : nil;
    NSString *tail = wantDate ? [timeOnly stringFromDate:item.posted] : nil;
    if (head.length && tail.length && [text hasPrefix:head]) {
        NSRange timeRange = [text rangeOfString:tail options:NSBackwardsSearch];
        if (timeRange.location != NSNotFound && timeRange.location >= head.length) {
            NSString *join = [[text substringWithRange:NSMakeRange(head.length, timeRange.location - head.length)]
                stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            NSString *second = join.length ? [NSString stringWithFormat:@"%@ %@", join, tail] : tail;
            text = [NSString stringWithFormat:@"%@\n%@", head, second];
        }
    }

    if (author) {
        // One quiet line: "22 Oct 2026 · 3:50 PM · ♥ 86.7K 🇸🇦". Each piece is wrapped in a bidi isolate so a Latin date or a count beside an
        // Arabic one cannot merge into one run and read backwards (CLAUDE.md 4.5).
        NSMutableArray<NSString *> *pieces = [NSMutableArray array];
        if (wantDate) {
            if (head.length && tail.length && [text hasPrefix:head]) { [pieces addObject:head]; [pieces addObject:tail]; }
            else if (text.length) [pieces addObject:[formatter stringFromDate:item.posted]];
        }
        NSMutableArray<NSString *> *isolated = [NSMutableArray array];
        for (NSString *piece in pieces) [isolated addObject:[NSString stringWithFormat:@"\u2068%@\u2069", piece]];
        text = [isolated componentsJoinedByString:@"  ·  "];
        // The country is not part of this line: it is its own flag over the download button.
        SCITTPlaceFlagLabel(button.superview, button, wantStats ? item.stats : nil);

        BOOL rtl = labelHost.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
        label.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        label.textColor = [UIColor colorWithWhite:1 alpha:0.82];
        label.textAlignment = rtl ? NSTextAlignmentRight : NSTextAlignmentLeft;
        label.numberOfLines = 1;
        label.lineBreakMode = NSLineBreakByTruncatingTail;
        // Shrunk a little before it is cut: the time at the end is the part that must not go.
        label.adjustsFontSizeToFitWidth = YES;
        label.minimumScaleFactor = 0.7;
        sciDateAboveName++;
    } else {
        // **No author row: no date.** Over the button it used to sit, and the button now sits between bookmark and share, where a date would
        // cover the bookmark's count. The row is found on practically every video (retried while TikTok fills it); the miss is counted.
        text = @"";
        label.numberOfLines = 1;
        sciDateOnRail++;
        SCITTPlaceFlagLabel(button.superview, button, wantStats ? item.stats : nil);
    }
    label.text = text;
    label.hidden = text.length == 0;
    sciDatePlaced++;
    sciDateLast = label.text;

    //
    // **Above the button, centred on it, and kept inside the host.**
    //
    // It sat below and drifted right, which is what centring a fixed width on a button that lives
    // at the right edge of the screen does: half the label wants to be off-screen, so what is
    // visible reads as offset. The frame is clamped to the host's bounds now, so the label sits
    // over the button rather than beside it -- and this is a frame this code owns, which is the
    // whole reason a two-line change can move it at all.
    //
    //
    // **Sized to its own text and centred on the button, with nothing clamped to the host.**
    //
    // What was here forced a 96pt box and then clamped it into `host.bounds` -- and the host is the
    // interaction rail, which is about 44pt wide. So `hostWidth - 96 - 2` was *negative*, the right
    // clamp never ran, and `if (x < 2) x = 2` shoved the label onto the rail's left edge every
    // time. A device with a slightly different rail width leans differently, which is exactly what
    // two phones showed: centred on one, hard left and cut off on the other.
    //
    // **A clamp into a box narrower than the thing being placed is not a safety net; it is a
    // guarantee of the wrong position.** The button's own frame is the only rectangle this code
    // owns and the only one that means the same thing on every device, so the label is centred on
    // that and allowed to overhang a narrow rail rather than be pushed out of it.
    //
    // The button it belongs to, re-read on every bind because a recycled cell hands this label a
    // different button than the one it was created for.
    label.sciButton = button;
    label.sciAuthor = author;
    label.sciItem = item;
    SCITTLayoutDateLabel(label, button);

    // **TikTok fills the author row after it hands the button its model**, so the first search at a bind can find an empty column (68 views, none of
    // them the row: seen with the live hierarchy). A miss is asked again a moment later, three times at most, and a bind that came in meanwhile
    // (a recycled cell, another video) cancels the old attempt because the label no longer carries the item the attempt was for.
    if (!sciDateRetrying) label.sciRetries = 0;
    if (!author && label.sciRetries < 3) {
        static const double delays[3] = {0.15, 0.5, 1.2};
        double wait = delays[label.sciRetries];
        label.sciRetries++;
        __weak SCITTDateLabel *weakLabel = label;
        __weak UIView *weakButton = button;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(wait * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            SCITTDateLabel *current = weakLabel;
            UIView *liveButton = weakButton;
            if (!current || !liveButton || current.sciItem != item || current.sciAuthor || !liveButton.superview) return;
            sciDateRetrying = YES;
            SCITTPlaceDateLabel(liveButton.superview, liveButton, item);
            sciDateRetrying = NO;
        });
    }
}

//
// **The measurement itself, in one place, callable whenever the numbers become true.**
//
/// The first descendant of `root` whose class has this name, breadth first and bounded; nil when there is none.
static UIView *SCITTFindNamedDescendant(UIView *root, NSString *className) {
    Class wanted = NSClassFromString(className);
    if (!wanted || !root) return nil;
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:root];
    for (NSUInteger i = 0; i < queue.count && i < 60; i++) {
        UIView *view = queue[i];
        if ([view isKindOfClass:wanted]) return view;
        [queue addObjectsFromArray:view.subviews];
    }
    return nil;
}

static void SCITTLayoutDateLabel(UILabel *label, UIView *button) {
    UIView *host = label.superview;

    // Above the account name: a frame computed from TikTok's author row, in the container that holds it.
    UIView *author = [label isKindOfClass:[SCITTDateLabel class]] ? ((SCITTDateLabel *)label).sciAuthor : nil;
    if (author && host && author.superview == host) {
        CGRect row = author.frame;
        if (CGRectGetWidth(row) < 1 || CGRectGetHeight(row) < 1) return;   // not laid out yet: it calls back when it is

        // **Beside the account name, on its own line: the name's button is found inside the row and the label takes the room after it.**
        // Above the row it met TikTok's topic chip ("Anime . ONE PIECE") on videos that have one; the row itself is free to the side of the
        // name. "After" is the trailing side, so an Arabic phone puts it to the left of the name.
        UIView *nameButton = SCITTFindNamedDescendant(author, @"AWEPlayInteractionAuthorUserNameButton");
        CGRect name = nameButton ? [host convertRect:nameButton.bounds fromView:nameButton] : CGRectZero;
        // **Which side is measured, not assumed from the phone's language.** On an Arabic phone TikTok mirrors its tab bar and lists but leaves
        // this info column on the left, name first (seen in the simulator, ar_SA), so the layout direction would have put the date on the wrong
        // side. The name sits on one half of its row; the date goes to the other side of it.
        BOOL nameOnLeft = CGRectGetMidX(name) <= CGRectGetMidX(row);
        CGFloat gap = 8;
        CGFloat x = nameOnLeft ? CGRectGetMaxX(name) + gap : CGRectGetMinX(row);
        CGFloat room = nameOnLeft ? CGRectGetMaxX(row) - x : CGRectGetMinX(name) - gap - CGRectGetMinX(row);
        CGRect frame;
        if (CGRectGetWidth(name) > 1 && room >= 90) {
            label.textAlignment = nameOnLeft ? NSTextAlignmentLeft : NSTextAlignmentRight;
            frame = CGRectMake(x, CGRectGetMinY(row), room, CGRectGetHeight(row));
            sciDateBeside++;
        } else {
            // A long name leaves no room: above the row, as the first version had it.
            CGFloat height = MAX(ceil([label sizeThatFits:CGSizeMake(CGRectGetWidth(row), 40)].height), 14);
            label.textAlignment = nameOnLeft ? NSTextAlignmentLeft : NSTextAlignmentRight;
            frame = CGRectMake(CGRectGetMinX(row), CGRectGetMinY(row) - height - 1, CGRectGetWidth(row), height);
        }
        if (!CGRectEqualToRect(label.frame, frame)) label.frame = frame;

        // The info column clips by default in places; this line sits above the row it belongs to, outside its box.
        UIView *up = host;
        for (NSInteger i = 0; up && i < 4; i++, up = up.superview) if (up.clipsToBounds) up.clipsToBounds = NO;
        if (host.subviews.lastObject != label) [host bringSubviewToFront:label];
        return;
    }

    if (!host || !button || button.superview != host) return;

    CGRect b = button.frame;

    // **An unlaid-out button is not a position, and placing against it would be inventing one.**
    // Nothing is moved until the stack has given the button a size; the layout pass that gives it
    // one calls straight back here.
    if (CGRectGetWidth(b) < 1 || CGRectGetHeight(b) < 1) return;

    // Measured against a width the two-line form can actually use, then given exactly that box.
    CGSize fits = [label sizeThatFits:CGSizeMake(150, 60)];
    CGFloat width = MIN(MAX(ceil(fits.width) + 8, 60), 150);
    CGFloat height = MAX(ceil(fits.height) + 2, 16);

    CGFloat centerX = CGRectGetMidX(b);
    CGFloat iconX = [label isKindOfClass:[SCITTDateLabel class]] ? ((SCITTDateLabel *)label).sciIconCenterX : 0;
    if (iconX > 0) centerX = CGRectGetMinX(b) + iconX;
    CGRect frame = CGRectMake(centerX - width / 2,
                              CGRectGetMinY(b) - height - 2,
                              width, height);

    //
    // **Centred on the button, and never past the edge of the screen -- which is one clamp, in the
    // one space where the screen exists.**
    //
    // The rail lives hard against the right edge, and this label is wider than the button it is
    // centred on, so its right half wants to be off the display. The previous attempt at this
    // clamped into `host.bounds` -- a 44pt rail -- which cannot contain a 150pt label at all and
    // therefore pinned it to the rail's left edge on every device. **A clamp into a box narrower
    // than the thing being placed is not a safety net, it is a guarantee of the wrong position.**
    //
    // The window is the box that actually has the property being asked for. The frame is converted
    // there, pushed back by however much it overhangs, and converted home -- so the label stays
    // centred on the button wherever there is room and slides only as far as it must. With no
    // window there is nothing to measure against, and it is left centred rather than clamped
    // against a guess.
    //
    UIView *root = host.window;
    if (root) {
        CGRect inWindow = [host convertRect:frame toView:root];
        CGFloat margin = 4;
        CGFloat over = CGRectGetMaxX(inWindow) - (CGRectGetWidth(root.bounds) - margin);
        if (over > 0) inWindow.origin.x -= over;
        if (CGRectGetMinX(inWindow) < margin) inWindow.origin.x = margin;
        frame = [host convertRect:inWindow fromView:root];
    }

    // **A frame it already has is not set again.** This runs from `-layoutSubviews`, and assigning
    // an equal-but-new rectangle there is how a layout pass talks itself into another one.
    if (!CGRectEqualToRect(label.frame, frame)) label.frame = frame;

    // The rail clips by default, which is how a correctly centred label still lost its digits.
    host.clipsToBounds = NO;

    // Only when it is not already there: this runs from a layout pass, and reordering subviews is
    // not free even when the order does not change.
    if (host.subviews.lastObject != label) [host bringSubviewToFront:label];
}

/// Defined below the counters it reads, not above them.
///
/// C reads a file top to bottom, and this went in beside a forward declaration where none of them
/// existed yet -- the same ordering mistake the Watch tweak's own verdict publisher made, caught
/// there by CI and here by the first local build. Both flavours are built before a push now, so
/// this cost seconds rather than five minutes.
NSString *SCITTDateReport(void) {
    return [NSString stringWithFormat:
            @"%lu call(s) → %lu with no host yet → %lu off → %lu without a date → %lu drawn (%lu on the author row, %lu of the layouts beside the name, %lu with no author row found, so no date%@)%@",
            (unsigned long)sciDateCalls, (unsigned long)sciDateNoHost, (unsigned long)sciDateOff,
            (unsigned long)sciDateNoDate, (unsigned long)sciDatePlaced, (unsigned long)sciDateAboveName, (unsigned long)sciDateBeside, (unsigned long)sciDateOnRail,
            sciDateAuthorWhy.length ? [@"; last miss: " stringByAppendingString:sciDateAuthorWhy] : @"",
            sciDateLast.length ? [@" — last: " stringByAppendingString:sciDateLast] : @""];
}

@interface SCITTButtonTarget : NSObject
+ (instancetype)shared;
- (void)tapped:(UIButton *)button;
@end

static const void *kSCITTCopyMarkKey = &kSCITTCopyMarkKey;
static const void *kSCITTHeldKey = &kSCITTHeldKey;

/// Adds the hold-to-copy recogniser to a download button, once. The recogniser's own action is on SCITTButtonTarget; whether the menu opens
/// is decided when the hold happens (the switch can be turned on after the button was made).
static void SCITTAttachCopyMenu(UIButton *button);
static UIViewController *SCITTOwningController(UIView *view);

@implementation SCITTButtonTarget

+ (instancetype)shared {
    static SCITTButtonTarget *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[SCITTButtonTarget alloc] init]; });
    return shared;
}

- (void)pressed:(UIButton *)button {
    objc_setAssociatedObject(button, kSCITTHeldKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [UIView animateWithDuration:0.12 animations:^{
        button.transform = CGAffineTransformScale(SCITTRailRest(), 0.86, 0.86);
        button.alpha = 0.75;
    }];
}

- (void)released:(UIButton *)button {
    [UIView animateWithDuration:0.24
                          delay:0
         usingSpringWithDamping:0.6
          initialSpringVelocity:0
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        button.transform = SCITTRailRest();
        button.alpha = 1;
    } completion:nil];
}

- (void)tapped:(UIButton *)button {
    // A hold that opened the copy menu ends in a lift on the button; that lift is not a tap.
    if (objc_getAssociatedObject(button, kSCITTHeldKey)) {
        objc_setAssociatedObject(button, kSCITTHeldKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    // **Resolved again, here, rather than trusting what was stashed when the button was made.**
    // A cell is recycled and a photo album is swiped, and both happen after placement: the stashed
    // item can be a video ago, and its recorded page index certainly can. Asking the controller the
    // button is currently inside costs one responder walk and is the only reading that describes
    // what is on screen at the moment of the tap. The stash stays as the fallback for a button whose
    // chain no longer reaches a controller.
    SCITTMediaItem *item = SCITTItemForRail(button) ?: objc_getAssociatedObject(button, kSCIItemKey);
    if (!item) {
        SCILogV(@"in-feed download button: nothing captured yet");
        return;
    }
    [SCITTDownload save:item];
}

@end

/// Marks a download button as one a hold means something on. **The hold itself is not followed here**: a recogniser on the button competes
/// with TikTok's own long-press (the feed's panel) and loses whenever TikTok's recognises first, and the first version did exactly that and
/// copied nothing. The window follows the touch itself (`SCITTHold.x`, from `-[UIWindow sendEvent:]`) and asks `SCITTCopyHoldOnDownloadButton`.
static void SCITTAttachCopyMenu(UIButton *button) {
    objc_setAssociatedObject(button, kSCITTCopyMarkKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

BOOL SCITTTouchIsOnCopyButton(UIView *hit) {
    if (!SCIPrefEnabled(SCIPrefCopyMenu)) return NO;
    UIView *view = hit;
    for (NSInteger step = 0; view && step < 6; step++, view = view.superview) {
        if (objc_getAssociatedObject(view, kSCITTCopyMarkKey)) return YES;
    }
    return NO;
}

BOOL SCITTCopyHoldOnDownloadButton(UIView *hit) {
    UIView *view = hit;
    for (NSInteger step = 0; view && step < 6; step++, view = view.superview) {
        if (!objc_getAssociatedObject(view, kSCITTCopyMarkKey)) continue;
        if (!SCIPrefEnabled(SCIPrefCopyMenu)) return NO;

        // The finger is still down: the lift that follows is the end of a hold, not a tap, and must not start a download.
        objc_setAssociatedObject(view, kSCITTHeldKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        UIViewController *owner = SCITTOwningController(view);
        id model = owner ? ((id (*)(id, SEL))objc_msgSend)(owner, NSSelectorFromString(@"model")) : nil;
        SCITTShowCopyMenu(model, view);
        return YES;
    }
    return NO;
}


// `SCITTViewIsCentered` was here: a test for whether a rail sat within a quarter of the window's
// height of its centre, used to decide which video's button to show. It is deleted rather than
// left unused, because a helper nobody calls is a claim that its idea still applies.
//
// The idea does not. It was answering "which video is on screen" with geometry, when a rail can be
// asked outright which video it belongs to -- see `SCITTItemForRail`. During a scroll two rails
// passed the test at once and at rest the visible one could fail it, which is exactly the
// "sometimes one, sometimes two, sometimes none" that followed.

/// Which rail class is allowed to place a button, decided at install.
static Class sciRailOwnerClass = nil;

///
/// The video a given rail belongs to, by asking rather than by guessing.
///
/// A `UIView`'s responder chain runs up through its superviews to the view controller that owns
/// them, so a rail can find the controller showing it without knowing anything about TikTok's cell
/// structure. That controller answers `-model`, and the model is the video whose rail this is.
///
/// **Every guard here is one this file has already paid for.** `-respondsToSelector:` because a
/// selector's presence on one class says nothing about another; `-isKindOfClass:` because `model`
/// is declared `AWEAwemeModel` on a base and a subclass may return something else — that exact
/// assumption crashed the direct-message screen; and a bounded walk, because a loop whose exit
/// depends on a hierarchy TikTok owns is not ours to trust.
/// The view controller showing the video this view belongs to, or nil.
///
/// Split out of `SCITTItemForRail` because the *tap* needs it too, not only the placement: a photo
/// album's live page index lives on that controller and changes with every swipe, so reading it when
/// the button was created answers a question about a picture the user has since scrolled past.
static UIViewController *SCITTOwningController(UIView *view) {
    SEL modelSel = NSSelectorFromString(@"model");
    Class awemeClass = NSClassFromString(@"AWEAwemeModel");

    UIResponder *responder = view;

    for (NSInteger step = 0; step < 12 && responder; step++) {
        responder = responder.nextResponder;
        if (![responder isKindOfClass:[UIViewController class]]) continue;
        if (![responder respondsToSelector:modelSel]) continue;

        id model = ((id (*)(id, SEL))objc_msgSend)(responder, modelSel);
        if (!model || (awemeClass && ![model isKindOfClass:awemeClass])) continue;

        return (UIViewController *)responder;
    }

    return nil;
}

static SCITTMediaItem *SCITTItemForRail(UIView *rail) {
    UIViewController *owner = SCITTOwningController(rail);
    if (!owner) {
        // Nothing in the chain owns a video. Falling back to the most recent capture would be the
        // old wrong-video bug, so the answer is no item and therefore no button on this rail.
        return nil;
    }

    id model = ((id (*)(id, SEL))objc_msgSend)(owner, NSSelectorFromString(@"model"));

    // Settled: this controller is on screen showing this video, so the deeper questions --
    // the bitrate ladder, the URL models -- are safe to ask here.
    [SCITTMedia captureSettledModel:(AWEAwemeModel *)model];
    [SCITTMedia refreshPhotoIndexFromController:owner];
    return [SCITTMedia recent].firstObject;
}

/// **Keeps the button above the profile picture in z-order.**
///
/// The button sits at index 0 of an arranged stack and the avatar is a later sibling, so wherever
/// the two overlap (the avatar's follow badge and live ring both draw outside its box, and the nudge
/// moves the button a few points) the avatar is painted over it and the button "hides behind the
/// picture" on some videos only. Arranged order and subview order are independent in a stack view:
/// raising the subview changes what is on top, never where the stack lays anything. Done only when it
/// is not already on top, because this runs from a layout pass and `-bringSubviewToFront:` is not
/// free even when nothing moves.
static void SCITTRaiseRailButton(UIStackView *stack, UIView *button) {
    if (!button || button.superview != stack) return;
    if (stack.subviews.lastObject != button) [stack bringSubviewToFront:button];
    if (button.layer.zPosition < 100) button.layer.zPosition = 100;
}

/// Whether a view is, or holds within a few levels, a view of this class.
static BOOL SCITTHoldsClass(UIView *view, Class wanted) {
    if (!view || !wanted) return NO;
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:view];
    for (NSUInteger i = 0; i < queue.count && i < 40; i++) {
        if ([queue[i] isKindOfClass:wanted]) return YES;
        [queue addObjectsFromArray:queue[i].subviews];
    }
    return NO;
}

static void SCITTPlaceRailButton(UIStackView *stack) {
    if (!SCIPrefEnabled(SCIPrefDownloadButton)) return;

    // **The rail owns the button now, and this guard is why it never did.**
    //
    // Everything below was written to make a rail button behave — sized from a real sibling,
    // inserted after the last `PlayInteraction` view rather than between two backgrounds,
    // shown only for the centred cell, and following the rail's own `hidden`/`alpha` so it fades
    // exactly when its neighbours do. None of it ever ran: `sciCellSurfaceWorks` is set the first
    // time the cell places one, which happens first, so this returned immediately for release
    // after release. **Fixes that are never reached are indistinguishable from fixes that do not
    // work**, and this file carried a set of them for weeks.
    //
    // The owner is the rail because that is what was actually asked for: a button that belongs to
    // TikTok's own column and rides up and down with it, instead of one pinned to a spot on the
    // cell that only happens to look right in the feed. The cell surface stands down — see its
    // own group — and stays as the fallback for a build where neither rail class exists.

    // Only the rail class chosen at install may place. Both were hooked, and on a build that has
    // both, one cell carries both — so one video grew two buttons, which is half of "sometimes one,
    // sometimes two".
    if (sciRailOwnerClass && ![stack isKindOfClass:sciRailOwnerClass]) return;

    UIButton *existing = (UIButton *)[stack viewWithTag:kSCIRailButtonTag];

    // **The other half was hiding by geometry.**
    //
    // `SCITTViewIsCentered` asks whether a rail sits within a quarter of the window's height of
    // its centre. During a scroll two rails satisfy that at once, and at rest the visible one can
    // fail it — so a button appeared twice, or not at all, for reasons no user could see. The
    // guess existed to answer "is this the video on screen", and it was only ever needed because
    // the item came from `[SCITTMedia recent]`, which is whatever model TikTok built most
    // recently — a preloading neighbour as often as the one under the thumb.
    //
    // **A rail can simply be asked which video it belongs to.** Its own responder chain reaches
    // the controller hosting it, and that controller holds the model. Then every rail gets a
    // correct button, an offscreen rail's button is offscreen because its rail is, and no
    // geometric threshold decides anything.
    SCITTMediaItem *item = SCITTItemForRail(stack);

    if (existing) {
        // Visibility follows the rail itself, which is synced separately. Hidden here only when
        // there is genuinely nothing to save.
        existing.hidden = (item == nil);
        if (item) objc_setAssociatedObject(existing, kSCIItemKey, item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        SCITTRaiseRailButton(stack, existing);
        return;
    }

    if (!item) return;

    //
    // **A plain image button was tried three ways and read tilted every time.** Set as
    // the button's own image, `UIButton` positions it through `contentEdgeInsets`,
    // `contentHorizontalAlignment` and its own `imageView` frame -- all of which
    // iOS 15+ reinterprets through `UIButtonConfiguration` whether one was asked for
    // or not, and none of which this project can confirm against TikTok's own rail
    // metrics. Pinning a fixed width made it worse (it fought the stack's own fill
    // alignment); leaving the width free was still off-centre.
    //
    // So the glyph is no longer the button's image at all. It is a separate
    // `UIImageView` centred inside the button by two constraints of this file's own
    // making -- `centerXAnchor` and `centerYAnchor` -- which nothing in `UIButton`'s
    // internal layout or in the stack's alignment can reinterpret. The button itself
    // keeps no intrinsic content, so the stack sizes it purely from the height
    // constraint below and whatever width the fill gives it, and the glyph sits in the
    // middle of that by construction rather than by any alignment property holding.
    //
    // The height is constrained further down, from a sibling's own measured height
    // rather than a number chosen here -- see the placement block.
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.tag = kSCIRailButtonTag;

    // **The look of TikTok's own rail items, because that is what was asked for ("as if it came native").** Measured on the live hierarchy
    // (47.1.0): every item is 80 x 66 with a 32 x 32 icon box at the top (9 pt down), a white glyph with no disc behind it, and a 16-point count
    // label under it at 41 pt, centred on x = 49.67. The blurred disc this button had made it look like an addition; the item below is the same
    // shape as like / comment / bookmark / share: a filled white glyph, and a short caption where they have a count.
    UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:30 weight:UIImageSymbolWeightRegular];
    UIImageView *glyph = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:@"arrow.down.circle.fill" withConfiguration:config]];
    glyph.tintColor = [UIColor whiteColor];
    glyph.contentMode = UIViewContentModeCenter;
    glyph.translatesAutoresizingMaskIntoConstraints = NO;
    glyph.userInteractionEnabled = NO;   // never takes the tap meant for the button
    [button addSubview:glyph];

    UILabel *caption = [[UILabel alloc] init];
    caption.text = SCILocalized(@"rail_download");
    caption.font = [UIFont systemFontOfSize:10.5 weight:UIFontWeightSemibold];   // 'Download' at 13 and at 11.5 ran to the screen edge; TikTok's counts are 3-5 characters
    caption.textColor = [UIColor whiteColor];
    caption.textAlignment = NSTextAlignmentCenter;
    caption.adjustsFontSizeToFitWidth = YES;
    caption.minimumScaleFactor = 0.75;
    caption.translatesAutoresizingMaskIntoConstraints = NO;
    caption.userInteractionEnabled = NO;
    [button addSubview:caption];

    // `left`, not `leading`: TikTok keeps this column on the right of the screen in Arabic as well, and a leading anchor would mirror.
    [NSLayoutConstraint activateConstraints:@[
        [glyph.centerXAnchor constraintEqualToAnchor:button.leftAnchor constant:kSCIRailIconCenterX],
        [glyph.topAnchor constraintEqualToAnchor:button.topAnchor constant:9],
        [glyph.widthAnchor constraintEqualToConstant:32],
        [glyph.heightAnchor constraintEqualToConstant:32],
        [caption.centerXAnchor constraintEqualToAnchor:button.leftAnchor constant:kSCIRailIconCenterX],
        [caption.topAnchor constraintEqualToAnchor:button.topAnchor constant:41],
        [caption.widthAnchor constraintEqualToConstant:60],
        [caption.heightAnchor constraintEqualToConstant:16],
    ]];

    // The same soft shadow TikTok's white glyphs and counts carry over a bright frame.
    for (UIView *piece in @[glyph, caption]) {
        piece.layer.shadowColor = [UIColor blackColor].CGColor;
        piece.layer.shadowOpacity = 0.3;
        piece.layer.shadowRadius = 2;
        piece.layer.shadowOffset = CGSizeMake(0, 1);
    }

    [button addTarget:[SCITTButtonTarget shared]
               action:@selector(tapped:)
     forControlEvents:UIControlEventTouchUpInside];
    SCITTAttachCopyMenu(button);

    objc_setAssociatedObject(button, kSCIItemKey, item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    //
    // **Searching the siblings for "share" cannot work, and a device report is what
    // proved it.** The rail's arranged subviews came back as:
    //
    //   TTKRightInteractionAreaBackgroundView | PlayInteractionLikeView |
    //   TTKRightInteractionAreaBackgroundView ×4
    //
    // TikTok wraps every icon except like in the *same* generically-named background
    // view, so no icon but like can be identified by class name at all. The name search
    // therefore always failed and always fell through to appending at the very end --
    // below the music disc, which is what "way below the picture" was describing. That
    // was a regression this file introduced; the index arithmetic it replaced was
    // closer to right.
    //
    // So: one position before the end. On the six-item rail above that is between the
    // fifth wrapper and the sixth, which is where the button belongs on TikTok's own
    // avatar/like/comment/bookmark/share/disc order. It is still an assumption about
    // that order -- but it is now a *recorded* one, printed in the report beside the
    // rail's real contents, rather than one buried in code.
    //
    NSArray<UIView *> *siblings = stack.arrangedSubviews;
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (UIView *sibling in siblings) {
        [names addObject:NSStringFromClass([sibling class])];
    }
    // Named by which rail it is.
    //
    // Two stack views are hooked and both report into one string, so "appended at end" and
    // the rail contents printed beside it could come from different objects -- which is
    // exactly how a report can show a rail containing PlayInteractionLikeView while also
    // saying the anchor search found nothing. They are separate lines now.
    sciRailContents = [NSString stringWithFormat:@"%@ [%@]",
        [names componentsJoinedByString:@" | "], NSStringFromClass([stack class])];

    // Matched to a sibling's own height rather than a number picked here, so the button
    // occupies the same vertical slot every other icon does instead of whatever 44
    // points happens to look like on this rail.
    // Width as well as height, and this is what "leaning far to the right" was.
    //
    // Only the height was matched. A vertical stack whose alignment is not .fill positions
    // each arranged subview by its own width, so a button sized from its glyph sat at a
    // different horizontal offset from every icon around it -- pushed off to one side by
    // however much narrower or wider than them it happened to be. Nothing about the index
    // could fix that; it is a sizing bug, and the report calling the placement "nice but
    // leaning right" is precisely the shape of one.
    //
    // Both dimensions come from a sibling rather than from numbers chosen here, so the button
    // occupies the same slot TikTok's own icons do on whatever rail it lands in.
    // Tied to the sibling's anchors, not to numbers copied out of its bounds.
    //
    // 0.8.0 read `reference.bounds` and constrained to those constants. **Bounds are zero at
    // this moment** -- the button is created and constrained before the rail has ever been
    // laid out -- so the width fell through to the fallback and the button came out a square
    // narrower than every icon beside it. That is the "still leaning right", and it is the
    // same bug the height had, hidden because the height fallback of 44 happened to be close
    // enough to look deliberate.
    //
    // An anchor constraint is resolved at layout time, whatever the order of construction, so
    // there is no moment at which it can read a size that does not exist yet.
    UIView *reference = siblings.lastObject;

    // **The constraints used to be activated here, and that is what crashed the app.**
    //
    // A constraint between two views is only legal once they share an ancestor. `reference` is
    // already inside the stack; `button` is not added until the placement block below — so
    // activating a width tied to a sibling raised immediately and took TikTok with it. The comment
    // that used to sit here reasoned carefully about *bounds being zero at this moment* and never
    // asked the prior question: **are these two views in the same hierarchy yet?**
    //
    // Both are now activated after insertion, which is the only order in which they can be
    // resolved at all. The sizing intent is unchanged, and it is still anchors rather than numbers
    // copied out of `bounds` — that part was right and stays.
    //
    // And centred inside whatever width it is given, so the glyph sits on the same vertical
    // line as the icons above and below rather than against one edge of its own box.
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    button.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;

    // **Index 0 — above the avatar — and the reason is that every other index is a question
    // about the rail's contents, which differ from video to video.**
    //
    // "Sometimes under the like icon, sometimes above the profile picture" is exactly what the
    // search below it used to produce, and the search was not failing: the rails genuinely differ.
    // A video with a like counter, a live badge, a pinned-comment row or a music disc has a
    // different number of `PlayInteraction*` views and a different number of anonymous
    // `TTKRightInteractionAreaBackgroundView` wrappers around them, so "straight after the last
    // interaction view" names a different height on each one — and the two fallbacks under it
    // named two more. Three code paths, three positions, one button.
    //
    // The top of the stack is the one position that needs nothing to be true about what is in it.
    // TikTok's rail order is avatar first, so index 0 is above the profile picture on every video
    // — which is also where it was asked to be. The anchor search and its "one before last"
    // fallback are both gone rather than kept as a fallback: a fallback here is a second position,
    // and a second position is the bug.
    //
    // **Between bookmark and share, found from the music disc.** NA9 (run in the simulator, 2026-10-29) puts its item exactly there, as an
    // arranged item of the same 80 x 66 shape. The disc is the one item that holds an `AWEPlayInteractionMusicView`, so "the item before the disc"
    // is the share item and the button goes in front of it; counting from the end would be a guess about how many items a rail has.
    NSUInteger insertAt = NSNotFound;
    Class musicClass = NSClassFromString(@"AWEPlayInteractionMusicView");
    for (NSUInteger i = 0; musicClass && i < siblings.count; i++) {
        if (SCITTHoldsClass(siblings[i], musicClass)) { insertAt = i >= 1 ? i - 1 : 0; break; }
    }
    if (insertAt == NSNotFound) insertAt = siblings.count >= 2 ? siblings.count - 2 : siblings.count;
    if ([stack respondsToSelector:@selector(insertArrangedSubview:atIndex:)]) {
        [stack insertArrangedSubview:button atIndex:insertAt];
        sciRailPlacement = [NSString stringWithFormat:@"arranged at index %lu of %lu (before the share item)", (unsigned long)insertAt, (unsigned long)siblings.count];
    } else if ([stack respondsToSelector:@selector(addArrangedSubview:)]) {
        [stack addArrangedSubview:button];
        sciRailPlacement = @"appended (no insertAtIndex:)";
    } else {
        [stack addSubview:button];
        sciRailPlacement = @"plain subview (not arranged)";
    }

    // The resting offset, applied once. A transform survives every layout pass the stack runs, so
    // there is nothing to reapply and nothing to keep in step.
    button.transform = SCITTRailRest();

    // Sized only now that it is in the hierarchy, and only if the insertion actually happened —
    // a constraint to a sibling is meaningless, and fatal, before there is a common ancestor.
    if (button.superview) {
        button.translatesAutoresizingMaskIntoConstraints = NO;

        if (reference && reference.superview == button.superview) {
            [button.widthAnchor constraintEqualToAnchor:reference.widthAnchor].active = YES;
            [button.heightAnchor constraintEqualToAnchor:reference.heightAnchor].active = YES;
        } else {
            // No usable sibling: fixed points, which the stack can satisfy on its own.
            [button.widthAnchor constraintEqualToConstant:44].active = YES;
            [button.heightAnchor constraintEqualToConstant:44].active = YES;
        }
    }

    sciRailButtonsPlaced++;
    SCITTRaiseRailButton(stack, button);

    // **Here, not at the bind.** The date label was placed where the item is attached, which on
    // this path is while the button is still being built -- no superview, no frame, and a label
    // positioned from a rectangle that does not exist yet. This is the line where the button is
    // actually in the hierarchy, which is the same distinction a constraint built from `bounds` at
    // construction time already cost this file once.
    SCITTPlaceDateLabel(button.superview, button, item);
}


///
/// **`-setHidden:` and `-setAlpha:` are hooked because NA9 hooks them, and reading why
/// explained the last remaining complaint.** Those two are in its own symbol table
/// alongside `-layoutSubviews` and `-didMoveToWindow` for both rails — and a tweak has
/// no reason to hook them unless its button's visibility has to be *kept in step with
/// the rail's own*. TikTok hides and fades this rail constantly: while a comment sheet
/// is open, during a long-press, on a live cell, whenever the UI gets out of the video's
/// way. A button that does not follow those transitions is a button that is sometimes
/// there and sometimes not for no reason the user can see — which is precisely the
/// "doesn't show on every video" report, arriving from the app's own behaviour rather
/// than from any failure to place it.
///
/// Placement itself stays where it is: an arranged subview of the rail, so the stack
/// lays it out. What these two add is the rail's own hidden/alpha state being applied to
/// the button on every change, so it appears and fades exactly when its neighbours do.
///
static void SCITTSyncRailButton(UIStackView *stack) {
    UIButton *button = (UIButton *)[stack viewWithTag:kSCIRailButtonTag];
    if (!button) return;

    // **The button's visibility is the rail's visibility, and nothing else decides it.**
    //
    // This used to restore the button only when a geometric test said the rail was near the
    // window's centre — the same guess that made the button come and go — so a fade that TikTok
    // then reversed left the button behind at whatever alpha it had. The rail is the authority: it
    // is hidden exactly when its own icons are, and it belongs to one video by construction.
    button.hidden = stack.isHidden;
    button.alpha = stack.alpha;
    [stack viewWithTag:kSCIFlagTag].alpha = stack.alpha;
}


%group RailA

%hook TTKFeedInteractionStackView

- (void)layoutSubviews {
    %orig;
    SCITTPlaceRailButton(self);
}

- (void)didMoveToWindow {
    %orig;
    SCITTPlaceRailButton(self);
}

- (void)setHidden:(BOOL)hidden {
    %orig;
    SCITTSyncRailButton(self);
}

- (void)setAlpha:(CGFloat)alpha {
    %orig;
    SCITTSyncRailButton(self);
}

%end

%end


%group RailB

%hook TTKFeedRightInteractionStackView

- (void)layoutSubviews {
    %orig;
    SCITTPlaceRailButton(self);
}

- (void)didMoveToWindow {
    %orig;
    SCITTPlaceRailButton(self);
}

- (void)setHidden:(BOOL)hidden {
    %orig;
    SCITTSyncRailButton(self);
}

- (void)setAlpha:(CGFloat)alpha {
    %orig;
    SCITTSyncRailButton(self);
}

%end

%end



///
/// The button on the feed cell itself — which is where NA9 puts its own.
///
/// Its Logos symbols name the technique outright:
/// `AWEFeedViewTemplateCell$na9AddDownloadButton`. **Not the interaction rail.** And every
/// symptom the rail placement produced follows from being a guest in someone else's stack:
///
///   - it appeared on some videos and not others, because TikTok rebuilds the rail's
///     arranged subviews and sweeps a guest out;
///   - it drifted sideways, because a vertical stack positions each child by its own width;
///   - it needed its size copied from neighbours, and those neighbours turned out to be
///     invisible background containers rather than icons.
///
/// A cell hook has none of those problems. `-layoutSubviews` on the cell fires for every
/// video the feed shows, so the button cannot be missing from some of them, and its frame is
/// one this code owns outright.
///
/// `AWEFeedViewTemplateCell` is confirmed present in TikTok 46.4.0 -- checked in the app's
/// own binary, not taken from NA9, whose `AWEFeedViewTemplateNewCell` is **not** in this
/// build. A reference tweak's class list is a map, not a manifest.
///
/// The rail surfaces stay for now and the report counts both separately. Nothing is deleted
/// on the strength of one device until this one is confirmed on it -- and while both are
/// live, the rail stands down whenever a cell button exists, so there is never a second
/// button on screen.
///

// The base surface state, declared up here because the cell group below reads it in order
// to stand down. Declaration before use is not a matter of taste in C, and the compiler
// said so on the first build.
static const NSInteger kSCIBaseButtonTag = 0x5C19;
static NSUInteger sciBaseButtonsPlaced = 0;
static BOOL sciBasePresent = NO;
static BOOL sciBaseWorks = NO;
static NSMutableSet<NSString *> *sciBaseSurfaces = nil;
static NSMutableSet<NSString *> *sciBaseSkipped = nil;
static BOOL sciBaseAnchoredToRail = NO;

static const NSInteger kSCICellButtonTag = 0x5C18;
static NSUInteger sciCellButtonsPlaced = 0;
static BOOL sciCellPresent = NO;

/// Which accessor the cell answered its model through, for the report.
static NSString *sciCellModelVia = nil;

/// YES when the item came from the cell itself rather than from the recent-capture list.
static BOOL sciCellItemFromCell = NO;

/// A hooked class that touches a property needs a real @interface, not the forward
/// declaration Logos leaves behind -- rule 3 in check.py exists for this, and three builds
/// have gone to it in three different shapes.
@interface AWEFeedViewTemplateCell : UICollectionViewCell
@end

%group Cell

%hook AWEFeedViewTemplateCell

- (void)layoutSubviews {
    %orig;

    if (!SCIPrefEnabled(SCIPrefDownloadButton)) return;

    // **Stands down for the rail, which is the owner.** One video, one placer -- that single
    // ownership is the whole reason the reference tweaks are stable and three of ours were not.
    //
    // Still installed rather than deleted, because it is the only surface that needs nothing from
    // TikTok's own column: if a future build renames both rail classes, this keeps a button on
    // screen instead of leaving none.
    if (sciBaseWorks || sciRailIsOwner) return;

    @try {
        UIView *host = self.contentView ?: (UIView *)self;

        UIButton *button = (UIButton *)[host viewWithTag:kSCICellButtonTag];

        if (!button) {
            button = [UIButton buttonWithType:UIButtonTypeSystem];
            button.tag = kSCICellButtonTag;

            UIImageSymbolConfiguration *config =
                [UIImageSymbolConfiguration configurationWithPointSize:27
                                                                weight:UIImageSymbolWeightSemibold];
            [button setImage:[UIImage systemImageNamed:@"arrow.down.circle.fill"
                                     withConfiguration:config]
                    forState:UIControlStateNormal];

            // White with a shadow: the video underneath is arbitrary, and a shadow keeps the
            // glyph readable over a bright frame without a plate competing with TikTok's own
            // icons.
            button.tintColor = [UIColor whiteColor];
            button.layer.shadowColor = [UIColor blackColor].CGColor;
            button.layer.shadowOpacity = 0.45;
            button.layer.shadowRadius = 3;
            button.layer.shadowOffset = CGSizeZero;

            [button addTarget:[SCITTButtonTarget shared]
                       action:@selector(tapped:)
             forControlEvents:UIControlEventTouchUpInside];
            SCITTAttachCopyMenu(button);

            [host addSubview:button];
            sciCellButtonsPlaced++;
            sciCellSurfaceWorks = YES;
        }

        // A frame, not constraints, and computed from the cell's own bounds every pass.
        //
        // Frames because this cell lays its own subviews out by hand and mixing a constraint
        // into that is how the Instagram panel came down twice. Recomputed each pass because
        // the value must not depend on a previous one -- the drifting title in the panel's
        // new row was exactly that mistake, made earlier today.
        CGFloat side = 44;
        CGFloat right = 12;
        CGRect b = host.bounds;
        if (b.size.width <= 0 || b.size.height <= 0) return;

        // Above the profile picture, which is the top of TikTok's rail.
        //
        // 0.62 put it among like/comment/share, below the avatar. Asked for higher: the rail
        // runs avatar, like, comment, bookmark, share, disc from the top down, so clearing the
        // avatar means going above all of them.
        button.frame = CGRectMake(b.size.width - side - right,
                                  b.size.height * 0.38,
                                  side, side);

        [host bringSubviewToFront:button];

        // The model this cell holds -- not the last one captured anywhere.
        //
        // `[SCITTMedia recent].firstObject` is whatever model TikTok most recently built,
        // which during a scroll is a video being preloaded rather than the one under the
        // finger. That is why the same clip saved three times while something else was on
        // screen: the button was correct about *a* video and wrong about *which*.
        //
        // It is the same mistake the Instagram carousel had, fixed earlier the same day by
        // asking the page control which slide was showing instead of assuming. Here the cell
        // itself is the thing that knows.
        //
        // Several accessor names exist in the binary and which one this cell answers is not
        // knowable from a global selector list -- that lesson has already cost this file
        // three releases -- so each is tried behind -respondsToSelector: and **the one that
        // answered is recorded**, so the next report names it instead of leaving it to be
        // guessed again.
        // The cell hosts a view controller, and the model is on that.
        //
        // An unfiltered dump of AWEFeedViewTemplateCell answered this in its first line:
        // `viewController, feedTableViewCellMaskView, interactionConfigClass, pageContext,
        // parentVC, ... setupViewController, layoutViewController, _addChildVC,
        // vcContainerView`. The cell is a **container**. It has no aweme accessor of its own
        // -- which is why every name tried on it answered nothing -- because the video is the
        // controller's, not the cell's.
        //
        // And this is what NA9 has been saying all along: it hooks
        // `AWEAwemeBaseViewController$viewDidLoad` and `$viewDidAppear`, not the cell. Its
        // button lives on the cell and its *model* comes from the controller. Two facts that
        // only made sense together.
        //
        // So the search runs on the cell first (harmless, and cheap if a build ever does put
        // it there) and then on whatever controller the cell is hosting.
        id model = nil;

        NSMutableArray *hosts = [NSMutableArray arrayWithObject:self];
        for (NSString *name in @[@"viewController", @"parentVC"]) {
            SEL selector = NSSelectorFromString(name);
            if (![self respondsToSelector:selector]) continue;
            id host = ((id (*)(id, SEL))objc_msgSend)(self, selector);
            if (host) [hosts addObject:host];
        }

        for (id host in hosts) {
            for (NSString *name in @[@"awemeModel", @"aweme", @"model", @"currentAweme",
                                     @"currentAwemeModel", @"itemModel", @"cellModel"]) {
                SEL selector = NSSelectorFromString(name);
                if (![host respondsToSelector:selector]) continue;

                id candidate = ((id (*)(id, SEL))objc_msgSend)(host, selector);
                if (!candidate) continue;

                // A model, not a string or a number that happens to share the name.
                if (![candidate respondsToSelector:@selector(video)]) continue;

                model = candidate;
                sciCellModelVia = (host == self)
                    ? name
                    : [NSString stringWithFormat:@"%@.%@", NSStringFromClass([host class]), name];
                break;
            }
            if (model) break;
        }

        SCITTMediaItem *item = nil;
        if (model) {
            // The settled entry point: this model came from the cell's own view controller,
            // so it is finished and on screen, and may be asked for the bitrate ladder.
            [SCITTMedia captureSettledModel:(AWEAwemeModel *)model];
            item = [SCITTMedia recent].firstObject;
        }

        // Falls back, and **never hides the button** -- 0.10.0 did both the other way round
        // and shipped a button nobody could see.
        //
        // The reasoning for refusing a fallback was that saving the wrong video is worse than
        // saving none. That is true of the *save*, and it was applied to the *button*: no
        // accessor answered on this build, so `item` was nil on every pass and `hidden` was
        // set on every pass. A correct principle, enforced in the wrong place, removed a
        // working feature outright.
        //
        // So the button is always visible, the cell's own model is used when it can be found,
        // and the most recent capture stands in when it cannot. Which of the two supplied the
        // item is recorded, so "it saved the wrong clip" and "it saved nothing" stay
        // distinguishable in the next report instead of both being a blank button.
        if (!item) {
            item = [SCITTMedia recent].firstObject;
            sciCellItemFromCell = NO;
        } else {
            sciCellItemFromCell = YES;
        }

        if (item) {
            objc_setAssociatedObject(button, kSCIItemKey, item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        button.hidden = NO;

        SCITTPlaceDateLabel(host, button, item);
    } @catch (NSException *exception) {
        // A button is a convenience; the feed is not. Anything thrown here costs the button.
        SCILogV(@"cell button: %@", exception.reason);
    }
}

%end

%end



///
/// One download button, built the same way wherever it lands.
///
/// The rail and the cell each grew their own copy of this. A third copy for the base controller
/// would be a third place to fix a colour, so the new surface uses a shared maker; the two older
/// ones are left exactly as they are, because refactoring code that is working on a device is
/// not what this session is for.
static UIButton *SCITTMakeDownloadButton(void) {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];

    // **A new design, and it is the same design as the banner.** A filled glyph floating with a
    // drop shadow was borrowed from nothing and matched nothing: TikTok's rail is filled white
    // glyphs, so ours disappeared into it, and the download banner it belongs to is a dark
    // blurred capsule. Giving the button that same material makes the two read as one feature
    // instead of two additions by different hands.
    //
    // A disc of blur, a hairline ring, and a plain downward arrow — not the filled circle glyph,
    // which drew a second circle inside the first one.
    UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark];
    UIVisualEffectView *disc = [[UIVisualEffectView alloc] initWithEffect:effect];

    disc.frame = CGRectMake(0, 0, 44, 44);
    disc.layer.cornerRadius = 22;
    disc.layer.cornerCurve = kCACornerCurveContinuous;
    disc.clipsToBounds = YES;

    // The ring is what separates it from a bright video frame, where blur alone goes pale.
    disc.layer.borderWidth = 0.5;
    disc.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.35].CGColor;

    // Never takes the touch — the button underneath must, or the disc would swallow every tap.
    disc.userInteractionEnabled = NO;
    disc.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [button insertSubview:disc atIndex:0];

    UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:17
                                                        weight:UIImageSymbolWeightBold];
    [button setImage:[UIImage systemImageNamed:@"arrow.down" withConfiguration:config]
            forState:UIControlStateNormal];

    button.tintColor = [UIColor whiteColor];

    // A soft shadow under the disc rather than around the glyph: it lifts the whole control off
    // the video without outlining the arrow.
    button.layer.shadowColor = [UIColor blackColor].CGColor;
    button.layer.shadowOpacity = 0.25;
    button.layer.shadowRadius = 6;
    button.layer.shadowOffset = CGSizeMake(0, 2);

    [button addTarget:[SCITTButtonTarget shared]
               action:@selector(tapped:)
     forControlEvents:UIControlEventTouchUpInside];

    // **Pressed state, because the finger should get an answer before the network does.** Even
    // with the banner now showing on the tap, the first acknowledgement a control can give costs
    // no work at all: it shrinks under the thumb and comes back. TikTok's own rail buttons do
    // this, so a button that stayed perfectly still read as dead even when it had fired.
    [button addTarget:[SCITTButtonTarget shared]
               action:@selector(pressed:)
     forControlEvents:UIControlEventTouchDown];

    [button addTarget:[SCITTButtonTarget shared]
               action:@selector(released:)
     forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside |
                      UIControlEventTouchCancel];

    SCITTAttachCopyMenu(button);

    return button;
}

//
// ─────────────────────────────────────────────────────────────────────────────
// The universal surface: one controller every video screen inherits from.
// ─────────────────────────────────────────────────────────────────────────────
//
// **The button was on the feed's cell, so it existed only in the feed.** Opening a video from a
// direct message or from search gave no button at all, which is what the owner reported.
//
// The binary answers where it should live instead, and the answer is one class:
//
//     AWEFeedCellViewController              -> AWEAwemeBaseViewController
//     AWEIMChatRoomVideoDetailCellController -> AWEIMChatRoomDMMediaDetailCellController
//                                            -> AWEAwemeBaseViewController
//     TTKPhotoAlbumFeedCellController        -> AWEAwemeBaseViewController
//
// The feed, direct messages and photo albums are three subclasses of one base — read from the
// class metadata's superclass pointer, not guessed — and that base declares both things this
// needs as typed properties: `model : AWEAwemeModel` and `view : TTKFeedInteractionRootView`.
// NA9's own `na9UniversalDownloadTapped` on this exact class says its author reached the same
// conclusion; the inheritance chain is why, and it is checkable rather than borrowed.
//
// **`-setModel:` is the bind point, not `-viewDidLoad`.** A recycled controller loads its view
// once and is handed a new model for every video after that — the same lesson `-didMoveToWindow`
// cost the X tweak, where buttons appeared on the first screenful and never again.
//
@interface AWEAwemeBaseViewController : UIViewController
@property (nonatomic, strong) AWEAwemeModel *model;
@end



///
/// TikTok's own interaction rail inside a controller's view, or nil.
///
/// **A fraction of the screen height is a guess, and it was wrong the moment the screen
/// changed.** 0.38 clears the avatar in the feed and lands on top of it when a video is opened
/// from search, because that layout is not the feed's. The rail is the thing the button has to
/// clear, so the button is placed relative to *it* — and when it cannot be found, the old
/// fraction still applies rather than the button vanishing.
///
/// Searched by class name rather than by a hardcoded list, because the two rails this project
/// already knows about (`TTKFeedInteractionStackView`, `TTKFeedRightInteractionStackView`) are
/// clearly not the only ones — a third on the search screen would otherwise need finding all
/// over again. Depth-limited: a full walk of a deep hierarchy on every bind is the kind of cost
/// that has already crashed this tweak once.
static UIView *SCITTFindInteractionRail(UIView *view, NSInteger depth) {
    if (!view || depth <= 0) return nil;

    for (UIView *child in view.subviews) {
        NSString *name = NSStringFromClass([child class]);
        if ([name containsString:@"InteractionStackView"] ||
            [name containsString:@"InteractionRail"]) {
            if (child.bounds.size.height > 40) return child;
        }

        UIView *found = SCITTFindInteractionRail(child, depth - 1);
        if (found) return found;
    }
    return nil;
}

static void SCITTPlaceBaseButton(UIViewController *controller) {
    if (!SCIPrefEnabled(SCIPrefDownloadButton)) return;

    // The cell path has been wrapped since it was written; this one was not, and that is why a
    // wrong model class became a crash instead of a missing button. A download button is a
    // convenience and TikTok is not -- nothing in here is worth taking the app down for.
    @try {

    UIView *host = controller.viewIfLoaded;
    if (!host || host.bounds.size.width <= 0 || host.bounds.size.height <= 0) return;

    SEL modelSel = NSSelectorFromString(@"model");
    if (![controller respondsToSelector:modelSel]) return;

    id model = ((id (*)(id, SEL))objc_msgSend)(controller, modelSel);
    if (!model) return;

    // **The class of `model` was assumed, and the DM screen crashed on it.** `model` is declared
    // `AWEAwemeModel` on the base, but a subclass may return something else entirely -- a direct
    // message carries its own model -- and everything downstream sends `-video`, walks a bitrate
    // ladder and reads URL models off it. Handing that a different object is the 0.12.0 crash
    // again, arrived at from a different direction: **a declared property type describes the
    // base, not what every subclass actually returns.**
    //
    // Recorded as well as checked, so a screen that is skipped says which class it had rather
    // than silently having no button.
    if (![model isKindOfClass:NSClassFromString(@"AWEAwemeModel")]) {
        if (!sciBaseSkipped) sciBaseSkipped = [NSMutableSet set];
        [sciBaseSkipped addObject:[NSString stringWithFormat:@"%@ has %@",
            NSStringFromClass([controller class]), NSStringFromClass([model class])]];
        return;
    }

    // Resolved once per model, not once per call. Walking the ladder is not free, and this used
    // to run on every layout pass -- the cost of that was the crash, not a detail of it.
    static const void *kSCIResolvedKey = &kSCIResolvedKey;
    if (objc_getAssociatedObject(controller, kSCIResolvedKey) != model) {
        [SCITTMedia captureSettledModel:(AWEAwemeModel *)model];
        objc_setAssociatedObject(controller, kSCIResolvedKey, model,
                                 OBJC_ASSOCIATION_ASSIGN);
    }

    SCITTMediaItem *item = [SCITTMedia recent].firstObject;
    if (!item) return;

    // Anything an older build's cell surface left behind is removed. An upgrade must not inherit
    // a second button that nothing owns any more.
    //
    // **This was a `while` loop and it froze the app.** `-viewWithTag:` searches the receiver as
    // well as its subviews, so a tagged view that `-removeFromSuperview` does not take out of
    // that search — the host itself, or one re-added by another pass — is found again forever, and
    // a spin on the main thread is killed by the watchdog and reported as a crash. **An
    // unbounded loop over a hierarchy someone else owns is never safe**: the exit condition
    // depends on their code, not ours.
    for (NSInteger sweep = 0; sweep < 4; sweep++) {
        UIView *stale = [host viewWithTag:kSCICellButtonTag];
        if (!stale || stale == host) break;
        [stale removeFromSuperview];
    }

    UIButton *button = (UIButton *)[host viewWithTag:kSCIBaseButtonTag];

    if (!button) {
        button = SCITTMakeDownloadButton();
        button.tag = kSCIBaseButtonTag;
        [host addSubview:button];

        sciBaseButtonsPlaced++;
        sciBaseWorks = YES;

        if (!sciBaseSurfaces) sciBaseSurfaces = [NSMutableSet set];
        [sciBaseSurfaces addObject:NSStringFromClass([controller class])];
    }

    // Recomputed every pass from the host's own bounds, never from the button's last frame:
    // a value derived from its own previous output drifts, which is exactly what the panel's
    // subtitle row did.
    CGFloat side = 44, right = 12, gap = 10;
    CGRect b = host.bounds;

    // Anchored above TikTok's own rail, so the button sits where the rail ends on whatever
    // screen this is — and horizontally centred on the rail, so it lines up with like and share
    // instead of being pinned to an edge the rail does not touch.
    UIView *rail = SCITTFindInteractionRail(host, 6);

    if (rail && rail.bounds.size.height > 0) {
        CGRect frame = [rail convertRect:rail.bounds toView:host];
        CGFloat centreX = CGRectGetMidX(frame) - side / 2;
        CGFloat top = CGRectGetMinY(frame) - side - gap;

        // Never above the safe area, and never off the left edge if the rail sits oddly.
        top = MAX(top, host.safeAreaInsets.top + gap);
        centreX = MAX(0, MIN(centreX, b.size.width - side));

        button.frame = CGRectMake(centreX, top, side, side);
        sciBaseAnchoredToRail = YES;
    } else {
        button.frame = CGRectMake(b.size.width - side - right, b.size.height * 0.38, side, side);
        sciBaseAnchoredToRail = NO;
    }

    [host bringSubviewToFront:button];

    // Re-associated on every bind, because the controller is reused and the button is not:
    // a stale association is how the same clip saved three times while another was on screen.
    objc_setAssociatedObject(button, kSCIItemKey, item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    SCITTPlaceDateLabel(host, button, item);

    } @catch (NSException *exception) {
        SCILogV(@"base button: %@", exception.reason);
    }
}

%group Base

%hook AWEAwemeBaseViewController

- (void)setModel:(id)model {
    %orig;

    // **`-viewDidLayoutSubviews` was hooked here too, and it caused crashes.** Two mistakes in
    // one line: the class does not implement it -- its own method list is `loadView`,
    // `setModel:`, `viewDidLoad` -- and it fires on every layout pass, so the full ladder walk
    // ran continuously on the main thread while scrolling. Hooking a method a class does not
    // declare, at a frequency nobody measured, is the same family of error as the guessed
    // signature that crashed 0.15.1: *check what the class actually has, and how often it runs.*
    //
    // `-setModel:` is declared on this class and fires once per video. Placement is deferred to
    // the next runloop turn because the view may not be loaded at bind time, and asking for it
    // here would build it earlier than TikTok intends.
    __weak UIViewController *controller = (UIViewController *)self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (controller) SCITTPlaceBaseButton(controller);
    });
}

%end

%end

void SCITTInstallButton(void) {
    // **One owner, chosen here, and the others are never installed at all.**
    //
    // The button appeared twice and three times and came and went, because two surfaces were both
    // placing one: the base controller and the feed cell, on different hosts, each looking only
    // for *its own* tag. "Stand down once the other succeeds" cannot fix that — buttons already
    // added stay added, and nothing owns the answer to "is there a button here".
    //
    // **Reading NA9 again settled the architecture, and I had it backwards.**
    // `na9AddDownloadButton` exists on `AWEFeedViewTemplateCell` and `AWEFeedViewTemplateNewCell`
    // — cells, and nothing else. On `AWEAwemeBaseViewController` it has only
    // `na9UniversalDownloadTapped`: a *tap handler*. So the reference places from exactly one kind
    // of object and uses the base class to answer the tap. **That single ownership is why it is
    // stable and this was not.**
    //
    // The base is the placer here rather than the cell, because it is the only one that reaches
    // direct messages and search. The cell and rail surfaces are therefore not installed when it
    // exists — not installed, which is a different thing from standing down.
    // **Not installed. The base surface crashed TikTok three times and it is switched off.**
    //
    // Everything above about ownership and about the inheritance chain is correct and worth
    // keeping — the feed, direct messages and photo albums really are three subclasses of one
    // base, and one owner really is why the references are stable. What is *not* established is
    // that placing a button from inside `-setModel:` on that base is safe on this build, and
    // three attempts each found a new way for it not to be: a hooked method the class does not
    // declare, a model class that is not `AWEAwemeModel` on every subclass, and an unbounded
    // sweep over a hierarchy TikTok owns.
    //
    // **A missing button in direct messages is a smaller cost than an app that dies**, and that
    // is this project's own rule, written down when a crash was traded for SD quality. The cell
    // surface below was stable for many releases and becomes the owner again.
    //
    // Reaching the other screens is still worth doing, and the next attempt should not start from
    // this one: NA9 places from cells and hooks `AWEAwemeDetailViewController` and
    // `AWENewAwemeDetailViewController` for the screens a search or a profile opens. That is a
    // different surface from the base, with a `%hook` per concrete class rather than one on a
    // shared parent — narrower, and each one checkable before it ships.
    //
    // The key is read rather than a constant folded into the branch, because a `%group` that is
    // never `%init`-ed does not compile at all — Logos says so outright — and because a flag in
    // the plist can be turned on to test a fix on one device without shipping it to anyone.
    if (SCIPrefEnabled(SCIPrefBaseSurface) &&
        NSClassFromString(@"AWEAwemeBaseViewController")) {
        %init(Base);
        sciBasePresent = YES;
        sciBaseWorks = YES;
    }

    if (NSClassFromString(@"TTKFeedInteractionStackView")) {
        %init(RailA);
        sciRailPresent = YES;
        sciRailName = @"TTKFeedInteractionStackView";
    }
    if (NSClassFromString(@"TTKFeedRightInteractionStackView")) {
        %init(RailB);
        sciRailPresent = YES;
        sciRailName = sciRailName
            ? [sciRailName stringByAppendingString:@" + TTKFeedRightInteractionStackView"]
            : @"TTKFeedRightInteractionStackView";
    }

    // **Ownership is decided here, before anything is on screen.**
    //
    // If a rail exists it owns the button, because that is what makes it behave like one of
    // TikTok's own: the stack lays it out, so it rides up and down with the column instead of
    // sitting at a fixed spot on the cell that only looks right in the feed. VibeTok does exactly
    // this and nothing else -- its whole button is `TTKFeedInteractionStackView` plus
    // `layoutSubviews`, `buttonTouchDown` and `buttonTouchUp` -- and that narrowness is the
    // stability, not a better technique.
    sciRailIsOwner = sciRailPresent;

    // **One rail class places, not both.** A build carrying both hooks one cell twice, and that is
    // literally where "sometimes two buttons" came from. The right-hand rail is preferred when it
    // exists because it is the column TikTok draws beside the video; the other is the fallback.
    sciRailOwnerClass = NSClassFromString(@"TTKFeedRightInteractionStackView")
        ?: NSClassFromString(@"TTKFeedInteractionStackView");

    // The cell surface, which is where NA9 puts its button. Installed as the fallback for a build
    // with no rail class, and standing down whenever there is one.
    if (NSClassFromString(@"AWEFeedViewTemplateCell")) {
        %init(Cell);
        sciCellPresent = YES;
        SCILogV(@"in-feed button: attached to AWEFeedViewTemplateCell");
    }

    if (sciRailPresent) {
        SCILogV(@"in-feed button: attached to %@", sciRailName);
    } else {
        SCILogV(@"neither interaction rail is in this build — no in-feed button");
    }
}

NSString *SCITTButtonReport(void) {
    if (!sciRailPresent && !sciCellPresent && !sciBasePresent) {
        return @"no button surface in this build";
    }

    // **The base surface leads the line because it is the one that answers the complaint.**
    // "No button in a DM" and "no button in search" are questions about which *screens* got one,
    // and only this line names them — a count alone would have said "3 placed" while two screens
    // had none, which is the shape of report this project has already been misled by.
    NSMutableString *out = [NSMutableString stringWithFormat:@"base %@ — %lu placed",
        sciBasePresent ? @"—" : @"(absent)", (unsigned long)sciBaseButtonsPlaced];

    if (sciBaseSurfaces.count) {
        [out appendFormat:@" on %@",
            [[sciBaseSurfaces allObjects] componentsJoinedByString:@", "]];
    } else if (sciBasePresent) {
        [out appendString:@" — no screen has bound a model yet"];
    }

    [out appendFormat:@"; %@", sciBaseAnchoredToRail
        ? @"anchored above the rail" : @"no rail found — using the height fraction"];

    if (sciBaseSkipped.count) {
        [out appendFormat:@"; skipped %@",
            [[sciBaseSkipped allObjects] componentsJoinedByString:@", "]];
    }

    [out appendFormat:@" | cell %@ %lu placed",
        sciCellPresent ? @"—" : @"(absent)", (unsigned long)sciCellButtonsPlaced];

    if (sciBaseWorks) [out appendString:@" (standing down)"];
    if (sciCellSurfaceWorks) [out appendString:@"; rail standing down"];
    [out appendFormat:@"; model via %@ (%@)",
        sciCellModelVia ?: @"nothing answered",
        sciCellItemFromCell ? @"from cell" : @"fell back to recent"];

    [out appendFormat:@" | rail %@ — %lu placed",
        sciRailName ?: @"(absent)", (unsigned long)sciRailButtonsPlaced];

    [out appendFormat:@"; %@", sciRailPlacement ?: @"not placed yet"];

    if (sciRailContents) [out appendFormat:@"; rail: %@", sciRailContents];

    return out;
}
