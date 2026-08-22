# OpenVPN3 Manager

A Noctalia plugin for driving [OpenVPN 3 Linux](https://github.com/OpenVPN/openvpn3-linux)
sessions from the bar, the control center or a panel.

## Architecture

Every `openvpn3` call lives in the headless `[[service]]`. The three UI entries
are thin clients: they mirror the service's published `status` and drive it
through the `command` channel, so a session can be toggled even with no widget
placed on a bar.

| Entry | Type | File | Purpose |
| --- | --- | --- | --- |
| `service` | service | `vpn_service.luau` | Polls the session manager, owns all shell-outs |
| `status` | widget | `widget.luau` | Bar tile: state, profile name, tooltip |
| `toggle` | shortcut | `shortcut.luau` | Control-center quick toggle |
| `manager` | panel | `panel.luau` | Profile picker and session details |

Shared state published by the service:

| Key | Meaning |
| --- | --- |
| `status` | `{ available, connected, busy, profile, device, statusText, ip, bytesIn, bytesOut, error, profiles }` |
| `command` | `{ action = "connect" \| "disconnect" \| "toggle" \| "refresh", profile?, nonce }` |

## Requirements

- `openvpn3` (OpenVPN 3 Linux) on `PATH`, with at least one imported profile
- Noctalia plugin API 9+

Import a profile first, otherwise the plugin has nothing to connect to:

```bash
openvpn3 config-import --config ~/vpn/profile.ovpn --name MyVPN --persistent
```

## Usage

- **Bar widget** — left click connects or disconnects, right click opens the panel.
- **Control center** — add the toggle from Settings → Control Center shortcuts.
- **Panel** — `noctalia msg panel-toggle kuznetsov17/openvpn3-manager:manager`

### Credentials

A background process cannot answer a password or 2FA prompt. Certificate-only
profiles connect silently; for anything that asks for credentials, turn on
**Connect in a terminal** so `openvpn3 session-start` runs where you can type.

## IPC

```bash
# Connect to a specific profile
noctalia msg plugin kuznetsov17/openvpn3-manager:status focused connect "MyVPN"

# Disconnect the active session
noctalia msg plugin kuznetsov17/openvpn3-manager:status focused disconnect

# Re-read profiles and session state
noctalia msg plugin kuznetsov17/openvpn3-manager:status focused refresh
```

## Settings

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `poll_interval` | int | `5` | Seconds between session-manager polls |
| `default_profile` | string | `""` | Profile used by the widget/shortcut toggle; empty means the first one |
| `show_label` | bool | `true` | Show the active profile name next to the glyph |
| `show_traffic` | bool | `true` | Include byte counters in the tooltip |
| `hide_when_disconnected` | bool | `false` | Hide the bar widget while no session is active |
| `connect_in_terminal` | bool | `false` | Run `session-start` in a terminal for credential prompts |

## Commands used

```
openvpn3 sessions-list                        # active sessions
openvpn3 configs-list --verbose               # imported profiles + D-Bus paths
openvpn3 session-stats --config N --json      # byte counters
openvpn3 session-start --config-path P        # connect
openvpn3 session-manage --session-path P -D   # disconnect
ip -4 -o addr show dev <tun>                  # assigned VPN address
```

## License

MIT
