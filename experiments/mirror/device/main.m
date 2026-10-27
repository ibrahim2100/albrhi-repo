//
//  main.m  --  albrhi-mirrord, stage 1
//
//  A probe, not a product. It answers one question before anything bigger is built:
//  **can this phone's screen be captured from a root process, and does that keep working while the phone is locked?**
//
//  It listens on 127.0.0.1 only (the Mac reaches it through a USB tunnel, `iproxy`), serves one client at a time,
//  captures the display as JPEG frames, and reports what it can see about the device: iOS version, lock state,
//  which private symbols resolved, how long a capture took, and whether the picture changed since the last one.
//  It does not inject touches, does not change power or brightness, does not start itself, and there is no
//  authentication because there is no network exposure: that is stage 4, and nothing leaves stage 1 without it.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <signal.h>
#include <sys/socket.h>
#include <sys/utsname.h>
#include <unistd.h>
#include <dlfcn.h>
#include <mach/mach_time.h>

#if TARGET_OS_IPHONE
#import <IOSurface/IOSurfaceRef.h>
#endif

// ---- wire format: [type:1][length:4 big endian][payload] ---------------------------------------------------------
enum { kMsgInfo = 1, kMsgFrame = 2, kMsgEvent = 3, kMsgCommand = 10 };

static BOOL SendAll(int fd, const void *bytes, size_t length) {
    const uint8_t *p = bytes;
    while (length) {
        ssize_t n = send(fd, p, length, 0);
        if (n <= 0) return NO;
        p += n; length -= (size_t)n;
    }
    return YES;
}

static BOOL SendMessage(int fd, uint8_t type, NSData *payload) {
    uint8_t header[5] = { type, (uint8_t)(payload.length >> 24), (uint8_t)(payload.length >> 16),
                          (uint8_t)(payload.length >> 8), (uint8_t)payload.length };
    return SendAll(fd, header, 5) && SendAll(fd, payload.bytes, payload.length);
}

static BOOL SendJSON(int fd, uint8_t type, NSDictionary *object) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:object options:0 error:nil];
    return SendMessage(fd, type, data ?: [NSData data]);
}

static double Seconds(void) {
    static mach_timebase_info_data_t base;
    if (!base.denom) mach_timebase_info(&base);
    return (double)mach_absolute_time() * base.numer / base.denom / 1e9;
}

// ---- what the device lets us do ----------------------------------------------------------------------------------
typedef void (*RenderDisplayFn)(uint32_t port, CFStringRef display, void *surface, int x, int y);
typedef uint32_t (*FrameCounterFn)(uint32_t port);
typedef void (*LockStatusFn)(BOOL *locked, BOOL *passcode);

static RenderDisplayFn sRender;
static FrameCounterFn sFrameCounter;
static LockStatusFn sLockStatus;
static NSMutableArray<NSString *> *sSymbolReport;

static void ResolveSymbols(void) {
    sSymbolReport = [NSMutableArray array];
#if TARGET_OS_IPHONE
    void *quartz = dlopen("/System/Library/Frameworks/QuartzCore.framework/QuartzCore", RTLD_NOW);
    sRender = quartz ? (RenderDisplayFn)dlsym(quartz, "CARenderServerRenderDisplay") : NULL;
    sFrameCounter = quartz ? (FrameCounterFn)dlsym(quartz, "CARenderServerGetFrameCounter") : NULL;
    void *sbs = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_NOW);
    sLockStatus = sbs ? (LockStatusFn)dlsym(sbs, "SBSGetScreenLockStatus") : NULL;
#endif
    [sSymbolReport addObject:[NSString stringWithFormat:@"CARenderServerRenderDisplay: %@", sRender ? @"found" : @"MISSING"]];
    [sSymbolReport addObject:[NSString stringWithFormat:@"CARenderServerGetFrameCounter: %@", sFrameCounter ? @"found" : @"MISSING"]];
    [sSymbolReport addObject:[NSString stringWithFormat:@"SBSGetScreenLockStatus: %@", sLockStatus ? @"found" : @"MISSING"]];
}

