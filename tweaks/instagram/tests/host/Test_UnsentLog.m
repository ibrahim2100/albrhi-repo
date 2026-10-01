#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "Features/StoriesAndMessages/SCIUnsentLog.h"
#import "Localization/SCILocalize.h"
#import "Settings/SCIDiagnosticsViewController.h"
@implementation SCILocalize
+ (BOOL)isRTL { return NO; }
@end
@implementation SCIDiagnostics
+ (void)privacyCount:(NSString *)l { printf("COUNT %s\n", l.UTF8String); }
+ (void)recordUnsendPath:(NSString *)p detail:(NSString *)d { printf("PATH %s : %s\n", p.UTF8String, d.UTF8String); }
@end
@implementation UIWindow @end
@implementation UIApplication
+ (UIApplication *)sharedApplication { static UIApplication *a; if(!a) a=[[UIApplication alloc] init]; return a; }
- (NSArray *)windows { return @[]; }
@end

// Mock shapes: IGDirectText { text, message -> IGDirectUIMessage { metadata -> { key, senderPk, sentDate, threadId } } }
@interface MKey : NSObject @property NSString *serverId, *clientId; @end @implementation MKey @end
@interface MMeta : NSObject @property MKey *key; @property NSString *senderPk, *threadId; @property NSDate *sentDate; @end @implementation MMeta @end
@interface MUIMessage : NSObject @property MMeta *metadata; @end @implementation MUIMessage @end
@interface IGDirectText : NSObject @property NSString *text; @property MUIMessage *message; @end @implementation IGDirectText @end
@interface IGDirectPhoto : NSObject @property MUIMessage *message; @end @implementation IGDirectPhoto @end
@interface MUser : NSObject @property NSString *pk, *username; @end @implementation MUser @end
@interface MThreadMeta : NSObject @property NSArray *users; @end @implementation MThreadMeta @end
// Published shape: IGDirectPublishedMessage { metadata{serverId,clientContext,serverTimestamp,senderPk,threadId}, content{ivar _text_string} }
@interface PMeta : NSObject @property NSString *serverId, *clientContext, *senderPk, *threadId; @property NSDate *serverTimestamp; @end @implementation PMeta @end
@interface PContent : NSObject { @public NSString *_text_string; id _media; } @end @implementation PContent @end
@interface IGDirectPublishedMessage : NSObject @property PMeta *metadata; @property PContent *content; @end @implementation IGDirectPublishedMessage @end
// The held key: a class with ivars only, like IGDirectMessageUpdateMessageKey.
@interface IGDirectMessageUpdateMessageKey : NSObject { @public NSString *_messageServerId; NSString *_messageClientContext; } @end @implementation IGDirectMessageUpdateMessageKey @end

