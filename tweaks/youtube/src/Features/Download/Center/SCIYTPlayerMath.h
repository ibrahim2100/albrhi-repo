#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#include <math.h>

// The arithmetic behind the Centre player's gestures, with no UIKit in it, so a host test can
// run the same code the player ships (tweaks/youtube/tests/host).

/// Where a sideways drag lands. A drag across the whole screen moves ninety seconds -- or the
/// whole file when it is shorter -- so a three-minute song and a three-hour film both answer
/// to a thumb, and the target is clamped to the file.
static inline double SCIPlayerSeekTarget(double start, double dx, double width, double length) {
    if (!isfinite(length) || length <= 0 || width <= 0) return start;
    double span = fmin(length, 90);
    double target = start + (dx / width) * span;
    if (target < 0) return 0;
    if (target > length) return length;
    return target;
}

/// A level (brightness or volume, 0...1) after a vertical drag. Up raises it; a drag over the
/// full height moves the whole range, and the result stays inside it.
static inline double SCIPlayerEdgeLevel(double start, double dy, double height) {
    if (height <= 0) return start;
    double level = start - dy / height;
    if (level < 0) return 0;
    if (level > 1) return 1;
    return level;
}

/// Which gesture a drag is. Sideways wins when it is the larger half; a vertical drag belongs
/// to brightness or volume only in the outer quarters of the picture and to nothing in the
/// middle, where it is left to the swipe-down that closes the screen.
typedef NS_ENUM(NSInteger, SCIPlayerDrag) {
    SCIPlayerDragNone = 0,
    SCIPlayerDragSeek,
    SCIPlayerDragBrightness,
    SCIPlayerDragVolume,
};

static inline SCIPlayerDrag SCIPlayerClassifyDrag(double vx, double vy, double x, double width) {
    if (width <= 0) return SCIPlayerDragNone;
    if (fabs(vx) > fabs(vy)) return SCIPlayerDragSeek;
    if (x < width * 0.25) return SCIPlayerDragBrightness;
    if (x > width * 0.75) return SCIPlayerDragVolume;
    return SCIPlayerDragNone;
}

/// Pinch to fill or fit: a pinch has to be deliberate to change anything.
/// Returns 1 for fill, -1 for fit, 0 for "leave it".
static inline int SCIPlayerZoomChoice(double scale) {
    if (scale > 1.15) return 1;
    if (scale < 0.87) return -1;
    return 0;
}

// MARK: - SponsorBlock in a saved file

/// Which saved segment to jump over right now, or -1.
///
/// `starts`/`ends` are the segments in seconds; `active[i]` says whether its category is switched
/// on *now* (the choice is read when playing, not when the file was saved, so a category turned on
/// later applies to old files); `done[i]` marks the ones already skipped this playback, so an undo
/// that goes back into a segment is not skipped again. A segment under one second is not worth a
/// jump (the seek costs about that), one that starts at or past the end of the file is a segment
/// of a different cut of the video, and the end is clamped to the file.
static inline int SCISkipIndex(const double *starts, const double *ends, const unsigned char *active,
                               const unsigned char *done, int count, double now, double length) {
    if (!isfinite(now) || now < 0) return -1;
    for (int i = 0; i < count; i++) {
        if (!active[i] || done[i]) continue;
        double start = starts[i], end = ends[i];
        if (!isfinite(start) || !isfinite(end) || start < 0 || end <= start) continue;
        if (isfinite(length) && length > 0) {
            if (start >= length - 0.5) continue;
            if (end > length) end = length;
        }
        if (end - start < 1.0) continue;
        if (now >= start && now < end) return i;
    }
    return -1;
}

// MARK: - Shuffle

/// A play order for `count` items that starts with `first` and visits every other one once.
/// Fisher-Yates over a small deterministic generator, so a test can pin the seed and a run of
/// the app does not need a source of randomness it can fail to have.
static inline void SCIShuffleOrder(int *out, int count, int first, unsigned int seed) {
    if (count <= 0) return;
    if (first < 0 || first >= count) first = 0;
    int slot = 1;
    out[0] = first;
    for (int i = 0; i < count; i++) if (i != first) out[slot++] = i;
    unsigned int state = seed ? seed : 0x9E3779B9u;
    for (int i = count - 1; i > 1; i--) {
        state ^= state << 13; state ^= state >> 17; state ^= state << 5;
        int j = 1 + (int)(state % (unsigned int)i);   // 1...i, slot 0 stays where it is
        int t = out[i]; out[i] = out[j]; out[j] = t;
    }
}
