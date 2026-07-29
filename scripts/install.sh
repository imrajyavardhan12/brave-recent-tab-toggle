#!/bin/bash
set -euo pipefail

PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
EXTENSION_ID=edcgmlcjhdpdanpfhgcnbkeppbaijbmd

if [[ $(uname -s) != Darwin ]]; then
  printf 'Recent Tab Toggle currently supports macOS only.\n' >&2
  exit 1
fi

if [[ -n ${RTT_HOST_BINARY:-} ]]; then
  HOST_BINARY=$RTT_HOST_BINARY
else
  command -v swift >/dev/null || {
    printf 'Swift is required. Install Apple Command Line Tools with: xcode-select --install\n' >&2
    exit 1
  }
  swift build \
    --package-path "$PROJECT_ROOT/native" \
    --configuration release \
    --product recent-tab-toggle-host
  BIN_DIRECTORY=$(swift build \
    --package-path "$PROJECT_ROOT/native" \
    --configuration release \
    --show-bin-path)
  HOST_BINARY="$BIN_DIRECTORY/recent-tab-toggle-host"
fi

HOST_DESTINATION=$(python3 "$PROJECT_ROOT/scripts/native_host.py" install \
  --source "$HOST_BINARY")

cat <<EOF
Recent Tab Toggle helper installed.

Next steps:
  1. Open brave://extensions
  2. Enable Developer mode
  3. Choose "Load unpacked"
  4. Select: $PROJECT_ROOT/extension
  5. Reload the extension if it was already loaded

Extension ID: $EXTENSION_ID
Native host:  $HOST_DESTINATION

Verify at any time with: ./scripts/doctor.sh
EOF
