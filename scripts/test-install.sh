#!/bin/bash
set -euo pipefail

PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/recent-tab-toggle-install-test.XXXXXX")
trap 'rm -rf "$SANDBOX"' EXIT

FAKE_HOST="$SANDBOX/fake-host"
printf '#!/bin/sh\nexit 0\n' > "$FAKE_HOST"
chmod +x "$FAKE_HOST"

export RTT_INSTALL_ROOT="$SANDBOX/install"
export RTT_BRAVE_USER_DATA_DIR="$SANDBOX/brave"
export RTT_CHROMIUM_NATIVE_HOST_DIR="$SANDBOX/chromium-native-hosts"
export RTT_HOST_BINARY="$FAKE_HOST"

"$PROJECT_ROOT/scripts/install.sh" >/dev/null

INSTALLED_HOST="$RTT_INSTALL_ROOT/bin/recent-tab-toggle-host"
MANIFEST="$RTT_BRAVE_USER_DATA_DIR/NativeMessagingHosts/org.recenttabtoggle.host.json"
COMPAT_MANIFEST="$RTT_CHROMIUM_NATIVE_HOST_DIR/org.recenttabtoggle.host.json"
test -x "$INSTALLED_HOST"
test -f "$MANIFEST"
test -f "$COMPAT_MANIFEST"

python3 - "$MANIFEST" "$COMPAT_MANIFEST" "$INSTALLED_HOST" <<'PY'
import json, os, sys
manifests = [json.load(open(path)) for path in sys.argv[1:3]]
for manifest in manifests:
    assert manifest["name"] == "org.recenttabtoggle.host"
    assert manifest["path"] == os.path.realpath(sys.argv[3])
    assert manifest["allowed_origins"] == [
        "chrome-extension://edcgmlcjhdpdanpfhgcnbkeppbaijbmd/"
    ]
PY

"$PROJECT_ROOT/scripts/uninstall.sh" >/dev/null
test ! -e "$INSTALLED_HOST"
test ! -e "$MANIFEST"
test ! -e "$COMPAT_MANIFEST"

printf '✓ source install and uninstall are reversible\n'
