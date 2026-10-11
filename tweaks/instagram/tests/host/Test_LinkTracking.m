// The link cleaner: which addresses lose which parameters, and everything it must leave alone.
#import <Foundation/Foundation.h>
#import "Features/General/SCILinkTracking.h"

static int fails = 0;
#define CHECK_EQ(actual, expected) do { NSString *a_ = (actual), *e_ = (expected); \
    if (![a_ isEqualToString:e_]) { printf("FAIL line %d\n   got:      %s\n   expected: %s\n", __LINE__, a_.UTF8String, e_.UTF8String); fails++; } \
    else printf("ok   %s\n", #actual); } while (0)

int main(void) {
    @autoreleasepool {
        // The sharer's id goes; the post stays.
        CHECK_EQ(SCIStripTrackingFromURLString(@"https://www.instagram.com/p/DAbC123/?igsh=MzRlODBiNWFlZA=="),
                 @"https://www.instagram.com/p/DAbC123/");
        CHECK_EQ(SCIStripTrackingFromURLString(@"https://www.instagram.com/reel/XyZ/?igshid=abc123"),
                 @"https://www.instagram.com/reel/XyZ/");

        // A real parameter next to a tracker is kept, byte for byte (here with an encoded value).
        CHECK_EQ(SCIStripTrackingFromURLString(@"https://www.instagram.com/p/A/?img_index=2&igsh=zzz&hl=ar%2DSA"),
                 @"https://www.instagram.com/p/A/?img_index=2&hl=ar%2DSA");
        CHECK_EQ(SCIStripTrackingFromURLString(@"https://instagram.com/p/A/?igsh=x&utm_source=ig_web_copy_link&utm_medium=copy_link"),
                 @"https://instagram.com/p/A/");

        // The fragment survives; the name is matched case-insensitively.
        CHECK_EQ(SCIStripTrackingFromURLString(@"https://www.instagram.com/p/A/?IGSH=x#comments"),
                 @"https://www.instagram.com/p/A/#comments");

        // Nothing to remove: the very same string back.
        NSString *clean = @"https://www.instagram.com/p/A/?img_index=2";
        CHECK_EQ(SCIStripTrackingFromURLString(clean), clean);

        // Other sites are not ours to touch, even with the same parameter names.
        NSString *other = @"https://example.com/page?igsh=keepme&utm_source=newsletter";
        CHECK_EQ(SCIStripTrackingFromURLString(other), other);
        // A look-alike host is not Instagram.
        NSString *fake = @"https://notinstagram.com/p/A/?igsh=x";
        CHECK_EQ(SCIStripTrackingFromURLString(fake), fake);
        CHECK_EQ(SCIStripTrackingFromURLString(@"https://ig.me/j/Abc/?igsh=x"), @"https://ig.me/j/Abc/");

        // Things that are not addresses come back untouched.
        CHECK_EQ(SCIStripTrackingFromURLString(@"not a url"), @"not a url");
        CHECK_EQ(SCIStripTrackingFromURLString(@""), @"");

        // Text: only the Instagram address inside it changes, and the full stop after it stays.
        CHECK_EQ(SCIStripTrackingFromText(@"Look at this https://www.instagram.com/p/A/?igsh=x. Great, no?"),
                 @"Look at this https://www.instagram.com/p/A/. Great, no?");
        CHECK_EQ(SCIStripTrackingFromText(@"(https://www.instagram.com/reel/B/?igsh=y) and https://example.com/?igsh=keep"),
                 @"(https://www.instagram.com/reel/B/) and https://example.com/?igsh=keep");
        CHECK_EQ(SCIStripTrackingFromText(@"no link here"), @"no link here");
        CHECK_EQ(SCIStripTrackingFromText(@"two https://www.instagram.com/p/1/?igsh=a and https://www.instagram.com/p/2/?igshid=b"),
                 @"two https://www.instagram.com/p/1/ and https://www.instagram.com/p/2/");

        // Arabic around the address.
        CHECK_EQ(SCIStripTrackingFromText(@"شوف هذا https://www.instagram.com/p/A/?igsh=x جميل"),
                 @"شوف هذا https://www.instagram.com/p/A/ جميل");

        printf(fails ? "\n%d FAILED\n" : "\nall passed\n", fails);
        return fails ? 1 : 0;
    }
}
