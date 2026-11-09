//
//  SCITTVoiceMessage.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>
#import "../Download/SCITTMedia.h"

NS_ASSUME_NONNULL_BEGIN

/// Installs the one hook: `AVAudioRecorder -stop`, which swaps the file a finished recording wrote for the sound that was prepared.
void SCITTInstallVoiceMessage(void);

/// Fetches this video, takes its sound as an `.m4a` (the first 60 seconds), and arms it: **the next recording that stops is replaced by it**.
/// Progress and the result are shown in the tweak's own banner. Does nothing visible if `item` has no link.
void SCITTVoicePrepareFromItem(SCITTMediaItem *item);

/// Whether a prepared sound is waiting, and drops it.
BOOL SCITTVoiceIsArmed(void);
void SCITTVoiceDisarm(void);

NSString *SCITTVoiceReport(void);

NS_ASSUME_NONNULL_END
