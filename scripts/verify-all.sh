#!/bin/bash
# verify-all.sh - run every automatable check in order.
#
# Stages: environment → generate → build → unit/integration tests → UI tests.
# Exits non-zero as soon as a stage fails, printing which stage failed.
#
# Set SKIP_UI_TESTS=1 to skip the UI stage (e.g. on a machine where the test
# runner cannot be granted Accessibility permission).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

STAMP="$(date +%Y%m%d-%H%M%S)"
LOG_DIR="artifacts/verify-${STAMP}"
mkdir -p "$LOG_DIR"

FAILED_STAGE=""
run_stage() {
  local name="$1"; shift
  echo
  echo "=================================================================="
  echo "== $name"
  echo "=================================================================="
  if "$@" 2>&1 | tee "$LOG_DIR/${name}.log"; then
    echo "== $name: PASS"
  else
    echo "== $name: FAIL"
    FAILED_STAGE="$name"
    return 1
  fi
}

trap 'echo; echo "Verification FAILED at stage: ${FAILED_STAGE:-unknown}"; echo "Logs: $LOG_DIR"; exit 1' ERR

# 1. Environment record
if ! run_stage environment ./scripts/env.sh; then exit 1; fi

# 2. Project generation
if ! run_stage generate ./scripts/generate-project.sh; then exit 1; fi

# 3. Build
if ! run_stage build ./scripts/build.sh; then exit 1; fi

# 4. Unit + integration tests (Swift Testing)
if ! run_stage tests ./scripts/test.sh; then exit 1; fi

# 5. UI automation (XCTest) unless explicitly skipped
if [ "${SKIP_UI_TESTS:-0}" = "1" ]; then
  echo
  echo "== ui-tests: SKIPPED (SKIP_UI_TESTS=1)"
else
  if ! run_stage ui-tests ./scripts/ui-test.sh; then exit 1; fi
fi

echo
echo "=================================================================="
echo "All verification stages passed."
echo "Logs: $LOG_DIR"
echo "=================================================================="
