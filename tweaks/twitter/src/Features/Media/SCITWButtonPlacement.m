#import "SCITWButtonPlacement.h"

CGRect SCITWButtonArea(CGRect bounds, UIEdgeInsets safeArea, CGFloat margin) {
    CGRect area = UIEdgeInsetsInsetRect(bounds, safeArea);
    area = CGRectInset(area, margin, margin);
    if (CGRectIsNull(area) || area.size.width < 0 || area.size.height < 0) {
        // A view laid out at zero size, or safe-area insets larger than the view: nothing to
        // place into yet. The bounds' own centre, not the origin, so a button that does get
        // drawn before the real layout arrives is not in a corner it will then jump from.
        return CGRectMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds), 0, 0);
    }
    return area;
}

/// One axis: the span a centre may move along, as its low end and its length.
static void SCITWSpan(CGFloat origin, CGFloat length, CGFloat size, CGFloat *low, CGFloat *span) {
    CGFloat usable = length - size;
    if (usable <= 0) {
        *low = origin + length / 2.0;
        *span = 0;
        return;
    }
    *low = origin + size / 2.0;
    *span = usable;
}

static CGFloat SCITWUnit(CGFloat value) {
    // NaN fails every comparison, so it is caught first; an infinity is clamped like any number.
    if (value != value) return 0.5;
    return MAX(0.0, MIN(1.0, value));
}

CGPoint SCITWButtonCenterForFraction(CGPoint fraction, CGRect area, CGSize button) {
    CGFloat lowX, spanX, lowY, spanY;
    SCITWSpan(area.origin.x, area.size.width, button.width, &lowX, &spanX);
    SCITWSpan(area.origin.y, area.size.height, button.height, &lowY, &spanY);
    return CGPointMake(lowX + SCITWUnit(fraction.x) * spanX,
                       lowY + SCITWUnit(fraction.y) * spanY);
}

CGPoint SCITWButtonFractionForCenter(CGPoint center, CGRect area, CGSize button) {
    CGFloat lowX, spanX, lowY, spanY;
    SCITWSpan(area.origin.x, area.size.width, button.width, &lowX, &spanX);
    SCITWSpan(area.origin.y, area.size.height, button.height, &lowY, &spanY);
    return CGPointMake(spanX > 0 ? SCITWUnit((center.x - lowX) / spanX) : 0.5,
                       spanY > 0 ? SCITWUnit((center.y - lowY) / spanY) : 0.5);
}

CGPoint SCITWButtonClampCenter(CGPoint center, CGRect area, CGSize button) {
    return SCITWButtonCenterForFraction(SCITWButtonFractionForCenter(center, area, button),
                                        area, button);
}
