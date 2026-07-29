#!/bin/bash
set -euo pipefail

PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
python3 "$PROJECT_ROOT/scripts/native_host.py" uninstall

cat <<EOF
Recent Tab Toggle helper removed.
Remove the unpacked extension from brave://extensions to complete uninstallation.
EOF
