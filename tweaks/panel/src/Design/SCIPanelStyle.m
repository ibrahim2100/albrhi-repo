//
//  SCIPanelStyle.m
//  Albrhi Panel
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCIPanelStyle.h"
#import "../SCIPanelScan.h"

const CGFloat SCIPanelTileSide = 44;

UIColor *SCIPanelOrange(void) { return [UIColor colorWithRed:0.98 green:0.47 blue:0.13 alpha:1]; }
UIColor *SCIPanelIndigo(void) { return [UIColor colorWithRed:0.33 green:0.28 blue:0.78 alpha:1]; }

UIFont *SCIPanelRoundedFont(CGFloat size, UIFontWeight weight) {
    UIFont *base = [UIFont systemFontOfSize:size weight:weight];
    UIFontDescriptor *rounded = [base.fontDescriptor fontDescriptorWithDesign:UIFontDescriptorSystemDesignRounded];
    return rounded ? [UIFont fontWithDescriptor:rounded size:size] : base;
}

static UIColor *RGB(CGFloat r, CGFloat g, CGFloat b) { return [UIColor colorWithRed:r / 255 green:g / 255 blue:b / 255 alpha:1]; }

/// A vertical (or diagonal, bottom-left to top-right) gradient over the whole tile.
static void FillGradient(CGContextRef ctx, CGRect rect, NSArray<UIColor *> *colors, BOOL diagonal) {
    NSMutableArray *cg = [NSMutableArray array];
    for (UIColor *c in colors) [cg addObject:(__bridge id)c.CGColor];
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGGradientRef gradient = CGGradientCreateWithColors(space, (__bridge CFArrayRef)cg, NULL);
    CGPoint from = diagonal ? CGPointMake(CGRectGetMinX(rect), CGRectGetMaxY(rect)) : CGPointMake(0, CGRectGetMinY(rect));
    CGPoint to = diagonal ? CGPointMake(CGRectGetMaxX(rect), CGRectGetMinY(rect)) : CGPointMake(0, CGRectGetMaxY(rect));
    CGContextDrawLinearGradient(ctx, gradient, from, to, kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(space);
}

/// Renders `draw` inside a continuous rounded square of `side` points. The unit passed is `side`, so every mark below is written in fractions.
static UIImage *Tile(CGFloat side, void (^draw)(CGContextRef ctx, CGFloat s)) {
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.opaque = NO;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(side, side) format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        CGRect rect = CGRectMake(0, 0, side, side);
        CGContextRef ctx = context.CGContext;
        UIBezierPath *clip = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:side * 0.225];
        [clip addClip];
        draw(ctx, side);
        // A hairline inside the edge, so a white tile does not melt into a white row and a black one does not into a dark row.
        [[UIColor colorWithWhite:0.5 alpha:0.28] setStroke];
        clip.lineWidth = 0.5;
        [[UIBezierPath bezierPathWithRoundedRect:CGRectInset(rect, 0.25, 0.25) cornerRadius:side * 0.225] stroke];
    }];
}

#pragma mark - The marks (stand-ins, drawn here)

static UIImage *InstagramTile(CGFloat side) {
    return Tile(side, ^(CGContextRef ctx, CGFloat s) {
        FillGradient(ctx, CGRectMake(0, 0, s, s), @[RGB(254, 218, 117), RGB(250, 126, 30), RGB(214, 41, 118), RGB(150, 47, 191), RGB(79, 91, 213)], YES);
        CGContextSetStrokeColorWithColor(ctx, [UIColor whiteColor].CGColor);
        CGContextSetLineWidth(ctx, s * 0.055);
        UIBezierPath *frame = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(s * 0.22, s * 0.22, s * 0.56, s * 0.56) cornerRadius:s * 0.17];
        [frame stroke];
        UIBezierPath *lens = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(s * 0.355, s * 0.355, s * 0.29, s * 0.29)];
        lens.lineWidth = s * 0.055;
        [[UIColor whiteColor] setStroke];
        [lens stroke];
        [[UIColor whiteColor] setFill];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(s * 0.64, s * 0.285, s * 0.07, s * 0.07)] fill];
    });
}

static UIImage *YouTubeTile(CGFloat side) {
    return Tile(side, ^(CGContextRef ctx, CGFloat s) {
        FillGradient(ctx, CGRectMake(0, 0, s, s), @[RGB(255, 255, 255), RGB(238, 238, 240)], NO);
        [RGB(255, 0, 0) setFill];
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(s * 0.17, s * 0.29, s * 0.66, s * 0.42) cornerRadius:s * 0.13] fill];
        [[UIColor whiteColor] setFill];
        UIBezierPath *play = [UIBezierPath bezierPath];
        [play moveToPoint:CGPointMake(s * 0.43, s * 0.395)];
        [play addLineToPoint:CGPointMake(s * 0.43, s * 0.605)];
        [play addLineToPoint:CGPointMake(s * 0.62, s * 0.5)];
        [play closePath];
        [play fill];
    });
}

