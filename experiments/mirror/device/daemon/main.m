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
//    * It starts by itself (a LaunchDaemon) and sits idle, **switched off**, until the person turns it on in the Albrhi
//      Mirror app. Off, it answers every connection with one word and nothing else.
//    * **Pairing, once, started on the phone**: the app asks the daemon to open a pairing window and shows the six-digit
//      code it gets back. A Mac can only pair while that window is open (120 seconds, three wrong codes), so the one thing
//      an app on the phone cannot do is start a pairing by itself. The daemon then hands over a random 32-byte secret.
//    * **Every later session**: each side sends a random nonce and proves it knows the secret with HMAC-SHA256 over both
//      nonces and its role, so the Mac also knows it is talking to the daemon and not to an app squatting on the port.
//    * The app and the daemon talk over a Unix socket owned by mobile, mode 0600; the peer's uid is checked as well.
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
#include <sys/un.h>
#include <errno.h>
#import <CommonCrypto/CommonHMAC.h>

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

static BOOL SessionAllowed(void);

static void Serve(int client, double fps) {
    SendJSON(client, kMsgInfo, DeviceInfo());
    uint32_t previous = 0; BOOL first = YES; double lastInfo = 0; NSUInteger sent = 0, changed = 0;
    double interval = 1.0 / (fps > 0 ? fps : 4);

    while (SessionAllowed()) {
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

// ---- state, on disk and in memory ------------------------------------------------------------------------------------
//
//  /var/mobile/Library/AlbrhiMirror/   (root 0755)
//      pairing      the shared secret, root 0600: only this daemon reads it
//      enabled      exists = mirroring is switched on (off until the person turns it on in the app)
//      control.sock the control socket, owned by mobile 0600: the app talks to the daemon here
//
static NSString *sDir = @"/var/mobile/Library/AlbrhiMirror";
static NSString *sSecretPath, *sEnabledPath, *sControlPath;

static NSLock *sLock;
static BOOL sEnabled;
static NSString *sPairCode;          // set while a pairing window is open
static double sPairDeadline;
static int sPairAttempts;
static BOOL sPairingBusy;            // a Mac is in the middle of typing the code
static BOOL sSessionActive;
static BOOL sKickSession;

static void SetPaths(NSString *dir) {
    sDir = dir;
    sSecretPath = [dir stringByAppendingPathComponent:@"pairing"];
    sEnabledPath = [dir stringByAppendingPathComponent:@"enabled"];
    sControlPath = [dir stringByAppendingPathComponent:@"control.sock"];
}

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

static BOOL Enabled(void) { [sLock lock]; BOOL on = sEnabled; [sLock unlock]; return on; }

/// Whether the running session may go on: switched on, and not told to end (unpairing or switching off ends it).
static BOOL SessionAllowed(void) { [sLock lock]; BOOL ok = sEnabled && !sKickSession; [sLock unlock]; return ok; }

static void CloseWindowLocked(void) { sPairCode = nil; sPairDeadline = 0; sPairAttempts = 0; }

static void SetEnabled(BOOL on) {
    [sLock lock];
    sEnabled = on;
    if (on) [@"" writeToFile:sEnabledPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    else { unlink(sEnabledPath.fileSystemRepresentation); CloseWindowLocked(); sKickSession = YES; }
    if (on) sKickSession = NO;
    [sLock unlock];
}

// ---- the control socket (the app talks to the daemon here) --------------------------------------------------------------
static NSDictionary *StatusLocked(void) {
    NSMutableDictionary *status = [@{
        @"enabled": @(sEnabled), @"paired": @((BOOL)(LoadSecret() != nil)), @"session": @(sSessionActive), @"lock": LockText(),
        @"daemon": @"albrhi-mirrord stage 1",
    } mutableCopy];
    if (sPairCode && Seconds() < sPairDeadline) {
        status[@"pairing"] = @{ @"code": sPairCode, @"secondsLeft": @((int)(sPairDeadline - Seconds())), @"attemptsLeft": @(sPairAttempts) };
    }
    return status;
}

static NSDictionary *HandleControl(NSDictionary *request) {
    NSString *command = request[@"cmd"];
    if ([command isEqual:@"status"]) {
        [sLock lock]; NSDictionary *status = StatusLocked(); [sLock unlock]; return status;
    }
    if ([command isEqual:@"enable"] || [command isEqual:@"disable"]) { SetEnabled([command isEqual:@"enable"]); }
    else if ([command isEqual:@"pair-start"]) {
        [sLock lock];
        if (!sEnabled) { [sLock unlock]; return @{ @"error": @"switch mirroring on first" }; }
        sPairCode = [NSString stringWithFormat:@"%06u", arc4random_uniform(1000000)];
        sPairDeadline = Seconds() + 120; sPairAttempts = 3;
        [sLock unlock];
    }
    else if ([command isEqual:@"pair-cancel"]) { [sLock lock]; CloseWindowLocked(); [sLock unlock]; }
    else if ([command isEqual:@"unpair"]) {
        unlink(sSecretPath.fileSystemRepresentation);
        [sLock lock]; sKickSession = YES; CloseWindowLocked(); [sLock unlock];
    }
    else return @{ @"error": @"unknown command" };
    [sLock lock]; NSDictionary *status = StatusLocked(); [sLock unlock];
    return status;
}

static void ServeControl(int listener) {
    while (YES) {
        int fd = accept(listener, NULL, NULL);
        if (fd < 0) { if (errno == EINTR) continue; return; }
        @autoreleasepool {
            // Who is asking: the socket is 0600 and owned by mobile, and this is the second lock on that door.
            uid_t uid = (uid_t)-1; gid_t gid = 0;
            if (getpeereid(fd, &uid, &gid) == 0 && (uid == 0 || uid == 501 || uid == getuid())) {
                struct timeval limit = { 2, 0 }; setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &limit, sizeof(limit));
                char buffer[1024]; ssize_t n = recv(fd, buffer, sizeof(buffer) - 1, 0);
                NSDictionary *request = nil;
                if (n > 0) { id object = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:buffer length:(NSUInteger)n] options:0 error:nil];
                             if ([object isKindOfClass:[NSDictionary class]]) request = object; }
                NSDictionary *reply = request ? HandleControl(request) : @{ @"error": @"expected one JSON object" };
                NSMutableData *line = [[NSJSONSerialization dataWithJSONObject:reply options:0 error:nil] mutableCopy];
                [line appendBytes:"\n" length:1];
                SendAll(fd, line.bytes, line.length);
            }
        }
        close(fd);
    }
}

