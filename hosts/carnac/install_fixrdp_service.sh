#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing RDP display fix service..."

# Install scripts to ~/.local/bin
mkdir -p ~/.local/bin
cp "$SCRIPT_DIR/fix-rdp.py" ~/.local/bin/
cp "$SCRIPT_DIR/monitor-rdp.sh" ~/.local/bin/
chmod +x ~/.local/bin/fix-rdp.py ~/.local/bin/monitor-rdp.sh

# Install systemd user service
mkdir -p ~/.config/systemd/user
cp "$SCRIPT_DIR/rdp-display-fix.service" ~/.config/systemd/user/

# Enable and start service
systemctl --user daemon-reload
systemctl --user enable rdp-display-fix.service
systemctl --user start rdp-display-fix.service

echo "Done! Service status:"
systemctl --user status rdp-display-fix.service --no-pager
