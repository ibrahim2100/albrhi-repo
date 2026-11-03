#import "SCIYTSubtitles.h"

static const int32_t kScale = 1000;   // milliseconds: what VTT is written in

/// "00:01:02.345" or "01:02.345" in seconds, or a negative number when it is not a time.
static double SCIVTTTime(NSString *text) {
    NSArray<NSString *> *parts = [text componentsSeparatedByString:@":"];
    if (parts.count < 2 || parts.count > 3) return -1;
    double total = 0;
    for (NSString *part in parts) {
        NSString *clean = [part stringByReplacingOccurrencesOfString:@"," withString:@"."];
        NSScanner *scanner = [NSScanner scannerWithString:clean];
        double value = 0;
        if (![scanner scanDouble:&value] || !scanner.isAtEnd || value < 0) return -1;
        total = total * 60 + value;
    }
    return total;
}

static NSString *SCIDecodeEntities(NSString *text) {
    NSString *out = text;
    NSDictionary *named = @{@"&amp;": @"&", @"&lt;": @"<", @"&gt;": @">", @"&quot;": @"\"",
                            @"&#39;": @"'", @"&apos;": @"'", @"&nbsp;": @" ",
                            @"&lrm;": @"‎", @"&rlm;": @"‏"};
    for (NSString *key in named) out = [out stringByReplacingOccurrencesOfString:key withString:named[key]];
    return out;
}

static NSString *SCIStripTags(NSString *line) {
    NSRegularExpression *tags = [NSRegularExpression regularExpressionWithPattern:@"<[^>]*>" options:0 error:nil];
    return [tags stringByReplacingMatchesInString:line options:0 range:NSMakeRange(0, line.length) withTemplate:@""];
}

static BOOL SCIHasWordTiming(NSString *line) {
    static NSRegularExpression *timing;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ timing = [NSRegularExpression regularExpressionWithPattern:@"<\\d{1,2}:\\d{2}[:.]" options:0 error:nil]; });
    return [timing firstMatchInString:line options:0 range:NSMakeRange(0, line.length)] != nil;
}

@implementation SCIYTSubtitles

