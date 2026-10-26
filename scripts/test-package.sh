#!/bin/bash
set -euo pipefail

PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd -P)
SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/recent-tab-toggle-package-test.XXXXXX")
# Operating-system and editor droppings (such as an editor swap file) never ship. Any other
# file git does not track must stop packaging instead of being silently left out.
JUNK_FILE="$PROJECT_ROOT/extension/popup/.package-probe-$$.swp"
UNTRACKED_FILE="$PROJECT_ROOT/extension/popup/package-probe-$$.js"
EXCLUDED_FILE="$PROJECT_ROOT/extension/src/package-probe-$$.js"
trap 'rm -rf "$SANDBOX" "$JUNK_FILE" "$UNTRACKED_FILE" "$EXCLUDED_FILE"' EXIT
printf 'junk\n' >"$JUNK_FILE"

expect_packaging_to_name() {
  local file=$1 reason=$2
  if "$PROJECT_ROOT/scripts/package-extension.sh" >/dev/null 2>"$SANDBOX/package.log"; then
    printf 'packaging unexpectedly accepted %s\n' "$reason" >&2
    exit 1
  fi
  grep -qF "${file#"$PROJECT_ROOT"/}" "$SANDBOX/package.log" || {
    printf 'packaging failed without naming %s:\n' "$reason" >&2
    cat "$SANDBOX/package.log" >&2
    exit 1
  }
}

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
REFERENCES=$(node "$PROJECT_ROOT/scripts/manifest-references.mjs" "$PROJECT_ROOT/extension/manifest.json")
# The fixed entry points check the reference list itself instead of trusting it.
REQUIRED=$(printf '%s\n' manifest.json src/service-worker.js popup/popup.html icons/icon-128.png "$REFERENCES")
while IFS= read -r required; do
  grep -qxF "$required" <<<"$ARCHIVE_CONTENTS" || {
    printf 'extension package is missing %s\n' "$required" >&2
    exit 1
  }
done <<<"$REQUIRED"
if grep -q 'package-probe' <<<"$ARCHIVE_CONTENTS"; then
  printf 'extension package unexpectedly contains a junk file\n' >&2
  exit 1
fi

printf 'export {};\n' >"$UNTRACKED_FILE"
expect_packaging_to_name "$UNTRACKED_FILE" 'an untracked extension file'
rm "$UNTRACKED_FILE"

# A contributor's global excludes file can hide a file the extension needs. Append to any
# git configuration the environment already provides instead of replacing it.
printf 'export {};\n' >"$EXCLUDED_FILE"
printf '%s\n' "$(basename "$EXCLUDED_FILE")" >"$SANDBOX/global-excludes"
CONFIG_INDEX=${GIT_CONFIG_COUNT:-0}
export "GIT_CONFIG_KEY_$CONFIG_INDEX=core.excludesFile"
export "GIT_CONFIG_VALUE_$CONFIG_INDEX=$SANDBOX/global-excludes"
export GIT_CONFIG_COUNT=$((CONFIG_INDEX + 1))
git -C "$PROJECT_ROOT" check-ignore -q "$EXCLUDED_FILE" || {
  printf 'the excludes probe is not ignored, so it cannot test ignore rules\n' >&2
  exit 1
}
expect_packaging_to_name "$EXCLUDED_FILE" 'an ignored extension file'

printf '✓ extension package is deterministic and checksummed\n'
