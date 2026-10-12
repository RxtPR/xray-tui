# xray-tui

Текстовый менеджер профилей Xray для Debian. Импортирует ссылки `vless://`,
`vmess://`, `trojan://` и `ss://`, проверяет конфигурацию средствами Xray,
переключает профили через systemd и показывает состояние и журнал. Поддерживает
локальный Proxy, полноценный системный TUN и подписки на списки серверов.
Интерфейс автоматически переключается между русским и английским по языку
системы. Для новых установок режим TUN выбран по умолчанию; в LXC без
проброшенного `/dev/net/tun` установщик безопасно выбирает Proxy.

## Установка

```bash
chmod +x xray-tui
sudo ./xray-tui install
sudo xray-tui
```

Установщик автоматически ставит `python3`, `dialog`, `curl`, `iproute2`,
сертификаты и прочие зависимости через `apt`. Если Xray Core отсутствует, он
загружается вместе с geodata официальным установщиком проекта XTLS. Уже
установленный исправный Core повторно не скачивается, поэтому обновление
`xray-tui` не зависит от доступности GitHub Releases. При первой установке
сетевые ошибки повторяются до трёх раз. Архитектура определяется автоматически; архив Xray
проверяется штатными контрольными суммами официального установщика.
Созданный им стандартный `xray.service` отключается, поскольку профилями управляет
отдельный `xray-tui.service`.

## Командная строка

```bash
sudo xray-tui import 'vless://…'
sudo xray-tui subscription add main 'https://example.com/subscription'
sudo xray-tui subscription refresh main
sudo xray-tui subscription list
sudo xray-tui list
sudo xray-tui up имя-профиля
sudo xray-tui mode tun
sudo xray-tui status
sudo xray-tui doctor
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

## Подписки

Откройте пункт «Управление подписками» в TUI или добавьте источник командой:

```bash
sudo xray-tui subscription add NAME URL
```

Поддерживаются обычные и Base64-кодированные списки ссылок `vless://`,
`vmess://`, `trojan://` и `ss://`. Каждый корректный сервер становится отдельным
профилем с префиксом подписки и появляется в общем меню подключения.

```bash
sudo xray-tui subscription refresh NAME  # обновить одну
sudo xray-tui subscription refresh       # обновить все
sudo xray-tui subscription list
sudo xray-tui subscription delete NAME
```

При обновлении исчезнувшие серверы удаляются. Активный профиль сохраняется до
переключения, чтобы обновление подписки не обрывало текущее соединение. URL и
списки профилей хранятся в `/etc/xray-tui/subscriptions` с правами `0600`.

## Язык интерфейса

Для локалей `ru*` используется русский язык, для остальных — английский.
Язык можно переопределить независимо от системной локали:

```bash
XRAY_TUI_LANG=ru sudo -E xray-tui
XRAY_TUI_LANG=en sudo -E xray-tui
```

## Обновление программы

Проверить ветку `main` репозитория `RxtPR/xray-tui`:

```bash
sudo xray-tui update --check
sudo xray-tui update
```

Для установки без интерактивного подтверждения используйте
`sudo xray-tui update --yes`. Эта же функция доступна через пункт «Проверить
обновления» в главном меню. Перед установкой проверяются идентификатор проекта,
номер версии и Bash-синтаксис загруженного файла. Понижение версии блокируется.

## Режимы подключения

Режим выбирается в TUI или командой:

```bash
sudo xray-tui mode proxy
sudo xray-tui mode tun
```

На новой установке по умолчанию используется `tun`. Исключение — LXC без
доступного TUN-устройства: там установщик выбирает `proxy` и показывает команды
настройки Proxmox. Выбранный режим сохраняется между запусками. Чтобы изменить
начальное значение при автоматической установке, задайте
`XRAY_TUI_DEFAULT_MODE=proxy`.

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

## Proxmox LXC

Proxy-режим работает в LXC без специальной настройки. Для системного TUN
контейнеру требуются `/dev/net/tun` и `CAP_NET_ADMIN`. Проверить готовность:

```bash
sudo xray-tui doctor
```

Если TUN не передан, выполните на узле Proxmox, заменив `<CTID>` на ID
контейнера:

```bash
modprobe tun
pct stop <CTID>
pct set <CTID> --dev0 path=/dev/net/tun
pct start <CTID>
```

