#!/bin/bash
# test.sh - run unit/integration tests (macOS)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
"$ROOT/scripts/generate-project.sh"

STAMP="$(date +%Y%m%d-%H%M%S)"
RESULT_BUNDLE="artifacts/TestResults/tests-${STAMP}.xcresult"
LOG_DIR="artifacts/TestResults/${STAMP}"
mkdir -p "$LOG_DIR"

set +e
xcodebuild test \
  -project EvidenceDesk.xcodeproj \
  -scheme EvidenceDesk \
  -destination 'platform=macOS' \
  -derivedDataPath artifacts/DerivedData \
  -only-testing:EvidenceDeskTests \
  -resultBundlePath "$RESULT_BUNDLE" \
  2>&1 | tee "$LOG_DIR/test.log"
STATUS=${PIPESTATUS[0]}
set -e

echo "Full log: $LOG_DIR/test.log"
echo "xcresult: $RESULT_BUNDLE"
if [ "$STATUS" -ne 0 ]; then
  echo "TESTS FAILED (exit $STATUS)"
fi
exit "$STATUS"