#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d /tmp/xray-tui-update-test.XXXXXX)"
cleanup() {
  cleanup_update 2>/dev/null || true
  case "$WORK" in /tmp/xray-tui-update-test.*) rm -rf -- "$WORK" ;; esac
}
trap cleanup EXIT

# shellcheck source=../xray-tui
source "$ROOT/xray-tui"
sed '0,/^VERSION=/{s/^VERSION=.*/VERSION="9.9.9"/;}' "$ROOT/xray-tui" > "$WORK/new"
cp "$ROOT/xray-tui" "$WORK/current"
printf 'not a shell script\n' > "$WORK/broken"

export UPDATE_FIXTURE="$WORK/new"
curl() {
  local output=""
  while (($#)); do
    if [[ "$1" == "--output" ]]; then output="$2"; shift 2; else shift; fi
  done
  cp "$UPDATE_FIXTURE" "$output"
}

download_update
[[ "$UPDATE_VERSION" == "9.9.9" ]]
version_is_newer "$UPDATE_VERSION"
cleanup_update

UPDATE_FIXTURE="$WORK/current"
download_update
[[ "$UPDATE_VERSION" == "$VERSION" ]]
! version_is_newer "$UPDATE_VERSION"
cleanup_update

UPDATE_FIXTURE="$WORK/broken"
! download_update 2>/dev/null
[[ -z "$UPDATE_FILE" ]]

printf 'update tests: OK\n'
