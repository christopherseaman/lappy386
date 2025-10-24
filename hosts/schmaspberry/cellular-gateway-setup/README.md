# Raspberry Pi Cellular Gateway Setup

## Purpose
Configure Raspberry Pi to act as a NAT gateway, allowing UniFi Gateway to use the cellular USB tether connection as a failover WAN.

## Network Topology
```
Cellular Network (USB Tether)
    ↓
enx9a1ccb379736 (10.51.43.133/24)
    ↓
[Raspberry Pi - NAT Gateway]
    ↓
eth0 (10.42.0.1/24) - NetworkManager "shared" mode
    ↓
UniFi Gateway WAN Port
    ↓
UniFi manages its own failover between primary WAN and this cellular backup
```

## Components

### 1. NetworkManager Connection
- **Interface**: eth0
- **Mode**: shared (provides DHCP on 10.42.0.0/24)
- **DHCP Range**: 10.42.0.10 - 10.42.0.254
- **Gateway IP**: 10.42.0.1

Check connection:
```bash
nmcli con show "Wired connection 1"
```

### 2. IP Forwarding
- **File**: `/etc/sysctl.d/99-ip-forward.conf`
- **Setting**: `net.ipv4.ip_forward=1`

Verify:
```bash
cat /proc/sys/net/ipv4/ip_forward  # Should show 1
```

### 3. NAT/Masquerading Script
- **Location**: `~/.local/bin/setup-gateway-nat.sh`
- **Purpose**: Creates iptables NAT rule on boot

Script creates rule:
```bash
iptables -t nat -A POSTROUTING -s 10.42.0.0/24 -o enx9a1ccb379736 -j MASQUERADE
```

### 4. Systemd Service
- **File**: `/etc/systemd/system/gateway-nat.service`
- **Status**: enabled
- **Runs**: On boot after network is online

## Installation/Restoration

If reinstalling or moving to a new Pi:

```bash
# 1. Copy script to .local/bin
cp setup-gateway-nat.sh ~/.local/bin/
chmod +x ~/.local/bin/setup-gateway-nat.sh

# 2. Install systemd service
sudo cp gateway-nat.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable gateway-nat.service
sudo systemctl start gateway-nat.service

# 3. Enable IP forwarding permanently
sudo cp 99-ip-forward.conf /etc/sysctl.d/
sudo sysctl -p /etc/sysctl.d/99-ip-forward.conf

# 4. Configure eth0 for connection sharing (if not already set)
sudo nmcli con modify "Wired connection 1" ipv4.method shared
sudo nmcli con up "Wired connection 1"
```

## Verification

### Check if NAT is working:
```bash
# 1. Verify IP forwarding
cat /proc/sys/net/ipv4/ip_forward  # Should be 1

# 2. Check NAT rules
sudo iptables -t nat -L POSTROUTING -n -v | grep 10.42

# 3. Check service status
systemctl status gateway-nat.service

# 4. Check if UniFi Gateway received DHCP
ip neigh show dev eth0

# 5. Check routing
ip route show
```

### Expected NAT rule output:
```
MASQUERADE  all  --  *  enx9a1ccb379736  10.42.0.0/24  0.0.0.0/0
```

## UniFi Configuration

On the UniFi Gateway:
1. Connect WAN port to Raspberry Pi eth0
2. Add new WAN connection (should auto-detect via DHCP)
3. Configure failover settings to use cellular as backup
4. UniFi handles automatic failover between primary and cellular WAN

## Troubleshooting

### NAT not working after reboot
```bash
# Check if service is enabled and running
systemctl status gateway-nat.service

# Manually run the script
~/.local/bin/setup-gateway-nat.sh

# Check system logs
journalctl -u gateway-nat.service
```

### UniFi not getting IP
```bash
# Check DHCP server is running
ps aux | grep dnsmasq | grep eth0

# Restart NetworkManager
sudo systemctl restart NetworkManager
```

### No internet from UniFi
```bash
# Verify NAT rule exists
sudo iptables -t nat -L POSTROUTING -n -v | grep 10.42

# Test connectivity from Pi
ping -I eth0 8.8.8.8

# Check cellular connection is up
ip addr show enx9a1ccb379736
```

## Notes

- The cellular interface name `enx9a1ccb379736` is based on MAC address and should remain consistent
- NetworkManager's "shared" mode handles DHCP but NOT the NAT rule to cellular
- The systemd service is required to recreate the iptables NAT rule after each reboot
- IP forwarding must be explicitly enabled via sysctl for routing to work
- SSH via Tailscale (tailscale0) is unaffected by these routing changes

## Created
2025-10-24
