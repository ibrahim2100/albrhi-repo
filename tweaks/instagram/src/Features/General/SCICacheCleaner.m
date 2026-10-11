#import "SCICacheCleaner.h"
#import "SCICacheRules.h"
#import "../../Utils.h"
#import "../../Localization/SCILocalize.h"
#import "modules/JGProgressHUD/JGProgressHUD.h"

@implementation SCICacheCleaner

+ (NSURL *)cachesURL {
    NSString *path = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    return path ? [NSURL fileURLWithPath:path] : nil;
}

/// The entries that would go: everything at the top level that is not ours and was not touched lately.
+ (NSArray<NSURL *> *)removableEntries {
    NSURL *root = [self cachesURL];
    if (!root) return @[];

    NSArray<NSURL *> *entries = [[NSFileManager defaultManager]
        contentsOfDirectoryAtURL:root
      includingPropertiesForKeys:@[NSURLContentModificationDateKey]
                         options:0
                           error:nil];

    NSMutableArray<NSURL *> *out = [NSMutableArray array];
    NSDate *recent = [NSDate dateWithTimeIntervalSinceNow:-SCICacheRecentlyUsedSeconds];
    for (NSURL *entry in entries) {
        if (SCICacheNameIsOurs(entry.lastPathComponent)) continue;
        NSDate *modified = nil;
        [entry getResourceValue:&modified forKey:NSURLContentModificationDateKey error:nil];
        if (modified && [modified compare:recent] == NSOrderedDescending) continue;
        [out addObject:entry];
    }
    return out;
}

+ (unsigned long long)bytesIn:(NSURL *)entry {
    NSFileManager *files = [NSFileManager defaultManager];
    unsigned long long total = 0;

    NSNumber *isDirectory = nil;
    [entry getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
    if (!isDirectory.boolValue) {
        NSNumber *size = nil;
        [entry getResourceValue:&size forKey:NSURLTotalFileAllocatedSizeKey error:nil];
        return size.unsignedLongLongValue;
    }

    NSDirectoryEnumerator *walk = [files enumeratorAtURL:entry
                              includingPropertiesForKeys:@[NSURLTotalFileAllocatedSizeKey, NSURLIsRegularFileKey]
                                                 options:0
                                            errorHandler:^BOOL(NSURL *url, NSError *error) { return YES; }];
    for (NSURL *file in walk) {
        NSNumber *regular = nil, *size = nil;
        [file getResourceValue:&regular forKey:NSURLIsRegularFileKey error:nil];
        if (!regular.boolValue) continue;
        [file getResourceValue:&size forKey:NSURLTotalFileAllocatedSizeKey error:nil];
        total += size.unsignedLongLongValue;
    }
    return total;
}

+ (unsigned long long)reclaimableBytes {
    unsigned long long total = 0;
    for (NSURL *entry in [self removableEntries]) total += [self bytesIn:entry];
    return total;
}

+ (unsigned long long)cleanCountingFailures:(NSUInteger *)failures {
    unsigned long long freed = 0;
    NSUInteger failed = 0;
    for (NSURL *entry in [self removableEntries]) {
        unsigned long long size = [self bytesIn:entry];
        NSError *error = nil;
        if ([[NSFileManager defaultManager] removeItemAtURL:entry error:&error]) freed += size;
        else failed++;
    }
    if (failures) *failures = failed;
    return freed;
}

+ (NSString *)describe:(unsigned long long)bytes {
    return [NSByteCountFormatter stringFromByteCount:(long long)bytes countStyle:NSByteCountFormatterCountStyleFile];
}

+ (void)presentCleanFlow {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        unsigned long long size = [self reclaimableBytes];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (size < 1024 * 1024) {
                JGProgressHUD *HUD = [[JGProgressHUD alloc] init];
                HUD.textLabel.text = SCILocalized(@"cache_nothing");
                HUD.indicatorView = [[JGProgressHUDSuccessIndicatorView alloc] init];
                [HUD showInView:topMostController().view];
                [HUD dismissAfterDelay:2.0];
                return;
            }

            NSString *title = [NSString stringWithFormat:SCILocalized(@"cache_confirm_fmt"), [self describe:size]];
            [SCIUtils showConfirmation:^{
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                    NSUInteger failures = 0;
                    unsigned long long freed = [self cleanCountingFailures:&failures];

                    dispatch_async(dispatch_get_main_queue(), ^{
                        JGProgressHUD *HUD = [[JGProgressHUD alloc] init];
                        HUD.textLabel.text = failures
                            ? [NSString stringWithFormat:SCILocalized(@"cache_done_partial_fmt"), [self describe:freed], (unsigned long)failures]
                            : [NSString stringWithFormat:SCILocalized(@"cache_done_fmt"), [self describe:freed]];
                        HUD.indicatorView = [[JGProgressHUDSuccessIndicatorView alloc] init];
                        [HUD showInView:topMostController().view];
                        [HUD dismissAfterDelay:2.5];
                    });
                });
            } title:title];
        });
    });
}

@end
