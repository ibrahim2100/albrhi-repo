#!/bin/bash
# ./build.sh rootless|roothide  ->  ~/Desktop/Albrhi-Mirror/
set -e
cd "$(dirname "$0")"
SCHEME="${1:?usage: build.sh rootless|roothide}"
case "$SCHEME" in
  rootless) export THEOS="$HOME/theos" ;;
  roothide) export THEOS="$HOME/theos-roothide" ;;
  *) echo "scheme must be rootless or roothide" >&2; exit 2 ;;
esac
export THEOS_PACKAGE_SCHEME="$SCHEME"
export PATH="/opt/homebrew/opt/make/libexec/gnubin:$PATH"
make clean >/dev/null 2>&1 || true
rm -rf .theos packages
make package FINALPACKAGE=1
mkdir -p "$HOME/Desktop/Albrhi-Mirror"
for f in packages/*.deb; do
  # prove the flavour from the staged paths, not from the file name (the same rule tools/build-local.sh follows)
  listing="$(dpkg-deb -c "$f")"
  if [ "$SCHEME" = rootless ] && ! grep -q "var/jb/usr/bin/albrhi-mirrord" <<<"$listing"; then echo "NOT a rootless layout: $f" >&2; exit 3; fi
  if [ "$SCHEME" = roothide ] &&   grep -q "var/jb" <<<"$listing"; then echo "NOT a roothide layout (found var/jb): $f" >&2; exit 3; fi
  cp "$f" "$HOME/Desktop/Albrhi-Mirror/$(basename "$f" .deb)_$SCHEME.deb"
  echo "copied: $HOME/Desktop/Albrhi-Mirror/$(basename "$f" .deb)_$SCHEME.deb"
done
