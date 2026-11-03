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
}