static int OpenControlSocket(void) {
    mkdir(sDir.fileSystemRepresentation, 0755);
    unlink(sControlPath.fileSystemRepresentation);
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    struct sockaddr_un address = { .sun_family = AF_UNIX };
    if (sControlPath.length >= sizeof(address.sun_path)) return -1;
    strlcpy(address.sun_path, sControlPath.fileSystemRepresentation, sizeof(address.sun_path));
    address.sun_len = (uint8_t)SUN_LEN(&address);
    if (bind(fd, (struct sockaddr *)&address, sizeof(address)) != 0 || listen(fd, 4) != 0) { close(fd); return -1; }
    chmod(sControlPath.fileSystemRepresentation, 0600);
#if TARGET_OS_IPHONE
    chown(sControlPath.fileSystemRepresentation, 501, 501);       // mobile: the app runs as mobile
#endif
    return fd;
}

/// `albrhi-mirrord --control <cmd>`: the same conversation the app has, from a terminal.
static int RunControlClient(const char *command) {
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    struct sockaddr_un address = { .sun_family = AF_UNIX };
    strlcpy(address.sun_path, sControlPath.fileSystemRepresentation, sizeof(address.sun_path));
    address.sun_len = (uint8_t)SUN_LEN(&address);
    if (connect(fd, (struct sockaddr *)&address, sizeof(address)) != 0) { fprintf(stderr, "no daemon on %s\n", sControlPath.UTF8String); return 2; }
    NSData *request = [NSJSONSerialization dataWithJSONObject:@{ @"cmd": @(command) } options:0 error:nil];
    SendAll(fd, request.bytes, request.length);
    char buffer[2048]; ssize_t n = recv(fd, buffer, sizeof(buffer) - 1, 0);
    if (n > 0) { buffer[n] = 0; fputs(buffer, stdout); }
    return 0;
}

// ---- the network side: handshake and pairing ----------------------------------------------------------------------------
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

