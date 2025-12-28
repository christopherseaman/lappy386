#!/bin/bash

## GIT PULL - Ensure we have latest changes (check FIRST before any setup)
# Assumes we're running from within the git repo
echo "Pulling latest changes from repository..."
BEFORE_COMMIT=$(git rev-parse HEAD 2>/dev/null)
if ! git pull; then
  echo "Error: git pull failed. Please check your git configuration and try again."
  exit 1
fi
AFTER_COMMIT=$(git rev-parse HEAD 2>/dev/null)
# Abort if new commits were pulled
if [ "$BEFORE_COMMIT" != "$AFTER_COMMIT" ]; then
  echo "New changes were pulled from the repository."
  echo "Please review the changes and run the setup script again."
  exit 1
fi
echo "Repository is up to date."

echo "Detecting operating system..."

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Detect Linux distribution
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu)
                echo "Ubuntu detected - running Ubuntu setup"
                cd tools && ./setup-ubuntu.sh
                ;;
            debian)
                echo "Debian detected - running Debian setup"
                cd tools && ./setup-debian.sh
                ;;
            arch)
                echo "Arch Linux detected - running Arch setup"
                cd tools && ./setup-arch.sh
                ;;
            *)
                echo "Linux distribution: $ID"
                echo "Unsupported Linux distribution. Supported: Ubuntu, Debian, Arch"
                echo "Please run the appropriate setup script manually or adapt one."
                exit 1
                ;;
        esac
    else
        echo "Cannot detect Linux distribution (no /etc/os-release)"
        echo "Please run the appropriate setup script manually:"
        echo "  Ubuntu: tools/setup-ubuntu.sh"
        echo "  Debian: tools/setup-debian.sh"
        echo "  Arch: tools/setup-arch.sh"
        exit 1
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macOS detected - running macOS setup"
    cd tools && ./setup-macos.sh
else
    echo "Unsupported OS: $OSTYPE"
    echo "Please run the appropriate setup script manually:"
    echo "  Ubuntu: tools/setup-ubuntu.sh"
    echo "  Debian: tools/setup-debian.sh"
    echo "  Arch: tools/setup-arch.sh"
    echo "  macOS: tools/setup-macos.sh"
    exit 1
fi

