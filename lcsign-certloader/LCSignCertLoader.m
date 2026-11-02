// LCSign CertLoader (experimental): source code only, no embedded credentials.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <stdint.h>
#include <sys/stat.h>

static NSString *cachedPath;
static BOOL didTry;
static void put16(NSMutableData *d,uint16_t n){uint8_t b[2]={n&255,n>>8};[d appendBytes:b length:2];}
static void put32(NSMutableData *d,uint32_t n){uint8_t b[4]={n&255,(n>>8)&255,(n>>16)&255,n>>24};[d appendBytes:b length:4];}
static uint32_t crc32(NSData *d){
 uint32_t c=0xffffffffu;const uint8_t *p=d.bytes;
 for(NSUInteger i=0;i<d.length;i++){c^=p[i];for(int b=0;b<8;b++)c=(c>>1)^(0xedb88320u&-(c&1u));}
 return ~c;
}
static NSData *zipThree(NSDictionary<NSString*,NSData*> *content){
 NSMutableData *out=[NSMutableData data];NSMutableArray *entries=[NSMutableArray array];
 for(NSString *name in @[@"cert.p12",@"cert.mobileprovision",@"pwd.txt"]){
  NSData *data=content[name],*utf=[name dataUsingEncoding:NSUTF8StringEncoding];
  if(!data||data.length>UINT32_MAX||out.length>UINT32_MAX)return nil;
  uint32_t offset=(uint32_t)out.length,sum=crc32(data),size=(uint32_t)data.length;
  put32(out,0x04034b50);put16(out,20);put16(out,0);put16(out,0);put16(out,0);put16(out,0);
  put32(out,sum);put32(out,size);put32(out,size);put16(out,(uint16_t)utf.length);put16(out,0);
  [out appendData:utf];[out appendData:data];
  [entries addObject:@{@"name":utf,@"size":@(size),@"crc":@(sum),@"offset":@(offset)}];
 }
 if(out.length>UINT32_MAX)return nil;uint32_t central=(uint32_t)out.length;
 for(NSDictionary *e in entries){
  NSData *name=e[@"name"];uint32_t sz=[e[@"size"] unsignedIntValue];
  put32(out,0x02014b50);put16(out,20);put16(out,20);put16(out,0);put16(out,0);put16(out,0);put16(out,0);
  put32(out,[e[@"crc"] unsignedIntValue]);put32(out,sz);put32(out,sz);
  put16(out,(uint16_t)name.length);put16(out,0);put16(out,0);put16(out,0);put16(out,0);
  put32(out,0);put32(out,[e[@"offset"] unsignedIntValue]);[out appendData:name];
 }
 if(out.length>UINT32_MAX)return nil;uint32_t length=(uint32_t)out.length-central;
 put32(out,0x06054b50);put16(out,0);put16(out,0);put16(out,3);put16(out,3);
 put32(out,length);put32(out,central);put16(out,0);return out;
}
static NSString *certificateZip(void){
 @synchronized([NSBundle class]){
  if(didTry)return cachedPath;didTry=YES;
  NSString *dir=[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"signing-assets/iKiraPlus"];
  NSData *p12=[NSData dataWithContentsOfFile:[dir stringByAppendingPathComponent:@"cert.p12"]];
  NSData *profile=[NSData dataWithContentsOfFile:[dir stringByAppendingPathComponent:@"cert.mobileprovision"]];
  NSData *pwd=[NSData dataWithContentsOfFile:[dir stringByAppendingPathComponent:@"pwd.txt"]];
  if(!pwd)pwd=[NSData dataWithContentsOfFile:[dir stringByAppendingPathComponent:@"cert.txt"]];
  if(!p12.length||!profile.length||!pwd||p12.length>8388608||profile.length>8388608||pwd.length>2048)return nil;
  NSData *z=zipThree(@{@"cert.p12":p12,@"cert.mobileprovision":profile,@"pwd.txt":pwd});
  NSArray *cache=NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES);
  if(!z||!cache.count)return nil;
  NSString *folder=[cache[0] stringByAppendingPathComponent:@"LCSignCertLoader"];
  if(![[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL])return nil;
  NSString *file=[folder stringByAppendingPathComponent:@"cert.dat"];
  if(![z writeToFile:file options:NSDataWritingAtomic error:NULL])return nil;
  chmod(file.fileSystemRepresentation,S_IRUSR|S_IWUSR);
  cachedPath=file;return cachedPath;
 }
}
static BOOL isTarget(NSString *p){
 return [p isKindOfClass:[NSString class]]&&[p isEqualToString:[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"cert.dat"]];
}
static NSString *rPath(NSString *p){return isTarget(p)?(certificateZip()?:p):p;}
static BOOL isCert(NSString *n,NSString *ext){
 return ([n isEqualToString:@"cert"]&&[ext isEqualToString:@"dat"])||([n isEqualToString:@"cert.dat"]&&!ext.length);
}

@interface NSBundle (LCSignCertLoader)
-(NSURL *)lc_url:(NSString *)n ext:(NSString *)e;
-(NSString *)lc_path:(NSString *)n type:(NSString *)e;
@end
@implementation NSBundle (LCSignCertLoader)
-(NSURL *)lc_url:(NSString *)n ext:(NSString *)e{
 if(self==[NSBundle mainBundle]&&isCert(n,e)){NSString *path=certificateZip();if(path)return [NSURL fileURLWithPath:path];}
 return [self lc_url:n ext:e];
}
-(NSString *)lc_path:(NSString *)n type:(NSString *)e{
 if(self==[NSBundle mainBundle]&&isCert(n,e)){NSString *path=certificateZip();if(path)return path;}
 return [self lc_path:n type:e];
}
@end

@interface NSData (LCSignCertLoader)
+(instancetype)lc_fromFile:(NSString *)p;
-(instancetype)lc_initFile:(NSString *)p;
@end
@implementation NSData (LCSignCertLoader)
+(instancetype)lc_fromFile:(NSString *)p{return [self lc_fromFile:rPath(p)];}
-(instancetype)lc_initFile:(NSString *)p{return [self lc_initFile:rPath(p)];}
@end
static void swap(Class cls,SEL original,SEL replacement,BOOL classMethod){
 Class target=classMethod?object_getClass(cls):cls;
 Method a=class_getInstanceMethod(target,original),b=class_getInstanceMethod(target,replacement);
 if(a&&b)method_exchangeImplementations(a,b);
}
__attribute__((constructor))static void setup(void){
 @autoreleasepool{
  NSString *exe=[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleExecutable"];
  if(![exe isEqualToString:@"LoadController"])return;
  swap([NSBundle class],@selector(URLForResource:withExtension:),@selector(lc_url:ext:),NO);
  swap([NSBundle class],@selector(pathForResource:ofType:),@selector(lc_path:type:),NO);
  swap([NSData class],@selector(dataWithContentsOfFile:),@selector(lc_fromFile:),YES);
  swap([NSData class],@selector(initWithContentsOfFile:),@selector(lc_initFile:),NO);
 }
}
