#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d /tmp/xray-tui-i18n-test.XXXXXX)"
trap 'case "$WORK" in /tmp/xray-tui-i18n-test.*) rm -rf -- "$WORK" ;; esac' EXIT

english="$(XRAY_TUI_LANG=en bash "$ROOT/xray-tui" --help)"
grep -q '^Usage:' <<<"$english"
grep -q 'open the interactive menu' <<<"$english"

russian="$(XRAY_TUI_LANG=ru bash "$ROOT/xray-tui" --help)"
grep -q '^Использование:' <<<"$russian"
grep -q 'открыть интерактивное меню' <<<"$russian"

XRAY_TUI_DEFAULT_MODE=tun bash -c 'source "$1"; MODE_FILE="$2/missing"; [[ "$(current_mode)" == tun ]]' _ "$ROOT/xray-tui" "$WORK"
XRAY_TUI_DEFAULT_MODE=proxy bash -c 'source "$1"; MODE_FILE="$2/missing"; [[ "$(current_mode)" == proxy ]]' _ "$ROOT/xray-tui" "$WORK"

# Updating xray-tui must not access GitHub when a valid Core is already present.
bash -c 'source "$1"; is_xray_core(){ return 0; }; xray(){ printf "Xray test\n"; }; curl(){ return 99; }; install_xray_core >/dev/null' _ "$ROOT/xray-tui"

printf 'i18n tests: OK\n'
