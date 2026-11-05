//
//  SCIYTRecipe.h
//  Albrhi for YouTube
//
//  What a download was asked to be, in a form that survives the app closing.
//
//  The addresses a download fetches expire within hours and mean nothing to the next launch,
//  so what is kept is the *choice*: which video, which quality, which languages and captions.
//  A resumed download asks YouTube for fresh addresses and re-makes the same choice from them,
//  then fetches only the parts that never arrived. Pure -- no request, no UIKit -- so a host
//  test runs the shipped code (tests/host/Test_Recipe.m).
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>
#import "SCIYTHLS.h"

NS_ASSUME_NONNULL_BEGIN

@interface SCIYTRecipe : NSObject

@property (nonatomic, copy) NSString *videoID;
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic) BOOL isShort;
@property (nonatomic) BOOL audioOnly;

/// The exact quality to get back (resuming), with its codec family -- zero when it is a policy.
@property (nonatomic) NSInteger height;
@property (nonatomic, copy, nullable) NSString *family;      ///< @"h264" or @"av1"

/// A policy for batches: the tallest quality not above this (0 = the tallest there is).
@property (nonatomic) NSInteger maxHeight;

@property (nonatomic, copy) NSArray<NSString *> *extraAudioIDs;
@property (nonatomic, copy) NSArray<NSString *> *captionIDs;

/// For a sound-only save in a language other than the original.
@property (nonatomic, copy, nullable) NSString *soundOnlyTrackID;

+ (NSString *)familyOfVariant:(SCIHLSVariant *)variant;

/// The recipe of a variant the person just chose in the sheet (its ticks included).
+ (instancetype)recipeForVariant:(SCIHLSVariant *)variant
                       audioOnly:(BOOL)audioOnly
                           title:(nullable NSString *)title
                         videoID:(NSString *)videoID
                         isShort:(BOOL)isShort;

+ (nullable instancetype)recipeFromDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)dictionary;

/// The variant this recipe means among those a fresh request returned (tallest first), or nil
/// when there are none. Exact height and family first; then the same height in another family;
/// then the nearest height, preferring the lower. A policy takes the tallest H.264 not above
/// `maxHeight` -- AV1 above 1080 only when nothing else is offered, because that is a file fewer
/// phones can play.
- (nullable SCIHLSVariant *)pickFrom:(NSArray<SCIHLSVariant *> *)variants;

/// Sets the variant's ticks from the recipe's ids -- only those the video really offers, so a
/// language or caption that has gone is dropped rather than failing the download.
- (void)applyTo:(SCIHLSVariant *)variant;

@end

NS_ASSUME_NONNULL_END
