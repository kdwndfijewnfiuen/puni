TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = YWP

THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = YWPOverlay

YWPOverlay_FILES = Tweak.mm
YWPOverlay_CFLAGS = -fobjc-arc -Wno-unused-variable -Wno-unused-function
YWPOverlay_FRAMEWORKS = UIKit Foundation CoreGraphics
YWPOverlay_LIBRARIES =

include $(THEOS_MAKE_PATH)/tweak.mk
