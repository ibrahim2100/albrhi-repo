#!/usr/bin/env bash
#
# TikTok's download ranking, the parts that are pure: what *kind* a link is (audio, video, unknown)
# and which origins are demoted. Every wrong-file report in this tweak's history was a different
# property that size cannot see, so these two decide before size does. Copied out of
# SCITTDownload.m by marker -- not retyped -- so what passes is what ships.
#
# NOT covered, on purpose and stated: the comparator that orders measured links (it sits inside a
# method that makes network requests, and moving it would be a change to shipping code for the sake
# of a test) and everything about which URLs TikTok hands over, which only a device can say.
#
#   bash tweaks/tiktok/tests/host/run.sh
#
set -euo pipefail
cd "$(dirname "$0")"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

python3 - "$OUT" <<'PY'
import sys
src = open('../../src/Features/Download/SCITTDownload.m').read()
def region(name):
    a = src.index('// host-test:begin ' + name)
    b = src.index('// host-test:end ' + name)
    assert a < b
    return src[a:b]
open(sys.argv[1] + '/region.inc', 'w').write(region('kindrank') + '\n' + region('demoted'))

# The animated-WebP-to-GIF converter (in the same file) and the copy-without-the-name cut (in the comments file).
def region_of(path, name):
    text = open(path).read()
    a = text.index('// host-test:begin ' + name)
    b = text.index('// host-test:end ' + name)
    assert a < b
    return text[a:b]
open(sys.argv[1] + '/gif.inc', 'w').write(region_of('../../src/Features/Download/SCITTDownload.m', 'animatedgif'))
open(sys.argv[1] + '/copyname.inc', 'w').write(region_of('../../src/Features/Comments/SCITTComments.x', 'copyname'))
PY

cat > "$OUT/Test.m" <<'EOM'
#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
#import "shared/src/SCIKVC.h"

#include "region.inc"
#include "gif.inc"
#include "copyname.inc"

// Stand-ins for the app's own models: a comment with an author, exactly as far as the cut reads them.
@interface FakeAuthor : NSObject
@property (nonatomic, copy) NSString *nickname;
@end
@implementation FakeAuthor
@end
@interface FakeComment : NSObject
@property (nonatomic, strong) FakeAuthor *author;
@property (nonatomic, copy) NSString *content;
@end
@implementation FakeComment
@end
static FakeComment *MakeComment(NSString *nick, NSString *text) {
    FakeComment *c = [FakeComment new];
    c.author = [FakeAuthor new];
    c.author.nickname = nick;
    c.content = text;
    return c;
}

