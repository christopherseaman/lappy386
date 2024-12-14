## COPY DOT-FILES
cat dot-zshrc > ~/.zshrc
mkdir -p ~/.ssh
cat dotssh-config > ~/.ssh/config

git config --global user.name 'Christopher Seaman'
git config --global user.email '86775+christopherseaman@users.noreply.github.com'

## INSTALL HOMEBREW
## https://brew.sh
# /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

## INSTALL BREW PACKAGES
brew tap homebrew/cask-fonts
brew tap teamookla/speedtest
brew install $(grep -v '#' brew.lst)
brew install --cask $(grep -v '#' cask.lst)

## INSTALL NVM AND NODE
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
source .zshrc
nvm install --lts
