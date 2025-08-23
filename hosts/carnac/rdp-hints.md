# Complete gnome-remote-desktop Configuration Summary

## Prerequisites
- **Desktop Environment**: Ubuntu Desktop must be installed
  ```bash
  sudo apt install ubuntu-desktop
  ```
  Without a desktop environment, RDP has nothing to connect to.

## Systemd Service Status
- **System service** (`gnome-remote-desktop.service`): **DISABLED**
- **User service** (`systemctl --user gnome-remote-desktop.service`): **MASKED** 
- **User headless service** (`gnome-remote-desktop-headless.service`): **ENABLED** and **ACTIVE**
  - Running since: Fri 2025-08-22 03:42:44 UTC (16+ hours)
  - Process: `/usr/libexec/gnome-remote-desktop-daemon --headless` (PID 3653)

## grdctl Status (Three Contexts)
1. **User/Default** (`grdctl status`):
   - RDP: **ENABLED**, Port 3389
   - Credentials: Empty (no username/password shown)
   - Certs: `~/.local/share/gnome-remote-desktop/certificates/`

2. **Headless** (`grdctl --headless status`):
   - RDP: **ENABLED**, Port 3389  
   - Credentials: **SET** (hidden, stored in keyfile)
   - Certs: `~/.local/share/gnome-remote-desktop/certificates/`
   - Using GKeyFile fallback (no TPM)

3. **System** (`grdctl --system status`):
   - RDP: **DISABLED**
   - Credentials: Set but unused
   - Certs: `/var/lib/gnome-remote-desktop/.local/share/gnome-remote-desktop/certificates/`

## Network Configuration
- **Port 3389**: Listening (bound by gnome-remote-desktop-daemon --headless)
- **iptables**: ACCEPT rule for TCP 3389 from all sources
- subnet security: ACCEPT port 3389 from 100.64.0.0/10

## Certificates
- **User certificates**: `~/.local/share/gnome-remote-desktop/certificates/rdp-tls.{crt,key}`
- **System certificates**: `/var/lib/gnome-remote-desktop/.local/share/gnome-remote-desktop/certificates/` (unused)

## Session Requirements
- **Autologin**: **ENABLED** in `/etc/gdm3/custom.conf`
- **Screen lock**: **DISABLED** (`gsettings: lock-enabled=false`)
- **Display server**: Wayland (not disabled)

## Authentication
- **RDP Credentials**: Stored in `~/.config/gnome-remote-desktop-rdp-credentials`
- **Method**: GKeyFile (TPM not available)

