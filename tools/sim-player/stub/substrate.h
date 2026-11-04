// MSHookMessageEx without Substrate, for the simulator harness: five lines of the runtime.
#import <objc/runtime.h>
static inline void MSHookMessageEx(Class cls, SEL sel, IMP imp, IMP *result) {
    Method m = class_getInstanceMethod(cls, sel);
    if (result) *result = method_getImplementation(m);
    method_setImplementation(m, imp);
}
