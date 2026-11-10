//
//  SCICard.m
//  Albrhi -- shared
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCICard.h"

static UIWindow *sciCardWindow = nil;

BOOL SCICardArabic(void) {
    return [([NSLocale preferredLanguages].firstObject ?: @"") hasPrefix:@"ar"];
}

BOOL SCICardIsShowing(void) { return sciCardWindow && !sciCardWindow.hidden; }

static UIWindowScene *SCICardScene(void) {
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) return (UIWindowScene *)scene;
    }
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) return (UIWindowScene *)scene;
    }
    return nil;
}

static void SCICardClose(void) {
    sciCardWindow.hidden = YES;
    sciCardWindow = nil;
}

static UILabel *SCICardLabel(NSString *text, UIFont *font, UIColor *color) {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentCenter;
    return label;
}

BOOL SCICardShow(NSString *title, NSString *message, NSArray<NSString *> *buttons, NSInteger primary, void (^chosen)(NSInteger)) {
    if (![NSThread isMainThread]) {
        __block BOOL shown = NO;
        dispatch_sync(dispatch_get_main_queue(), ^{ shown = SCICardShow(title, message, buttons, primary, chosen); });
        return shown;
    }
    UIWindowScene *scene = SCICardScene();
    if (!scene) return NO;
    SCICardClose();   // one card at a time: a new one replaces the old

    UIWindow *window = [[UIWindow alloc] initWithWindowScene:scene];
    window.windowLevel = UIWindowLevelAlert + 1;
    window.backgroundColor = [UIColor clearColor];
    UIViewController *root = [[UIViewController alloc] init];
    root.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.45];
    window.rootViewController = root;

    UIView *card = [[UIView alloc] init];
    card.backgroundColor = [UIColor secondarySystemBackgroundColor];
    card.layer.cornerRadius = 20;
    card.translatesAutoresizingMaskIntoConstraints = NO;
    [root.view addSubview:card];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:stack];
    [stack addArrangedSubview:SCICardLabel(title, [UIFont systemFontOfSize:19 weight:UIFontWeightBold], [UIColor labelColor])];
    if (message.length) [stack addArrangedSubview:SCICardLabel(message, [UIFont systemFontOfSize:15], [UIColor secondaryLabelColor])];
    [stack setCustomSpacing:18 afterView:stack.arrangedSubviews.lastObject];

    [buttons enumerateObjectsUsingBlock:^(NSString *name, NSUInteger index, BOOL *stop) {
        BOOL filled = (NSInteger)index == primary;
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        [button setTitle:name forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:17 weight:filled ? UIFontWeightSemibold : UIFontWeightRegular];
        button.backgroundColor = filled ? [UIColor systemBlueColor] : [UIColor colorWithWhite:0.5 alpha:0.18];
        [button setTitleColor:filled ? [UIColor whiteColor] : [UIColor labelColor] forState:UIControlStateNormal];
        button.layer.cornerRadius = 12;
        button.translatesAutoresizingMaskIntoConstraints = NO;
        [button.heightAnchor constraintEqualToConstant:46].active = YES;
        [button addAction:[UIAction actionWithHandler:^(__kindof UIAction *action) {
            SCICardClose();
            if (chosen) chosen((NSInteger)index);
        }] forControlEvents:UIControlEventTouchUpInside];
        [stack addArrangedSubview:button];
    }];

    [NSLayoutConstraint activateConstraints:@[
        [card.centerXAnchor constraintEqualToAnchor:root.view.centerXAnchor],
        [card.centerYAnchor constraintEqualToAnchor:root.view.centerYAnchor],
        [card.widthAnchor constraintEqualToConstant:MIN(320, scene.coordinateSpace.bounds.size.width - 48)],
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:22],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-18],
        [stack.leftAnchor constraintEqualToAnchor:card.leftAnchor constant:18],
        [stack.rightAnchor constraintEqualToAnchor:card.rightAnchor constant:-18],
    ]];

    sciCardWindow = window;
    window.hidden = NO;
    return YES;
}
