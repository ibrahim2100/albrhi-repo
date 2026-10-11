//
//  SCIYTDiagnostics+Streams.m
//  Albrhi for YouTube
//
//  What a streaming-data object holds, printed for the report.
//
//  Split out of SCIYTDiagnostics.m, which had grown to 1,783 lines holding every feature's
//  record as well as the report itself. This part keeps no variables at all,
//  so it moves whole, as a category, with nothing about the report changed.
//
#import "SCIYTDiagnostics.h"
#import "SCIYTDiagnosticsInternal.h"
#import "../SCIYTLaunchGuard.h"
#import "shared/src/SCIKVC.h"
#import "../YouTubeHeaders.h"
#import "../Tweak.h"
#import "../SCILog.h"
#import "../Prefs.h"
#import "../Localization/SCILocalize.h"
#import "../Features/Download/SCIYTDownload.h"
#import "../Features/Download/Center/SCIYTWatch.h"
#import "../Features/Playback/SCIYTPoProbe.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import "../Features/Tabs/SCIYTTabBar.h"
#import "../Features/Tabs/SCIYTHistoryTab.h"

@implementation SCIYTDiagnostics (Streams)

/// One value from an object, boxed, or nil. KVC rather than -performSelector: it
/// returns numbers as NSNumber without the caller having to know the return type,
/// which is the whole difficulty with an unfamiliar class.
+ (id)value:(NSString *)key from:(id)object {
    if (!object || !key.length) return nil;
    @try {
        if (![object respondsToSelector:NSSelectorFromString(key)]) return nil;
        return SCISafeValueForKey(object, key);
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

/// What MLStreamingData actually holds.
///
/// Its -description prints the class and an address and nothing else: it is not a
/// protobuf, so the trick that makes the player response readable does not work here,
/// and this section of the report has been saying "<MLStreamingData: 0x...>" since
/// 0.1.0 — the one measurement the download feature was waiting on.
///
/// The question is narrow and worth stating: does this build hand out plain file URLs
/// per format, or only the piecewise UMP/ABR stream? A URL in the list below means the
/// first; an empty list, or formats with no URL, means the second — and the difference
/// is a week of work against a month of it.
+ (NSString *)describeStreams:(id)streamingData {
    if (!streamingData) return nil;

    NSMutableString *out = [NSMutableString string];
    [out appendFormat:@"  class: %@\n", NSStringFromClass([streamingData class])];

    // The names both this app and other tweaks use for the format lists. Asked in
    // order; every one that answers is reported, because which of them is populated
    // is exactly what is unknown.
    NSArray<NSString *> *containers = @[
        @"adaptiveStreams", @"adaptiveFormats", @"adaptiveFormatsArray",
        @"formats", @"formatsArray", @"allFormats", @"streams", @"videoStreams",
        @"audioStreams", @"progressiveStreams", @"hlsManifestURL", @"dashManifestURL",
    ];

    BOOL foundAny = NO;

    for (NSString *name in containers) {
        id value = [self value:name from:streamingData];
        if (!value) continue;

        foundAny = YES;

        if (![value isKindOfClass:[NSArray class]]) {
            [out appendFormat:@"  %@: %@\n", name, value];
            continue;
        }

        NSArray *list = value;
        [out appendFormat:@"  %@: %lu\n", name, (unsigned long)list.count];

        // Twelve is more than enough to see the shape of the ladder, and keeps the
        // page inside what a person will actually read.
        NSUInteger shown = MIN(list.count, (NSUInteger)24);
        for (NSUInteger i = 0; i < shown; i++) {
            id stream = list[i];

            // The scalars (itag, size, frame rate, bitrate) come back nil through the object-only
            // reader -- which is why every line of the first reports said `[?] … ?x? ?fps ?bps`
            // and a list of twenty formats could not say which of them were VP9 or AV1. They are
            // read as numbers, from the nested `YTIFormatStream` where the stream itself has none.
            id formatStream = [self value:@"formatStream" from:stream];
            id itag = SCISafeNumberForKey(stream, @"itag") ?: SCISafeNumberForKey(formatStream, @"itag");
            NSString *mime = [self string:[self value:@"MIMEType" from:stream]
                                            ?: [self value:@"mimeType" from:stream]];
            NSString *quality = [self string:[self value:@"qualityLabel" from:stream]
                                               ?: [self value:@"quality" from:stream]];
            if (!mime.length) mime = [self string:[self value:@"mimeType" from:formatStream]];
            id width = SCISafeNumberForKey(stream, @"width") ?: SCISafeNumberForKey(formatStream, @"width");
            id height = SCISafeNumberForKey(stream, @"height") ?: SCISafeNumberForKey(formatStream, @"height");
            id fps = SCISafeNumberForKey(stream, @"FPS") ?: SCISafeNumberForKey(formatStream, @"fps");
            id bitrate = SCISafeNumberForKey(stream, @"bitrate") ?: SCISafeNumberForKey(formatStream, @"bitrate");
            if (!quality.length) quality = [self string:[self value:@"qualityLabel" from:formatStream]];

            // `video/mp4; codecs="avc1.640020"` is the part that matters, kept short.
            NSString *codec = mime;
            NSRange codecs = [mime rangeOfString:@"codecs=\""];
            if (codecs.location != NSNotFound) {
                codec = [[mime substringFromIndex:NSMaxRange(codecs)] stringByReplacingOccurrencesOfString:@"\"" withString:@""];
            }
            if (codec.length) mime = codec;

            // The decisive question, and the reason the whole page exists: is there a
            // fetchable link per format, or does playback go through the piecewise
            // protocol only? The first probe answered "?cpn=..." — a query fragment,
            // not a URL — so every name the stream might keep a real one under is asked
            // for, and the one that answered is named alongside it.
            // Every name that answers, not the first.
            //
            // This probe used to stop at the first non-empty one, and that single `break`
            // steered four releases down the wrong road. `URL` answers with "?cpn=…" — a
            // fragment — so the loop reported that and never tried `url`, `baseURL` or any
            // of the rest even once. "No links anywhere" was a conclusion drawn from a
            // list of one.
            //
            // The reference tweak whose download works reads `URL` and falls through to
            // the nested formatStream when it is not usable, which is exactly the step
            // this report was unable to show.
            NSMutableArray<NSString *> *links = [NSMutableArray array];

            for (NSString *key in @[@"URL", @"url", @"baseURL", @"streamURL", @"videoURL",
                                    @"assetURL", @"mediaURL", @"urlString", @"URLString",
                                    @"absoluteURL", @"downloadURL"]) {
                id candidate = [self value:key from:stream];
                if (!candidate) continue;

                NSString *text = [candidate isKindOfClass:[NSURL class]]
                    ? [(NSURL *)candidate absoluteString] : [self string:candidate];
                if (!text.length) continue;

                // A signed CDN link runs to a thousand characters of query string; the
                // opening is enough to tell a real one from a fragment.
                NSString *shown = text.length > 90
                    ? [[text substringToIndex:90] stringByAppendingString:@"…"] : text;
                [links addObject:[NSString stringWithFormat:@"%@ = %@", key, shown]];
            }

            NSString *link = links.count
                ? [links componentsJoinedByString:@"\n      "]
                : @"none";

            [out appendFormat:@"    [%@] %@ %@ %@x%@ %@fps %@bps\n      %@\n",
                itag ?: @"?", mime ?: @"?", quality ?: @"?",
                width ?: @"?", height ?: @"?", fps ?: @"?", bitrate ?: @"?", link];
        }

        if (list.count > shown) {
            [out appendFormat:@"    … and %lu more\n", (unsigned long)(list.count - shown)];
        }

        // What else a stream can be asked, taken from the runtime rather than guessed.
        // Printed once: if the fields above came back empty, this is the list that says
        // what to ask for instead.
        if (list.count) {
            [out appendFormat:@"  stream class: %@\n", NSStringFromClass([list.firstObject class])];
            [out appendFormat:@"  stream offers: %@\n", [self zeroArgumentSelectorsOn:list.firstObject]];

            // And what is nested inside it, which is the one place left to look.
            //
            // Every stream in a real report answered -URL with "?cpn=..." — a query
            // fragment and not a link — and four of the twelve were H.264, which iOS
            // plays. So the codec was never the obstacle; the missing link was. The
            // outer stream does not hold one, and this says whether the inner one does.
            //
            // If it does not either, the answer is settled: this build hands out no file
            // URLs at all and downloading has to go through YouTube's own downloader or
            // the piecewise protocol. That is a different project, and worth knowing
            // before starting it rather than after.
            id nested = [self value:@"formatStream" from:list.firstObject];
            if (nested) {
                [out appendFormat:@"  formatStream class: %@\n", NSStringFromClass([nested class])];
                [out appendFormat:@"  formatStream offers: %@\n",
                    [self zeroArgumentSelectorsOn:nested]];

                for (NSString *key in @[@"URL", @"url", @"baseURL", @"urlString"]) {
                    id candidate = [self value:key from:nested];
                    if (!candidate) continue;

                    NSString *text = [candidate isKindOfClass:[NSURL class]]
                        ? [(NSURL *)candidate absoluteString] : [self string:candidate];
                    if (!text.length) continue;

                    NSString *head = text.length > 120
                        ? [[text substringToIndex:120] stringByAppendingString:@"…"] : text;
                    [out appendFormat:@"  formatStream %@ = %@\n", key, head];
                }

                // A GPBMessage prints its whole tree, which for a format stream is every
                // field it carries — the fastest way to see a link that is under a name
                // nobody thought to ask for.
                NSString *tree = [self describeMessage:nested];
                if (tree.length && tree.length < 4000) {
                    [out appendFormat:@"  formatStream contents:\n%@\n", tree];
                }
            } else {
                [out appendString:@"  formatStream: nothing nested\n"];
            }
        }
    }

    if (!foundAny) {
        [out appendFormat:@"  no format list answered. offers: %@\n",
            [self zeroArgumentSelectorsOn:streamingData]];
    }

    return out;
}

/// The zero-argument selectors a class declares, as one line.
///
/// Asking the runtime instead of guessing is how the Instagram side found the DASH
/// manifest after three wrong guesses. Bounded, and only the class's own methods:
/// walking every superclass would print most of NSObject.
+ (NSString *)zeroArgumentSelectorsOn:(id)object {
    if (!object) return @"—";

    NSMutableArray<NSString *> *names = [NSMutableArray array];

    // Up the chain, not just the class itself. MLRemoteStream declares almost nothing
    // of its own -- the accessors are on its superclass -- so asking only the class
    // printed an empty list, which read as "this object offers nothing" when it in
    // fact offers everything the download feature needs to know about.
    //
    // Stopping before NSObject keeps -hash, -description and the rest out of it.
    Class cls = [object class];
    NSInteger levels = 0;

    while (cls && cls != [NSObject class] && levels++ < 6 && names.count < 90) {
        unsigned int count = 0;
        Method *methods = class_copyMethodList(cls, &count);

        for (unsigned int i = 0; i < count && names.count < 90; i++) {
            NSString *name = NSStringFromSelector(method_getName(methods[i]));
            if ([name containsString:@":"]) continue;      // takes arguments
            if ([name hasPrefix:@"."]) continue;           // .cxx_destruct
            if ([name hasPrefix:@"set"]) continue;         // setters answer nothing useful
            if ([names containsObject:name]) continue;     // overridden further down
            [names addObject:name];
        }

        free(methods);
        cls = class_getSuperclass(cls);
    }

    [names sortUsingSelector:@selector(compare:)];
    return names.count ? [names componentsJoinedByString:@", "] : @"—";
}

/// A value as text, whatever kind of object it turns out to be.
///
/// MIMEType came back as <HAMMIMEType: 0x…> — a wrapper, not a string — so the report
/// printed an address where a type should be. Anything that is not already a string is
/// asked for one before being given up on.
+ (NSString *)string:(id)value {
    if (!value) return nil;
    if ([value isKindOfClass:[NSString class]]) return value;
    if ([value isKindOfClass:[NSNumber class]]) return [value stringValue];

    for (NSString *key in @[@"stringValue", @"string", @"type", @"name", @"value"]) {
        id inner = [self value:key from:value];
        if ([inner isKindOfClass:[NSString class]] && [inner length]) return inner;
    }

    return [value description];
}

@end
