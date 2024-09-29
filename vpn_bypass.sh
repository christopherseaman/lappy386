#!/bin/bash

# Define the ports to bypass VPN
BYPASS_PORTS="22,3389,5900,80,443"

# Get the default gateway
DEFAULT_GATEWAY=$(ip route show default | awk '/default/ {print $3}')

# Function to apply VPN bypass
apply_bypass() {
    # Create a new routing table
    echo "200 vpn-bypass" | sudo tee -a /etc/iproute2/rt_tables

    # Add a rule to use the new table for marked packets
    sudo ip rule add fwmark 1 table vpn-bypass

    # Add a default route in the new table
    sudo ip route add default via $DEFAULT_GATEWAY table vpn-bypass

    # Create iptables rules to mark packets
    sudo iptables -t mangle -A OUTPUT -p tcp -m multiport --dports $BYPASS_PORTS -j MARK --set-mark 1

    echo "VPN bypass configured for ports: $BYPASS_PORTS"
}

# Function to undo VPN bypass
undo_bypass() {
    # Remove iptables rule
    sudo iptables -t mangle -D OUTPUT -p tcp -m multiport --dports $BYPASS_PORTS -j MARK --set-mark 1

    # Remove ip rule
    sudo ip rule del fwmark 1 table vpn-bypass

    # Remove route from vpn-bypass table
    sudo ip route del default via $DEFAULT_GATEWAY table vpn-bypass

    # Remove the vpn-bypass table entry
    sudo sed -i '/200 vpn-bypass/d' /etc/iproute2/rt_tables

    echo "VPN bypass configuration removed."
}

# Main execution
if [ "$1" = "undo" ]; then
    undo_bypass
else
    apply_bypass
    echo "To undo these changes, run this script with the 'undo' parameter."
fi
