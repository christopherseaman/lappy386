#!/bin/bash

# Install code-server for carnac host
# Downloads latest version from GitHub releases

set -e

echo "Installing code-server..."

# Get latest version from GitHub API
VERSION=$(curl -s https://api.github.com/repos/coder/code-server/releases/latest | grep '"tag_name"' | cut -d'"' -f4 | sed 's/^v//')

if [ -z "$VERSION" ]; then
    echo "Failed to get latest version, using fallback"
    VERSION="4.101.2"
fi

echo "Installing code-server version: $VERSION"

# Detect architecture
ARCH=$(dpkg --print-architecture)

# Download and install
curl -fOL "https://github.com/coder/code-server/releases/download/v$VERSION/code-server_${VERSION}_${ARCH}.deb"
sudo dpkg -i "code-server_${VERSION}_${ARCH}.deb"

# Clean up downloaded file
rm "code-server_${VERSION}_${ARCH}.deb"

# Create config directory and generate random password
mkdir -p ~/.config/code-server

# Generate random-ish password (hash of current time + hostname)
PASSWORD=$(echo "$(date +%s)-$(hostname)" | sha256sum | head -c 16)

# Create config file
cat > ~/.config/code-server/config.yaml << EOF
bind-addr: 127.0.0.1:8080
auth: password
password: $PASSWORD
cert: false
EOF

# Enable service for current user
sudo systemctl enable --now "code-server@$USER"

echo ""
echo "code-server installed and enabled!"
echo "Visit http://127.0.0.1:8080"
echo "Password: $PASSWORD"
echo "(Also saved in ~/.config/code-server/config.yaml)"