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

## GPU ACCESS FOR KITTY
getent group render >/dev/null || sudo groupadd render
sudo usermod -aG render "$(whoami)"


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
  git \
  git-delta \
  gh \
  kitty \
  libegl1 \
  libegl-mesa0 \
  libgl1-mesa-dri \
  libwayland-cursor0 \
  libwayland-egl1 \
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

## INSTALL NERD FONTS
echo "Installing Nerd Fonts..."
NERD_FONTS_VERSION=$(curl -s https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"
for font in FiraCode FiraMono 0xProto; do
  echo "  Installing $font Nerd Font..."
  wget -q "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONTS_VERSION}/${font}.tar.xz" -O /tmp/${font}.tar.xz
  mkdir -p "$FONT_DIR/$font"
  tar -xf /tmp/${font}.tar.xz -C "$FONT_DIR/$font"
  rm /tmp/${font}.tar.xz
done
fc-cache -f "$FONT_DIR"

echo "Debian installation complete."

## RUN COMMON SETUP
./setup-common.sh
