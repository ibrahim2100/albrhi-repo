//
//  main.m  --  albrhi-mirrord, stage 1
//
//  A probe, not a product. It answers one question before anything bigger is built:
//  **can this phone's screen be captured from a root process, and does that keep working while the phone is locked?**
//
//  It listens on 127.0.0.1 only (the Mac reaches it through a USB tunnel, `iproxy`) and serves one client at a time.
//  **Loopback is not private on a phone: any app on the device can connect to 127.0.0.1.** So nothing is sent to a
//  client that has not proved it holds a secret that only a paired Mac has:
//
//    * It starts by itself (a LaunchDaemon) and sits idle: no capture, no output, until an authenticated session.
//    * **Pairing, once**: the viewer asks to pair, the phone shows a six-digit code in an alert, the person types it on the
//      Mac, and the daemon hands over a random 32-byte secret (stored 0600 on the phone). Three wrong codes, or 120 seconds,
//      end the attempt; a new alert is not shown more than once every 20 seconds, nor within 30 seconds of a failed attempt.
//    * **Every later session**: each side sends a random nonce and proves it knows the secret with HMAC-SHA256 over both
//      nonces and its role, so the Mac also knows it is talking to the daemon and not to an app squatting on the port.
//
//  It does not inject touches and does not change power or brightness. Frames are not encrypted: they never leave the
//  USB tunnel, and encryption is stage 4, before any listener on the network.
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
#include <sys/stat.h>
#include <errno.h>
#import <CommonCrypto/CommonHMAC.h>
#import <CoreFoundation/CFUserNotification.h>

#if TARGET_OS_IPHONE
#import <IOSurface/IOSurfaceRef.h>
#endif

// ---- wire format: [type:1][length:4 big endian][payload] ---------------------------------------------------------
enum { kMsgInfo = 1, kMsgFrame = 2, kMsgEvent = 3, kMsgCommand = 10,
       kMsgHello = 20, kMsgChallenge = 21, kMsgProof = 22, kMsgPairCode = 23, kMsgPaired = 24 };

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

// ---- pairing and the handshake ------------------------------------------------------------------------------------
static NSString *sSecretPath = @"/var/mobile/Library/Preferences/com.albrhi.mirror.pairing";
static BOOL sTestPrintCode;   // host test builds only: print the pairing code instead of showing an alert

static NSString *Hex(NSData *data) {
    NSMutableString *out = [NSMutableString stringWithCapacity:data.length * 2];
    const uint8_t *p = data.bytes;
    for (NSUInteger i = 0; i < data.length; i++) [out appendFormat:@"%02x", p[i]];
    return out;
}

static NSData *RandomBytes(size_t count) {
    NSMutableData *data = [NSMutableData dataWithLength:count];
    arc4random_buf(data.mutableBytes, count);
    return data;
}

static NSString *Proof(NSData *secret, NSString *role, NSString *clientNonce, NSString *serverNonce) {
    NSData *message = [[NSString stringWithFormat:@"%@|%@|%@", role, clientNonce, serverNonce] dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t mac[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, secret.bytes, secret.length, message.bytes, message.length, mac);
    return Hex([NSData dataWithBytes:mac length:sizeof(mac)]);
}

static BOOL ConstantTimeEqual(id a, id b) {
    if (![a isKindOfClass:[NSString class]] || ![b isKindOfClass:[NSString class]] || [a length] != [b length]) return NO;
    unsigned diff = 0;
    for (NSUInteger i = 0; i < [a length]; i++) diff |= (unsigned)([a characterAtIndex:i] ^ [b characterAtIndex:i]);
    return diff == 0;
}

static NSData *LoadSecret(void) {
    NSData *data = [NSData dataWithContentsOfFile:sSecretPath];
    return data.length == 32 ? data : nil;
}

static BOOL SaveSecret(NSData *secret) {
    if (![secret writeToFile:sSecretPath atomically:YES]) return NO;
    chmod(sSecretPath.fileSystemRepresentation, 0600);
    return YES;
}

/// 1 = a message, 0 = nothing arrived in time, -1 = the connection closed or sent nonsense.
static int ReadMessage(int fd, double timeout, uint8_t *type, NSData **payload) {
    struct timeval limit = { (time_t)timeout, (suseconds_t)((timeout - (time_t)timeout) * 1e6) };
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &limit, sizeof(limit));
    uint8_t header[5];
    ssize_t n = recv(fd, header, 5, MSG_WAITALL);
    if (n == 0) return -1;
    if (n < 0) return (errno == EAGAIN || errno == EWOULDBLOCK) ? 0 : -1;
    if (n != 5) return -1;
    uint32_t length = ((uint32_t)header[1] << 24) | (header[2] << 16) | (header[3] << 8) | header[4];
    if (length > 4096) return -1;
    NSMutableData *body = [NSMutableData dataWithLength:length];
    if (length && recv(fd, body.mutableBytes, length, MSG_WAITALL) != (ssize_t)length) return -1;
    *type = header[0]; *payload = body;
    return 1;
}

