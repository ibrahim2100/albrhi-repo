#import "SCIPanelUpdate.h"


#import "SCIPanelScan.h"

// Both flavours are one product wearing two package identities, and a device carries exactly
// one of them. Asking about both and taking whichever answers is simpler than working out
// which jailbreak this is.
static NSArray<NSString *> *SCISuitePackages(void) {
    return @[@"com.albrhi", @"com.albrhi.roothide"];
}

//
// **Not written a second time.**
//
// The first draft of this file derived the jailbreak prefix from `dladdr` and parsed dpkg's
// status file itself -- both of which `SCIPanelScan` already does, correctly, and has done
// since the panel learned to show the installed suite version. Two readers of one fact drift
// apart the moment either is fixed, which is the failure this project has written down about
// the per-app switch being answered in three places.
//
NSString *SCIPanelInstalledSuiteVersion(void) {
    return [SCIPanelScan installedSuiteVersion];
}

// host-test:begin newest
// dpkg-scanpackages -m publishes several versions of one package on purpose, so the source
// legitimately lists 1.57.0 above 1.58.10. Taking the first match would report an update as a
// downgrade; the highest is the only answer that means anything.
static NSString *SCINewestVersionIn(NSString *text) {
    NSString *best = nil;

    for (NSString *stanza in [text componentsSeparatedByString:@"\n\n"]) {
        NSString *name = nil, *version = nil;

        for (NSString *line in [stanza componentsSeparatedByString:@"\n"]) {
            if ([line hasPrefix:@"Package: "]) name = [line substringFromIndex:9];
            else if ([line hasPrefix:@"Version: "]) version = [line substringFromIndex:9];
        }

        if (!name || !version) continue;
        if (![SCISuitePackages() containsObject:name]) continue;

        if (!best || [version compare:best options:NSNumericSearch] == NSOrderedDescending) {
            best = version;
        }
    }

    return best;
}

// host-test:end newest

void SCIPanelCheckForUpdate(void (^completion)(NSString *latest, NSString *installed, BOOL newer)) {
    NSString *installed = SCIPanelInstalledSuiteVersion();

    NSURL *url = [NSURL URLWithString:@"https://ibrahim2100.github.io/albrhi-repo/Packages"];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                          cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                      timeoutInterval:15];

    NSURLSessionDataTask *task =
        [[NSURLSession sharedSession] dataTaskWithRequest:request
                                        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSString *text = data.length
                ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;

            NSString *latest = text.length ? SCINewestVersionIn(text) : nil;

            // A missing installed version is not a reason to withhold the published one: a
            // sideloaded device has no dpkg to ask, and "the newest is X" is still the answer
            // to what was asked.
            BOOL newer = (latest.length && installed.length)
                && [latest compare:installed options:NSNumericSearch] == NSOrderedDescending;

            dispatch_async(dispatch_get_main_queue(), ^{
                completion(latest, installed, newer);
            });
        }];

    [task resume];
}
