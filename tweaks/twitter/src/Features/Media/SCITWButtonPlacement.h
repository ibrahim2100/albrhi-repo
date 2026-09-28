#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

///
/// Where a user-placed button sits, as arithmetic with no UIKit state in it.
///
/// **A position is stored as a fraction of the room the button has, never as points.** A point
/// saved on one video card is a different place on the next one -- a different height with the
/// status bar hidden, a different width after rotation, a different device after a restore --
/// and a button placed by stored points walks, or ends up off screen where nobody can reach it
/// to move it back. A fraction of the usable span means the same spot relative to the video
/// wherever it is shown, and every value that comes back from these functions is clamped, so no
/// input -- a corrupted preference included -- can put any part of the button outside the area.
///
/// Pure functions on purpose: that is what lets the round trip be driven directly on a Mac
/// rather than argued about.
///

/// The area the button may occupy: the view's bounds, inside the safe area, less a margin.
CGRect SCITWButtonArea(CGRect bounds, UIEdgeInsets safeArea, CGFloat margin);

/// The centre for a stored fraction. Each fraction is clamped to 0...1 first, and the result
/// keeps the whole button inside `area`; an area smaller than the button centres it.
CGPoint SCITWButtonCenterForFraction(CGPoint fraction, CGRect area, CGSize button);

/// The fraction for a centre -- the inverse of the above, clamped the same way, so a centre
/// dragged past an edge is saved as the edge.
CGPoint SCITWButtonFractionForCenter(CGPoint center, CGRect area, CGSize button);

/// A centre held inside `area` for a button of this size: what a drag is clamped by, so the
/// button cannot be pulled out of reach while it is still under the finger.
CGPoint SCITWButtonClampCenter(CGPoint center, CGRect area, CGSize button);

NS_ASSUME_NONNULL_END