static NSDictionary *ReadJSON(int fd, double timeout, uint8_t expected) {
    uint8_t type = 0; NSData *payload = nil;
    if (ReadMessage(fd, timeout, &type, &payload) != 1 || type != expected) return nil;
    id object = [NSJSONSerialization JSONObjectWithData:payload options:0 error:nil];
    return [object isKindOfClass:[NSDictionary class]] ? object : nil;
}

static double sNextPairingAllowed = 0;
static volatile BOOL sPairingCancelled;

static void ShowCodeAlert(NSString *code) {
    // On the phone the code is shown in an alert (it appears over the lock screen too). A host test build never opens one.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        CFOptionFlags response = 0;
        NSString *message = [NSString stringWithFormat:@"A Mac asked to pair with this iPhone.\n\n%@\n\nType this code on the Mac. Cancel if you did not ask for it.\n\nمكبوك يطلب الاقتران بهذا الآيفون. اكتب الرمز على الماك، أو اضغط Cancel إن لم تطلبه.", code];
        SInt32 result = CFUserNotificationDisplayAlert(120, kCFUserNotificationNoteAlertLevel, NULL, NULL, NULL, CFSTR("Albrhi Mirror"),
                                       (__bridge CFStringRef)message, CFSTR("OK"), CFSTR("Cancel"), NULL, &response);
        // The log never carries the code. A non-zero result means the phone could not show the alert at all.
        printf("pairing alert closed: result %d, response %lu\n", (int)result, (unsigned long)response); fflush(stdout);
        if (response == kCFUserNotificationAlternateResponse) sPairingCancelled = YES;
    });
}

static void DoPairing(int client) {
    if (Seconds() < sNextPairingAllowed) { SendJSON(client, kMsgChallenge, @{ @"error": @"wait a little before asking again" }); return; }
    sNextPairingAllowed = Seconds() + 20;

    NSString *code = [NSString stringWithFormat:@"%06u", arc4random_uniform(1000000)];
    sPairingCancelled = NO;
    if (sTestPrintCode) { printf("PAIRING CODE: %s\n", code.UTF8String); fflush(stdout); }
    else { ShowCodeAlert(code); printf("pairing alert requested\n"); fflush(stdout); }
    SendJSON(client, kMsgChallenge, @{ @"pairing": @"code-shown" });

    double deadline = Seconds() + 120; int wrong = 0;
    while (Seconds() < deadline && wrong < 3 && !sPairingCancelled) {
        uint8_t type = 0; NSData *payload = nil;
        int got = ReadMessage(client, 2, &type, &payload);
        if (got < 0) return;
        if (got == 0 || type != kMsgPairCode) continue;
        NSDictionary *message = [NSJSONSerialization JSONObjectWithData:payload options:0 error:nil];
        if (ConstantTimeEqual(message[@"code"], code)) {
            NSData *secret = RandomBytes(32);
            if (!SaveSecret(secret)) { SendJSON(client, kMsgEvent, @{ @"error": @"could not store the pairing on the phone" }); return; }
            SendJSON(client, kMsgPaired, @{ @"secret": Hex(secret) });
            return;
        }
        wrong++;
        SendJSON(client, kMsgEvent, @{ @"error": @"wrong code", @"attemptsLeft": @(3 - wrong) });
    }
    sNextPairingAllowed = Seconds() + 30;
    SendJSON(client, kMsgEvent, @{ @"error": sPairingCancelled ? @"cancelled on the phone" : @"pairing failed or timed out" });
}

