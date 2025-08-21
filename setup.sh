#!/bin/bash

echo "Detecting operating system..."

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Linux detected - running Ubuntu setup"
    cd setup && ./setup-ubuntu.sh
elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macOS detected - running macOS setup"
    cd setup && ./setup-macos.sh
else
    echo "Unsupported OS: $OSTYPE"
    echo "Please run the appropriate setup script manually:"
    echo "  Ubuntu/Linux: setup/setup-ubuntu.sh"
    echo "  macOS: setup/setup-macos.sh"
    exit 1
fi

