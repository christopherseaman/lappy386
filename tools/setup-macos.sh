#!/bin/bash

## COPY ZSH CONFIG (macOS default)
cat artifacts/dot-zshrc >~/.zshrc

## COPY GHOSTTY CONFIG
mkdir -p ~/Library/Application\ Support/com.mitchellh.ghostty
cp artifacts/ghostty.config ~/Library/Application\ Support/com.mitchellh.ghostty/config

## COPY SUDOERS CONFIG
sudo cp artifacts/sudoers_nopasswd /etc/sudoers.d/sudoers_nopasswd
sudo chmod 440 /etc/sudoers.d/sudoers_nopasswd

## INSTALL HOMEBREW
## https://brew.sh
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "Homebrew already installed, skipping..."
fi

## INSTALL BREW PACKAGES
brew tap teamookla/speedtest
brew install --quiet $(grep -v '#' artifacts/brew.lst)
brew install --quiet $(grep -v '#' artifacts/cask.lst)

## CONFIGURE DOCK
# Clear dock if it contains Music
if defaults read com.apple.dock persistent-apps | grep -q "Music.app"; then
    echo "Music found in dock, clearing dock..."
    defaults write com.apple.dock persistent-apps -array
fi

# Enable dock auto-hiding
defaults write com.apple.dock autohide -bool true

# Enable magnification and set to max
defaults write com.apple.dock magnification -bool true
defaults write com.apple.dock largesize -int 128

# Restart dock to apply changes
killall Dock

## RUN COMMON SETUP
./setup-common.sh

