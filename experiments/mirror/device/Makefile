# The package: the daemon and the app. Build with ./build.sh rootless|roothide (the scheme picks which Theos is used).
ARCHS = arm64 arm64e
TARGET := iphone:clang:16.2:14.0

include $(THEOS)/makefiles/common.mk

SUBPROJECTS = daemon app

include $(THEOS_MAKE_PATH)/aggregate.mk
