#import "GuardCommon.h"

__attribute__((constructor))
static void ProcessServicesInit(void) {
    @autoreleasepool { IKPGuardInstall(@"ProcessServices", 1450); }
}
