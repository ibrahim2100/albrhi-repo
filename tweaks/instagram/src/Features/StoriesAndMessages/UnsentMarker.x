#import <objc/runtime.h>
#import "../../Utils.h"
#import "shared/src/SCIKVC.h"
#import "../../Settings/SCIDiagnosticsViewController.h"

///
/// Marks a message that was kept after its sender unsent it.
///
/// Keeping works by emptying the removal before Instagram applies it, so the message simply
/// stays -- and looks exactly like every other message, which is the whole complaint: nobody can
/// tell which ones were taken back. The mark needs the same message on both sides, and on 410
/// both sides carry its server id, each confirmed from the app's own class metadata:
///
///   held removal   IGDirectMessageUpdateMessageKey { _messageServerId, _messageClientContext }
///                  -- named by a device report, read as fields, so nothing is executed
///   drawn message  IGDirectMessageCell -configureWithViewModel:ringViewSpecFactory:launcherSet:
///                  → viewModel.messageMetadata (IGDirectUIMessageMetadata)
///                  → .key (IGDirectMessageKey) → .serverId / .clientId
///
/// The configure method is the bind point: it fires on first appearance and on every reuse, so
/// a recycled cell is re-asked and a mark never lingers on the wrong message. The ids are kept in
/// the app's own defaults, bounded, so a mark survives closing the app for as long as the message
/// itself does.
///

@interface IGDirectMessageCell : UICollectionViewCell
@end

static NSString * const kSCIUnsentIdsKey = @"sci_unsent_marked_ids";
static const NSInteger kSCIUnsentBadgeTag = 0x5C1D;
static const void *kSCICellMessageIds = &kSCICellMessageIds;

static NSMutableOrderedSet<NSString *> *sMarked = nil;
static NSHashTable *sCells = nil;

static NSMutableOrderedSet<NSString *> *SCIMarked(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSArray *stored = [[NSUserDefaults standardUserDefaults] arrayForKey:kSCIUnsentIdsKey];
        sMarked = [NSMutableOrderedSet orderedSet];
        for (id value in stored) if ([value isKindOfClass:[NSString class]]) [sMarked addObject:value];
        sCells = [NSHashTable weakObjectsHashTable];
    });
    return sMarked;
}

static BOOL SCIIsMarked(NSArray<NSString *> *ids) {
    if (!ids.count) return NO;
    @synchronized (SCIMarked()) {
        for (NSString *value in ids) if ([sMarked containsObject:value]) return YES;
    }
    return NO;
}

/// The ids a drawn message is known by: its server id and, before it is published, its client id.
static NSArray<NSString *> *SCIIdsForViewModel(id viewModel) {
    id metadata = SCISafeValueForKey(viewModel, @"messageMetadata");
    id key = SCISafeValueForKey(metadata, @"key");
    NSMutableArray<NSString *> *ids = [NSMutableArray array];
    for (NSString *name in @[@"serverId", @"clientId"]) {
        id value = SCISafeValueForKey(key, name);
        if ([value isKindOfClass:[NSString class]] && [(NSString *)value length]) [ids addObject:value];
    }
    return ids;
}

static UIView *SCIBubbleOf(UIView *cell) {
    Ivar field = class_getInstanceVariable(object_getClass(cell), "_messageContentContainerView");
    id bubble = field ? object_getIvar(cell, field) : nil;
    if ([bubble isKindOfClass:[UIView class]]) return bubble;
    return [cell isKindOfClass:[UICollectionViewCell class]] ? ((UICollectionViewCell *)cell).contentView : cell;
}

/// Top-trailing corner of the bubble, measured from its bounds *now*.
///
/// Not an autoresizing mask: a cell is configured before it is laid out, so the bubble can be
/// zero wide when the badge is made, and a mask then keeps the badge exactly as far outside the
/// right edge as it started -- off the bubble for good. Re-measured on every layout instead, and
/// written only when it moved, so a second pass costs a comparison and asks for nothing.
static void SCIPlaceMark(UIView *bubble, UIView *badge) {
    if (!badge || badge.hidden) return;
    CGFloat size = CGRectGetWidth(badge.bounds);
    BOOL rtl = (bubble.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft);
    CGFloat x = rtl ? 2 : CGRectGetWidth(bubble.bounds) - size - 2;
    CGRect frame = CGRectMake(MAX(0, x), 2, size, size);
    if (!CGRectEqualToRect(badge.frame, frame)) badge.frame = frame;
}

