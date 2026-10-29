//
//  SCITTMark.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

///
/// The mark: the letter A drawn as one thin line, with its crossbar bent down into the head of a download arrow.
///
/// It replaced a heavy filled accent tile holding the system's bold arrow, which read as a placeholder: the tile carried all the weight and the
/// arrow was the same one every app uses. This is drawn here (so it is ours), as a line (so it is light), with nothing behind it, and in whatever
/// colour it is asked for (so it sits on the settings page and on the dark welcome card without a second asset). The A is the name; the bent
/// crossbar is what the tool does; neither is decoration. Proportions are fractions of the side, so any size is the same drawing.
///
static inline UIImage *SCITTMarkImage(CGFloat side, UIColor *color) {
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.opaque = NO;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(side, side) format:format];

    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        CGFloat u = side;
        CGFloat weight = u * 0.075;
        [color setStroke];

        // The legs of the A: from the apex to the two feet, joined at the apex with a round join so the top reads as one stroke.
        UIBezierPath *legs = [UIBezierPath bezierPath];
        [legs moveToPoint:CGPointMake(u * 0.17, u * 0.86)];
        [legs addLineToPoint:CGPointMake(u * 0.50, u * 0.14)];
        [legs addLineToPoint:CGPointMake(u * 0.83, u * 0.86)];
        legs.lineWidth = weight;
        legs.lineCapStyle = kCGLineCapRound;
        legs.lineJoinStyle = kCGLineJoinRound;
        [legs stroke];

        // The crossbar, bent down: it leaves each leg at the height where a crossbar would, and meets in the middle below it, so it is also the
        // open head of a down arrow. The legs are straight lines, so the two ends are on them by arithmetic, not by eye.
        CGFloat barY = 0.58;
        CGFloat half = (0.86 - barY) / (0.86 - 0.14) * 0.33;   // distance from the axis to a leg at that height
        UIBezierPath *bar = [UIBezierPath bezierPath];
        [bar moveToPoint:CGPointMake(u * (0.50 - half), u * barY)];
        [bar addLineToPoint:CGPointMake(u * 0.50, u * (barY + half))];
        [bar addLineToPoint:CGPointMake(u * (0.50 + half), u * barY)];
        bar.lineWidth = weight;
        bar.lineCapStyle = kCGLineCapRound;
        bar.lineJoinStyle = kCGLineJoinRound;
        [bar stroke];
    }];
}
