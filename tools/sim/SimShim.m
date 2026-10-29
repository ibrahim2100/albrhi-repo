// A simulator-only helper, never shipped. TikTok's Metal pipeline completion handlers are written for a device: when the simulator's
// Metal compiler refuses a device-built library the handler is called with an error and a nil state, and TikTok's handler builds a C++
// string from a nil NSString (strlen(NULL)). This swallows the failed callbacks and says why they failed.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <objc/runtime.h>

static NSUInteger sFailed = 0;

typedef void (^RenderHandler)(id, id, NSError *);
typedef void (^ComputeHandler)(id, id, NSError *);

static void SwizzleDevice(Class cls, SEL sel, IMP imp, IMP *orig) {
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;
    *orig = method_getImplementation(m);
    method_setImplementation(m, imp);
}

static IMP origRenderOpts, origRender, origTexFromBuffer;
static NSUInteger sTexRefused = 0;

static id renderOpts(id self, SEL _cmd, id desc, NSUInteger options, RenderHandler handler) {
    RenderHandler safe = ^(id state, id reflection, NSError *error) {
        if (!state || error) { sFailed++; NSLog(@"[SimShim] render pipeline failed (%lu): %@", (unsigned long)sFailed, error.localizedDescription); return; }
        if (handler) handler(state, reflection, error);
    };
    return ((id (*)(id, SEL, id, NSUInteger, RenderHandler))origRenderOpts)(self, _cmd, desc, options, safe);
}
static id renderPlain(id self, SEL _cmd, id desc, id handler) {
    RenderHandler h = handler;
    void (^safe)(id, NSError *) = ^(id state, NSError *error) {
        if (!state || error) { sFailed++; NSLog(@"[SimShim] render pipeline failed (%lu): %@", (unsigned long)sFailed, error.localizedDescription); return; }
        ((void (^)(id, NSError *))h)(state, error);
    };
    return ((id (*)(id, SEL, id, id))origRender)(self, _cmd, desc, safe);
}

// A texture made from a buffer: the simulator's driver asserts (and aborts the process) when the offset or the row pitch is not aligned
// the way the simulator's GPU wants it, where a real device accepts it. Such a request is refused with nil instead of aborting.
static id texFromBuffer(id self, SEL _cmd, MTLTextureDescriptor *desc, NSUInteger offset, NSUInteger bytesPerRow) {
    id<MTLDevice> device = [(id<MTLBuffer>)self device];
    if ([(id<MTLBuffer>)self storageMode] != MTLStorageModePrivate) {
        sTexRefused++;
        NSLog(@"[SimShim] refused texture-from-buffer #%lu: the simulator only allows it on a private buffer (this one is storage mode %lu)", (unsigned long)sTexRefused, (unsigned long)[(id<MTLBuffer>)self storageMode]);
        return nil;
    }
    NSUInteger align = [device minimumLinearTextureAlignmentForPixelFormat:desc.pixelFormat];
    if (align > 1 && (offset % align != 0 || bytesPerRow % align != 0)) {
        sTexRefused++;
        NSLog(@"[SimShim] refused texture-from-buffer #%lu: offset %lu, bytesPerRow %lu, alignment %lu, %lux%lu fmt %lu", (unsigned long)sTexRefused,
              (unsigned long)offset, (unsigned long)bytesPerRow, (unsigned long)align, (unsigned long)desc.width, (unsigned long)desc.height, (unsigned long)desc.pixelFormat);
        return nil;
    }
    return ((id (*)(id, SEL, id, NSUInteger, NSUInteger))origTexFromBuffer)(self, _cmd, desc, offset, bytesPerRow);
}

__attribute__((constructor)) static void ShimInit(void) {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device) { NSLog(@"[SimShim] no Metal device"); return; }
    Class cls = object_getClass(device);
    SwizzleDevice(cls, @selector(newRenderPipelineStateWithDescriptor:options:completionHandler:), (IMP)renderOpts, &origRenderOpts);
    SwizzleDevice(cls, @selector(newRenderPipelineStateWithDescriptor:completionHandler:), (IMP)renderPlain, &origRender);
    id<MTLBuffer> probe = [device newBufferWithLength:4096 options:MTLResourceStorageModeShared];
    SwizzleDevice(object_getClass(probe), @selector(newTextureWithDescriptor:offset:bytesPerRow:), (IMP)texFromBuffer, &origTexFromBuffer);
    NSLog(@"[SimShim] guarding %@ (render %d/%d, texture-from-buffer %d on %@)", NSStringFromClass(cls), origRenderOpts != NULL, origRender != NULL,
          origTexFromBuffer != NULL, NSStringFromClass(object_getClass(probe)));
}
