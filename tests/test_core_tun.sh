#!/usr/bin/env bash
set -Eeuo pipefail

XRAY_BIN="${1:?передайте путь к исполняемому файлу xray}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d /tmp/xray-tui-config-test.XXXXXX)"
cleanup() {
  case "$WORK" in /tmp/xray-tui-config-test.*) rm -rf -- "$WORK" ;; esac
}
trap cleanup EXIT

# shellcheck source=../xray-tui
source "$ROOT/xray-tui"
parsed="$(parse_uri 'vless://11111111-1111-1111-1111-111111111111@example.com:443?encryption=none&security=tls&sni=example.com#test' '')"
PARSED="$parsed" python3 - "$WORK/profile.json" <<'PY'
import json, os, sys
with open(sys.argv[1], 'w') as f:
    json.dump(json.loads(os.environ['PARSED'])['config'], f)
PY

render_active_config "$WORK/profile.json" tun > "$WORK/tun.json"
if output="$("$XRAY_BIN" run -test -c "$WORK/tun.json" 2>&1)"; then
  printf '%s\n' "$output"
  printf 'Xray TUN config test: OK\n'
elif grep -qi 'operation not permitted' <<<"$output"; then
  # Конфигурация разобрана и Core дошёл до создания TUN, но тест запущен без root.
  printf 'Xray TUN config parsed; runtime test skipped without CAP_NET_ADMIN\n'
else
  printf '%s\n' "$output" >&2
  exit 1
fi
