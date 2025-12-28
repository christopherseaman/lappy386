#!/bin/bash

## ARCH LINUX PACKAGE INSTALLATION
sudo pacman -Syu --quiet --noconfirm
sudo pacman -S --quiet --noconfirm \
  bash-completion \
  bat \
  base-devel \
  cmake \
  wget \
  git \
  fd \
  findutils \
  fzf \
  git-delta \
  github-cli \
  htop \
  ncdu \
  ripgrep \
  qemu-guest-agent \
  spice-vdagent \
  tmux \
  neovim \
  starship \
  fastfetch \
  helix

curl -LsSf https://astral.sh/uv/install.sh | sh -s -- --quiet

echo "Arch Linux package installation complete."

## RUN COMMON SETUP
./setup-common.sh
