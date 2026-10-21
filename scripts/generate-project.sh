#!/bin/bash
# generate-project.sh - generate the Xcode project with XcodeGen
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
xcodegen generate