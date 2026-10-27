# albrhi-mirrord (stage 1 probe). Build with ./build.sh rootless|roothide -- the scheme picks which Theos is used.
ARCHS = arm64 arm64e
TARGET := iphone:clang:16.2:14.0

include $(THEOS)/makefiles/common.mk

TOOL_NAME = albrhi-mirrord
albrhi-mirrord_FILES = main.m
albrhi-mirrord_CFLAGS = -fobjc-arc -Wall
albrhi-mirrord_FRAMEWORKS = Foundation CoreGraphics ImageIO IOSurface QuartzCore
albrhi-mirrord_INSTALL_PATH = /usr/bin
albrhi-mirrord_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/tool.mk
