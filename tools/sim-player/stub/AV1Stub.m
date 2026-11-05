// The AV1 converter links a device-built dav1d, which a simulator app cannot; the harness never converts.
#import "Features/Download/SCIYTAV1Convert.h"
@implementation SCIYTAV1Convert
+ (void)convertVideo:(NSURL *)video audio:(NSURL *)audio progress:(void (^)(double))progress completion:(void (^)(NSURL *, NSString *))completion {
    completion(nil, @"not in the harness");
}
@end
