//
//  SCIReceipt.x
//  Albrhi for Instagram
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>
#import "SCIReceipt.h"

%group SCIReceipt
%hook NSBundle

- (NSURL *)appStoreReceiptURL {
    NSURL *url = %orig;
    if (self != [NSBundle mainBundle]) return url;
    return SCIReceiptRewritten(url);
}

%end
%end

void SCIReceiptInstall(void) {
    %init(SCIReceipt);
}
