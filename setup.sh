#!/bin/bash

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
