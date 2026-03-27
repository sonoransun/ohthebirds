#!/usr/bin/env bash
# run_tests.sh — Run the Sugar Glider Adventure test suite headlessly.
#
# Usage:
#   ./run_tests.sh
#
# Set GODOT_BIN to override the godot binary path:
#   GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot ./run_tests.sh

set -eo pipefail

GODOT="${GODOT_BIN:-godot}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Verify godot is available
if ! command -v "$GODOT" &>/dev/null; then
    echo "Error: godot not found. Set GODOT_BIN or add godot to PATH."
    echo "Example: GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot ./run_tests.sh"
    exit 1
fi

echo "Using Godot: $GODOT"
echo "Project path: $SCRIPT_DIR"
echo ""

"$GODOT" --path "$SCRIPT_DIR" --headless --script tests/run_all_tests.gd
EXIT_CODE=$?

exit $EXIT_CODE
