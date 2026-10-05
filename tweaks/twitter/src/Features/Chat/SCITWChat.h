//
//  SCITWChat.h
//  Albrhi for X
//
//  What a conversation tells the other side while you are in it: that you are typing, and
//  that you took a screenshot.
//
//  Both are the same kind of thing as Instagram's seen receipts and TikTok's read-sync in
//  this repository: a report that leaves the phone about something the person never chose
//  to announce. Neither tells X's servers anything untrue -- the typing frame is not sent,
//  and an observer that would have told X about a screenshot is never registered -- which is
//  the line this project keeps (and the reason `app_attest_*` is not offered).
//
//  Both attach only when their switch was on at launch, and say so on the switch: off means
//  no hook at all, and a change needs X to be reopened.
//
//  The approach is NeoFreeBird's (orionblur, GPLv3, `src/Hooks/Chat.x` and `Misc.x`); the
//  frame shape that identifies the typing heartbeat is theirs and was measured by them, not
//  by this project, so the counters below say how many frames were seen and how many dropped.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NSString *SCITWChatReport(void);
void SCITWInstallChat(void);
