#!/bin/bash
# Provision a disposable macOS + Xcode Tart VM running Codex + Happier, with ~/projects
# shared in and the guest isolated from the host LAN. Apple Silicon only.
set -euo pipefail

VM_NAME="${SANDBOX_VM:-tahoe-xcode}"
IMAGE="ghcr.io/cirruslabs/macos-tahoe-xcode:latest"
WORKSPACE="${SANDBOX_WORKSPACE:-$HOME/projects}"
CPU="${SANDBOX_CPU:-8}"
MEM_MB="${SANDBOX_MEM_MB:-16384}"
DISK_GB="${SANDBOX_DISK_GB:-150}"

if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
  echo "This sandbox requires macOS on Apple Silicon." >&2
  exit 1
fi

if ! command -v tart >/dev/null 2>&1; then
  echo "tart not found; installing via Homebrew..."
  brew install cirruslabs/cli/tart
fi

mkdir -p "$WORKSPACE"

# Clone the prebuilt Xcode image once (large, one-time). Idempotent: skip if VM exists.
if ! tart list --quiet 2>/dev/null | grep -qx "$VM_NAME"; then
  echo "Cloning $IMAGE -> $VM_NAME (large download, one-time)..."
  tart clone "$IMAGE" "$VM_NAME"
  tart set "$VM_NAME" --cpu "$CPU" --memory "$MEM_MB" --disk-size "$DISK_GB"
fi

cat <<EOF

Starting '$VM_NAME':
  LAN isolation:    --net-softnet
  Shared workspace: $WORKSPACE  ->  /Volumes/My Shared Files/projects (in guest)

One-time first-boot steps inside the guest (login admin/admin, then CHANGE the password):
  git clone https://github.com/christopherseaman/lappy386
  (cd lappy386/tools && ./setup-cli.sh)   # dotfiles + starship + nvm + uv + golang + codex
  brew install gh bat fd fzf ripgrep git-delta zoxide tmux   # CLI tools (parity with the Debian guest)
  curl -fsSL https://happier.dev/install-dev | bash          # Happier dev channel -> hdev
  codex login
  hdev auth login             # mobile-first; the daemon will not start until this completes
  gh auth login
  hdev daemon service install && hdev daemon start

(From another terminal you can shell in with the 'sandbox' alias instead of the GUI console.)

A Happier daemon error before auth completes is expected and benign.
EOF

exec tart run \
  --net-softnet \
  --dir="projects:$WORKSPACE" \
  "$VM_NAME"