typedef struct { size_t width, height; } PixelSize;

/// MobileGestalt answers "how big is the panel" without UIKit, which a daemon with no application should not start.
__attribute__((unused)) static int32_t GestaltInt(NSString *key, int32_t fallback) {
    static void *library; static CFTypeRef (*copyAnswer)(CFStringRef);
    if (!library) { library = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_NOW); copyAnswer = library ? (CFTypeRef (*)(CFStringRef))dlsym(library, "MGCopyAnswer") : NULL; }
    if (!copyAnswer) return fallback;
    CFTypeRef value = copyAnswer((__bridge CFStringRef)key);
    int32_t result = fallback;
    if (value && CFGetTypeID(value) == CFNumberGetTypeID()) CFNumberGetValue(value, kCFNumberSInt32Type, &result);
    if (value) CFRelease(value);
    return result;
}

static PixelSize ScreenPixels(void) {
#if TARGET_OS_IPHONE
    int32_t w = GestaltInt(@"main-screen-width", 0), h = GestaltInt(@"main-screen-height", 0);
    if (w > 0 && h > 0) return (PixelSize){ (size_t)w, (size_t)h };
#endif
    return (PixelSize){ 1170, 2532 };
}

static NSString *LockText(void) {
    if (!sLockStatus) return @"unknown (SBSGetScreenLockStatus missing)";
    BOOL locked = NO, passcode = NO;
    sLockStatus(&locked, &passcode);
    return [NSString stringWithFormat:@"%@, passcode %@", locked ? @"LOCKED" : @"unlocked", passcode ? @"set" : @"none"];
}

// ---- capture ------------------------------------------------------------------------------------------------------
#if TARGET_OS_IPHONE
static IOSurfaceRef sSurface;
static PixelSize sSurfaceSize;

static IOSurfaceRef MakeSurface(PixelSize size) {
    NSDictionary *props = @{
        (id)kIOSurfaceWidth: @(size.width), (id)kIOSurfaceHeight: @(size.height),
        (id)kIOSurfaceBytesPerElement: @4, (id)kIOSurfacePixelFormat: @((uint32_t)'BGRA'),
    };
    return IOSurfaceCreate((__bridge CFDictionaryRef)props);
}
#endif

