//
//  Viewer.m  --  the Mac side of stage 1
//
//  Starts the USB tunnel to the phone (`iproxy`) when nothing is listening yet, pairs once (the phone shows a six-digit code,
//  you type it here), then on every later run proves it holds the pairing secret and shows the frames and the device report.
//  `--selftest` and `--selftest-pair` do the same without a window, which is how the wire format and the handshake are tested
//  against the daemon's host build without a phone.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Cocoa/Cocoa.h>
#import <CommonCrypto/CommonHMAC.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <unistd.h>

enum { kMsgInfo = 1, kMsgFrame = 2, kMsgEvent = 3, kMsgCommand = 10,
       kMsgHello = 20, kMsgChallenge = 21, kMsgProof = 22, kMsgPairCode = 23, kMsgPaired = 24 };

// ---- sockets ------------------------------------------------------------------------------------------------------
static BOOL ReadAll(int fd, void *buffer, size_t length) {
    uint8_t *p = buffer;
    while (length) { ssize_t n = recv(fd, p, length, 0); if (n <= 0) return NO; p += n; length -= (size_t)n; }
    return YES;
}

static int Connect(int port) {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in a = { .sin_len = sizeof(a), .sin_family = AF_INET, .sin_port = htons((uint16_t)port) };
    a.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    if (connect(fd, (struct sockaddr *)&a, sizeof(a)) != 0) { close(fd); return -1; }
    return fd;
}

static BOOL SendMessage(int fd, uint8_t type, NSData *payload) {
    uint8_t header[5] = { type, (uint8_t)(payload.length >> 24), (uint8_t)(payload.length >> 16), (uint8_t)(payload.length >> 8), (uint8_t)payload.length };
    return send(fd, header, 5, 0) == 5 && (payload.length == 0 || send(fd, payload.bytes, payload.length, 0) == (ssize_t)payload.length);
}

static BOOL SendJSON(int fd, uint8_t type, NSDictionary *object) {
    return SendMessage(fd, type, [NSJSONSerialization dataWithJSONObject:object options:0 error:nil] ?: [NSData data]);
}

/// Reads one message. Returns NO on a closed connection.
static BOOL ReadMessage(int fd, uint8_t *type, NSData **payload) {
    uint8_t header[5];
    if (!ReadAll(fd, header, 5)) return NO;
    uint32_t length = ((uint32_t)header[1] << 24) | (header[2] << 16) | (header[3] << 8) | header[4];
    if (length > 32u * 1024 * 1024) return NO;
    NSMutableData *body = [NSMutableData dataWithLength:length];
    if (length && !ReadAll(fd, body.mutableBytes, length)) return NO;
    *type = header[0]; *payload = body;
    return YES;
}

static NSDictionary *ReadJSON(int fd, uint8_t *type) {
    NSData *payload = nil;
    if (!ReadMessage(fd, type, &payload)) return nil;
    id object = [NSJSONSerialization JSONObjectWithData:payload options:0 error:nil];
    return [object isKindOfClass:[NSDictionary class]] ? object : @{};
}

// ---- the pairing secret -----------------------------------------------------------------------------------------
static NSString *sSecretFile;

static NSString *Hex(NSData *data) {
    NSMutableString *out = [NSMutableString stringWithCapacity:data.length * 2];
    const uint8_t *p = data.bytes;
    for (NSUInteger i = 0; i < data.length; i++) [out appendFormat:@"%02x", p[i]];
    return out;
}

static NSData *FromHex(NSString *hex) {
    if (hex.length % 2) return nil;
    NSMutableData *out = [NSMutableData dataWithCapacity:hex.length / 2];
    for (NSUInteger i = 0; i < hex.length; i += 2) {
        unsigned value; if (sscanf([hex substringWithRange:NSMakeRange(i, 2)].UTF8String, "%2x", &value) != 1) return nil;
        uint8_t byte = (uint8_t)value; [out appendBytes:&byte length:1];
    }
    return out;
}

static NSString *RandomHex(size_t bytes) {
    NSMutableData *data = [NSMutableData dataWithLength:bytes];
    arc4random_buf(data.mutableBytes, bytes);
    return Hex(data);
}