На старых версиях Proxmox, где параметр `dev0` недоступен, добавьте в
`/etc/pve/lxc/<CTID>.conf`:

```text
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
```

После изменения полностью остановите и снова запустите контейнер. Установщик
не пытается ослаблять изоляцию LXC изнутри: если TUN недоступен при первой
установке, выбирается Proxy, а после настройки можно выполнить
`sudo xray-tui mode tun`.

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
The interface automatically selects Russian or English based on the system
locale. New installations use TUN mode by default; an LXC container without a
passed-through `/dev/net/tun` safely falls back to Proxy mode.

## Features

- Interactive terminal interface powered by `dialog`.
- VLESS, VMess, Trojan, and Shadowsocks URI import.
- TLS, REALITY, TCP, WebSocket, gRPC, HTTPUpgrade, XHTTP/SplitHTTP, HTTP/2,
  and mKCP support.
- Multiple named profiles with safe permissions.
- Plain-text and Base64 subscription support with per-server selection.
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
using the official XTLS installer when Core is not already available. An
existing working Core is not downloaded again, so updating `xray-tui` does not
depend on GitHub Releases availability. First-time network failures are retried
up to three times. The machine architecture is detected automatically, and upstream checksums are used to verify
the downloaded Xray archive.

The default `xray.service` created by the upstream installer is disabled because
profiles are managed by the dedicated `xray-tui.service` unit.

## Command-line usage

```bash
sudo xray-tui import 'vless://…'
sudo xray-tui subscription add main 'https://example.com/subscription'
sudo xray-tui subscription refresh main
sudo xray-tui list
sudo xray-tui up profile-name
sudo xray-tui mode tun
sudo xray-tui status
sudo xray-tui doctor
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

## Subscriptions

Open **Subscription management** in the TUI or add a source from the command
line:

```bash
sudo xray-tui subscription add NAME URL
```

Plain-text and Base64-encoded lists containing `vless://`, `vmess://`,
`trojan://`, and `ss://` URIs are supported. Every valid server becomes a named
profile with a subscription prefix and appears in the regular connection menu.

```bash
sudo xray-tui subscription refresh NAME  # update one subscription
sudo xray-tui subscription refresh       # update all subscriptions
sudo xray-tui subscription list
sudo xray-tui subscription delete NAME
```

Servers removed upstream are removed locally during refresh. An active profile
is retained until another one is selected, preventing a subscription refresh
from interrupting the current connection. Subscription URLs and profile indexes
are stored under `/etc/xray-tui/subscriptions` with `0600` permissions.

## Interface language

Russian is selected for `ru*` locales; all other locales use English. Override
the detected language independently of the system locale with:

```bash
XRAY_TUI_LANG=ru sudo -E xray-tui
XRAY_TUI_LANG=en sudo -E xray-tui
```

## Application updates

Check the `main` branch of `RxtPR/xray-tui`:

```bash
sudo xray-tui update --check
sudo xray-tui update
```

Use `sudo xray-tui update --yes` to install without an interactive confirmation.
The same action is available through **Check for updates** in the main menu.
Before installation, the downloaded file is checked for the project marker,
version format, and valid Bash syntax. Downgrades are refused.

## Connection modes

Select a mode from the TUI or use the command line:

```bash
sudo xray-tui mode proxy
sudo xray-tui mode tun
```

New installations default to `tun`. The exception is an LXC container without
a usable TUN device: the installer selects `proxy` and prints the required
Proxmox host commands. The selected mode persists across restarts. Set
`XRAY_TUI_DEFAULT_MODE=proxy` to change the initial value during automated
installation.

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

## Proxmox LXC

Proxy mode works in LXC without special host configuration. System-wide TUN
requires both `/dev/net/tun` and `CAP_NET_ADMIN` inside the container. Check the
environment with:

```bash
sudo xray-tui doctor
```

If the TUN device is missing, run the following on the Proxmox host, replacing
`<CTID>` with the container ID:

```bash
modprobe tun
pct stop <CTID>
pct set <CTID> --dev0 path=/dev/net/tun
pct start <CTID>
```

On older Proxmox versions without the `dev0` option, add these lines to
`/etc/pve/lxc/<CTID>.conf`:

```text
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
```

Fully stop and start the container after changing its configuration. The
installer does not weaken LXC isolation from inside the guest: when TUN is not
available during the first installation, it selects Proxy mode. After passing
the device through, enable TUN with `sudo xray-tui mode tun`.

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