static UIImage *XTile(CGFloat side) {
    return Tile(side, ^(CGContextRef ctx, CGFloat s) {
        FillGradient(ctx, CGRectMake(0, 0, s, s), @[RGB(36, 36, 38), RGB(0, 0, 0)], NO);
        CGContextSetStrokeColorWithColor(ctx, [UIColor whiteColor].CGColor);
        CGContextSetLineCap(ctx, kCGLineCapSquare);
        CGContextSetLineWidth(ctx, s * 0.09);
        CGContextMoveToPoint(ctx, s * 0.30, s * 0.27);
        CGContextAddLineToPoint(ctx, s * 0.70, s * 0.73);
        CGContextStrokePath(ctx);
        CGContextSetLineWidth(ctx, s * 0.045);
        CGContextMoveToPoint(ctx, s * 0.70, s * 0.27);
        CGContextAddLineToPoint(ctx, s * 0.30, s * 0.73);
        CGContextStrokePath(ctx);
    });
}

static UIImage *TikTokTile(CGFloat side) {
    return Tile(side, ^(CGContextRef ctx, CGFloat s) {
        FillGradient(ctx, CGRectMake(0, 0, s, s), @[RGB(28, 28, 32), RGB(0, 0, 0)], NO);
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:s * 0.52 weight:UIImageSymbolWeightBold];
        UIImage *note = [UIImage systemImageNamed:@"music.note" withConfiguration:config];
        if (!note) return;
        CGPoint origin = CGPointMake((s - note.size.width) / 2, (s - note.size.height) / 2);
        // The cyan and red offset copies behind a white one: the way the real mark reads, made of a symbol that is not it.
        [[note imageWithTintColor:RGB(37, 244, 238) renderingMode:UIImageRenderingModeAlwaysOriginal] drawAtPoint:CGPointMake(origin.x - s * 0.025, origin.y - s * 0.02)];
        [[note imageWithTintColor:RGB(254, 44, 85) renderingMode:UIImageRenderingModeAlwaysOriginal] drawAtPoint:CGPointMake(origin.x + s * 0.025, origin.y + s * 0.02)];
        [[note imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal] drawAtPoint:origin];
    });
}

static UIImage *YouTubeMusicTile(CGFloat side) {
    return Tile(side, ^(CGContextRef ctx, CGFloat s) {
        FillGradient(ctx, CGRectMake(0, 0, s, s), @[RGB(48, 48, 52), RGB(14, 14, 16)], NO);
        [RGB(255, 0, 0) setFill];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(s * 0.18, s * 0.18, s * 0.64, s * 0.64)] fill];
        [[UIColor whiteColor] setStroke];
        UIBezierPath *ring = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(s * 0.255, s * 0.255, s * 0.49, s * 0.49)];
        ring.lineWidth = s * 0.03;
        [ring stroke];
        [[UIColor whiteColor] setFill];
        UIBezierPath *play = [UIBezierPath bezierPath];
        [play moveToPoint:CGPointMake(s * 0.44, s * 0.40)];
        [play addLineToPoint:CGPointMake(s * 0.44, s * 0.60)];
        [play addLineToPoint:CGPointMake(s * 0.62, s * 0.50)];
        [play closePath];
        [play fill];
    });
}

static UIImage *SpotifyTile(CGFloat side) {
    return Tile(side, ^(CGContextRef ctx, CGFloat s) {
        FillGradient(ctx, CGRectMake(0, 0, s, s), @[RGB(41, 224, 104), RGB(25, 176, 78)], NO);
        CGContextSetStrokeColorWithColor(ctx, RGB(12, 12, 14).CGColor);
        CGContextSetLineCap(ctx, kCGLineCapRound);
        struct { CGFloat x0, y0, x1, y1, cy, w; } arcs[] = {
            { 0.23, 0.385, 0.77, 0.365, 0.29, 0.065 },
            { 0.28, 0.535, 0.72, 0.52, 0.45, 0.055 },
            { 0.335, 0.665, 0.665, 0.655, 0.60, 0.045 },
        };
        for (int i = 0; i < 3; i++) {
            CGContextSetLineWidth(ctx, s * arcs[i].w);
            CGContextMoveToPoint(ctx, s * arcs[i].x0, s * arcs[i].y0);
            CGContextAddQuadCurveToPoint(ctx, s * 0.5, s * arcs[i].cy, s * arcs[i].x1, s * arcs[i].y1);
            CGContextStrokePath(ctx);
        }
    });
}

static UIImage *InitialTile(NSString *name, CGFloat side) {
    // An app this panel has never heard of: its first letter on a quiet gradient, still the same size and shape as every other row's.
    NSString *letter = name.length ? [[name substringToIndex:1] uppercaseString] : @"?";
    return Tile(side, ^(CGContextRef ctx, CGFloat s) {
        FillGradient(ctx, CGRectMake(0, 0, s, s), @[RGB(118, 118, 132), RGB(70, 70, 82)], NO);
        NSDictionary *attributes = @{ NSFontAttributeName: SCIPanelRoundedFont(s * 0.5, UIFontWeightBold), NSForegroundColorAttributeName: [UIColor whiteColor] };
        CGSize size = [letter sizeWithAttributes:attributes];
        [letter drawAtPoint:CGPointMake((s - size.width) / 2, (s - size.height) / 2) withAttributes:attributes];
    });
}

