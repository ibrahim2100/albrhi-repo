//
//  Test_Robust.m
//  Albrhi for YouTube -- host tests
//
//  The parts of the 1.48.0 download work that are pure: what a finished file is (SCIMediaSniff), why a
//  download failed (SCIYTFailure), whether a batch fits (SCIYTPreflight), how many parts to fetch at
//  once (SCIYTConcurrency, driven against a simulated link), the client cascade's decisions, an
//  album's order and file names, a playlist's lengths, and the tags a sound is written with.
//
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "shared/src/SCIMediaSniff.h"
#import "Features/Download/SCIYTFailure.h"
#import "Features/Download/SCIYTPreflight.h"
#import "Features/Download/SCIYTConcurrency.h"
#import "Features/Download/SCIYTClients.h"
#import "Features/Download/SCIYTAlbum.h"
#import "Features/Download/SCIYTPlaylist.h"
#import "Features/Download/SCIYTFragments.h"
#import "Features/Interface/SCIYTRyd.h"
#import "AlbrhiTestKit.h"

// What Prefs.h's SCIPrefEnabled reaches for; the real ones need the panel and the launch guard.
BOOL SCIPanelAllowsThisApp(void) { return YES; }
void SCIYTLaunchMark(NSString *label) { (void)label; }

static NSData *SCIBytes(const char *text) { return [NSData dataWithBytes:text length:strlen(text)]; }

/// A simulated link: `capacity` connections worth of bandwidth at 1 MB/s each, and a server that
/// answers 429 when more than `limit` are open.
typedef struct { int capacity; int limit; } SCILink;
static double SCILinkRate(SCILink link, int n) { return (double)MIN(n, link.capacity) * 1e6; }

