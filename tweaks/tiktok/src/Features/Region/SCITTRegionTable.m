//
//  SCITTRegionTable.m
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCITTRegionTable.h"

///
/// Written for this tweak from public country and operator codes (ITU E.212), not taken from any
/// reference tweak's list. One operator per country, chosen because it is a large national one --
/// the pair is read by TikTok as a carrier, so it has to be a carrier that exists. **Best effort:**
/// nothing here was checked against a live network, and an operator's own code can change.
///

NSArray<NSDictionary<NSString *, NSString *> *> *SCITTRegionTable(void) {
    static NSArray *table;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        table = @[
        @{@"code": @"SA", @"en": @"Saudi Arabia", @"ar": @"السعودية", @"mcc": @"420", @"mnc": @"01"},
        @{@"code": @"AE", @"en": @"United Arab Emirates", @"ar": @"الإمارات", @"mcc": @"424", @"mnc": @"02"},
        @{@"code": @"KW", @"en": @"Kuwait", @"ar": @"الكويت", @"mcc": @"419", @"mnc": @"02"},
        @{@"code": @"QA", @"en": @"Qatar", @"ar": @"قطر", @"mcc": @"427", @"mnc": @"01"},
        @{@"code": @"BH", @"en": @"Bahrain", @"ar": @"البحرين", @"mcc": @"426", @"mnc": @"01"},
        @{@"code": @"OM", @"en": @"Oman", @"ar": @"عُمان", @"mcc": @"422", @"mnc": @"02"},
        @{@"code": @"EG", @"en": @"Egypt", @"ar": @"مصر", @"mcc": @"602", @"mnc": @"01"},
        @{@"code": @"JO", @"en": @"Jordan", @"ar": @"الأردن", @"mcc": @"416", @"mnc": @"01"},
        @{@"code": @"IQ", @"en": @"Iraq", @"ar": @"العراق", @"mcc": @"418", @"mnc": @"05"},
        @{@"code": @"LB", @"en": @"Lebanon", @"ar": @"لبنان", @"mcc": @"415", @"mnc": @"01"},
        @{@"code": @"MA", @"en": @"Morocco", @"ar": @"المغرب", @"mcc": @"604", @"mnc": @"01"},
        @{@"code": @"DZ", @"en": @"Algeria", @"ar": @"الجزائر", @"mcc": @"603", @"mnc": @"01"},
        @{@"code": @"TN", @"en": @"Tunisia", @"ar": @"تونس", @"mcc": @"605", @"mnc": @"02"},
        @{@"code": @"TR", @"en": @"Türkiye", @"ar": @"تركيا", @"mcc": @"286", @"mnc": @"01"},
        @{@"code": @"US", @"en": @"United States", @"ar": @"الولايات المتحدة", @"mcc": @"310", @"mnc": @"260"},
        @{@"code": @"CA", @"en": @"Canada", @"ar": @"كندا", @"mcc": @"302", @"mnc": @"720"},
        @{@"code": @"GB", @"en": @"United Kingdom", @"ar": @"المملكة المتحدة", @"mcc": @"234", @"mnc": @"10"},
        @{@"code": @"IE", @"en": @"Ireland", @"ar": @"أيرلندا", @"mcc": @"272", @"mnc": @"01"},
        @{@"code": @"DE", @"en": @"Germany", @"ar": @"ألمانيا", @"mcc": @"262", @"mnc": @"01"},
        @{@"code": @"FR", @"en": @"France", @"ar": @"فرنسا", @"mcc": @"208", @"mnc": @"01"},
        @{@"code": @"ES", @"en": @"Spain", @"ar": @"إسبانيا", @"mcc": @"214", @"mnc": @"07"},
        @{@"code": @"IT", @"en": @"Italy", @"ar": @"إيطاليا", @"mcc": @"222", @"mnc": @"01"},
        @{@"code": @"NL", @"en": @"Netherlands", @"ar": @"هولندا", @"mcc": @"204", @"mnc": @"08"},
        @{@"code": @"SE", @"en": @"Sweden", @"ar": @"السويد", @"mcc": @"240", @"mnc": @"01"},
        @{@"code": @"RU", @"en": @"Russia", @"ar": @"روسيا", @"mcc": @"250", @"mnc": @"01"},
        @{@"code": @"UA", @"en": @"Ukraine", @"ar": @"أوكرانيا", @"mcc": @"255", @"mnc": @"01"},
        @{@"code": @"KZ", @"en": @"Kazakhstan", @"ar": @"كازاخستان", @"mcc": @"401", @"mnc": @"02"},
        @{@"code": @"IN", @"en": @"India", @"ar": @"الهند", @"mcc": @"404", @"mnc": @"10"},
        @{@"code": @"PK", @"en": @"Pakistan", @"ar": @"باكستان", @"mcc": @"410", @"mnc": @"01"},
        @{@"code": @"ID", @"en": @"Indonesia", @"ar": @"إندونيسيا", @"mcc": @"510", @"mnc": @"10"},
        @{@"code": @"MY", @"en": @"Malaysia", @"ar": @"ماليزيا", @"mcc": @"502", @"mnc": @"12"},
        @{@"code": @"SG", @"en": @"Singapore", @"ar": @"سنغافورة", @"mcc": @"525", @"mnc": @"01"},
        @{@"code": @"JP", @"en": @"Japan", @"ar": @"اليابان", @"mcc": @"440", @"mnc": @"10"},
        @{@"code": @"KR", @"en": @"South Korea", @"ar": @"كوريا الجنوبية", @"mcc": @"450", @"mnc": @"05"},
        @{@"code": @"BR", @"en": @"Brazil", @"ar": @"البرازيل", @"mcc": @"724", @"mnc": @"05"},
        @{@"code": @"MX", @"en": @"Mexico", @"ar": @"المكسيك", @"mcc": @"334", @"mnc": @"020"},
        @{@"code": @"AU", @"en": @"Australia", @"ar": @"أستراليا", @"mcc": @"505", @"mnc": @"01"},
        @{@"code": @"ZA", @"en": @"South Africa", @"ar": @"جنوب أفريقيا", @"mcc": @"655", @"mnc": @"01"}
        ];
    });
    return table;
}

NSDictionary<NSString *, NSString *> *SCITTRegionFind(NSString *code) {
    if (code.length != 2) return nil;
    for (NSDictionary *entry in SCITTRegionTable()) {
        if ([entry[@"code"] caseInsensitiveCompare:code] == NSOrderedSame) return entry;
    }
    return nil;
}

NSString *SCITTRegionName(NSDictionary<NSString *, NSString *> *entry) {
    BOOL arabic = [([[NSLocale preferredLanguages] firstObject] ?: @"en") hasPrefix:@"ar"];
    return (arabic ? entry[@"ar"] : entry[@"en"]) ?: entry[@"code"];
}
