#!/bin/bash

## COPY CONFIGS
cat artifacts/dot-zshrc >~/.zshrc
mkdir -p ~/Library/Application\ Support/com.mitchellh.ghostty
cp artifacts/ghostty.config ~/Library/Application\ Support/com.mitchellh.ghostty/config
sudo cp artifacts/sudoers_nopasswd /etc/sudoers.d/sudoers_nopasswd
sudo chmod 440 /etc/sudoers.d/sudoers_nopasswd

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

## RUN COMMON SETUP
./setup-common.sh
