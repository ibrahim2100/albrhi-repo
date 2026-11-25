#import "SCITTCapture.h"
#import "SCITTMedia.h"
#import "../../Prefs.h"
#import "../../SCILog.h"

///
/// The download link comes from `AWEVideoModel`, caught at its own construction.
///
/// **Every earlier attempt went through the aweme model, and a device report finally
/// explained why that could not work.** `AWEAwemeModel -video` answers nil for the
/// overwhelming majority of models at the moment they are built, and a retry timer
/// only partly papered over it. Meanwhile the one path that *did* keep resolving --
/// `-URLList` on the aweme model, 288 times out of 706 -- turned out to be the
/// **sound's** URL list: the file it produced was 972 KB of `audio/mp4` with no video
/// track at all, which is why every save reported "sound saved". A confident wrong
/// answer, which is worse than no answer.
///
/// `AWEVideoModel` itself is confirmed real by that same report family -- one of them
/// said `"AWEVideoModel has no -playAddr"`, which only a real class can say, and
/// another said `video.playURL` ended `"at AWEURLModel"`, one hop short of that class's
/// own doubly-confirmed `-bestURLtoDownload`. Hooking the video model's construction
/// removes the wait entirely: by the time this object exists, its own play URL is what
/// it was built to carry.
///
/// `%orig` runs first in both hooks and the return value is never altered -- this
/// reads, it does not filter. Nothing here can drop a video the way the ad filter
/// deliberately does.
///

@interface AWEVideoModel : NSObject
@end

%group Capture

%hook AWEVideoModel

// **Never walked inside the model's own construction, and never on the thread that builds it (0.31.4).** This hook used to run the whole ladder
// of getter chains (about fifteen of them) from `-init` *and* from `-initWithDictionary:error:`, synchronously, on whichever thread TikTok was
// building the model on -- the feed parses on background queues, thirty models a second in the phone's report -- and the walk wrote to state the
// main thread reads (`sciRecent`, the pending id/date, strong statics) with no lock between them. A `-init` hook sees a model with nothing in it
// yet, so that half could only ever fail (and was counted as a failure); `-initWithDictionary:error:` returns the finished object. The walk now
// happens once the construction has returned, on the main thread, one at a time.
- (instancetype)initWithDictionary:(NSDictionary *)dictionary error:(NSError **)error {
    id built = %orig;
    if (built && SCIPrefEnabled(SCIPrefDownloadButton)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SCITTMedia captureVideoModel:built];
        });
    }
    return built;
}

%end


%end


void SCITTInstallCapture(void) {
    if (!NSClassFromString(@"AWEVideoModel")) {
        SCILogV(@"AWEVideoModel is not in this build — no video-model capture");
        return;
    }

    %init(Capture);
    SCILogV(@"video-model capture attached to AWEVideoModel");
}
