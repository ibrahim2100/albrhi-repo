//
//  SCITTBudget.x
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <string.h>
#import "SCITTBudget.h"
#import "../../Prefs.h"
#import "../../SCILog.h"
#import "shared/src/SCIWatchBudget.h"
#import "shared/src/SCIKVC.h"

///
/// **What counts as "a video watched".** `AWEFeedCellViewController` is the controller TikTok keeps for each page of the feed; its `-viewDidAppear:`
/// fires when that page becomes the one on screen (the hierarchy shows the others as "disappeared"). The video's own id is the key, so a page that
/// appears twice in a row (a pull, a rotation, coming back from a comment sheet) is one video, and the same video seen again after another is a new look.
/// A page TikTok only *prepares* ahead of the swipe does not appear, so the neighbours are not counted.
///
/// The limits live in two ordinary choices in Settings (videos, minutes), 0 = off. With both off this installs nothing and counts nothing.
///

static NSUInteger sciBudgetAppeared = 0, sciBudgetCounted = 0, sciBudgetNoKey = 0;
static NSString *sciBudgetState = nil;

static NSString *SCITTBudgetKeyOf(id controller) {
    id model = SCISafeValueForKey(controller, @"model");
    id identifier = SCISafeValueForKey(model, @"itemID");
    if ([identifier isKindOfClass:[NSString class]] && [(NSString *)identifier length]) return identifier;
    if ([identifier isKindOfClass:[NSNumber class]]) return [(NSNumber *)identifier stringValue];
    return nil;
}

%group SCITTBudgetGroup
%hook AWEFeedCellViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    sciBudgetAppeared++;
    NSString *key = SCITTBudgetKeyOf(self);
    if (!key) { sciBudgetNoKey++; return; }
    sciBudgetCounted++;
    SCIWatchBudgetNoteVideo(key);
}

%end
%end

NSString *SCITTBudgetReport(void) {
    return [NSString stringWithFormat:@"%@; pages appeared %lu, counted %lu, without an id %lu; %@",
            sciBudgetState ?: @"not installed", (unsigned long)sciBudgetAppeared, (unsigned long)sciBudgetCounted, (unsigned long)sciBudgetNoKey,
            SCIWatchBudgetReport()];
}

void SCITTInstallBudget(void) {
    // The limits are read each time they are needed, so a change in Settings applies at once without a relaunch.
    SCIWatchBudgetSetProvider(^SCIWatchLimits{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        return (SCIWatchLimits){[defaults integerForKey:SCIPrefBudgetVideos], [defaults integerForKey:SCIPrefBudgetMinutes]};
    });

    Class controller = NSClassFromString(@"AWEFeedCellViewController");
    Method method = controller ? class_getInstanceMethod(controller, @selector(viewDidAppear:)) : NULL;
    const char *types = method ? method_getTypeEncoding(method) : NULL;
    if (!types || strcmp(types, "v20@0:8B16") != 0) {
        sciBudgetState = controller ? @"stood down: -viewDidAppear: differently typed" : @"stood down: AWEFeedCellViewController absent (minutes still count)";
        SCILogV(@"[Budget] %@", sciBudgetState);
        return;
    }
    %init(SCITTBudgetGroup);
    sciBudgetState = @"installed: AWEFeedCellViewController -viewDidAppear:";
    SCILogV(@"[Budget] %@", sciBudgetState);
}
