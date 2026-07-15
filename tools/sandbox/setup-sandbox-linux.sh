#!/bin/bash
# Build the happier-agent image and run a disposable Codex + Happier sandbox.
# Rootless Podman, started by the normal user (never sudo). The container's writable
# overlay layer is discarded on removal, so agent-installed toolchains stay disposable.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="localhost/happier-agent:latest"
NAME="happier-agent"
WORKSPACE="${SANDBOX_WORKSPACE:-$HOME/projects}"
HAPPIER_STATE="$HOME/.local/share/happier-container"
CODEX_STATE="$HOME/.local/share/codex-container"

if ! command -v podman >/dev/null 2>&1; then
  echo "podman not found; installing..."
  sudo apt-get update && sudo apt-get install -y podman
fi

mkdir -p "$WORKSPACE" "$HAPPIER_STATE" "$CODEX_STATE"

# Build (idempotent; layer cache makes re-runs cheap). UID/GID baked in so keep-id maps clean.
podman build \
  --build-arg "UID=$(id -u)" \
  --build-arg "GID=$(id -g)" \
  -t "$IMAGE" \
  -f "$SCRIPT_DIR/Containerfile" \
  "$SCRIPT_DIR"

# Replace any previous instance.
podman rm -f "$NAME" >/dev/null 2>&1 || true

# Rootless, no new privileges, all caps dropped, resource-limited, cut off from host
# loopback services (slirp4netns). Only ~/projects + the two auth dirs are mounted.
exec podman run \
  --name "$NAME" \
  --hostname "$NAME" \
  --userns="keep-id:uid=$(id -u),gid=$(id -g)" \
  --cap-drop=all \
  --security-opt=no-new-privileges \
  --network=slirp4netns:allow_host_loopback=false \
  --memory=8g --pids-limit=512 --cpus=4 \
  --volume "$WORKSPACE:/workspace:rw" \
  --volume "$HAPPIER_STATE:/home/agent/.happier:rw" \
  --volume "$CODEX_STATE:/home/agent/.codex:rw" \
  --workdir /workspace \
  --interactive --tty \
  "$IMAGE" "$@"
