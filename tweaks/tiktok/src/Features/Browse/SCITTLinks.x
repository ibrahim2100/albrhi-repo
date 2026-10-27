//
//  SCITTLinks.x
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "SCITTLinks.h"
#import "../../Prefs.h"
#import "../../SCILog.h"

///
/// **Links in Safari, rebuilt from where the reference actually intercepts.**
///
/// The first version (0.26.0) hooked two selectors of one class, `AWEThirdWebModuleServiceImpl`, and did nothing on a phone. Reading what
/// ASJTok does with REA showed why, and showed three things the first version did not have:
///
///   1. **The doors.** It does not wait for TikTok to ask "browser or system?". It intercepts where the address enters: the four
///      `-[GBLRouterImpl openURLString:…]`, the three `-[AWE3rdWebContainerService openURL:…]`, and -- as a net under both -- every
///      `-[WKWebView loadRequest:]` of an external host. When the address is an http(s) one it opens it with `UIApplication` and
///      **swallows the call** (the original never runs).
///   2. **The wrapper.** A link TikTok shows people is often not the address itself but TikTok's link-safety redirect: a host containing
///      `tiktoklinksafety`, or a path beginning `/link/`, with the real address in a query item (percent-encoded, starting `http`).
///      That is a tiktok.com address, so a test of "is this foreign" on the wrapper says no and the page stays in TikTok -- which is
///      exactly what 0.26.0's `-isThirdHttpURL:` gate would have done. The wrapper is opened and the target taken.
///   3. **Who is foreign.** Nine hosts the reference treats as TikTok's own (`tiktokv.com`, `tiktokcdn.com`, `byteoversea.com`,
///      `bytedance.com`, `musical.ly`, `ttwstatic.com`, `ibytedtos.com`, `tiktokglobalshop.com`, `capcut.com`); this file adds
///      `tiktok.com`, because an address inside TikTok must stay inside TikTok -- the reference sends even those to Safari.
///
/// Read in the 47.1.0 binary: `PHFDfidRouterServiceImpl` declares its **own** `-shouldOpenURLInIAB:`, `-tryOpenURL:dataflowId:` and
/// `-tryOpenURLString:dataflowId:` (the same decision as `AWEThirdWebModuleServiceImpl`'s, and `-shouldOpenURLInIAB:` is called from its
/// `-tryOpenURL:dataflowId:`), which 0.26.0 never touched. Both are hooked now.
///
/// **What this machine cannot say** is which door a link in a bio or a comment really takes (the caller scan of the router names live-room
/// components and `TPPieceParser handleClickableStringPiece:…`, which is where clickable text is built). So every door counts, and a foreign
/// address that a web view loads without any door having caught it is recorded with its class chain. **Not run on a device.**
///

static NSString *sciLinksState = nil;
static NSMutableDictionary<NSString *, NSNumber *> *sciLinkDoors = nil;
static NSString *sciLinkLastHost = nil, *sciLinkLastDoor = nil, *sciLinkLastMiss = nil;
static NSUInteger sciLinkUnwrapped = 0, sciLinkWrapperNoTarget = 0, sciLinkKept = 0;
static NSString *sciLinkRecentURL = nil;
static CFAbsoluteTime sciLinkRecentAt = 0;

static BOOL SCITTLinksHas(Class cls, const char *selector, const char *encoding) {
    if (!cls) return NO;
    Method method = class_getInstanceMethod(cls, sel_registerName(selector));
    const char *types = method ? method_getTypeEncoding(method) : NULL;
    return types && strcmp(types, encoding) == 0;
}

static BOOL SCITTHostIsTikTokOwned(NSString *host) {
    static NSArray<NSString *> *suffixes;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        suffixes = @[@"tiktok.com", @"tiktokv.com", @"tiktokcdn.com", @"byteoversea.com", @"bytedance.com", @"musical.ly",
                     @"ttwstatic.com", @"ibytedtos.com", @"tiktokglobalshop.com", @"capcut.com"];
    });
    NSString *lower = host.lowercaseString;
    for (NSString *suffix in suffixes) {
        if ([lower isEqualToString:suffix] || [lower hasSuffix:[@"." stringByAppendingString:suffix]]) return YES;
    }
    return NO;
}

