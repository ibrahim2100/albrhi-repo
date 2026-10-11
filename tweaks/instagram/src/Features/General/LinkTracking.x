#import "../../Utils.h"
#import "SCILinkTracking.h"

///
/// Strip link tracking (`strip_link_tracking`, off until asked for).
///
/// Two doors, because a link leaves Instagram two ways: copied to the pasteboard, and handed to the
/// system share sheet. Both are UIKit calls Instagram makes with the address already built, so
/// this cleans the address on its way out rather than finding the code that builds it -- which is
/// why it needs no Instagram class at all and cannot be broken by an Instagram update.
///
/// Only Instagram's own addresses lose anything, and only the parameters listed in SCILinkTracking.m
/// (the sharer's `igsh` id and the usual campaign tags). A caption copied as text keeps its words;
/// only an Instagram address inside it is cleaned.
///

static BOOL SCIStripLinksOn(void) {
    return [SCIUtils getBoolPref:@"strip_link_tracking"];
}

static id SCICleanedItem(id item) {
    if ([item isKindOfClass:[NSURL class]]) {
        NSString *cleaned = SCIStripTrackingFromURLString(((NSURL *)item).absoluteString);
        return [cleaned isEqualToString:((NSURL *)item).absoluteString] ? item : ([NSURL URLWithString:cleaned] ?: item);
    }
    if ([item isKindOfClass:[NSString class]]) return SCIStripTrackingFromText(item);
    return item;
}

%hook UIPasteboard
- (void)setURL:(NSURL *)url {
    if (SCIStripLinksOn() && url) {
        %orig(SCICleanedItem(url));
        return;
    }
    %orig;
}

- (void)setString:(NSString *)string {
    if (SCIStripLinksOn() && string) {
        %orig(SCICleanedItem(string));
        return;
    }
    %orig;
}
%end

%hook UIActivityViewController
- (instancetype)initWithActivityItems:(NSArray *)items applicationActivities:(NSArray *)activities {
    if (SCIStripLinksOn() && items.count) {
        NSMutableArray *cleaned = [NSMutableArray arrayWithCapacity:items.count];
        for (id item in items) [cleaned addObject:SCICleanedItem(item)];
        return %orig(cleaned, activities);
    }
    return %orig;
}
%end
