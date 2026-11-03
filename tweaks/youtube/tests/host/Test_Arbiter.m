//
//  Test_Arbiter.m
//  Albrhi for YouTube — host tests
//
//  Who is allowed to play (SCIYTArbiterCore.h, compiled as shipped): exactly one owner, a
//  lock-screen button answered by exactly one side, and YouTube's start read as the echo of one
//  of our commands only inside a short window. What YouTube actually does is a device's question.
//
#import <Foundation/Foundation.h>
#import "Features/Download/Center/SCIYTArbiterCore.h"
#import "AlbrhiTestKit.h"

void Test_Arbiter(void) {
    printf("one player at a time\n");

    ALBRHI_TEST(a_fresh_state_belongs_to_nobody, {
        SCIArbiterState s = { SCIOwnerNone, 0 };
        ALBRHI_ASSERT(!SCIArbiterOursMayAct(&s), @"ours does not answer buttons it was never given");
        ALBRHI_ASSERT(!SCIArbiterHostMustStandBack(&s), @"YouTube answers when ours never played");
        ALBRHI_ASSERT(SCIArbiterOursMayDescribe(&s), @"nothing forbids writing an entry");
    });

    ALBRHI_TEST(starting_ours_makes_it_the_only_one_to_answer, {
        SCIArbiterState s = { SCIOwnerNone, 0 };
        SCIArbiterOursStarted(&s, 10);
        ALBRHI_ASSERT(SCIArbiterOursMayAct(&s), @"ours answers");
        ALBRHI_ASSERT(SCIArbiterHostMustStandBack(&s), @"YouTube's handlers stand back");
    });

    ALBRHI_TEST(youtube_starting_inside_the_window_is_an_echo_and_is_vetoed, {
        SCIArbiterState s = { SCIOwnerNone, 0 };
        SCIArbiterOursStarted(&s, 10);
        ALBRHI_ASSERT(SCIArbiterHostStarted(&s, 10.4, 1) == 1, @"the lock screen's Play reached both handlers");
        ALBRHI_ASSERT(s.owner == SCIOwnerOurs, @"ownership did not move");
    });

    ALBRHI_TEST(a_command_keeps_the_window_open, {
        SCIArbiterState s = { SCIOwnerNone, 0 };
        SCIArbiterOursStarted(&s, 10);
        SCIArbiterOursCommanded(&s, 40);
        ALBRHI_ASSERT(SCIArbiterHostStarted(&s, 40.5, 1) == 1, @"half a second after a command is still its echo");
    });

    ALBRHI_TEST(youtube_starting_later_is_a_real_start_and_takes_over, {
        SCIArbiterState s = { SCIOwnerNone, 0 };
        SCIArbiterOursStarted(&s, 10);
        ALBRHI_ASSERT(SCIArbiterHostStarted(&s, 25, 1) == 0, @"a video chosen in YouTube's own screen");
        ALBRHI_ASSERT(s.owner == SCIOwnerHost, @"YouTube owns playback");
        ALBRHI_ASSERT(!SCIArbiterOursMayAct(&s), @"ours stops answering");
        ALBRHI_ASSERT(!SCIArbiterHostMustStandBack(&s), @"YouTube answers");
        ALBRHI_ASSERT(!SCIArbiterOursMayDescribe(&s), @"a paused mini bar does not overwrite YouTube's entry");
    });

    ALBRHI_TEST(youtube_starting_while_ours_is_paused_is_never_an_echo, {
        SCIArbiterState s = { SCIOwnerNone, 0 };
        SCIArbiterOursStarted(&s, 10);
        ALBRHI_ASSERT(SCIArbiterHostStarted(&s, 10.2, 0) == 0, @"nothing is being talked over");
        ALBRHI_ASSERT(s.owner == SCIOwnerHost, @"the host owns it");
    });

    ALBRHI_TEST(ours_taking_back_after_youtube_works, {
        SCIArbiterState s = { SCIOwnerNone, 0 };
        SCIArbiterHostStarted(&s, 5, 0);
        SCIArbiterOursStarted(&s, 30);
        ALBRHI_ASSERT(SCIArbiterOursMayAct(&s) && SCIArbiterHostMustStandBack(&s), @"the last to start owns it");
    });

    ALBRHI_TEST(closing_ours_releases_ownership_only_if_it_was_ours, {
        SCIArbiterState s = { SCIOwnerNone, 0 };
        SCIArbiterOursStarted(&s, 1);
        SCIArbiterOursEnded(&s);
        ALBRHI_ASSERT(s.owner == SCIOwnerNone, @"released");

        SCIArbiterState h = { SCIOwnerHost, 0 };
        SCIArbiterOursEnded(&h);
        ALBRHI_ASSERT(h.owner == SCIOwnerHost, @"closing the mini bar must not take YouTube's ownership away");
    });

    ALBRHI_TEST(a_command_from_ours_while_the_host_owns_does_not_open_a_window, {
        SCIArbiterState s = { SCIOwnerHost, 0 };
        SCIArbiterOursCommanded(&s, 50);
        ALBRHI_ASSERT(s.oursAt == 0 && s.owner == SCIOwnerHost, @"nothing changed");
    });
}
