#import "GuardCommon.h"

static void IKPLoadFrameworkGuard(const char *frameworkName) {
    if (!frameworkName || !frameworkName[0]) return;
    if (IKPGuardExactImageLoaded(frameworkName, NULL, NULL)) return;

    NSString *name = [NSString stringWithUTF8String:frameworkName];
    if (!name.length) return;

    NSString *frameworks = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"Frameworks"];
    NSString *bundlePath = [frameworks stringByAppendingPathComponent:[name stringByAppendingString:@".framework"]];
    NSString *binaryPath = [bundlePath stringByAppendingPathComponent:name];

    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:bundlePath isDirectory:&isDirectory] || !isDirectory) {
        NSLog(@"[iKiraPlus:UIDisplayServices] framework bundle missing: %@", bundlePath);
        return;
    }
    if (![[NSFileManager defaultManager] isExecutableFileAtPath:binaryPath]) {
        NSLog(@"[iKiraPlus:UIDisplayServices] framework executable missing: %@", binaryPath);
        return;
    }

    void *handle = dlopen(binaryPath.fileSystemRepresentation, RTLD_NOW | RTLD_LOCAL);
    if (!handle) {
        NSLog(@"[iKiraPlus:UIDisplayServices] framework load failed for %@: %s",
              binaryPath, dlerror() ?: "unknown");
    }
}

__attribute__((constructor))
static void UIDisplayServicesInit(void) {
    @autoreleasepool {
        // Load all five secondary guard frameworks before the integrity pass.
        for (size_t i = 0; i < IKP_SECONDARY_FRAMEWORK_GUARD_COUNT; i++) {
            IKPLoadFrameworkGuard(IKP_SECONDARY_FRAMEWORK_GUARDS[i]);
        }
        IKPGuardInstall(@"UIDisplayServices", 850);
    }
}