static int fails = 0;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); fails++; } else printf("ok   %s\n", #c); } while (0)

static NSURL *U(NSString *s) { return [NSURL URLWithString:s]; }

int main(void) {
    @autoreleasepool {
        // Audio is never the file somebody wanted, whichever way it announces itself.
        CHECK(SCITTKindRank(@"audio/mpeg", U(@"https://x.invalid/a")) == 0);
        CHECK(SCITTKindRank(nil, U(@"https://x.invalid/song.mp3")) == 0);
        CHECK(SCITTKindRank(nil, U(@"https://x.invalid/song.M4A")) == 0);

        // Video, by content type or by extension.
        CHECK(SCITTKindRank(@"video/mp4", U(@"https://x.invalid/v")) == 2);
        CHECK(SCITTKindRank(nil, U(@"https://x.invalid/clip.mp4")) == 2);
        CHECK(SCITTKindRank(nil, U(@"https://x.invalid/clip.MOV")) == 2);

        // A link that says nothing (a server refusing HEAD) is *unknown*, not worst: it outranks
        // audio and loses to a known video.
        CHECK(SCITTKindRank(nil, U(@"https://x.invalid/abc")) == 1);
        CHECK(SCITTKindRank(@"application/octet-stream", U(@"https://x.invalid/abc")) == 1);

        // A content type outranks a misleading extension: audio served from an .mp4 path is audio.
        CHECK(SCITTKindRank(@"audio/mpeg", U(@"https://x.invalid/fake.mp4")) == 0);

        // The two origins that rank below a clean video: the watermarked save copy and the H.264
        // compatibility re-encode. Everything else, and nil, is not demoted.
        CHECK(SCITTOriginIsDemoted(@"downloadURL"));
        CHECK(SCITTOriginIsDemoted(@"h264DownloadURL"));
        CHECK(!SCITTOriginIsDemoted(@"downloadNoWatermarkURL"));
        CHECK(!SCITTOriginIsDemoted(@"tikwm HD"));
        CHECK(!SCITTOriginIsDemoted(nil));

        // --- A comment copied without the name in front of it -------------------------------------------------
        // The text TikTok hands to its copy operation is "@<nickname>: <comment>" (measured on 47.1.0), and a nickname is not a word.
        BOOL tail = NO;
        CHECK([SCITTCopyWithoutName(@"@Sophie_rose \U0001F940: imagine it's a mom spider \U0001F62D",
                                   MakeComment(@"Sophie_rose \U0001F940", @"imagine it's a mom spider \U0001F62D"), &tail)
               isEqualToString:@"imagine it's a mom spider \U0001F62D"] && !tail);
        // An Arabic nickname with two flags and a space, which the first attempt's pattern could not match.
        NSString *arabic = @"\u0627\u0628\u0648\u0644\u064A\u0646 \u0648\u0644\u064A\u0627\u0646\U0001F1FE\U0001F1EA\U0001F1E6\U0001F1EA \u0627\u0644\u0639\u0627\u0645\u0631\u064A";
        CHECK([SCITTCopyWithoutName([NSString stringWithFormat:@"@%@: \u0632\u0639\u064A\u0645", arabic], MakeComment(arabic, @"\u0632\u0639\u064A\u0645"), NULL)
               isEqualToString:@"\u0632\u0639\u064A\u0645"]);
        // A full-width colon, and no space after it.
        CHECK([SCITTCopyWithoutName(@"@A\uFF1Ahello", MakeComment(@"A", @"hello"), NULL) isEqualToString:@"hello"]);
        // A comment that is itself a mention keeps it.
        CHECK([SCITTCopyWithoutName(@"@a: @b hi", MakeComment(@"a", @"@b hi"), NULL) isEqualToString:@"@b hi"]);
        // A multi-line comment is cut only at the front.
        CHECK([SCITTCopyWithoutName(@"@a: one\ntwo: three", MakeComment(@"a", @"one\ntwo: three"), NULL) isEqualToString:@"one\ntwo: three"]);
        // The nickname is not the one on the model (renamed since): the comment's own text, found at the end after a colon, is used.
        tail = NO;
        CHECK([SCITTCopyWithoutName(@"@Old name: the words", MakeComment(@"New name", @"the words"), &tail) isEqualToString:@"the words"] && tail);
        // Left alone, never guessed at: no name on the model and no text to find, nothing after the colon, no colon, no comment, not a string.
        CHECK(SCITTCopyWithoutName(@"@x: hello", MakeComment(nil, nil), NULL) == nil);
        CHECK(SCITTCopyWithoutName(@"@a: ", MakeComment(@"a", @""), NULL) == nil);
        CHECK(SCITTCopyWithoutName(@"@a hello", MakeComment(@"a", @"hello"), NULL) == nil);
        CHECK(SCITTCopyWithoutName(@"@a: hello", nil, NULL) == nil);
        CHECK(SCITTCopyWithoutName((NSString *)@42, MakeComment(@"a", @"b"), NULL) == nil);
        // A suffix that is not set apart by a colon is not "the name in front".
        CHECK(SCITTCopyWithoutName(@"look at hello", MakeComment(@"zzz", @"hello"), NULL) == nil);

        // --- An animated WebP, kept moving as a GIF ------------------------------------------------------------
        NSData *animated = [NSData dataWithContentsOfFile:@"fixtures/animated-3-frames.webp"];
        NSData *still = [NSData dataWithContentsOfFile:@"fixtures/still.webp"];
        CHECK(animated.length > 0 && still.length > 0);
        NSData *gif = SCITTAnimatedGIFFromWebP(animated);
        CHECK(gif.length > 0 && !memcmp(gif.bytes, "GIF8", 4));
        CGImageSourceRef out = CGImageSourceCreateWithData((__bridge CFDataRef)gif, NULL);
        CHECK(out && CGImageSourceGetCount(out) == 3);
        if (out) {
            NSDictionary *props = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(out, 1, NULL));
            double delay = [props[(__bridge NSString *)kCGImagePropertyGIFDictionary][(__bridge NSString *)kCGImagePropertyGIFDelayTime] doubleValue];
            CHECK(delay > 0.09 && delay < 0.11);   // the 100 ms the WebP asked for
            CFRelease(out);
        }
        // One picture is not an animation, and what is not a picture is nothing.
        CHECK(SCITTAnimatedGIFFromWebP(still) == nil);
        CHECK(SCITTAnimatedGIFFromWebP([@"not an image" dataUsingEncoding:NSUTF8StringEncoding]) == nil);
        CHECK(SCITTAnimatedGIFFromWebP([NSData data]) == nil);

        printf(fails ? "\n%d FAILED\n" : "\nall passed\n", fails);
        return fails ? 1 : 0;
    }
}
EOM

