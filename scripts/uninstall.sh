#!/bin/bash
set -euo pipefail

INSTALL_ROOT=${RTT_INSTALL_ROOT:-"$HOME/Library/Application Support/RecentTabToggle"}
BRAVE_USER_DATA_DIR=${RTT_BRAVE_USER_DATA_DIR:-"$HOME/Library/Application Support/BraveSoftware/Brave-Browser"}
CACHE_ROOT=${RTT_CACHE_ROOT:-"$HOME/Library/Caches/RecentTabToggle"}
HOST_PATH="$INSTALL_ROOT/bin/recent-tab-toggle-host"
MANIFEST_PATH="$BRAVE_USER_DATA_DIR/NativeMessagingHosts/org.recenttabtoggle.host.json"

rm -f "$HOST_PATH" "$MANIFEST_PATH"
rmdir "$INSTALL_ROOT/bin" "$INSTALL_ROOT" 2>/dev/null || true
rm -rf "$CACHE_ROOT"

cat <<EOF
Recent Tab Toggle helper removed.
Remove the unpacked extension from brave://extensions to complete uninstallation.
EOF
