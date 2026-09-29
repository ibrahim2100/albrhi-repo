#
# Albrhi NextUp.
#
# A port of NextUp 3 by Yves (github.com/Yves000/NextUp3), GPLv3 — the same licence
# this repository ships under, which is why the code is carried over rather than only
# read for architecture the way the unlicensed TikTok references are. See control and
# CHANGELOG.md for the attribution this obliges, and CLAUDE.md for what was changed.
#
# Only what is true of this project lives here; everything shared with the other
# tweaks in this repository is in shared/tweak.mk, included at the bottom.
#
# **Seven target processes, and they are two different jobs.** Five providers run
# inside media apps and read that app's own playback queue; the display side runs in
# SpringBoard (Lock Screen, Dynamic Island) and MediaRemoteUI (the now-playing UI that
# Control Center hosts). They talk over a LightMessaging mach service plus Darwin
# notifications, because a provider cannot draw into SpringBoard and SpringBoard cannot
# read another app's queue. Every hook is gated at runtime on the host process and the
# iOS major version, so one binary serves all seven and iOS 14.2 through 26.
#
ROOT := ../..

# 14.2 is upstream's floor and the Lock Screen hooks are written down to it. Kept
# rather than raised to this repository's usual 15.0: the version gating is runtime
# (NUIOSMajor()), so a lower deployment target costs nothing and dropping iOS 14
# support would be a regression this port has no reason to introduce.
TARGET := iphone:clang:latest:14.2
INSTALL_TARGET_PROCESSES = MediaRemoteUI Music Podcasts SpringBoard YouTubeMusic YouTube Spotify SoundCloud

# arm64e as well as arm64, unlike every other tweak here. This one injects into
# SpringBoard on modern devices, where the process is arm64e and an arm64-only slice is
# simply not loaded.
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AlbrhiNU

# src/Settings and src/Localization belong to the preference bundle below, not to a dylib
# that loads into SpringBoard and five media apps. Pruned rather than left to link by luck.
AlbrhiNU_FILES = $(shell find src -type f -not -path 'src/Settings/*' -not -path 'src/Localization/*' \( -iname \*.x -o -iname \*.xm -o -iname \*.m \))

# The guarded accessor, named explicitly because this tweak does not include
# shared/tweak.mk (see the note further down). It replaces one `-valueForKey:` upstream
# does inside an @try -- which runs the receiver's own code, in SpringBoard, where a probe
# that fails takes the home screen rather than a feature.
AlbrhiNU_FILES += $(ROOT)/shared/src/SCIKVC.m
AlbrhiNU_FILES += $(ROOT)/shared/src/SCIPanelGate.m
AlbrhiNU_FILES += $(ROOT)/shared/src/SCILicense.m

# ImageIO for the artwork downscale; the rest is what the row and the hooks draw with.
AlbrhiNU_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore ImageIO Security

# LIGHTMESSAGING_TIMEOUT (ms) bounds the synchronous mach round trip. Upstream's own
# note, kept verbatim in intent because the failure it describes is severe: without it
# the display's main-thread query blocks forever against a suspended app whose runloop
# never services the port, and SpringBoard hangs until the watchdog resprings.
AlbrhiNU_CFLAGS = -I$(ROOT) -Isrc -Isrc/hooks -I$(ROOT)/vendor/LightMessaging -I$(ROOT)/vendor/libSandy \
	-DLIGHTMESSAGING_USE_ROCKETBOOTSTRAP=0 -DLIGHTMESSAGING_TIMEOUT=250 \
	$(NU_PTRAUTH_CFLAGS)

