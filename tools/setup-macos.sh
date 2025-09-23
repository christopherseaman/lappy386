#!/bin/bash

## COPY ZSH CONFIG (macOS default)
cat artifacts/dot-zshrc > ~/.zshrc

## INSTALL HOMEBREW
## https://brew.sh
# /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

## INSTALL BREW PACKAGES
brew tap teamookla/speedtest
brew install --quiet $(grep -v '#' artifacts/brew.lst)
brew install --cask --quiet $(grep -v '#' artifacts/cask.lst)

## RUN COMMON SETUP
./setup-common.sh