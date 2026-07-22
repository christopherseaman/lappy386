#!/bin/bash
# Provision a disposable macOS + Xcode Tart VM running Codex, with ~/projects
# shared in and the guest isolated from the host LAN. Apple Silicon only.
set -euo pipefail

VM_NAME="${SANDBOX_VM:-tahoe-xcode}"
IMAGE="ghcr.io/cirruslabs/macos-tahoe-xcode:latest"
WORKSPACE="${SANDBOX_WORKSPACE:-$HOME/projects}"
CPU="${SANDBOX_CPU:-8}"
MEM_MB="${SANDBOX_MEM_MB:-16384}"
DISK_GB="${SANDBOX_DISK_GB:-150}"
USE_LAUNCHD="${SANDBOX_LAUNCHD:-1}"
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

if ! command -v tart >/dev/null 2>&1; then
  echo "tart not found; installing via Homebrew..."
  if ! brew tap | grep -qx "cirruslabs/cli"; then
    brew tap --quiet cirruslabs/cli
  fi
  brew install --no-ask --quiet cirruslabs/cli/tart
fi

mkdir -p "$WORKSPACE"

# Clone the prebuilt Xcode image once (large, one-time). Idempotent: skip if VM exists.
if ! tart list --quiet 2>/dev/null | grep -qx "$VM_NAME"; then
  echo "Cloning $IMAGE -> $VM_NAME (large download, one-time)..."
tart clone "$IMAGE" "$VM_NAME"
  tart set "$VM_NAME" --cpu "$CPU" --memory "$MEM_MB" --disk-size "$DISK_GB"
fi

cat <<EOF

Workspace:         $WORKSPACE
VM:               $VM_NAME
Image:            $IMAGE
  LAN isolation:    --net-softnet

Shared workspace:  $WORKSPACE  ->  /Volumes/My Shared Files/projects (in guest)

One-time first-boot steps inside the guest (login admin/admin, then CHANGE the password):
  git clone https://github.com/christopherseaman/lappy386
  (cd lappy386/tools && ./setup-cli.sh)   # dotfiles, starship, nvm, uv, golang, codex, ~/.codex/AGENTS.md
  (cd lappy386/tools && ./merge-codex-config.py sandbox ~/.codex/config.toml)  # this VM is the jail
  brew install gh bat fd fzf ripgrep git-delta zoxide tmux   # CLI tools (parity with the Debian guest)
  codex login
  gh auth login
  codex remote-control start  # publishes no port; reaches OpenAI outbound over a unix socket
  codex remote-control pair   # short-lived code to pair a phone

(From another terminal you can shell in with the 'sandbox' alias instead of the GUI console.)

A remote-control error before 'codex login' completes is expected and benign.
EOF

if [[ "$USE_LAUNCHD" == "1" ]]; then
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
    <string>--net-softnet</string>
    <string>--dir</string>
    <string>projects:$WORKSPACE</string>
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

  launchctl bootout "$LAUNCHD_DOMAIN/$LAUNCH_LABEL" 2>/dev/null || true
  if ! launchctl bootstrap "$LAUNCHD_DOMAIN" "$PLIST_PATH" 2>/dev/null; then
    launchctl unload -w "$PLIST_PATH" 2>/dev/null || true
    launchctl load -w "$PLIST_PATH"
  fi

  echo "Sandbox '$VM_NAME' managed by launchd as '$LAUNCH_LABEL' (label: $LAUNCH_LABEL)."
  echo "Logs: $LOG_DIR/tart-sandbox.log"
  echo "Tail logs: tail -f \"$LOG_DIR/tart-sandbox.log\""
  echo "Stop:  launchctl bootout $LAUNCHD_DOMAIN/$LAUNCH_LABEL"
  echo "Start: launchctl bootstrap $LAUNCHD_DOMAIN \"$PLIST_PATH\""
else
  tart run \
    --no-graphics \
    --net-softnet \
    --dir="projects:$WORKSPACE" \
    "$VM_NAME" &

  echo "Started '$VM_NAME' in background (PID: $!)."
fi

provision_client_key
