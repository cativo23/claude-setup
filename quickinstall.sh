#!/usr/bin/env bash
# quickinstall.sh - Bootstrap installer for claude-setup
# Usage: curl -fsSL https://raw.githubusercontent.com/cativo23/claude-setup/main/quickinstall.sh | bash

set -euo pipefail

REPO="https://github.com/cativo23/claude-setup.git"
CLONE_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$CLONE_DIR"
}
trap cleanup EXIT

echo "Cloning claude-setup..."
git clone --depth 1 "$REPO" "$CLONE_DIR" 2>/dev/null

echo "Starting installer..."
# Run the installer with interactive tty attached if piped
if [ -t 0 ]; then
    bash "$CLONE_DIR/install.sh"
else
    bash "$CLONE_DIR/install.sh" < /dev/tty
fi
