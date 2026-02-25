# WireGuard Module

WireGuard VPN tunnel management for Windows.

## Commands

```powershell
wgstart     # Start tunnel
wgstop      # Stop tunnel
wgstatus    # Show status
wgrestart   # Restart tunnel
```

## Install/Reinstall Tunnel (Admin Required)

```powershell
# Uninstall existing
wireguard /uninstalltunnelservice home

# Install from .conf
wireguard /installtunnelservice "C:\path\to\home.conf"

# Verify and start
Get-Service WireGuardTunnel*
wgstart
```

## Config

`~/.config/WireGuard/config.json`:

```json
{
  "wireguard": {
    "wireguardPath": "C:\\Program Files\\WireGuard\\wg.exe",
    "defaultTunnel": "home"
  }
}
```
