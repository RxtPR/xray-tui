#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d /tmp/xray-tui-lxc-test.XXXXXX)"
trap 'case "$WORK" in /tmp/xray-tui-lxc-test.*) rm -rf -- "$WORK" ;; esac' EXIT

# shellcheck source=../xray-tui
source "$ROOT/xray-tui"
TUN_DEVICE="$WORK/missing-tun"
XRAY_TUI_CONTAINER=lxc
XRAY_TUI_CAP_NET_ADMIN=1

[[ "$(container_type)" == "lxc" ]]
[[ "$(initial_install_mode)" == "proxy" ]]

if output="$(ensure_tun_available 2>&1)"; then
  printf 'ensure_tun_available unexpectedly succeeded\n' >&2
  exit 1
fi
grep -q 'pct set <CTID> --dev0 path=/dev/net/tun' <<<"$output"
grep -q 'lxc.cgroup2.devices.allow: c 10:200 rwm' <<<"$output"

if output="$(doctor_cmd 2>&1)"; then
  printf 'doctor_cmd unexpectedly reported TUN ready\n' >&2
  exit 1
fi
grep -q 'Proxy mode is available' <<<"$output"

XRAY_TUI_CONTAINER=none
[[ "$(initial_install_mode)" == "tun" ]]

(
  XRAY_TUI_CONTAINER=lxc
  tun_device_usable() { return 0; }
  has_cap_net_admin() { return 0; }
  [[ "$(initial_install_mode)" == "tun" ]]
)

printf 'lxc tests: OK\n'
