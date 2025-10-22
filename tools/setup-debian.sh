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

## DEBIAN PACKAGE INSTALLATION
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
  htop \
  ncdu \
  ripgrep \
  qemu-guest-agent \
  qemu-utils \
  spice-vdagent

# Install Neovim from GitHub releases
echo "Installing Neovim from GitHub..."
NVIM_VERSION=$(curl -s https://api.github.com/repos/neovim/neovim/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
wget -q "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-${NVIM_ARCH}.tar.gz" -O /tmp/nvim.tar.gz
sudo tar -xzf /tmp/nvim.tar.gz -C /opt
sudo ln -sf /opt/nvim-${NVIM_ARCH}/bin/nvim /usr/local/bin/nvim
rm /tmp/nvim.tar.gz

# Install gh (GitHub CLI) - need to add their official repo for Debian
sudo mkdir -p -m 755 /etc/apt/keyrings
wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update -qq
sudo apt install -qq -y gh

curl -LsSf https://astral.sh/uv/install.sh | sh -s -- --quiet

# Install Starship - use curl for Debian
echo "Installing Starship via curl..."
curl -sS https://starship.rs/install.sh | sudo sh -s -- --yes

# Install fastfetch from GitHub releases (not in Debian stable repos)
echo "Installing fastfetch from GitHub..."
FASTFETCH_VERSION=$(curl -s https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
wget -q "https://github.com/fastfetch-cli/fastfetch/releases/download/${FASTFETCH_VERSION}/fastfetch-linux-${FASTFETCH_ARCH}.deb" -O /tmp/fastfetch.deb
sudo dpkg -i /tmp/fastfetch.deb
rm /tmp/fastfetch.deb

# Install helix from GitHub releases (not in Debian stable repos)
echo "Installing helix from GitHub..."
HELIX_VERSION=$(curl -s https://api.github.com/repos/helix-editor/helix/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
wget -q "https://github.com/helix-editor/helix/releases/download/${HELIX_VERSION}/helix-${HELIX_VERSION}-${HELIX_ARCH}-linux.tar.xz" -O /tmp/helix.tar.xz
sudo tar -xf /tmp/helix.tar.xz -C /opt
sudo ln -sf /opt/helix-${HELIX_VERSION}-${HELIX_ARCH}-linux/hx /usr/local/bin/hx
rm /tmp/helix.tar.xz

echo "Debian package installation complete."

## RUN COMMON SETUP
./setup-common.sh
