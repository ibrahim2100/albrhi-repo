#import <objc/runtime.h>
#import "../../Utils.h"
#import "../../Settings/SCIDiagnosticsViewController.h"

///
/// Hides "Active now" from other people — beta, off by default.
///
/// Instagram's own setting (Show activity status) already does this, at a price: turning it
/// off also hides everybody else's status from you. This leaves the setting alone and stops
/// the app *reporting* that it is in use, so the server has nothing to show.
///
/// **Three reports, each measured in 410's class metadata before a line was written:**
///
///   BCNPresenceRequestStreamCoordinator -reportUserStatus:availability:     v28@0:8B16@20
///   BCNPresenceRSTransportManager       -reportAppStateChange:availability: v28@0:8B16@20
///   IGRealtimeMqttClient -publishToTopic:payload:successBlock:failureBlock:timeoutBlock:
///                                                                  topic `/t_fs`, foreground state
///
/// The first two are the presence stream saying "this user is here"; each is sent on with its
/// BOOL answered NO -- the same call, reporting away -- rather than swallowed, so whatever
/// waits on the report still gets one. **The second argument is an object, not a BOOL**, which
/// the encoding says plainly (`@20`) and which InstaPlus's version of this hook treats as a
/// BOOL to force; it is passed through untouched here. `/t_fs` is the MQTT connection telling
/// the server the app came to the foreground, and is the one thing withheld outright.
///
/// **What it costs, stated rather than discovered:** a server that believes the app is in the
/// background may send push notifications for messages you are already reading. Nothing else
/// changes -- messages still arrive in real time, because the connection itself is untouched.
///
/// **What is not known yet:** whether these are *all* of the ways 439 reports presence. So every
/// topic published while the switch is on is counted by name, and each of the three points
/// says how often it acted -- if "Active now" still shows, the report names what went out.
///

static BOOL SCIHideOnline(void) {
    return [SCIUtils getBoolPref:@"hide_online_status"];
}

%hook BCNPresenceRequestStreamCoordinator

- (void)reportUserStatus:(BOOL)active availability:(id)availability {
    if (!SCIHideOnline()) {
        %orig;
        return;
    }

    [SCIDiagnostics privacyCount:active ? @"Online · user status reported as away"
                                        : @"Online · user status already away"];
    %orig(NO, availability);
}

%end

%hook BCNPresenceRSTransportManager

- (void)reportAppStateChange:(BOOL)foreground availability:(id)availability {
    if (!SCIHideOnline()) {
        %orig;
        return;
    }

    [SCIDiagnostics privacyCount:foreground ? @"Online · app state reported as background"
                                            : @"Online · app state already background"];
    %orig(NO, availability);
}

%end

%hook IGRealtimeMqttClient

- (void)publishToTopic:(id)topic payload:(id)payload successBlock:(id)success failureBlock:(id)failure timeoutBlock:(id)timeout {
    if (!SCIHideOnline() || ![topic isKindOfClass:[NSString class]]) {
        %orig;
        return;
    }

    if ([(NSString *)topic isEqualToString:@"/t_fs"]) {
        [SCIDiagnostics privacyCount:@"Online · foreground state withheld (/t_fs)"];
        return;
    }

    // Every other topic goes out, and is named: a list of what the app publishes is the
    // shortest way to whichever presence report is still getting through.
    [SCIDiagnostics privacyCount:[NSString stringWithFormat:@"Online · MQTT published %@", topic]];
    %orig;
}

%end

// Which of the three this build has, said once after launch -- a %hook on an absent class
// never attaches, and silence would read as "attached and never needed".
%ctor {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil queue:nil
                                                  usingBlock:^(__unused NSNotification *note) {
        struct { const char *cls; const char *sel; } points[] = {
            { "BCNPresenceRequestStreamCoordinator", "reportUserStatus:availability:" },
            { "BCNPresenceRSTransportManager", "reportAppStateChange:availability:" },
            { "IGRealtimeMqttClient", "publishToTopic:payload:successBlock:failureBlock:timeoutBlock:" },
        };

        NSMutableArray<NSString *> *here = [NSMutableArray array];
        NSMutableArray<NSString *> *missing = [NSMutableArray array];
        for (size_t i = 0; i < sizeof(points) / sizeof(points[0]); i++) {
            Class cls = objc_getClass(points[i].cls);
            BOOL present = cls && class_getInstanceMethod(cls, sel_registerName(points[i].sel));
            [(present ? here : missing) addObject:@(points[i].cls)];
        }

        [SCIDiagnostics privacyNote:@"Online · points in this build"
                              value:[NSString stringWithFormat:@"%lu of 3%@%@", (unsigned long)here.count,
                                     missing.count ? @" — missing " : @"",
                                     [missing componentsJoinedByString:@", "]]];
    }];
}
