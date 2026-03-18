#!/usr/bin/env bash
set -euo pipefail

# Setup script for GNOME Remote Desktop headless mode on a cloud VM.
# Configures GDM autologin + TimedLogin and the user-level --headless service.
#
# Usage: sudo ./setup-headless-rdp.sh <username> [rdp_username] [rdp_password]
#   - If rdp_username/rdp_password are omitted, you'll be prompted.
#   - Must be run as root (needs to modify GDM config and systemd units).

AUTOLOGIN_USER="${1:?Usage: $0 <username> [rdp_username] [rdp_password]}"
RDP_USER="${2:-}"
RDP_PASS="${3:-}"
TIMED_LOGIN_DELAY=5

if [[ $EUID -ne 0 ]]; then
    echo "Error: must run as root" >&2
    exit 1
fi

if ! id "$AUTOLOGIN_USER" &>/dev/null; then
    echo "Error: user '$AUTOLOGIN_USER' does not exist" >&2
    exit 1
fi

AUTOLOGIN_UID=$(id -u "$AUTOLOGIN_USER")

if [[ -z "$RDP_USER" ]]; then
    read -rp "RDP username: " RDP_USER
fi
if [[ -z "$RDP_PASS" ]]; then
    read -rsp "RDP password: " RDP_PASS
    echo
fi

echo "==> Checking for existing headless RDP setup..."

HEADLESS_STATUS=$(sudo -u "$AUTOLOGIN_USER" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${AUTOLOGIN_UID}/bus" \
    systemctl --user is-enabled gnome-remote-desktop-headless.service 2>/dev/null || true)

HEADLESS_ACTIVE=$(sudo -u "$AUTOLOGIN_USER" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${AUTOLOGIN_UID}/bus" \
    systemctl --user is-active gnome-remote-desktop-headless.service 2>/dev/null || true)

if [[ "$HEADLESS_ACTIVE" == "active" ]]; then
    echo "    Headless service is already running. Checking port..."
    if ss -tlnp | grep -q ':3389'; then
        echo "    Port 3389 is already listening — setup appears functional."
        read -rp "    Continue anyway and re-apply config? [y/N] " REPLY
        [[ "$REPLY" =~ ^[Yy]$ ]] || exit 0
    fi
elif [[ "$HEADLESS_STATUS" == "enabled" ]]; then
    echo "    Headless service is enabled but not running."
fi

# --- Step 1: Clean up system-mode artifacts ---
echo "==> Cleaning up system-mode artifacts..."

# Revert system grd.conf to package default (remove if it has custom config)
if [[ -f /etc/gnome-remote-desktop/grd.conf ]]; then
    SYSTEM_CONF=$(cat /etc/gnome-remote-desktop/grd.conf)
    PACKAGE_DEFAULT=$(cat /usr/share/gnome-remote-desktop/grd.conf 2>/dev/null || true)
    if [[ "$SYSTEM_CONF" != "$PACKAGE_DEFAULT" ]]; then
        echo "    Removing custom /etc/gnome-remote-desktop/grd.conf"
        rm /etc/gnome-remote-desktop/grd.conf
    else
        echo "    /etc/gnome-remote-desktop/grd.conf matches package default, leaving alone"
    fi
fi

# Remove stale system-mode credentials
SYSTEM_CREDS="/var/lib/gnome-remote-desktop/.local/share/gnome-remote-desktop/credentials.ini"
if [[ -f "$SYSTEM_CREDS" ]]; then
    echo "    Removing stale system-mode credentials"
    rm "$SYSTEM_CREDS"
fi

# Disable system-level gnome-remote-desktop service
systemctl disable gnome-remote-desktop.service 2>/dev/null || true
systemctl stop gnome-remote-desktop.service 2>/dev/null || true
echo "    System-level gnome-remote-desktop.service disabled"

# --- Step 1b: Remove stale monitors.xml ---
# Mutter crashes (SIGSEGV) if monitors.xml contains modes that don't match
# what the RDP virtual monitor supports. The headless fix script uses temporary
# config (method 1), so no persistent monitors.xml is needed.
MONITORS_XML="/home/${AUTOLOGIN_USER}/.config/monitors.xml"
if [[ -f "$MONITORS_XML" ]]; then
    echo "    Removing stale $MONITORS_XML"
    rm -f "$MONITORS_XML"
fi

# --- Step 2: Configure GDM autologin + TimedLogin ---
echo "==> Configuring GDM autologin..."

GDM_CONF="/etc/gdm3/custom.conf"
if [[ ! -f "$GDM_CONF" ]]; then
    echo "Error: $GDM_CONF not found — is gdm3 installed?" >&2
    exit 1
fi

# Write a clean [daemon] section preserving other sections
python3 - "$GDM_CONF" "$AUTOLOGIN_USER" "$TIMED_LOGIN_DELAY" <<'PYEOF'
import sys, configparser

conf_path, user, delay = sys.argv[1], sys.argv[2], sys.argv[3]

config = configparser.ConfigParser(allow_no_value=True)
config.optionxform = str  # preserve case
config.read(conf_path)

if not config.has_section('daemon'):
    config.add_section('daemon')

config.set('daemon', 'AutomaticLoginEnable', 'true')
config.set('daemon', 'AutomaticLogin', user)
config.set('daemon', 'TimedLoginEnable', 'true')
config.set('daemon', 'TimedLogin', user)
config.set('daemon', 'TimedLoginDelay', delay)

for section in ['security', 'debug']:
    if not config.has_section(section):
        config.add_section(section)

with open(conf_path, 'w') as f:
    f.write('# GDM configuration storage\n')
    f.write('# Managed by setup-headless-rdp.sh\n\n')
    config.write(f)

PYEOF

echo "    GDM configured: AutomaticLogin=$AUTOLOGIN_USER, TimedLogin=${TIMED_LOGIN_DELAY}s delay"

# --- Step 3: Configure user-level headless RDP ---
echo "==> Configuring user-level headless RDP service..."

run_as_user() {
    sudo -u "$AUTOLOGIN_USER" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${AUTOLOGIN_UID}/bus" \
        XDG_RUNTIME_DIR="/run/user/${AUTOLOGIN_UID}" \
        "$@"
}

# Mask the non-headless user service (conflicts with headless)
run_as_user systemctl --user mask gnome-remote-desktop.service 2>/dev/null || true

# Enable headless service
run_as_user systemctl --user enable gnome-remote-desktop-headless.service 2>/dev/null || true

# Set RDP credentials via grdctl
run_as_user grdctl --headless rdp enable 2>/dev/null || true
run_as_user grdctl --headless rdp set-credentials "$RDP_USER" "$RDP_PASS"
echo "    RDP credentials set for headless mode"

# --- Step 4: Restart GDM ---
echo "==> Restarting GDM..."
systemctl restart gdm

echo "==> Waiting for autologin and headless RDP to start..."
for i in $(seq 1 15); do
    sleep 2
    if ss -tlnp | grep -q ':3389'; then
        echo ""
        echo "==> Success! RDP is listening on port 3389"
        echo ""
        echo "Setup complete:"
        echo "  - GDM autologin: $AUTOLOGIN_USER (TimedLogin re-fires on session drop)"
        echo "  - Headless RDP: enabled on port 3389"
        echo "  - System RDP service: disabled"
        echo ""
        echo "Connect with any RDP client to port 3389."
        exit 0
    fi
    printf "."
done

echo ""
echo "Warning: port 3389 not listening after 30s. Check with:"
echo "  systemctl --user status gnome-remote-desktop-headless"
echo "  journalctl --user -u gnome-remote-desktop-headless"
exit 1
