#!/bin/bash
# Install the pinned lint tools for CI and print the directory to add to PATH.
#
# Homebrew installs whatever version is current, so a tagged release could fail because a
# tool changed. These releases match the versions the project is linted with locally; update
# a version and its checksum together.
set -euo pipefail

DESTINATION=${1:?usage: install-ci-tools.sh <directory>}

if [[ $(uname -s) != Darwin || $(uname -m) != arm64 ]]; then
  printf 'install-ci-tools.sh supports Apple silicon macOS runners only\n' >&2
  exit 1
fi

ACTIONLINT_VERSION=1.7.12
ACTIONLINT_SHA256=aba9ced2dee8d27fecca3dc7feb1a7f9a52caefa1eb46f3271ea66b6e0e6953f
RUFF_VERSION=0.16.1
RUFF_SHA256=a8df4e8e9f22e3b0ae0b9f165ddaafb7e34df692197a6c1a361e7426f90681d5
SHELLCHECK_VERSION=0.11.0
SHELLCHECK_SHA256=56affdd8de5527894dca6dc3d7e0a99a873b0f004d7aabc30ae407d3f48b0a79

DOWNLOADS=$(mktemp -d "${TMPDIR:-/tmp}/recent-tab-toggle-ci-tools.XXXXXX")
trap 'rm -rf "$DOWNLOADS"' EXIT
mkdir -p "$DESTINATION"
# The printed directory goes on PATH, so it must not depend on the working directory.
DESTINATION=$(CDPATH='' cd -- "$DESTINATION" && pwd)

# Runs inside $(...), where bash 3.2 does not apply set -e, so every failure returns explicitly.
fetch() {
  local url=$1 sha256=$2 archive
  archive="$DOWNLOADS/$(basename "$url")"
  curl --fail --silent --show-error --location --retry 3 --retry-all-errors \
    --output "$archive" "$url" ||
    return 1
  printf '%s  %s\n' "$sha256" "$archive" | shasum -a 256 -c - >/dev/null || {
    printf 'checksum mismatch for %s\n' "$url" >&2
    return 1
  }
  printf '%s\n' "$archive"
}

archive=$(fetch "https://github.com/rhysd/actionlint/releases/download/v$ACTIONLINT_VERSION/actionlint_${ACTIONLINT_VERSION}_darwin_arm64.tar.gz" "$ACTIONLINT_SHA256")
tar -xzf "$archive" -C "$DESTINATION" actionlint

archive=$(fetch "https://github.com/astral-sh/ruff/releases/download/$RUFF_VERSION/ruff-aarch64-apple-darwin.tar.gz" "$RUFF_SHA256")
tar -xzf "$archive" -C "$DESTINATION" --strip-components 1 ruff-aarch64-apple-darwin/ruff

archive=$(fetch "https://github.com/koalaman/shellcheck/releases/download/v$SHELLCHECK_VERSION/shellcheck-v$SHELLCHECK_VERSION.darwin.aarch64.tar.xz" "$SHELLCHECK_SHA256")
tar -xJf "$archive" -C "$DESTINATION" --strip-components 1 "shellcheck-v$SHELLCHECK_VERSION/shellcheck"

"$DESTINATION/actionlint" -version >/dev/null
"$DESTINATION/ruff" --version >/dev/null
"$DESTINATION/shellcheck" --version >/dev/null
printf '%s\n' "$DESTINATION"
