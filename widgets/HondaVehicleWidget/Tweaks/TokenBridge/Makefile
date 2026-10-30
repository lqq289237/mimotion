ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TokenBridge
TokenBridge_FILES = Tweak.x
TokenBridge_CFLAGS = -fobjc-arc -Wno-unused-function
TokenBridge_FRAMEWORKS = Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