ROOT="$(cd ../../../.. && pwd)"
clang -fobjc-arc -Wall -Wno-unused-function -I"$ROOT" -framework Foundation -framework ImageIO -framework CoreGraphics "$OUT/Test.m" "$ROOT/shared/src/SCIKVC.m" -o "$OUT/test"
"$OUT/test"

# --- The recalled-message store (SCITTRecalledStore.m is plain Foundation, compiled as it ships) -------------------
cat > "$OUT/Store.m" <<'EOM'
#import <Foundation/Foundation.h>
#import "tweaks/tiktok/src/Features/Messages/SCITTRecalledStore.h"

static int fails = 0;
#define CHECK(x) do { if (!(x)) { printf("FAIL line %d: %s\n", __LINE__, #x); fails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSString *dir = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"albrhi-store-%u", arc4random()]];
        NSString *path = [dir stringByAppendingPathComponent:@"sub/recalled.plist"];

        SCITTRecalledStore *store = [[SCITTRecalledStore alloc] initWithPath:path limit:3];
        CHECK(store.count == 0);
        CHECK(![store isTracked:@(111)]);
        CHECK(![store isTracked:nil]);

        // An id seen alone is tracked (the message is marked) with no content; an NSNumber and its decimal string are the same id.
        CHECK([store track:@(111) content:nil] == YES);
        CHECK([store isTracked:@(111)] && [store isTracked:@"111"] && [store isTracked:@111LL]);
        CHECK([store contentFor:@(111)] == nil);
        CHECK([store track:@(111) content:nil] == NO);        // the recall getter asks again and again: nothing new

        // Content arriving later for a known id is kept; later empty or different content never replaces it.
        NSDictionary *said = @{ @"text": @"hello", @"n": @3 };
        CHECK([store track:@(111) content:said] == NO);
        CHECK([[store contentFor:@(111)] isEqual:said]);
        [store track:@(111) content:@{}];
        [store track:@(111) content:@{ @"text": @"overwritten" }];
        CHECK([[store contentFor:@(111)] isEqual:said]);

        // Content that cannot be a property list is not kept, but the id still is.
        CHECK([store track:@(222) content:@{ @"bad": [NSObject new] }] == YES);
        CHECK([store isTracked:@(222)] && [store contentFor:@(222)] == nil);

        // Content over 16 KB is not kept either.
        NSMutableString *big = [NSMutableString string];
        while (big.length < 20000) [big appendString:@"x"];
        [store track:@(333) content:@{ @"text": big }];
        CHECK([store isTracked:@(333)] && [store contentFor:@(333)] == nil);

        // The newest `limit` survive: a fourth id pushes the oldest (111) out.
        CHECK([store track:@(444) content:@{ @"text": @"four" }] == YES);
        CHECK(store.count == 3);
        CHECK(![store isTracked:@(111)] && [store isTracked:@(444)]);

        // It is written, atomically, and a new store reads the file back.
        [store flush];
        CHECK([[NSFileManager defaultManager] fileExistsAtPath:path]);
        SCITTRecalledStore *again = [[SCITTRecalledStore alloc] initWithPath:path limit:3];
        CHECK(again.count == 3);
        CHECK([again isTracked:@(444)] && [[again contentFor:@(444)] isEqual:@{ @"text": @"four" }]);
        CHECK([again isTracked:@(222)] && ![again isTracked:@(111)]);

        // A smaller limit trims on load; forgetting removes.
        SCITTRecalledStore *small = [[SCITTRecalledStore alloc] initWithPath:path limit:1];
        CHECK(small.count == 1 && [small isTracked:@(444)]);
        [small forget:@(444)];
        CHECK(small.count == 0 && ![small isTracked:@(444)]);

        // A damaged file is an empty store, not a crash.
        [@"not a plist" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        SCITTRecalledStore *damaged = [[SCITTRecalledStore alloc] initWithPath:path limit:3];
        CHECK(damaged.count == 0);

        [[NSFileManager defaultManager] removeItemAtPath:dir error:NULL];
        printf(fails ? "\n%d FAILED (store)\n" : "recalled store: all passed\n", fails);
        return fails ? 1 : 0;
    }
}
EOM
clang -fobjc-arc -Wall -I"$ROOT" -framework Foundation "$OUT/Store.m" "$ROOT/tweaks/tiktok/src/Features/Messages/SCITTRecalledStore.m" -o "$OUT/store-test"
"$OUT/store-test"