# arm64e pointer authentication, probed rather than hardcoded — upstream's reasoning,
# and it describes a crash rather than a warning: clang 17 signs the class_ro pointer of
# every Objective-C class, and only libobjc from iOS 17 on authenticates that slot. An
# older runtime dereferences the signed pointer as-is and the injected process dies in
# readClass() while dyld is still mapping the tweak. A clang that rejects the flag does
# not emit the signing either, so probing is the whole test.
NU_PTRAUTH_CFLAGS := $(shell $(TARGET_CC) -x objective-c -fsyntax-only -fno-ptrauth-objc-class-ro /dev/null >/dev/null 2>&1 && echo -fno-ptrauth-objc-class-ro)
export NU_PTRAUTH_CFLAGS

# The warning suppressions shared/tweak.mk hands every other tweak, kept because this
# code is someone else's and should not have to satisfy our taste in warnings to build.
AlbrhiNU_CFLAGS += -fobjc-arc -DDISABLE_ROOTLESS_COMPAT_WARNING \
	-Wno-deprecated-declarations -Wno-nullability-completeness \
	-Wno-unused-function -Wno-unused-value

#
# **The log is compiled in and switched off at runtime, not compiled out.**
#
# This shipped with `-DDEBUG=1` because the first install came back "it didn't work" with nothing
# to read: upstream strips NULog from FINALPACKAGE builds, which is right for a tweak that works
# and left this port mute. It is confirmed on iOS 16.1 now, and always-on logging is the wrong
# answer in the other direction — it writes the names of what you are listening to into a file on
# disk, forever, from a package whose neighbour in this same source exists to stop watching being
# reported at all.
#
# So NU_LOGGING is defined in NUShared.h and `NULogEnabled()` reads a preference that is off until
# somebody turns it on in Settings. Nothing is compiled out, nothing is written by default, and a
# device can still be asked what it is doing.
#
AlbrhiNU_LOGOSFLAGS = --c warnings=none

#
# **This is the one tweak here that does not include shared/tweak.mk, and the reason is
# what that file would add rather than what it configures.**
#
# It appends three things to every tweak unconditionally: the whole JGProgressHUD module
# (twelve source files), shared/src/SCIPanelGate.m and shared/src/SCISubstrateShim.m.
# Albrhi NextUp uses none of them — it reads its own preferences through NUPrefs, draws
# no HUD, and is never built self-contained — so all three were being compiled into a
# dylib that loads into SpringBoard purely because the include was the habit. Code
# written against a 15.0 deployment target was also being compiled at this tweak's 14.2,
# which is a class of failure nothing here needed to risk.
#
# The flags that *are* worth having are copied above rather than inherited, so this file
# says plainly what it builds with. Anything genuinely shared that a future tweak needs
# belongs in shared/tweak.mk; this one needed the opposite of sharing.
#
include $(THEOS_MAKE_PATH)/tweak.mk

# The localisation bundle ships through layout/, not as a Theos subproject.
#
# NULocalization.h finds its .strings by walking up from this dylib's own path to
# <jbroot>/Library/PreferenceBundles/NUPrefs.bundle — the one lookup that resolves on
# rootful, rootless and roothide alike. Upstream shipped that bundle as its Settings
# pane; this port's settings live in Albrhi Panel instead, so what is left is 27 .lproj
# tables and an Info.plist with no executable named in it.
#
# A BUNDLE subproject was the obvious way to do that and the wrong one: it exists to
# compile and link something, and this has no sources at all. layout/ is copied into the
# package verbatim, which is exactly the job — and it drops the aggregate.mk include that
# would otherwise sit after shared/tweak.mk has already pulled in tweak.mk.


#
# **And the settings page, as a subproject.**
#
# It ships in this package now rather than inside Albrhi Panel. A page that lives in another
# package is a page that is simply absent whenever that package is not installed -- and Albrhi
# is a tweak for social apps, which this one has nothing to do with. Separate tweaks, separate
# rows in Settings.
#
# A subproject rather than a second name in TWEAK_NAME: that builds two dylibs, and this is a
# preference bundle, which is a different kind of thing with a different makefile behind it.
#
SUBPROJECTS += prefs

include $(THEOS_MAKE_PATH)/aggregate.mk
