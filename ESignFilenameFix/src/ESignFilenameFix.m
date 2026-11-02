#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>
#import "IPAArchiveCheck.h"

// Only completed downloads with IPA archive content are changed.
// No network callbacks or download-button hooks.
static void (*originalSave)(id, SEL) = NULL;
static BOOL (*originalIsDownloaded)(id, SEL) = NULL;
static NSMutableSet<NSString *> *pendingPaths;
static NSMutableSet<NSString *> *checkedPaths;
static BOOL fixing = NO;

static BOOL missingRealExtension(NSString *s) {
    if (![s isKindOfClass:[NSString class]] || s.length == 0) return NO;
    NSString *ext = s.lastPathComponent.pathExtension.lowercaseString;
    if (ext.length == 0) return YES;
    NSCharacterSet *letters = [NSCharacterSet letterCharacterSet];
    if (ext.length <= 16 && [ext rangeOfCharacterFromSet:[letters invertedSet]].location == NSNotFound) {
        return NO;
    }
    return YES;
}

static void enqueueIfAppropriate(id item) {
    @try {
        if (fixing || !item || ![item respondsToSelector:@selector(fileSavePath)] ||
            ![item respondsToSelector:@selector(name)] ||
            ![item respondsToSelector:@selector(setFileSavePath:)] ||
            ![item respondsToSelector:@selector(setName:)]) return;
        NSString *path = [item fileSavePath];
        if (![path isKindOfClass:[NSString class]] || !missingRealExtension(path)) return;
        if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return;
        @synchronized (pendingPaths) {
            if ([pendingPaths containsObject:path] || [checkedPaths containsObject:path]) return;
            [pendingPaths addObject:path];
        }
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            BOOL validIPA = esign_is_ipa_archive(path.fileSystemRepresentation);
            dispatch_async(dispatch_get_main_queue(), ^{
                @try {
                    @synchronized (pendingPaths) {
                        [pendingPaths removeObject:path];
                        // Only memoize validated paths; incomplete files can be rechecked.
                        if (validIPA) [checkedPaths addObject:path];
                    }
                    if (!validIPA || fixing || ![[item fileSavePath] isEqualToString:path]) return;
                    NSString *dest = [path stringByAppendingString:@".ipa"];
                    NSFileManager *fm = [NSFileManager defaultManager];
                    if ([fm fileExistsAtPath:dest]) return;
                    NSError *error = nil;
                    if (![fm moveItemAtPath:path toPath:dest error:&error]) return;
                    fixing = YES;
                    @try {
                        [item setFileSavePath:dest];
                        NSString *name = [item name];
                        if (missingRealExtension(name)) {
                            [item setName:[name stringByAppendingString:@".ipa"]];
                        }
                        if (originalSave) originalSave(item, @selector(save));
                    } @finally { fixing = NO; }
                } @catch (__unused NSException *exception) {
                    // Fail closed if the app has unexpected runtime internals.
                }
            });
        });
    } @catch (__unused NSException *exception) { }
}
static void fixedSave(id self, SEL cmd) {
    if (originalSave) originalSave(self, cmd);
    if (originalIsDownloaded && originalIsDownloaded(self, @selector(isDownloaded))) {
        enqueueIfAppropriate(self);
    }
}
static BOOL fixedIsDownloaded(id self, SEL cmd) {
    BOOL done = originalIsDownloaded ? originalIsDownloaded(self, cmd) : NO;
    if (done) enqueueIfAppropriate(self);
    return done;
}
__attribute__((constructor)) static void installHooks(void) {
    @autoreleasepool {
        Class itemClass = objc_getClass("YYYDownloadItem");
        if (!itemClass) return;
        Method save = class_getInstanceMethod(itemClass, @selector(save));
        Method isDownloaded = class_getInstanceMethod(itemClass, @selector(isDownloaded));
        if (!save || !isDownloaded) return;
        pendingPaths = [NSMutableSet new];
        checkedPaths = [NSMutableSet new];
        originalSave = (void (*)(id,SEL))method_setImplementation(save, (IMP)fixedSave);
        originalIsDownloaded = (BOOL (*)(id,SEL))method_setImplementation(isDownloaded, (IMP)fixedIsDownloaded);
    }
}
