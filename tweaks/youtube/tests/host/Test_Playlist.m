//
//  Test_Playlist.m
//  Albrhi for YouTube — host tests
//
//  Reading a playlist's answer (SCIYTPlaylist, compiled as shipped). The fixture has the shape
//  measured from the live web client: each video a `watchEndpoint` (twice, with the add-to-playlist
//  command beside it), a `continuationCommand` with a token when there is more, the title under
//  `playlistMetadataRenderer` and the size as two text runs.
//
#import <Foundation/Foundation.h>
#import "Features/Download/SCIYTPlaylist.h"
#import "AlbrhiTestKit.h"

static NSDictionary *Page(NSArray<NSString *> *ids, NSString *token, BOOL first) {
    NSMutableArray *items = [NSMutableArray array];
    for (NSString *video in ids) {
        [items addObject:@{@"lockupViewModel": @{@"contentId": video, @"rendererContext": @{@"commandContext": @{@"onTap": @{@"innertubeCommand": @{@"watchEndpoint": @{@"videoId": video, @"playlistId": @"PLx"}}}}}}}];
        [items addObject:@{@"menu": @{@"addToPlaylistCommand": @{@"videoId": video}}}];   // not an endpoint
    }
    if (token) [items addObject:@{@"continuationItemRenderer": @{@"continuationEndpoint": @{@"continuationCommand": @{@"token": token, @"request": @"CONTINUATION_REQUEST_TYPE_BROWSE"}}}}];
    NSMutableDictionary *page = [NSMutableDictionary dictionaryWithObject:@{@"contents": items} forKey:@"contents"];
    if (first) {
        page[@"metadata"] = @{@"playlistMetadataRenderer": @{@"title": @"Select Lectures"}};
        page[@"header"] = @{@"stats": @[@{@"runs": @[@{@"text": @"1,693"}, @{@"text": @" videos"}]}, @{@"runs": @[@{@"text": @"Updated"}, @{@"text": @" today"}]}]};
    }
    return page;
}

void Test_Playlist(void) {
    printf("playlists\n");

    ALBRHI_TEST(links_ids_and_refusals, {
        NSString *why = nil;
        ALBRHI_ASSERT([[SCIYTPlaylist playlistIDFromText:@"https://www.youtube.com/playlist?list=PLrAXtmErZgOeiKm4sgNOknGvNjby9efdf" reason:&why] isEqualToString:@"PLrAXtmErZgOeiKm4sgNOknGvNjby9efdf"], @"a playlist page link");
        ALBRHI_ASSERT([[SCIYTPlaylist playlistIDFromText:@"https://youtu.be/dQw4w9WgXcQ?list=PLrAXtmErZgOeiKm4sgNOknGvNjby9efdf&t=5" reason:&why] hasPrefix:@"PLrAXtmErZ"], @"a video link carrying a list");
        ALBRHI_ASSERT([[SCIYTPlaylist playlistIDFromText:@"  PLrAXtmErZgOeiKm4sgNOknGvNjby9efdf \n" reason:&why] hasPrefix:@"PLrAXtm"], @"a bare id, whitespace around it");
        ALBRHI_ASSERT([SCIYTPlaylist playlistIDFromText:@"UUBR8-60-B28hp2BmDPdntcQ" reason:&why] != nil, @"a channel's uploads");

        why = nil;
        ALBRHI_ASSERT([SCIYTPlaylist playlistIDFromText:@"https://www.youtube.com/watch?v=abc&list=RDabcdefghijk" reason:&why] == nil && why.length, @"a Mix is refused with a reason");
        why = nil;
        ALBRHI_ASSERT([SCIYTPlaylist playlistIDFromText:@"https://www.youtube.com/playlist?list=WL" reason:&why] == nil && why.length, @"Watch later is refused with a reason");
        ALBRHI_ASSERT([SCIYTPlaylist playlistIDFromText:@"https://www.youtube.com/watch?v=dQw4w9WgXcQ" reason:&why] == nil, @"a video link alone is not a playlist");
        ALBRHI_ASSERT([SCIYTPlaylist playlistIDFromText:@"hello world" reason:&why] == nil, @"words are not a playlist");
        ALBRHI_ASSERT([SCIYTPlaylist playlistIDFromText:@"" reason:&why] == nil, @"empty");
    });

    ALBRHI_TEST(a_page_gives_its_videos_once_each_and_the_way_on, {
        NSString *token = nil, *title = nil, *total = nil;
        NSArray *ids = [SCIYTPlaylist videoIDsInBrowse:Page(@[@"aaaaaaaaaaa", @"bbbbbbbbbbb", @"aaaaaaaaaaa"], @"TOKEN-2", YES) token:&token title:&title total:&total];
        ALBRHI_ASSERT([ids isEqualToArray:(@[@"aaaaaaaaaaa", @"bbbbbbbbbbb"])], @"in order, a repeat dropped, the add-to-playlist command not counted");
        ALBRHI_ASSERT([token isEqualToString:@"TOKEN-2"], @"the continuation token");
        ALBRHI_ASSERT([title isEqualToString:@"Select Lectures"], @"the title");
        ALBRHI_ASSERT([total isEqualToString:@"1,693"], @"the size, from the two text runs and not from 'Updated today'");
    });

    ALBRHI_TEST(the_last_page_has_no_token, {
        NSString *token = @"stale";
        NSArray *ids = [SCIYTPlaylist videoIDsInBrowse:Page(@[@"ccccccccccc"], nil, NO) token:&token title:nil total:nil];
        ALBRHI_ASSERT(ids.count == 1 && token == nil, @"one video and nowhere further to go");
    });

    ALBRHI_TEST(odd_ids_and_empty_answers_are_ignored, {
        NSDictionary *odd = @{@"a": @{@"watchEndpoint": @{@"videoId": @"short"}}, @"b": @{@"watchEndpoint": @{@"videoId": @12345678901}}, @"c": @{@"watchEndpoint": @{}}};
        ALBRHI_ASSERT([SCIYTPlaylist videoIDsInBrowse:odd token:nil title:nil total:nil].count == 0, @"only 11-character string ids");
        ALBRHI_ASSERT([SCIYTPlaylist videoIDsInBrowse:@{} token:nil title:nil total:nil].count == 0, @"an empty answer");
    });
}