static NSData *LoadSecret(void) {
    NSString *text = [[NSString stringWithContentsOfFile:sSecretFile encoding:NSUTF8StringEncoding error:nil]
                      stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSData *data = text.length ? FromHex(text) : nil;
    return data.length == 32 ? data : nil;
}

static BOOL SaveSecret(NSData *secret) {
    [[NSFileManager defaultManager] createDirectoryAtPath:[sSecretFile stringByDeletingLastPathComponent] withIntermediateDirectories:YES
                                               attributes:@{ NSFilePosixPermissions: @0700 } error:nil];
    if (![Hex(secret) writeToFile:sSecretFile atomically:YES encoding:NSUTF8StringEncoding error:nil]) return NO;
    chmod(sSecretFile.fileSystemRepresentation, 0600);
    return YES;
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

/// nil when both sides proved they hold the secret; otherwise what went wrong (the string "unpaired" means the phone has no pairing).
static NSString *Handshake(int fd, NSData *secret) {
    NSString *cn = RandomHex(16);
    if (!SendJSON(fd, kMsgHello, @{ @"v": @1, @"cn": cn })) return @"the connection closed before the phone answered";
    uint8_t type = 0; NSDictionary *challenge = ReadJSON(fd, &type);
    if (!challenge || type != kMsgChallenge) return @"the phone did not answer (is albrhi-mirror installed there, and the phone plugged in and trusted?)";
    if (challenge[@"error"]) return challenge[@"error"];
    NSString *sn = challenge[@"sn"];
    if (![sn isKindOfClass:[NSString class]] || !ConstantTimeEqual(challenge[@"proof"], Proof(secret, @"S", cn, sn)))
        return @"whatever answered did not prove it knows the pairing (a different phone, or something else is listening on the port)";
    if (!SendJSON(fd, kMsgProof, @{ @"proof": Proof(secret, @"C", cn, sn) })) return @"the connection closed during the handshake";
    return nil;
}

/// Pairs with the daemon on `fd`. `askCode` shows what the phone displays and returns what the person typed (nil to give up).
/// nil on success, otherwise what went wrong.
static NSString *Pair(int fd, NSString *(^askCode)(NSString *note)) {
    if (!SendJSON(fd, kMsgHello, @{ @"v": @1, @"cn": RandomHex(16), @"pair": @YES })) return @"the connection closed before the phone answered";
    uint8_t type = 0; NSDictionary *reply = ReadJSON(fd, &type);
    if (!reply || type != kMsgChallenge) return @"the phone did not answer (is albrhi-mirror installed there, and the phone plugged in and trusted?)";
    if (reply[@"error"]) return reply[@"error"];
    NSString *note = @"The iPhone is showing a six-digit code.";
    while (YES) {
        NSString *code = askCode(note);
        if (!code.length) return @"pairing cancelled";
        SendJSON(fd, kMsgPairCode, @{ @"code": code });
        NSDictionary *answer = ReadJSON(fd, &type);
        if (!answer) return @"the connection closed (three wrong codes, or the phone cancelled)";
        if (type == kMsgPaired) {
            NSData *secret = FromHex(answer[@"secret"]);
            if (secret.length != 32 || !SaveSecret(secret)) return @"the phone paired but the secret could not be stored on this Mac";
            return nil;
        }
        if (answer[@"error"]) {
            if (![answer[@"attemptsLeft"] intValue]) return answer[@"error"];
            note = [NSString stringWithFormat:@"%@ — %@ attempts left.", answer[@"error"], answer[@"attemptsLeft"]];
        }
    }
}

// ---- the USB tunnel -----------------------------------------------------------------------------------------------
static NSTask *sTunnel;

/// Starts `iproxy` for the port when nothing is listening yet. Returns a note for the status line when it cannot.
static NSString *EnsureTunnel(int port, BOOL allowSpawn) {
    int probe = Connect(port);
    if (probe >= 0) { close(probe); return nil; }
    if (!allowSpawn) return nil;
    NSString *path = nil;
    for (NSString *candidate in @[ @"/opt/homebrew/bin/iproxy", @"/usr/local/bin/iproxy" ])
        if ([[NSFileManager defaultManager] isExecutableFileAtPath:candidate]) { path = candidate; break; }
    if (!path) return @"iproxy is not installed (brew install libusbmuxd)";
    if (sTunnel.isRunning) return nil;
    sTunnel = [[NSTask alloc] init];
    sTunnel.executableURL = [NSURL fileURLWithPath:path];
    sTunnel.arguments = @[ [NSString stringWithFormat:@"%d:%d", port, port] ];
    sTunnel.standardOutput = [NSFileHandle fileHandleWithNullDevice];
    sTunnel.standardError = [NSFileHandle fileHandleWithNullDevice];
    NSError *error = nil;
    if (![sTunnel launchAndReturnError:&error]) { sTunnel = nil; return [NSString stringWithFormat:@"could not start iproxy: %@", error.localizedDescription]; }
    usleep(600000);
    return nil;
}

// ---- reporting ------------------------------------------------------------------------------------------------------
static NSString *DescribeInfo(NSDictionary *info) {
    NSMutableString *s = [NSMutableString string];
    NSDictionary *live = info[@"live"];
    [s appendFormat:@"iOS %@ · %@ · %@ · root uid %@\n", info[@"ios"], info[@"machine"], info[@"screen"], info[@"uid"]];
    [s appendFormat:@"LOCK STATE: %@\n", info[@"lock"]];
    for (NSString *line in info[@"symbols"]) [s appendFormat:@"  %@\n", line];
    if (info[@"renderFrameCounter"]) [s appendFormat:@"  render frame counter: %@\n", info[@"renderFrameCounter"]];
    if (live) [s appendFormat:@"sent %@ · picture differed in %@ · last capture %@ ms · non-black share %.0f%%\n",
               live[@"framesSent"], live[@"framesThatDiffered"], live[@"lastCaptureMs"], [live[@"nonBlackShare"] doubleValue] * 100];
    return s;
}

// ---- the window ---------------------------------------------------------------------------------------------------
@interface Viewer : NSObject <NSApplicationDelegate>
@property (nonatomic) NSWindow *window;
@property (nonatomic) NSImageView *imageView;
@property (nonatomic) NSTextField *status;
@property (nonatomic) int port;
@property (nonatomic) BOOL spawnTunnel;
@end

@implementation Viewer
- (void)applicationDidFinishLaunching:(NSNotification *)n {
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 760, 760)
                                              styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable
                                                backing:NSBackingStoreBuffered defer:NO];
    self.window.title = @"Albrhi Mirror — stage 1 (probe)";
    NSView *content = self.window.contentView;
    self.imageView = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 150, 760, 610)];
    self.imageView.imageScaling = NSImageScaleProportionallyUpOrDown;
    self.imageView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.status = [NSTextField labelWithString:@"starting…"];
    self.status.frame = NSMakeRect(8, 4, 744, 142);
    self.status.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
    self.status.maximumNumberOfLines = 0;
    self.status.autoresizingMask = NSViewWidthSizable;
    [content addSubview:self.imageView]; [content addSubview:self.status];
    [self.window center]; [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    [NSThread detachNewThreadSelector:@selector(run) toTarget:self withObject:nil];
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)a { return YES; }
- (void)applicationWillTerminate:(NSNotification *)n { if (sTunnel.isRunning) [sTunnel terminate]; }

