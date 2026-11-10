//
//  Test_FileName.m -- SCIFileName
//
#import <Foundation/Foundation.h>
#import "shared/src/SCIFileName.h"

static int failures = 0, checks = 0;
#define CHECK(cond, ...) do { checks++; if (!(cond)) { failures++; NSLog(@"FAIL: %@", __VA_ARGS__); } } while (0)

static NSUInteger Bytes(NSString *s) { return [s lengthOfBytesUsingEncoding:NSUTF8StringEncoding]; }

static BOOL Safe(NSString *name) {
    if (!name.length) return NO;
    if ([name hasPrefix:@"."] || [name hasSuffix:@"."] || [name hasSuffix:@" "]) return NO;
    NSCharacterSet *bad = [NSCharacterSet characterSetWithCharactersInString:@"/\\:*?\"<>|\n\r\t‎‏‮⁦⁩​"];
    if ([name rangeOfCharacterFromSet:bad].location != NSNotFound) return NO;
    return Bytes(name) <= 200;
}

int main(void) {
    @autoreleasepool {
        // The ordinary case.
        NSString *n = SCIFileNameBuild(@"ilzer", @"Beautiful sunset over the sea", @"7691154739186126", @"mp4", @"TikTok");
        CHECK([n isEqualToString:@"@ilzer - Beautiful sunset over the sea - 7691154739186126.mp4"], n);

        // An "@" already there is not doubled; spaces in an account become underscores.
        n = SCIFileNameBuild(@"@Some Name", @"hi", @"42", @"m4a", @"x");
        CHECK([n isEqualToString:@"@Some_Name - hi - 42.m4a"], n);

        // Arabic stays Arabic and is cut on a character, not through one.
        n = SCIFileNameBuild(@"محمد", @"السعودية خط أحمر وطنياً ولا يمكن لأحد أن يتجاوزه أبداً في أي وقت من الأوقات مهما كان", @"123456", @"mp4", @"x");
        CHECK(Safe(n), n);
        CHECK(Bytes(n) <= 120, [NSString stringWithFormat:@"%lu bytes: %@", (unsigned long)Bytes(n), n]);
        CHECK([n hasPrefix:@"@محمد - السعودية"], n);
        CHECK([n hasSuffix:@" - 123456.mp4"], n);
        CHECK([[NSString alloc] initWithData:[n dataUsingEncoding:NSUTF8StringEncoding] encoding:NSUTF8StringEncoding] != nil, @"valid utf8");

        // An emoji family is one character and is never split.
        NSString *fam = @"\U0001F468‍\U0001F469‍\U0001F467‍\U0001F466";
        NSString *longEmoji = @"";
        for (int i = 0; i < 30; i++) longEmoji = [longEmoji stringByAppendingString:fam];
        n = SCIFileNameBuild(@"a", longEmoji, @"1", @"mp4", @"x");
        CHECK(Bytes(n) <= 120, [NSString stringWithFormat:@"emoji %lu", (unsigned long)Bytes(n)]);
        CHECK([[NSString alloc] initWithData:[n dataUsingEncoding:NSUTF8StringEncoding] encoding:NSUTF8StringEncoding] != nil, @"emoji utf8");
        // The ZWJ characters are stripped (they are in the invisible set), so the family falls apart into its parts -- but never half a scalar.
        for (NSUInteger i = 0; i < n.length; i++) {
            unichar c = [n characterAtIndex:i];
            if (CFStringIsSurrogateHighCharacter(c)) CHECK(i + 1 < n.length && CFStringIsSurrogateLowCharacter([n characterAtIndex:i + 1]), @"lone high surrogate");
            if (CFStringIsSurrogateLowCharacter(c)) CHECK(i > 0 && CFStringIsSurrogateHighCharacter([n characterAtIndex:i - 1]), @"lone low surrogate");
        }

        // Characters a path cannot hold, newlines, bidi controls.
        n = SCIFileNameBuild(@"u/s:e*r", @"a/b\\c:d*e?f\"g<h>i|j\nk‮l", @"9", @"mp4", @"x");
        CHECK(Safe(n), n);

        // Links go, and so does a trailing run of hashtags.
        n = SCIFileNameBuild(@"u", @"look at this https://vt.tiktok.com/ZSabc/ now #fyp #foryou #viral", @"5", @"mp4", @"x");
        CHECK([n isEqualToString:@"@u - look at this now - 5.mp4"], n);

        // A caption that is only hashtags keeps them (empty would lose the name).
        n = SCIFileNameBuild(@"u", @"#fyp #foryou", @"5", @"mp4", @"x");
        CHECK([n isEqualToString:@"@u - #fyp #foryou - 5.mp4"], n);

        // A very long id keeps its tail; a missing caption is simply absent.
        n = SCIFileNameBuild(@"u", nil, @"1234567890123456789012345", @"mp4", @"x");
        CHECK([n isEqualToString:@"@u - 0123456789012345.mp4"], n);

        // Nothing at all: the fallback; nothing and no fallback: still not empty.
        CHECK([SCIFileNameBuild(nil, nil, nil, @"mp4", @"TikTok video") isEqualToString:@"TikTok video.mp4"], @"fallback");
        CHECK([SCIFileNameBuild(nil, nil, nil, nil, @"") isEqualToString:@"Albrhi"], @"last resort");
        CHECK([SCIFileNameBuild((id)@42, (id)@[], (id)[NSNull null], (id)@7, @"f") isEqualToString:@"f"], @"wrong types do not crash");

        // An extension is letters and digits only; a dot, spaces and capitals are normalised, rubbish is dropped.
        CHECK([SCIFileNameBuild(@"u", nil, @"1", @".MP4 ", @"x") hasSuffix:@".mp4"], @"extension normalised");
        CHECK(![SCIFileNameBuild(@"u", nil, @"1", @"mp4/../x", @"x") containsString:@"/"], @"extension with a slash is dropped");

        // A name never starts with a dot.
        n = SCIFileNameBuild(@"", @"...hidden", @"", @"txt", @"x");
        CHECK(![n hasPrefix:@"."], n);

        // The plain cleaner.
        CHECK([SCIFileNameClean(@"  a   b \n c  ", 100) isEqualToString:@"a b c"], @"whitespace collapsed");
        CHECK([SCIFileNameClean(@"abcdef", 3) isEqualToString:@"abc"], @"cut");
        CHECK([SCIFileNameClean(nil, 10) isEqualToString:@""], @"nil");

        // Same inputs, same name (a re-download must not invent a new one).
        CHECK([SCIFileNameBuild(@"u", @"c", @"1", @"mp4", @"x") isEqualToString:SCIFileNameBuild(@"u", @"c", @"1", @"mp4", @"x")], @"deterministic");
    }
    printf("SCIFileName: %d checks, %d failed\n", checks, failures);
    return failures ? 1 : 0;
}
