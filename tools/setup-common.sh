#!/bin/bash

## COPY DOT-FILES
cat artifacts/dot-bashrc >~/.bashrc
cat artifacts/dot-aliases >~/.aliases
cat artifacts/dot-tmux.conf >~/.tmux.conf
cat artifacts/dot-zshrc >~/.zshrc

## SSH CONFIG
mkdir -p ~/.ssh
if [ -f ~/.ssh/config ]; then
  echo "Existing SSH config found at ~/.ssh/config"
  read -p "Replace existing SSH config? (y/N): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    cp ~/.ssh/config ~/.ssh/config.backup-$(date +%Y%m%d-%H%M%S)
    echo "Backed up existing config to ~/.ssh/config.backup-$(date +%Y%m%d-%H%M%S)"
    cat artifacts/dotssh-config >~/.ssh/config
  else
    echo "Keeping existing SSH config"
  fi
else
  cat artifacts/dotssh-config >~/.ssh/config
fi

## NVIM CONFIG
mkdir -p ~/.config
if [ -d ~/.config/nvim ]; then
  echo "Existing nvim config found at ~/.config/nvim"
  read -p "Replace existing nvim config? (y/N): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    mv ~/.config/nvim ~/.config/nvim.backup-$(date +%Y%m%d-%H%M%S)
    echo "Backed up existing config to ~/.config/nvim.backup-$(date +%Y%m%d-%H%M%S)"
    cp -r artifacts/dot-config-nvim ~/.config/nvim
  else
    echo "Keeping existing nvim config"
  fi
else
  cp -r artifacts/dot-config-nvim ~/.config/nvim
fi

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
