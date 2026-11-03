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
