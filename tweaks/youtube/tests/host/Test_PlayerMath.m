//
//  Test_PlayerMath.m
//  Albrhi for YouTube — host tests
//
//  The arithmetic behind the Centre player's gestures (SCIYTPlayerMath.h, compiled as shipped):
//  where a sideways drag lands, what a vertical drag does to brightness and volume, which
//  gesture a drag is, and when a pinch counts. What a finger actually does is a device's
//  question; these are the numbers that must be right whatever the finger does.
//
#import <Foundation/Foundation.h>
#import "Features/Download/Center/SCIYTPlayerMath.h"
#import "AlbrhiTestKit.h"

void Test_PlayerMath(void) {
    printf("player gestures\n");

    ALBRHI_TEST(seek_full_width_is_ninety_seconds, {
        ALBRHI_ASSERT(fabs(SCIPlayerSeekTarget(100, 400, 400, 3600) - 190) < 1e-9, @"a full-width drag on a long file moves 90 s");
        ALBRHI_ASSERT(fabs(SCIPlayerSeekTarget(100, -200, 400, 3600) - 55) < 1e-9, @"half a width back moves 45 s back");
    });

    ALBRHI_TEST(seek_short_file_spans_the_file, {
        ALBRHI_ASSERT(fabs(SCIPlayerSeekTarget(0, 400, 400, 30) - 30) < 1e-9, @"a drag across a 30 s file reaches its end");
        ALBRHI_ASSERT(fabs(SCIPlayerSeekTarget(10, 100, 400, 30) - 17.5) < 1e-9, @"a quarter width on 30 s is 7.5 s");
    });

    ALBRHI_TEST(seek_is_clamped_to_the_file, {
        ALBRHI_ASSERT(SCIPlayerSeekTarget(5, -4000, 400, 600) == 0, @"never before the start");
        ALBRHI_ASSERT(SCIPlayerSeekTarget(595, 4000, 400, 600) == 600, @"never past the end");
    });

    ALBRHI_TEST(seek_without_a_length_does_not_move, {
        ALBRHI_ASSERT(SCIPlayerSeekTarget(42, 300, 400, NAN) == 42, @"NaN length");
        ALBRHI_ASSERT(SCIPlayerSeekTarget(42, 300, 400, 0) == 42, @"zero length");
        ALBRHI_ASSERT(SCIPlayerSeekTarget(42, 300, 0, 600) == 42, @"zero width");
        ALBRHI_ASSERT(SCIPlayerSeekTarget(42, 300, 400, INFINITY) == 42, @"infinite length");
    });

    ALBRHI_TEST(edge_level_up_raises_down_lowers, {
        ALBRHI_ASSERT(fabs(SCIPlayerEdgeLevel(0.5, -100, 400) - 0.75) < 1e-9, @"a quarter height up adds a quarter");
        ALBRHI_ASSERT(fabs(SCIPlayerEdgeLevel(0.5, 100, 400) - 0.25) < 1e-9, @"a quarter height down takes one");
    });

    ALBRHI_TEST(edge_level_is_clamped, {
        ALBRHI_ASSERT(SCIPlayerEdgeLevel(0.9, -4000, 400) == 1, @"not above 1");
        ALBRHI_ASSERT(SCIPlayerEdgeLevel(0.1, 4000, 400) == 0, @"not below 0");
        ALBRHI_ASSERT(SCIPlayerEdgeLevel(0.3, 50, 0) == 0.3, @"no height, no change");
    });

    ALBRHI_TEST(drag_classification, {
        ALBRHI_ASSERT(SCIPlayerClassifyDrag(300, 20, 200, 400) == SCIPlayerDragSeek, @"sideways in the middle seeks");
        ALBRHI_ASSERT(SCIPlayerClassifyDrag(300, 20, 10, 400) == SCIPlayerDragSeek, @"sideways at the edge still seeks");
        ALBRHI_ASSERT(SCIPlayerClassifyDrag(10, -300, 40, 400) == SCIPlayerDragBrightness, @"vertical on the left is brightness");
        ALBRHI_ASSERT(SCIPlayerClassifyDrag(10, 300, 390, 400) == SCIPlayerDragVolume, @"vertical on the right is volume");
        ALBRHI_ASSERT(SCIPlayerClassifyDrag(10, 300, 200, 400) == SCIPlayerDragNone, @"vertical in the middle is left to the swipe-down");
        ALBRHI_ASSERT(SCIPlayerClassifyDrag(10, 300, 100, 400) == SCIPlayerDragNone, @"the quarter boundary is not an edge");
        ALBRHI_ASSERT(SCIPlayerClassifyDrag(10, 300, 200, 0) == SCIPlayerDragNone, @"no width, no gesture");
    });

    ALBRHI_TEST(zoom_needs_a_deliberate_pinch, {
        ALBRHI_ASSERT(SCIPlayerZoomChoice(1.5) == 1, @"spread fills");
        ALBRHI_ASSERT(SCIPlayerZoomChoice(0.6) == -1, @"pinch fits");
        ALBRHI_ASSERT(SCIPlayerZoomChoice(1.05) == 0, @"a tremor changes nothing");
        ALBRHI_ASSERT(SCIPlayerZoomChoice(0.95) == 0, @"a tremor changes nothing");
    });

    printf("sponsor segments in a saved file\n");

    ALBRHI_TEST(skip_picks_the_segment_the_playhead_is_inside, {
        double starts[] = {10, 100}, ends[] = {20, 130};
        unsigned char active[] = {1, 1}, done[] = {0, 0};
        ALBRHI_ASSERT(SCISkipIndex(starts, ends, active, done, 2, 5, 600) == -1, @"before the first");
        ALBRHI_ASSERT(SCISkipIndex(starts, ends, active, done, 2, 10, 600) == 0, @"at the start of the first");
        ALBRHI_ASSERT(SCISkipIndex(starts, ends, active, done, 2, 19.9, 600) == 0, @"inside it");
        ALBRHI_ASSERT(SCISkipIndex(starts, ends, active, done, 2, 20, 600) == -1, @"the end is outside");
        ALBRHI_ASSERT(SCISkipIndex(starts, ends, active, done, 2, 120, 600) == 1, @"inside the second");
    });

    ALBRHI_TEST(skip_honours_switches_and_what_was_already_skipped, {
        double starts[] = {10}, ends[] = {20};
        unsigned char off[] = {0}, on[] = {1}, done[] = {0}, skipped[] = {1};
        ALBRHI_ASSERT(SCISkipIndex(starts, ends, off, done, 1, 12, 600) == -1, @"a category that is off");
        ALBRHI_ASSERT(SCISkipIndex(starts, ends, on, skipped, 1, 12, 600) == -1, @"an undone skip is not repeated");
    });

    ALBRHI_TEST(skip_ignores_what_is_not_worth_it_or_not_in_this_file, {
        double starts[] = {10, 50, 580, 5}, ends[] = {10.5, 40, 700, NAN};
        unsigned char active[] = {1, 1, 1, 1}, done[] = {0, 0, 0, 0};
        ALBRHI_ASSERT(SCISkipIndex(starts, ends, active, done, 4, 10.2, 600) == -1, @"under a second");
        ALBRHI_ASSERT(SCISkipIndex(starts, ends, active, done, 4, 45, 600) == -1, @"end before start");
        double lateStart[] = {599.7}, lateEnd[] = {640};
        unsigned char one[] = {1}, none[] = {0};
        ALBRHI_ASSERT(SCISkipIndex(lateStart, lateEnd, one, none, 1, 599.8, 600) == -1, @"a segment that begins at the very end is another cut");
        ALBRHI_ASSERT(SCISkipIndex(starts, ends, active, done, 4, 590, 600) == 2, @"one that runs past the end is clamped, not dropped");
        ALBRHI_ASSERT(SCISkipIndex(starts, ends, active, done, 4, 6, 600) == -1, @"NaN");
        ALBRHI_ASSERT(SCISkipIndex(starts, ends, active, done, 4, NAN, 600) == -1, @"no time");
    });

    printf("shuffle\n");

    ALBRHI_TEST(shuffle_starts_at_the_current_one_and_visits_each_once, {
        for (unsigned seed = 1; seed < 200; seed++) {
            int order[9];
            SCIShuffleOrder(order, 9, 4, seed);
            int seen[9] = {0};
            for (int i = 0; i < 9; i++) { ALBRHI_ASSERT(order[i] >= 0 && order[i] < 9, @"in range"); seen[order[i]]++; }
            for (int i = 0; i < 9; i++) ALBRHI_ASSERT(seen[i] == 1, @"each exactly once");
            ALBRHI_ASSERT(order[0] == 4, @"the one playing stays first");
        }
    });

    ALBRHI_TEST(shuffle_actually_mixes_and_is_repeatable, {
        int a[20], b[20], c[20];
        SCIShuffleOrder(a, 20, 0, 7); SCIShuffleOrder(b, 20, 0, 7); SCIShuffleOrder(c, 20, 0, 8);
        BOOL same = YES, other = NO, ordered = YES;
        for (int i = 0; i < 20; i++) { if (a[i] != b[i]) same = NO; if (a[i] != c[i]) other = YES; if (a[i] != i) ordered = NO; }
        ALBRHI_ASSERT(same, @"the same seed gives the same order");
        ALBRHI_ASSERT(other, @"another seed gives another");
        ALBRHI_ASSERT(!ordered, @"not left in order");
    });

    ALBRHI_TEST(shuffle_edge_sizes, {
        int one[1]; SCIShuffleOrder(one, 1, 0, 3);
        ALBRHI_ASSERT(one[0] == 0, @"one item");
        int two[2]; SCIShuffleOrder(two, 2, 1, 3);
        ALBRHI_ASSERT(two[0] == 1 && two[1] == 0, @"two items, the second playing");
        int bad[3]; SCIShuffleOrder(bad, 3, 99, 3);
        ALBRHI_ASSERT(bad[0] == 0, @"an invalid start falls back to the first");
    });
}
