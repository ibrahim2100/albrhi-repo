//
//  SCIAppGroup.h
//  Albrhi for Instagram
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// For a re-signed Instagram: an app group the new signature does not hold (`group.com.burbn.instagram`) answers "no container", and Instagram keeps
/// part of its state and its session in it. Where the system gives no container, the app is given a folder of its own for that group instead.
/// Standalone build only; a group the app really holds is never touched.
void SCIAppGroupInstall(void);

/// The folder used in place of a group the app does not hold: `<Application Support>/AlbrhiAppGroups/<group>`, created on first use.
NSURL *SCIAppGroupFallbackContainer(NSString *group);

/// How often the system said "no container" and a folder of ours was given, how many shared-defaults suites were pointed at one, and which groups.
NSArray<NSString *> *SCIAppGroupReportLines(void);
