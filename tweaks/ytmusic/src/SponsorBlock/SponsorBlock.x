//
//  SponsorBlock.x
//  Albrhi for YouTube Music
//
//  Carried over from YTMEnhanced (github.com/py233/YTMEnhanced) under GPLv3, itself derived
//  from YTMusicUltimate. Kept diffable against upstream: the edits are the %group wrapper and
//  its installer, the shared YTMU() reader, and any one-line %orig body opened out because
//  the Logos this repository pins needs %orig alone in a full block.
//
#import "../YTMShared.h"
#import "shared/src/SCIKVC.h"
#import "../Localization/SCILocalize.h"



static id YTMUSponsorBlockSafeValueForKey(id object, NSString *key) {
    if (!object || !key.length) return nil;
    @try {
        return SCISafeValueForKey(object, key);
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static NSString *YTMUSponsorBlockCurrentVideoID(YTPlayerViewController *player) {
    NSString *videoID = @"";
    @try {
        videoID = player.currentVideoID ?: player.contentVideoID ?: @"";
    } @catch (__unused NSException *exception) {
        videoID = @"";
    }
    if (!videoID.length) {
        id value = YTMUSponsorBlockSafeValueForKey(player, @"currentVideoID") ?: YTMUSponsorBlockSafeValueForKey(player, @"contentVideoID");
        if ([value isKindOfClass:[NSString class]]) videoID = value;
        else if ([value respondsToSelector:@selector(stringValue)]) videoID = [value stringValue];
    }
    return videoID ?: @"";
}

static CGFloat YTMUSponsorBlockCurrentVideoTime(YTPlayerViewController *player) {
    @try {
        return player.currentVideoMediaTime;
    } @catch (__unused NSException *exception) {
        id value = YTMUSponsorBlockSafeValueForKey(player, @"currentVideoMediaTime");
        return [value respondsToSelector:@selector(floatValue)] ? [value floatValue] : 0;
    }
}

%group YTMSponsorBlock

%hook YTPlayerViewController
%property (nonatomic, strong) NSMutableDictionary *sponsorBlockValues;

- (void)playbackController:(id)arg1 didActivateVideo:(id)arg2 withPlaybackData:(id)arg3 {
    %orig;

    if (!YTMU(@"sponsorBlock")) return;

    self.sponsorBlockValues = [NSMutableDictionary dictionary];
    NSString *videoID = YTMUSponsorBlockCurrentVideoID(self);
    if (!videoID.length) return;

    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://sponsor.ajay.app/api/skipSegments?videoID=%@&categories=%@", videoID, @"%5B%22music_offtopic%22%5D"]]];

    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!error) {
            id jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([jsonResponse isKindOfClass:[NSArray class]] && [NSJSONSerialization isValidJSONObject:jsonResponse]) {
                NSMutableDictionary *segments = [NSMutableDictionary dictionary];
                for (NSDictionary *segmentDict in jsonResponse) {
                    if (![segmentDict isKindOfClass:[NSDictionary class]]) continue;
                    NSString *uuid = segmentDict[@"UUID"];
                    if (!uuid.length) continue;
                    [segments setObject:@(1) forKey:uuid];
                }

                [self.sponsorBlockValues setObject:jsonResponse forKey:videoID];
                [self.sponsorBlockValues setObject:segments forKey:@"segments"];
            }
        }
    }] resume];
}

- (void)singleVideo:(id)video currentVideoTimeDidChange:(id)time {
    %orig;

    [self skipSegment];
}

- (void)potentiallyMutatedSingleVideo:(id)video currentVideoTimeDidChange:(id)time {
    %orig;

    [self skipSegment];
}

%new(v@:)
- (void)skipSegment {
    if (YTMU(@"sponsorBlock") && [NSJSONSerialization isValidJSONObject:self.sponsorBlockValues]) {
        NSString *videoID = YTMUSponsorBlockCurrentVideoID(self);
        if (!videoID.length) return;
        NSDictionary *sponsorBlockValues = [self.sponsorBlockValues objectForKey:videoID];
        NSMutableDictionary *segmentSkipValues = [self.sponsorBlockValues objectForKey:@"segments"];
        CGFloat currentTime = YTMUSponsorBlockCurrentVideoTime(self);

        for (NSDictionary *jsonDictionary in sponsorBlockValues) {
            if (![jsonDictionary isKindOfClass:[NSDictionary class]]) continue;
            NSString *uuid = [jsonDictionary objectForKey:@"UUID"];
            NSNumber *segmentSkipValue = [segmentSkipValues objectForKey:uuid];
            NSArray *segment = [jsonDictionary objectForKey:@"segment"];
            if (![segment isKindOfClass:[NSArray class]] || segment.count < 2) continue;

            if (segmentSkipValue && [segmentSkipValue isEqual:@(1)]
                && [[jsonDictionary objectForKey:@"category"] isEqual:@"music_offtopic"]
                && currentTime >= [segment[0] floatValue]
                && currentTime <= ([segment[1] floatValue] - 1)) {

                [segmentSkipValues setObject:@(0) forKey:uuid];
                [self.sponsorBlockValues setObject:segmentSkipValues forKey:@"segments"];

                GOOHUDMessageAction *unskipAction = [[%c(GOOHUDMessageAction) alloc] init];
                unskipAction.title = SCILocalized(@"sb_unskip");
                [unskipAction setHandler:^ {
                    [self seekToTime:[segment[0] floatValue]];
                }];
                
                GOOHUDMessageAction *skipAction = [[%c(GOOHUDMessageAction) alloc] init];
                skipAction.title = SCILocalized(@"sb_skip");
                [skipAction setHandler:^ {
                    [self seekToTime:[segment[1] floatValue]];

                    [[%c(YTMToastController) alloc] showMessage:SCILocalized(@"sb_skipped") HUDMessageAction:unskipAction infoType:0 duration:YTMUInt(@"sbDuration")];
                }];

                if (YTMUInt(@"sbSkipMode") == 0) {
                    [self seekToTime:[segment[1] floatValue]];

                    [[%c(YTMToastController) alloc] showMessage:SCILocalized(@"sb_skipped") HUDMessageAction:unskipAction infoType:0 duration:YTMUInt(@"sbDuration")];
                }

                else {
                    [[%c(YTMToastController) alloc] showMessage:SCILocalized(@"sb_found") HUDMessageAction:skipAction infoType:0 duration:YTMUInt(@"sbDuration")];
                }
            }
        }
    }
}
%end

%end

void SCIYTMInstallSponsorBlock(void) { %init(YTMSponsorBlock); }
