#import "GuardCommon.h"

__attribute__((constructor))
static void UIInfrastructureInit(void) {
    @autoreleasepool { IKPGuardInstall(@"UIInfrastructure", 1050); }
}
