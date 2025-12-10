#!/bin/bash

## GIT PULL - Ensure we have latest changes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -d "$REPO_ROOT/.git" ]; then
  cd "$REPO_ROOT"
  # Get current commit before pull
  BEFORE_COMMIT=$(git rev-parse HEAD 2>/dev/null)
  # Pull latest changes
  git pull
  # Get commit after pull
  AFTER_COMMIT=$(git rev-parse HEAD 2>/dev/null)
  # Abort if new commits were pulled
  if [ "$BEFORE_COMMIT" != "$AFTER_COMMIT" ]; then
    echo "New changes were pulled from the repository."
    echo "Please review the changes and run the setup script again."
    exit 1
  fi
  # Return to tools directory
  cd "$SCRIPT_DIR"
else
  echo "Warning: Not in a git repository, skipping git pull"
fi

## COPY DOT-FILES
cat artifacts/dot-bashrc >~/.bashrc
cat artifacts/dot-aliases >~/.aliases
cat artifacts/dot-tmux.conf >~/.tmux.conf
cat artifacts/dot-zshrc >~/.zshrc

## SSH CONFIG
mkdir -p ~/.ssh
chmod 0700 ~/.ssh

# Get hostname for repo public key naming
CLIENT_HOSTNAME=$(hostname)
# Use standard key name on all clients
CLIENT_KEY_NAME="client_key"
CLIENT_KEY_PATH="$HOME/.ssh/$CLIENT_KEY_NAME"
CLIENT_PUBKEY_PATH="$HOME/.ssh/$CLIENT_KEY_NAME.pub"

# Ensure public_keys directory exists in repo
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PUBLIC_KEYS_DIR="$REPO_DIR/artifacts/public_keys"
mkdir -p "$PUBLIC_KEYS_DIR"

# Check if ed25519 key exists for this client, create if not
if [ ! -f "$CLIENT_KEY_PATH" ] || [ ! -f "$CLIENT_PUBKEY_PATH" ]; then
  echo "Creating ed25519 key for client: $CLIENT_HOSTNAME"
  ssh-keygen -t ed25519 -f "$CLIENT_KEY_PATH" -N "" -C "$CLIENT_HOSTNAME"
  echo "Created key: $CLIENT_KEY_PATH"
  
  # Copy public key to repo using hostname-based naming
  cp "$CLIENT_PUBKEY_PATH" "$PUBLIC_KEYS_DIR/$CLIENT_HOSTNAME.pub"
  echo "Copied public key to repo: $PUBLIC_KEYS_DIR/$CLIENT_HOSTNAME.pub"
  
  # Git add, status, and prompt for push
  if [ -d "$REPO_ROOT/.git" ]; then
    cd "$REPO_ROOT"
    git add "tools/artifacts/public_keys/$CLIENT_HOSTNAME.pub"
    echo ""
    echo "Git status:"
    git status --short
    echo ""
    read -p "Push public key to repository? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      git push
      echo "Pushed public key to repository"
    else
      echo "Skipping git push (public key staged but not pushed)"
    fi
    cd "$SCRIPT_DIR"
  else
    echo "Warning: Not in a git repository, skipping git add/push"
  fi
else
  echo "Key already exists for client: $CLIENT_HOSTNAME"
fi

# Create authorized_keys from all public keys in repo
if [ -d "$PUBLIC_KEYS_DIR" ] && [ "$(ls -A $PUBLIC_KEYS_DIR/*.pub 2>/dev/null)" ]; then
  cat "$PUBLIC_KEYS_DIR"/*.pub > ~/.ssh/authorized_keys
  chmod 0600 ~/.ssh/authorized_keys
  echo "Created authorized_keys from $(ls -1 $PUBLIC_KEYS_DIR/*.pub | wc -l) public key(s)"
else
  echo "Warning: No public keys found in $PUBLIC_KEYS_DIR"
fi

# Copy SSH config
cat artifacts/dotssh-config > ~/.ssh/config

## NVIM CONFIG
mkdir -p ~/.config
rm -rf ~/.config/nvim
cp -r artifacts/dot-config-nvim ~/.config/nvim

## SETUP CLAUDE GLOBAL CONFIG
mkdir -p ~/.claude
curl -o ~/.claude/CLAUDE.md https://gist.githubusercontent.com/christopherseaman/310a389a659acf37a6b13675a92a2438/raw/CLAUDE.md

## INSTALL NVM AND NODE
wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion
nvm install --lts

curl -fsSL https://claude.ai/install.sh | bash

git config --global user.name "Christopher Seaman"
git config --global user.email "86775+christopherseaman@users.noreply.github.com"
git config --global --add --bool push.autoSetupRemote true

# Source the appropriate shell config
if command -v zsh >/dev/null 2>&1; then
  source ~/.zshrc
else
  source ~/.bashrc
fi

## REMINDER
echo ""
echo "┌─────────────────────────────────────┐"
echo "│                                     │"
if command -v zsh >/dev/null 2>&1; then
  echo "│ Remember to $(tput bold)source .zshrc$(tput sgr0) and run:  │"
else
  echo "│ Remember to $(tput bold)source .bashrc$(tput sgr0) and run: │"
fi
echo "│                                     │"
echo "│          $(tput bold)gh auth login$(tput sgr0)              │"
echo "│                                     │"
echo "└─────────────────────────────────────┘"
