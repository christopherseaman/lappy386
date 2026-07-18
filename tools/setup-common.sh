#!/bin/bash
set -euo pipefail

## Shared CLI layer (dotfiles, starship, nvm, uv, golang, codex) — same as the sandbox guest
./setup-cli.sh
export PATH="$HOME/.local/bin:$PATH"

## Git defaults
git config --global user.name "Christopher Seaman"
git config --global user.email "86775+christopherseaman@users.noreply.github.com"
git config --global --add --bool push.autoSetupRemote true
git config --global init.defaultBranch main
git config --global pull.rebase false

## SSH CONFIG
mkdir -p ~/.ssh
chmod 0700 ~/.ssh
cat artifacts/dot-ssh-config >~/.ssh/config

CLIENT_HOSTNAME=$(hostname)
CLIENT_KEY_PATH="$HOME/.ssh/client_key"
CLIENT_PUBKEY_PATH="$HOME/.ssh/client_key.pub"
PUBLIC_KEYS_DIR="artifacts/public_keys"
mkdir -p "$PUBLIC_KEYS_DIR"

if [ ! -f "$CLIENT_KEY_PATH" ] || [ ! -f "$CLIENT_PUBKEY_PATH" ]; then
  echo "SSH: creating ed25519 key for $CLIENT_HOSTNAME"
  ssh-keygen -t ed25519 -f "$CLIENT_KEY_PATH" -N "" -C "$CLIENT_HOSTNAME"
  cp "$CLIENT_PUBKEY_PATH" "$PUBLIC_KEYS_DIR/$CLIENT_HOSTNAME.pub"
fi

: >~/.ssh/authorized_keys
for f in "$PUBLIC_KEYS_DIR"/*.pub; do
  printf '%s\n' "$(<"$f")" >>~/.ssh/authorized_keys
done
chmod 0600 ~/.ssh/authorized_keys

## DNS RESOLVER FOR HOME NETWORK
sudo mkdir -p /etc/resolver
echo "nameserver 10.1.0.1" | sudo tee /etc/resolver/home >/dev/null

## SUDOERS
sudo cp artifacts/sudoers_nopasswd /etc/sudoers.d/sudoers_nopasswd
sudo chmod 440 /etc/sudoers.d/sudoers_nopasswd

## NVIM CONFIG
mkdir -p ~/.config
rm -rf ~/.config/nvim
cp -r artifacts/dot-config-nvim ~/.config/nvim

## AGENT CLI'S (host-only: claude + ntn; codex is installed by setup-cli.sh)
if command -v claude &>/dev/null; then
  claude update &>/dev/null || true
else
  echo "Claude: installing..."
  curl -fsSL https://claude.ai/install.sh | bash &>/dev/null || true
fi
echo "Claude: $(claude --version 2>/dev/null | head -1 || true)"
if command -v ntn &>/dev/null; then
  ntn update &>/dev/null || true
else
  echo "Notion CLI: installing..."
  curl -fsSL https://ntn.dev | bash &>/dev/null || true
fi
echo "Notion CLI: $(ntn --version 2>/dev/null | head -1 || true)"

## CLAUDE GLOBAL CONFIG
mkdir -p ~/.claude
curl -so ~/.claude/CLAUDE.md https://gist.githubusercontent.com/christopherseaman/310a389a659acf37a6b13675a92a2438/raw/CLAUDE.md || true
cp artifacts/claude-settings.json ~/.claude/settings.json

## REMINDER
echo ""
echo "┌──────────────────────────────┐"
echo "│                              │"
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "│  Remember to $(tput bold)source .zshrc$(tput sgr0)   │"
else
  echo "│  Remember to $(tput bold)source .bashrc$(tput sgr0)  │"
fi
if [[ -n "${RDP_PASSWORD:-}" ]]; then
  echo "│                              │"
  printf "│  RDP password: $(tput bold)%-13s$(tput sgr0)│\n" "$RDP_PASSWORD"
fi
echo "│                              │"
echo "└──────────────────────────────┘"