/// One captured frame as JPEG, plus a cheap fingerprint of the pixels (to tell "the picture changed" from "it was resent")
/// and the share of sampled pixels that are not black (to tell a captured screen from an empty surface).
static NSData *CaptureFrame(PixelSize *outSize, uint32_t *outFingerprint, double *outNonBlack, NSString **outError) {
    size_t width = 0, height = 0, stride = 0;
    const uint8_t *pixels = NULL;
    CGContextRef context = NULL;
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    NSData *result = nil;

#if TARGET_OS_IPHONE
    PixelSize wanted = ScreenPixels();
    if (!sRender) { *outError = @"CARenderServerRenderDisplay is not available"; CGColorSpaceRelease(rgb); return nil; }
    if (!sSurface || sSurfaceSize.width != wanted.width || sSurfaceSize.height != wanted.height) {
        if (sSurface) CFRelease(sSurface);
        sSurface = MakeSurface(wanted);
        sSurfaceSize = wanted;
    }
    if (!sSurface) { *outError = @"IOSurfaceCreate failed"; CGColorSpaceRelease(rgb); return nil; }
    sRender(0, CFSTR("LCD"), sSurface, 0, 0);
    IOSurfaceLock(sSurface, kIOSurfaceLockReadOnly, NULL);
    pixels = IOSurfaceGetBaseAddress(sSurface);
    width = IOSurfaceGetWidth(sSurface); height = IOSurfaceGetHeight(sSurface); stride = IOSurfaceGetBytesPerRow(sSurface);
#else
    // Host build (the Mac), a moving test picture: it exists so the wire format and the viewer can be tested without a phone.
    static uint32_t tick; tick++;
    width = 390; height = 844; stride = width * 4;
    static uint8_t *fake; if (!fake) fake = malloc(stride * height);
    for (size_t y = 0; y < height; y++) for (size_t x = 0; x < width; x++) {
        uint8_t *px = fake + y * stride + x * 4;
        px[0] = (uint8_t)(x + tick * 3); px[1] = (uint8_t)(y); px[2] = (uint8_t)((x ^ y) + tick); px[3] = 255;
    }
    pixels = fake;
#endif

    uint32_t hash = 2166136261u; size_t sampled = 0, lit = 0;
    for (size_t y = 0; y < height; y += 37) for (size_t x = 0; x < width; x += 29) {
        const uint8_t *px = pixels + y * stride + x * 4;
        hash = (hash ^ px[0]) * 16777619u; hash = (hash ^ px[1]) * 16777619u; hash = (hash ^ px[2]) * 16777619u;
        sampled++; if (px[0] | px[1] | px[2]) lit++;
    }

    context = CGBitmapContextCreate((void *)pixels, width, height, 8, stride, rgb,
                                    kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef image = context ? CGBitmapContextCreateImage(context) : NULL;
    if (image) {
        NSMutableData *jpeg = [NSMutableData data];
        CGImageDestinationRef dest = CGImageDestinationCreateWithData((CFMutableDataRef)jpeg, CFSTR("public.jpeg"), 1, NULL);
        NSDictionary *options = @{ (id)kCGImageDestinationLossyCompressionQuality: @0.55 };
        CGImageDestinationAddImage(dest, image, (CFDictionaryRef)options);
        if (CGImageDestinationFinalize(dest)) result = jpeg;
        CFRelease(dest); CGImageRelease(image);
    } else {
        *outError = @"could not build an image from the captured pixels";
    }
    if (context) CGContextRelease(context);
#if TARGET_OS_IPHONE
    IOSurfaceUnlock(sSurface, kIOSurfaceLockReadOnly, NULL);
#endif
    CGColorSpaceRelease(rgb);
    *outSize = (PixelSize){ width, height };
    *outFingerprint = hash;
    *outNonBlack = sampled ? (double)lit / (double)sampled : 0;
    return result;
}

// ---- one client -------------------------------------------------------------------------------------------------
static NSDictionary *DeviceInfo(void) {
    struct utsname name; uname(&name);
    NSMutableDictionary *info = [@{
        @"daemon": @"albrhi-mirrord stage 1",
        @"machine": @(name.machine),
        @"uid": @(getuid()),
        @"symbols": sSymbolReport ?: @[],
        @"lock": LockText(),
        @"screen": [NSString stringWithFormat:@"%zux%zu px", ScreenPixels().width, ScreenPixels().height],
    } mutableCopy];
#if TARGET_OS_IPHONE
    info[@"ios"] = [NSProcessInfo processInfo].operatingSystemVersionString;
    info[@"mgScreenScale"] = @(GestaltInt(@"main-screen-scale", 0));
#else
    info[@"ios"] = @"(host test build, no iPhone)";
#endif
    if (sFrameCounter) info[@"renderFrameCounter"] = @(sFrameCounter(0));
    return info;
}

static void Serve(int client, double fps) {
    SendJSON(client, kMsgInfo, DeviceInfo());
    uint32_t previous = 0; BOOL first = YES; double lastInfo = 0; NSUInteger sent = 0, changed = 0;
    double interval = 1.0 / (fps > 0 ? fps : 4);

    while (YES) {
        double started = Seconds();
        PixelSize size = {0, 0}; uint32_t fingerprint = 0; double nonBlack = 0; NSString *error = nil;
        NSData *jpeg = CaptureFrame(&size, &fingerprint, &nonBlack, &error);
        double took = Seconds() - started;

        if (!jpeg) {
            if (!SendJSON(client, kMsgEvent, @{ @"error": error ?: @"capture failed", @"lock": LockText() })) return;
        } else {
            BOOL differs = first || fingerprint != previous;
            if (differs) changed++;
            first = NO; previous = fingerprint; sent++;

            // 20-byte header: width, height, render frame counter, fingerprint, flags (bit0: differs, bit1: non-black < 1%)
            uint32_t fields[5] = { htonl((uint32_t)size.width), htonl((uint32_t)size.height),
                                   htonl(sFrameCounter ? sFrameCounter(0) : 0), htonl(fingerprint),
                                   htonl((differs ? 1u : 0u) | (nonBlack < 0.01 ? 2u : 0u)) };
            NSMutableData *payload = [NSMutableData dataWithBytes:fields length:sizeof(fields)];
            [payload appendData:jpeg];
            if (!SendMessage(client, kMsgFrame, payload)) return;
        }

        if (Seconds() - lastInfo > 1.5) {
            lastInfo = Seconds();
            NSMutableDictionary *info = [DeviceInfo() mutableCopy];
            info[@"live"] = @{ @"framesSent": @(sent), @"framesThatDiffered": @(changed),
                               @"lastCaptureMs": @((int)(took * 1000)), @"nonBlackShare": @(nonBlack) };
            if (!SendJSON(client, kMsgInfo, info)) return;
        }

        // A command is a JSON line from the viewer; stage 1 understands only {"fps": n}.
        fd_set readable; FD_ZERO(&readable); FD_SET(client, &readable);
        double remaining = interval - (Seconds() - started);
        struct timeval wait = { 0, (int)((remaining > 0 ? remaining : 0) * 1e6) };
        if (select(client + 1, &readable, NULL, NULL, &wait) > 0) {
            uint8_t header[5]; ssize_t n = recv(client, header, 5, MSG_WAITALL);
            if (n != 5) return;
            uint32_t length = ((uint32_t)header[1] << 24) | (header[2] << 16) | (header[3] << 8) | header[4];
            if (length > 4096) return;
            NSMutableData *body = [NSMutableData dataWithLength:length];
            if (length && recv(client, body.mutableBytes, length, MSG_WAITALL) != (ssize_t)length) return;
            NSDictionary *command = header[0] == kMsgCommand ? [NSJSONSerialization JSONObjectWithData:body options:0 error:nil] : nil;
            if ([command[@"fps"] isKindOfClass:[NSNumber class]]) interval = 1.0 / MAX(0.5, MIN(30.0, [command[@"fps"] doubleValue]));
        }
    }
}

int main(int argc, char **argv) {
    @autoreleasepool {
        signal(SIGPIPE, SIG_IGN);
        int port = 9777; double fps = 4; BOOL once = NO;
        for (int i = 1; i < argc; i++) {
            if (!strcmp(argv[i], "--port") && i + 1 < argc) port = atoi(argv[++i]);
            else if (!strcmp(argv[i], "--fps") && i + 1 < argc) fps = atof(argv[++i]);
            else if (!strcmp(argv[i], "--once")) once = YES;
        }
        ResolveSymbols();

        int listener = socket(AF_INET, SOCK_STREAM, 0);
        int yes = 1; setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
        struct sockaddr_in address = { .sin_len = sizeof(address), .sin_family = AF_INET, .sin_port = htons((uint16_t)port) };
        address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);          // loopback only: never on the network
        if (bind(listener, (struct sockaddr *)&address, sizeof(address)) != 0 || listen(listener, 1) != 0) {
            fprintf(stderr, "albrhi-mirrord: cannot listen on 127.0.0.1:%d\n", port);
            return 1;
        }
        printf("albrhi-mirrord stage 1 listening on 127.0.0.1:%d (loopback only; reach it through `iproxy`)\n", port);
        fflush(stdout);

        while (YES) {
            int client = accept(listener, NULL, NULL);
            if (client < 0) continue;
            @autoreleasepool { Serve(client, fps); }
            close(client);
            if (once) break;
        }
    }
    return 0;
}