/// The address behind TikTok's link-safety redirect, or the address itself.
static NSURL *SCITTUnwrap(NSURL *url) {
    NSString *host = url.host.lowercaseString ?: @"";
    BOOL wrapper = [host containsString:@"tiktoklinksafety"] || [url.path hasPrefix:@"/link/"];
    if (!wrapper) return url;

    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    for (NSURLQueryItem *item in components.queryItems) {
        NSString *value = item.value;
        if (value.length <= 7) continue;
        NSString *decoded = value.stringByRemovingPercentEncoding ?: value;
        if (![decoded hasPrefix:@"http"]) continue;
        NSURL *target = [NSURL URLWithString:decoded];
        if (target) {
            sciLinkUnwrapped++;
            return target;
        }
    }
    sciLinkWrapperNoTarget++;
    return url;
}

/// The foreign http(s) address an argument stands for, or nil when it is TikTok's own, not a web address, or not an address at all.
static NSURL *SCITTForeignTarget(id argument) {
    NSURL *url = nil;
    if ([argument isKindOfClass:[NSURL class]]) url = argument;
    else if ([argument isKindOfClass:[NSString class]] && [(NSString *)argument length]) url = [NSURL URLWithString:argument];
    if (!url) return nil;

    url = SCITTUnwrap(url);
    NSString *scheme = url.scheme.lowercaseString;
    if (!([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"])) return nil;
    if (!url.host.length || SCITTHostIsTikTokOwned(url.host)) {
        sciLinkKept++;
        return nil;
    }
    return url;
}

static void SCITTSendToSafari(NSURL *url, NSString *door) {
    if (!sciLinkDoors) sciLinkDoors = [NSMutableDictionary dictionary];
    sciLinkDoors[door] = @(sciLinkDoors[door].unsignedIntegerValue + 1);
    sciLinkLastDoor = door;
    sciLinkLastHost = url.host;

    // Two doors can be walked by one tap (a router that calls a container); the first swallows, but a service that decides and then asks
    // again would open the page twice. The same address within a second is one request.
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if ([sciLinkRecentURL isEqualToString:url.absoluteString] && now - sciLinkRecentAt < 1.0) return;
    sciLinkRecentURL = url.absoluteString;
    sciLinkRecentAt = now;

    dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    });
}

/// The controller a view is inside, nearest first.
static UIViewController *SCITTControllerOf(UIView *view) {
    UIResponder *responder = view;
    for (NSInteger i = 0; responder && i < 30; i++, responder = responder.nextResponder) {
        if ([responder isKindOfClass:[UIViewController class]]) return (UIViewController *)responder;
    }
    return nil;
}

static void SCITTCloseBrowser(UIViewController *controller) {
    if (!controller) return;
    UINavigationController *navigation = controller.navigationController;
    if (navigation && navigation.topViewController == controller && navigation.viewControllers.count > 1) {
        [navigation popViewControllerAnimated:NO];
    } else if (controller.presentingViewController) {
        [controller dismissViewControllerAnimated:NO completion:nil];
    }
}

/// Whether a controller is TikTok's browser for foreign pages, by its class name. Payment, wallet, sign-in and similar pages load foreign
/// hosts on purpose and are never redirected.
static BOOL SCITTIsBrowserController(UIViewController *controller) {
    if (!controller) return NO;
    NSString *name = NSStringFromClass([controller class]);
    for (NSString *denied in @[@"Pay", @"Wallet", @"Checkout", @"Venmo", @"Auth", @"Login", @"Autofill", @"Shopify", @"Report",
                               @"Donation", @"Survey", @"Game", @"Creator", @"Live", @"Anchor", @"POI"]) {
        if ([name rangeOfString:denied].location != NSNotFound) return NO;
    }
    for (NSString *allowed in @[@"WebContainer", @"WebViewController", @"Browser", @"SparkViewController"]) {
        if ([name rangeOfString:allowed].location != NSNotFound) return YES;
    }
    return NO;
}

#pragma mark - The router

%group SCITTLinksRouter
%hook GBLRouterImpl

- (void)openURLString:(id)string {
    NSURL *target = SCIPrefEnabled(SCIPrefOpenInSafari) ? SCITTForeignTarget(string) : nil;
    if (target) { SCITTSendToSafari(target, @"router openURLString:"); return; }
    %orig;
}

- (void)openURLString:(id)string fromInside:(BOOL)inside completion:(id)completion {
    NSURL *target = SCIPrefEnabled(SCIPrefOpenInSafari) ? SCITTForeignTarget(string) : nil;
    if (target) { SCITTSendToSafari(target, @"router …fromInside:completion:"); return; }
    %orig;
}

- (void)openURLString:(id)string fromInside:(BOOL)inside fromViewController:(id)controller completion:(id)completion {
    NSURL *target = SCIPrefEnabled(SCIPrefOpenInSafari) ? SCITTForeignTarget(string) : nil;
    if (target) { SCITTSendToSafari(target, @"router …fromViewController:"); return; }
    %orig;
}

- (void)openURLString:(id)string userInfo:(id)info fromInside:(BOOL)inside fromViewController:(id)controller
           completion:(id)completion onWillDismiss:(id)dismiss {
    NSURL *target = SCIPrefEnabled(SCIPrefOpenInSafari) ? SCITTForeignTarget(string) : nil;
    if (target) { SCITTSendToSafari(target, @"router …userInfo:"); return; }
    %orig;
}

%end
%end

#pragma mark - The web container service

%group SCITTLinksContainer
%hook AWE3rdWebContainerService

- (void)openURL:(id)url configuration:(id)configuration {
    NSURL *target = SCIPrefEnabled(SCIPrefOpenInSafari) ? SCITTForeignTarget(url) : nil;
    if (target) { SCITTSendToSafari(target, @"container openURL:configuration:"); return; }
    %orig;
}

- (void)openURL:(id)url dataflowId:(unsigned long long)dataflowId {
    NSURL *target = SCIPrefEnabled(SCIPrefOpenInSafari) ? SCITTForeignTarget(url) : nil;
    if (target) { SCITTSendToSafari(target, @"container openURL:dataflowId:"); return; }
    %orig;
}

- (void)openURL:(id)url fallback:(id)fallback {
    NSURL *target = SCIPrefEnabled(SCIPrefOpenInSafari) ? SCITTForeignTarget(url) : nil;
    if (target) { SCITTSendToSafari(target, @"container openURL:fallback:"); return; }
    %orig;
}

- (void)openURL:(id)url dataflowId:(unsigned long long)dataflowId fallback:(id)fallback {
    NSURL *target = SCIPrefEnabled(SCIPrefOpenInSafari) ? SCITTForeignTarget(url) : nil;
    if (target) { SCITTSendToSafari(target, @"container openURL:dataflowId:fallback:"); return; }
    %orig;
}

%end
%end

#pragma mark - The two services that choose between the browser and the system

%group SCITTLinksThirdWeb
%hook AWEThirdWebModuleServiceImpl

- (BOOL)shouldOpenURLInIAB:(id)url {
    if (SCIPrefEnabled(SCIPrefOpenInSafari) && SCITTForeignTarget(url)) return NO;
    return %orig;
}

- (BOOL)tryOpenURL:(id)url dataflowId:(id)dataflowId {
    NSURL *target = SCIPrefEnabled(SCIPrefOpenInSafari) ? SCITTForeignTarget(url) : nil;
    if (target) { SCITTSendToSafari(target, @"third-web tryOpenURL:"); return YES; }
    return %orig;
}

- (BOOL)tryOpenURLString:(id)string dataflowId:(id)dataflowId {
    NSURL *target = SCIPrefEnabled(SCIPrefOpenInSafari) ? SCITTForeignTarget(string) : nil;
    if (target) { SCITTSendToSafari(target, @"third-web tryOpenURLString:"); return YES; }
    return %orig;
}

%end
%end

%group SCITTLinksDfid
%hook PHFDfidRouterServiceImpl

- (BOOL)shouldOpenURLInIAB:(id)url {
    if (SCIPrefEnabled(SCIPrefOpenInSafari) && SCITTForeignTarget(url)) return NO;
    return %orig;
}

- (BOOL)tryOpenURL:(id)url dataflowId:(id)dataflowId {
    NSURL *target = SCIPrefEnabled(SCIPrefOpenInSafari) ? SCITTForeignTarget(url) : nil;
    if (target) { SCITTSendToSafari(target, @"dfid tryOpenURL:"); return YES; }
    return %orig;
}

- (BOOL)tryOpenURLString:(id)string dataflowId:(id)dataflowId {
    NSURL *target = SCIPrefEnabled(SCIPrefOpenInSafari) ? SCITTForeignTarget(string) : nil;
    if (target) { SCITTSendToSafari(target, @"dfid tryOpenURLString:"); return YES; }
    return %orig;
}

%end
%end

#pragma mark - TikTok's Safari-view wrapper

@interface AWESafariViewController : UIViewController
- (id)requestURL;
- (id)lastURLString;
@end

%group SCITTLinksSafariView
%hook AWESafariViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!SCIPrefEnabled(SCIPrefOpenInSafari)) return;

    NSURL *target = SCITTForeignTarget([self requestURL]) ?: SCITTForeignTarget([self lastURLString]);
    if (!target) return;
    SCITTSendToSafari(target, @"safari-view viewDidAppear:");
    SCITTCloseBrowser(self);
}

