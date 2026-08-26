#import "GuardCommon.h"

__attribute__((constructor))
static void CoreLifecycleInit(void) {
    @autoreleasepool { IKPGuardInstall(@"CoreLifecycle", 1250); }
}
