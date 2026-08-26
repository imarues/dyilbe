#import "GuardCommon.h"

__attribute__((constructor))
static void SystemEnvironmentInit(void) {
    @autoreleasepool { IKPGuardInstall(@"SystemEnvironment", 1850); }
}
