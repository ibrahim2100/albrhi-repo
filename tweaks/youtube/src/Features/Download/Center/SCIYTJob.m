#import "SCIYTJob.h"
#import "SCIYTLibrary.h"
#import "../../../Localization/SCILocalize.h"

@implementation SCIYTJob

+ (instancetype)jobWithTitle:(NSString *)title
                     quality:(NSString *)quality
                        kind:(SCIYTJobKind)kind
                     videoID:(NSString *)videoID {
    SCIYTJob *job = [[SCIYTJob alloc] init];
    job.identifier = [[NSUUID UUID] UUIDString];
    job.title = title.length ? title : SCILocalized(@"dl_untitled");
    job.quality = quality;
    job.kind = kind;
    job.videoID = videoID;
    job.state = SCIYTJobStateWorking;
    job.createdAt = [NSDate date];
    return job;
}

- (NSURL *)fileURL {
    if (!self.fileName.length) return nil;

    NSURL *file = [[SCIYTLibrary folder] URLByAppendingPathComponent:self.fileName];
    return [[NSFileManager defaultManager] fileExistsAtPath:file.path] ? file : nil;
}

- (NSString *)statusLine {
    switch (self.state) {
        case SCIYTJobStateWorking:
            return [NSString stringWithFormat:SCILocalized(@"dl_progress_format"),
                    (int)(self.progress * 100)];

        case SCIYTJobStateFailed:
            return self.failure.length ? self.failure : SCILocalized(@"dl_failed");

        case SCIYTJobStateDone: {
            NSString *size = [NSByteCountFormatter stringFromByteCount:self.bytes
                                                            countStyle:NSByteCountFormatterCountStyleFile];
            NSString *what = self.quality.length ? self.quality
                           : SCILocalized(self.kind == SCIYTJobKindAudio ? @"dl_kind_audio"
                                                                          : @"dl_kind_video");
            // The mark comes last, so the size stays where the eye already learned to
            // look for it when a row has not been exported.
            if (self.exported) {
                return [NSString stringWithFormat:@"%@ · %@ · %@",
                        what, size, SCILocalized(@"dl_in_photos")];
            }

            // A refused automatic copy is said on the row itself. The download succeeded
            // and the file is here, so this is not a failure state -- it is the one line
            // that separates "it is in the Centre because you asked for that" from "it
            // tried to reach Photos and could not".
            if (self.exportFailure.length) {
                return [NSString stringWithFormat:@"%@ · %@ · %@", what, size, self.exportFailure];
            }

            return [NSString stringWithFormat:@"%@ · %@", what, size];
        }
    }
}

// MARK: - Coding

+ (BOOL)supportsSecureCoding { return YES; }

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (!self) return nil;

    self.identifier = [coder decodeObjectOfClass:[NSString class] forKey:@"id"];
    self.title      = [coder decodeObjectOfClass:[NSString class] forKey:@"title"];
    self.videoID    = [coder decodeObjectOfClass:[NSString class] forKey:@"video"];
    self.quality    = [coder decodeObjectOfClass:[NSString class] forKey:@"quality"];
    self.fileName   = [coder decodeObjectOfClass:[NSString class] forKey:@"file"];
    self.createdAt  = [coder decodeObjectOfClass:[NSDate class] forKey:@"created"];
    self.kind       = [coder decodeIntegerForKey:@"kind"];
    self.bytes      = [coder decodeInt64ForKey:@"bytes"];
    self.duration   = [coder decodeDoubleForKey:@"duration"];
    self.position   = [coder decodeDoubleForKey:@"position"];
    self.exported   = [coder decodeBoolForKey:@"exported"];
    self.exportFailure = [coder decodeObjectOfClass:[NSString class] forKey:@"exportFailure"];

    // Absent on anything saved before this existed, and a missing key decodes to NO --
    // exactly right, since every job saved before Shorts had their own tab was an
    // ordinary video by definition.
    self.isShort    = [coder decodeBoolForKey:@"short"];

    // Always Done. Only finished jobs are written out, and a decoder that trusted a
    // stored state would put a permanently stalled row in front of the user after a
    // crash mid-download.
    self.state = SCIYTJobStateDone;
    self.progress = 1;

    return self.identifier.length ? self : nil;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.identifier forKey:@"id"];
    [coder encodeObject:self.title forKey:@"title"];
    [coder encodeObject:self.videoID forKey:@"video"];
    [coder encodeObject:self.quality forKey:@"quality"];
    [coder encodeObject:self.fileName forKey:@"file"];
    [coder encodeObject:self.createdAt forKey:@"created"];
    [coder encodeInteger:self.kind forKey:@"kind"];
    [coder encodeInt64:self.bytes forKey:@"bytes"];
    [coder encodeDouble:self.duration forKey:@"duration"];
    [coder encodeDouble:self.position forKey:@"position"];
    [coder encodeBool:self.exported forKey:@"exported"];
    [coder encodeObject:self.exportFailure forKey:@"exportFailure"];
    [coder encodeBool:self.isShort forKey:@"short"];
}

@end
