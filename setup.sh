#!/bin/bash

## GIT PULL - Ensure we have latest changes (check FIRST before any setup)
sudo apt install --quiet -qq -y git
# Ensure preferred defaulst
git config --global user.name "Christopher Seaman"
git config --global user.email "86775+christopherseaman@users.noreply.github.com"
git config --global --add --bool push.autoSetupRemote true
git config --global init.defaultBranch main
git config --global pull.rebase false
## Assumes we're running from within the git repo
#echo "Pulling latest changes from repository..."
#BEFORE_COMMIT=$(git rev-parse HEAD 2>/dev/null)
#if ! git pull; then
#  echo "Error: git pull failed. Please check your git configuration and try again."
#  exit 1
#fi
#AFTER_COMMIT=$(git rev-parse HEAD 2>/dev/null)
## Abort if new commits were pulled
#if [ "$BEFORE_COMMIT" != "$AFTER_COMMIT" ]; then
#  echo "New changes were pulled from the repository."
#  echo "Please review the changes and run the setup script again."
#  exit 1
#fi
#echo "Repository is up to date."

echo "Detecting operating system..."

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  # Detect Linux distribution
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
    debian|ubuntu)
      echo "'$ID' detected - running Debian setup"
      cd tools && ./setup-debian.sh
      ;;
    arch|archarm)
      echo "'$ID' detected - running Arch setup"
      cd tools && ./setup-arch.sh
      ;;
    *)
      echo "Detected unknown ID='$ID'"
      echo "Run the appropriate setup script manually."
      exit 1
      ;;
    esac
  else
    echo "Cannot detect Linux distribution (no /etc/os-release)"
    exit 1
  fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
  echo "macOS detected - running macOS setup"
  cd tools && ./setup-macos.sh
else
  echo "Unsupported OS: $OSTYPE"
  exit 1
fi
