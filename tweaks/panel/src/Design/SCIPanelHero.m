//
//  SCIPanelHero.m
//  Albrhi Panel
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCIPanelHero.h"
#import "SCIPanelStyle.h"
#import "../Localization/SCILocalize.h"

/// A capsule: an optional dot, then the text, both centred on the capsule's own middle. (The dot was first an attachment inside the label, which
/// lifted the line and put this chip's text a point lower than its neighbour's.)
static UIView *Chip(NSString *text, UIColor *textColor, UIColor *fill, UIColor *_Nullable dot, CGFloat *width) {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightSemibold];
    label.textColor = textColor;
    CGFloat textWidth = ceil([label sizeThatFits:CGSizeMake(400, 28)].width);

    CGFloat dotSpace = dot ? 15 : 0;
    CGFloat w = textWidth + dotSpace + 26;
    UIView *chip = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 28)];
    chip.backgroundColor = fill;
    chip.layer.cornerRadius = 14;
    chip.layer.cornerCurve = kCACornerCurveContinuous;
    if (dot) {
        UIView *mark = [[UIView alloc] initWithFrame:CGRectMake(13, 10.5, 7, 7)];
        mark.backgroundColor = dot;
        mark.layer.cornerRadius = 3.5;
        [chip addSubview:mark];
    }
    label.frame = CGRectMake(13 + dotSpace, 0, textWidth, 28);
    [chip addSubview:label];
    *width = w;
    return chip;
}

@implementation SCIPanelHero

+ (UIImage *)mark {
    NSBundle *bundle = [NSBundle bundleForClass:self];
    return [UIImage imageNamed:@"AlbrhiMark" inBundle:bundle compatibleWithTraitCollection:nil];
}

