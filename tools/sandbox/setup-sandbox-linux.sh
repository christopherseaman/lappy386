#!/bin/bash
# Build the agent image and run a disposable coding sandbox (codex + opencode web).
# Rootless Podman, started by the normal user (never sudo). The container's writable
# overlay layer is discarded on removal, so agent-installed toolchains stay disposable.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="localhost/agent:latest"
NAME="agent"                                 # podman container name — stable across hosts (exec/sandbox alias)
# hostname INSIDE the guest — per-host so each machine registers distinctly for remote control
GUEST_HOSTNAME="${SANDBOX_HOSTNAME:-$(hostname -s 2>/dev/null || hostname)-agent}"
WORKSPACE="${SANDBOX_WORKSPACE:-$HOME/projects}"
CODEX_STATE="$HOME/.local/share/codex-container"
GH_STATE="$HOME/.local/share/gh-container"
OPENCODE_STATE="$HOME/.local/share/opencode-container"
OPENCODE_CONFIG="$SCRIPT_DIR/../artifacts/opencode-config.json"

# The published port must match what opencode binds inside the guest, so read it back out of
# the config that sets it rather than restating the number here. A mismatch would publish a
# dead port and fail only at the tunnel, so this is a hard error rather than a default.
WEB_PORT="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["server"]["port"])' \
  "$OPENCODE_CONFIG")" || {
  echo "Cannot read server.port from $OPENCODE_CONFIG (needs python3)" >&2; exit 1; }

if ! command -v podman >/dev/null 2>&1; then
  echo "podman not found; installing..."
  sudo apt-get update && sudo apt-get install -y podman
fi

mkdir -p "$WORKSPACE" "$CODEX_STATE" "$GH_STATE" "$OPENCODE_STATE"

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
# The web UI is published to 127.0.0.1 ONLY — opencode has no auth of its own, so the sole
# route in is the cloudflared tunnel (code.badmath.org), which does the authenticating.
# Binding the host's 0.0.0.0 here would put an unauthenticated agent shell on the LAN.
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
  --volume "$OPENCODE_STATE:/home/agent/.local/share/opencode:rw" \
  --publish "127.0.0.1:$WEB_PORT:$WEB_PORT" \
  --env "WEB_PORT=$WEB_PORT" \
  --workdir /workspace \
  "$IMAGE" /home/agent/.local/bin/agent-supervisor.sh

cat <<EOF

Sandbox '$NAME' is running (detached) as '$GUEST_HOSTNAME'. Codex remote control and
opencode web auto-start on container start/restart (codex is a no-op before you auth).
  Web UI:     http://127.0.0.1:$WEB_PORT     # host loopback only; public via the tunnel
  Shell in:   sandbox              # alias; or:  podman exec -it $NAME bash
  Auth once (persists via mounted volumes):
    codex login
    gh auth login
    opencode auth login  # only for paid providers; free models work unauthed
  Pair a phone (short-lived code; machine shows up as '$GUEST_HOSTNAME'):
    podman exec $NAME bash -lc 'codex remote-control pair'
  Restart:  podman restart $NAME
  Stop:  podman stop $NAME      Rebuild: re-run this script
EOF
