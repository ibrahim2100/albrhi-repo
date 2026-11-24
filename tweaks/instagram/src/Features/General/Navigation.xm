#import "../../Utils.h"
#import "shared/src/SCIKVC.h"

BOOL isSurfaceShown(IGMainAppSurfaceIntent *surface) {
    BOOL isShown = YES;

    // Feed
    if ([[surface tabStringFromSurfaceIntent] isEqualToString:@"FEED"] && [SCIUtils getBoolPref:@"hide_feed_tab"]) {
        isShown = NO;
    }
    
    // Reels
    else if ([[surface tabStringFromSurfaceIntent] isEqualToString:@"CLIPS"] && [SCIUtils getBoolPref:@"hide_reels_tab"]) {
        isShown = NO;
    }

    // Explore
    else if ([[surface tabStringFromSurfaceIntent] isEqualToString:@"SEARCH"] && [SCIUtils getBoolPref:@"hide_explore_tab"]) {
        isShown = NO;
    }

    // Create
    else if (SCISafeNumberForKey(surface, @"_subtype").unsignedIntegerValue == 3 && [SCIUtils getBoolPref:@"hide_create_tab"]) {
        isShown = NO;
    }

    return isShown;
}

NSArray *filterSurfacesArray(NSArray *surfaces) {
    NSMutableArray *filteredSurfaces = [NSMutableArray array];

    for (IGMainAppSurfaceIntent *surface in surfaces) {
        if (![surface isKindOfClass:%c(IGMainAppSurfaceIntent)]) break;

        if (isSurfaceShown(surface)) {
            [filteredSurfaces addObject:surface];
        }
    }

    return filteredSurfaces;
}

///////////////////////////////////////////////

%hook IGTabBarControllerSwipeCoordinator
- (id)initWithSurfaces:(id)surfaces parentViewController:(id)controller enableHaptics:(_Bool)haptics launcherSet:(id)set {
    // Removes the surface from the main swipeable app collection view
    return %orig(filterSurfacesArray(surfaces), controller, haptics, set);
}
%end

/// Like `filterSurfacesArray`, for an array that may hold anything: only a surface can be filtered out, and an answer that would leave nothing is not used.
static NSArray *SCIFilterNativeSurfaces(NSArray *surfaces) {
    if (![surfaces isKindOfClass:[NSArray class]] || surfaces.count == 0) return surfaces;

    NSMutableArray *kept = [NSMutableArray arrayWithCapacity:surfaces.count];
    for (id item in surfaces) {
        if ([item isKindOfClass:%c(IGMainAppSurfaceIntent)] && !isSurfaceShown(item)) continue;
        [kept addObject:item];
    }
    return kept.count ? kept : surfaces;
}

%hook IGTabBarController

// **On iOS 26 and 27 Instagram 456 draws its tabs with a real `UITabBarController` (the system's Liquid Glass bar).** `IGTabBarController` gained
// `_installOrUpdateNativeTabBarController`, `_usesNativeTabBarController`, `_nativeTabDescriptors` and a Swift `IGNativeTabBarControllerCoordinator`, and
// that bar never goes through `_layoutTabBar` / `_buttonForTabBarSurface:` below, so hiding a tab did nothing on a phone that takes the native path.
// `-_nativeOrderedSurfacesForHorizontalSizeClass:` is where the native bar asks which surfaces it shows (once for each size class), so the filter is
// applied to its answer. **Read from the 456.0.0 class dump (the same method names are what Rocket 4.27.2's tab-bar component loads); not seen on a
// screen** -- the simulator cannot sign in, and a signed-out Instagram has no tab bar.
- (id)_nativeOrderedSurfacesForHorizontalSizeClass:(NSInteger)sizeClass {
    id original = %orig;
    return SCIFilterNativeSurfaces(original);
}

- (void)_layoutTabBar {
    // Prevents the wrong icon from being shown as selected because of mismatched surface array indexes
    NSArray *_tabBarSurfaces = [SCIUtils getIvarForObj:self name:"_tabBarSurfaces"];

    [SCIUtils setIvarForObj:self name:"_tabBarSurfaces" value:filterSurfacesArray(_tabBarSurfaces)];
    
    %orig;
}

- (id)_buttonForTabBarSurface:(id)surface {
    // Prevents the button from being added to the tab bar 
    id button = %orig(surface);

    if (!isSurfaceShown(surface)) {
        return nil;
    }

    return button;
}
%end

// Demangled name: IGNavConfiguration.IGNavConfiguration
%hook _TtC18IGNavConfiguration18IGNavConfiguration
- (NSInteger)tabOrdering {

    if ([[SCIUtils getStringPref:@"nav_icon_ordering"] isEqualToString:@"classic"]) return 0;
    else if ([[SCIUtils getStringPref:@"nav_icon_ordering"] isEqualToString:@"standard"]) return 1;
    else if ([[SCIUtils getStringPref:@"nav_icon_ordering"] isEqualToString:@"alternate"]) return 2;

    return %orig;

}
- (void)setTabOrdering:(NSInteger)arg1 {
    return;
}

- (BOOL)isTabSwipingEnabled {

    if ([[SCIUtils getStringPref:@"swipe_nav_tabs"] isEqualToString:@"enabled"]) return YES;
    else if ([[SCIUtils getStringPref:@"swipe_nav_tabs"] isEqualToString:@"disabled"]) return NO;

    return %orig;

}
- (void)setIsTabSwipingEnabled:(BOOL)arg1 {
    return;
}
%end