void Test_Robust(void) {
    printf("what a finished file is\n");

    ALBRHI_TEST(sniff_recognises_media_containers, {
        uint8_t ftyp[] = {0,0,0,0x20,'f','t','y','p','i','s','o','m',0,0,0,0};
        ALBRHI_ASSERT(SCIMediaSniff([NSData dataWithBytes:ftyp length:sizeof ftyp]) == SCIMediaKindMP4, @"mp4");
        uint8_t moof[] = {0,0,0,0x10,'m','o','o','f',0,0,0,0};
        ALBRHI_ASSERT(SCIMediaSniff([NSData dataWithBytes:moof length:sizeof moof]) == SCIMediaKindFragmentedMP4, @"fragment");
        uint8_t webm[] = {0x1A,0x45,0xDF,0xA3,0x9F,0x42};
        ALBRHI_ASSERT(SCIMediaSniff([NSData dataWithBytes:webm length:sizeof webm]) == SCIMediaKindWebM, @"webm");
        ALBRHI_ASSERT(SCIMediaSniff(SCIBytes("ID3\x03\x00\x00\x00")) == SCIMediaKindMP3, @"mp3 tag");
        uint8_t adts[] = {0xFF,0xF1,0x50,0x80,0x00,0x1F,0xFC};
        ALBRHI_ASSERT(SCIMediaSniff([NSData dataWithBytes:adts length:sizeof adts]) == SCIMediaKindAAC, @"aac");
        uint8_t jpeg[] = {0xFF,0xD8,0xFF,0xE0,0,0x10};
        ALBRHI_ASSERT(SCIMediaSniff([NSData dataWithBytes:jpeg length:sizeof jpeg]) == SCIMediaKindImage, @"jpeg");
        NSMutableData *ts = [NSMutableData dataWithLength:400];
        ((uint8_t *)ts.mutableBytes)[0] = 0x47; ((uint8_t *)ts.mutableBytes)[188] = 0x47;
        ALBRHI_ASSERT(SCIMediaSniff(ts) == SCIMediaKindMPEGTS, @"transport stream needs the second packet");
    });

    ALBRHI_TEST(sniff_refuses_pages_and_nothing_but_not_unknown_binary, {
        ALBRHI_ASSERT(SCIMediaKindIsRefused(SCIMediaSniff(SCIBytes("<!DOCTYPE html><html><body>Access denied"))), @"html");
        ALBRHI_ASSERT(SCIMediaKindIsRefused(SCIMediaSniff(SCIBytes("  \n<?xml version=\"1.0\"?><Error>"))), @"xml after whitespace");
        ALBRHI_ASSERT(SCIMediaKindIsRefused(SCIMediaSniff(SCIBytes("{\"error\":{\"code\":403}}"))), @"json refusal");
        ALBRHI_ASSERT(SCIMediaKindIsRefused(SCIMediaSniff(SCIBytes("Access Denied"))), @"plain refusal");
        ALBRHI_ASSERT(SCIMediaKindIsRefused(SCIMediaSniff([NSData data])), @"empty");
        uint8_t blob[] = {0x00,0x01,0x02,0x7F,0x80,0xFE,0xAA,0x55,0x10,0x20};
        ALBRHI_ASSERT(!SCIMediaKindIsRefused(SCIMediaSniff([NSData dataWithBytes:blob length:sizeof blob])), @"binary nobody recognises is let through");
        ALBRHI_ASSERT(!SCIMediaKindIsRefused(SCIMediaSniff(SCIBytes("WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nhi"))), @"a subtitle file is not an error page");
        ALBRHI_ASSERT(!SCIMediaKindIsRefused(SCIMediaSniff(SCIBytes("1\n00:00:01,000 --> 00:00:02,000\nhi"))), @"nor an srt");
    });

    ALBRHI_TEST(sniff_reads_a_file, {
        NSURL *page = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"albrhi_sniff.mp4"]];
        [SCIBytes("<html>Forbidden</html>") writeToURL:page atomically:YES];
        SCIMediaKind kind = SCIMediaKindUnknown;
        ALBRHI_ASSERT(!SCIMediaFileLooksFinished(page, &kind) && kind == SCIMediaKindDocument, @"an HTML body with an .mp4 name is refused");
        ALBRHI_ASSERT(SCIMediaFileLooksFinished([NSURL fileURLWithPath:@"/nonexistent/file.mp4"], NULL), @"unreadable is not a refusal");
        [[NSFileManager defaultManager] removeItemAtURL:page error:nil];
    });

    printf("why a download failed\n");

    ALBRHI_TEST(failure_names_the_cause_most_specific_first, {
        ALBRHI_ASSERT([SCIYTFailure causeForText:@"LOGIN_REQUIRED: Sign in to confirm you're not a bot" status:0] == SCIYTFailureSignIn, @"sign in");
        ALBRHI_ASSERT([SCIYTFailure causeForText:@"This video may be inappropriate for some users. Sign in to confirm your age" status:0] == SCIYTFailureAge, @"age beats sign-in");
        ALBRHI_ASSERT([SCIYTFailure causeForText:@"The uploader has not made this video available in your country" status:0] == SCIYTFailureRegion, @"region");
        ALBRHI_ASSERT([SCIYTFailure causeForText:@"Private video" status:0] == SCIYTFailureUnavailable, @"private");
        ALBRHI_ASSERT([SCIYTFailure causeForText:@"The Internet connection appears to be offline." status:0] == SCIYTFailureOffline, @"offline");
        ALBRHI_ASSERT([SCIYTFailure causeForText:@"no space left on device" status:0] == SCIYTFailureDiskFull, @"disk");
        ALBRHI_ASSERT([SCIYTFailure causeForText:nil status:429] == SCIYTFailureThrottled, @"429");
        ALBRHI_ASSERT([SCIYTFailure causeForText:@"" status:403] == SCIYTFailureExpired, @"403 with no other word is an expired address");
        ALBRHI_ASSERT([SCIYTFailure causeForText:@"something nobody has seen" status:0] == SCIYTFailureUnknown, @"unknown stays unknown");
    });

    ALBRHI_TEST(failure_reads_nserrors, {
        NSError *disk = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteOutOfSpaceError userInfo:nil];
        ALBRHI_ASSERT([SCIYTFailure causeForError:disk] == SCIYTFailureDiskFull, @"out of space");
        NSError *offline = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil];
        ALBRHI_ASSERT([SCIYTFailure causeForError:offline] == SCIYTFailureOffline, @"no internet");
        ALBRHI_ASSERT([[SCIYTFailure messageForCause:SCIYTFailureDiskFull] length] > 10, @"every cause has a sentence");
        ALBRHI_ASSERT([[SCIYTFailure keyForCause:SCIYTFailureSignIn] isEqualToString:@"dlf_signin"], @"and a key");
    });

    printf("does a batch fit\n");

    ALBRHI_TEST(preflight_estimates_from_measured_rates, {
        // 1000 s at 720p: 0.20 MB/s of picture plus the sound.
        long long bytes = [SCIYTPreflight estimatedBytesForSeconds:1000 height:720 soundOnly:NO];
        ALBRHI_ASSERT(bytes > 210e6 && bytes < 225e6, @"about 216 MB");
        ALBRHI_ASSERT([SCIYTPreflight estimatedBytesForSeconds:1000 height:0 soundOnly:NO] > 4e8, @"tallest counts as 1080p");
        ALBRHI_ASSERT([SCIYTPreflight estimatedBytesForSeconds:1000 height:720 soundOnly:YES] < 20e6, @"sound alone is small");
        ALBRHI_ASSERT([SCIYTPreflight estimatedBytesForSeconds:NAN height:720 soundOnly:NO] == 0 && [SCIYTPreflight estimatedBytesForSeconds:-5 height:720 soundOnly:NO] == 0, @"no nonsense");
    });

    ALBRHI_TEST(preflight_unknown_lengths_take_the_median, {
        NSDictionary *known = @{@"a": @100, @"b": @300, @"c": @200};
        long long withUnknown = [SCIYTPreflight estimatedBytesForVideoIDs:@[@"a", @"b", @"c", @"d"] durations:known height:360 soundOnly:NO];
        long long sum = [SCIYTPreflight estimatedBytesForSeconds:100 height:360 soundOnly:NO] + [SCIYTPreflight estimatedBytesForSeconds:300 height:360 soundOnly:NO]
                      + [SCIYTPreflight estimatedBytesForSeconds:200 height:360 soundOnly:NO] + [SCIYTPreflight estimatedBytesForSeconds:200 height:360 soundOnly:NO];
        ALBRHI_ASSERT(withUnknown == sum, @"the unknown one counts as the median of the others, 200 s");
        ALBRHI_ASSERT([SCIYTPreflight estimatedBytesForVideoIDs:@[@"x"] durations:@{} height:360 soundOnly:NO] == [SCIYTPreflight estimatedBytesForSeconds:600 height:360 soundOnly:NO], @"ten minutes with nothing to go on");
    });

    ALBRHI_TEST(preflight_verdicts, {
        long long gb = 1024LL * 1024 * 1024;
        ALBRHI_ASSERT([SCIYTPreflight verdictForBytes:1 * gb free:20 * gb] == SCIYTPreflightFits, @"plenty");
        ALBRHI_ASSERT([SCIYTPreflight verdictForBytes:8 * gb free:12 * gb] == SCIYTPreflightTight, @"most of what is free");
        ALBRHI_ASSERT([SCIYTPreflight verdictForBytes:12 * gb free:12 * gb] == SCIYTPreflightTooBig, @"all of it, with the margin, does not fit");
        ALBRHI_ASSERT([SCIYTPreflight verdictForBytes:5 * gb free:-1] == SCIYTPreflightFits, @"unreadable free space does not nag");
        ALBRHI_ASSERT([SCIYTPreflight verdictForBytes:0 free:1] == SCIYTPreflightFits, @"nothing to fetch fits");
    });

    printf("how many parts at once\n");

    ALBRHI_TEST(concurrency_climbs_while_it_pays_and_stops_at_the_knee, {
        SCILink link = { .capacity = 6, .limit = 99 };
        SCIConcState state; SCIConcInit(&state, 4);
        int history[40];
        for (int run = 0; run < 40; run++) { history[run] = state.n; SCIConcRecordRun(&state, state.n, SCILinkRate(link, state.n)); }
        ALBRHI_ASSERT(state.n >= 5 && state.n <= 7, @"settles around the link's capacity of 6");
        BOOL steady = YES;
        for (int run = 30; run < 40; run++) if (abs(history[run] - history[39]) > 1) steady = NO;
        ALBRHI_ASSERT(steady, @"and stays there rather than wandering");
    });

    ALBRHI_TEST(concurrency_does_not_climb_past_a_flat_link, {
        SCILink link = { .capacity = 2, .limit = 99 };
        SCIConcState state; SCIConcInit(&state, 4);
        int highest = 0;
        for (int run = 0; run < 40; run++) { SCIConcRecordRun(&state, state.n, SCILinkRate(link, state.n)); highest = MAX(highest, state.n); }
        ALBRHI_ASSERT(highest <= 5 && state.n <= 5, @"more connections gained nothing, so it does not keep adding them");
    });

    ALBRHI_TEST(concurrency_backs_off_a_refusal_and_stays_under_it, {
        SCILink link = { .capacity = 8, .limit = 5 };
        SCIConcState state; SCIConcInit(&state, 4);
        int worstAfterRefusal = 0; BOOL refused = NO;
        for (int run = 0; run < 60; run++) {
            if (state.n > link.limit) { SCIConcRecordThrottle(&state); refused = YES; continue; }
            SCIConcRecordRun(&state, state.n, SCILinkRate(link, state.n));
            if (refused && run < 8) worstAfterRefusal = MAX(worstAfterRefusal, state.n);
        }
        ALBRHI_ASSERT(refused, @"it did reach the limit once");
        ALBRHI_ASSERT(state.n <= 5, @"and was not left above what the server allows");
        SCIConcState hit; SCIConcInit(&hit, 6); SCIConcRecordThrottle(&hit);
        ALBRHI_ASSERT(hit.n == 3 && hit.ceiling == 5, @"a refusal halves the count and holds the ceiling just under it");
    });

    ALBRHI_TEST(concurrency_survives_the_preferences_and_junk, {
        SCIConcState state; SCIConcInit(&state, 4);
        SCIConcRecordRun(&state, 4, 3e6);
        SCIConcState back; SCIConcLoad(&back, SCIConcDictionary(&state), 4);
        ALBRHI_ASSERT(back.n == state.n && back.ceiling == state.ceiling && back.rate[4] == state.rate[4], @"written and read back");
        SCIConcState junk; SCIConcLoad(&junk, @{@"n": @99, @"ceiling": @-3, @"rate": @"nope"}, 4);
        ALBRHI_ASSERT(junk.n >= SCI_CONC_MIN && junk.n <= SCI_CONC_MAX && junk.ceiling >= SCI_CONC_MIN, @"out-of-range numbers are clamped");
        SCIConcRecordRun(&junk, 4, NAN); SCIConcRecordRun(&junk, 0, 1e6); SCIConcRecordRun(&junk, 9, 1e6); SCIConcRecordRun(&junk, 4, -1);
        ALBRHI_ASSERT(junk.n >= SCI_CONC_MIN && junk.n <= SCI_CONC_MAX, @"nonsense measurements change nothing");
    });

    printf("which client answers\n");

    ALBRHI_TEST(clients_are_a_table_in_order, {
        NSArray *all = SCIYTClients.all;
        ALBRHI_ASSERT(all.count == 3, @"visionOS, iOS, Android VR");
        ALBRHI_ASSERT([all[0][@"client"][@"clientName"] isEqualToString:@"VISIONOS"] && [all[0][@"visitor"] boolValue], @"visionOS first, with a visitor id");
        ALBRHI_ASSERT([all[1][@"client"][@"clientName"] isEqualToString:@"IOS"] && [all[1][@"client"][@"clientVersion"] isEqualToString:@"20.10.4"], @"iOS at the version that serves addresses");
        for (NSDictionary *spec in all) ALBRHI_ASSERT([spec[@"agent"] length] > 20 && [spec[@"client"][@"hl"] length], @"each carries its own agent and language");
    });

    ALBRHI_TEST(a_held_back_answer_is_recognised_and_a_short_one_is_not, {
        ALBRHI_ASSERT([SCIYTClients looksDegradedMaxHeight:360 seconds:600], @"360p for ten minutes looks held back");
        ALBRHI_ASSERT(![SCIYTClients looksDegradedMaxHeight:360 seconds:19], @"360p for nineteen seconds is just an old clip");
        ALBRHI_ASSERT(![SCIYTClients looksDegradedMaxHeight:1080 seconds:600], @"1080p is fine");
        ALBRHI_ASSERT(![SCIYTClients looksDegradedMaxHeight:0 seconds:600], @"no picture at all is a refusal, not a degradation");
    });

    ALBRHI_TEST(only_refusals_another_client_may_not_share_move_on, {
        ALBRHI_ASSERT([SCIYTClients refusalMayDifferByClient:@"LOGIN_REQUIRED" reason:@"Sign in to confirm you're not a bot"], @"sign-in differs by client");
        ALBRHI_ASSERT([SCIYTClients refusalMayDifferByClient:@"UNPLAYABLE" reason:nil], @"unplayable may");
        ALBRHI_ASSERT(![SCIYTClients refusalMayDifferByClient:@"LOGIN_REQUIRED" reason:@"This is a private video."], @"private is private for everyone");
        ALBRHI_ASSERT(![SCIYTClients refusalMayDifferByClient:@"UNPLAYABLE" reason:@"The uploader has not made this video available in your country"], @"so is a region lock");
        ALBRHI_ASSERT([SCIYTClients refusalMayDifferByClient:nil reason:nil], @"no answer at all is worth another client");
    });

    printf("albums\n");

    ALBRHI_TEST(album_order_and_names, {
        NSArray *tracks = @[@{@"title": @"Zebra", @"track": @0}, @{@"title": @"Third", @"track": @3}, @{@"title": @"First", @"track": @1},
                            @{@"title": @"Apple", @"track": @0}, @{@"title": @"Second", @"track": @2}];
        NSMutableArray *names = [NSMutableArray array];
        for (NSDictionary *t in [SCIYTAlbum orderedTracks:tracks]) [names addObject:t[@"title"]];
        ALBRHI_ASSERT([names isEqualToArray:(@[@"First", @"Second", @"Third", @"Apple", @"Zebra"])], @"numbered first in order, then the rest by title");
        ALBRHI_ASSERT([[SCIYTAlbum fileNameForTrack:3 of:12 title:@"Song" extension:@"m4a"] isEqualToString:@"03 Song.m4a"], @"padded to two");
        ALBRHI_ASSERT([[SCIYTAlbum fileNameForTrack:7 of:120 title:@"Song" extension:@"m4a"] isEqualToString:@"007 Song.m4a"], @"and wider for a long album");
        ALBRHI_ASSERT([[SCIYTAlbum fileNameForTrack:0 of:0 title:@"Song" extension:@"m4a"] isEqualToString:@"Song.m4a"], @"no number, no prefix");
        ALBRHI_ASSERT([[SCIYTAlbum fileNameForTrack:1 of:9 title:@"AC/DC: \"Hells\" Bells?\n" extension:@"m4a"] isEqualToString:@"01 AC DC Hells Bells.m4a"], @"characters a file name cannot hold become spaces");
        ALBRHI_ASSERT([[SCIYTAlbum folderNameForAlbum:nil] isEqualToString:@"Album"] && [[SCIYTAlbum folderNameForAlbum:@"  .hidden  "] isEqualToString:@"hidden"], @"folder names");
    });

    printf("a playlist's lengths\n");

    ALBRHI_TEST(playlist_lengths_are_read_where_they_are_stated, {
        NSDictionary *page = @{@"contents": @[
            @{@"playlistVideoRenderer": @{@"videoId": @"AAAAAAAAAAA", @"lengthSeconds": @"212"}},
            @{@"playlistVideoRenderer": @{@"videoId": @"BBBBBBBBBBB", @"lengthSeconds": @"0"}},
            @{@"playlistVideoRenderer": @{@"videoId": @"CCCCCCCCCCC"}},
            @{@"playlistVideoRenderer": @{@"videoId": @"short", @"lengthSeconds": @"60"}},
            @{@"playlistVideoRenderer": @{@"videoId": @"DDDDDDDDDDD", @"lengthSeconds": @3600}},
        ]};
        NSDictionary *d = [SCIYTPlaylist durationsInBrowse:page];
        ALBRHI_ASSERT(d.count == 2 && [d[@"AAAAAAAAAAA"] doubleValue] == 212 && [d[@"DDDDDDDDDDD"] doubleValue] == 3600, @"only real lengths of real ids");
    });

    printf("album tags in the file\n");

    ALBRHI_TEST(a_sound_carries_its_album_artist_and_track_number, {
        NSString *dir = NSTemporaryDirectory();
        NSURL *source = [NSURL fileURLWithPath:[dir stringByAppendingPathComponent:@"albrhi_tag_src.m4a"]];
        NSURL *copy = [NSURL fileURLWithPath:[dir stringByAppendingPathComponent:@"albrhi_mux_a0.m4a"]];
        // The mux test leaves a fragmented AAC source behind; use it when it is there.
        if (![[NSFileManager defaultManager] fileExistsAtPath:copy.path]) { printf("    (no source sound on disk; mux test did not run first)\n"); return; }
        [[NSFileManager defaultManager] removeItemAtURL:source error:nil];
        [[NSFileManager defaultManager] copyItemAtURL:copy toURL:source error:nil];

        __block NSURL *out = nil; __block NSString *why = nil;
        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        [SCIYTFragments rewriteAudio:source
                                tags:@{@"title": @"Song", @"artist": @"Channel", @"album": @"The Playlist", @"albumArtist": @"Channel", @"track": @3, @"trackTotal": @12}
                          completion:^(NSURL *o, NSString *f) { out = o; why = f; dispatch_semaphore_signal(done); }];
        while (dispatch_semaphore_wait(done, DISPATCH_TIME_NOW)) [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
        ALBRHI_ASSERT(out != nil, why ?: @"no output");

        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:out options:nil];
        NSString *(^common)(AVMetadataIdentifier) = ^NSString *(AVMetadataIdentifier id_) {
            NSArray *items = [AVMetadataItem metadataItemsFromArray:asset.commonMetadata filteredByIdentifier:id_];
            return [items.firstObject stringValue];
        };
        ALBRHI_ASSERT([common(AVMetadataCommonIdentifierTitle) isEqualToString:@"Song"], @"title");
        ALBRHI_ASSERT([common(AVMetadataCommonIdentifierArtist) isEqualToString:@"Channel"], @"artist");
        ALBRHI_ASSERT([common(AVMetadataCommonIdentifierAlbumName) isEqualToString:@"The Playlist"], @"album is the playlist, not the channel");

        NSArray *itunes = [asset metadataForFormat:AVMetadataFormatiTunesMetadata];
        NSArray *albumArtist = [AVMetadataItem metadataItemsFromArray:itunes filteredByIdentifier:AVMetadataIdentifieriTunesMetadataAlbumArtist];
        ALBRHI_ASSERT([[albumArtist.firstObject stringValue] isEqualToString:@"Channel"], @"album artist");
        NSArray *trk = [AVMetadataItem metadataItemsFromArray:itunes filteredByIdentifier:AVMetadataIdentifieriTunesMetadataTrackNumber];
        NSData *raw = [trk.firstObject dataValue];
        ALBRHI_ASSERT(raw.length >= 6 && ((const uint8_t *)raw.bytes)[3] == 3 && ((const uint8_t *)raw.bytes)[5] == 12, @"track 3 of 12 in the trkn atom");
    });

    printf("dislike counts\n");

    ALBRHI_TEST(ryd_counts_are_compact, {
        ALBRHI_ASSERT([[SCIYTRyd compact:0] isEqualToString:@"0"] && [[SCIYTRyd compact:987] isEqualToString:@"987"], @"under a thousand as is");
        ALBRHI_ASSERT([[SCIYTRyd compact:1000] isEqualToString:@"1K"] && [[SCIYTRyd compact:1234] isEqualToString:@"1.2K"], @"one decimal under ten of a unit");
        ALBRHI_ASSERT([[SCIYTRyd compact:34400] isEqualToString:@"34K"] && [[SCIYTRyd compact:999999] isEqualToString:@"1M"], @"none above, and 999.9K carries up");
        ALBRHI_ASSERT([[SCIYTRyd compact:1.2e6] isEqualToString:@"1.2M"] && [[SCIYTRyd compact:4.7e9] isEqualToString:@"4.7B"], @"millions and billions");
        ALBRHI_ASSERT([[SCIYTRyd compact:-5] isEqualToString:@"—"] && [[SCIYTRyd compact:NAN] isEqualToString:@"—"], @"nonsense is a dash");
    });

    ALBRHI_TEST(ryd_answers_are_read_or_refused, {
        NSDictionary *good = @{@"id": @"x", @"likes": @1500, @"dislikes": @34000, @"rating": @4.2, @"viewCount": @9000000, @"deleted": @NO};
        NSDictionary *ok = [SCIYTRyd parseVotes:good];
        ALBRHI_ASSERT([ok[@"dislikes"] intValue] == 34000 && [ok[@"likes"] intValue] == 1500 && fabs([ok[@"rating"] doubleValue] - 4.2) < 1e-9 && [ok[@"views"] intValue] == 9000000, @"the figures");
        NSDictionary *none = @{@"likes": @0, @"dislikes": @0};
        ALBRHI_ASSERT([SCIYTRyd parseVotes:none] == nil, @"nothing known is not a zero to show");
        NSDictionary *negative = @{@"likes": @-1, @"dislikes": @5};
        ALBRHI_ASSERT([SCIYTRyd parseVotes:negative] == nil, @"negative counts");
        NSDictionary *text = @{@"likes": @"1", @"dislikes": @2};
        NSArray *array = @[];
        ALBRHI_ASSERT([SCIYTRyd parseVotes:text] == nil && [SCIYTRyd parseVotes:array] == nil && [SCIYTRyd parseVotes:nil] == nil, @"wrong shapes");
        NSDictionary *gone = @{@"likes": @5, @"dislikes": @5, @"deleted": @YES};
        ALBRHI_ASSERT([SCIYTRyd parseVotes:gone] == nil, @"a removed video");
    });
}
