//
//  SCIReceipt.h
//  Albrhi for Instagram
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// For a re-signed (sideloaded) Instagram: makes the app's receipt address look like a store install's, so it does not take itself for a TestFlight
/// beta. Standalone build only.
void SCIReceiptInstall(void);

/// The address the app should be told: `.../StoreKit/sandboxReceipt` becomes `.../StoreKit/receipt`; anything else is returned as it came. (Pure: the
/// rule the hook applies, kept apart so it can be tested without an app.)
NSURL *SCIReceiptRewritten(NSURL *url);

/// How many times the app asked and was given the rewritten address, and the address it was given last.
NSArray<NSString *> *SCIReceiptReportLines(void);
