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
PY

cat > "$OUT/Test.m" <<'EOM'
#import <Foundation/Foundation.h>

#include "region.inc"

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

        printf(fails ? "\n%d FAILED\n" : "\nall passed\n", fails);
        return fails ? 1 : 0;
    }
}
EOM

clang -fobjc-arc -Wall -Wno-unused-function -framework Foundation "$OUT/Test.m" -o "$OUT/test"
"$OUT/test"
