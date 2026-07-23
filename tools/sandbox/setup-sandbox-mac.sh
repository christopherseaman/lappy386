#!/bin/bash
# Provision a disposable macOS + Xcode Tart VM running Codex, with ~/projects
# shared in and opencode exposed via bridged networking on the configured port. Apple Silicon only.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_NAME="${SANDBOX_VM:-tahoe-xcode}"
GUEST_HOSTNAME="${SANDBOX_GUEST_HOSTNAME:-$VM_NAME}"
IMAGE="ghcr.io/cirruslabs/macos-tahoe-xcode:latest"
WORKSPACE="${SANDBOX_WORKSPACE:-$HOME/projects}"
sanitize_share_name() {
  local value="${1:-projects}"
  value="${value// /_}"
  value="${value//\//_}"
  value="${value//:/_}"
  value="${value//\*/_}"
  value="${value//\?/_}"
  value="${value//\</_}"
  value="${value//\>/_}"
  value="${value//\|/_}"
  value="${value//\"/_}"
  value="${value//\'/_}"
  value="${value//./_}"
  value="${value//../_}"
  value="$(printf "%s" "$value" | tr "[:upper:]" "[:lower:]")"
  value="${value#_}"
  value="${value%_}"
  if [[ -z "$value" ]]; then
    value="projects"
  fi
  printf '%s\n' "$value"
}

if [[ "${SANDBOX_TART_DIR_SPEC:-}" != "" ]]; then
  TART_DIR_PATH="${SANDBOX_TART_DIR_SPEC#*:}"
  TART_DIR_NAME="${SANDBOX_TART_DIR_NAME:-projects}"
  if [[ "$SANDBOX_TART_DIR_SPEC" == *:* ]]; then
    if [[ "${SANDBOX_TART_DIR_SPEC%%:*}" != "" ]]; then
      TART_DIR_NAME="${SANDBOX_TART_DIR_SPEC%%:*}"
    fi
  else
    TART_DIR_PATH="$SANDBOX_TART_DIR_SPEC"
  fi
else
  TART_DIR_NAME="${SANDBOX_TART_DIR_NAME:-projects}"
  TART_DIR_PATH="$WORKSPACE"
fi

TART_DIR_BASENAME="$(sanitize_share_name "$TART_DIR_NAME")"
TART_DIR_SPEC="${TART_DIR_BASENAME}:${TART_DIR_PATH}"
GUEST_WORKSPACE_HINT="/Volumes/My Shared Files/$TART_DIR_BASENAME"
CPU="${SANDBOX_CPU:-8}"
MEM_MB="${SANDBOX_MEM_MB:-16384}"
DISK_GB="${SANDBOX_DISK_GB:-150}"
USE_LAUNCHD="${SANDBOX_LAUNCHD:-1}"
RECREATE_VM="${SANDBOX_RECREATE_VM:-1}"
GUEST_SSH_USER="${SANDBOX_GUEST_SSH_USER:-admin}"
HOST_CLIENT_PUBLIC_KEY="${SANDBOX_CLIENT_PUBLIC_KEY:-$HOME/.ssh/client_key.pub}"
HOST_CLIENT_PRIVATE_KEY="${SANDBOX_CLIENT_PRIVATE_KEY:-${HOST_CLIENT_PUBLIC_KEY%.pub}}"
LAUNCH_LABEL="${SANDBOX_LAUNCHD_LABEL:-com.lappy386.sandbox.macos}"
PORT_FORWARD_LABEL="${SANDBOX_PORT_FORWARD_LAUNCHD_LABEL:-com.lappy386.sandbox.macos.opencode-forward}"
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$LAUNCH_AGENT_DIR/${LAUNCH_LABEL}.plist"
PORT_FORWARD_PLIST_PATH="$LAUNCH_AGENT_DIR/${PORT_FORWARD_LABEL}.plist"
LOG_DIR="$HOME/Library/Logs/lappy386-sandbox"
OPENCODE_MODE="${1:-${OPENCODE_MODE:-serve}}"
LAUNCHD_DOMAIN="gui/$(id -u)"
GUEST_AUTH_KEYS_DIR="/Users/$GUEST_SSH_USER/.ssh"
GUEST_AUTH_KEYS="$GUEST_AUTH_KEYS_DIR/authorized_keys"
GUEST_KEY_STAGING="/tmp/lappy386-host-client-key.pub"
OPENCODE_CONFIG="$SCRIPT_DIR/../artifacts/opencode-config.json"
OPENCODE_LAUNCH_LABEL="${SANDBOX_OPENCODE_LAUNCHD_LABEL:-com.lappy386.opencode}"
OPENCODE_PORT="4096"
OPENCODE_HOST_PORT="${SANDBOX_OPENCODE_HOST_PORT:-49152}"
OPENCODE_HOST_BIND_ADDRESS="${SANDBOX_OPENCODE_HOST_BIND_ADDRESS:-0.0.0.0}"
TART_BRIDGE_INTERFACE="${SANDBOX_TART_BRIDGE_INTERFACE:-en0}"

