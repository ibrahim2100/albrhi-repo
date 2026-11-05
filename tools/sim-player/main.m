// A throwaway simulator app around the REAL Download Centre player sources (see build.sh).
#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#include <dlfcn.h>
#import <objc/runtime.h>
#import "Features/Download/Center/SCIYTPlayer.h"
#import "Features/Download/Center/SCIYTJob.h"
#import "Features/Download/Center/SCIYTLibrary.h"
#import "Features/Download/Center/SCIYTCaptionSettings.h"
#import "Features/Download/Center/SCIYTQueueSheet.h"
#import "Features/Download/Center/SCIYTHostPlayer.h"
#import "Features/Download/Center/SCIYTArbiter.h"
#import "Features/Download/Center/SCIYTChoiceSheet.h"
#import "Diagnostics/SCIYTDiagnostics.h"
#import "SCIYTLaunchGuard.h"
#import "Features/Download/SCIYTParts.h"
#ifdef SIM_FULL
#import "Features/Download/Center/SCIYTPlaylistSheet.h"
#endif
#import "Features/Download/SCIYTRecipe.h"
#import <AVFoundation/AVFoundation.h>

// ---- Stubs for what the player reaches that a Mac-side harness has no business running.
NSString *SCIVersionString = @"harness";
BOOL SCIPanelAllowsThisApp(void) { return YES; }

#ifndef SIM_FULL
@implementation SCIYTLibrary
+ (instancetype)shared { static SCIYTLibrary *l; static dispatch_once_t o; dispatch_once(&o, ^{ l = [SCIYTLibrary new]; }); return l; }
+ (NSURL *)folder {
    NSURL *u = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject URLByAppendingPathComponent:@"lib"];
    [[NSFileManager defaultManager] createDirectoryAtURL:u withIntermediateDirectories:YES attributes:nil error:nil];
    return u;
}
- (void)save {}
- (void)ensureSponsorSegmentsFor:(SCIYTJob *)job completion:(void (^)(void))completion { if (completion) completion(); }
@end
#endif

@implementation SCIYTHostPlayer
+ (void)pauseHost {}
+ (NSString *)activeVideoID { return nil; }
@end

@implementation SCIYTDiagnostics
+ (BOOL)resolveClassMethod:(SEL)sel { class_addMethod(object_getClass(self), sel, imp_implementationWithBlock(^(id _s) { return (id)nil; }), "@@:"); return YES; }
@end

#ifndef SIM_FULL
@implementation SCIHLSVariant
- (NSString *)label { return [NSString stringWithFormat:@"%ldp · %@", (long)self.height, [self.codecs containsString:@"av01"] ? @"AV1" : @"H.264"]; }
@end
#endif

// ---- Stand-ins for YouTube's classes, with the exact selectors and encodings of 21.41.5, so the arbiter's REAL hooks
// ---- install on them and can be driven.
static BOOL gMuted = NO;
@interface YTSingleVideoController : NSObject @end
@implementation YTSingleVideoController
- (void)play { NSLog(@"[HOSTTEST] fake YouTube play ran"); }
- (BOOL)isMuted { return gMuted; }
- (float)volume { return 1; }
@end
@interface YTRemoteCommandHandler : NSObject @end
@implementation YTRemoteCommandHandler
- (NSInteger)handlePlayCommand:(id)e { NSLog(@"[HOSTTEST] fake YouTube handlePlay ran"); return 0; }
@end
@interface YTNowPlayingInfoCenterPlaybackObserverImpl : NSObject @end
@implementation YTNowPlayingInfoCenterPlaybackObserverImpl
- (void)clearNowPlayingInfo { NSLog(@"[HOSTTEST] fake YouTube clearNowPlayingInfo ran"); }
@end

