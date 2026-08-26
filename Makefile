ARCHS = arm64
TARGET = iphone:clang:16.5:14.0
DEBUG = 0
FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

# V8 Framework Edition
# Two directly injected plain dylibs + five genuine dynamic frameworks.
LIBRARY_NAME = iKiraPlus UIDisplayServices
FRAMEWORK_NAME = UIInfrastructure CoreLifecycle ProcessServices ProcessSupport SystemEnvironment

COMMON_CFLAGS = -fobjc-arc -Os -fvisibility=hidden -ffunction-sections -fdata-sections -Wall -Wextra -Wno-deprecated-declarations
COMMON_LDFLAGS = -Wl,-dead_strip

# ---- Direct dylibs ----
iKiraPlus_FILES = iKiraPlus.m
iKiraPlus_FRAMEWORKS = UIKit Foundation
iKiraPlus_CFLAGS = $(COMMON_CFLAGS)
iKiraPlus_LDFLAGS = $(COMMON_LDFLAGS)

UIDisplayServices_FILES = UIDisplayServices.m
UIDisplayServices_FRAMEWORKS = UIKit Foundation
UIDisplayServices_CFLAGS = $(COMMON_CFLAGS)
UIDisplayServices_LDFLAGS = $(COMMON_LDFLAGS)

# ---- Dynamic framework guards ----
# @rpath gives each framework a normal relocatable framework install-name:
#   @rpath/<Name>.framework/<Name>
UIInfrastructure_FILES = UIInfrastructure.m
UIInfrastructure_FRAMEWORKS = UIKit Foundation
UIInfrastructure_CFLAGS = $(COMMON_CFLAGS)
UIInfrastructure_LDFLAGS = $(COMMON_LDFLAGS)
UIInfrastructure_INSTALL_PATH = @rpath
UIInfrastructure_RESOURCE_DIRS = FrameworkResources/UIInfrastructure

CoreLifecycle_FILES = CoreLifecycle.m
CoreLifecycle_FRAMEWORKS = UIKit Foundation
CoreLifecycle_CFLAGS = $(COMMON_CFLAGS)
CoreLifecycle_LDFLAGS = $(COMMON_LDFLAGS)
CoreLifecycle_INSTALL_PATH = @rpath
CoreLifecycle_RESOURCE_DIRS = FrameworkResources/CoreLifecycle

ProcessServices_FILES = ProcessServices.m
ProcessServices_FRAMEWORKS = UIKit Foundation
ProcessServices_CFLAGS = $(COMMON_CFLAGS)
ProcessServices_LDFLAGS = $(COMMON_LDFLAGS)
ProcessServices_INSTALL_PATH = @rpath
ProcessServices_RESOURCE_DIRS = FrameworkResources/ProcessServices

ProcessSupport_FILES = ProcessSupport.m
ProcessSupport_FRAMEWORKS = UIKit Foundation
ProcessSupport_CFLAGS = $(COMMON_CFLAGS)
ProcessSupport_LDFLAGS = $(COMMON_LDFLAGS)
ProcessSupport_INSTALL_PATH = @rpath
ProcessSupport_RESOURCE_DIRS = FrameworkResources/ProcessSupport

SystemEnvironment_FILES = SystemEnvironment.m
SystemEnvironment_FRAMEWORKS = UIKit Foundation
SystemEnvironment_CFLAGS = $(COMMON_CFLAGS)
SystemEnvironment_LDFLAGS = $(COMMON_LDFLAGS)
SystemEnvironment_INSTALL_PATH = @rpath
SystemEnvironment_RESOURCE_DIRS = FrameworkResources/SystemEnvironment

include $(THEOS_MAKE_PATH)/library.mk
include $(THEOS_MAKE_PATH)/framework.mk
