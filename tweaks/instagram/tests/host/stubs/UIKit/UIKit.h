#import <Foundation/Foundation.h>
@interface UIWindow : NSObject @end
@interface UIApplication : NSObject
+ (UIApplication *)sharedApplication;
@property (nonatomic, readonly) NSArray<UIWindow *> *windows;
@end