- (void)show:(NSString *)text { dispatch_async(dispatch_get_main_queue(), ^{ self.status.stringValue = text; }); }

/// The code prompt, from the connection thread (the modal runs on the main thread).
- (NSString *)askCode:(NSString *)note {
    __block NSString *answer = nil;
    dispatch_sync(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Pair with the iPhone";
        alert.informativeText = [note stringByAppendingString:@"\nType it here. This is asked once; after it, opening the viewer is enough."];
        NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
        alert.accessoryView = field;
        [alert addButtonWithTitle:@"Pair"]; [alert addButtonWithTitle:@"Cancel"];
        alert.window.initialFirstResponder = field;
        if ([alert runModal] == NSAlertFirstButtonReturn) answer = [field.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    });
    return answer;
}

- (void)run {
    while (YES) {
        NSString *tunnelNote = EnsureTunnel(self.port, self.spawnTunnel);
        int fd = Connect(self.port);
        if (fd < 0) { [self show:[NSString stringWithFormat:@"No tunnel to the phone on 127.0.0.1:%d.%@", self.port, tunnelNote ? [@"\n" stringByAppendingString:tunnelNote] : @"\nIs the phone plugged in and trusted?"]]; sleep(2); continue; }

        NSData *secret = LoadSecret();
        if (!secret) {
            [self show:@"Not paired yet. Asking the phone to show a code…"];
            NSString *error = Pair(fd, ^NSString *(NSString *note) { return [self askCode:note]; });
            close(fd);
            if (error) { [self show:[@"Pairing did not finish: " stringByAppendingString:error]]; sleep(3); }
            continue;
        }

        NSString *error = Handshake(fd, secret);
        if (error) {
            close(fd);
            if ([error isEqual:@"unpaired"]) { unlink(sSecretFile.fileSystemRepresentation); error = @"the phone has no pairing any more (reinstalled or reset): pairing again"; }
            [self show:error]; sleep(2); continue;
        }

        NSString *report = @""; NSString *frameLine = @"";
        uint8_t type; NSData *payload;
        while (ReadMessage(fd, &type, &payload)) {
            if (type == kMsgInfo) {
                report = DescribeInfo([NSJSONSerialization JSONObjectWithData:payload options:0 error:nil] ?: @{});
            } else if (type == kMsgEvent) {
                NSDictionary *e = [NSJSONSerialization JSONObjectWithData:payload options:0 error:nil];
                frameLine = [NSString stringWithFormat:@"CAPTURE ERROR: %@ (lock: %@)\n", e[@"error"], e[@"lock"]];
            } else if (type == kMsgFrame && payload.length > 20) {
                const uint32_t *f = payload.bytes; uint32_t flags = ntohl(f[4]);
                NSImage *image = [[NSImage alloc] initWithData:[payload subdataWithRange:NSMakeRange(20, payload.length - 20)]];
                frameLine = [NSString stringWithFormat:@"frame %ux%u · counter %u · %@%@\n", ntohl(f[0]), ntohl(f[1]), ntohl(f[2]),
                             (flags & 1) ? @"picture CHANGED" : @"same picture as the last frame", (flags & 2) ? @" · (almost all black)" : @""];
                dispatch_async(dispatch_get_main_queue(), ^{ if (image) self.imageView.image = image; });
            }
            [self show:[frameLine stringByAppendingString:report]];
        }
        close(fd);
        [self show:@"connection closed; retrying…"];
        sleep(1);
    }
}
@end

