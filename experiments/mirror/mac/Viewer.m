//
//  Viewer.m  --  the Mac side of stage 1
//
//  Connects to 127.0.0.1:<port> (the USB tunnel to the phone's albrhi-mirrord), shows the frames and the device report.
//  `--selftest` does the same without a window: it receives a few frames, writes the first to a file and prints what the
//  daemon reported, which is how the wire format is tested without a phone.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Cocoa/Cocoa.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

enum { kMsgInfo = 1, kMsgFrame = 2, kMsgEvent = 3, kMsgCommand = 10, kMsgAuth = 20 };

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

static BOOL SendAuth(int fd, NSString *token) {
    NSData *body = [token dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t header[5] = { kMsgAuth, 0, 0, 0, (uint8_t)body.length };
    return send(fd, header, 5, 0) == 5 && send(fd, body.bytes, body.length, 0) == (ssize_t)body.length;
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

@interface Viewer : NSObject <NSApplicationDelegate>
@property (nonatomic) NSWindow *window;
@property (nonatomic) NSImageView *imageView;
@property (nonatomic) NSTextField *status;
@property (nonatomic) int port;
@property (nonatomic, copy) NSString *token;
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
    self.status = [NSTextField labelWithString:@"connecting…"];
    self.status.frame = NSMakeRect(8, 4, 744, 142);
    self.status.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
    self.status.maximumNumberOfLines = 0;
    self.status.autoresizingMask = NSViewWidthSizable;
    [content addSubview:self.imageView]; [content addSubview:self.status];
    [self.window center]; [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    if (!self.token.length) {
        // The daemon prints a token when it starts; without it the daemon sends nothing.
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Token";
        alert.informativeText = @"Type the TOKEN that albrhi-mirrord printed on the phone.";
        NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 280, 24)];
        alert.accessoryView = field;
        [alert addButtonWithTitle:@"Connect"]; [alert addButtonWithTitle:@"Quit"];
        alert.window.initialFirstResponder = field;
        if ([alert runModal] != NSAlertFirstButtonReturn) { [NSApp terminate:nil]; return; }
        self.token = [field.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    [NSThread detachNewThreadSelector:@selector(run) toTarget:self withObject:nil];
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)a { return YES; }

- (void)show:(NSString *)text { dispatch_async(dispatch_get_main_queue(), ^{ self.status.stringValue = text; }); }

- (void)run {
    while (YES) {
        int fd = Connect(self.port);
        if (fd < 0) { [self show:[NSString stringWithFormat:@"No daemon on 127.0.0.1:%d.\nStart `iproxy %d %d` and run albrhi-mirrord on the phone.", self.port, self.port, self.port]]; sleep(2); continue; }
        if (!SendAuth(fd, self.token)) { close(fd); sleep(1); continue; }
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
        [self show:@"connection closed (a wrong token is closed without a reply); retrying…"];
        sleep(1);
    }
}
@end

int main(int argc, char **argv) {
    @autoreleasepool {
        int port = 9777; BOOL selftest = NO; const char *saveTo = "/tmp/albrhi-mirror-frame.jpg"; NSString *token = nil;
        for (int i = 1; i < argc; i++) {
            if (!strcmp(argv[i], "--port") && i + 1 < argc) port = atoi(argv[++i]);
            else if (!strcmp(argv[i], "--token") && i + 1 < argc) token = @(argv[++i]);
            else if (!strcmp(argv[i], "--selftest")) selftest = YES;
            else if (!strcmp(argv[i], "--save") && i + 1 < argc) saveTo = argv[++i];
        }
        if (selftest) {
            int fd = Connect(port);
            if (fd < 0) { fprintf(stderr, "no daemon on 127.0.0.1:%d\n", port); return 2; }
            if (!token || !SendAuth(fd, token)) { fprintf(stderr, "selftest needs --token\n"); return 2; }
            int frames = 0, infos = 0; uint8_t type; NSData *payload; NSDictionary *last = nil; BOOL saved = NO; uint32_t firstPrint = 0, differing = 0, lastPrint = 0;
            while (frames < 6 && ReadMessage(fd, &type, &payload)) {
                if (type == kMsgInfo) { infos++; last = [NSJSONSerialization JSONObjectWithData:payload options:0 error:nil]; }
                else if (type == kMsgFrame && payload.length > 20) {
                    const uint32_t *f = payload.bytes; frames++;
                    if (frames == 1) firstPrint = ntohl(f[3]);
                    if (ntohl(f[3]) != lastPrint) differing++;
                    lastPrint = ntohl(f[3]);
                    if (!saved) { [[payload subdataWithRange:NSMakeRange(20, payload.length - 20)] writeToFile:@(saveTo) atomically:YES]; saved = YES; }
                }
            }
            printf("selftest: %d frames, %d info messages, %u distinct pictures; first frame written to %s\n%s", frames, infos, differing, saveTo,
                   DescribeInfo(last ?: @{}).UTF8String);
            (void)firstPrint;
            return frames >= 3 ? 0 : 1;
        }
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        Viewer *viewer = [[Viewer alloc] init]; viewer.port = port; viewer.token = token;
        app.delegate = viewer;
        [app run];
    }
    return 0;
}
