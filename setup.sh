#!/bin/bash

echo "Detecting operating system..."

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Linux detected - running Ubuntu setup"
    cd tools && ./setup-ubuntu.sh
elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macOS detected - running macOS setup"
    cd tools && ./setup-macos.sh
else
    echo "Unsupported OS: $OSTYPE"
    echo "Please run the appropriate setup script manually:"
    echo "  Ubuntu/Linux: tools/setup-ubuntu.sh"
    echo "  macOS: tools/setup-macos.sh"
    exit 1
fi

