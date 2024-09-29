#!/bin/bash

set -e

# Define the ports to bypass VPN
BYPASS_PORTS="22,3389,5900,80,443"

# Function to get the default gateway
get_default_gateway() {
    ip route show default | awk '/default/ {print $3}' | head -n1
}

# Function to apply VPN bypass
apply_bypass() {
    echo "Applying VPN bypass..."

    # Create a new routing table if it doesn't exist
    if ! grep -q "200 vpn-bypass" /etc/iproute2/rt_tables; then
        echo "200 vpn-bypass" | sudo tee -a /etc/iproute2/rt_tables
        echo "Added vpn-bypass to rt_tables."
    else
        echo "vpn-bypass already in rt_tables."
    fi

    # Add a rule to use the new table for marked packets
    if ! ip rule show | grep -q "fwmark 0x1 lookup vpn-bypass"; then
        sudo ip rule add fwmark 1 table vpn-bypass
        echo "Added ip rule for vpn-bypass table."
    else
        echo "ip rule for vpn-bypass already exists."
    fi

    # Get the default gateway
    DEFAULT_GATEWAY=$(get_default_gateway)
    if [ -z "$DEFAULT_GATEWAY" ]; then
        echo "Error: Could not determine default gateway."
        exit 1
    fi
    echo "Detected default gateway: $DEFAULT_GATEWAY"

    # Add a default route in the new table
    if ! ip route show table vpn-bypass 2>/dev/null | grep -q "default"; then
        sudo ip route add default via $DEFAULT_GATEWAY table vpn-bypass
        echo "Added default route to vpn-bypass table."
    else
        echo "Default route in vpn-bypass table already exists."
    fi

    # Create iptables rules to mark packets
    if ! sudo iptables -t mangle -C OUTPUT -p tcp -m multiport --dports $BYPASS_PORTS -j MARK --set-mark 1 2>/dev/null; then
        sudo iptables -t mangle -A OUTPUT -p tcp -m multiport --dports $BYPASS_PORTS -j MARK --set-mark 1
        echo "Added iptables rule for marking packets."
    else
        echo "iptables rule for marking packets already exists."
    fi

    echo "VPN bypass configured for ports: $BYPASS_PORTS"
}

# Function to undo VPN bypass
undo_bypass() {
    echo "Removing VPN bypass..."

    # Remove iptables rule
    if sudo iptables -t mangle -C OUTPUT -p tcp -m multiport --dports $BYPASS_PORTS -j MARK --set-mark 1 2>/dev/null; then
        sudo iptables -t mangle -D OUTPUT -p tcp -m multiport --dports $BYPASS_PORTS -j MARK --set-mark 1
        echo "Removed iptables rule."
    else
        echo "iptables rule not found."
    fi

    # Remove ip rule
    if ip rule show | grep -q "fwmark 0x1 lookup vpn-bypass"; then
        sudo ip rule del fwmark 1 table vpn-bypass
        echo "Removed ip rule."
    else
        echo "ip rule not found."
    fi

    # Remove route from vpn-bypass table
    DEFAULT_GATEWAY=$(get_default_gateway)
    if [ -n "$DEFAULT_GATEWAY" ]; then
        sudo ip route del default via $DEFAULT_GATEWAY table vpn-bypass 2>/dev/null || true
        echo "Attempted to remove route from vpn-bypass table."
    else
        echo "No default gateway found. Skipping route removal."
    fi

    # Remove the vpn-bypass table entry
    sudo sed -i '/200 vpn-bypass/d' /etc/iproute2/rt_tables
    echo "Removed vpn-bypass from rt_tables."

    echo "VPN bypass configuration removed."
}

# Main execution
if [ "$1" = "undo" ]; then
    undo_bypass
else
    apply_bypass
    echo "To undo these changes, run this script with the 'undo' parameter."
fi
