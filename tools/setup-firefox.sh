#!/bin/bash

# Install Firefox from Mozilla's official apt repository
# Removes snap version if present

## Remove Firefox snap if snapd is available
if command -v snap &>/dev/null && snap list firefox &>/dev/null; then
  echo "Removing Firefox snap..."
  sudo snap remove --purge firefox
fi

## Remove any existing Mozilla apt config to avoid duplicates
sudo rm -f /etc/apt/sources.list.d/mozilla.list /etc/apt/sources.list.d/mozilla.sources

## Set up Mozilla apt repository
echo "Setting up Mozilla apt repository..."
sudo install -d -m 0755 /etc/apt/keyrings
wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | \
  sudo tee /etc/apt/keyrings/packages.mozilla.org.asc >/dev/null

cat <<'EOF' | sudo tee /etc/apt/sources.list.d/mozilla.sources >/dev/null
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Signed-By: /etc/apt/keyrings/packages.mozilla.org.asc
EOF

# Prefer Mozilla's repo over distro packages
cat <<'EOF' | sudo tee /etc/apt/preferences.d/mozilla >/dev/null
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF

## Install Firefox
echo "Installing Firefox from Mozilla apt repo..."
sudo apt update --quiet -qq
sudo apt install --quiet -qq -y firefox

echo "Firefox installation complete."
