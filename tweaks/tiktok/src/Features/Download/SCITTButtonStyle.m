//
//  SCITTButtonStyle.m
//  Albrhi for TikTok
//
//  See SCITTButtonStyle.h. Every number below is a fraction of the side, so any size is the same drawing.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCITTButtonStyle.h"
#import <math.h>

// -- shared pieces -----------------------------------------------------------------------------------------------

/// A downward arrow as one round-capped stroke: a stem from `y0` to the tip at `y1`, and a head whose two arms run `half` out and `half` back.
static void SCITTArrowPath(CGContextRef c, CGFloat u, CGFloat cx, CGFloat y0, CGFloat y1, CGFloat half) {
    CGContextMoveToPoint(c, u * cx, u * y0);
    CGContextAddLineToPoint(c, u * cx, u * y1);
    CGContextMoveToPoint(c, u * (cx - half), u * (y1 - half));
    CGContextAddLineToPoint(c, u * cx, u * y1);
    CGContextAddLineToPoint(c, u * (cx + half), u * (y1 - half));
}

static void SCITTStrokeStyle(CGContextRef c, CGFloat width) {
    CGContextSetLineWidth(c, width);
    CGContextSetLineCap(c, kCGLineCapRound);
    CGContextSetLineJoin(c, kCGLineJoinRound);
}

/// Cuts an arrow out of whatever was just filled.
static void SCITTCutArrow(CGContextRef c, CGFloat u, CGFloat cx, CGFloat y0, CGFloat y1, CGFloat half, CGFloat weight) {
    CGContextSaveGState(c);
    CGContextSetBlendMode(c, kCGBlendModeClear);
    SCITTStrokeStyle(c, u * weight);
    CGContextBeginPath(c);
    SCITTArrowPath(c, u, cx, y0, y1, half);
    CGContextStrokePath(c);
    CGContextRestoreGState(c);
}

static void SCITTRoundedRect(CGContextRef c, CGRect r, CGFloat radius) {
    CGPathRef path = CGPathCreateWithRoundedRect(r, radius, radius, NULL);
    CGContextAddPath(c, path);
    CGPathRelease(path);
}

// -- the designs ---------------------------------------------------------------------------------------------------

/// The tool's own mark: the letter A as one thin line whose crossbar bends down into the head of a download arrow (what the button always wore;
/// the same proportions as `SCITTMark.h`, at the weight the rail needs).
static void SCITTDrawMark(CGContextRef c, CGFloat u) {
    SCITTStrokeStyle(c, u * 0.115);
    CGContextBeginPath(c);
    CGContextMoveToPoint(c, u * 0.17, u * 0.86);
    CGContextAddLineToPoint(c, u * 0.50, u * 0.14);
    CGContextAddLineToPoint(c, u * 0.83, u * 0.86);
    CGContextStrokePath(c);

    CGFloat barY = 0.58;
    CGFloat half = (0.86 - barY) / (0.86 - 0.14) * 0.33;
    CGContextBeginPath(c);
    CGContextMoveToPoint(c, u * (0.50 - half), u * barY);
    CGContextAddLineToPoint(c, u * 0.50, u * (barY + half));
    CGContextAddLineToPoint(c, u * (0.50 + half), u * barY);
    CGContextStrokePath(c);
}

/// An arrow landing on a line.
static void SCITTDrawArrow(CGContextRef c, CGFloat u) {
    SCITTStrokeStyle(c, u * 0.125);
    CGContextBeginPath(c);
    SCITTArrowPath(c, u, 0.50, 0.12, 0.64, 0.23);
    CGContextMoveToPoint(c, u * 0.20, u * 0.86);
    CGContextAddLineToPoint(c, u * 0.80, u * 0.86);
    CGContextStrokePath(c);
}

/// A solid disc with the arrow cut out.
static void SCITTDrawCircle(CGContextRef c, CGFloat u) {
    CGContextFillEllipseInRect(c, CGRectMake(u * 0.06, u * 0.06, u * 0.88, u * 0.88));
    SCITTCutArrow(c, u, 0.50, 0.27, 0.67, 0.17, 0.105);
}

/// A tray with the arrow dropping into it.
static void SCITTDrawTray(CGContextRef c, CGFloat u) {
    SCITTStrokeStyle(c, u * 0.115);
    CGContextBeginPath(c);
    CGContextMoveToPoint(c, u * 0.15, u * 0.55);
    CGContextAddLineToPoint(c, u * 0.15, u * 0.83);
    CGContextAddLineToPoint(c, u * 0.85, u * 0.83);
    CGContextAddLineToPoint(c, u * 0.85, u * 0.55);
    SCITTArrowPath(c, u, 0.50, 0.10, 0.60, 0.21);
    CGContextStrokePath(c);
}

/// A solid cloud with the arrow cut out.
static void SCITTDrawCloud(CGContextRef c, CGFloat u) {
    CGContextBeginPath(c);
    CGContextAddEllipseInRect(c, CGRectMake(u * 0.10, u * 0.40, u * 0.40, u * 0.40));
    CGContextAddEllipseInRect(c, CGRectMake(u * 0.28, u * 0.18, u * 0.50, u * 0.50));
    CGContextAddEllipseInRect(c, CGRectMake(u * 0.56, u * 0.36, u * 0.36, u * 0.44));
    SCITTRoundedRect(c, CGRectMake(u * 0.28, u * 0.50, u * 0.50, u * 0.30), u * 0.04);
    CGContextFillPath(c);
    SCITTCutArrow(c, u, 0.50, 0.36, 0.68, 0.13, 0.085);
}

