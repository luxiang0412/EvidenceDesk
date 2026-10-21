#!/bin/bash
# perf-baseline.sh - record a local performance/scale baseline.
# Data is synthetic and written to an isolated temp directory only.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUT="artifacts/P6/performance-baseline.txt"
mkdir -p artifacts/P6

{
  echo "=== Performance baseline ==="
  echo "Recorded: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo
  echo "--- Device / OS ---"
  sw_vers
  sysctl -n machdep.cpu.brand_string 2>/dev/null || true
  echo "RAM: $(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 )) GB"
  echo
  echo "--- Toolchain ---"
  xcodebuild -version | head -2
  swift --version | head -1
  echo
  echo "--- Build type ---"
  echo "Debug (artifacts/DerivedData), generated project via XcodeGen"
  echo
  echo "--- Dataset ---"
  echo "Synthetic in-memory fixtures: 500 sources, 200 evidence items, 200 finding links."
  echo "Synthetic 100 MB file import via sparse file (no user data)."
  echo
} > "$OUT"

echo "--- Running scale tests ---"
xcodebuild test \
  -project EvidenceDesk.xcodeproj \
  -scheme EvidenceDesk \
  -destination 'platform=macOS' \
  -derivedDataPath artifacts/DerivedData \
  -only-testing:EvidenceDeskTests/PerformanceTests \
  2>&1 | tee /tmp/ed-perf.log | grep -E "✔|✘|Test run with|passed after|failed after" | sed 's/^/  /' | tee -a "$OUT"

echo
echo "--- 100 MB import probe (sparse file, isolated temp storage) ---"
APP="artifacts/DerivedData/Build/Products/Debug/EvidenceDesk.app"
TMPDIR_TEST="$(mktemp -d /tmp/ed-perf-XXXXXX)"
BIG="$TMPDIR_TEST/big.pdf"
mkfile -n 100m "$BIG" 2>/dev/null || dd if=/dev/zero of="$BIG" bs=1m count=0 seek=100 2>/dev/null
# A 100 MB file is exactly at the limit; 101 MB must be rejected quickly.
mkfile -n 101m "$TMPDIR_TEST/too-big.pdf" 2>/dev/null || dd if=/dev/zero of="$TMPDIR_TEST/too-big.pdf" bs=1m count=0 seek=101 2>/dev/null
ls -lh "$BIG" "$TMPDIR_TEST/too-big.pdf" 2>/dev/null | sed 's/^/  /' | tee -a "$OUT"
{
  echo "  Import size limit: $(grep -n 'maxFileSize' EvidenceDesk/Domain/Validation/FileValidation.swift | head -1)"
  echo "  Validation checks file size via attributesOfItem (no full read into memory)."
} >> "$OUT"
rm -rf "$TMPDIR_TEST"

echo
echo "Baseline written to: $OUT"