//
//  SCITTLinks.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// Opens an address TikTok does not own in Safari instead of TikTok's own browser, at every door the app is known to use for one:
/// its router (`GBLRouterImpl`), its web container service (`AWE3rdWebContainerService`), the two services that decide between the
/// in-app browser and the system (`AWEThirdWebModuleServiceImpl`, `PHFDfidRouterServiceImpl`), its Safari-view wrapper
/// (`AWESafariViewController`) and, as the last net, a web view inside an in-app browser being asked to load a foreign host.
/// Each door is installed only where the build declares the selector with the encoding it was written against.
void SCITTInstallLinks(void);

/// Which door answered how often, the host of the last address handed over, and -- for a foreign address a web view loaded that no door
/// caught -- the class chain it was loaded in, so a door nobody knew about names itself.
NSString *SCITTLinksReport(void);
