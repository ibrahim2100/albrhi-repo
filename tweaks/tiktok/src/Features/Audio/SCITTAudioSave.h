//
//  SCITTAudioSave.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>
#import "../Download/SCITTMedia.h"

NS_ASSUME_NONNULL_BEGIN

/// The video's own sound -- voice and music together -- as an `.m4a`, handed to the share sheet (Save to Files, AirDrop, any app).
void SCITTAudioSaveVideoSound(SCITTMediaItem *item);

/// The post's sound on its own (the music or recording the post uses), as the file TikTok serves, handed to the share sheet.
void SCITTAudioSavePostSound(NSURL *sound, NSString *_Nullable itemID);

NSString *SCITTAudioReport(void);

NS_ASSUME_NONNULL_END
