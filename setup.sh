#!/bin/bash

## Self-update from upstream before running setup
## Only fast-forwards if HEAD is strictly behind origin/main; skips if ahead or diverged.
if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null; then
  git fetch --quiet origin main
  LOCAL=$(git rev-parse HEAD)
  REMOTE=$(git rev-parse origin/main)
  BASE=$(git merge-base HEAD origin/main)
  if [ "$LOCAL" != "$REMOTE" ] && [ "$LOCAL" = "$BASE" ]; then
    git pull --quiet --ff-only origin main
    echo "Updated to latest. Please re-run ./setup.sh"
    exit 0
  fi
fi

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  . /etc/os-release 2>/dev/null || { echo "Cannot detect Linux distribution"; exit 1; }
  case "$ID" in
    debian|ubuntu) echo "Setup: $PRETTY_NAME"; cd tools && ./setup-debian.sh ;;
    *)             echo "Unsupported distro: $ID"; exit 1 ;;
  esac
elif [[ "$OSTYPE" == "darwin"* ]]; then
  echo "Setup: macOS"; cd tools && ./setup-macos.sh
else
  echo "Unsupported OS: $OSTYPE"; exit 1
fi
