#!/bin/bash
set -euo pipefail

PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/recent-tab-toggle-package-test.XXXXXX")
# An ignored file (such as Finder's .DS_Store) must never ship, and an untracked file that
# is not ignored must stop packaging instead of being silently left out.
IGNORED_FILE="$PROJECT_ROOT/extension/popup/.package-probe-$$.swp"
UNTRACKED_FILE="$PROJECT_ROOT/extension/popup/package-probe-$$.js"
trap 'rm -rf "$SANDBOX" "$IGNORED_FILE" "$UNTRACKED_FILE"' EXIT
printf 'ignored\n' >"$IGNORED_FILE"

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
for required in manifest.json src/service-worker.js popup/popup.html icons/icon-128.png; do
  grep -qxF "$required" <<<"$ARCHIVE_CONTENTS" || {
    printf 'extension package is missing %s\n' "$required" >&2
    exit 1
  }
done
if grep -q 'package-probe' <<<"$ARCHIVE_CONTENTS"; then
  printf 'extension package unexpectedly contains an ignored file\n' >&2
  exit 1
fi

printf 'export {};\n' >"$UNTRACKED_FILE"
if "$PROJECT_ROOT/scripts/package-extension.sh" >/dev/null 2>"$SANDBOX/package.log"; then
  printf 'packaging unexpectedly ignored an untracked extension file\n' >&2
  exit 1
fi
grep -qF "extension/popup/package-probe-$$.js" "$SANDBOX/package.log" || {
  printf 'packaging failed without naming the untracked file:\n' >&2
  cat "$SANDBOX/package.log" >&2
  exit 1
}

printf '✓ extension package is deterministic and checksummed\n'
