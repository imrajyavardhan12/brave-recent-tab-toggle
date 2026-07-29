#!/bin/bash
set -euo pipefail

PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
for ARCHITECTURE in arm64 x86_64; do
  TRIPLE="$ARCHITECTURE-apple-macosx13.0"
  swift build \
    --package-path "$PROJECT_ROOT/native" \
    --configuration release \
    --triple "$TRIPLE" \
    --product recent-tab-toggle-host >/dev/null
  BIN_DIRECTORY=$(swift build \
    --package-path "$PROJECT_ROOT/native" \
    --configuration release \
    --triple "$TRIPLE" \
    --show-bin-path)
  file "$BIN_DIRECTORY/recent-tab-toggle-host" | grep -q "$ARCHITECTURE"
done

printf '✓ native helper builds for Apple silicon and Intel\n'
