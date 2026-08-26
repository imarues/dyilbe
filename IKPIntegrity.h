#ifndef IKP_INTEGRITY_H
#define IKP_INTEGRITY_H

#include "IKPProtectedStrings.h"

// Canonical identity of the protected iKiraPlus watermark.
#define IKP_INTEGRITY_PROTOCOL              6
#define IKP_EXPECTED_DYLIB_NAME_C           "iKiraPlus.dylib"
#define IKP_EXPECTED_BRAND_C                IKPProtectedBrand()
#define IKP_EXPECTED_TELEGRAM_C             IKPProtectedTelegram()
#define IKP_EXPECTED_DEVELOPER_C            IKPProtectedDeveloper()
#define IKP_EXPECTED_UI_TITLE_C             IKPProtectedTitle()
#define IKP_EXPECTED_SUBTITLE_C             IKPProtectedSubtitle()
#define IKP_EXPECTED_LOGO_SHA256_C          IKPProtectedLogoHash()

// dyld exposes the basename of a dynamic-framework executable without the
// .framework suffix, while the two direct products remain .dylib basenames.
#define IKP_BOOTSTRAP_GUARD_NAME_C          "UIDisplayServices.dylib"
static const char * const IKP_EXPECTED_GUARDS[] = {
    "UIDisplayServices.dylib",
    "UIInfrastructure",
    "CoreLifecycle",
    "ProcessServices",
    "ProcessSupport",
    "SystemEnvironment"
};
#define IKP_EXPECTED_GUARD_COUNT (sizeof(IKP_EXPECTED_GUARDS) / sizeof(IKP_EXPECTED_GUARDS[0]))

static const char * const IKP_SECONDARY_FRAMEWORK_GUARDS[] = {
    "UIInfrastructure",
    "CoreLifecycle",
    "ProcessServices",
    "ProcessSupport",
    "SystemEnvironment"
};
#define IKP_SECONDARY_FRAMEWORK_GUARD_COUNT \
    (sizeof(IKP_SECONDARY_FRAMEWORK_GUARDS) / sizeof(IKP_SECONDARY_FRAMEWORK_GUARDS[0]))

#endif
