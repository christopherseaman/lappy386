#!/bin/bash

## COPY DOT-FILES
cat artifacts/dot-bashrc >~/.bashrc
cat artifacts/dot-aliases >~/.aliases
cat artifacts/dot-tmux.conf >~/.tmux.conf
cat artifacts/dot-zshrc >~/.zshrc
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

# Get hostname for repo public key naming
CLIENT_HOSTNAME=$(cat /etc/hostname)
# Use standard key name on all clients
CLIENT_KEY_NAME="client_key"
CLIENT_KEY_PATH="$HOME/.ssh/$CLIENT_KEY_NAME"
CLIENT_PUBKEY_PATH="$HOME/.ssh/$CLIENT_KEY_NAME.pub"

# Ensure public_keys directory exists in repo
PUBLIC_KEYS_DIR="artifacts/public_keys"
mkdir -p "$PUBLIC_KEYS_DIR"

# Check if ed25519 key exists for this client, create if not
if [ ! -f "$CLIENT_KEY_PATH" ] || [ ! -f "$CLIENT_PUBKEY_PATH" ]; then
  echo "Creating ed25519 key for client: $CLIENT_HOSTNAME"
  ssh-keygen -t ed25519 -f "$CLIENT_KEY_PATH" -N "" -C "$CLIENT_HOSTNAME"
  echo "Created key: $CLIENT_KEY_PATH"

  # Copy public key to repo using hostname-based naming
  cp "$CLIENT_PUBKEY_PATH" "$PUBLIC_KEYS_DIR/$CLIENT_HOSTNAME.pub"
  echo "Copied public key to repo: $PUBLIC_KEYS_DIR/$CLIENT_HOSTNAME.pub"
else
  echo "Key already exists for client: $CLIENT_HOSTNAME"
fi

## Replace authorized_keys with all public keys from repo, ensuring newline separation
: >~/.ssh/authorized_keys
for f in "$PUBLIC_KEYS_DIR"/*.pub; do
  printf '%s\n' "$(<"$f")" >>~/.ssh/authorized_keys
done
chmod 0600 ~/.ssh/authorized_keys
echo "Updated authorized_keys from public keys in repo"

## DNS RESOLVER FOR HOME NETWORK
# Create /etc/resolver/home for proper .home domain resolution
sudo mkdir -p /etc/resolver
echo "nameserver 10.1.0.1" | sudo tee /etc/resolver/home >/dev/null
echo "Created /etc/resolver/home for .home domain resolution"

## Install Astral uv
curl -LsSf https://astral.sh/uv/install.sh | sh -s -- --quiet

## NVIM CONFIG
mkdir -p ~/.config
rm -rf ~/.config/nvim
cp -r artifacts/dot-config-nvim ~/.config/nvim

## INSTALL NVM AND NODE
mkdir -p "$HOME/.config/nvm"
export NVM_DIR="$HOME/.config/nvm"
wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
\. "$NVM_DIR/nvm.sh"
nvm install --lts
npm install -g npm@latest

## INSTALL LOCAL AGENT CLI'S
curl -fsSL https://gh.io/copilot-install | bash
curl -fsSL https://claude.ai/install.sh | bash
# curl -fsSL https://happier.dev/install-preview | bash
npm i -g @happier-dev/cli@next

## SETUP CLAUDE GLOBAL CONFIG
mkdir -p ~/.claude
curl -o ~/.claude/CLAUDE.md https://gist.githubusercontent.com/christopherseaman/310a389a659acf37a6b13675a92a2438/raw/CLAUDE.md
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
