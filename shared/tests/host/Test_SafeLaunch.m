//
//  Test_SafeLaunch.m -- the rule behind SCISafeLaunch
//
#import <Foundation/Foundation.h>
#import "shared/src/SCISafeLaunch.h"

static int failures = 0, checks = 0;
#define CHECK(cond, ...) do { checks++; if (!(cond)) { failures++; NSLog(@"FAIL: %@", __VA_ARGS__); } } while (0)

static SCISafeLaunchState Run(SCISafeLaunchState s, SCISafeLaunchEvent e) { return SCISafeLaunchStep(s, e); }

int main(void) {
    @autoreleasepool {
        SCISafeLaunchState s = {NO, 0, NO};

        // A healthy launch: begin, then stable. Nothing accumulates.
        s = Run(s, SCISafeLaunchEventBegin);
        CHECK(s.pending && s.failures == 0 && !s.paused, @"first begin");
        s = Run(s, SCISafeLaunchEventStable);
        CHECK(!s.pending && s.failures == 0 && !s.paused, @"stable clears");

        // One crash (begin, then begin again with the mark standing) is not enough.
        s = Run(s, SCISafeLaunchEventBegin);
        s = Run(s, SCISafeLaunchEventBegin);
        CHECK(s.failures == 1 && !s.paused, @"one failed launch does not pause");
        // ...and a good launch afterwards forgets it.
        s = Run(s, SCISafeLaunchEventStable);
        s = Run(s, SCISafeLaunchEventBegin);
        CHECK(s.failures == 0 && !s.paused, @"recovery resets the count");
        s = Run(s, SCISafeLaunchEventStable);

        // Two in a row pause -- on the *third* launch, which is the one that must not install anything.
        s = Run(s, SCISafeLaunchEventBegin);   // launch 1: dies
        s = Run(s, SCISafeLaunchEventBegin);   // launch 2: dies   (failures 1)
        CHECK(!s.paused, @"not yet after two launches");
        s = Run(s, SCISafeLaunchEventBegin);   // launch 3: finds two failures
        CHECK(s.paused && s.failures == 2, @"third launch is the paused one");

        // Paused stays paused through any number of ordinary events: only the person's choice brings Albrhi back.
        for (int i = 0; i < 5; i++) { s = Run(s, SCISafeLaunchEventBegin); s = Run(s, SCISafeLaunchEventStable); }
        CHECK(s.paused, @"stable launches while paused do not un-pause");
        s = Run(s, SCISafeLaunchEventLeft);
        CHECK(s.paused, @"leaving does not un-pause");

        // Resume.
        s = Run(s, SCISafeLaunchEventResume);
        CHECK(!s.paused && s.failures == 0 && !s.pending, @"resume clears everything");
        s = Run(s, SCISafeLaunchEventBegin);
        CHECK(!s.paused && s.failures == 0, @"after resume the next launch is ordinary");

        // A launch in the background (a push) is no evidence: it neither pauses nor counts.
        s = (SCISafeLaunchState){NO, 0, NO};
        s = Run(s, SCISafeLaunchEventBegin);
        s = Run(s, SCISafeLaunchEventBackground);
        s = Run(s, SCISafeLaunchEventBegin);
        s = Run(s, SCISafeLaunchEventBackground);
        s = Run(s, SCISafeLaunchEventBegin);
        CHECK(!s.paused && s.failures == 0, @"background launches never pause");

        // Leaving on purpose before three seconds is not a crash either (swiping the app away).
        s = (SCISafeLaunchState){NO, 0, NO};
        for (int i = 0; i < 10; i++) { s = Run(s, SCISafeLaunchEventBegin); s = Run(s, SCISafeLaunchEventLeft); }
        CHECK(!s.paused, @"ten quick open-and-leave launches do not pause");

        // A crash-free history that includes one crash every other launch never pauses (the failures reset in between).
        s = (SCISafeLaunchState){NO, 0, NO};
        for (int i = 0; i < 10; i++) {
            s = Run(s, SCISafeLaunchEventBegin);          // crashes
            s = Run(s, SCISafeLaunchEventBegin);          // starts fine
            s = Run(s, SCISafeLaunchEventStable);
        }
        CHECK(!s.paused, @"alternating crash and success never pauses");

        // A background launch in the middle of a streak softens it by one, never below zero.
        s = (SCISafeLaunchState){NO, 0, NO};
        s = Run(s, SCISafeLaunchEventBackground);
        CHECK(s.failures == 0, @"never negative");
        CHECK(SCISafeLaunchLimit == 2, @"the limit is the documented one");
    }
    printf("SCISafeLaunch rule: %d checks, %d failed\n", checks, failures);
    return failures ? 1 : 0;
}
