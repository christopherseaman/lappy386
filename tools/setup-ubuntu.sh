#!/bin/bash
echo "│ Remember to source .zshrc  │"

## UBUNTU PACKAGE INSTALLATION
sudo apt update --quiet
sudo apt upgrade --quiet -y
sudo apt autoremove --quiet -y
sudo apt install --quiet -y \
  bash-completion \
  bat \
  build-essential \
  cmake \
  fastfetch \
  fd-find \
  findutils \
  fzf \
  git-delta \
  gh \
  htop \
  ncdu \
  ripgrep \
  software-properties-common

## VM TOOLS
# sudo apt install -qq -y \
#  qemu-guest-agent \
#  qemu-utils \
#  spice-vdagent

sudo snap install nvim --classic 2>/dev/null
# sudo snap install helix 2>/dev/null

curl -LsSf https://astral.sh/uv/install.sh | sh -s -- --quiet
uv tool install ruff

# Install Starship - use apt for Ubuntu after 24.10, curl for earlier versions
. /etc/lsb-release

# Convert version to comparable integer (25.04 -> 2504, 24.10 -> 2410)
VERSION_NUM=$(echo "$DISTRIB_RELEASE" | awk -F. '{printf "%d%02d", $1, $2}')

if [ "$VERSION_NUM" -gt 2410 ]; then
  echo "Installing Starship via apt (Ubuntu $DISTRIB_RELEASE)..."
  sudo apt install -qq -y starship
else
  echo "Installing Starship via curl (Ubuntu $DISTRIB_RELEASE)..."
  curl -sS https://starship.rs/install.sh | sudo sh -s -- --yes
fi

echo "Ubuntu package installation complete."

## RUN COMMON SETUP
./setup-common.sh
