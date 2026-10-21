#!/bin/bash
# ui-test.sh - run UI tests (macOS)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
"$ROOT/scripts/generate-project.sh"

STAMP="$(date +%Y%m%d-%H%M%S)"
RESULT_BUNDLE="artifacts/TestResults/uitests-${STAMP}.xcresult"
LOG_DIR="artifacts/TestResults/${STAMP}"
mkdir -p "$LOG_DIR"

set +e
xcodebuild test \
  -project EvidenceDesk.xcodeproj \
  -scheme EvidenceDesk \
  -destination 'platform=macOS' \
  -derivedDataPath artifacts/DerivedData \
  -only-testing:EvidenceDeskUITests \
  -resultBundlePath "$RESULT_BUNDLE" \
  2>&1 | tee "$LOG_DIR/uitest.log"
STATUS=${PIPESTATUS[0]}
set -e

# The sandboxed app's test stores live inside its own container, which the
# sandboxed test runner cannot delete. Clean them up from here.
CONTAINER_TESTS="$HOME/Library/Containers/com.luxiang0412.EvidenceDesk/Data/tmp/EvidenceDeskUITest"
if [ -d "$CONTAINER_TESTS" ]; then
  find "$CONTAINER_TESTS" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} + 2>/dev/null || true
fi

echo "Full log: $LOG_DIR/uitest.log"
echo "xcresult: $RESULT_BUNDLE"
if [ "$STATUS" -ne 0 ]; then
  echo "UI TESTS FAILED (exit $STATUS)"
fi
exit "$STATUS"