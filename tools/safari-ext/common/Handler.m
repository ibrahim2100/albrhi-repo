//
//  Handler.m
//  Albrhi — Open in app (Safari web extension)
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// Safari needs an executable and a principal class even for an extension that is only a script; this is the whole of the native side. The
/// script runs inside the web page and sends nothing back, so the request is simply completed.
@interface AlbrhiLinksHandler : NSObject <NSExtensionRequestHandling>
@end

@implementation AlbrhiLinksHandler
- (void)beginRequestWithExtensionContext:(NSExtensionContext *)context {
    [context completeRequestReturningItems:@[] completionHandler:nil];
}
@end
