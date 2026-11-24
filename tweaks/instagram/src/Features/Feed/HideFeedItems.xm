#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../../Compat/SCIResolve.h"

static NSArray *removeItemsInList(NSArray *list, BOOL isFeed) {
    NSArray *originalObjs = list;
    NSMutableArray *filteredObjs = [NSMutableArray arrayWithCapacity:[originalObjs count]];

    for (id obj in originalObjs) {
        // Remove suggested posts
        if (isFeed && [SCIUtils getBoolPref:@"no_suggested_post"]) {

            // Posts
            if (
                ([obj isKindOfClass:%c(IGMedia)] && [((IGMedia *)obj).explorePostInFeed isEqual:@YES])
                || ([obj isKindOfClass:%c(IGFeedGroupHeaderViewModel)] && [[obj title] isEqualToString:@"Suggested Posts"])
            ) {
                SCILogV(@"[SCInsta] Removing suggested posts");

                continue;
            }

            // Suggested stories (carousel)
            if ([obj isKindOfClass:%c(IGInFeedStoriesTrayModel)]) {
                SCILogV(@"[SCInsta] Hiding suggested stories carousel");

                continue;
            }

        }

        // Remove suggested reels (carousel)
        if (isFeed && [SCIUtils getBoolPref:@"no_suggested_reels"]) {
            if ([obj isKindOfClass:%c(IGFeedScrollableClipsModel)]) {
                SCILogV(@"[SCInsta] Hiding suggested reels carousel");

                continue;
            }
        }
        
        // Remove suggested for you (accounts)
        if ([SCIUtils getBoolPref:@"no_suggested_account"]) {
            
            // Feed
            if (isFeed && [obj isKindOfClass:%c(IGHScrollAYMFModel)]) {
                SCILogV(@"[SCInsta] Hiding accounts suggested for you (feed)");

                continue;
            }

            // Reels
            if ([obj isKindOfClass:%c(IGSuggestedUserInReelsModel)]) {
                SCILogV(@"[SCInsta] Hiding accounts suggested for you (reels)");

                continue;
            }
        }

        // Remove suggested threads posts
        if ([SCIUtils getBoolPref:@"no_suggested_threads"]) {

            // Feed (carousel)
            if (isFeed) {
                if ([obj isKindOfClass:%c(IGBloksFeedUnitModel)] || [obj isKindOfClass:objc_getClass("IGThreadsInFeedModels.IGThreadsInFeedModel")]) {
                    SCILogV(@"[SCInsta] Hiding suggested threads posts (carousel)");

                    continue;
                }
            }

            // Reels
            if ([obj isKindOfClass:%c(IGSundialNetegoItem)]) {
                SCILogV(@"[SCInsta] Hiding suggested threads posts (reels)");

                continue;
            }

        }        

        // Remove story tray
        if (isFeed && [SCIUtils getBoolPref:@"hide_stories_tray"]) {
            if ([obj isKindOfClass:%c(IGStoryDataController)]) {
                SCILogV(@"[SCInsta] Hiding stories tray");

                continue;
            }
        }

        // Hide entire feed
        if (isFeed && [SCIUtils getBoolPref:@"hide_entire_feed"]) {
            if ([obj isKindOfClass:%c(IGPostCreationManager)] || [obj isKindOfClass:%c(IGMedia)] || [obj isKindOfClass:%c(IGEndOfFeedDemarcatorModel)] || [obj isKindOfClass:%c(IGSpinnerLabelViewModel)]) {
                SCILogV(@"[SCInsta] Hiding entire feed");

                continue;
            }
        }

        // Remove ads
        if ([SCIUtils getBoolPref:@"hide_ads"]) {
            if (
                ([obj isKindOfClass:%c(IGFeedItem)] && ([obj isSponsored] || [obj isSponsoredApp]))
                || ([obj isKindOfClass:%c(IGDiscoveryGridItem)] && [[obj model] isKindOfClass:%c(IGAdItem)])
                || [obj isKindOfClass:%c(IGAdItem)]
            ) {
                SCILogV(@"[SCInsta] Removing ads");

                continue;
            }
        }

        [filteredObjs addObject:obj];
    }

    return [filteredObjs copy];
}

