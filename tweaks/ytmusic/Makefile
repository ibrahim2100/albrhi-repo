#
# Albrhi for YouTube Music.
#
# **The hooks are carried over from YTMusicUltimate** (github.com/dayanch96/YTMusicUltimate),
# GPLv3 -- the same licence this repository ships under, which is what makes carrying code
# over lawful here, as it was for Albrhi NextUp and the Spotify ad blocking. The notice ships
# inside the package; control and CHANGELOG.md carry the attribution.
#
# **What was deliberately not carried over is the Premium claim.** That tweak answers
# `-isPremiumSubscriber` with YES on six classes, which tells YouTube Music the account is a
# paying one. This project refused the same thing by name for Locket and again for Spotify.
# The two files here never ask what the account is -- measured before a line was copied --
# which is why they could be taken while that one could not.
#
ROOT := ../..

TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = YouTubeMusic

ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AlbrhiYTM

AlbrhiYTM_FILES = $(shell find src -type f \( -iname \*.x -o -iname \*.xm -o -iname \*.m \)) \
	$(ROOT)/shared/src/SCIPanelGate.m \
	$(ROOT)/shared/src/SCIKVC.m \
	$(ROOT)/shared/src/SCIResponder.m

AlbrhiYTM_CFLAGS = -fobjc-arc -I$(ROOT) -Isrc \
	-DDISABLE_ROOTLESS_COMPAT_WARNING \
	-Wno-deprecated-declarations -Wno-nullability-completeness -Wno-unused-function

AlbrhiYTM_FRAMEWORKS = Foundation UIKit Security

#
# **shared/tweak.mk is deliberately not included**, the same decision Watch and Spotify made:
# it appends the whole JGProgressHUD module to every tweak that includes it, and this one
# draws nothing of its own. SCIPanelGate is named above instead, because this tweak patches
# exactly one app and so takes an ordinary switch on Albrhi's app list.
#
include $(THEOS_MAKE_PATH)/tweak.mk
