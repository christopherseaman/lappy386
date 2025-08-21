#!/bin/bash

## COPY DOT-FILES
cat artifacts/dot-bashrc >~/.bashrc
cat artifacts/dot-bash_aliases >~/.bash_aliases
cat artifacts/dot-tmux.conf >~/.tmux.conf
mkdir -p ~/.ssh
cat artifacts/dotssh-config >~/.ssh/config

## COPY NVIM CONFIG
mkdir -p ~/.config
cp -r artifacts/dot-config-nvim ~/.config/nvim

## SETUP CLAUDE GLOBAL CONFIG
mkdir -p ~/.claude
curl -o ~/.claude/CLAUDE.md https://gist.githubusercontent.com/christopherseaman/310a389a659acf37a6b13675a92a2438/raw/CLAUDE.md

## INSTALL NVM AND NODE
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion
source ~/.bashrc
nvm install --lts
npm i -g @anthropic-ai/claude-code

git config --global user.name "Christopher Seaman"
git config --global user.email "86775+christopherseaman@users.noreply.github.com"

## REMINDER
echo ""
echo "┌─────────────────────────────────────┐"
echo "│ Setup complete! Remember to run:    │"
echo "│                                     │"
echo "│ $(tput bold)gh auth login$(tput sgr0)                       │"
echo "└─────────────────────────────────────┘"