static MUIMessage *ui(NSString *sid, NSString *cid, NSString *pk, NSTimeInterval t) {
    MKey *k=[MKey new]; k.serverId=sid; k.clientId=cid; MMeta *m=[MMeta new]; m.key=k; m.senderPk=pk; m.threadId=@"T1"; m.sentDate=[NSDate dateWithTimeIntervalSince1970:t];
    MUIMessage *u=[MUIMessage new]; u.metadata=m; return u;
}
static IGDirectMessageUpdateMessageKey *held(NSString *sid, NSString *cid) { IGDirectMessageUpdateMessageKey *k=[IGDirectMessageUpdateMessageKey new]; k->_messageServerId=sid; k->_messageClientContext=cid; return k; }
#define CHECK(c) do{ if(!(c)){ printf("FAIL line %d: %s\n",__LINE__,#c); fails++; } else printf("ok   %s\n",#c);}while(0)
int main(void){ @autoreleasepool {
  int fails=0;
  [SCIUnsentLog clear];
  // names
  MUser *u1=[MUser new]; u1.pk=@"111"; u1.username=@"alice"; MThreadMeta *tm=[MThreadMeta new]; tm.users=@[u1];
  [SCIUnsentLog learnThreadMetadata:tm];
  IGDirectText *t=[IGDirectText new]; t.text=@"hello world"; t.message=ui(@"S1",@"C1",@"111",1000);
  IGDirectPhoto *p=[IGDirectPhoto new]; p.message=ui(@"S2",@"C2",@"111",1010);
  [SCIUnsentLog captureMessage:t]; [SCIUnsentLog captureMessage:p];
  [SCIUnsentLog captureMessage:[NSObject new]];   // an element with no ids: must not crash
  { IGDirectPublishedMessage *pm=[IGDirectPublishedMessage new]; PMeta *pmm=[PMeta new]; pmm.serverId=@"P1"; pmm.clientContext=@"PC1"; pmm.senderPk=@"111"; pmm.threadId=@"T9"; pmm.serverTimestamp=[NSDate dateWithTimeIntervalSince1970:2000]; pm.metadata=pmm; PContent *pc=[PContent new]; pc->_text_string=@"from the cache"; pm.content=pc; [SCIUnsentLog captureMessage:pm]; }
  { IGDirectPublishedMessage *pm=[IGDirectPublishedMessage new]; PMeta *pmm=[PMeta new]; pmm.serverId=@"P2"; pm.metadata=pmm; PContent *pc=[PContent new]; pc->_media=@"m"; pm.content=pc; [SCIUnsentLog captureMessage:pm]; }
  [SCIUnsentLog recordHeldKey:held(@"P1",nil)]; [SCIUnsentLog recordHeldKey:held(@"P2",nil)];
  [SCIUnsentLog recordHeldKey:held(@"S1",@"C1")];
  [SCIUnsentLog recordHeldKey:held(@"S2",nil)];
  [SCIUnsentLog recordHeldKey:held(@"S9",nil)];   // never seen
  [SCIUnsentLog recordHeldKey:held(@"S1",@"C1")]; // duplicate delivery
  NSArray *e=[SCIUnsentLog entries];
  CHECK(e.count==5);
  NSDictionary *byId=@{}; NSMutableDictionary *m=[NSMutableDictionary dictionary]; for (NSDictionary *r in e) m[r[@"id"]]=r; byId=m;
  CHECK([byId[@"S1"][@"text"] isEqualToString:@"hello world"]);
  CHECK([byId[@"S1"][@"name"] isEqualToString:@"alice"]);
  CHECK([byId[@"S1"][@"sent"] doubleValue]==1000);
  CHECK([byId[@"S1"][@"captured"] boolValue]);
  CHECK([byId[@"S2"][@"kind"] isEqualToString:@"Photo"]);
  CHECK(byId[@"S2"][@"text"]==nil && [byId[@"S2"][@"captured"] boolValue]);
  CHECK(![byId[@"S9"][@"captured"] boolValue]);
  CHECK([[SCIUnsentLog localizedKind:@"Photo"] isEqualToString:@"unsent_kind_photo"]);
  CHECK([[SCIUnsentLog localizedKind:@"ReelShare"] isEqualToString:@"unsent_kind_reel"]);
  CHECK([byId[@"P1"][@"text"] isEqualToString:@"from the cache"] && [byId[@"P1"][@"sent"] doubleValue]==2000 && [byId[@"P1"][@"kind"] isEqualToString:@"Text"]);
  CHECK([byId[@"P2"][@"kind"] isEqualToString:@"Media"] && byId[@"P2"][@"text"]==nil);
  NSString *x=[SCIUnsentLog exportText]; CHECK([x containsString:@"hello world"] && [x containsString:@"alice"]);
  [SCIUnsentLog removeEntryWithIdentifier:@"S2"]; CHECK([SCIUnsentLog count]==4);
  // persistence: wait for the debounced write, then read the file
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:3.5]];
  NSString *dir=NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES).firstObject;
  NSData *d=[NSData dataWithContentsOfFile:[dir stringByAppendingPathComponent:@"Albrhi/unsent-log.json"]];
  id json=d?[NSJSONSerialization JSONObjectWithData:d options:0 error:nil]:nil;
  CHECK([json isKindOfClass:[NSArray class]] && [json count]==4);
  // bound: 700 rows -> capped at 600
  for (int i=0;i<700;i++) [SCIUnsentLog recordHeldKey:held([NSString stringWithFormat:@"B%d",i],nil)];
  CHECK([SCIUnsentLog count]==600);
  [SCIUnsentLog clear]; [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:3.5]];
  CHECK(![[NSFileManager defaultManager] fileExistsAtPath:[dir stringByAppendingPathComponent:@"Albrhi/unsent-log.json"]]);
  printf(fails?"FAILURES: %d\n":"ALL PASSED\n",fails); return fails; } }
