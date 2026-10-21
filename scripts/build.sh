#!/bin/bash
# build.sh - generate project and build Debug
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
"$ROOT/scripts/generate-project.sh"

xcodebuild build \
  -project EvidenceDesk.xcodeproj \
  -scheme EvidenceDesk \
  -destination 'platform=macOS' \
  -derivedDataPath artifacts/DerivedData \
  -configuration Debug