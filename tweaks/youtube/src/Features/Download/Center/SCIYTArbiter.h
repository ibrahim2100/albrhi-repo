//
//  SCIYTArbiter.h
//  Albrhi for YouTube
//
//  One player at a time. See SCIYTArbiterCore.h for the rules and SCIYTArbiter.m for where they
//  are enforced inside YouTube.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>
#import "SCIYTArbiterCore.h"

@interface SCIYTArbiter : NSObject

+ (SCIOwner)owner;

/// The Centre's player started playing, or was told to by the person.
+ (void)oursStarted;

/// One of our lock-screen or on-screen commands was handled (keeps the echo window open).
+ (void)oursCommanded;

/// The Centre's player was stopped for good.
+ (void)oursEnded;

/// Stops YouTube's players (the watch page's and Shorts') -- ours is about to play.
+ (void)pauseHostPlayers;

/// Whether YouTube's handlers must stand back (our player owns playback).
+ (BOOL)hostMustStandBack;

/// Whether our lock-screen handlers should act now. Exactly one of ours and YouTube's answers.
+ (BOOL)oursMayAct;

/// Whether the "now playing" entry may be written by us.
+ (BOOL)oursMayDescribe;

/// A line for the diagnostics page: the owner, and for each hook whether it attached and how
/// many times it acted.
+ (NSString *)report;

@end