/// Shows or hides the mark. Built once per bubble and then only toggled, so reuse costs a lookup.
static void SCIApplyMark(UIView *cell, BOOL marked) {
    UIView *bubble = SCIBubbleOf(cell);
    UIView *badge = [bubble viewWithTag:kSCIUnsentBadgeTag];

    if (!marked) {
        badge.hidden = YES;
        return;
    }

    if (!badge) {
        CGFloat size = 20;
        badge = [[UIView alloc] initWithFrame:CGRectMake(0, 0, size, size)];
        badge.tag = kSCIUnsentBadgeTag;
        badge.backgroundColor = [UIColor systemRedColor];
        badge.layer.cornerRadius = size / 2;
        badge.layer.borderColor = [UIColor whiteColor].CGColor;
        badge.layer.borderWidth = 1.5;
        badge.userInteractionEnabled = NO;
        badge.isAccessibilityElement = YES;
        badge.accessibilityLabel = SCILocalized(@"keep_unsent_badge");

        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:9 weight:UIImageSymbolWeightBold];
        UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"trash.fill" withConfiguration:config]];
        icon.tintColor = [UIColor whiteColor];
        icon.center = CGPointMake(size / 2, size / 2);
        [badge addSubview:icon];

        [bubble addSubview:badge];
    }

    badge.hidden = NO;
    [bubble bringSubviewToFront:badge];
    SCIPlaceMark(bubble, badge);
}

/// Called by KeepDeletedMessages.x for every message key it holds back.
void SCIUnsentRememberKey(id key) {
    if (!key) return;

    NSMutableArray<NSString *> *ids = [NSMutableArray array];
    const char *names[] = { "_messageServerId", "_messageClientContext" };
    for (size_t i = 0; i < sizeof(names) / sizeof(names[0]); i++) {
        Ivar field = class_getInstanceVariable(object_getClass(key), names[i]);
        id value = field ? object_getIvar(key, field) : nil;
        if ([value isKindOfClass:[NSString class]] && [(NSString *)value length]) [ids addObject:value];
    }
    if (!ids.count) {
        [SCIDiagnostics privacyCount:@"Unsent · mark: key carried no id"];
        return;
    }

    NSArray *snapshot;
    @synchronized (SCIMarked()) {
        [sMarked addObjectsFromArray:ids];
        // Bounded: a mark is only useful while the message is still on screen somewhere.
        while (sMarked.count > 500) [sMarked removeObjectAtIndex:0];
        snapshot = sMarked.array;
    }
    [[NSUserDefaults standardUserDefaults] setObject:snapshot forKey:kSCIUnsentIdsKey];
    [SCIDiagnostics privacyCount:@"Unsent · messages marked"];

    // A cell already on screen is not configured again just because a removal was refused, so
    // the ones showing these ids are marked now rather than at the next scroll.
    dispatch_async(dispatch_get_main_queue(), ^{
        NSArray *cells;
        @synchronized (SCIMarked()) { cells = sCells.allObjects; }
        for (UIView *cell in cells) {
            NSArray *cellIds = objc_getAssociatedObject(cell, kSCICellMessageIds);
            if (SCIIsMarked(cellIds)) SCIApplyMark(cell, YES);
        }
    });
}

%hook IGDirectMessageCell

- (void)layoutSubviews {
    %orig;

    UIView *bubble = SCIBubbleOf((UIView *)self);
    SCIPlaceMark(bubble, [bubble viewWithTag:kSCIUnsentBadgeTag]);
}

- (void)configureWithViewModel:(id)viewModel ringViewSpecFactory:(id)factory launcherSet:(id)launcherSet {
    %orig;

    UIView *cell = (UIView *)self;
    if (![SCIUtils getBoolPref:@"keep_unsent_messages"]) {
        SCIApplyMark(cell, NO);
        return;
    }

    NSArray<NSString *> *ids = SCIIdsForViewModel(viewModel);
    objc_setAssociatedObject(cell, kSCICellMessageIds, ids, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @synchronized (SCIMarked()) { [sCells addObject:cell]; }

    BOOL marked = SCIIsMarked(ids);
    if (marked) [SCIDiagnostics privacyCount:@"Unsent · marked message drawn"];
    else if (!ids.count) [SCIDiagnostics privacyNote:@"Unsent · mark: last cell without an id"
                                               value:NSStringFromClass([viewModel class]) ?: @"nil"];
    SCIApplyMark(cell, marked);
}

%end
