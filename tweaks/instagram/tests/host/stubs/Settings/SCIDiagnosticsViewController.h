#import <Foundation/Foundation.h>
@interface SCIDiagnostics : NSObject
+ (void)privacyCount:(NSString *)label;
+ (void)recordUnsendPath:(NSString *)path detail:(NSString *)detail;
@end
