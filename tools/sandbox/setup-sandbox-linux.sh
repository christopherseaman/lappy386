#!/bin/bash
# Build the codex-agent image and run a disposable Codex coding sandbox.
# Rootless Podman, started by the normal user (never sudo). The container's writable
# overlay layer is discarded on removal, so agent-installed toolchains stay disposable.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="localhost/codex-agent:latest"
NAME="codex-agent"                           # podman container name — stable across hosts (exec/sandbox alias)
# hostname INSIDE the guest — per-host so each machine registers distinctly for remote control
GUEST_HOSTNAME="${SANDBOX_HOSTNAME:-$(hostname -s 2>/dev/null || hostname)-codex}"
WORKSPACE="${SANDBOX_WORKSPACE:-$HOME/projects}"
CODEX_STATE="$HOME/.local/share/codex-container"
GH_STATE="$HOME/.local/share/gh-container"

if ! command -v podman >/dev/null 2>&1; then
  echo "podman not found; installing..."
  sudo apt-get update && sudo apt-get install -y podman
fi

mkdir -p "$WORKSPACE" "$CODEX_STATE" "$GH_STATE"

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
if command -v python3 >/dev/null 2>&1; then
  "$SCRIPT_DIR/../merge-codex-config.py" sandbox "$CODEX_STATE/config.toml" \
    || echo "Codex config: merge failed; continuing with existing config" >&2
else
  echo "Codex config: python3 not found; skipped (existing config untouched)" >&2
fi

# Rootless, no new privileges, all caps dropped, resource-limited, cut off from host
# loopback services (slirp4netns). Only ~/projects + the auth dirs are mounted. Runs
# DETACHED with a keep-alive PID 1 — provisioning does not open a shell; use `sandbox`
# (alias) or `podman exec -it codex-agent bash` for that. gh creds are persisted via
# a mounted volume because the container's writable layer is discarded on rebuild.
#
# --init gives PID 1 an init that reaps orphans: codex spawns per-task children, and a
# non-reaping PID 1 (e.g. a bare `sleep`) leaves each one a zombie until the pids-limit
# is exhausted.
#
# On start the wrapper restores what the ~/.codex volume shadows — the installer-managed
# standalone codex package and the global AGENTS.md — then supervises remote control: whenever the
# app-server is not running it drops the control/daemon state (a socket and pidfile whose
# process is gone, which otherwise makes startup fail to become ready) and restarts it. That
# covers both container restarts and the app-server dying mid-life. Remote control reaches
# OpenAI outbound over a unix socket and publishes no port.
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
  "$IMAGE" bash -c '
    mkdir -p "$HOME/.codex/packages"
    [ -x "$HOME/.codex/packages/standalone/current/codex" ] \
      || cp -a "$HOME/.local/share/codex-seed/packages/." "$HOME/.codex/packages/"
    # Global instructions, restored past the same mount. Overwritten every start (the
    # image copy is canonical), unlike the package seed above which codex updates in place.
    [ -f "$HOME/.local/share/agent-instructions/AGENTS.md" ] \
      && cp -f "$HOME/.local/share/agent-instructions/AGENTS.md" "$HOME/.codex/AGENTS.md"
    while true; do
      # bracket keeps the pattern from matching this supervisor own command line
      if ! pgrep -f "codex app-[s]erver" >/dev/null 2>&1; then
        rm -rf "$HOME/.codex/app-server-control" "$HOME/.codex/app-server-daemon"
        codex remote-control start >/dev/null 2>&1 || true
      fi
      sleep 30
    done'

cat <<EOF

Sandbox '$NAME' is running (detached) as '$GUEST_HOSTNAME'. Codex remote control
auto-starts on container start/restart once you've authed (a no-op before that).
  Shell in:   sandbox              # alias; or:  podman exec -it $NAME bash
  Auth once (persists via mounted volumes):
    codex login
    gh auth login
  Pair a phone (short-lived code; machine shows up as '$GUEST_HOSTNAME'):
    podman exec $NAME bash -lc 'codex remote-control pair'
  Restart:  podman restart $NAME
  Stop:  podman stop $NAME      Rebuild: re-run this script
EOF
