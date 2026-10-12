#
# Everything a preference bundle in this repository shares.
#
# Separate from shared/tweak.mk on purpose. That file exists to build a
# MobileSubstrate dylib: it forces JGProgressHUD in, sets Logos flags, and ends
# with tweak.mk. A preference bundle is a different product -- bundle.mk, no
# filter plist, no injection, and it links against Preferences rather than into
# somebody else's app.
#
# Teaching tweak.mk to be both would mean editing the one file both shipping
# tweaks depend on, to serve a third that does not resemble them. The rule this
# project already follows for check.py applies here too: leave the expensive
# thing alone and add beside it.
#
# ROOT must be set by the includer to the repository root.
#

ifeq ($(ROOT),)
$(error ROOT must be set to the repository root before including shared/bundle.mk)
endif

# The repository root on the include path, so shared code is imported by the
# path it really has rather than by counting ../ from wherever it is used.
$(BUNDLE_NAME)_CFLAGS += -I$(ROOT)

# The safe accessor, compiled in the same as it is for every tweak.
#
# A preference bundle names its own sources with a `find` over its `src/`, so nothing
# under shared/ arrives on its own -- and the panel reads filter plists' contents off
# objects it does not own, which is exactly what SCIKVC exists for.
# The preference-bundle kit: the header view, the app cell, the badge art and the button
# action, shared by every bundle here.
#
# They lived inside Albrhi Panel until NextUp and Watch were separated out of it. Each of
# those now ships a Settings row of its own rather than a page inside Albrhi's, and all
# three draw the same furniture -- so it moved here rather than being copied twice. Each
# bundle still supplies its own `SCILocalized`, which is why the kit declares that in
# SCILocalizeAPI.h instead of importing a table by a relative path.
$(BUNDLE_NAME)_FILES += $(ROOT)/shared/src/Prefs/SCIPanelHeader.m
$(BUNDLE_NAME)_FILES += $(ROOT)/shared/src/Prefs/SCIPanelAppCell.m
$(BUNDLE_NAME)_FILES += $(ROOT)/shared/src/Prefs/SCIPanelButtonAction.m

$(BUNDLE_NAME)_FILES += $(ROOT)/shared/src/SCIKVC.m
$(BUNDLE_NAME)_FILES += $(ROOT)/shared/src/SCIPanelGate.m

$(BUNDLE_NAME)_CFLAGS += -fobjc-arc \
	-Wno-deprecated-declarations -Wno-nullability-completeness \
	-Wno-unused-function -Wno-unsupported-availability-guard

# Preferences owns the process this bundle is loaded into, and every class it
# needs -- PSListController, PSSpecifier -- lives there.
#
# The search path is given explicitly. `_PRIVATE_FRAMEWORKS` alone got as far as
# the linker and then "framework 'Preferences' not found": every source compiled,
# so the classes and headers were fine, and only the directory holding the stub was
# missing from the search path. Theos adds it for a tweak target and evidently not
# for a bundle one, and rather than depend on which does what, the path is named.
#
# $(SYSROOT) rather than a version number: the SDK is chosen by CI and pinning
# iPhoneOS16.2 here would break the day it changes.
$(BUNDLE_NAME)_PRIVATE_FRAMEWORKS = Preferences
$(BUNDLE_NAME)_LDFLAGS += -F$(SYSROOT)/System/Library/PrivateFrameworks
$(BUNDLE_NAME)_FRAMEWORKS += UIKit Foundation CoreGraphics Security

# Where a preference bundle has to land for Settings to find it. Under rootless
# this is rewritten to /var/jb/... by Theos itself, which is why it is written
# as an absolute path here and not adjusted by hand.
$(BUNDLE_NAME)_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
