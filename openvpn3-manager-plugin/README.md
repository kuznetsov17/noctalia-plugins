# OpenVPN3 Manager

A Noctalia plugin for managing OpenVPN3 VPN connections directly from the status bar.

## Features

- **Status Bar Widget** - Shows current VPN connection status and active profile
- **Quick Toggle Shortcut** - Fast connect/disconnect from the Control Center
- **Management Panel** - Full VPN profile management with connection details
- **Real-time Updates** - Live refresh of connection status
- **Traffic Stats** - Display data usage (in/out) when connected

## Installation

1. Copy this plugin to your Noctalia plugins directory
2. Restart Noctalia
3. Add the "OpenVPN3 Manager" widget from the Add-widget picker

## Usage

### Bar Widget
- **Click** - Shows active profile name and connection status
- **Settings** - Configure auto-refresh and IP display options
- **Tooltip** - Hover to see current connection details

### Quick Toggle
1. Add from Settings → Control Center shortcuts
2. **Left-click** - Toggle VPN on/off
3. **Right-click** - Open manager panel

### Management Panel
Open with: `noctalia msg panel-toggle openvpn3/manager:manager`

Features:
- View active connection and statistics
- Select and connect to VPN profiles
- Disconnect from current connection
- Enable auto-connect on startup
- Refresh available profiles
- Import new VPN profiles

## IPC Commands

```bash
# Connect to a specific profile
noctalia msg plugin openvpn3/manager:status connect "ProfileName"

# Disconnect from current profile
noctalia msg plugin openvpn3/manager:status disconnect

# Refresh connection status
noctalia msg plugin openvpn3/manager:status refresh
```

## Settings

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `auto_refresh` | bool | `true` | Automatically refresh VPN status every 5 seconds |
| `show_ip` | bool | `false` | Display the assigned VPN IP address in tooltip |

## Requirements

- OpenVPN3 command-line client (`openvpn3`) must be installed
- Noctalia plugin API 9+

## Plugin Structure

| Entry | Type | File | Purpose |
| --- | --- | --- | --- |
| `status` | widget | `widget.luau` | Status bar widget |
| `toggle` | shortcut | `shortcut.luau` | Control Center quick toggle |
| `manager` | panel | `panel.luau` | VPN connection management |

## State Management

The plugin uses Noctalia's state system to synchronize VPN status across entries:

- `vpn_connected` - Boolean indicating if VPN is active
- `vpn_profile` - Currently connected profile name
- `vpn_ip` - Assigned VPN IP address
- `vpn_time` - Duration of current connection
- `vpn_traffic_in` - Data received (bytes)
- `vpn_traffic_out` - Data sent (bytes)

## Roadmap

- [ ] Profile import UI
- [ ] Connection statistics/graphs
- [ ] VPN protocol selection
- [ ] Per-profile settings
- [ ] Connection logs
- [ ] Automatic reconnect on disconnect
- [ ] Kill switch option

## License

MIT

## Author

VPN Community