// Suggested posts/reels
%hook IGMainFeedListAdapterDataSource
- (NSArray *)objectsForListAdapter:(id)arg1 {
    NSArray *originalObjs = %orig(arg1);
    NSArray *filteredObjs = removeItemsInList(originalObjs, YES);

    // Remove loading spinner at end of feed (if 5 or less items in feed)
    NSUInteger arrayLength = [filteredObjs count];

    if (arrayLength <= 5) {
        filteredObjs = [filteredObjs filteredArrayUsingPredicate:
            [NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *bindings) {
                return ![obj isKindOfClass:[%c(IGSpinnerLabelViewModel) class]];
            }]
        ];
    }

    return filteredObjs;
}
%end
%group SCIgIGSundialFeedDataSource

%hook IGSundialFeedDataSource
- (NSArray *)objectsForListAdapter:(id)arg1 {
    NSArray *originalObjs = %orig(arg1);
    return removeItemsInList(originalObjs, NO);
}
%end

%end

%group SCIgIGContextualFeedViewController

%hook IGContextualFeedViewController
- (NSArray *)objectsForListAdapter:(id)arg1 {
    if ([SCIUtils getBoolPref:@"hide_ads"]) {
        NSArray *originalObjs = %orig(arg1);
        return removeItemsInList(originalObjs, NO);
    }

    return %orig;
}
%end

%end

%hook IGVideoFeedViewController
- (NSArray *)objectsForListAdapter:(id)arg1 {
    if ([SCIUtils getBoolPref:@"hide_ads"]) {
        NSArray *originalObjs = %orig(arg1);
        return removeItemsInList(originalObjs, NO);
    }

    return %orig;
}
%end
%group SCIgIGChainingFeedViewController

%hook IGChainingFeedViewController
- (NSArray *)objectsForListAdapter:(id)arg1 {
    if ([SCIUtils getBoolPref:@"hide_ads"]) {
        NSArray *originalObjs = %orig(arg1);
        return removeItemsInList(originalObjs, NO);
    }

    return %orig;
}
%end

%end

%hook IGStoryAdPool
- (id)initWithUserSession:(id)arg1 {
    if ([SCIUtils getBoolPref:@"hide_ads"]) {
        SCILogV(@"[SCInsta] Removing ads");

        return nil;
    }

    return %orig;
}
%end
%group SCIgIGStoryAdsManager

%hook IGStoryAdsManager
- (id)initWithUserSession:(id)arg1 storyViewerLoggingContext:(id)arg2 storyFullscreenSectionLoggingContext:(id)arg3 viewController:(id)arg4 {
    if ([SCIUtils getBoolPref:@"hide_ads"]) {
        SCILogV(@"[SCInsta] Removing ads");

        return nil;
    }

    return %orig;
}
%end

%end

%hook IGStoryAdsFetcher
- (id)initWithUserSession:(id)arg1 delegate:(id)arg2 {
    if ([SCIUtils getBoolPref:@"hide_ads"]) {
        SCILogV(@"[SCInsta] Removing ads");

        return nil;
    }

    return %orig;
}
%end
// IG 148.0
%hook IGStoryAdsResponseParser
- (id)parsedObjectFromResponse:(id)arg1 {
    if ([SCIUtils getBoolPref:@"hide_ads"]) {
        SCILogV(@"[SCInsta] Removing ads");

        return nil;
    }

    return %orig;
}
- (id)initWithReelStore:(id)arg1 {
    if ([SCIUtils getBoolPref:@"hide_ads"]) {
        SCILogV(@"[SCInsta] Removing ads");

        return nil;
    }

    return %orig;
}
%end
%group SCIgIGStoryAdsOptInTextView
%hook IGStoryAdsOptInTextView
// 450.1.0 / 456.0.0 (Swift class `_TtC12IGStoryAdsUI23IGStoryAdsOptInTextView`): a third argument was added.
- (id)initWithBrandedContentStyledString:(id)arg1 sponsoredPostLabel:(id)arg2 adTransparencyDisclaimerStyledString:(id)arg3 {
    if ([SCIUtils getBoolPref:@"hide_ads"]) {
        SCILogV(@"[SCInsta] Removing ads");

        return nil;
    }

    return %orig;
}
- (id)initWithBrandedContentStyledString:(id)arg1 sponsoredPostLabel:(id)arg2 {
    if ([SCIUtils getBoolPref:@"hide_ads"]) {
        SCILogV(@"[SCInsta] Removing ads");

        return nil;
    }

    return %orig;
}
%end
%end

%hook IGSundialAdsResponseParser
- (id)parsedObjectFromResponse:(id)arg1 {
    if ([SCIUtils getBoolPref:@"hide_ads"]) {
        SCILogV(@"[SCInsta] Removing ads");

        return nil;
    }

    return %orig;
}
- (id)initWithMediaStore:(id)arg1 userStore:(id)arg2 {
    if ([SCIUtils getBoolPref:@"hide_ads"]) {
        SCILogV(@"[SCInsta] Removing ads");
        
        return nil;
    }
    
    return %orig;
}
%end
// "Sponsored" posts on discover/search page
%group SCIgIGExploreListKitDataSource

