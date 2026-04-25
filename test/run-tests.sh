#!/usr/bin/env bash
# run-tests.sh - Execute all Bats tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATS_BIN="${SCRIPT_DIR}/libs/bats/bin/bats"

echo "Running claude-setup test suite..."
echo ""

# Run all .bats files
"${BATS_BIN}" "${SCRIPT_DIR}"/*.bats
