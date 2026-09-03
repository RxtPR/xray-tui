#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../xray-tui
source "$ROOT/xray-tui"

assert_profile() {
  local uri="$1" expected_name="$2" expected_protocol="$3" json
  json="$(parse_uri "$uri" "")"
  JSON="$json" EXPECTED_NAME="$expected_name" EXPECTED_PROTOCOL="$expected_protocol" python3 <<'PY'
import json, os
d=json.loads(os.environ['JSON'])
assert d['name'] == os.environ['EXPECTED_NAME'], d['name']
assert d['config']['outbounds'][0]['protocol'] == os.environ['EXPECTED_PROTOCOL']
assert d['config']['inbounds'][0]['listen'] == '127.0.0.1'
PY
}

assert_profile \
  'vless://11111111-1111-1111-1111-111111111111@example.com:443?encryption=none&security=reality&type=tcp&sni=www.example.com&fp=chrome&pbk=publickey&sid=abcd#Reality' \
  'Reality' 'vless'

assert_profile \
  'trojan://secret@example.org:443?security=tls&type=ws&host=cdn.example.org&path=%2Fws#Trojan' \
  'Trojan' 'trojan'

assert_profile \
  'ss://YWVzLTI1Ni1nY206cGFzc3dvcmQ@example.net:8388#SS' \
  'SS' 'shadowsocks'

vmess_payload="$(python3 - <<'PY'
import base64,json
d={'v':'2','ps':'VMess','add':'example.net','port':'443','id':'11111111-1111-1111-1111-111111111111','aid':'0','scy':'auto','net':'ws','type':'none','host':'cdn.example.net','path':'/x','tls':'tls','sni':'example.net'}
print(base64.b64encode(json.dumps(d).encode()).decode())
PY
)"
assert_profile "vmess://$vmess_payload" 'VMess' 'vmess'

# Xray 26.x определяет формат конфигурации по суффиксу временного файла.
tmp_profile="$(mktemp --suffix=.json /tmp/xray-tui-test.XXXXXX)"
[[ "$tmp_profile" == *.json ]]

parsed="$(parse_uri 'vless://11111111-1111-1111-1111-111111111111@example.com:443?encryption=none&security=tls&sni=example.com#TUN' '')"
PARSED="$parsed" python3 - "$tmp_profile" <<'PY'
import json, os, sys
with open(sys.argv[1], 'w') as f:
    json.dump(json.loads(os.environ['PARSED'])['config'], f)
PY
tun_config="$(render_active_config "$tmp_profile" tun)"
TUN_CONFIG="$tun_config" python3 <<'PY'
import json, os
d=json.loads(os.environ['TUN_CONFIG'])
tun=next(x for x in d['inbounds'] if x['protocol']=='tun')
assert tun['settings']['name'] == 'xray0'
assert tun['settings']['MTU'] == 1500
assert 'autoSystemRoutingTable' not in tun['settings']
assert all(r.get('protocol') != ['bittorrent'] for r in d['routing']['rules'])
PY
rm -f -- "$tmp_profile"

printf 'parser tests: OK\n'
