#import "GuardCommon.h"

__attribute__((constructor))
static void ProcessSupportInit(void) {
    @autoreleasepool { IKPGuardInstall(@"ProcessSupport", 1650); }
}
