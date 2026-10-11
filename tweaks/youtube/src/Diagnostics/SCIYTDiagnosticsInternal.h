//
//  SCIYTDiagnosticsInternal.h
//  Albrhi for YouTube
//
//  What the diagnostics' own files share and nothing else may use: the pieces of the report
//  that live in their own files (SCIYTDiagnostics+Streams.m).
//
#import "SCIYTDiagnostics.h"

@interface SCIYTDiagnostics (Streams)
+ (NSString *)describeStreams:(id)streamingData;
+ (id)value:(NSString *)key from:(id)object;
+ (NSString *)string:(id)value;
+ (NSString *)zeroArgumentSelectorsOn:(id)object;
@end

// Defined in SCIYTDiagnostics.m; the pieces split into their own files need to call it.
@interface SCIYTDiagnostics ()
+ (NSString *)describeMessage:(id)message;
@end