case "$OPENCODE_MODE" in
  web|serve|server)
    ;;
  *)
    echo "Invalid OPENCODE_MODE '$OPENCODE_MODE'. Use: serve (default), web, or server (alias for serve)." >&2
    exit 1
    ;;
esac
if [[ ! "$GUEST_HOSTNAME" =~ ^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$ ]]; then
  echo "Invalid SANDBOX_GUEST_HOSTNAME '$GUEST_HOSTNAME'." >&2
  exit 1
fi
if [[ "$OPENCODE_MODE" == "server" ]]; then
  OPENCODE_MODE="serve"
fi

if command -v python3 >/dev/null 2>&1; then
  OPENCODE_CONFIG_PORT="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["server"]["port"])' "$OPENCODE_CONFIG" 2>/dev/null || true)"
  if [[ -n "${OPENCODE_CONFIG_PORT}" ]]; then
    OPENCODE_PORT="$OPENCODE_CONFIG_PORT"
  fi
fi
if [[ "${2:-}" != "" ]]; then
  OPENCODE_HOST_PORT="${2}"
fi
TART_NETWORK_ARGS=(--net-bridged "$TART_BRIDGE_INTERFACE")

if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
  echo "This sandbox requires macOS on Apple Silicon." >&2
  exit 1
fi

wait_for_tart_exec() {
  local attempts="${1:-60}"
  while (( attempts > 0 )); do
    if tart exec "$VM_NAME" /bin/sh -lc 'echo ok' >/dev/null 2>&1; then
      return 0
    fi
    attempts=$(( attempts - 1 ))
    sleep 1
  done
  echo "tart exec is not available in '$VM_NAME' after start; skipping key provisioning." >&2
  return 1
}

provision_client_key() {
  if [[ ! -f "$HOST_CLIENT_PUBLIC_KEY" ]]; then
    echo "Skipping VM key provisioning: missing $HOST_CLIENT_PUBLIC_KEY" >&2
    return 0
  fi

  if ! wait_for_tart_exec 90; then
    return 0
  fi

  printf '%s\n' "$(cat "$HOST_CLIENT_PUBLIC_KEY")" | \
    tart exec -i "$VM_NAME" /bin/sh -lc "cat > \"$GUEST_KEY_STAGING\"" || {
      echo "Failed to stage public key inside '$VM_NAME'." >&2
      return 0
    }

  tart exec "$VM_NAME" /bin/sh -lc "mkdir -p '$GUEST_AUTH_KEYS_DIR'; touch '$GUEST_AUTH_KEYS'; chmod 700 '$GUEST_AUTH_KEYS_DIR'; chmod 600 '$GUEST_AUTH_KEYS'; \
    if ! grep -qxF -f '$GUEST_KEY_STAGING' '$GUEST_AUTH_KEYS'; then \
      cat '$GUEST_KEY_STAGING' >> '$GUEST_AUTH_KEYS'; \
    fi; rm -f '$GUEST_KEY_STAGING'" || {
    echo "Failed to merge public key into $GUEST_AUTH_KEYS in '$VM_NAME'." >&2
    return 0
  }

  echo "Provisioned host SSH key from $HOST_CLIENT_PUBLIC_KEY into $VM_NAME:$GUEST_AUTH_KEYS."
}

