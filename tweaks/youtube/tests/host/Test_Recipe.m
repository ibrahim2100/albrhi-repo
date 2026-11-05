//
//  Test_Recipe.m
//  Albrhi for YouTube — host tests
//
//  What a download was asked to be (SCIYTRecipe, compiled as shipped) and the file side of
//  resuming it (SCIYTParts' join). The recipe is the only thing kept across a launch -- the
//  addresses expire -- so choosing again from a fresh answer has to land on the same thing.
//
#import <Foundation/Foundation.h>
#import "Features/Download/SCIYTRecipe.h"
#import "Features/Download/SCIYTParts.h"
#import "AlbrhiTestKit.h"

static SCIHLSVariant *V(NSInteger height, NSString *codecs) {
    SCIHLSVariant *v = [SCIHLSVariant new];
    v.height = height; v.codecs = codecs;
    v.directAudioTracks = @[
        @{@"id": @"en.4", @"lang": @"en", @"name": @"English", @"url": @"http://example.invalid/en", @"bytes": @100, @"default": @YES},
        @{@"id": @"ar.3", @"lang": @"ar", @"name": @"Arabic", @"url": @"http://example.invalid/ar", @"bytes": @200, @"default": @NO},
    ];
    v.directCaptionTracks = @[@{@"id": @"en", @"lang": @"en", @"name": @"English", @"url": @"u", @"auto": @NO},
                              @{@"id": @"fr", @"lang": @"fr", @"name": @"French", @"url": @"u", @"auto": @NO}];
    return v;
}

