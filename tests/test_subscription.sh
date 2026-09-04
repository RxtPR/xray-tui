#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d /tmp/xray-tui-sub-test.XXXXXX)"
cleanup() {
  case "$WORK" in /tmp/xray-tui-sub-test.*) rm -rf -- "$WORK" ;; esac
}
trap cleanup EXIT

export XRAY_TUI_ETC="$WORK/etc"
# shellcheck source=../xray-tui
source "$ROOT/xray-tui"
mkdir -p "$PROFILE_DIR" "$SUB_DIR"

uri1='vless://11111111-1111-1111-1111-111111111111@example.com:443?encryption=none#One'
uri2='trojan://secret@example.net:443?security=tls#Two'
printf '%s\n%s\n' "$uri1" "$uri2" > "$WORK/plain"
mapfile -t plain < <(extract_subscription_uris "$WORK/plain")
[[ ${#plain[@]} -eq 2 && "${plain[0]}" == "$uri1" && "${plain[1]}" == "$uri2" ]]

PLAIN="$WORK/plain" python3 - "$WORK/base64" <<'PY'
import base64,os,sys
with open(os.environ['PLAIN'],'rb') as src, open(sys.argv[1],'wb') as dst:
    dst.write(base64.b64encode(src.read()))
PY
mapfile -t encoded < <(extract_subscription_uris "$WORK/base64")
[[ ${#encoded[@]} -eq 2 && "${encoded[0]}" == "$uri1" && "${encoded[1]}" == "$uri2" ]]

export FIXTURE="$WORK/plain"
curl() {
  local output=""
  while (($#)); do
    if [[ "$1" == "--output" ]]; then output="$2"; shift 2; else shift; fi
  done
  cp "$FIXTURE" "$output"
}
xray() { return 0; }

subscription_add Demo https://example.com/subscription >/dev/null
[[ -f "$SUB_DIR/Demo.url" && -f "$SUB_DIR/Demo.profiles" ]]
[[ "$(find "$PROFILE_DIR" -maxdepth 1 -name 'Demo__*.json' | wc -l)" -eq 2 ]]

printf '%s\n' "$uri1" > "$FIXTURE"
subscription_refresh Demo >/dev/null
[[ "$(find "$PROFILE_DIR" -maxdepth 1 -name 'Demo__*.json' | wc -l)" -eq 1 ]]

subscription_delete Demo >/dev/null
[[ ! -e "$SUB_DIR/Demo.url" ]]
[[ "$(find "$PROFILE_DIR" -maxdepth 1 -name 'Demo__*.json' | wc -l)" -eq 0 ]]

printf 'subscription tests: OK\n'
