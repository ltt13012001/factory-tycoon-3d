#!/usr/bin/env bash
# Runs the headless test suite and also fails on any GDScript runtime error.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
out=$("$GODOT" --headless --path . --script res://tests/run_tests.gd 2>&1)
code=$?
echo "$out"
if echo "$out" | grep -q "SCRIPT ERROR"; then
	echo "Script errors found." >&2
	exit 1
fi
exit $code
