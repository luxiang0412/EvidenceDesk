#!/bin/bash
# collect-evidence.sh - archive test logs, xcresult and non-sensitive screenshots
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DEST="artifacts/evidence-bundle-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$DEST"

if [ -d artifacts/TestResults ]; then
  cp -R artifacts/TestResults "$DEST/" 2>/dev/null || true
fi
if [ -d artifacts/Screenshots ]; then
  cp -R artifacts/Screenshots "$DEST/" 2>/dev/null || true
fi
if [ -f artifacts/P0/environment.txt ]; then
  cp artifacts/P0/environment.txt "$DEST/" 2>/dev/null || true
fi

echo "Evidence archived to: $DEST"