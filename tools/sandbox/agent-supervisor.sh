#!/bin/bash
# PID 1 of the agent sandbox: restore what the ~/.codex bind mount shadows, then keep the codex
# app-server and the opencode serve UI alive for the life of the container.
#
# A file rather than an inline `bash -c` in setup-sandbox-linux.sh, because inline every literal
# in the body becomes part of PID 1's command line: a `pgrep -f`/`pkill -f` for either supervised
# process then matches the supervisor and takes the whole container down. As a file, PID 1 reads
# as `bash agent-supervisor.sh` and the patterns below can only match what they are aiming at.
#
# No `set -e`: this is a supervisor, so a failing check must cost one iteration, not the sandbox.
set -uo pipefail

mkdir -p "$HOME/.codex/packages" "$HOME/.local/share/opencode"
[ -x "$HOME/.codex/packages/standalone/current/codex" ] \
  || cp -a "$HOME/.local/share/codex-seed/packages/." "$HOME/.codex/packages/"
# Global instructions, restored past the same mount. Overwritten every start (the image copy is
# canonical), unlike the package seed above, which codex updates in place.
if [ -f "$HOME/.local/share/agent-instructions/AGENTS.md" ]; then
  cp -f "$HOME/.local/share/agent-instructions/AGENTS.md" "$HOME/.codex/AGENTS.md"
fi

while true; do
  # Stale control/daemon state — a socket and pidfile whose process is gone — makes the next
  # start hang short of ready, so clear it before restarting. Failure here is expected and
  # silent until `codex login` has run: there is nothing to serve before then.
  if ! pgrep -f "codex app-server" >/dev/null 2>&1; then
    rm -rf "$HOME/.codex/app-server-control" "$HOME/.codex/app-server-daemon"
    codex remote-control start >/dev/null 2>&1 || true
  fi
  # Supervise opencode on the port rather than the PID: answering a request proves it is
  # serving, where a live process only proves it has not exited yet.
  if ! curl -fsS -o /dev/null "http://127.0.0.1:$WEB_PORT/"; then
    opencode serve >>"$HOME/.local/share/opencode/web.log" 2>&1 &
  fi
  sleep 30
done