+ (UIView *)viewForWidth:(CGFloat)width version:(NSString *)version on:(NSInteger)on of:(NSInteger)total masterOn:(BOOL)masterOn {
    const CGFloat margin = 16, cardTop = 6;
    CGFloat cardWidth = width - margin * 2;

    UIView *card = [[UIView alloc] init];
    card.layer.cornerRadius = 30;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.clipsToBounds = YES;
    card.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.15 alpha:1];

    // The body: graphite to a deep indigo, then a warm plum at the far corner.
    CAGradientLayer *body = [CAGradientLayer layer];
    body.colors = @[(id)[UIColor colorWithRed:0.07 green:0.08 blue:0.16 alpha:1].CGColor,
                    (id)[UIColor colorWithRed:0.17 green:0.13 blue:0.38 alpha:1].CGColor,
                    (id)[UIColor colorWithRed:0.36 green:0.15 blue:0.34 alpha:1].CGColor];
    body.startPoint = CGPointMake(0, 0);
    body.endPoint = CGPointMake(1, 1);
    [card.layer addSublayer:body];

    // Two soft glows -- the mark's orange behind the mark, indigo in the opposite corner -- so the card has depth rather than a flat fill.
    CAGradientLayer *warm = [CAGradientLayer layer];
    warm.type = kCAGradientLayerRadial;
    warm.colors = @[(id)[UIColor colorWithRed:0.99 green:0.50 blue:0.16 alpha:0.55].CGColor, (id)[UIColor colorWithRed:0.99 green:0.50 blue:0.16 alpha:0].CGColor];
    warm.startPoint = CGPointMake(0.5, 0.5);
    warm.endPoint = CGPointMake(1, 1);
    [card.layer addSublayer:warm];
    CAGradientLayer *cool = [CAGradientLayer layer];
    cool.type = kCAGradientLayerRadial;
    cool.colors = @[(id)[UIColor colorWithRed:0.38 green:0.45 blue:1 alpha:0.34].CGColor, (id)[UIColor colorWithRed:0.38 green:0.45 blue:1 alpha:0].CGColor];
    cool.startPoint = CGPointMake(0.5, 0.5);
    cool.endPoint = CGPointMake(1, 1);
    [card.layer addSublayer:cool];

    CGFloat y = 28;

    // The mark, on a white ring so it reads on any part of the gradient.
    const CGFloat markSide = 76;
    UIImage *mark = [self mark];
    UIView *ring = [[UIView alloc] initWithFrame:CGRectMake((cardWidth - markSide - 8) / 2, y, markSide + 8, markSide + 8)];
    ring.layer.cornerRadius = 25;
    ring.layer.cornerCurve = kCACornerCurveContinuous;
    ring.backgroundColor = [UIColor colorWithWhite:1 alpha:0.14];
    ring.layer.borderWidth = 0.6;
    ring.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.28].CGColor;
    [card addSubview:ring];
    if (mark) {
        UIImageView *logo = [[UIImageView alloc] initWithImage:mark];
        logo.frame = CGRectMake(4, 4, markSide, markSide);
        logo.contentMode = UIViewContentModeScaleAspectFit;
        logo.layer.cornerRadius = 21;
        logo.layer.cornerCurve = kCACornerCurveContinuous;
        logo.clipsToBounds = YES;
        [ring addSubview:logo];
    }
    warm.frame = CGRectMake(CGRectGetMidX(ring.frame) - 130, CGRectGetMidY(ring.frame) - 130, 260, 260);
    y += markSide + 8 + 14;

    UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(24, y, cardWidth - 48, 42)];
    name.text = SCILocalized(@"panel_title");
    name.font = SCIPanelRoundedFont(36, UIFontWeightHeavy);
    name.textColor = [UIColor whiteColor];
    name.textAlignment = NSTextAlignmentCenter;
    [card addSubview:name];
    y += 44;

    UILabel *tagline = [[UILabel alloc] init];
    tagline.text = SCILocalized(@"panel_tagline");
    tagline.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    tagline.textColor = [UIColor colorWithWhite:1 alpha:0.72];
    tagline.textAlignment = NSTextAlignmentCenter;
    tagline.numberOfLines = 0;
    CGSize fit = [tagline sizeThatFits:CGSizeMake(cardWidth - 56, CGFLOAT_MAX)];
    tagline.frame = CGRectMake(28, y + 2, cardWidth - 56, ceil(fit.height));
    [card addSubview:tagline];
    y += 2 + ceil(fit.height) + 18;

    // Two chips, centred as a pair: the version, and how much is on.
    CGFloat versionWidth = 0, stateWidth = 0;
    UIView *versionChip = Chip(version, [UIColor colorWithWhite:1 alpha:0.92], [UIColor colorWithWhite:1 alpha:0.13], nil, &versionWidth);
    NSString *stateText = masterOn ? [NSString stringWithFormat:SCILocalized(@"panel_on_count"), (long)on, (long)total] : SCILocalized(@"hero_off");
    UIColor *stateDot = !masterOn ? [UIColor colorWithRed:1 green:0.42 blue:0.38 alpha:1] : (on > 0 ? [UIColor colorWithRed:0.30 green:0.86 blue:0.50 alpha:1] : [UIColor colorWithWhite:1 alpha:0.5]);
    UIView *stateChip = Chip(stateText, [UIColor colorWithWhite:1 alpha:0.92], [UIColor colorWithWhite:1 alpha:0.13], stateDot, &stateWidth);
    CGFloat total_ = versionWidth + 8 + stateWidth;
    CGFloat x = (cardWidth - total_) / 2;
    versionChip.frame = CGRectMake(x, y, versionWidth, 28);
    stateChip.frame = CGRectMake(x + versionWidth + 8, y, stateWidth, 28);
    [card addSubview:versionChip];
    [card addSubview:stateChip];
    y += 28 + 26;

    CGFloat cardHeight = y;
    card.frame = CGRectMake(margin, cardTop, cardWidth, cardHeight);
    body.frame = card.bounds;
    cool.frame = CGRectMake(cardWidth - 170, cardHeight - 150, 300, 300);

    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, cardHeight + cardTop + 10)];
    [header addSubview:card];
    return header;
}

@end
