#!/bin/bash

# Create a directory for custom nftables configurations if it doesn't exist
sudo mkdir -p /etc/nftables.d

# Create the custom configuration file
sudo tee /etc/nftables.d/vpn-split-tunnel.nft > /dev/null << EOF
#!/usr/sbin/nft -f

flush ruleset

table ip vpn-split {
    set excluded_ports {
        type inet_service
        elements = { 22, 80, 443, 3389 }
    }

    chain prerouting {
        type filter hook prerouting priority 0;
    }
    
    chain output {
        type route hook output priority 0;
        tcp sport @excluded_ports accept
        oifname "tun0" accept
        fib daddr type local accept
        drop
    }
}
EOF

# Make the custom configuration file executable
sudo chmod +x /etc/nftables.d/vpn-split-tunnel.nft

# Create a systemd service to load the custom nftables configuration
sudo tee /etc/systemd/system/nftables-vpn-split.service > /dev/null << EOF
[Unit]
Description=nftables VPN split tunneling configuration
After=network.target

[Service]
Type=oneshot
ExecStart=/etc/nftables.d/vpn-split-tunnel.nft
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Create the systemd-networkd configuration
sudo tee /etc/systemd/network/50-vpn-split-tunnel.network > /dev/null << EOF
[Match]
Name=tun0

[Network]
Description=VPN Split Tunnel Configuration

[Route]
Destination=0.0.0.0/0
Table=1000

[RoutingPolicyRule]
Family=ipv4
Table=1000
Priority=100
Not=true
From=0.0.0.0/0
SourcePort=22,80,443,3389
EOF

# Enable and start the custom nftables service
sudo systemctl daemon-reload
sudo systemctl enable nftables-vpn-split.service
sudo systemctl restart nftables-vpn-split.service

# Restart systemd-networkd
sudo systemctl restart systemd-networkd

echo "VPN split tunneling configuration completed. Please restart your VPN connection."