provision_guest_state() {
  if ! wait_for_tart_exec 120; then
    return 0
  fi

  if ! tart exec -i "$VM_NAME" /bin/sh -lc 'mkdir -p "$HOME/.config/opencode" && cat > "$HOME/.config/opencode/opencode.json"' < "$OPENCODE_CONFIG"; then
    echo "Failed to copy opencode config into guest." >&2
  fi

  local merged_config
  merged_config="$(mktemp)"
  cp "$HOME/.codex/config.toml" "$merged_config" 2>/dev/null || : > "$merged_config"

  if ! uv run --managed-python --python 3.11 --script "$SCRIPT_DIR/../merge-codex-config.py" sandbox "$merged_config"; then
    echo "Codex config merge failed; using unmodified config." >&2
  fi

  tart exec -i "$VM_NAME" /bin/sh -lc 'mkdir -p "$HOME/.codex" && cat > "$HOME/.codex/config.toml"' < "$merged_config" || {
    echo "Failed to copy Codex config into guest." >&2
    rm -f "$merged_config"
    return 0
  }

  tart exec "$VM_NAME" /bin/sh -lc '
    set -e
    current=$(command -v codex || true)
    if [ "$current" != "$HOME/.local/bin/codex" ]; then
      if command -v brew >/dev/null 2>&1; then
        brew uninstall --cask codex >/dev/null 2>&1 || true
      fi
    fi

    current=$(command -v codex || true)
    if [ "$current" = "$HOME/.local/bin/codex" ]; then
      exit 0
    fi
    CODEX_INSTALL_DIR="$HOME/.local/bin" CODEX_NON_INTERACTIVE=true curl -fsSL https://chatgpt.com/codex/install.sh | sh
    CODEX_BIN="$HOME/.local/bin/codex"
    if [ ! -x "$CODEX_BIN" ]; then
      echo "codex installer did not create $CODEX_BIN" >&2
      exit 1
    fi
  ' || {
    echo "Codex install failed inside guest; continuing to keep VM up." >&2
  }

  rm -f "$merged_config"
}

configure_guest_hostname() {
  wait_for_tart_exec 120
  tart exec "$VM_NAME" /usr/bin/sudo -n /usr/sbin/scutil --set LocalHostName "$GUEST_HOSTNAME"
}

start_guest_opencode() {
  wait_for_tart_exec 180

  tart exec "$VM_NAME" /bin/sh -lc 'set -e
    mkdir -p "$HOME/.local/bin" "$HOME/.local/share/opencode" "$HOME/Library/LaunchAgents"
    if [ ! -x "$HOME/.opencode/bin/opencode" ]; then
      curl -fsSL https://opencode.ai/install | bash
    fi

    if [ ! -f "$HOME/.zprofile" ]; then
      : > "$HOME/.zprofile"
    fi
    if ! grep -qxF "export PATH=\"\$HOME/.opencode/bin:\$HOME/.local/bin:\$PATH\"" "$HOME/.zprofile" >/dev/null 2>&1; then
      echo "export PATH=\"\$HOME/.opencode/bin:\$HOME/.local/bin:\$PATH\"" >> "$HOME/.zprofile"
    fi

    OPENCODE_BIN="$HOME/.opencode/bin/opencode"
    if [ ! -x "$OPENCODE_BIN" ] && command -v opencode >/dev/null 2>&1; then
      OPENCODE_BIN="$(command -v opencode)"
    fi
    if [ -x "$OPENCODE_BIN" ]; then
      ln -sf "$OPENCODE_BIN" "$HOME/.local/bin/opencode"
    fi

    if [ ! -x "$OPENCODE_BIN" ]; then
      echo "opencode install failed; skipping startup."
      exit 0
    fi

    OPENCODE_LOG_PATH="$HOME/.local/share/opencode/web.log"
    OPENCODE_MODE_BIN_ARGS="serve"
    case '"$OPENCODE_MODE"' in
      web) OPENCODE_MODE_BIN_ARGS="web" ;;
      serve|server) OPENCODE_MODE_BIN_ARGS="serve" ;;
    esac
    OPENCODE_LABEL="'"$OPENCODE_LAUNCH_LABEL"'"
    OPENCODE_PLIST="$HOME/Library/LaunchAgents/$OPENCODE_LABEL.plist"
    cat > "$OPENCODE_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$OPENCODE_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$OPENCODE_BIN</string>
    <string>$OPENCODE_MODE_BIN_ARGS</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$OPENCODE_LOG_PATH</string>
  <key>StandardErrorPath</key>
  <string>$OPENCODE_LOG_PATH</string>
