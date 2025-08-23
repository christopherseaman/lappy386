#!/bin/bash

## UBUNTU PACKAGE INSTALLATION
sudo apt install -y \
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

sudo snap install nvim --classic

curl -LsSf https://astral.sh/uv/install.sh | sh

curl -sS https://starship.rs/install.sh | sudo sh -s -- --yes

sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch
sudo add-apt-repository -y ppa:maveonair/helix-editor
sudo apt update
sudo apt install -y fastfetch helix

## RUN COMMON SETUP
./setup-common.sh
