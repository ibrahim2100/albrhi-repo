// What a cache clean keeps: the tweak's own files, and anything it cannot name.
#import <Foundation/Foundation.h>
#import "Features/General/SCICacheRules.h"

static int fails = 0;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); fails++; } else printf("ok   %s\n", #c); } while (0)

int main(void) {
    @autoreleasepool {
        // Our download history and a finished download are kept.
        CHECK(SCICacheNameIsOurs(@"albrhi-downloads.plist"));
        CHECK(SCICacheNameIsOurs(@"Albrhi-anything"));
        CHECK(SCICacheNameIsOurs(@"3F2504E0-4F89-11D3-9A0C-0305E82C3301.mp4"));
        CHECK(SCICacheNameIsOurs(@"3f2504e0-4f89-11d3-9a0c-0305e82c3301.jpg"));

        // Instagram's own caches are not ours.
        CHECK(!SCICacheNameIsOurs(@"com.burbn.instagram"));
        CHECK(!SCICacheNameIsOurs(@"fsCachedData"));
        CHECK(!SCICacheNameIsOurs(@"com.apple.WebKit.WebContent"));
        CHECK(!SCICacheNameIsOurs(@"SDImageCache"));

        // Close but not a download: a UUID with no extension, or a name that merely contains one.
        CHECK(!SCICacheNameIsOurs(@"3F2504E0-4F89-11D3-9A0C-0305E82C3301"));
        CHECK(!SCICacheNameIsOurs(@"x3F2504E0-4F89-11D3-9A0C-0305E82C3301.mp4"));
        CHECK(!SCICacheNameIsOurs(@"3F2504E0-4F89-11D3-9A0C-0305E82C3301.mp4.tmp.something"));

        // What cannot be read is kept: a cleaner that guesses wrong deletes somebody's file.
        CHECK(SCICacheNameIsOurs(@""));
        CHECK(SCICacheNameIsOurs((NSString *)[NSNull null]));

        CHECK(SCICacheRecentlyUsedSeconds >= 60);

        printf(fails ? "\n%d FAILED\n" : "\nall passed\n", fails);
        return fails ? 1 : 0;
    }
}