+ (NSArray<NSDictionary *> *)cuesFromVTT:(NSString *)vtt {
    if (![vtt isKindOfClass:[NSString class]] || !vtt.length) return @[];

    NSString *normal = [[vtt stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"]
                        stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
    NSArray<NSString *> *lines = [normal componentsSeparatedByString:@"\n"];

    // First pass: raw blocks, each with its own lines kept so rolling captions can be told apart.
    NSMutableArray<NSDictionary *> *raw = [NSMutableArray array];
    BOOL rolling = NO;
    NSUInteger i = 0;
    while (i < lines.count) {
        NSString *line = lines[i];
        NSRange arrow = [line rangeOfString:@"-->"];
        if (arrow.location == NSNotFound) { i++; continue; }

        NSString *left = [[line substringToIndex:arrow.location] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        NSString *rest = [[line substringFromIndex:NSMaxRange(arrow)] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        NSString *right = [rest componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet].firstObject ?: @"";
        double start = SCIVTTTime(left), end = SCIVTTTime(right);
        i++;

        NSMutableArray<NSString *> *payload = [NSMutableArray array];
        // The block ends at an *empty* line. YouTube's rolling captions open each block with a line holding a
        // single space, which is content as far as the format goes -- trimming it ended the block there
        // and lost the line with the new words.
        while (i < lines.count && lines[i].length > 0) {
            [payload addObject:lines[i]];
            i++;
        }
        if (start < 0 || end < 0 || end <= start) continue;
        for (NSString *p in payload) if (SCIHasWordTiming(p)) rolling = YES;
        [raw addObject:@{@"start": @(start), @"end": @(end), @"lines": payload}];
    }

    NSMutableArray<NSDictionary *> *cues = [NSMutableArray array];
    for (NSDictionary *block in raw) {
        NSMutableArray<NSString *> *kept = [NSMutableArray array];
        for (NSString *p in block[@"lines"]) {
            if (rolling && !SCIHasWordTiming(p)) continue;
            NSString *clean = [SCIDecodeEntities(SCIStripTags(p)) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (clean.length) [kept addObject:clean];
        }
        if (!kept.count) continue;
        NSString *text = [kept componentsJoinedByString:@"\n"];

        NSDictionary *last = cues.lastObject;
        // The same words twice in a row are one cue that goes on: extend it rather than repeat it.
        if (last && [last[@"text"] isEqualToString:text] && [last[@"end"] doubleValue] >= [block[@"start"] doubleValue] - 0.05) {
            NSMutableDictionary *merged = [last mutableCopy];
            merged[@"end"] = @(MAX([last[@"end"] doubleValue], [block[@"end"] doubleValue]));
            cues[cues.count - 1] = merged;
            continue;
        }
        [cues addObject:@{@"start": block[@"start"], @"end": block[@"end"], @"text": text}];
    }

    [cues sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"start"] compare:b[@"start"]];
    }];

    // No overlaps: a text track plays one sample at a time.
    NSMutableArray<NSDictionary *> *flat = [NSMutableArray arrayWithCapacity:cues.count];
    for (NSUInteger k = 0; k < cues.count; k++) {
        NSMutableDictionary *cue = [cues[k] mutableCopy];
        if (k + 1 < cues.count) {
            double next = [cues[k + 1][@"start"] doubleValue];
            if ([cue[@"end"] doubleValue] > next) cue[@"end"] = @(next);
        }
        if ([cue[@"end"] doubleValue] - [cue[@"start"] doubleValue] >= 0.001) [flat addObject:cue];
    }
    return flat;
}

+ (NSArray<NSDictionary *> *)scheduleForCues:(NSArray<NSDictionary *> *)cues {
    NSMutableArray<NSDictionary *> *schedule = [NSMutableArray array];
    double at = 0;
    for (NSDictionary *cue in cues) {
        double start = [cue[@"start"] doubleValue], end = [cue[@"end"] doubleValue];
        if (start > at + 0.001) [schedule addObject:@{@"start": @(at), @"duration": @(start - at)}];
        [schedule addObject:@{@"start": @(start), @"duration": @(end - start), @"text": cue[@"text"]}];
        at = end;
    }
    return schedule;
}

+ (NSData *)payloadForText:(NSString *)text {
    NSData *utf8 = [text dataUsingEncoding:NSUTF8StringEncoding] ?: [NSData data];
    // A 16-bit length: a cue can never be longer than that, and one that is would be cut.
    if (utf8.length > 0xFFFF) utf8 = [utf8 subdataWithRange:NSMakeRange(0, 0xFFFF)];
    NSMutableData *out = [NSMutableData dataWithCapacity:utf8.length + 2];
    uint16_t length = CFSwapInt16HostToBig((uint16_t)utf8.length);
    [out appendBytes:&length length:2];
    [out appendData:utf8];
    return out;
}

+ (NSData *)descriptionData {
    NSMutableData *d = [NSMutableData data];
    void (^put8)(uint8_t) = ^(uint8_t v) { [d appendBytes:&v length:1]; };
    void (^put16)(uint16_t) = ^(uint16_t v) { uint16_t b = CFSwapInt16HostToBig(v); [d appendBytes:&b length:2]; };
    void (^put32)(uint32_t) = ^(uint32_t v) { uint32_t b = CFSwapInt32HostToBig(v); [d appendBytes:&b length:4]; };

    put32(0); put32('tx3g'); for (int i = 0; i < 6; i++) put8(0); put16(1);   // size patched below; data reference 1
    put32(0); put8(1); put8(0xFF); put8(0); put8(0); put8(0); put8(0);          // display flags, justification, background
    put16(0); put16(0); put16(0); put16(0);                                     // default text box
    put16(0); put16(0); put16(1); put8(0); put8(24); put8(255); put8(255); put8(255); put8(255);  // style: font 1, 24 pt, white
    put32(18); put32('ftab'); put16(1); put16(1); put8(5); [d appendBytes:"Arial" length:5];
    uint32_t total = CFSwapInt32HostToBig((uint32_t)d.length);
    [d replaceBytesInRange:NSMakeRange(0, 4) withBytes:&total];
    return d;
}

+ (CMFormatDescriptionRef)newFormatDescription {
    NSData *data = [self descriptionData];
    CMFormatDescriptionRef format = NULL;
    OSStatus status = CMTextFormatDescriptionCreateFromBigEndianTextDescriptionData(
        NULL, data.bytes, data.length, NULL, kCMMediaType_Subtitle, &format);
    return status == noErr ? format : NULL;
}

+ (CMSampleBufferRef)newSampleForEntry:(NSDictionary *)entry format:(CMFormatDescriptionRef)format {
    NSData *payload = [self payloadForText:entry[@"text"]];

    CMBlockBufferRef block = NULL;
    if (CMBlockBufferCreateWithMemoryBlock(NULL, NULL, payload.length, NULL, NULL, 0, payload.length,
                                           kCMBlockBufferAssureMemoryNowFlag, &block) != noErr) return NULL;
    if (CMBlockBufferReplaceDataBytes(payload.bytes, block, 0, payload.length) != noErr) { CFRelease(block); return NULL; }

    int64_t start = llround([entry[@"start"] doubleValue] * kScale);
    int64_t length = MAX(1, llround([entry[@"duration"] doubleValue] * kScale));
    CMSampleTimingInfo timing = { CMTimeMake(length, kScale), CMTimeMake(start, kScale), kCMTimeInvalid };
    size_t size = payload.length;

    CMSampleBufferRef sample = NULL;
    OSStatus status = CMSampleBufferCreate(NULL, block, true, NULL, NULL, format, 1, 1, &timing, 1, &size, &sample);
    CFRelease(block);
    return status == noErr ? sample : NULL;
}

@end
