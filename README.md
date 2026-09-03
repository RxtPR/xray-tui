# xray-tui

Текстовый менеджер профилей Xray для Debian. Импортирует ссылки `vless://`,
`vmess://`, `trojan://` и `ss://`, проверяет конфигурацию средствами Xray,
переключает профили через systemd и показывает состояние и журнал. Поддерживает
локальный Proxy и полноценный системный TUN.

## Установка

```bash
chmod +x xray-tui
sudo ./xray-tui install
sudo xray-tui
```

Установщик автоматически ставит `python3`, `dialog`, `curl`, `iproute2`,
сертификаты и прочие зависимости через `apt`. Если Xray Core отсутствует, он
загружается вместе с geodata официальным установщиком проекта XTLS. При повторной
установке Core обновляется до актуальной стабильной версии, необходимой для
автоматического TUN. Архитектура определяется автоматически; архив Xray
проверяется штатными контрольными суммами официального установщика.
Созданный им стандартный `xray.service` отключается, поскольку профилями управляет
отдельный `xray-tui.service`.

## Командная строка

```bash
sudo xray-tui import 'vless://…'
sudo xray-tui list
sudo xray-tui up имя-профиля
sudo xray-tui mode tun
sudo xray-tui status
sudo xray-tui probe
sudo xray-tui logs 200
sudo xray-tui down
```

Чтобы секрет из URI не был виден в списке процессов, передавайте ссылку через
стандартный ввод: `printf '%s\n' "$URI" | sudo xray-tui import`.
В интерактивном TUI ссылка отображается полностью, чтобы её можно было проверить
и исправить перед импортом.

Профили находятся в `/etc/xray-tui/profiles` с правами `0600`. Перед
сохранением и каждым запуском выполняется `xray run -test`.

## Режимы подключения

Режим выбирается в TUI или командой:

```bash
sudo xray-tui mode proxy
sudo xray-tui mode tun
```

В режиме `proxy` Xray слушает только localhost:

- SOCKS5: `127.0.0.1:10808` (включая UDP);
- HTTP proxy: `127.0.0.1:10809`.

В режиме `tun` Xray создаёт интерфейс `xray0`, а `xray-tui` назначает ему адреса
и направляет весь IPv4- и IPv6-трафик через отдельную таблицу маршрутизации.
Адрес VPN-сервера и локальные сети исключаются из туннеля, чтобы избежать петли
и сохранить доступ к LAN. При остановке сервиса правила, таблица маршрутов и
изменения `rp_filter` автоматически удаляются. Для TUN необходимы root и доступное устройство
`/dev/net/tun`; некоторые VPS и контейнеры требуют включить TUN в панели хостинга.
Временное состояние правил хранится в защищённом systemd-каталоге
`/run/xray-tui` и удаляется вместе с сервисом.
При работе по удалённому SSH включение полного TUN может изменить маршрут уже
открытого сеанса; предусмотрите запасной доступ к машине через консоль хостинга.

Локальные SOCKS5/HTTP-порты остаются доступны и в TUN-режиме.

Поддерживаются наиболее распространённые транспорты Xray: TCP, WebSocket,
gRPC, HTTPUpgrade, XHTTP/SplitHTTP, HTTP/2 и mKCP, а также TLS и REALITY.

## Удаление

```bash
sudo systemctl disable --now xray-tui.service
sudo rm /etc/systemd/system/xray-tui.service /usr/local/bin/xray-tui
sudo systemctl daemon-reload
```

Профили при этом остаются в `/etc/xray-tui` и удаляются только вручную.

---

# English

`xray-tui` is a terminal-based Xray profile manager for Debian. It imports
`vless://`, `vmess://`, `trojan://`, and `ss://` connection URIs, validates
generated configurations with Xray Core, switches profiles through systemd,
and provides status and journal views. Both local proxy and system-wide TUN
modes are supported.

## Features

- Interactive terminal interface powered by `dialog`.
- VLESS, VMess, Trojan, and Shadowsocks URI import.
- TLS, REALITY, TCP, WebSocket, gRPC, HTTPUpgrade, XHTTP/SplitHTTP, HTTP/2,
  and mKCP support.
- Multiple named profiles with safe permissions.
- Local SOCKS5 and HTTP proxy mode.
- System-wide IPv4/IPv6 TUN mode.
- systemd integration and optional startup at boot.
- Connection status, external IP check, and journal viewer.
- Automatic Xray Core and geodata installation or update.

## Installation

```bash
chmod +x xray-tui
sudo ./xray-tui install
sudo xray-tui
```

The installer uses `apt` to install Python 3, `dialog`, `curl`, `iproute2`, CA
certificates, and other required packages. It downloads Xray Core and geodata
using the official XTLS installer. The machine architecture and current stable
release are detected automatically, and upstream checksums are used to verify
the downloaded Xray archive.

The default `xray.service` created by the upstream installer is disabled because
profiles are managed by the dedicated `xray-tui.service` unit.

## Command-line usage

```bash
sudo xray-tui import 'vless://…'
sudo xray-tui list
sudo xray-tui up profile-name
sudo xray-tui mode tun
sudo xray-tui status
sudo xray-tui probe
sudo xray-tui logs 200
sudo xray-tui down
```

Passing a connection URI as an argument may expose it in the process list. To
avoid that, pass it through standard input:

```bash
printf '%s\n' "$URI" | sudo xray-tui import
```

The interactive TUI intentionally displays the complete URI so it can be
reviewed and corrected before import.

Profiles are stored in `/etc/xray-tui/profiles` with `0600` permissions. Every
generated configuration is checked with `xray run -test` before it is saved or
activated.

## Connection modes

Select a mode from the TUI or use the command line:

```bash
sudo xray-tui mode proxy
sudo xray-tui mode tun
```

### Proxy mode

Only applications configured to use one of these local proxies are routed
through Xray:

- SOCKS5: `127.0.0.1:10808`, including UDP support.
- HTTP proxy: `127.0.0.1:10809`.

### TUN mode

Xray creates the `xray0` interface, and `xray-tui` assigns its addresses and
routes system-wide IPv4 and IPv6 traffic through a dedicated routing table. The
Xray server address and private networks bypass the tunnel to prevent routing
loops and preserve LAN access.

Routing rules, the dedicated table, and temporary `rp_filter` changes are
automatically reverted when the service stops. Runtime state is kept in the
protected `/run/xray-tui` systemd directory.

TUN mode requires root privileges and an available `/dev/net/tun` device. Some
VPS providers and container platforms require TUN to be enabled separately.
Enabling a full tunnel over a remote SSH session may change that session's
route, so make sure you have backup console access.

The local SOCKS5 and HTTP listeners remain available in TUN mode.

## Verifying TUN mode

```bash
sudo xray-tui status
ip -4 address show xray0
ip -4 rule show
ip route show table 20220
sudo xray-tui probe
```

The expected routing state includes `198.18.0.1/30` on `xray0`, an IP rule for
table `20220`, and a default route through `xray0` in that table.

## Uninstallation

```bash
sudo systemctl disable --now xray-tui.service
sudo rm /etc/systemd/system/xray-tui.service /usr/local/bin/xray-tui
sudo systemctl daemon-reload
```

Profiles remain in `/etc/xray-tui` and are removed only when explicitly deleted.

## Disclaimer

This is an independent community project and is not affiliated with or endorsed
by the Xray or XTLS projects. Make sure your use complies with the laws and
network policies applicable to you.
