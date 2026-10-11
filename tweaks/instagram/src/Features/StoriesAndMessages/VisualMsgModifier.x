#import "../../Utils.h"
#import "../../Compat/SCIResolve.h"
#import <objc/runtime.h>

%hook IGDirectVisualMessage
- (NSInteger)viewMode {
    NSInteger mode = %orig;

    // * Modes *
    // 0 - View Once
    // 1 - Replayable

    if ([SCIUtils getBoolPref:@"disable_view_once_limitations"]) {
        if (mode == 0) {
            mode = 1;

            SCILogV(@"[SCInsta] Modifying visual message from read-once to replayable");
        }
    }
    
    return mode;
}
%end

///
/// **410 keeps the same switch somewhere else.** `IGDirectVisualMessage` has no `-viewMode` in 410.1.0
/// (measured with `tools/objc-diff.py --check` against the decrypted binary): the init takes a
/// `viewMode:` argument and the value is read back from the published message's media info, whose
/// `-viewMode` is declared there (`q16@0:8`). The hook above attaches nowhere on 410, so on that
/// build "disable view-once limitations" did nothing. The same transformation is installed on the
/// media-info class **only where that class declares the getter with exactly that type**, so 439 and
/// 441 are untouched. Not run on a device: the report line `view-once mode` says whether it fired.
///
%group SCIgPublishedVisualMediaInfo
%hook IGDirectPublishedMessageVisualMediaInfo
- (NSInteger)viewMode {
    NSInteger mode = %orig;

    if ([SCIUtils getBoolPref:@"disable_view_once_limitations"] && mode == 0) {
        SCILogV(@"[SCInsta] Modifying published visual media from read-once to replayable");
        return 1;
    }
    return mode;
}
%end
%end

%ctor {
    %init;

    Class mediaInfo = SCIResolveClass(@"IGDirectPublishedMessageVisualMediaInfo");
    Method getter = mediaInfo ? class_getInstanceMethod(mediaInfo, @selector(viewMode)) : NULL;
    const char *encoding = getter ? method_getTypeEncoding(getter) : NULL;
    if (encoding && strcmp(encoding, "q16@0:8") == 0) {
        %init(SCIgPublishedVisualMediaInfo, IGDirectPublishedMessageVisualMediaInfo = mediaInfo);
    }
}
