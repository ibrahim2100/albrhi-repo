#!/usr/bin/env bash
#
# Is this machine ready to build, check and test Albrhi? One line per requirement, each with the
# command that fixes it. Read-only: it installs nothing and changes nothing.
#
# The shape is REA's `rea doctor` (github.com/morluto/rea): a readiness report that names what is
# missing and how to get it, instead of a build that fails four minutes in. Every requirement below
# is one CLAUDE.md §3.4 already lists in prose.
#
#   bash tools/doctor.sh
#
cd "$(dirname "$0")/.." || exit 1
missing=0

row() {  # row <ok|MISSING|optional> <what> <detail> [fix]
  printf '%-9s %-34s %s\n' "$1" "$2" "$3"
  if [[ "$1" == MISSING ]]; then missing=$((missing + 1)); [[ -n "${4:-}" ]] && printf '          fix: %s\n' "$4"; fi
  if [[ "$1" == optional && -n "${4:-}" ]]; then printf '          to enable: %s\n' "$4"; fi
}

have() { command -v "$1" >/dev/null 2>&1; }

# ── always needed ─────────────────────────────────────────────────────────────────────────────
have python3 && row ok python3 "$(python3 -V 2>&1)" || row MISSING python3 "" "brew install python"
have git && row ok git "$(git --version | cut -d' ' -f3)" || row MISSING git ""
THEOS_DIR="${THEOS:-$HOME/theos}"
if [[ -f "$THEOS_DIR/makefiles/common.mk" ]]; then
  row ok "Theos (rootless)" "$THEOS_DIR"
else
  row MISSING "Theos (rootless)" "not at $THEOS_DIR" "git clone --recursive https://github.com/theos/theos.git ~/theos && export THEOS=\$HOME/theos"
fi
SDK="$(ls -d "$THEOS_DIR"/sdks/iPhoneOS16.2.sdk 2>/dev/null | head -1)"
[[ -n "$SDK" ]] && row ok "iPhoneOS16.2.sdk" "$SDK" || row MISSING "iPhoneOS16.2.sdk" "not in $THEOS_DIR/sdks" "put it there from github.com/xybp888/iOS-SDKs (the SDK CI uses)"
if have make && make --version 2>/dev/null | grep -q GNU; then
  row ok "GNU make" "$(make --version | head -1)"
elif [[ -x /opt/homebrew/opt/make/libexec/gnubin/make ]]; then
  row ok "GNU make" "gnubin (add /opt/homebrew/opt/make/libexec/gnubin to PATH)"
else
  row MISSING "GNU make" "Apple's make fails Theos" "brew install make && export PATH=\"/opt/homebrew/opt/make/libexec/gnubin:\$PATH\""
fi
have ldid && row ok ldid "$(command -v ldid)" || row MISSING ldid "" "brew install ldid"
have dpkg-deb && row ok dpkg-deb "$(command -v dpkg-deb)" || row MISSING dpkg-deb "" "brew install dpkg"
have dpkg-scanpackages && row ok dpkg-scanpackages "" || row optional dpkg-scanpackages "only the APT index needs it" "brew install dpkg"

# ── roothide flavour ──────────────────────────────────────────────────────────────────────────
RH_DIR="$HOME/theos-roothide"
if [[ -f "$RH_DIR/makefiles/common.mk" ]]; then
  row ok "Theos (roothide fork)" "$RH_DIR"
else
  row optional "Theos (roothide fork)" "not at $RH_DIR; roothide packages cannot be built" "git clone --recursive https://github.com/roothide/theos.git ~/theos-roothide && cp -R \$THEOS/sdks ~/theos-roothide/"
fi

# ── tests ─────────────────────────────────────────────────────────────────────────────────────
if [[ -d /Applications/Xcode.app/Contents/Developer ]] || xcode-select -p >/dev/null 2>&1; then
  row ok "Xcode (host tests)" "$(xcode-select -p 2>/dev/null)"
else
  row optional "Xcode (host tests)" "tools/run-host-tests.sh needs the macOS SDK" "xcode-select --install"
fi
have node && row ok node "$(node -v)" || row optional node "only the licence server's tests" "brew install node"
have gh && gh auth status >/dev/null 2>&1 && row ok "gh (signed in)" "$(gh api user -q .login 2>/dev/null)" \
  || row optional "gh (signed in)" "CI logs cannot be read" "gh auth login"
[[ "$(git config core.hooksPath)" == tools/hooks ]] && row ok "pre-commit hook" "tools/hooks" \
  || row optional "pre-commit hook" "not installed in this clone" "bash tools/install-hooks.sh"

# ── reverse-engineering aids (none is needed to build) ───────────────────────────────────────
have java && java -version >/dev/null 2>&1 && row ok "Java (Ghidra)" "$(java -version 2>&1 | head -1)" \
  || row optional "Java (Ghidra)" "no runtime" "brew install openjdk@21"
if [[ -n "${GHIDRA_INSTALL_DIR:-}" && -d "$GHIDRA_INSTALL_DIR" ]]; then
  row ok "Ghidra" "$GHIDRA_INSTALL_DIR"
else
  row optional "Ghidra" "GHIDRA_INSTALL_DIR not set" "brew install ghidra; export GHIDRA_INSTALL_DIR=\$(brew --prefix ghidra)/libexec"
fi

echo
if (( missing )); then echo "$missing requirement(s) missing — the builds will fail until they are installed."; exit 1; fi
echo "ready to build."
