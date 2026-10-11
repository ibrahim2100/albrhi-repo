#!/usr/bin/env bash
#
# Every host test in the repository: the pure logic of each tweak, run on this Mac against the
# macOS SDK. `tweaks/*/tests/host/run.sh` are found by glob, so a tweak that gains tests needs no
# edit here. A hook needs a device; a parser, a ranking or a ladder does not -- and several of this
# project's most expensive bugs lived in exactly that layer.
#
#   bash tools/run-host-tests.sh
#
set -uo pipefail
cd "$(dirname "$0")/.."

# The YouTube and YouTube Music harnesses want an Xcode.app path; take the selected one when the
# conventional location is absent (a CI image names it with its version).
if [[ -z "${XCODE:-}" && ! -d /Applications/Xcode.app ]]; then
  DEV="$(xcode-select -p 2>/dev/null || true)"
  [[ -n "$DEV" ]] && export XCODE="${DEV%/Contents/Developer}"
fi

failed=()
count=0
for script in tweaks/*/tests/host/run.sh; do
  [[ -f "$script" ]] || continue
  count=$((count + 1))
  tweak="$(echo "$script" | cut -d/ -f2)"
  echo "=== host tests: $tweak ==="
  if ! bash "$script"; then failed+=("$tweak"); fi
  echo
done

# The class-dump diff tool's self-test: two tiny dylibs, one method removed, one re-typed, one added.
if [[ -x "$(command -v xcrun)" ]]; then
  count=$((count + 1))
  echo "=== tools: objc-diff self-test ==="
  if ! python3 tools/objc-diff.py --selftest; then failed+=("objc-diff"); fi
  echo
fi

# The licence server's own tests (Node, an in-memory KV that paginates like the real one).
if command -v node >/dev/null 2>&1 && [[ -d server/test ]]; then
  count=$((count + 1))
  echo "=== server tests ==="
  if ! (cd server && node --test test/*.test.mjs); then failed+=("server"); fi
  echo
fi

if (( count == 0 )); then echo "no host tests found"; exit 1; fi
if (( ${#failed[@]} )); then echo "HOST TESTS FAILED: ${failed[*]}"; exit 1; fi
echo "HOST TESTS PASSED ($count tweaks)"
