#!/bin/bash
set -euo pipefail

PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/recent-tab-toggle-doctor-test.XXXXXX")
trap 'rm -rf "$SANDBOX"' EXIT

BIN_DIRECTORY=$(swift build --package-path "$PROJECT_ROOT/native" --show-bin-path)
export RTT_INSTALL_ROOT="$SANDBOX/install"
export RTT_BRAVE_USER_DATA_DIR="$SANDBOX/brave"
export RTT_CHROMIUM_NATIVE_HOST_DIR="$SANDBOX/chromium-native-hosts"
export RTT_CACHE_ROOT="$SANDBOX/cache"
export RTT_HOST_BINARY="$BIN_DIRECTORY/recent-tab-toggle-host"
export RTT_BRAVE_BINARY="$SANDBOX/Brave Browser"
printf '#!/bin/sh\necho "Brave Browser 150.1.0.0"\n' > "$RTT_BRAVE_BINARY"
chmod +x "$RTT_BRAVE_BINARY"

"$PROJECT_ROOT/scripts/install.sh" >/dev/null
"$PROJECT_ROOT/scripts/doctor.sh" >/dev/null

rm "$RTT_CHROMIUM_NATIVE_HOST_DIR/org.recenttabtoggle.host.json"
if "$PROJECT_ROOT/scripts/doctor.sh" >"$SANDBOX/doctor.log" 2>&1; then
  printf 'doctor unexpectedly accepted a missing compatibility manifest\n' >&2
  exit 1
fi
grep -q 'compatibility native manifest is missing' "$SANDBOX/doctor.log"

"$PROJECT_ROOT/scripts/uninstall.sh" >/dev/null
printf '✓ doctor validates the installed native host\n'
