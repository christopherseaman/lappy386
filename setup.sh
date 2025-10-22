#!/bin/bash

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
            *)
                echo "Linux distribution: $ID"
                echo "Unsupported Linux distribution. Supported: Ubuntu, Debian"
                echo "Please run the appropriate setup script manually or adapt one."
                exit 1
                ;;
        esac
    else
        echo "Cannot detect Linux distribution (no /etc/os-release)"
        echo "Please run the appropriate setup script manually:"
        echo "  Ubuntu: tools/setup-ubuntu.sh"
        echo "  Debian: tools/setup-debian.sh"
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
    echo "  macOS: tools/setup-macos.sh"
    exit 1
fi

