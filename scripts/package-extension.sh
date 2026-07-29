#!/bin/bash
set -euo pipefail

PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$PROJECT_ROOT"

npm run check:extension
python3 scripts/package_extension.py --project-root "$PROJECT_ROOT"
