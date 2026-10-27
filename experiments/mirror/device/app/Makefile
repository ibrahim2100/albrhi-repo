ARCHS = arm64 arm64e
TARGET := iphone:clang:16.2:14.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = AlbrhiMirror
AlbrhiMirror_FILES = main.m
AlbrhiMirror_CFLAGS = -fobjc-arc -Wall
AlbrhiMirror_FRAMEWORKS = UIKit Foundation
AlbrhiMirror_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk
