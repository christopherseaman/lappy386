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

# Install Starship - use apt for Ubuntu 25.10+, curl for earlier versions
UBUNTU_VERSION=$(lsb_release -rs)
if [ "$(echo "$UBUNTU_VERSION >= 25.10" | bc -l)" = "1" ] 2>/dev/null; then
    echo "Installing Starship via apt (Ubuntu $UBUNTU_VERSION)..."
    sudo apt install -qq -y starship
else
    echo "Installing Starship via curl (Ubuntu $UBUNTU_VERSION)..."
    curl -sS https://starship.rs/install.sh | sudo sh -s -- --yes --quiet
fi

sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch >/dev/null 2>&1
sudo add-apt-repository -y ppa:maveonair/helix-editor >/dev/null 2>&1
sudo apt update -qq
sudo apt install -qq -y fastfetch helix

echo "Ubuntu package installation complete."

## RUN COMMON SETUP
./setup-common.sh