// ---- What the SYSTEM believes is now playing (MediaRemote, private -- this probe lives only in the harness).
static void SCIProbeNowPlaying(NSString *tag) {
    static void *lib; static dispatch_once_t once;
    dispatch_once(&once, ^{ lib = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW); });
    if (!lib) { NSLog(@"[NPTEST] %@ MediaRemote not loadable", tag); return; }
    void (*getInfo)(dispatch_queue_t, void (^)(CFDictionaryRef)) = dlsym(lib, "MRMediaRemoteGetNowPlayingInfo");
    void (*getPlaying)(dispatch_queue_t, void (^)(Boolean)) = dlsym(lib, "MRMediaRemoteGetNowPlayingApplicationIsPlaying");
    void (*getClient)(dispatch_queue_t, void (^)(id)) = dlsym(lib, "MRMediaRemoteGetNowPlayingClient");
    dispatch_queue_t q = dispatch_get_main_queue();
    if (getPlaying) getPlaying(q, ^(Boolean playing) { NSLog(@"[NPTEST] %@ system says the now-playing app is playing = %d", tag, playing); });
    if (getInfo) getInfo(q, ^(CFDictionaryRef info) {
        NSDictionary *d = (__bridge NSDictionary *)info;
        NSLog(@"[NPTEST] %@ system now-playing title=%@ rate=%@ keys=%lu", tag, d[@"kMRMediaRemoteNowPlayingInfoTitle"], d[@"kMRMediaRemoteNowPlayingInfoPlaybackRate"], (unsigned long)d.count);
    });
    if (getClient) getClient(q, ^(id client) { NSLog(@"[NPTEST] %@ system now-playing client = %@", tag, client ? [client description] : @"NONE"); });
}

static void SCIAfter(double seconds, void (^block)(void)) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), block);
}

@interface Root : UIViewController @end
@implementation Root
- (void)viewDidAppear:(BOOL)a {
    [super viewDidAppear:a];
    static BOOL once; if (once) return; once = YES;
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];



    // -badfirst: the first client in the cascade is made to ask for something that does not exist, so
    // the route has to fall through to the next one -- the only way to see the cascade work while the
    // real first client is healthy.
    if ([d boolForKey:@"badfirst"]) {
        Method m = class_getClassMethod(objc_getClass("SCIYTClients"), NSSelectorFromString(@"all"));
        NSArray *(*orig)(id, SEL) = (NSArray *(*)(id, SEL))method_getImplementation(m);
        method_setImplementation(m, imp_implementationWithBlock(^NSArray *(id self_) {
            NSMutableArray *list = [orig(self_, NSSelectorFromString(@"all")) mutableCopy];
            NSMutableDictionary *first = [list.firstObject mutableCopy];
            NSMutableDictionary *client = [first[@"client"] mutableCopy];
            client[@"clientName"] = @"NO_SUCH_CLIENT";
            first[@"client"] = client;
            list[0] = first;
            return list;
        }));
        NSLog(@"[CASCADE] first client broken on purpose");
    }
#ifdef SIM_FULL
    if ([d boolForKey:@"playlisttest"]) { [SCIYTParts useForegroundSessionForHarness]; [SCIYTPlaylistSheet presentFrom:self]; return; }
    // The REAL library, direct route, parts, recipe and muxer, against YouTube itself.
    //   -dltest <videoID> [-audio YES]   queue one download (240p at most, an extra language and two captions)
    //   -dlwatch YES                     only watch: what the last launch left (the library resumes it by itself)
    if ([d stringForKey:@"dltest"].length || [d boolForKey:@"dlwatch"]) {
        [SCIYTParts useForegroundSessionForHarness];
        if ([d stringForKey:@"dltest"].length) {
            SCIYTRecipe *r = [SCIYTRecipe new];
            r.videoID = [d stringForKey:@"dltest"]; r.maxHeight = [d integerForKey:@"height"] ?: 240; r.audioOnly = [d boolForKey:@"audio"];
            r.extraAudioIDs = @[@"ar.3"]; r.captionIDs = @[@"en", @"ar"];
            [[SCIYTLibrary shared] enqueueRecipes:@[r]];
        }
        __block NSString *last = @"";
        NSTimer *poll = [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer *t) {
            for (SCIYTJob *job in [SCIYTLibrary shared].jobs) {
                NSString *line = [NSString stringWithFormat:@"%@ | %@ | state %ld | %@", job.title, job.quality, (long)job.state, [job statusLine]];
                if ([line isEqualToString:last]) continue;
                last = line;
                NSLog(@"[DLTEST] %@", line);
                if (job.state == SCIYTJobStateDone && job.fileURL) {
                    AVURLAsset *a = [AVURLAsset URLAssetWithURL:job.fileURL options:nil];
                    NSMutableArray *langs = [NSMutableArray array];
                    for (AVAssetTrack *tr in a.tracks) [langs addObject:[NSString stringWithFormat:@"%@:%@%@", [tr.mediaType substringToIndex:4], tr.extendedLanguageTag ?: @"-", tr.isEnabled ? @"" : @"(off)"]];
                    NSMutableArray *meta = [NSMutableArray array];
                    for (AVMetadataItem *m in a.commonMetadata) [meta addObject:[NSString stringWithFormat:@"%@=%@", m.commonKey, [m.commonKey isEqualToString:@"artwork"] ? [NSString stringWithFormat:@"%lu bytes", (unsigned long)[(NSData *)m.value length]] : m.stringValue]];
                    NSLog(@"[DLTEST] FILE %@ %lld bytes, %.1f s | tracks %@ | tags %@", job.fileName, job.bytes, CMTimeGetSeconds(a.duration), [langs componentsJoinedByString:@" "], [meta componentsJoinedByString:@"; "]);
                }
            }
        }];
        (void)poll;
        return;
    }
