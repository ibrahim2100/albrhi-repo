#import "shared/src/SCIMediaSniff.h"
#import "Manager.h"
#import "../SCILog.h"

@implementation SCIDownloadManager

- (instancetype)initWithDelegate:(id<SCIDownloadDelegateProtocol>)downloadDelegate {
    self = [super init];
    
    if (self) {
        self.delegate = downloadDelegate;
    }

    return self;
}

- (void)downloadFileWithURL:(NSURL *)url fileExtension:(NSString *)fileExtension {
    // Properties
    self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:nil];
    self.task = [self.session downloadTaskWithURL:url];
    
    // Default to jpg if no other reasonable length extension is provided
    self.fileExtension = [fileExtension length] >= 3 ? fileExtension : @"jpg";

    [self.task resume];
    [self.delegate downloadDidStart];
}

- (void)cancelDownload {
    [self.task cancel];
    [self.delegate downloadDidCancel];
}

// URLSession methods
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    SCILogV(@"Task wrote %lld bytes of %lld bytes", bytesWritten, totalBytesExpectedToWrite);
    
    float progress = (float)totalBytesWritten / (float)totalBytesExpectedToWrite;

    [self.delegate downloadDidProgress:progress];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {    
    // An HTTP error answers with a body like any other and NSURLSession hands it over as a finished
    // download: a refused address arrives as a small page named like a video and fails later, in the
    // transcoder or in Photos, with no reason.
    if ([downloadTask.response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSInteger status = ((NSHTTPURLResponse *)downloadTask.response).statusCode;
        if (status < 200 || status >= 300) {
            SCILogV(@"[SCInsta] Download Handler: server answered HTTP %ld", (long)status);
            [[NSFileManager defaultManager] removeItemAtURL:location error:nil];
            [self.delegate downloadDidFinishWithError:[NSError errorWithDomain:@"SCIDownload" code:status
                userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"HTTP %ld", (long)status]}]];
            return;
        }
    }

    // Move downloaded file to cache directory
    NSURL *finalLocation = [self moveFileToCacheDir:location];

    SCIMediaKind seen = SCIMediaKindUnknown;
    if (finalLocation && !SCIMediaFileLooksFinished(finalLocation, &seen)) {
        SCILogV(@"[SCInsta] Download Handler: refused a file that is %@", SCIMediaKindDescription(seen));
        [[NSFileManager defaultManager] removeItemAtURL:finalLocation error:nil];
        [self.delegate downloadDidFinishWithError:[NSError errorWithDomain:@"SCIDownload" code:0
            userInfo:@{NSLocalizedDescriptionKey: @"The server sent a page instead of the file"}]];
        return;
    }

    [self.delegate downloadDidFinishWithFileURL:finalLocation];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    SCILogV(@"Task completed with error: %@", error);
    
    [self.delegate downloadDidFinishWithError:error];
}

// Rename downloaded file & move from documents dir -> cache dir
- (NSURL *)moveFileToCacheDir:(NSURL *)oldPath {
    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSString *cacheDirectoryPath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    NSURL *newPath = [[NSURL fileURLWithPath:cacheDirectoryPath] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", NSUUID.UUID.UUIDString, self.fileExtension]];
    
    SCILogV(@"[SCInsta] Download Handler: Moving file from: %@ to: %@", oldPath.absoluteString, newPath.absoluteString);

    // Move file to cache directory
    NSError *fileMoveError;
    [fileManager moveItemAtURL:oldPath toURL:newPath error:&fileMoveError];

    if (fileMoveError) {
        SCILogV(@"[SCInsta] Download Handler: Error while moving file: %@", oldPath.absoluteString);
        SCILogV(@"[SCInsta] Download Handler: %@", fileMoveError);
    }

    return newPath;
}

@end