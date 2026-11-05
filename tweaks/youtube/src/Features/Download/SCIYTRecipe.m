#import "SCIYTRecipe.h"

@implementation SCIYTRecipe

- (instancetype)init {
    self = [super init];
    if (self) { _extraAudioIDs = @[]; _captionIDs = @[]; }
    return self;
}

+ (NSString *)familyOfVariant:(SCIHLSVariant *)variant {
    return [variant.codecs.lowercaseString containsString:@"av01"] ? @"av1" : @"h264";
}

+ (instancetype)recipeForVariant:(SCIHLSVariant *)variant
                       audioOnly:(BOOL)audioOnly
                           title:(NSString *)title
                         videoID:(NSString *)videoID
                         isShort:(BOOL)isShort {
    SCIYTRecipe *recipe = [[SCIYTRecipe alloc] init];
    recipe.videoID = videoID ?: @"";
    recipe.title = title;
    recipe.isShort = isShort;
    recipe.audioOnly = audioOnly;
    recipe.height = variant.height;
    recipe.family = [self familyOfVariant:variant];

    NSMutableArray<NSString *> *extras = [NSMutableArray array], *captions = [NSMutableArray array];
    for (NSDictionary *track in variant.chosenExtraAudios) if ([track[@"id"] length]) [extras addObject:track[@"id"]];
    for (NSDictionary *track in variant.chosenCaptions) if ([track[@"id"] length]) [captions addObject:track[@"id"]];
    recipe.extraAudioIDs = extras;
    recipe.captionIDs = captions;
    recipe.soundOnlyTrackID = variant.soundOnlyTrackID;
    return recipe;
}

+ (instancetype)recipeFromDictionary:(NSDictionary *)d {
    if (![d isKindOfClass:[NSDictionary class]] || ![d[@"video"] isKindOfClass:[NSString class]] || ![d[@"video"] length]) return nil;

    SCIYTRecipe *recipe = [[SCIYTRecipe alloc] init];
    recipe.videoID = d[@"video"];
    recipe.title = [d[@"title"] isKindOfClass:[NSString class]] ? d[@"title"] : nil;
    recipe.isShort = [d[@"short"] boolValue];
    recipe.audioOnly = [d[@"audio"] boolValue];
    recipe.height = [d[@"height"] integerValue];
    recipe.maxHeight = [d[@"max"] integerValue];
    recipe.family = [d[@"family"] isKindOfClass:[NSString class]] ? d[@"family"] : nil;
    recipe.soundOnlyTrackID = [d[@"soundOnly"] isKindOfClass:[NSString class]] ? d[@"soundOnly"] : nil;

    NSMutableArray *extras = [NSMutableArray array], *captions = [NSMutableArray array];
    for (id item in ([d[@"extras"] isKindOfClass:[NSArray class]] ? d[@"extras"] : @[])) if ([item isKindOfClass:[NSString class]]) [extras addObject:item];
    for (id item in ([d[@"captions"] isKindOfClass:[NSArray class]] ? d[@"captions"] : @[])) if ([item isKindOfClass:[NSString class]]) [captions addObject:item];
    recipe.extraAudioIDs = extras;
    recipe.captionIDs = captions;
    return recipe;
}

- (NSDictionary *)dictionary {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"video"] = self.videoID ?: @"";
    if (self.title.length) d[@"title"] = self.title;
    if (self.isShort) d[@"short"] = @YES;
    if (self.audioOnly) d[@"audio"] = @YES;
    if (self.height) d[@"height"] = @(self.height);
    if (self.maxHeight) d[@"max"] = @(self.maxHeight);
    if (self.family.length) d[@"family"] = self.family;
    if (self.soundOnlyTrackID.length) d[@"soundOnly"] = self.soundOnlyTrackID;
    if (self.extraAudioIDs.count) d[@"extras"] = self.extraAudioIDs;
    if (self.captionIDs.count) d[@"captions"] = self.captionIDs;
    return d;
}

- (SCIHLSVariant *)pickFrom:(NSArray<SCIHLSVariant *> *)variants {
    if (!variants.count) return nil;

    // A sound-only save needs only the sound, which every variant of a video carries alike.
    if (self.audioOnly) {
        for (SCIHLSVariant *v in variants) if ([[SCIYTRecipe familyOfVariant:v] isEqualToString:@"h264"]) return v;
        return variants.firstObject;
    }

    if (self.height > 0) {
        for (SCIHLSVariant *v in variants) {
            if (v.height == self.height && (!self.family || [[SCIYTRecipe familyOfVariant:v] isEqualToString:self.family])) return v;
        }
        for (SCIHLSVariant *v in variants) if (v.height == self.height) return v;

        SCIHLSVariant *best = nil;
        NSInteger bestDistance = NSIntegerMax;
        for (SCIHLSVariant *v in variants) {
            NSInteger distance = labs((long)(v.height - self.height));
            // The lower one wins a tie: a file a little smaller than asked for beats one larger.
            if (distance < bestDistance || (distance == bestDistance && v.height < best.height)) { best = v; bestDistance = distance; }
        }
        return best;
    }

    // A policy: the tallest ordinary quality that fits.
    SCIHLSVariant *fits = nil, *smallest = nil;
    for (SCIHLSVariant *v in variants) {
        BOOL ordinary = [[SCIYTRecipe familyOfVariant:v] isEqualToString:@"h264"];
        if (ordinary && (!smallest || v.height < smallest.height)) smallest = v;
        if (ordinary && !fits && (self.maxHeight <= 0 || v.height <= self.maxHeight)) fits = v;   // tallest first
    }
    if (fits) return fits;
    // Nothing ordinary fits under the ceiling: the smallest ordinary one is the closest honest answer.
    if (smallest) return smallest;
    return variants.lastObject;   // only AV1 offered: the smallest of them
}

- (void)applyTo:(SCIHLSVariant *)variant {
    NSMutableArray<NSDictionary *> *extras = [NSMutableArray array], *captions = [NSMutableArray array];
    for (NSDictionary *track in variant.directAudioTracks) {
        if (![track[@"default"] boolValue] && [self.extraAudioIDs containsObject:track[@"id"]]) [extras addObject:track];
    }
    for (NSDictionary *track in variant.directCaptionTracks) {
        if ([self.captionIDs containsObject:track[@"id"]]) [captions addObject:track];
    }
    variant.chosenExtraAudios = extras;
    variant.chosenCaptions = captions;

    if (self.soundOnlyTrackID.length) {
        for (NSDictionary *track in variant.directAudioTracks) {
            if ([track[@"id"] isEqualToString:self.soundOnlyTrackID] && ![track[@"default"] boolValue]) {
                variant.directAudioURL = track[@"url"];
                variant.directAudioBytes = [track[@"bytes"] longLongValue];
                variant.soundOnlyTrackID = self.soundOnlyTrackID;
            }
        }
    }
}

@end
