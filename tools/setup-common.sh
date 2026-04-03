#!/bin/bash
set -euo pipefail

## COPY DOT-FILES
cat artifacts/dot-bashrc >~/.bashrc
cat artifacts/dot-aliases >~/.aliases
cat artifacts/dot-tmux.conf >~/.tmux.conf
cat artifacts/dot-zshrc >~/.zshrc
mkdir -p ~/.local/bin
cp artifacts/tmux-zen.sh ~/.local/bin/tmux-zen.sh
chmod +x ~/.local/bin/tmux-zen.sh
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

## CONFIGS
mkdir -p ~/.config
rm -rf ~/.config/nvim
cp -r artifacts/dot-config-nvim ~/.config/nvim
cp artifacts/starship.toml ~/.config/starship.toml

## STARSHIP (upstream binary, not apt)
if dpkg -l starship 2>/dev/null | grep -q '^ii'; then
  sudo apt purge --quiet -qq -y starship
fi
curl -sS https://starship.rs/install.sh | sudo sh -s -- -y >/dev/null
echo "Starship: $(starship --version | head -1)"

## UV
if command -v uv &>/dev/null; then
  uv self update &>/dev/null || true
  echo "uv: $(uv --version | head -1)"
else
  echo "uv: installing..."
  curl -LsSf https://astral.sh/uv/install.sh | sh -s -- --quiet
fi

## NVM + NODE
export NVM_DIR="$HOME/.config/nvm"
if [ -s "$NVM_DIR/nvm.sh" ] && ls "$NVM_DIR/versions/node/" &>/dev/null; then
  \. "$NVM_DIR/nvm.sh"
  echo "Node: $(node --version)"
else
  echo "Node: installing nvm + LTS..."
  mkdir -p "$NVM_DIR"
  wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
  \. "$NVM_DIR/nvm.sh"
  nvm install --lts
  npm install -g npm@latest
fi

## AGENT CLI'S
if command -v copilot &>/dev/null || command -v github-copilot-cli &>/dev/null; then
  copilot update &>/dev/null || true
else
  echo "Copilot: installing..."
  curl -fsSL https://gh.io/copilot-install | bash &>/dev/null || true
fi
echo "Copilot: $(copilot --version 2>/dev/null | head -1 || true)"
if command -v claude &>/dev/null; then
  claude update &>/dev/null || true
else
  echo "Claude: installing..."
  curl -fsSL https://claude.ai/install.sh | bash &>/dev/null || true
fi
echo "Claude: $(claude --version 2>/dev/null | head -1 || true)"
HAPPIER_INSTALLED=$(happier --version 2>/dev/null | head -1 || true)
HAPPIER_LATEST=$(npm view @happier-dev/cli@next version 2>/dev/null || true)
if [[ "$HAPPIER_INSTALLED" != *"$HAPPIER_LATEST"* ]]; then
  npm i -g @happier-dev/cli@next --silent &>/dev/null || true
  HAPPIER_INSTALLED=$(happier --version 2>/dev/null | head -1 || true)
fi
echo "Happier: $HAPPIER_INSTALLED"

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
