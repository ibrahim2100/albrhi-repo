#import <Foundation/Foundation.h>

///
/// One quality in an HLS playlist.
///
@interface SCIHLSVariant : NSObject
@property (nonatomic, copy) NSString *playlistURL;
@property (nonatomic, copy) NSString *codecs;
@property (nonatomic, assign) NSInteger height;
@property (nonatomic, assign) NSInteger width;
@property (nonatomic, assign) long long bandwidth;

/// The separate audio playlist, when the manifest keeps sound out of the video parts.
///
/// A variant's `CODECS` lists the codecs of the whole presentation — the pictures in its
/// own segments *and* the sound in whichever `#EXT-X-MEDIA` group its `AUDIO=` attribute
/// names. So a manifest can promise `avc1,mp4a` and hand over segments carrying no audio
/// at all, and nothing about the download would look wrong: the parts arrive, the packets
/// unwrap, the .mp4 is written, and it is silent. That is exactly what 0.11.0 produced.
///
/// Nil when the variant carries its own sound, which is the other shape and equally valid.
@property (nonatomic, copy) NSString *audioPlaylistURL;

/// Set when this quality comes from the direct route (SCIYTDirect) rather than from a playlist.
///
/// A variant is still the unit the sheet, the library and the job list understand, so the
/// direct route speaks the same type instead of growing a parallel one: what differs is only
/// where the bytes are fetched from, and that is decided by whether these are filled.
@property (nonatomic, copy) NSString *directVideoURL;
@property (nonatomic, assign) long long directVideoBytes;
@property (nonatomic, copy) NSString *directAudioURL;
@property (nonatomic, assign) long long directAudioBytes;
@property (nonatomic, copy) NSString *directVideoID;

/// "1080p · H.264", for the quality sheet.
- (NSString *)label;
@end


///
/// Saving a video from its HLS playlist.
///
/// This is the route, and it took nine releases of measurement to be sure of it. Every
/// individual format on this build arrives without an address — established through the
/// media layer, the format nested inside it, the player response, and four InnerTube
/// client identities. What does have an address is the *playlist*: YouTube hands the app
/// an `hls_variant` manifest, and a manifest is a list of ordinary segments.
///
/// It is also where every tweak whose downloading works ends up. YTLite reads that one
/// field and gives it to a bundled FFmpeg; DLEasy, Reborn and YTKACE each carry the same
/// library for the same reason.
///
/// **This does not carry FFmpeg**, and whether that holds depends on something only the
/// playlist can say. If its segments are fragmented MP4 — an `#EXT-X-MAP` line and `.m4s`
/// parts — then joining them end to end produces a file AVFoundation reads directly, and
/// the export is a passthrough copy. If they are MPEG-TS instead, that does not work and
/// the report will say so rather than leaving a broken file behind.
///
/// Segments are appended to a file as they arrive rather than gathered in memory: a
/// 1080p video runs to a couple of hundred megabytes and holding that twice over is not
/// something to do on a phone.
///
@interface SCIYTHLS : NSObject

/// Reads the master playlist and returns the qualities worth offering, best first.
/// Anything iOS cannot play is filtered out here rather than after it is chosen.
+ (void)variantsForManifest:(NSString *)manifestURL
                 completion:(void (^)(NSArray<SCIHLSVariant *> *variants, NSString *failure))completion;

/// Downloads one quality and hands back a finished .mp4, or a sentence saying why not.
/// `progress` is called on the main queue with a fraction between 0 and 1.
+ (void)downloadVariant:(SCIHLSVariant *)variant
               progress:(void (^)(double fraction))progress
             completion:(void (^)(NSURL *file, NSString *failure))completion;

/// The sound alone, for someone who wanted the song and not the video.
///
/// Cheap when the manifest keeps its soundtracks apart, which this build does: only the
/// audio rendition is fetched and the pictures are never downloaded at all. When it does
/// not, there is nothing to fetch separately and the video is stripped down afterwards
/// instead — slower, but the same file at the end.
+ (void)downloadAudioFor:(SCIHLSVariant *)variant
                progress:(void (^)(double fraction))progress
              completion:(void (^)(NSURL *file, NSString *failure))completion;

@end
