#!/bin/bash
# run-debug.sh - build and launch the app
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
"$ROOT/scripts/build.sh"

APP="artifacts/DerivedData/Build/Products/Debug/EvidenceDesk.app"
echo "Launching $APP"
open "$APP"