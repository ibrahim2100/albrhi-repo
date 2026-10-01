//
//  SCIYTFragmentsInternal.h
//  Albrhi for YouTube
//
//  What the fragmented-MP4 reader hands to the other things in this folder that need the frames
//  themselves rather than a finished file -- today the AV1 converter, which decodes them.
//  Kept out of SCIYTFragments.h on purpose: nothing outside Download/ should know a sample's
//  byte offset.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import "SCIYTFragments.h"

typedef struct {
    uint64_t offset;    ///< absolute position of the frame's bytes in the file
    uint32_t length;
    uint32_t duration;  ///< in the track's timescale
    int64_t dts;
    int64_t pts;
    uint8_t sync;
} SCIFSample;

@interface SCIFTrack : NSObject
@property (nonatomic) uint32_t trackID;
@property (nonatomic) uint32_t timescale;
@property (nonatomic, copy) NSString *handler;       ///< vide or soun
@property (nonatomic, copy) NSString *codec;         ///< avc1, av01 or mp4a
@property (nonatomic, strong) NSData *sps;
@property (nonatomic, strong) NSData *pps;
@property (nonatomic) uint8_t nalLength;
@property (nonatomic) uint32_t sampleRate;
@property (nonatomic) uint32_t channels;
@property (nonatomic, strong) NSData *audioConfig;
@property (nonatomic) uint32_t width;
@property (nonatomic) uint32_t height;
@property (nonatomic, strong) NSData *av1c;          ///< the `av1C` box body, for AV1
@property (nonatomic) uint32_t defaultDuration;
@property (nonatomic) uint32_t defaultSize;
@property (nonatomic) uint32_t defaultFlags;
@property (nonatomic, strong) NSMutableData *samples;   ///< SCIFSample records
@property (nonatomic, strong) NSData *file;
@property (nonatomic) int64_t nextDTS;
- (NSUInteger)count;
- (double)seconds;
@end


@interface SCIYTFragments (Internal)
+ (SCIFTrack * _Nullable)trackFromFile:(NSURL *)url failure:(NSString * _Nullable * _Nullable)failure;
+ (CMFormatDescriptionRef)audioFormat:(SCIFTrack *)track failure:(NSString * _Nullable * _Nullable)failure CF_RETURNS_RETAINED;
+ (CMSampleBufferRef)bufferFor:(SCIFSample)sample
                                   from:(const uint8_t *)bytes
                                 format:(CMFormatDescriptionRef)format
                              timescale:(int32_t)timescale CF_RETURNS_RETAINED;
@end