%end
%end

#pragma mark - The net: a web view asked to load a foreign host

%group SCITTLinksWebView
%hook WKWebView

- (id)loadRequest:(NSURLRequest *)request {
    if (!SCIPrefEnabled(SCIPrefOpenInSafari)) return %orig;

    NSURL *target = SCITTForeignTarget(request.URL);
    if (!target) return %orig;

    UIViewController *owner = SCITTControllerOf(self);
    if (SCITTIsBrowserController(owner)) {
        SCITTSendToSafari(target, @"web view loadRequest:");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            SCITTCloseBrowser(owner);
        });
        return nil;
    }

    // A foreign address in a web view that is not one of the browsers: left alone, and named, so the next report says which door it was.
    NSMutableArray<NSString *> *chain = [NSMutableArray array];
    UIResponder *responder = self;
    for (NSInteger i = 0; responder && i < 6; i++, responder = responder.nextResponder) [chain addObject:NSStringFromClass([responder class])];
    sciLinkLastMiss = [NSString stringWithFormat:@"%@ in %@", target.host, [chain componentsJoinedByString:@" < "]];
    return %orig;
}

%end
%end

NSString *SCITTLinksReport(void) {
    NSMutableArray<NSString *> *doors = [NSMutableArray array];
    for (NSString *door in [sciLinkDoors.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        [doors addObject:[NSString stringWithFormat:@"%@ %@", door, sciLinkDoors[door]]];
    }
    return [NSString stringWithFormat:@"%@; handed to Safari: %@; link-safety wrappers opened %lu (without a target %lu); kept in TikTok %lu; last: %@ via %@%@",
            sciLinksState ?: @"not installed",
            doors.count ? [doors componentsJoinedByString:@", "] : @"none yet",
            (unsigned long)sciLinkUnwrapped, (unsigned long)sciLinkWrapperNoTarget, (unsigned long)sciLinkKept,
            sciLinkLastHost ?: @"—", sciLinkLastDoor ?: @"—",
            sciLinkLastMiss ? [@"; a web view loaded a foreign address no door caught: " stringByAppendingString:sciLinkLastMiss] : @""];
}

void SCITTInstallLinks(void) {
    NSMutableArray<NSString *> *installed = [NSMutableArray array];
    NSMutableArray<NSString *> *skipped = [NSMutableArray array];

    Class router = NSClassFromString(@"GBLRouterImpl");
    if (SCITTLinksHas(router, "openURLString:", "v24@0:8@16")
        && SCITTLinksHas(router, "openURLString:fromInside:completion:", "v36@0:8@16B24@?28")
        && SCITTLinksHas(router, "openURLString:fromInside:fromViewController:completion:", "v44@0:8@16B24@28@?36")
        && SCITTLinksHas(router, "openURLString:userInfo:fromInside:fromViewController:completion:onWillDismiss:", "v60@0:8@16@24B32@36@?44@?52")) {
        %init(SCITTLinksRouter);
        [installed addObject:@"router"];
    } else {
        [skipped addObject:@"GBLRouterImpl -openURLString:…"];
    }

    Class container = NSClassFromString(@"AWE3rdWebContainerService");
    if (SCITTLinksHas(container, "openURL:configuration:", "v32@0:8@16@24")
        && SCITTLinksHas(container, "openURL:dataflowId:", "v32@0:8@16Q24")
        && SCITTLinksHas(container, "openURL:fallback:", "v32@0:8@16@?24")
        && SCITTLinksHas(container, "openURL:dataflowId:fallback:", "v40@0:8@16Q24@?32")) {
        %init(SCITTLinksContainer);
        [installed addObject:@"container"];
    } else {
        [skipped addObject:@"AWE3rdWebContainerService -openURL:…"];
    }

    Class third = NSClassFromString(@"AWEThirdWebModuleServiceImpl");
    if (SCITTLinksHas(third, "shouldOpenURLInIAB:", "B24@0:8@16") && SCITTLinksHas(third, "tryOpenURL:dataflowId:", "B32@0:8@16@24")
        && SCITTLinksHas(third, "tryOpenURLString:dataflowId:", "B32@0:8@16@24")) {
        %init(SCITTLinksThirdWeb);
        [installed addObject:@"third-web"];
    } else {
        [skipped addObject:@"AWEThirdWebModuleServiceImpl"];
    }

    Class dfid = NSClassFromString(@"PHFDfidRouterServiceImpl");
    if (SCITTLinksHas(dfid, "shouldOpenURLInIAB:", "B24@0:8@16") && SCITTLinksHas(dfid, "tryOpenURL:dataflowId:", "B32@0:8@16@24")
        && SCITTLinksHas(dfid, "tryOpenURLString:dataflowId:", "B32@0:8@16@24")) {
        %init(SCITTLinksDfid);
        [installed addObject:@"dfid"];
    } else {
        [skipped addObject:@"PHFDfidRouterServiceImpl"];
    }

    Class safari = NSClassFromString(@"AWESafariViewController");
    if (SCITTLinksHas(safari, "viewDidAppear:", "v20@0:8B16") && SCITTLinksHas(safari, "requestURL", "@16@0:8")
        && SCITTLinksHas(safari, "lastURLString", "@16@0:8")) {
        %init(SCITTLinksSafariView);
        [installed addObject:@"safari-view"];
    } else {
        [skipped addObject:@"AWESafariViewController"];
    }

    if (SCITTLinksHas([WKWebView class], "loadRequest:", "@24@0:8@16")) {
        %init(SCITTLinksWebView);
        [installed addObject:@"web view"];
    } else {
        [skipped addObject:@"WKWebView -loadRequest:"];
    }

    sciLinksState = [NSString stringWithFormat:@"%@%@",
        installed.count ? [@"installed: " stringByAppendingString:[installed componentsJoinedByString:@", "]] : @"nothing installed",
        skipped.count ? [NSString stringWithFormat:@" — skipped: %@", [skipped componentsJoinedByString:@"; "]] : @""];
    SCILogV(@"[Links] %@", sciLinksState);
}
