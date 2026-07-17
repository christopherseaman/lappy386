#!/bin/bash
# Build the happier-agent image and run a disposable Codex + Happier sandbox.
# Rootless Podman, started by the normal user (never sudo). The container's writable
# overlay layer is discarded on removal, so agent-installed toolchains stay disposable.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="localhost/happier-agent:latest"
NAME="happier-agent"                         # podman container name — stable across hosts (exec/sandbox alias)
# hostname INSIDE the guest — per-host so each machine's Happier daemon registers distinctly
GUEST_HOSTNAME="${SANDBOX_HOSTNAME:-$(hostname -s 2>/dev/null || hostname)-happier}"
WORKSPACE="${SANDBOX_WORKSPACE:-$HOME/projects}"
HAPPIER_STATE="$HOME/.local/share/happier-container"
CODEX_STATE="$HOME/.local/share/codex-container"
GH_STATE="$HOME/.local/share/gh-container"

if ! command -v podman >/dev/null 2>&1; then
  echo "podman not found; installing..."
  sudo apt-get update && sudo apt-get install -y podman
fi

mkdir -p "$WORKSPACE" "$HAPPIER_STATE" "$CODEX_STATE" "$GH_STATE"

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
# loopback services (slirp4netns). Only ~/projects + the auth dirs are mounted. Runs
# DETACHED with a keep-alive PID 1 — provisioning does not open a shell; use `sandbox`
# (alias) or `podman exec -it happier-agent bash` for that. gh creds are persisted via
# a mounted volume because the container's writable layer is discarded on rebuild.
podman run -d \
  --name "$NAME" \
  --hostname "$GUEST_HOSTNAME" \
  --userns="keep-id:uid=$(id -u),gid=$(id -g)" \
  --cap-drop=all \
  --security-opt=no-new-privileges \
  --network=slirp4netns:allow_host_loopback=false \
  --memory=8g --pids-limit=512 --cpus=4 \
  --volume "$WORKSPACE:/workspace:rw" \
  --volume "$HAPPIER_STATE:/home/agent/.happier:rw" \
  --volume "$CODEX_STATE:/home/agent/.codex:rw" \
  --volume "$GH_STATE:/home/agent/.config/gh:rw" \
  --workdir /workspace \
  "$IMAGE" bash -c 'happier daemon start >/dev/null 2>&1 || true; exec sleep infinity'

cat <<EOF

Sandbox '$NAME' is running (detached). The Happier daemon auto-starts on container
start/restart once you've authed (it's a benign no-op before that).
  Shell in:   sandbox              # alias; or:  podman exec -it $NAME bash
  Auth once (persists via mounted volumes):
    codex login
    happier auth login             # mobile-first
    gh auth login
  Bring the daemon up with your new auth:  podman restart $NAME
  Stop:  podman stop $NAME      Rebuild: re-run this script
EOF