// ---- entry ----------------------------------------------------------------------------------------------------------
int main(int argc, char **argv) {
    @autoreleasepool {
        int port = 9777; BOOL selftest = NO, selftestPair = NO, tunnel = YES; const char *saveTo = "/tmp/albrhi-mirror-frame.jpg";
        sSecretFile = [@"~/Library/Application Support/AlbrhiMirror/pairing" stringByExpandingTildeInPath];
        for (int i = 1; i < argc; i++) {
            if (!strcmp(argv[i], "--port") && i + 1 < argc) port = atoi(argv[++i]);
            else if (!strcmp(argv[i], "--secret-file") && i + 1 < argc) sSecretFile = @(argv[++i]);
            else if (!strcmp(argv[i], "--save") && i + 1 < argc) saveTo = argv[++i];
            else if (!strcmp(argv[i], "--no-iproxy")) tunnel = NO;
            else if (!strcmp(argv[i], "--selftest")) selftest = YES;
            else if (!strcmp(argv[i], "--selftest-pair")) selftestPair = YES;
            else if (!strcmp(argv[i], "--forget")) { unlink(sSecretFile.fileSystemRepresentation); printf("forgot the pairing on this Mac\n"); return 0; }
        }

        if (selftestPair) {                       // reads the code the daemon printed from stdin
            int fd = Connect(port);
            if (fd < 0) { fprintf(stderr, "no daemon on 127.0.0.1:%d\n", port); return 2; }
            NSString *error = Pair(fd, ^NSString *(NSString *note) {
                char line[64] = {0}; if (!fgets(line, sizeof(line), stdin)) return nil;
                return [@(line) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            });
            printf("pair: %s\n", error ? error.UTF8String : "ok, secret stored");
            return error ? 1 : 0;
        }

        if (selftest) {
            int fd = Connect(port);
            if (fd < 0) { fprintf(stderr, "no daemon on 127.0.0.1:%d\n", port); return 2; }
            NSData *secret = LoadSecret();
            NSString *error = secret ? Handshake(fd, secret) : @"no secret on this Mac";
            if (error) { printf("handshake: %s\n", error.UTF8String); return 3; }
            int frames = 0, infos = 0; uint8_t type; NSData *payload; NSDictionary *last = nil; BOOL saved = NO; uint32_t differing = 0, lastPrint = 0;
            while (frames < 6 && ReadMessage(fd, &type, &payload)) {
                if (type == kMsgInfo) { infos++; last = [NSJSONSerialization JSONObjectWithData:payload options:0 error:nil]; }
                else if (type == kMsgFrame && payload.length > 20) {
                    const uint32_t *f = payload.bytes; frames++;
                    if (ntohl(f[3]) != lastPrint) differing++;
                    lastPrint = ntohl(f[3]);
                    if (!saved) { [[payload subdataWithRange:NSMakeRange(20, payload.length - 20)] writeToFile:@(saveTo) atomically:YES]; saved = YES; }
                }
            }
            printf("selftest: handshake ok, %d frames, %d info messages, %u distinct pictures; first frame written to %s\n%s", frames, infos, differing, saveTo,
                   DescribeInfo(last ?: @{}).UTF8String);
            return frames >= 3 ? 0 : 1;
        }

        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        Viewer *viewer = [[Viewer alloc] init]; viewer.port = port; viewer.spawnTunnel = tunnel;
        app.delegate = viewer;
        [app run];
    }
    return 0;
}
