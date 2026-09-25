#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d)"
trap 'rm -rf "$TEMP"' EXIT
# Build a test-only source from the actual model declarations, excluding SwiftUI views.
awk '/^import (SwiftUI|FirebaseAuth)/ { next } /^private enum HomeTab/ { exit } { print }' "$ROOT/CalmIOS/HomeView.swift" > "$TEMP/models.swift"
awk '/^import (SwiftUI|FirebaseAuth)/ { next } /^private struct ReturnHomeKey/ { exit } { print }' "$ROOT/CalmIOS/DiscoveryView.swift" >> "$TEMP/models.swift"
sed -n '/^enum CancellationReason:/,/^}/p' "$ROOT/CalmIOS/ReservationFlow.swift" >> "$TEMP/models.swift"
cat "$ROOT/Tests/ReservationFlowChecks.swift" "$TEMP/models.swift" > "$TEMP/main.swift"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift -module-cache-path "$TEMP/cache" "$TEMP/main.swift"
