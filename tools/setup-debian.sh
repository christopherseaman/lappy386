#!/bin/bash

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
x86_64)
  NVIM_ARCH="linux-x86_64"
  CODE_ARCH="linux-deb-x64"
  OBSIDIAN_ARCH="amd64"
  ;;
aarch64 | arm64)
  NVIM_ARCH="linux-arm64"
  CODE_ARCH="linux-deb-arm64"
  OBSIDIAN_ARCH="arm64"
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
sudo apt full-upgrade --quiet -qq -y
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
  if [[ -n "${CODE_ARCH:-}" ]]; then
    wget -q -O /tmp/vscode.deb "https://code.visualstudio.com/sha/download?build=stable&os=${CODE_ARCH}"
    sudo apt install --quiet -qq -y /tmp/vscode.deb
    rm /tmp/vscode.deb
  else
    echo "  Skipping VS Code: unknown architecture $ARCH"
  fi
fi

## Install Zed editor if not present
if ! command -v zed &>/dev/null; then
  echo "Installing Zed editor..."
  curl -f https://zed.dev/install.sh | sh
fi

## Install or update Obsidian
OBSIDIAN_LATEST=$(curl -s https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
if [ "$OBSIDIAN_ARCH" = "amd64" ]; then
  OBSIDIAN_CURRENT=$(dpkg-query -W -f='${Version}' obsidian 2>/dev/null || true)
else
  OBSIDIAN_CURRENT=$(cat "$HOME/.local/share/obsidian/.version" 2>/dev/null || true)
fi
if [ "$OBSIDIAN_CURRENT" != "$OBSIDIAN_LATEST" ]; then
  echo "Installing Obsidian: ${OBSIDIAN_CURRENT:-none} -> $OBSIDIAN_LATEST"
  if [ "$OBSIDIAN_ARCH" = "amd64" ]; then
    wget -q "https://github.com/obsidianmd/obsidian-releases/releases/download/v${OBSIDIAN_LATEST}/obsidian_${OBSIDIAN_LATEST}_${OBSIDIAN_ARCH}.deb" -O /tmp/obsidian.deb
    sudo apt install --quiet -qq -y /tmp/obsidian.deb
    rm /tmp/obsidian.deb
  else
    wget -q "https://github.com/obsidianmd/obsidian-releases/releases/download/v${OBSIDIAN_LATEST}/obsidian-${OBSIDIAN_LATEST}-${OBSIDIAN_ARCH}.tar.gz" -O /tmp/obsidian.tar.gz
    rm -rf "$HOME/.local/share/obsidian"
    mkdir -p "$HOME/.local/share/obsidian"
    tar -xzf /tmp/obsidian.tar.gz -C "$HOME/.local/share/obsidian" --strip-components=1
    rm /tmp/obsidian.tar.gz
    sudo chown root:root "$HOME/.local/share/obsidian/chrome-sandbox"
    sudo chmod 4755 "$HOME/.local/share/obsidian/chrome-sandbox"
    echo "$OBSIDIAN_LATEST" > "$HOME/.local/share/obsidian/.version"
    ln -sf "$HOME/.local/share/obsidian/obsidian" "$HOME/.local/bin/obsidian"
    mkdir -p "$HOME/.local/share/applications"
    cat > "$HOME/.local/share/applications/obsidian.desktop" <<DESKTOP
[Desktop Entry]
Name=Obsidian
Exec=$HOME/.local/share/obsidian/obsidian %u
Icon=$HOME/.local/share/obsidian/resources/icon.png
Type=Application
Categories=Office;
MimeType=x-scheme-handler/obsidian;
DESKTOP
  fi
else
  echo "Obsidian already at latest ($OBSIDIAN_LATEST), skipping."
fi

## Firefox from Mozilla apt repo (skip on RPi, skip on ChromeOS, skip if already configured)
if [ -f /etc/rpi-issue ]; then
  echo "Firefox: skipped (Raspberry Pi)"
elif [ -f /dev/.container_token ]; then
  echo "Firefox: skipped (ChromeOS)"
elif [ -f /etc/apt/sources.list.d/mozilla.sources ]; then
  echo "Firefox: Mozilla apt repo already configured"
else
  "$SCRIPT_DIR/setup-firefox.sh"
fi

# Install or update Neovim from GitHub releases (always ensure latest)
NVIM_LATEST=$(curl -s https://api.github.com/repos/neovim/neovim/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
NVIM_CURRENT=$(nvim --version 2>/dev/null | head -1 | sed -E 's/NVIM //' || true)
if [ "$NVIM_CURRENT" != "$NVIM_LATEST" ]; then
  echo "Updating Neovim: ${NVIM_CURRENT:-none} -> $NVIM_LATEST"
  wget -q "https://github.com/neovim/neovim/releases/download/${NVIM_LATEST}/nvim-${NVIM_ARCH}.tar.gz" -O /tmp/nvim.tar.gz
  sudo rm -rf /opt/nvim-${NVIM_ARCH}
  sudo tar -xzf /tmp/nvim.tar.gz -C /opt
  sudo ln -sf /opt/nvim-${NVIM_ARCH}/bin/nvim /usr/local/bin/nvim
  rm /tmp/nvim.tar.gz
else
  echo "Neovim already at latest ($NVIM_LATEST), skipping."
fi

## INSTALL NERD FONTS (skip if already present)
FONT_DIR="$HOME/.local/share/fonts"
FONTS_NEEDED=()
for font in FiraCode FiraMono 0xProto; do
  if [ ! -d "$FONT_DIR/$font" ] || [ -z "$(ls -A "$FONT_DIR/$font" 2>/dev/null)" ]; then
    FONTS_NEEDED+=("$font")
  fi
done
if [ ${#FONTS_NEEDED[@]} -gt 0 ]; then
  echo "Installing Nerd Fonts: ${FONTS_NEEDED[*]}..."
  NERD_FONTS_VERSION=$(curl -s https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
  mkdir -p "$FONT_DIR"
  for font in "${FONTS_NEEDED[@]}"; do
    echo "  Installing $font Nerd Font..."
    wget -q "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONTS_VERSION}/${font}.tar.xz" -O /tmp/${font}.tar.xz
    mkdir -p "$FONT_DIR/$font"
    tar -xf /tmp/${font}.tar.xz -C "$FONT_DIR/$font"
    rm /tmp/${font}.tar.xz
  done
  fc-cache -f "$FONT_DIR"
else
  echo "Nerd Fonts already installed, skipping."
fi

## Debian Trixie: enable backports and install crostini packages
if grep -q 'VERSION_CODENAME=trixie' /etc/os-release 2>/dev/null; then
  echo "Trixie detected, enabling backports..."
  sudo cp "$SCRIPT_DIR/artifacts/debian-backports.sources" /etc/apt/sources.list.d/
  sudo cp "$SCRIPT_DIR/artifacts/99-prefer-backports" /etc/apt/preferences.d/
  sudo apt update --quiet -qq

  if [ -f /dev/.container_token ]; then
    echo "ChromeOS detected, installing ChromeOS packages..."
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

  FIXRDP_OUTPUT=$(DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus" \
    XDG_RUNTIME_DIR="/run/user/$(id -u)" \
      bash "$SCRIPT_DIR/rdp/install_fixrdp_service.sh" 2>&1) \
    && echo "RDP display fix service installed." \
    || { echo "Warning: RDP display fix service install failed:" >&2; echo "$FIXRDP_OUTPUT" >&2; }
fi

echo "Debian installation complete."

## RUN COMMON SETUP
./setup-common.sh
