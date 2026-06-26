#!/bin/bash

## COPY CONFIGS
cat artifacts/dot-zshrc >~/.zshrc
mkdir -p ~/Library/Application\ Support/com.mitchellh.ghostty
cp artifacts/ghostty.config ~/Library/Application\ Support/com.mitchellh.ghostty/config
## HOMEBREW
if ! command -v brew &>/dev/null; then
  echo "Homebrew: installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  brew update --quiet >/dev/null
fi

## BREW PACKAGES
echo "Brew: upgrading packages"
brew upgrade --quiet >/dev/null

echo "Brew: installing formulas"
brew tap teamookla/speedtest 2>/dev/null
brew install --quiet $(grep -v '#' artifacts/brew.lst) >/dev/null

echo "Brew: installing fonts"
brew install --cask --quiet $(grep -v '#' artifacts/fonts.lst) >/dev/null

installed_casks=$(brew list --cask -1)
new_casks=()
for cask in $(grep -v '#' artifacts/cask.lst); do
  if ! echo "$installed_casks" | grep -qx "$cask"; then
    new_casks+=("$cask")
  fi
done
if [[ ${#new_casks[@]} -gt 0 ]]; then
  for cask in "${new_casks[@]}"; do
    echo "Brew: installing cask $cask"
    brew install --cask --quiet "$cask" >/dev/null
  done
else
  echo "Brew: all casks already installed"
fi

brew cleanup --quiet >/dev/null

## DOCK
if defaults read com.apple.dock persistent-apps | grep -q "Music.app"; then
  defaults write com.apple.dock persistent-apps -array
fi
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock magnification -bool true
defaults write com.apple.dock largesize -int 128
killall Dock

## SANDBOX USER (sqrlbot): own home, no admin, group rwx to ~/projects.
## `dan` runs Claude as this user so --dangerously-skip-permissions stays inside a jail.
SANDBOX_USER="sqrlbot"
SANDBOX_GROUP="sqrlbot"
PROJECTS_DIR="$HOME/projects"
if ! id -u "$SANDBOX_USER" &>/dev/null; then
  echo "Creating sandbox user $SANDBOX_USER..."
  # no -admin => not in admin group / not a sudoer; reachable only via your sudo
  sudo sysadminctl -addUser "$SANDBOX_USER" -fullName "sqrlbot" -shell /bin/bash
  sudo dscl . -create /Users/"$SANDBOX_USER" IsHidden 1     # keep off the login window
  sudo dscl . -create /Users/"$SANDBOX_USER" Password '*'   # disable password login
fi
# dedicated shared group; you + sqrlbot are members
# (no docker group on macOS; Docker Desktop is a per-user GUI app — nothing to restrict)
sudo dseditgroup -o create "$SANDBOX_GROUP" &>/dev/null || true
sudo dseditgroup -o edit -a "$(whoami)" -t user "$SANDBOX_GROUP"
sudo dseditgroup -o edit -a "$SANDBOX_USER" -t user "$SANDBOX_GROUP"
# group rwx to ~/projects, with setgid + inherited ACLs so new files inherit access both ways.
# An explicit user ACL keeps YOUR access immediate and covers files sqrlbot creates.
# The recursive pass only fixes pre-existing files; inherited ACLs cover files created later,
# so it runs once and re-runs skip the (potentially large) tree walk.
mkdir -p "$PROJECTS_DIR"
if ! ls -lde "$PROJECTS_DIR" 2>/dev/null | grep -q "group:$SANDBOX_GROUP allow"; then
  echo "Granting $SANDBOX_GROUP group access to $PROJECTS_DIR..."
  ACL_PERMS="read,write,execute,delete,add_file,add_subdirectory,file_inherit,directory_inherit"
  sudo chgrp -R "$SANDBOX_GROUP" "$PROJECTS_DIR"
  sudo chmod -R g+rwX "$PROJECTS_DIR"
  sudo find "$PROJECTS_DIR" -type d -exec chmod g+s {} +
  sudo chmod -R +a "group:$SANDBOX_GROUP allow $ACL_PERMS" "$PROJECTS_DIR"
  sudo chmod -R +a "user:$(whoami) allow $ACL_PERMS" "$PROJECTS_DIR"
fi
# traverse into home so sqrlbot can reach ~/projects
sudo chmod +a "user:$SANDBOX_USER allow execute" "$HOME"

## RUN COMMON SETUP
./setup-common.sh