</dict>
</plist>
EOF
    OPENCODE_SERVICE="gui/$(id -u)/$OPENCODE_LABEL"
    if launchctl print "$OPENCODE_SERVICE" >/dev/null 2>&1; then
      launchctl bootout "$OPENCODE_SERVICE"
    fi
    launchctl bootstrap "gui/$(id -u)" "$OPENCODE_PLIST"
    launchctl kickstart -k "$OPENCODE_SERVICE"
  '
}

get_guest_ip() {
  tart exec "$VM_NAME" /bin/sh -lc 'ifconfig | awk "/inet / {print \$2}" | grep -Ev "^127\\.|^169\\.254\\." | head -n1'
}

wait_for_opencode() {
  local guest_ip="$1"
  local attempts=30
  while (( attempts > 0 )); do
    if curl --fail --silent --max-time 2 "http://$guest_ip:$OPENCODE_PORT" >/dev/null; then
      return 0
    fi
    attempts=$(( attempts - 1 ))
    sleep 1
  done
  echo "OpenCode did not become reachable at http://$guest_ip:$OPENCODE_PORT." >&2
  return 1
}

start_host_opencode_forward() {
  local guest_ip="$1"
  local forward_spec="$OPENCODE_HOST_BIND_ADDRESS:$OPENCODE_HOST_PORT:127.0.0.1:$OPENCODE_PORT"

  if [[ ! -f "$HOST_CLIENT_PRIVATE_KEY" ]]; then
    echo "Missing SSH private key for OpenCode forwarding: $HOST_CLIENT_PRIVATE_KEY" >&2
    return 1
  fi

  if launchctl print "$LAUNCHD_DOMAIN/$PORT_FORWARD_LABEL" >/dev/null 2>&1; then
    launchctl bootout "$LAUNCHD_DOMAIN/$PORT_FORWARD_LABEL"
  fi

  mkdir -p "$LAUNCH_AGENT_DIR" "$LOG_DIR"
  cat > "$PORT_FORWARD_PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$PORT_FORWARD_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/ssh</string>
    <string>-N</string>
    <string>-g</string>
    <string>-L</string>
    <string>$forward_spec</string>
    <string>-i</string>
    <string>$HOST_CLIENT_PRIVATE_KEY</string>
    <string>-o</string>
    <string>BatchMode=yes</string>
    <string>-o</string>
    <string>ExitOnForwardFailure=yes</string>
    <string>-o</string>
    <string>ServerAliveInterval=15</string>
    <string>-o</string>
    <string>ServerAliveCountMax=3</string>
    <string>-o</string>
    <string>StrictHostKeyChecking=accept-new</string>
    <string>$GUEST_SSH_USER@$guest_ip</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>ThrottleInterval</key>
  <integer>2</integer>
  <key>StandardOutPath</key>
  <string>$LOG_DIR/opencode-forward.log</string>
  <key>StandardErrorPath</key>
  <string>$LOG_DIR/opencode-forward.log</string>
</dict>
</plist>
EOF

  launchctl bootstrap "$LAUNCHD_DOMAIN" "$PORT_FORWARD_PLIST_PATH"
  launchctl kickstart -k "$LAUNCHD_DOMAIN/$PORT_FORWARD_LABEL"
}

wait_for_host_opencode() {
  local host_ip="$1"
  local attempts=30
  while (( attempts > 0 )); do
    if curl --fail --silent --max-time 2 "http://$host_ip:$OPENCODE_HOST_PORT" >/dev/null; then
      return 0
    fi
    attempts=$(( attempts - 1 ))
    sleep 1
  done
  echo "OpenCode did not become reachable through http://$host_ip:$OPENCODE_HOST_PORT." >&2
  return 1
}