#endif
    if ([d boolForKey:@"partstest"]) {
        // The real parts fetcher against tools/sim-player/range-server.py: eight parts of 1 MB, kept under one
        // name. Kill the app mid-way and launch again: what arrived must not be fetched a second time.
        NSMutableArray *urls = [NSMutableArray array], *sizes = [NSMutableArray array];
        for (int i = 0; i < 8; i++) {
            [urls addObject:[NSString stringWithFormat:@"http://127.0.0.1:8765/blob?v=1&range=%d-%d", i * 1000000, (i + 1) * 1000000 - 1]];
            [sizes addObject:@1000000];
        }
        [SCIYTParts useForegroundSessionForHarness];
        NSLog(@"[PARTSTEST] parts on disk at start: %lu", (unsigned long)[SCIYTParts partsOnDiskForRun:@"testrun"]);
        [SCIYTParts fetch:urls sizes:sizes runIdentifier:@"testrun" progress:^(double f) { NSLog(@"[PARTSTEST] progress %.2f", f); }
               completion:^(NSArray<NSURL *> *ordered, NSURL *folder, NSString *error) {
            if (!ordered) { NSLog(@"[PARTSTEST] FAILED: %@", error); return; }
            NSURL *joined = [SCIYTParts join:ordered extension:@"bin" folder:nil];
            NSData *data = [NSData dataWithContentsOfURL:joined];
            BOOL ok = data.length == 8000000;
            const uint8_t *b = data.bytes;
            for (NSUInteger i = 0; ok && i < data.length; i += 997) if (b[i] != (uint8_t)((i * 7) % 251)) ok = NO;
            NSLog(@"[PARTSTEST] DONE bytes=%lu identical=%d", (unsigned long)data.length, ok);
            [SCIYTParts abandonRun:@"testrun"];
        }];
        return;
    }
    if ([d boolForKey:@"sheettest"]) {
        NSMutableArray *variants = [NSMutableArray array];
        NSArray *sounds = @[@{@"id":@"en-US.4",@"lang":@"en-US",@"name":@"English (United States) original",@"url":@"u",@"bytes":@(4200000),@"default":@YES},
                            @{@"id":@"ar.3",@"lang":@"ar",@"name":@"Arabic",@"url":@"u",@"bytes":@(4100000),@"default":@NO},
                            @{@"id":@"de.3",@"lang":@"de",@"name":@"German",@"url":@"u",@"bytes":@(4000000),@"default":@NO}];
        NSMutableArray *caps = [NSMutableArray array];
        for (NSString *n in @[@"Arabic",@"Chinese (Simplified)",@"Czech",@"English",@"French",@"German",@"Hindi",@"Italian",@"Japanese",@"Korean"])
            [caps addObject:@{@"id":n,@"lang":n,@"name":n,@"url":@"u",@"auto":@NO}];
        [caps addObject:@{@"id":@"en-auto",@"lang":@"en",@"name":@"English (auto-generated)",@"url":@"u",@"auto":@YES}];
        for (NSNumber *h in @[@1080,@720,@480,@360]) {
            SCIHLSVariant *v = [SCIHLSVariant new]; v.height = h.integerValue; v.codecs = @"avc1,mp4a";
            v.directVideoBytes = h.integerValue * 90000; v.directAudioBytes = 4200000; v.directVideoURL = @"u"; v.directAudioURL = @"u";
            v.directAudioTracks = sounds; v.directCaptionTracks = caps; [variants addObject:v];
        }
        [SCIYTChoiceSheet presentFrom:self variants:variants title:@"Squid Game in Real Life! (long title that wraps onto a second line)" videoID:@"abc"
            chosen:^(SCIHLSVariant *v, SCIYTJobKind k) { NSLog(@"[SHEETTEST] chosen %ldp kind=%ld extras=%lu captions=%lu", (long)v.height, (long)k, (unsigned long)v.chosenExtraAudios.count, (unsigned long)v.chosenCaptions.count); }
            watch:^(SCIHLSVariant *v) {}];
        return;
    }

    NSMutableArray *jobs = [NSMutableArray array];
    NSArray *specs = @[@[@"Clip A (two audio, subtitles)", @"clipA.mp4", @(SCIYTJobKindVideo), @"720p"],
                       @[@"Clip B", @"clipB.mp4", @(SCIYTJobKindVideo), @"360p"],
                       @[@"Song C", @"songC.m4a", @(SCIYTJobKindAudio), @"128 kbps"],
                       @[@"Broken file", @"broken.mp4", @(SCIYTJobKindVideo), @"1080p"]];
    for (NSArray *s in specs) {
        NSURL *dst = [[SCIYTLibrary folder] URLByAppendingPathComponent:s[1]];
        if (![[NSFileManager defaultManager] fileExistsAtPath:dst.path]) {
            NSURL *src = [[NSBundle mainBundle] URLForResource:[s[1] stringByDeletingPathExtension] withExtension:[s[1] pathExtension]];
            if (src) [[NSFileManager defaultManager] copyItemAtURL:src toURL:dst error:nil];
        }
        SCIYTJob *j = [SCIYTJob jobWithTitle:s[0] quality:s[3] kind:[s[2] integerValue] videoID:nil];
        j.fileName = s[1]; j.state = SCIYTJobStateDone; j.duration = 90;
        [jobs addObject:j];
    }
    // SponsorBlock segments kept with the file (no network): a sponsor at 20-30 s, an intro at 5-8 s
    // whose category is left off, so a skip at 20 s and none at 5 s shows the filter works.
    [d registerDefaults:@{@"sponsorblock": @YES, @"sponsorblock_notice": @YES, @"sb_sponsor": @YES, @"sb_intro": @NO}];
    if ([d boolForKey:@"sbtest"]) {
        SCIYTJob *a = jobs.firstObject;
        a.sponsorSegments = @[@{@"category": @"intro", @"start": @5, @"end": @8}, @{@"category": @"sponsor", @"start": @20, @"end": @30}];
        a.sponsorCheckedAt = [[NSDate date] timeIntervalSince1970];
        for (NSNumber *t in @[@6, @19, @21, @24, @32]) SCIAfter(t.doubleValue, ^{ NSLog(@"[SBTEST] t+%@s playhead=%.1f s", t, [SCIYTPlayer progress] * 90.1); });
    }
    // Captions: -captest logs what the file carries; -caplang <tag> pretends that was chosen last time,
    // which is the "remembered per video" path; -capdelay <s> sets the timing offset.
    if ([d stringForKey:@"caplang"].length) ((SCIYTJob *)jobs.firstObject).captionChoice = [d stringForKey:@"caplang"];
    if ([d objectForKey:@"capdelay"]) ((SCIYTJob *)jobs.firstObject).captionDelay = [d doubleForKey:@"capdelay"];
    [SCIYTPlayer presentFrom:self jobs:jobs start:[d integerForKey:@"start"]];
    if ([d boolForKey:@"shuffletest"]) {
        SCIAfter(2, ^{ [[SCIYTPlayer current] performSelector:NSSelectorFromString(@"toggleShuffle")]; NSLog(@"[SHUF] on, playing %@", [SCIYTPlayer nowPlaying].title); });
        for (int i = 1; i <= 7; i++) SCIAfter(2 + i * 1.5, ^{
            [[SCIYTPlayer current] performSelector:NSSelectorFromString(@"next")];
            NSLog(@"[SHUF] next %d -> %@", i, [SCIYTPlayer nowPlaying].title);
        });
        for (int i = 1; i <= 2; i++) SCIAfter(14 + i * 1.5, ^{
            [[SCIYTPlayer current] performSelector:NSSelectorFromString(@"previous")];
            NSLog(@"[SHUF] previous %d -> %@", i, [SCIYTPlayer nowPlaying].title);
        });
    }
    if ([d boolForKey:@"capsheet"]) SCIAfter(3, ^{ [SCIYTCaptionSettings presentFrom:[SCIYTPlayer current]]; });
    if ([d boolForKey:@"queuesheet"]) SCIAfter(3, ^{ [d setBool:YES forKey:@"queuesheet_shown"]; [SCIYTQueueSheet presentFrom:[SCIYTPlayer current]]; });
    if ([d boolForKey:@"captest"]) SCIAfter(4, ^{
        NSLog(@"[CAPTEST] languages=%@ scale=%.2f delay=%.1f", [SCIYTPlayer captionLanguages], [SCIYTPlayer captionScale], [SCIYTPlayer captionDelay]);
        for (NSDictionary *l in [SCIYTPlayer captionLanguages]) {
            [SCIYTPlayer exportCaptionsFor:l[@"lang"] completion:^(NSURL *f, NSString *why) {
                NSLog(@"[CAPTEST] export %@ -> %@ %@", l[@"lang"], f.path, why ?: @"");
                if (f) NSLog(@"[CAPTEST] srt head:\n%@", [[[NSString stringWithContentsOfURL:f encoding:NSUTF8StringEncoding error:nil] componentsSeparatedByString:@"\n"] subarrayWithRange:NSMakeRange(0, 8)]);
            }];
        }
    });

    if ([d boolForKey:@"nptest"]) for (NSNumber *t in @[@3, @6, @9]) SCIAfter(t.doubleValue, ^{ SCIProbeNowPlaying([NSString stringWithFormat:@"t+%@s", t]); });

    if ([d boolForKey:@"hosttest"]) {
        YTSingleVideoController *host = [YTSingleVideoController new];
        YTRemoteCommandHandler *handler = [YTRemoteCommandHandler new];
        YTNowPlayingInfoCenterPlaybackObserverImpl *np = [YTNowPlayingInfoCenterPlaybackObserverImpl new];
        SCIAfter(4, ^{
            NSLog(@"[HOSTTEST] 1 owner=%d ours playing=%d (expect owner 1, playing 1)", (int)[SCIYTArbiter owner], [SCIYTPlayer isPlaying]);
            gMuted = YES; [host play];
            NSLog(@"[HOSTTEST] 2 muted preview started: ours playing=%d (expect 1)", [SCIYTPlayer isPlaying]);
            gMuted = NO;
            [SCIYTArbiter oursCommanded]; [host play];
            NSLog(@"[HOSTTEST] 3 echo inside window: ours playing=%d owner=%d (expect 1, 1; no 'host play ran' above)", [SCIYTPlayer isPlaying], (int)[SCIYTArbiter owner]);
            NSLog(@"[HOSTTEST] 4 lock-screen Play while ours owns: host handler returned %ld (expect 110, no 'handlePlay ran')", (long)[handler handlePlayCommand:nil]);
            [np clearNowPlayingInfo];
            NSLog(@"[HOSTTEST] 5 host clearNowPlayingInfo while ours owns (expect no 'clearNowPlayingInfo ran')");
        });
        SCIAfter(7, ^{
            [host play];
            NSLog(@"[HOSTTEST] 6 real YouTube start: owner=%d (expect 2; 'host play ran' above)", (int)[SCIYTArbiter owner]);
            NSLog(@"[HOSTTEST] 7 lock-screen Play while YouTube owns: host handler returned %ld (expect 0 and 'handlePlay ran')", (long)[handler handlePlayCommand:nil]);
        });
        SCIAfter(9, ^{
            [SCIYTPlayer toggle];
            NSLog(@"[HOSTTEST] 8 Play pressed in our player: ours playing=%d owner=%d (expect 1, 1)", [SCIYTPlayer isPlaying], (int)[SCIYTArbiter owner]);
            NSLog(@"[HOSTTEST] 9 lock-screen Play again: host handler returned %ld (expect 110)", (long)[handler handlePlayCommand:nil]);
            NSLog(@"[HOSTTEST] report:\n  %@", [SCIYTArbiter report]);
        });
    }

    if ([d boolForKey:@"resigntest"]) {
        SCIAfter(5, ^{
            NSLog(@"[harness] resign + become active (no background)");
            [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillResignActiveNotification object:nil];
            SCIAfter(1, ^{ [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil]; });
        });
    }
}
@end

@interface App : UIResponder <UIApplicationDelegate> @property (strong) UIWindow *window; @end
@implementation App
- (BOOL)application:(UIApplication *)a didFinishLaunchingWithOptions:(NSDictionary *)o {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [Root new]; self.window.backgroundColor = UIColor.darkGrayColor;
    [self.window makeKeyAndVisible]; return YES;
}
@end
int main(int c, char **v) { @autoreleasepool { SCIYTLaunchGuardStart(); return UIApplicationMain(c, v, nil, @"App"); } }