void Test_Recipe(void) {
    printf("download recipes\n");

    ALBRHI_TEST(a_recipe_survives_being_written_and_read, {
        SCIHLSVariant *v = V(720, @"avc1.64001f,mp4a.40.2");
        v.chosenExtraAudios = @[v.directAudioTracks[1]];
        v.chosenCaptions = @[v.directCaptionTracks[0]];
        SCIYTRecipe *r = [SCIYTRecipe recipeForVariant:v audioOnly:NO title:@"A title" videoID:@"abc123" isShort:YES];
        NSData *json = [NSJSONSerialization dataWithJSONObject:[r dictionary] options:0 error:nil];
        SCIYTRecipe *back = [SCIYTRecipe recipeFromDictionary:[NSJSONSerialization JSONObjectWithData:json options:0 error:nil]];
        ALBRHI_ASSERT([back.videoID isEqualToString:@"abc123"] && back.height == 720 && [back.family isEqualToString:@"h264"], @"video, height, family");
        ALBRHI_ASSERT(back.isShort && !back.audioOnly && [back.title isEqualToString:@"A title"], @"flags and title");
        ALBRHI_ASSERT([back.extraAudioIDs isEqualToArray:@[@"ar.3"]] && [back.captionIDs isEqualToArray:@[@"en"]], @"the ticks");
    });

    ALBRHI_TEST(junk_is_not_a_recipe, {
        ALBRHI_ASSERT([SCIYTRecipe recipeFromDictionary:@{}] == nil, @"no video");
        ALBRHI_ASSERT([SCIYTRecipe recipeFromDictionary:@{@"video": @""}] == nil, @"empty video");
        ALBRHI_ASSERT([SCIYTRecipe recipeFromDictionary:(NSDictionary *)@"x"] == nil, @"not a dictionary");
    });

    ALBRHI_TEST(resuming_picks_the_exact_quality_and_codec, {
        NSArray *fresh = @[V(2160, @"av01.0.12M.08,mp4a"), V(1080, @"avc1,mp4a"), V(1080, @"av01,mp4a"), V(720, @"avc1,mp4a")];
        SCIYTRecipe *r = [SCIYTRecipe new]; r.videoID = @"x"; r.height = 1080; r.family = @"av1";
        SCIHLSVariant *picked = [r pickFrom:fresh];
        ALBRHI_ASSERT(picked == fresh[2], @"the AV1 1080, not the H.264 one");
    });

    ALBRHI_TEST(resuming_falls_back_to_the_nearest_height_preferring_lower, {
        NSArray *fresh = @[V(1080, @"avc1,mp4a"), V(720, @"avc1,mp4a"), V(360, @"avc1,mp4a")];
        SCIYTRecipe *r = [SCIYTRecipe new]; r.videoID = @"x"; r.height = 540; r.family = @"h264";
        ALBRHI_ASSERT([r pickFrom:fresh].height == 360 || [r pickFrom:fresh].height == 720, @"one of the two equally near");
        ALBRHI_ASSERT([r pickFrom:fresh].height == 360, @"the lower of two equally near");
        r.height = 700;
        ALBRHI_ASSERT([r pickFrom:fresh].height == 720, @"nearest wins when not a tie");
    });

    ALBRHI_TEST(a_batch_policy_takes_the_tallest_ordinary_quality_that_fits, {
        NSArray *fresh = @[V(2160, @"av01,mp4a"), V(1080, @"avc1,mp4a"), V(720, @"avc1,mp4a"), V(360, @"avc1,mp4a")];
        SCIYTRecipe *r = [SCIYTRecipe new]; r.videoID = @"x";
        r.maxHeight = 0;   ALBRHI_ASSERT([r pickFrom:fresh].height == 1080, @"no ceiling: tallest H.264, never the AV1 4K");
        r.maxHeight = 720; ALBRHI_ASSERT([r pickFrom:fresh].height == 720, @"a ceiling of 720");
        r.maxHeight = 500; ALBRHI_ASSERT([r pickFrom:fresh].height == 360, @"under 500 only 360 fits");
        r.maxHeight = 144; ALBRHI_ASSERT([r pickFrom:fresh].height == 360, @"nothing fits: the smallest ordinary one");
    });

    ALBRHI_TEST(only_av1_on_offer_takes_the_smallest_of_it, {
        NSArray *fresh = @[V(2160, @"av01,mp4a"), V(1440, @"av01,mp4a")];
        SCIYTRecipe *r = [SCIYTRecipe new]; r.videoID = @"x";
        ALBRHI_ASSERT([r pickFrom:fresh].height == 1440, @"the smaller AV1");
        ALBRHI_ASSERT([r pickFrom:@[]] == nil, @"nothing offered, nothing picked");
    });

    ALBRHI_TEST(applying_keeps_only_what_the_video_really_offers, {
        SCIYTRecipe *r = [SCIYTRecipe new]; r.videoID = @"x";
        r.extraAudioIDs = @[@"ar.3", @"gone.1", @"en.4"];       // en.4 is the original: never an "extra"
        r.captionIDs = @[@"fr", @"zz"];
        SCIHLSVariant *v = V(720, @"avc1,mp4a");
        [r applyTo:v];
        ALBRHI_ASSERT(v.chosenExtraAudios.count == 1 && [v.chosenExtraAudios[0][@"id"] isEqualToString:@"ar.3"], @"only the real extra");
        ALBRHI_ASSERT(v.chosenCaptions.count == 1 && [v.chosenCaptions[0][@"id"] isEqualToString:@"fr"], @"only the real caption");
    });

    ALBRHI_TEST(a_sound_only_language_swaps_the_address, {
        SCIYTRecipe *r = [SCIYTRecipe new]; r.videoID = @"x"; r.audioOnly = YES; r.soundOnlyTrackID = @"ar.3";
        SCIHLSVariant *v = V(720, @"avc1,mp4a"); v.directAudioURL = @"http://example.invalid/en"; v.directAudioBytes = 100;
        [r applyTo:v];
        ALBRHI_ASSERT([v.directAudioURL hasSuffix:@"/ar"] && v.directAudioBytes == 200, @"the Arabic sound");
    });

    // The file side. Several joins read one run's parts in turn; the first of them used to remove
    // the folder and the next ones found nothing -- a second language always failed as "incomplete".
    ALBRHI_TEST(joins_of_one_run_do_not_remove_each_others_parts, {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSURL *folder = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]]];
        [fm createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:nil];
        NSMutableArray<NSURL *> *parts = [NSMutableArray array];
        for (int i = 0; i < 6; i++) {
            NSURL *p = [folder URLByAppendingPathComponent:[NSString stringWithFormat:@"%06d.part", i]];
            [[NSData dataWithBytes:(uint8_t[]){(uint8_t)('a' + i), (uint8_t)('a' + i)} length:2] writeToURL:p atomically:YES];
            [parts addObject:p];
        }
        NSURL *first = [SCIYTParts join:[parts subarrayWithRange:NSMakeRange(0, 2)] extension:@"mp4" folder:nil];
        NSURL *second = [SCIYTParts join:[parts subarrayWithRange:NSMakeRange(2, 2)] extension:@"m4a" folder:nil];
        NSURL *third = [SCIYTParts join:[parts subarrayWithRange:NSMakeRange(4, 2)] extension:@"m4a" folder:nil];
        ALBRHI_ASSERT(first && second && third, @"all three joined from one folder");
        ALBRHI_ASSERT([[NSString stringWithContentsOfURL:first encoding:NSUTF8StringEncoding error:nil] isEqualToString:@"aabb"], @"in order");
        ALBRHI_ASSERT([[NSString stringWithContentsOfURL:third encoding:NSUTF8StringEncoding error:nil] isEqualToString:@"eeff"], @"the last one too");
        ALBRHI_ASSERT([fm fileExistsAtPath:folder.path], @"a nil folder is left alone");

        NSURL *again = [SCIYTParts join:[parts subarrayWithRange:NSMakeRange(0, 1)] extension:@"mp4" folder:folder];
        ALBRHI_ASSERT(again != nil && ![fm fileExistsAtPath:folder.path], @"a given folder is removed afterwards, as before");
        for (NSURL *u in @[first, second, third, again]) [fm removeItemAtURL:u error:nil];
    });
}
