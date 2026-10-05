//
//  SCITWInterface.h
//  Albrhi for X
//
//  Small things X draws that some people would rather it did not: the floating compose
//  button, the badge on a paying account, the tab bar sliding away, the Trends under Explore,
//  Follow beside every post -- and a few it does not draw that some would rather it did:
//  the scroll indicator, tab labels, full-quality photos.
//
//  Each one is a single answer to a single question X already asks, so none of them lays a
//  view out or adds anything: a getter says no, a method is not called, a view that was
//  built is hidden. That is also why they live together and not in a file each.
//
//  The set is NeoFreeBird's (orionblur, GPLv3, `src/Hooks/HideUI.x`, `Timeline.x`, `Theme.x`,
//  `FeatureSwitches.x`, `ImmersivePlayer.x`), written against X 12.31. **Every class and
//  selector was checked against X 12.20's own metadata with the encoding it is hooked with**,
//  and one this build lacks (`TFNTwitterAccount -isDoubleMaxZoomFor4KImagesEnabled`, the
//  message button on a post's author row) was left out rather than added as a method X never
//  calls -- a `%hook` on an undeclared method does not do nothing, it creates one.
//
//  Attached only when the switch was on at launch, so off costs nothing; the answer is read
//  again at each call, so turning one off takes effect at once. Turning one *on* needs X to be
//  reopened, and the row says so.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NSString *SCITWInterfaceReport(void);
void SCITWInstallInterface(void);
