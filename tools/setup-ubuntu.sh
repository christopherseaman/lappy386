#!/bin/bash

## UBUNTU PACKAGE INSTALLATION
sudo apt update -qq --quiet
sudo apt install -qq --quiet -y \
  bash-completion \
  bat \
  build-essential \
  cmake \
  fd-find \
  findutils \
  fzf \
  git-delta \
  gh \
  htop \
  ncdu \
  ripgrep \
  qemu-guest-agent \
  qemu-utils \
  spice-vdagent \
  software-properties-common

sudo snap install nvim --classic 2>/dev/null

curl -LsSf https://astral.sh/uv/install.sh | sh -s -- --quiet

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

# Fastfetch and helix should be available in mainline Ubuntu apt sources
# Uncomment below for older Ubuntu releases if needed:
# sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch >/dev/null 2>&1
# sudo add-apt-repository -y ppa:maveonair/helix-editor >/dev/null 2>&1
sudo apt update -qq
sudo apt install -qq -y fastfetch helix

echo "Ubuntu package installation complete."

## RUN COMMON SETUP
./setup-common.sh
