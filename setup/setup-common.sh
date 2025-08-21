#!/bin/bash

## COPY DOT-FILES
cat artifacts/dot-bashrc > ~/.bashrc
cat artifacts/dot-bash_aliases > ~/.bash_aliases
cat artifacts/dot-tmux.conf > ~/.tmux.conf
mkdir -p ~/.ssh
cat artifacts/dotssh-config > ~/.ssh/config

## COPY NVIM CONFIG
mkdir -p ~/.config
cp -r artifacts/dot-config-nvim ~/.config/nvim

## SETUP CLAUDE GLOBAL CONFIG
mkdir -p ~/.claude
curl -o ~/.claude/CLAUDE.md https://gist.githubusercontent.com/christopherseaman/310a389a659acf37a6b13675a92a2438/raw/CLAUDE.md

## INSTALL NVM AND NODE
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
source ~/.bashrc
nvm install --lts
npm i -g @anthropic-ai/claude-code

## REMINDER
echo ""
echo "┌─────────────────────────────────────┐"
echo "│ Setup complete! Remember to run:    │"
echo "│                                     │"
echo "│ $(tput bold)gh auth login$(tput sgr0)                       │"
echo "└─────────────────────────────────────┘"