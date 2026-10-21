#!/bin/bash
# env.sh - record environment, tool versions and SDKs
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${ROOT}/artifacts/P0/environment.txt"
mkdir -p "$(dirname "$OUT")"

{
  echo "=== System ==="
  sw_vers
  uname -a
  echo
  echo "=== Xcode ==="
  xcodebuild -version
  echo
  echo "=== Swift ==="
  swift --version
  echo
  echo "=== Git ==="
  git --version
  echo
  echo "=== XcodeGen ==="
  xcodegen --version
  echo
  echo "=== SDKs ==="
  xcodebuild -showsdks
} 2>&1 | tee "$OUT" >&2

echo
echo "Environment written to: $OUT"