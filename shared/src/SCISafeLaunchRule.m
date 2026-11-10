//
//  SCISafeLaunchRule.m
//  Albrhi -- shared
//
//  The rule on its own, with no UIKit, so a Mac can test it (shared/tests/host).
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCISafeLaunch.h"

const NSInteger SCISafeLaunchLimit = 2;

SCISafeLaunchState SCISafeLaunchStep(SCISafeLaunchState s, SCISafeLaunchEvent event) {
    switch (event) {
        case SCISafeLaunchEventBegin:
            // The previous launch left its mark standing: it neither started fine nor left on purpose.
            if (s.pending) s.failures += 1; else s.failures = 0;
            if (s.failures >= SCISafeLaunchLimit) s.paused = YES;
            s.pending = YES;
            break;
        case SCISafeLaunchEventBackground:
            // Not a launch anybody waited for: it says nothing about the tweak either way.
            s.pending = NO;
            s.failures = MAX(0, s.failures - 1);
            break;
        case SCISafeLaunchEventStable:
        case SCISafeLaunchEventLeft:
            s.pending = NO;
            s.failures = 0;
            break;
        case SCISafeLaunchEventResume:
            s.paused = NO;
            s.failures = 0;
            s.pending = NO;
            break;
    }
    return s;
}

