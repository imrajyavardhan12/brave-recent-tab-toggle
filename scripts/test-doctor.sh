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

# Uninstall must warn about a helper the browser is still running. Holding the FIFO open
# keeps the helper alive; closing it delivers EOF so the helper exits.
mkfifo "$SANDBOX/host-input"
# Launch the helper exactly as Brave does: by the path recorded in its manifest.
MANIFEST_HOST=$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["path"])' \
  "$RTT_BRAVE_USER_DATA_DIR/NativeMessagingHosts/org.recenttabtoggle.host.json")
RTT_COORDINATION_ROOT="$SANDBOX/coordination" \
  RTT_EVENT_NAMESPACE="org.recenttabtoggle.tests.doctor-$$" \
  RTT_TARGET_BUNDLE_ID=org.recenttabtoggle.tests.never-frontmost \
  "$MANIFEST_HOST" \
  chrome-extension://edcgmlcjhdpdanpfhgcnbkeppbaijbmd/ \
  <"$SANDBOX/host-input" >/dev/null &
HOST_PID=$!
exec 3>"$SANDBOX/host-input"
sleep 0.5
"$PROJECT_ROOT/scripts/uninstall.sh" >/dev/null 2>"$SANDBOX/uninstall.log"
exec 3>&-
wait "$HOST_PID"
grep -q 'still running the removed helper' "$SANDBOX/uninstall.log"

"$PROJECT_ROOT/scripts/install.sh" >/dev/null
"$PROJECT_ROOT/scripts/uninstall.sh" >/dev/null 2>"$SANDBOX/uninstall.log"
if grep -q 'still running' "$SANDBOX/uninstall.log"; then
  printf 'uninstall warned about a helper that is not running\n' >&2
  exit 1
fi
printf '✓ doctor validates the installed native host\n'
printf '✓ uninstall warns about a helper that is still running\n'
