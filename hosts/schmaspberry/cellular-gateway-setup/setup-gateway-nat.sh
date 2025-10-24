#!/bin/bash

# Setup NAT/Masquerading for UniFi Gateway to use cellular connection
# This allows devices on eth0 (10.42.0.0/24) to use the cellular WAN

set -euo pipefail

CELLULAR_INTERFACE="enx9a1ccb379736"
LAN_SUBNET="10.42.0.0/24"

echo "Setting up NAT for eth0 -> $CELLULAR_INTERFACE"

# Enable IP forwarding (should already be enabled)
sudo sysctl -w net.ipv4.ip_forward=1

# Add masquerading rule for eth0 traffic going out cellular
sudo iptables -t nat -C POSTROUTING -s $LAN_SUBNET -o $CELLULAR_INTERFACE -j MASQUERADE 2>/dev/null || \
    sudo iptables -t nat -A POSTROUTING -s $LAN_SUBNET -o $CELLULAR_INTERFACE -j MASQUERADE

echo "NAT rules configured successfully"
echo ""
echo "Current POSTROUTING rules:"
sudo iptables -t nat -L POSTROUTING -n -v