/// A solid rounded tile with the arrow cut out.
static void SCITTDrawSquare(CGContextRef c, CGFloat u) {
    CGContextBeginPath(c);
    SCITTRoundedRect(c, CGRectMake(u * 0.08, u * 0.08, u * 0.84, u * 0.84), u * 0.25);
    CGContextFillPath(c);
    SCITTCutArrow(c, u, 0.50, 0.27, 0.68, 0.18, 0.105);
}

/// Two chevrons, one under the other.
static void SCITTDrawChevrons(CGContextRef c, CGFloat u) {
    SCITTStrokeStyle(c, u * 0.115);
    CGContextBeginPath(c);
    CGContextMoveToPoint(c, u * 0.20, u * 0.20);
    CGContextAddLineToPoint(c, u * 0.50, u * 0.46);
    CGContextAddLineToPoint(c, u * 0.80, u * 0.20);
    CGContextMoveToPoint(c, u * 0.20, u * 0.50);
    CGContextAddLineToPoint(c, u * 0.50, u * 0.76);
    CGContextAddLineToPoint(c, u * 0.80, u * 0.50);
    CGContextStrokePath(c);
}

/// A solid hexagon with the arrow cut out, its corners softened.
static void SCITTDrawBadge(CGContextRef c, CGFloat u) {
    CGFloat r = u * 0.43;
    CGContextBeginPath(c);
    for (int i = 0; i < 6; i++) {
        CGFloat a = (CGFloat)(-M_PI_2 + i * M_PI / 3.0);
        CGPoint p = CGPointMake(u * 0.5 + r * cos(a), u * 0.5 + r * sin(a));
        if (i == 0) CGContextMoveToPoint(c, p.x, p.y); else CGContextAddLineToPoint(c, p.x, p.y);
    }
    CGContextClosePath(c);
    SCITTStrokeStyle(c, u * 0.07);
    CGContextDrawPath(c, kCGPathFillStroke);
    SCITTCutArrow(c, u, 0.50, 0.27, 0.66, 0.16, 0.10);
}

typedef void (*SCITTDrawFn)(CGContextRef, CGFloat);

typedef struct {
    const char *identifier;
    const char *nameKey;
    SCITTDrawFn draw;
} SCITTStyleEntry;

// The first entry is the default and its identifier is stored as the empty string (the choice list removes the key for the first option).
static const SCITTStyleEntry kSCITTStyles[] = {
    { "mark",     "btn_style_mark",     SCITTDrawMark },
    { "arrow",    "btn_style_arrow",    SCITTDrawArrow },
    { "circle",   "btn_style_circle",   SCITTDrawCircle },
    { "tray",     "btn_style_tray",     SCITTDrawTray },
    { "cloud",    "btn_style_cloud",    SCITTDrawCloud },
    { "square",   "btn_style_square",   SCITTDrawSquare },
    { "chevrons", "btn_style_chevrons", SCITTDrawChevrons },
    { "badge",    "btn_style_badge",    SCITTDrawBadge },
};

NSUInteger SCITTButtonStyleCount(void) { return sizeof(kSCITTStyles) / sizeof(kSCITTStyles[0]); }

NSString *SCITTButtonStyleID(NSUInteger index) {
    return index < SCITTButtonStyleCount() ? @(kSCITTStyles[index].identifier) : @"mark";
}

NSString *SCITTButtonStyleNameKey(NSUInteger index) {
    return index < SCITTButtonStyleCount() ? @(kSCITTStyles[index].nameKey) : @"btn_style_mark";
}

NSUInteger SCITTButtonStyleIndexForID(NSString *identifier) {
    if (![identifier isKindOfClass:NSString.class] || identifier.length == 0) return 0;
    for (NSUInteger i = 0; i < SCITTButtonStyleCount(); i++) {
        if ([identifier caseInsensitiveCompare:@(kSCITTStyles[i].identifier)] == NSOrderedSame) return i;
    }
    return 0;
}

void SCITTButtonStyleDraw(NSUInteger index, CGContextRef context, CGFloat side) {
    if (index >= SCITTButtonStyleCount() || !context) return;
    CGContextSaveGState(context);
    kSCITTStyles[index].draw(context, side);
    CGContextRestoreGState(context);
}

SCITTButtonLabelMode SCITTButtonLabelModeForID(NSString *identifier) {
    if (![identifier isKindOfClass:NSString.class]) return SCITTButtonLabelName;
    if ([identifier isEqualToString:@"word"]) return SCITTButtonLabelWord;
    if ([identifier isEqualToString:@"none"]) return SCITTButtonLabelNone;
    return SCITTButtonLabelName;
}

// -- UIKit side ----------------------------------------------------------------------------------------------------

#if __has_include(<UIKit/UIKit.h>)
#import "../../Prefs.h"

UIImage *SCITTButtonStyleImage(NSUInteger index, CGFloat side, UIColor *color) {
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.opaque = NO;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(side, side) format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *rendererContext) {
        CGContextRef c = rendererContext.CGContext;
        CGContextSetFillColorWithColor(c, color.CGColor);
        CGContextSetStrokeColorWithColor(c, color.CGColor);
        SCITTButtonStyleDraw(index, c, side);
    }];
}

UIImage *SCITTButtonStylePreview(NSUInteger index, CGFloat side) {
    return [SCITTButtonStyleImage(index, side, [UIColor blackColor]) imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

NSUInteger SCITTButtonStyleCurrent(void) {
    return SCITTButtonStyleIndexForID([[NSUserDefaults standardUserDefaults] stringForKey:SCIPrefButtonStyle]);
}

SCITTButtonLabelMode SCITTButtonLabelCurrent(void) {
    return SCITTButtonLabelModeForID([[NSUserDefaults standardUserDefaults] stringForKey:SCIPrefButtonLabel]);
}
#endif