#pragma mark - Public

UIImage *SCIPanelAppTile(NSString *bundleIdentifier, UIImage *realIcon, CGFloat side) {
    if (realIcon) {
        // The phone's icon, scaled down to the tile and clipped to the same shape: at its own size (about 60 points) it filled the row and
        // ran into its neighbours.
        return Tile(side, ^(CGContextRef ctx, CGFloat s) {
            [realIcon drawInRect:CGRectMake(0, 0, s, s)];
        });
    }

    NSString *identifier = bundleIdentifier.lowercaseString;
    if ([identifier isEqualToString:@"com.burbn.instagram"]) return InstagramTile(side);
    if ([identifier isEqualToString:@"com.google.ios.youtube"]) return YouTubeTile(side);
    if ([identifier isEqualToString:@"com.atebits.tweetie2"]) return XTile(side);
    if ([identifier isEqualToString:@"com.zhiliaoapp.musically"]) return TikTokTile(side);
    if ([identifier isEqualToString:@"com.google.ios.youtubemusic"]) return YouTubeMusicTile(side);
    if ([identifier isEqualToString:@"com.spotify.client"] || [identifier isEqualToString:@"com.albrhi.spotify"]) return SpotifyTile(side);
    return InitialTile(bundleIdentifier.pathExtension.length ? bundleIdentifier.pathExtension : bundleIdentifier, side);
}

UIImage *SCIPanelSymbolTile(NSString *symbolName, UIColor *top, UIColor *bottom, CGFloat side) {
    return Tile(side, ^(CGContextRef ctx, CGFloat s) {
        FillGradient(ctx, CGRectMake(0, 0, s, s), @[top, bottom], NO);
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:s * 0.46 weight:UIImageSymbolWeightSemibold];
        UIImage *glyph = [[UIImage systemImageNamed:symbolName withConfiguration:config] imageWithTintColor:[UIColor whiteColor]
                                                                                              renderingMode:UIImageRenderingModeAlwaysOriginal];
        if (glyph) [glyph drawAtPoint:CGPointMake((s - glyph.size.width) / 2, (s - glyph.size.height) / 2)];
    });
}

void SCIPanelTonesForGroup(NSString *groupIdentifier, NSString **symbol, UIColor **top, UIColor **bottom) {
    if ([groupIdentifier isEqualToString:@"com.albrhi.nextup"]) {
        *symbol = @"music.note.list"; *top = RGB(255, 138, 76); *bottom = RGB(226, 70, 36);
    } else if ([groupIdentifier isEqualToString:@"com.albrhi.watch"]) {
        *symbol = @"applewatch"; *top = RGB(104, 112, 255); *bottom = RGB(70, 58, 214);
    } else {
        *symbol = @"gearshape.fill"; *top = RGB(142, 142, 152); *bottom = RGB(96, 96, 108);
    }
}


#pragma mark - Entries

/// The placeholder is asked for once, with an identifier no app has, and an icon counts as real only when it is a different picture from it.
@interface SCIPanelScan (PlaceholderProbe)
+ (UIImage *)iconFor:(NSString *)identifier;
@end

static UIImage *GenuineIcon(UIImage *icon) {
    if (!icon) return nil;
    static NSData *placeholder;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        UIImage *probe = [SCIPanelScan iconFor:@"com.albrhi.no-such-app.placeholder-probe"];
        placeholder = probe ? UIImagePNGRepresentation(probe) : nil;
    });
    NSData *data = UIImagePNGRepresentation(icon);
    return (placeholder && [data isEqualToData:placeholder]) ? nil : icon;
}

BOOL SCIPanelIsKnownApp(NSString *identifier) {
    static NSSet *known;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        known = [NSSet setWithArray:@[@"com.burbn.instagram", @"com.google.ios.youtube", @"com.atebits.tweetie2", @"com.zhiliaoapp.musically",
                                      @"com.google.ios.youtubemusic", @"com.spotify.client", @"com.albrhi.spotify"]];
    });
    return [known containsObject:identifier.lowercaseString];
}

UIImage *SCIPanelTileForEntry(SCIPanelEntry *entry, CGFloat side) {
    if (SCIPanelIsKnownApp(entry.bundleIdentifier) || GenuineIcon(entry.appIcon)) {
        return SCIPanelAppTile(entry.bundleIdentifier, entry.appInstalled ? GenuineIcon(entry.appIcon) : nil, side);
    }
    NSString *symbol = nil; UIColor *top = nil, *bottom = nil;
    SCIPanelTonesForGroup(entry.bundleIdentifier, &symbol, &top, &bottom);
    return SCIPanelSymbolTile(symbol, top, bottom, side);
}