/// A Mac typing the code that the app is showing. The window is opened only by the person, on the phone, with the app.
static void DoPairing(int client) {
    [sLock lock];
    BOOL open = sPairCode && Seconds() < sPairDeadline && sPairAttempts > 0 && !sPairingBusy;
    if (open) sPairingBusy = YES;
    [sLock unlock];
    if (!open) { SendJSON(client, kMsgChallenge, @{ @"error": @"pairing-closed" }); return; }
    SendJSON(client, kMsgChallenge, @{ @"pairing": @"code-shown" });

    BOOL paired = NO;
    while (YES) {
        [sLock lock]; NSString *code = sPairCode; double deadline = sPairDeadline; int left = sPairAttempts; [sLock unlock];
        if (!code || Seconds() >= deadline || left <= 0 || !Enabled()) break;
        uint8_t type = 0; NSData *payload = nil;
        int got = ReadMessage(client, 2, &type, &payload);
        if (got < 0) break;
        if (got == 0 || type != kMsgPairCode) continue;
        NSDictionary *message = [NSJSONSerialization JSONObjectWithData:payload options:0 error:nil];
        if (ConstantTimeEqual(message[@"code"], code)) {
            NSData *secret = RandomBytes(32);
            if (!SaveSecret(secret)) { SendJSON(client, kMsgEvent, @{ @"error": @"could not store the pairing on the phone" }); break; }
            SendJSON(client, kMsgPaired, @{ @"secret": Hex(secret) });
            paired = YES;
            break;
        }
        [sLock lock]; left = --sPairAttempts; [sLock unlock];
        SendJSON(client, kMsgEvent, @{ @"error": @"wrong code", @"attemptsLeft": @(left) });
    }
    [sLock lock]; sPairingBusy = NO; if (paired || sPairAttempts <= 0) CloseWindowLocked(); [sLock unlock];
    if (!paired) SendJSON(client, kMsgEvent, @{ @"error": @"pairing failed or timed out" });
}

/// YES when the client has proved it holds the pairing secret **and** the daemon has proved the same to the client.
static BOOL Handshake(int client) {
    NSDictionary *hello = ReadJSON(client, 5, kMsgHello);
    NSString *clientNonce = hello[@"cn"];
    if (![clientNonce isKindOfClass:[NSString class]] || clientNonce.length != 32) return NO;

    if (!Enabled()) { SendJSON(client, kMsgChallenge, @{ @"error": @"disabled" }); return NO; }
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
        sLock = [[NSLock alloc] init];
        SetPaths(sDir);
        int port = 9777; double fps = 4, lifetime = 0; BOOL once = NO; const char *control = NULL;
        for (int i = 1; i < argc; i++) {
            if (!strcmp(argv[i], "--port") && i + 1 < argc) port = atoi(argv[++i]);
            else if (!strcmp(argv[i], "--fps") && i + 1 < argc) fps = atof(argv[++i]);
            else if (!strcmp(argv[i], "--lifetime") && i + 1 < argc) lifetime = atof(argv[++i]);   // 0 = until stopped
            else if (!strcmp(argv[i], "--state-dir") && i + 1 < argc) SetPaths(@(argv[++i]));
            else if (!strcmp(argv[i], "--control") && i + 1 < argc) control = argv[++i];
            else if (!strcmp(argv[i], "--once")) once = YES;
        }
        if (control) return RunControlClient(control);
        ResolveSymbols();

        // Off until the person turns it on in the app: a fresh install must not serve anything.
        sEnabled = [[NSFileManager defaultManager] fileExistsAtPath:sEnabledPath];

        int controlListener = OpenControlSocket();
        if (controlListener < 0) { fprintf(stderr, "albrhi-mirrord: cannot open the control socket %s\n", sControlPath.UTF8String); return 1; }
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{ ServeControl(controlListener); });

        int listener = socket(AF_INET, SOCK_STREAM, 0);
        int yes = 1; setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
        struct sockaddr_in address = { .sin_len = sizeof(address), .sin_family = AF_INET, .sin_port = htons((uint16_t)port) };
        address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);          // loopback only: never on the network
        if (bind(listener, (struct sockaddr *)&address, sizeof(address)) != 0 || listen(listener, 1) != 0) {
            fprintf(stderr, "albrhi-mirrord: cannot listen on 127.0.0.1:%d (already running, or the Mac test build is using it)\n", port);
            return 1;
        }
        printf("albrhi-mirrord stage 1 listening on 127.0.0.1:%d; %s, %s\n", port, sEnabled ? "switched on" : "switched OFF", LoadSecret() ? "paired" : "not paired yet");
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
                    [sLock lock]; sSessionActive = YES; sKickSession = NO; [sLock unlock];
                    Serve(client, fps);
                    [sLock lock]; sSessionActive = NO; [sLock unlock];
                }
            }
            close(client);
            if (once) break;
        }
        printf("albrhi-mirrord: stopped\n");
    }
    return 0;
}
