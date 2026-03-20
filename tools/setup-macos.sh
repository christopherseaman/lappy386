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
  brew update --quiet
fi
echo "Homebrew: $(brew --version | head -1)"

## BREW PACKAGES
brew tap teamookla/speedtest 2>/dev/null
brew install --quiet $(grep -v '#' artifacts/brew.lst)
brew install --cask --quiet $(grep -v '#' artifacts/cask.lst)
brew upgrade --quiet
brew cleanup --quiet

## DOCK
if defaults read com.apple.dock persistent-apps | grep -q "Music.app"; then
  echo "Dock: clearing defaults"
  defaults write com.apple.dock persistent-apps -array
fi
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock magnification -bool true
defaults write com.apple.dock largesize -int 128
killall Dock

## RUN COMMON SETUP
./setup-common.sh
