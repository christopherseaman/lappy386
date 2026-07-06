#!/bin/bash
set -euo pipefail

## SANDBOX USER CLAUDE (sqrlbot): own install + config so `dan` can run Claude as it.
## Auth itself is a one-time manual step (see banner) — credentials are never copied.
## Runs standalone or after a platform user-creation script; paths resolve via SCRIPT_DIR.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARTIFACTS_DIR="$SCRIPT_DIR/../artifacts"

if id -u sqrlbot &>/dev/null; then
  echo "Provisioning Claude for sqrlbot sandbox..."
  SQRLBOT_HOME=$(eval echo ~sqrlbot)
  # CI=1 makes `claude install` non-interactive; without it Claude opens /dev/tty after
  # installing and blocks for a keypress, which hangs unattended provisioning.
  sudo -iu sqrlbot bash -c 'export CI=1; [ -x "$HOME/.local/bin/claude" ] && "$HOME/.local/bin/claude" install >/dev/null 2>&1 || curl -fsSL https://claude.ai/install.sh | bash >/dev/null 2>&1' </dev/null || true
  sudo -u sqrlbot mkdir -p "$SQRLBOT_HOME/.claude"
  sudo -u sqrlbot tee "$SQRLBOT_HOME/.claude/settings.json" <"$ARTIFACTS_DIR/claude-settings.json" >/dev/null || true
  curl -so- https://gist.githubusercontent.com/christopherseaman/310a389a659acf37a6b13675a92a2438/raw/CLAUDE.md 2>/dev/null | sudo -u sqrlbot tee "$SQRLBOT_HOME/.claude/CLAUDE.md" >/dev/null || true
  # login-shell PATH so bare `claude` resolves (claude installs to ~/.local/bin)
  sudo -u sqrlbot tee "$SQRLBOT_HOME/.bash_profile" >/dev/null <<'PROFILE' || true
export PATH="$HOME/.local/bin:$PATH"
PROFILE
  # macOS: a headless (never-GUI-logged-in) user has no login keychain, so Claude's OAuth
  # store has nowhere to write. Create an empty-password one that never auto-locks, and have
  # every login shell unlock it (empty pw => no secret) so it keeps working across reboots.
  if [[ "$OSTYPE" == darwin* ]]; then
    sudo -iu sqrlbot bash -c 'KC="$HOME/Library/Keychains/login.keychain-db"; [ -f "$KC" ] || security create-keychain -p "" "$KC"; security set-keychain-settings "$KC"; security default-keychain -s "$KC"; security list-keychains -d user -s "$KC" /Library/Keychains/System.keychain; security unlock-keychain -p "" "$KC"' </dev/null >/dev/null 2>&1 || true
    sudo -u sqrlbot tee -a "$SQRLBOT_HOME/.bash_profile" >/dev/null <<'PROFILE' || true
security unlock-keychain -p "" "$HOME/Library/Keychains/login.keychain-db" 2>/dev/null
PROFILE
  fi
  echo ""
  echo "sqrlbot sandbox ready. One-time Claude login:  $(tput bold)sudo -iu sqrlbot claude$(tput sgr0)"
fi
