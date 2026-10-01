#!/bin/bash
# Provision a disposable macOS + Xcode Tart VM running Codex, with ~/projects
# shared in. Apple Silicon only.
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
RECREATE_VM="${SANDBOX_RECREATE_VM:-0}"
GUEST_SSH_USER="${SANDBOX_GUEST_SSH_USER:-admin}"
HOST_CLIENT_PUBLIC_KEY="${SANDBOX_CLIENT_PUBLIC_KEY:-$HOME/.ssh/client_key.pub}"
LAUNCH_LABEL="${SANDBOX_LAUNCHD_LABEL:-com.lappy386.sandbox.macos}"
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$LAUNCH_AGENT_DIR/${LAUNCH_LABEL}.plist"
LOG_DIR="$HOME/Library/Logs/lappy386-sandbox"
LAUNCHD_DOMAIN="gui/$(id -u)"
GUEST_AUTH_KEYS_DIR="/Users/$GUEST_SSH_USER/.ssh"
GUEST_AUTH_KEYS="$GUEST_AUTH_KEYS_DIR/authorized_keys"
GUEST_KEY_STAGING="/tmp/lappy386-host-client-key.pub"
TART_BRIDGE_INTERFACE="${SANDBOX_TART_BRIDGE_INTERFACE:-en0}"

if [[ ! "$GUEST_HOSTNAME" =~ ^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$ ]]; then
  echo "Invalid SANDBOX_GUEST_HOSTNAME '$GUEST_HOSTNAME'." >&2
  exit 1
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

  local merged_config config_status=0
  merged_config="$(mktemp)"
  tart exec "$VM_NAME" /bin/sh -lc '
    [ -e "$HOME/.codex/config.toml" ] || exit 3
    cat "$HOME/.codex/config.toml"
  ' > "$merged_config" || config_status=$?

  if [[ "$config_status" == "3" ]]; then
    cp "$HOME/.codex/config.toml" "$merged_config" 2>/dev/null || : > "$merged_config"
  elif [[ "$config_status" != "0" ]]; then
    echo "Failed to read guest Codex config; keeping it untouched." >&2
    rm -f "$merged_config"
    return 0
  fi

  if ! uv run --managed-python --python 3.11 --script "$SCRIPT_DIR/../merge-codex-config.py" sandbox "$merged_config"; then
    echo "Codex config merge failed; keeping guest config untouched." >&2
    rm -f "$merged_config"
    return 0
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
    curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_INSTALL_DIR="$HOME/.local/bin" CODEX_NON_INTERACTIVE=true sh
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

echo "Sandbox '$VM_NAME' is running; workspace mounted from $WORKSPACE."
