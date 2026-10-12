#
# Everything every tweak in this repository shares.
#
# Theos requires a sandwich: common.mk before the definitions, tweak.mk after
# them. So a tweak's own Makefile opens with its identity (TARGET, TWEAK_NAME,
# the process it attaches to, its frameworks) and closes by including this file,
# which appends the parts that are the same whichever app is being patched.
#
# Anything genuinely specific to one app -- dav1d for Instagram's AV1 ladder,
# say -- belongs in that tweak's Makefile, not here.
#
# ROOT must be set by the includer to the repository root, relative to the
# tweak's own directory. Every shared path below is resolved through it, so
# modules/ and vendor/ stay at the top level and are shared rather than copied
# once per tweak.
#

ifeq ($(ROOT),)
$(error ROOT must be set to the repository root before including shared/tweak.mk)
endif

# Every one of TWEAK_NAME's binaries gets the same shared setup below. A tweak
# almost always names one; CarPlay is the first to name two (one dylib for
# SpringBoard/Camera, a second for every app the user enables), and
# `$(TWEAK_NAME)_FILES +=` with a space-separated TWEAK_NAME would silently build
# one oddly-named variable instead of two real ones -- Make does not split on
# spaces inside a variable-name substitution. The loop is what makes a second
# binary in one tweak cost nothing here.
# The trailing space before each `)\` below is load-bearing, not tidiness: tools/
# check.py's rule 9 finds include roots by scanning this file's raw text for
# `-I(\S+)` rather than actually running Make, and `-I$(ROOT))` with no space reads
# as one token, "$(ROOT))" -- the eval's own closing paren swallowed into the path,
# turning every "shared/src/..." import in every tweak into a false "not there".
# Confirmed the hard way: this file is included by all six tweaks, so the one
# missing space failed all six at once instead of just CarPlay.
$(foreach T,$(TWEAK_NAME),\
	$(eval $(T)_FILES += $(wildcard $(ROOT)/modules/JGProgressHUD/*.m))\
	$(eval $(T)_FILES += $(ROOT)/shared/src/SCIPanelGate.m)\
	$(eval $(T)_FILES += $(ROOT)/shared/src/SCIKVC.m)\
	$(eval $(T)_FILES += $(ROOT)/shared/src/SCIResponder.m)\
	$(eval $(T)_FRAMEWORKS += Security)\
	$(eval $(T)_FILES += $(ROOT)/shared/src/SCISubstrateShim.m)\
	$(eval $(T)_CFLAGS += -I$(ROOT) )\
	$(eval $(T)_CFLAGS += -DDISABLE_ROOTLESS_COMPAT_WARNING -fobjc-arc \
		-Wno-unsupported-availability-guard -Wno-unused-value \
		-Wno-deprecated-declarations -Wno-nullability-completeness \
		-Wno-unused-function -Wno-incompatible-pointer-types \
		-Wno-arc-performSelector-leaks)\
	$(eval $(T)_LOGOSFLAGS = --c warnings=none)\
)

CCFLAGS += -std=c++11

include $(THEOS_MAKE_PATH)/tweak.mk

# Build FLEXing for sideloading (not building in dev-mode).
#
# Only the local sideload build reaches this; CI and the published .dylib use
# SELFCONTAINED below instead.
ifdef SIDELOAD
$(foreach T,$(TWEAK_NAME),$(eval $(T)_SUBPROJECTS += $(ROOT)/modules/flexing))
endif

# A dylib that carries its own hooking, so it can be injected on its own -- by
# TrollStore, a certificate, SideStore, LiveContainer, anything -- without
# CydiaSubstrate having to be present alongside it.
#
# Off by default and never set for the jailbreak packages: those keep using
# Substrate exactly as they always have, and this cannot affect them.
#
# shared/src/SCISubstrateShim.m (added to every tweak above, alongside
# SCIPanelGate.m) supplies MSHookMessageEx itself, compiling to nothing unless
# SCI_SELFCONTAINED is defined. Defining it in our own binary means the linker
# resolves it internally, and -dead_strip_dylibs then drops the now-unreferenced
# CydiaSubstrate load command -- which is what makes the result genuinely
# standalone rather than merely appearing to be. CI verifies that with otool
# rather than trusting it.
#
# It lived under tweaks/instagram/src/Compat/ at first and only Instagram's own
# SELFCONTAINED build ever pulled it in -- Locket's own such build linked the
# real CydiaSubstrate anyway, having no shim to satisfy MSHookMessageEx
# internally, and "The dylib still links CydiaSubstrate" is what said so. The
# file itself was never Instagram-specific; only its location was.
#
# Neither $(foreach) line below may start with a tab. A tab in column one of a
# makefile is never "an indented statement" to Make -- it is always an attempt
# at a recipe, valid only inside a rule, and a bare $(eval)-as-statement idiom
# like this one is not a rule. It reads as "recipe commences before first
# target" and stops the parse cold, at this line, whether or not SELFCONTAINED
# is even set -- Make has to parse every line to find the matching endif before
# it can decide whether to skip the block. The unconditional $(foreach) above
# (for JGProgressHUD, SCIPanelGate and the rest) sits at column one for exactly
# this reason; these two did not, because indenting a line to show it belongs
# inside its ifdef reads as correct and is the opposite of correct here. It
# went unnoticed since check.py's rule 9 does not run Make, and neither
# SIDELOAD nor SELFCONTAINED is ever set by an ordinary build -- only Locket's
# own sideload-dylib CI step, the first to actually pass SELFCONTAINED=1 in a
# long while, ran into it.
ifdef SELFCONTAINED
$(foreach T,$(TWEAK_NAME),\
	$(eval $(T)_CFLAGS += -DSCI_SELFCONTAINED)\
	$(eval $(T)_LDFLAGS += -Wl,-dead_strip_dylibs)\
)
endif
