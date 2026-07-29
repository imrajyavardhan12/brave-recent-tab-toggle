#!/bin/bash
set -euo pipefail

PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$PROJECT_ROOT"

for command in actionlint ruff shellcheck swift; do
  command -v "$command" >/dev/null || {
    printf 'Missing lint dependency: %s\n' "$command" >&2
    exit 1
  }
done

PYTHON_CACHE=$(mktemp -d "${TMPDIR:-/tmp}/recent-tab-toggle-python-cache.XXXXXX")
trap 'rm -rf "$PYTHON_CACHE"' EXIT

npm run check:extension
shellcheck scripts/*.sh
for script in scripts/*.sh; do bash -n "$script"; done
PYTHONPYCACHEPREFIX=$PYTHON_CACHE python3 -m py_compile scripts/*.py
ruff check scripts/*.py
ruff format --check scripts/*.py
swift format lint \
  --recursive \
  --strict \
  --configuration .swift-format \
  native
actionlint
git diff --check

printf '✓ all production quality gates passed\n'
