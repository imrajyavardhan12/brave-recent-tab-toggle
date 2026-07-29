#!/bin/bash
set -euo pipefail

PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
INSTALL_ROOT=${RTT_INSTALL_ROOT:-"$HOME/Library/Application Support/RecentTabToggle"}
BRAVE_USER_DATA_DIR=${RTT_BRAVE_USER_DATA_DIR:-"$HOME/Library/Application Support/BraveSoftware/Brave-Browser"}
CHROMIUM_NATIVE_HOST_DIR=${RTT_CHROMIUM_NATIVE_HOST_DIR:-"$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"}
HOST_DESTINATION="$INSTALL_ROOT/bin/recent-tab-toggle-host"
MANIFEST_DIRECTORY="$BRAVE_USER_DATA_DIR/NativeMessagingHosts"
MANIFEST_PATH="$MANIFEST_DIRECTORY/org.recenttabtoggle.host.json"
COMPAT_MANIFEST_PATH="$CHROMIUM_NATIVE_HOST_DIR/org.recenttabtoggle.host.json"
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

if [[ ! -x "$HOST_BINARY" ]]; then
  printf 'Native host is missing or not executable: %s\n' "$HOST_BINARY" >&2
  exit 1
fi

mkdir -p \
  "$(dirname "$HOST_DESTINATION")" \
  "$MANIFEST_DIRECTORY" \
  "$CHROMIUM_NATIVE_HOST_DIR"
install -m 755 "$HOST_BINARY" "$HOST_DESTINATION"

python3 - \
  "$MANIFEST_PATH" \
  "$COMPAT_MANIFEST_PATH" \
  "$HOST_DESTINATION" \
  "$EXTENSION_ID" <<'PY'
import json
import os
import sys

manifest_paths = sys.argv[1:3]
host_path, extension_id = sys.argv[3:]
manifest = {
    "name": "org.recenttabtoggle.host",
    "description": "Recent Tab Toggle native macOS shortcut helper",
    "path": os.path.realpath(host_path),
    "type": "stdio",
    "allowed_origins": [f"chrome-extension://{extension_id}/"],
}
for manifest_path in manifest_paths:
    with open(manifest_path, "w") as file:
        json.dump(manifest, file, indent=2)
        file.write("\n")
    os.chmod(manifest_path, 0o644)
PY

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
EOF
