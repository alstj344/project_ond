#!/bin/bash
set -euo pipefail
PROFILE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROFILE_TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$PROFILE_TEST_DIR"' EXIT
# Extract the actual model declarations to run without an iOS simulator.
awk '/^import SwiftUI/ { next } /^private enum ProfileStyle/ { exit } { print }' "$PROFILE_ROOT/CalmIOS/ProfileFlow.swift" > "$PROFILE_TEST_DIR/models.swift"
cat "$PROFILE_ROOT/Tests/ProfileChecks.swift" "$PROFILE_TEST_DIR/models.swift" > "$PROFILE_TEST_DIR/main.swift"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift -module-cache-path "$PROFILE_TEST_DIR/cache" "$PROFILE_TEST_DIR/main.swift"
