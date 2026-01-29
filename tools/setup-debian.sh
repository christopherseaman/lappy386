#!/bin/bash

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)
    NVIM_ARCH="linux-x86_64"
    FASTFETCH_ARCH="amd64"
    HELIX_ARCH="x86_64"
    ;;
  aarch64|arm64)
    NVIM_ARCH="linux-arm64"
    FASTFETCH_ARCH="aarch64"
    HELIX_ARCH="aarch64"
    ;;
  *)
    echo "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

echo "Detected architecture: $ARCH"


## Package Update and Install
sudo apt update --quiet -qq
sudo apt upgrade --quiet -qq -y
sudo apt install --quiet -qq -y \
  bash-completion \
  bat \
  build-essential \
  cmake \
  curl \
  fastfetch \
  fd-find \
  findutils \
  fzf \
  git-delta \
  gh \
  htop \
  ncdu \
  ripgrep \
  starship
sudo apt autoremove --quiet -qq -y

## VM TOOLS
# sudo apt install -qq -y \
#   qemu-guest-agent \
#   qemu-utils \
#   spice-vdagent

# Install Neovim from GitHub releases
echo "Installing latest Neovim release from GitHub..."
NVIM_VERSION=$(curl -s https://api.github.com/repos/neovim/neovim/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
wget -q "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-${NVIM_ARCH}.tar.gz" -O /tmp/nvim.tar.gz
sudo tar -xzf /tmp/nvim.tar.gz -C /opt
sudo ln -sf /opt/nvim-${NVIM_ARCH}/bin/nvim /usr/local/bin/nvim
rm /tmp/nvim.tar.gz

echo "Debian installation complete."

## RUN COMMON SETUP
./setup-common.sh
