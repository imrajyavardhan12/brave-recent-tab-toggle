#!/bin/bash
set -euo pipefail

PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/recent-tab-toggle-package-test.XXXXXX")
trap 'rm -rf "$SANDBOX"' EXIT

"$PROJECT_ROOT/scripts/package-extension.sh" >/dev/null
VERSION=$(node -p "require('$PROJECT_ROOT/package.json').version")
ARCHIVE="$PROJECT_ROOT/dist/recent-tab-toggle-extension-$VERSION.zip"
cp "$ARCHIVE" "$SANDBOX/first.zip"
"$PROJECT_ROOT/scripts/package-extension.sh" >/dev/null
cmp "$SANDBOX/first.zip" "$ARCHIVE"
(
  cd "$(dirname "$ARCHIVE")"
  shasum -a 256 -c "$(basename "$ARCHIVE").sha256"
) >/dev/null
ARCHIVE_CONTENTS=$(unzip -Z1 "$ARCHIVE")
grep -qx 'LICENSE' <<<"$ARCHIVE_CONTENTS"
if grep -q '^test/\|/test/' <<<"$ARCHIVE_CONTENTS"; then
  printf 'extension package unexpectedly contains tests\n' >&2
  exit 1
fi

printf '✓ extension package is deterministic and checksummed\n'