%hook IGExploreListKitDataSource
- (NSArray *)objectsForListAdapter:(id)arg1 {
    if ([SCIUtils getBoolPref:@"hide_ads"]) {
        NSArray *originalObjs = %orig(arg1);
        return removeItemsInList(originalObjs, NO);
    }

    return %orig;
}
%end

%end

// Demangled name: IGExploreViewControllerSwift.IGExploreListKitDataSource
%hook _TtC28IGExploreViewControllerSwift26IGExploreListKitDataSource
- (NSArray *)objectsForListAdapter:(id)arg1 {
    if ([SCIUtils getBoolPref:@"hide_ads"]) {
        NSArray *originalObjs = %orig(arg1);
        return removeItemsInList(originalObjs, NO);
    }

    return %orig;
}
%end

// Hide shopping carousel in reel comments
// Demangled name: IGCommentThreadCommerceCarouselPill.IGCommentThreadCommerceCarousel
%hook _TtC35IGCommentThreadCommerceCarouselPill31IGCommentThreadCommerceCarousel
- (id)initWithFrame:(CGRect)frame pillText:(id)text pillStyle:(NSInteger)style {
    if ([SCIUtils getBoolPref:@"hide_ads"]) {
        return nil;
    }

    return %orig(frame, text, style);
}
%end

// Hide suggested search/shopping on reels

// Demangled name: IGShoppableEverythingCommon.IGRapEntrypointResolver
%hook _TtC27IGShoppableEverythingCommon23IGRapEntrypointResolver
- (id)initWithLauncherSet:(id)arg1 {
    if ([SCIUtils getBoolPref:@"hide_ads"]) {
        return nil;
    }

    return %orig(arg1);
}
%end
// Demangled name: IGSundialOrganicCTAContainerView.IGSundialOrganicCTAContainerView
%hook _TtC32IGSundialOrganicCTAContainerView32IGSundialOrganicCTAContainerView
- (void)didMoveToWindow {
    %orig;

    if ([SCIUtils getBoolPref:@"hide_ads"]) {
        [self removeFromSuperview];
    }
}
%end


// Hide "suggested for you" text at end of feed
%hook IGEndOfFeedDemarcatorCellTopOfFeed
- (void)configureWithViewConfig:(id)arg1 {
    %orig;

    if ([SCIUtils getBoolPref:@"no_suggested_post"]) {
        SCILogV(@"[SCInsta] Hiding end of feed message");

        // Hide suggested for you text
        UILabel *_titleLabel = MSHookIvar<UILabel *>(self, "_titleLabel");

        if (_titleLabel != nil) {
            [_titleLabel setText:@""];
        }
    }

    return;
}
%end

%ctor {
    // The hooks outside the groups below. Logos writes this call itself for
    // a file with no %ctor -- and stops the moment there is one, so leaving
    // it out would silence every hook this file did not need to convert.
    %init;

    Class sundialFeedDataSource = SCIResolveClass(@"IGSundialFeedDataSource");
    if (sundialFeedDataSource) %init(SCIgIGSundialFeedDataSource, IGSundialFeedDataSource = sundialFeedDataSource);
    Class contextualFeedViewController = SCIResolveClass(@"IGContextualFeedViewController");
    if (contextualFeedViewController) %init(SCIgIGContextualFeedViewController, IGContextualFeedViewController = contextualFeedViewController);
    Class chainingFeedViewController = SCIResolveClass(@"IGChainingFeedViewController");
    if (chainingFeedViewController) %init(SCIgIGChainingFeedViewController, IGChainingFeedViewController = chainingFeedViewController);
    Class storyAdsManager = SCIResolveClass(@"IGStoryAdsManager");
    if (storyAdsManager) %init(SCIgIGStoryAdsManager, IGStoryAdsManager = storyAdsManager);
    Class storyAdsOptIn = SCIResolveClass(@"IGStoryAdsOptInTextView");
    if (storyAdsOptIn) %init(SCIgIGStoryAdsOptInTextView, IGStoryAdsOptInTextView = storyAdsOptIn);
    Class exploreListKitDataSource = SCIResolveClass(@"IGExploreListKitDataSource");
    if (exploreListKitDataSource) %init(SCIgIGExploreListKitDataSource, IGExploreListKitDataSource = exploreListKitDataSource);
}