/// YES when the client has proved it holds the pairing secret **and** the daemon has proved the same to the client.
static BOOL Handshake(int client) {
    NSDictionary *hello = ReadJSON(client, 5, kMsgHello);
    NSString *clientNonce = hello[@"cn"];
    if (![clientNonce isKindOfClass:[NSString class]] || clientNonce.length != 32) return NO;

    if ([hello[@"pair"] boolValue]) { DoPairing(client); return NO; }

    NSData *secret = LoadSecret();
    if (!secret) { SendJSON(client, kMsgChallenge, @{ @"error": @"unpaired" }); return NO; }
    NSString *serverNonce = Hex(RandomBytes(16));
    SendJSON(client, kMsgChallenge, @{ @"sn": serverNonce, @"proof": Proof(secret, @"S", clientNonce, serverNonce) });
    NSDictionary *reply = ReadJSON(client, 5, kMsgProof);
    return reply && ConstantTimeEqual(reply[@"proof"], Proof(secret, @"C", clientNonce, serverNonce));
}

int main(int argc, char **argv) {
    @autoreleasepool {
        signal(SIGPIPE, SIG_IGN);
        int port = 9777; double fps = 4, lifetime = 0; BOOL once = NO;
        for (int i = 1; i < argc; i++) {
            if (!strcmp(argv[i], "--port") && i + 1 < argc) port = atoi(argv[++i]);
            else if (!strcmp(argv[i], "--fps") && i + 1 < argc) fps = atof(argv[++i]);
            else if (!strcmp(argv[i], "--lifetime") && i + 1 < argc) lifetime = atof(argv[++i]);   // 0 = until stopped
            else if (!strcmp(argv[i], "--secret-file") && i + 1 < argc) sSecretPath = @(argv[++i]);
            else if (!strcmp(argv[i], "--test-print-code")) sTestPrintCode = YES;
            else if (!strcmp(argv[i], "--unpair")) { unlink(sSecretPath.fileSystemRepresentation); printf("unpaired\n"); return 0; }
            else if (!strcmp(argv[i], "--once")) once = YES;
        }
        ResolveSymbols();

        int listener = socket(AF_INET, SOCK_STREAM, 0);
        int yes = 1; setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
        struct sockaddr_in address = { .sin_len = sizeof(address), .sin_family = AF_INET, .sin_port = htons((uint16_t)port) };
        address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);          // loopback only: never on the network
        if (bind(listener, (struct sockaddr *)&address, sizeof(address)) != 0 || listen(listener, 1) != 0) {
            fprintf(stderr, "albrhi-mirrord: cannot listen on 127.0.0.1:%d (already running, or the Mac test build is using it)\n", port);
            return 1;
        }
        printf("albrhi-mirrord stage 1 listening on 127.0.0.1:%d, %s\n", port, LoadSecret() ? "paired" : "not paired yet");
        fflush(stdout);

        double deadline = lifetime > 0 ? Seconds() + lifetime : 0;
        while (deadline == 0 || Seconds() < deadline) {
            fd_set readable; FD_ZERO(&readable); FD_SET(listener, &readable);
            struct timeval wait = { 1, 0 };
            if (select(listener + 1, &readable, NULL, NULL, &wait) <= 0) continue;
            int client = accept(listener, NULL, NULL);
            if (client < 0) continue;
            @autoreleasepool {
                if (Handshake(client)) {
                    struct timeval none = { 0, 0 }; setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &none, sizeof(none));
                    Serve(client, fps);
                }
            }
            close(client);
            if (once) break;
        }
        printf("albrhi-mirrord: stopped\n");
    }
    return 0;
}
