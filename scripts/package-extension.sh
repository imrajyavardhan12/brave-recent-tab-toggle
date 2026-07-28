#!/bin/bash
set -euo pipefail

PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$PROJECT_ROOT"

VERSION=$(python3 -c 'import json; print(json.load(open("extension/manifest.json"))["version"])')
DIST="$PROJECT_ROOT/dist"
ARCHIVE="$DIST/recent-tab-toggle-extension-$VERSION.zip"

npm run check:extension
mkdir -p "$DIST"
rm -f "$ARCHIVE"
(
  cd extension
  /usr/bin/zip -qr "$ARCHIVE" manifest.json src popup icons
)
printf 'Created %s\n' "$ARCHIVE"
