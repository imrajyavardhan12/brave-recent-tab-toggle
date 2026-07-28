#!/bin/bash
set -euo pipefail

PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
swift run --package-path "$PROJECT_ROOT/native" recent-tab-toggle-native-tests
swift build --package-path "$PROJECT_ROOT/native" --product recent-tab-toggle-host >/dev/null
BIN_DIRECTORY=$(swift build --package-path "$PROJECT_ROOT/native" --show-bin-path)
python3 "$PROJECT_ROOT/scripts/test-native-host.py" \
  "$BIN_DIRECTORY/recent-tab-toggle-host"
python3 "$PROJECT_ROOT/scripts/test-multi-profile.py" \
  "$BIN_DIRECTORY/recent-tab-toggle-host" \
  "$BIN_DIRECTORY/recent-tab-toggle-native-tests"
