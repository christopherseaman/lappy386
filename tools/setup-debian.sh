#!/bin/bash

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
x86_64)
  NVIM_ARCH="linux-x86_64"
  FASTFETCH_ARCH="amd64"
  HELIX_ARCH="x86_64"
  ;;
aarch64 | arm64)
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

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

## GPU ACCESS
getent group render >/dev/null || sudo groupadd render
sudo usermod -aG render "$(whoami)"

## Remove snapd if present
if command -v snap &>/dev/null; then
  echo "Removing snapd and all installed snaps..."
  # Remove all non-base snaps first, then bases, then snapd
  snap list 2>/dev/null | awk 'NR>1 && $1!="snapd" && $NF!~/base/ {print $1}' | while read -r pkg; do
    sudo snap remove --purge "$pkg" 2>/dev/null
  done
  snap list 2>/dev/null | awk 'NR>1 && $1!="snapd" && $NF~/base/ {print $1}' | while read -r pkg; do
    sudo snap remove --purge "$pkg" 2>/dev/null
  done
  sudo snap remove --purge snapd 2>/dev/null
  sudo apt purge --quiet -qq -y snapd gnome-software-plugin-snap
  sudo apt-mark hold snapd
  rm -rf ~/snap
fi

## Package Update and Install
sudo apt update --quiet -qq
sudo apt upgrade --quiet -qq -y
sudo apt install --quiet -qq -y \
  bash-completion \
  bat \
  build-essential \
  ca-certificates \
  cmake \
  curl \
  fastfetch \
  fd-find \
  findutils \
  fontconfig \
  fzf \
  gh \
  git \
  git-delta \
  gnupg \
  htop \
  ncdu \
  openssh-server \
  ripgrep \
  starship \
  tmux \
  wget
sudo apt autoremove --quiet -qq -y

## VM tools (clipboard/resize, host integration)
if systemd-detect-virt --quiet 2>/dev/null; then
  echo "VM detected, installing guest tools..."
  sudo apt install --quiet -qq -y \
    qemu-guest-agent \
    qemu-utils \
    spice-vdagent
fi

## Install VS Code if not present
if ! command -v code &>/dev/null; then
  echo "Installing VS Code..."
  case "$ARCH" in
    x86_64)          VSCODE_OS="linux-deb-x64" ;;
    aarch64 | arm64) VSCODE_OS="linux-deb-arm64" ;;
  esac
  if [[ -n "${VSCODE_OS:-}" ]]; then
    wget -q -O /tmp/vscode.deb "https://code.visualstudio.com/sha/download?build=stable&os=${VSCODE_OS}"
    sudo apt install --quiet -qq -y /tmp/vscode.deb
    rm /tmp/vscode.deb
  else
    echo "  Skipping VS Code: unsupported architecture $ARCH"
  fi
fi

## Install Zed editor if not present
if ! command -v zed &>/dev/null; then
  echo "Installing Zed editor..."
  curl -f https://zed.dev/install.sh | sh
fi

## Install Firefox from Mozilla apt repo
"$SCRIPT_DIR/setup-firefox.sh"

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

## Debian Trixie: enable backports and install crostini packages
if grep -q 'VERSION_CODENAME=trixie' /etc/os-release 2>/dev/null; then
  echo "Trixie detected, enabling backports..."
  sudo cp "$SCRIPT_DIR/artifacts/debian-backports.sources" /etc/apt/sources.list.d/
  sudo cp "$SCRIPT_DIR/artifacts/99-prefer-backports" /etc/apt/preferences.d/
  sudo apt update --quiet -qq

  if [ -f /dev/.container_token ]; then
    echo "Crostini detected, installing crostini packages..."
    sudo apt install --quiet -qq -y \
      cros-apt-config \
      cros-logging \
      cros-pipe-config \
      cros-sudo-config \
      cros-adapta \
      cros-host-fonts \
      cros-notificationd \
      cros-systemd-overrides \
      cros-ui-config \
      cros-xdg-desktop-portal \
      dbus-x11 \
      file \
      iptables \
      unzip
  fi
fi

## Headless RDP setup (if GDM is installed)
if dpkg -l gdm3 &>/dev/null; then
  echo "GDM detected, setting up headless RDP..."
  sudo --preserve-env=RDP_PASSWORD "$SCRIPT_DIR/rdp/setup-headless-rdp.sh" --auto
fi

echo "Debian installation complete."

## RUN COMMON SETUP
./setup-common.sh