if ! command -v tart >/dev/null 2>&1; then
  echo "tart not found; installing via Homebrew..."
  if ! brew tap | grep -qx "cirruslabs/cli"; then
    brew tap --quiet cirruslabs/cli
  fi
  brew install --no-ask --quiet cirruslabs/cli/tart
fi

mkdir -p "$WORKSPACE"

if [[ "$RECREATE_VM" == "1" ]]; then
  echo "Recreating '$VM_NAME' (SANDBOX_RECREATE_VM=$RECREATE_VM)."
  if launchctl print "$LAUNCHD_DOMAIN/$PORT_FORWARD_LABEL" >/dev/null 2>&1; then
    launchctl bootout "$LAUNCHD_DOMAIN/$PORT_FORWARD_LABEL"
  fi
  launchctl bootout "$LAUNCHD_DOMAIN/$LAUNCH_LABEL" 2>/dev/null || true
  tart stop "$VM_NAME" 2>/dev/null || true
  tart delete "$VM_NAME" 2>/dev/null || tart delete --force "$VM_NAME" 2>/dev/null || true
else
  echo "Reusing existing VM '$VM_NAME' (set SANDBOX_RECREATE_VM=1 to recreate each run)."
fi

# Clone the prebuilt Xcode image once (large, one-time). Idempotent: skip if VM exists.
if ! tart list --quiet 2>/dev/null | grep -qx "$VM_NAME"; then
  echo "Cloning $IMAGE -> $VM_NAME (large download, one-time)..."
tart clone "$IMAGE" "$VM_NAME"
  tart set "$VM_NAME" --cpu "$CPU" --memory "$MEM_MB" --disk-size "$DISK_GB"
fi
if [[ "$USE_LAUNCHD" == "1" ]]; then
  launchctl bootout "$LAUNCHD_DOMAIN/$LAUNCH_LABEL" 2>/dev/null || true
  mkdir -p "$LAUNCH_AGENT_DIR" "$LOG_DIR"

  cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LAUNCH_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$(command -v tart)</string>
    <string>run</string>
    <string>--no-graphics</string>
EOF
  for tart_arg in "${TART_NETWORK_ARGS[@]}"; do
    printf '    <string>%s</string>\n' "$tart_arg" >> "$PLIST_PATH"
  done
  cat >> "$PLIST_PATH" <<EOF
    <string>--dir</string>
    <string>$TART_DIR_SPEC</string>
    <string>$VM_NAME</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/bin:/usr/bin:/usr/local/bin:/usr/sbin:/sbin:/opt/homebrew/bin</string>
    <key>HOME</key>
    <string>$HOME</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$LOG_DIR/tart-sandbox.log</string>
  <key>StandardErrorPath</key>
    <string>$LOG_DIR/tart-sandbox.log</string>
</dict>
</plist>
EOF

  if ! launchctl bootstrap "$LAUNCHD_DOMAIN" "$PLIST_PATH" 2>/dev/null; then
    launchctl unload -w "$PLIST_PATH" 2>/dev/null || true
    launchctl load -w "$PLIST_PATH"
  fi

else
  tart run \
    --no-graphics \
    "${TART_NETWORK_ARGS[@]}" \
    --dir="$TART_DIR_SPEC" \
    "$VM_NAME" &

  echo "Started '$VM_NAME' in background (PID: $!)."
fi

provision_client_key
configure_guest_hostname
provision_guest_state
start_guest_opencode
GUEST_IP="$(get_guest_ip)"
wait_for_opencode "$GUEST_IP"
HOST_IP="$(ipconfig getifaddr "$TART_BRIDGE_INTERFACE")"
start_host_opencode_forward "$GUEST_IP"
wait_for_host_opencode "$HOST_IP"
HOST_LOCAL_HOSTNAME="$(scutil --get LocalHostName)"

cat <<EOF
VM:        $VM_NAME
Mode:      $OPENCODE_MODE
Endpoint:  http://$HOST_IP:$OPENCODE_HOST_PORT
Hostname:  http://$HOST_LOCAL_HOSTNAME.local:$OPENCODE_HOST_PORT
Workspace: $WORKSPACE -> $GUEST_WORKSPACE_HINT
EOF
