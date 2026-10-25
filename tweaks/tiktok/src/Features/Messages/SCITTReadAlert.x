//
//  SCITTReadAlert.x
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "SCITTReadAlert.h"
#import "../../Prefs.h"
#import "../../SCILog.h"
#import "../../Localization/SCILocalize.h"
#import "../../UI/SCITTToast.h"

///
/// **"Somebody read what you sent."**
///
/// TikTok keeps, per conversation, where each other person has read up to (`AWEIMMessageConversation -uidParticipantReadIndexDict`, a dictionary of
/// user id to read position) and says so when it changes (`-p_notifyParticipantReadIndexDidUpdate`, `v16@0:8`) -- both confirmed in 46.4.0's own
/// binary. This compares each person's position with the one it held last time and tells you when somebody's moved *forward*.
///
/// **The first look at a conversation is a baseline and says nothing.** The same notification fires when a chat is loaded and when old state is
/// replayed; an alert for each of those would be a banner every time an old chat opened. Only a position that rises after it was first seen counts.
///
/// **The dictionary is read from its ivar, not through its getter.** The getter has a dispatch queue beside it (`_uidParticipantReadIndexQueue`);
/// if this notification is delivered from inside that queue, a getter that synchronises on it would wait for itself. An ivar read waits for
/// nothing. The comparison itself then runs on the main queue, away from whoever called.
///
/// Your own position is left out (`-currentUserID`): reading a chat moves yours, and that is not news.
///

@interface AWEIMMessageConversation : NSObject
@end

static NSMutableDictionary<NSString *, NSDictionary *> *sciReadBaseline = nil;
static NSMutableDictionary<NSString *, NSDate *> *sciReadLastAlert = nil;
static NSUInteger sciReadNotifications = 0, sciReadAlerts = 0, sciReadBaselines = 0;
static NSString *sciReadState = nil;

static NSString *SCITTString(id object, const char *selector) {
    SEL sel = sel_registerName(selector);
    if (![object respondsToSelector:sel]) return nil;
    id value = ((id (*)(id, SEL))objc_msgSend)(object, sel);
    return [value isKindOfClass:[NSString class]] ? value : ([value respondsToSelector:@selector(stringValue)] ? [value stringValue] : nil);
}

static void SCITTCompareReads(NSString *conversation, NSString *me, NSString *name, NSDictionary *now) {
    if (!sciReadBaseline) { sciReadBaseline = [NSMutableDictionary dictionary]; sciReadLastAlert = [NSMutableDictionary dictionary]; }

    NSDictionary *before = sciReadBaseline[conversation];
    sciReadBaseline[conversation] = now;
    if (!before) { sciReadBaselines++; return; }

    BOOL advanced = NO;
    for (id key in now) {
        NSString *uid = [key description];
        if (me.length && [uid isEqualToString:me]) continue;
        long long after = [now[key] respondsToSelector:@selector(longLongValue)] ? [now[key] longLongValue] : 0;
        id was = before[key];
        long long prior = [was respondsToSelector:@selector(longLongValue)] ? [was longLongValue] : -1;
        if (prior >= 0 && after > prior) { advanced = YES; break; }
    }
    if (!advanced) return;

    // One banner per conversation every ten seconds: a person reading a long thread moves their position many times a minute.
    NSDate *last = sciReadLastAlert[conversation];
    if (last && [[NSDate date] timeIntervalSinceDate:last] < 10) return;
    sciReadLastAlert[conversation] = [NSDate date];

    sciReadAlerts++;
    NSString *text = name.length ? [NSString stringWithFormat:SCILocalized(@"read_alert_named"), name] : SCILocalized(@"read_alert");
    [SCITTToast noticeWithText:text symbol:@"envelope.open.fill"];
}

%group SCITTReadAlertGroup
%hook AWEIMMessageConversation

- (void)p_notifyParticipantReadIndexDidUpdate {
    %orig;
    sciReadNotifications++;
    if (!SCIPrefEnabled(SCIPrefReadAlert)) return;

    Ivar ivar = class_getInstanceVariable([self class], "_uidParticipantReadIndexDict");
    id dictionary = ivar ? object_getIvar(self, ivar) : nil;
    if (![dictionary isKindOfClass:[NSDictionary class]]) return;

    NSDictionary *snapshot = [(NSDictionary *)dictionary copy];
    NSString *conversation = SCITTString(self, "conversationID") ?: @"";
    NSString *me = SCITTString(self, "currentUserID");
    NSString *name = SCITTString(self, "name");

    dispatch_async(dispatch_get_main_queue(), ^{
        SCITTCompareReads(conversation, me, name, snapshot);
    });
}

%end
%end

NSString *SCITTReadAlertReport(void) {
    return [NSString stringWithFormat:@"%@; notifications seen: %lu, first looks (baselines): %lu, alerts shown: %lu",
            sciReadState ?: @"not installed", (unsigned long)sciReadNotifications, (unsigned long)sciReadBaselines, (unsigned long)sciReadAlerts];
}

void SCITTInstallReadAlert(void) {
    Class conversation = NSClassFromString(@"AWEIMMessageConversation");
    Method method = conversation ? class_getInstanceMethod(conversation, sel_registerName("p_notifyParticipantReadIndexDidUpdate")) : NULL;
    const char *types = method ? method_getTypeEncoding(method) : NULL;
    BOOL hasIvar = conversation && class_getInstanceVariable(conversation, "_uidParticipantReadIndexDict") != NULL;

    if (!types || strcmp(types, "v16@0:8") != 0 || !hasIvar) {
        sciReadState = [NSString stringWithFormat:@"stood down: %@", !conversation ? @"AWEIMMessageConversation absent" : (!types ? @"-p_notifyParticipantReadIndexDidUpdate absent" : (hasIvar ? @"encoding differs" : @"read-index ivar absent"))];
        SCILogV(@"[ReadAlert] %@", sciReadState);
        return;
    }
    %init(SCITTReadAlertGroup);
    sciReadState = @"installed: AWEIMMessageConversation -p_notifyParticipantReadIndexDidUpdate";
    SCILogV(@"[ReadAlert] %@", sciReadState);
}
