//
//  SCITTRegionTable.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// The countries a person may tell TikTok they are in. Each entry: `code` (ISO 3166 alpha-2, upper case), `en`, `ar`, `mcc`, `mnc`
/// (a real operator of that country, because TikTok reads the pair as a carrier and a made-up one is a tell).
NSArray<NSDictionary<NSString *, NSString *> *> *SCITTRegionTable(void);

/// The entry for `code` (any case), or nil.
NSDictionary<NSString *, NSString *> * _Nullable SCITTRegionFind(NSString *code);

/// The name to show, in the language the device is set to.
NSString *SCITTRegionName(NSDictionary<NSString *, NSString *> *entry);

NS_ASSUME_NONNULL_END
