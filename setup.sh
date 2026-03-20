#!/bin/bash

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
