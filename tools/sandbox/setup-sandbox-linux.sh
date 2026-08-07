#!/bin/bash
# Build the agent image and run a disposable coding sandbox for Codex.
# Rootless Podman, started by the normal user (never sudo). The container's writable
# overlay layer is discarded on removal, so agent-installed toolchains stay disposable.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="localhost/agent:latest"
NAME="agent"                                 # podman container name — stable across hosts (exec/sandbox alias)
# hostname INSIDE the guest — per-host so each machine registers distinctly for remote control
GUEST_HOSTNAME="${SANDBOX_HOSTNAME:-$(hostname -s 2>/dev/null || hostname)-agent}"
WORKSPACE="${SANDBOX_WORKSPACE:-$HOME/projects}"
WORKSPACE_GROUP="${SANDBOX_WORKSPACE_GROUP:-$(id -gn)}"
CODEX_STATE="$HOME/.local/share/codex-container"
GH_STATE="$HOME/.local/share/gh-container"

if ! command -v podman >/dev/null 2>&1; then
  echo "podman not found; installing..."
  sudo apt-get update && sudo apt-get install -y podman
fi

mkdir -p "$WORKSPACE" "$CODEX_STATE" "$GH_STATE"

if ! command -v setfacl >/dev/null 2>&1; then
  echo "setfacl is required to configure group-writable workspace ACLs." >&2
  exit 1
fi

chgrp "$WORKSPACE_GROUP" "$WORKSPACE"
setfacl -b "$WORKSPACE"
setfacl -k "$WORKSPACE"
chmod 2770 "$WORKSPACE"
setfacl -m "u::rwx,g::rwx,m::rwx,o::---" "$WORKSPACE"
setfacl -d -m "u::rwx,g::rwx,m::rwx,o::---" "$WORKSPACE"

# Build (idempotent; layer cache makes re-runs cheap). UID/GID baked in so keep-id maps clean.
podman build \
  --build-arg "UID=$(id -u)" \
  --build-arg "GID=$(id -g)" \
  -t "$IMAGE" \
  -f "$SCRIPT_DIR/Containerfile" \
  "$SCRIPT_DIR/.."

# Replace any previous instance.
podman rm -f "$NAME" >/dev/null 2>&1 || true

# Managed codex settings, written while the container is down so no guest codex process
# is holding the file. $CODEX_STATE is the host side of the ~/.codex bind mount, so this
# lands in the guest without needing anything installed there. The sandbox scope is what
# supplies approval_policy/sandbox_mode: correct here because the container is the jail.
# Non-fatal by design: this runs after `podman rm -f` and before `podman run`, so under
# `set -euo pipefail` any nonzero exit here would destroy the container without recreating
# it. A guest with stale settings beats a machine with no sandbox; the error is still loud.
uv run --managed-python --python 3.11 --script "$SCRIPT_DIR/../merge-codex-config.py" sandbox "$CODEX_STATE/config.toml" \
  || echo "Codex config: merge failed; continuing with existing config" >&2

# Rootless, no new privileges, all caps dropped, resource-limited, cut off from host
# loopback services (slirp4netns). Only ~/projects + the auth/state dirs are mounted. Runs
# DETACHED with agent-supervisor.sh as PID 1 — provisioning does not open a shell; use
# `sandbox` (alias) or `podman exec -it agent bash` for that. Auth is persisted via mounted
# volumes because the container's writable layer is discarded on rebuild.
#
# --init gives PID 1 an init that reaps orphans: codex spawns per-task children, and a
# non-reaping PID 1 (e.g. a bare `sleep`) leaves each one a zombie until the pids-limit
# is exhausted.
#
podman run -d \
  --name "$NAME" \
  --hostname "$GUEST_HOSTNAME" \
  --init \
  --userns="keep-id:uid=$(id -u),gid=$(id -g)" \
  --cap-drop=all \
  --security-opt=no-new-privileges \
  --network=slirp4netns:allow_host_loopback=false \
  --memory=8g --pids-limit=512 --cpus=4 \
  --volume "$WORKSPACE:/workspace:rw" \
  --volume "$CODEX_STATE:/home/agent/.codex:rw" \
  --volume "$GH_STATE:/home/agent/.config/gh:rw" \
  --workdir /workspace \
  "$IMAGE" /home/agent/.local/bin/agent-supervisor.sh

echo "Sandbox '$NAME' is running (detached) as '$GUEST_HOSTNAME'."
