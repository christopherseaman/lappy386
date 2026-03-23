#!/usr/bin/env bash
set -euo pipefail

# Setup script for GNOME Remote Desktop headless mode.
# Configures GDM autologin + TimedLogin and the user-level --headless service.
#
# Usage: sudo ./setup-headless-rdp.sh [--auto] [username] [rdp_password]
#   - --auto: non-interactive mode, skips setup if already functional
#   - Defaults to $SUDO_USER (or $USER) if username is omitted.
#   - Generates a random 12-char password if rdp_password is omitted.
#   - Must be run as root (needs to modify GDM config and systemd units).

AUTO_MODE=false
if [[ "${1:-}" == "--auto" ]]; then
  AUTO_MODE=true
  shift
fi

AUTOLOGIN_USER="${1:-${SUDO_USER:-$USER}}"
RDP_USER="$AUTOLOGIN_USER"
RDP_PASS="${2:-}"
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

## Check for existing setup
HEADLESS_ACTIVE=$(sudo -u "$AUTOLOGIN_USER" \
  DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${AUTOLOGIN_UID}/bus" \
  systemctl --user is-active gnome-remote-desktop-headless.service 2>/dev/null || true)

if [[ "$HEADLESS_ACTIVE" == "active" ]] && ss -tlnp | grep -q ':3389'; then
  if [[ "$AUTO_MODE" == "true" ]]; then
    echo "    Headless RDP already running, skipped."
    exit 0
  fi
  echo "    Headless RDP is already running on port 3389."
  read -rp "    Continue anyway and re-apply config? [y/N] " REPLY
  [[ "$REPLY" =~ ^[Yy]$ ]] || exit 0
fi

## Resolve RDP password
PASS_FILE="/home/${AUTOLOGIN_USER}/.rdp_pass"
if [[ -z "$RDP_PASS" && -f "$PASS_FILE" ]]; then
  RDP_PASS=$(cat "$PASS_FILE")
  echo "    Reusing existing RDP password"
elif [[ -z "$RDP_PASS" ]]; then
  RDP_PASS=$(head -c 100 /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 12)
  echo "    Generated RDP password"
fi

export RDP_PASSWORD="$RDP_PASS"

echo "$RDP_PASS" > "$PASS_FILE"
chown "$AUTOLOGIN_USER":"$AUTOLOGIN_USER" "$PASS_FILE"
chmod 600 "$PASS_FILE"

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

# Disable xrdp if installed (conflicts with GNOME headless RDP on port 3389)
if systemctl list-unit-files xrdp.service &>/dev/null; then
  systemctl stop xrdp.service 2>/dev/null || true
  systemctl disable xrdp.service 2>/dev/null || true
  systemctl stop xrdp-sesman.service 2>/dev/null || true
  systemctl disable xrdp-sesman.service 2>/dev/null || true
  echo "    xrdp services stopped and disabled"
fi

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

if [[ -f "/etc/gdm3/custom.conf" ]]; then
  GDM_CONF="/etc/gdm3/custom.conf"
elif [[ -f "/etc/gdm3/daemon.conf" ]]; then
  GDM_CONF="/etc/gdm3/daemon.conf"
else
  echo "Error GDM config not found /etc/gdm3/\{custom.conf,daemon.conf\}"
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

# Ensure TLS certificate and key exist for RDP
USER_GRD_DIR="/home/${AUTOLOGIN_USER}/.local/share/gnome-remote-desktop"
TLS_CERT="${USER_GRD_DIR}/rdp-tls.crt"
TLS_KEY="${USER_GRD_DIR}/rdp-tls.key"

NEED_TLS=false
if [[ ! -f "$TLS_CERT" || ! -f "$TLS_KEY" ]]; then
  NEED_TLS=true
elif ! openssl x509 -in "$TLS_CERT" -noout 2>/dev/null; then
  echo "    Existing TLS certificate is invalid, regenerating"
  NEED_TLS=true
fi

if [[ "$NEED_TLS" == "true" ]]; then
  echo "    Generating self-signed TLS certificate for RDP..."
  sudo -u "$AUTOLOGIN_USER" mkdir -p "$USER_GRD_DIR"
  sudo -u "$AUTOLOGIN_USER" openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
    -sha256 -days 3650 -nodes \
    -keyout "$TLS_KEY" -out "$TLS_CERT" \
    -subj "/CN=$(hostname)" 2>/dev/null
  chmod 600 "$TLS_KEY"
  chown "$AUTOLOGIN_USER":"$AUTOLOGIN_USER" "$TLS_CERT" "$TLS_KEY"
  echo "    TLS certificate generated"
fi

run_as_user grdctl --headless rdp set-tls-cert "$TLS_CERT"
run_as_user grdctl --headless rdp set-tls-key "$TLS_KEY"
echo "    TLS certificate configured for headless RDP"

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
    echo "  - RDP display fix service: installed"
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
