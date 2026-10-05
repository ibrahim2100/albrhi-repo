#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "SCITWSpacesBar.h"
#import "Features/Switches/SCITWFeatures.h"
#import "SCILog.h"

///
/// Withheld, not emptied. The setup call is simply not made when the feature is on, so
/// nothing downstream is ever handed a half-built bar — which is the same distinction the
/// Watch tweak paid for: refusing a delivery and feeding nil into a state machine are not
/// the same thing, and the second one crashes.
///

static BOOL sciModernPresent = NO, sciLegacyPresent = NO;
static NSUInteger sciModernHeld = 0, sciLegacyHeld = 0;
static NSUInteger sciModernAsked = 0, sciLegacyAsked = 0;
static BOOL sciGatePresent = NO;
static NSUInteger sciGateAsked = 0, sciGateRefused = 0;

static BOOL sciSpacesOn(void) { return [SCITWFeatures isOnIdentifier:@"spaces"]; }


%group SpacesBarModern

%hook THFHomeTimelineItemsViewController

- (void)_t1_initializeFleets {
    sciModernAsked++;
    if (!sciSpacesOn()) {
        %orig;
        return;
    }
    sciModernHeld++;
}

%end

%end


///
/// The gate both home timelines share.
///
/// **A third way in, found by reading what a tweak written against X 12.31 does.** NeoFreeBird
/// hides this bar by answering `T1FleetLineHeaderController -_t1_shouldShowFleetLine` ("the bar
/// is still the repurposed Fleets line; both home timeline implementations share this
/// visibility gate, re-evaluated on every content or settings update"). The method is in 12.20
/// too (`B16@0:8`), so it is a question X already asks and an answer is not an invention.
/// Withholding `-_t1_initializeFleets` stays where it works; this covers a build where the bar
/// is re-evaluated through the gate instead, and the counters say which of the two did the work.
///
%group SpacesBarGate

%hook T1FleetLineHeaderController

- (BOOL)_t1_shouldShowFleetLine {
    sciGateAsked++;
    BOOL show = %orig;
    if (sciSpacesOn()) {
        if (show) sciGateRefused++;
        show = NO;
    }
    return show;
}

%end

%end


%group SpacesBarLegacy

%hook T1HomeTimelineItemsViewController

- (void)_t1_initializeFleets {
    sciLegacyAsked++;
    if (!sciSpacesOn()) {
        %orig;
        return;
    }
    sciLegacyHeld++;
}

%end

%end


/// Whether a class both exists and declares the method.
///
/// The existence half is not enough on its own. **A `%hook` on a method a class does not
/// declare does not politely do nothing — Logos adds it**, and this tweak would then be
/// inventing an API X never calls, on a class whose superclass may well implement it.
static BOOL SCITWDeclaresFleets(NSString *name) {
    Class cls = NSClassFromString(name);
    if (!cls) return NO;
    return class_getInstanceMethod(cls, NSSelectorFromString(@"_t1_initializeFleets")) != NULL;
}

NSString *SCITWSpacesBarReport(void) {
    if (!sciModernPresent && !sciLegacyPresent && !sciGatePresent) {
        return @"spaces bar: no home timeline class declares _t1_initializeFleets and the fleet-line gate is absent";
    }

    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    if (sciModernPresent) {
        [parts addObject:[NSString stringWithFormat:@"THF asked %lu, held %lu",
                          (unsigned long)sciModernAsked, (unsigned long)sciModernHeld]];
    }
    if (sciLegacyPresent) {
        [parts addObject:[NSString stringWithFormat:@"T1 asked %lu, held %lu",
                          (unsigned long)sciLegacyAsked, (unsigned long)sciLegacyHeld]];
    }
    if (sciGatePresent) {
        [parts addObject:[NSString stringWithFormat:@"gate asked %lu, refused %lu",
                          (unsigned long)sciGateAsked, (unsigned long)sciGateRefused]];
    }
    if (!sciSpacesOn()) [parts addObject:@"feature off"];

    return [@"spaces bar: " stringByAppendingString:
            [parts componentsJoinedByString:@" · "]];
}

void SCITWInstallSpacesBar(void) {
    sciModernPresent = SCITWDeclaresFleets(@"THFHomeTimelineItemsViewController");
    sciLegacyPresent = SCITWDeclaresFleets(@"T1HomeTimelineItemsViewController");

    if (sciModernPresent) {
        %init(SpacesBarModern);
    }
    if (sciLegacyPresent) {
        %init(SpacesBarLegacy);
    }

    Class fleetLine = NSClassFromString(@"T1FleetLineHeaderController");
    Method gate = fleetLine ? class_getInstanceMethod(fleetLine, NSSelectorFromString(@"_t1_shouldShowFleetLine")) : NULL;
    const char *gateEncoding = gate ? method_getTypeEncoding(gate) : NULL;
    sciGatePresent = gateEncoding && strcmp(gateEncoding, "B16@0:8") == 0;
    if (sciGatePresent) {
        %init(SpacesBarGate);
    }

    SCILogV(@"spaces bar: modern %d, legacy %d, gate %d", sciModernPresent, sciLegacyPresent, sciGatePresent);
}
