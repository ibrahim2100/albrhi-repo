#!/usr/bin/env bash
# The address -> app-address maps of the Safari extensions (tools/safari-ext/*/map.js), run in node.
set -euo pipefail
cd "$(dirname "$0")"
node test.js
