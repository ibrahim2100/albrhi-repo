#!/usr/bin/env bash
# Points this clone's git hooks at tools/hooks (a pre-commit that runs tools/check.py).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
chmod +x tools/hooks/pre-commit
git config core.hooksPath tools/hooks
echo "hooks installed: git now runs tools/hooks/pre-commit"
