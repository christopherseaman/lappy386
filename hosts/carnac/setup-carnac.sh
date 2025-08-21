#!/bin/bash

# Complete setup script for carnac host
# Includes: Pi-hole config, Caddy reverse proxy, code-server, firewall rules, fstab

set -e

echo "=== Carnac Host Setup ==="

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check if Pi-hole is installed
if ! command -v pihole &> /dev/null; then
    echo "ERROR: Pi-hole is not installed. Please install Pi-hole first:"
    echo "  curl -sSL https://install.pi-hole.net | bash"
    exit 1
fi

# 1. Install code-server if not already installed
if ! command -v code-server &> /dev/null; then
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
    
    echo "code-server installed! Password: $PASSWORD"
else
    echo "Code-server already installed"
fi

# 2. Install Caddy if not already installed
if ! command -v caddy &> /dev/null; then
    echo "Installing Caddy..."
    sudo apt update
    sudo apt install -y caddy
else
    echo "Caddy already installed"
fi

# 3. Configure Pi-hole to use port 8081 (freeing 80/443 for Caddy)
echo "Configuring Pi-hole to use port 8081..."
# Check if Pi-hole is already on port 8081
if ! grep -q 'port = "8081o,\[::]:8081o"' /etc/pihole/pihole.toml 2>/dev/null; then
    sudo sed -i 's/port = ".*"/port = "8081o,[::]:8081o"/' /etc/pihole/pihole.toml
    sudo systemctl restart pihole-FTL
else
    echo "  Pi-hole already configured for port 8081"
fi

# 4. Configure Caddy reverse proxy
if [ -f "$SCRIPT_DIR/etc-Caddyfile" ]; then
    echo "Configuring Caddy..."
    # Check if our config is already present (check for one of our domains)
    if ! grep -q "carnac.badmath.org" /etc/caddy/Caddyfile 2>/dev/null; then
        echo "  Appending Caddyfile configuration..."
        sudo tee -a /etc/caddy/Caddyfile < "$SCRIPT_DIR/etc-Caddyfile" > /dev/null
    else
        echo "  Caddy configuration already present"
    fi
else
    echo "ERROR: etc-Caddyfile not found in $SCRIPT_DIR"
    exit 1
fi

# 5. Configure fstab if needed
if [ -f "$SCRIPT_DIR/etc-fstab" ]; then
    echo "Appending fstab entries..."
    while IFS= read -r line; do
        if ! grep -qF "$line" /etc/fstab; then
            echo "$line" | sudo tee -a /etc/fstab > /dev/null
            echo "  Added: $line"
        fi
    done < "$SCRIPT_DIR/etc-fstab"
fi

# 6. Configure firewall rules
echo "Configuring firewall rules..."

# Function to add rule if it doesn't exist
add_iptables_rule() {
    local protocol=$1
    local port=$2
    local service=$3
    
    # Determine the check pattern based on port format
    if [[ "$port" == *":"* ]]; then
        # Port range
        local rule_check="dpts:${port}"
    else
        # Single port
        local rule_check="dpt:${port}"
    fi
    
    if ! sudo iptables -L INPUT -n | grep -q "$rule_check"; then
        # Find position before REJECT rule (if exists)
        local reject_line=$(sudo iptables -L INPUT -n --line-numbers | grep "REJECT" | head -1 | awk '{print $1}')
        if [ -n "$reject_line" ]; then
            sudo iptables -I INPUT $reject_line -p $protocol --dport $port -j ACCEPT -m comment --comment "$service"
            echo "  Added: $service"
        else
            sudo iptables -A INPUT -p $protocol --dport $port -j ACCEPT -m comment --comment "$service"
        fi
    fi
}

# Read and process iptables rules from file
if [ -f "$SCRIPT_DIR/iptables-rules.lst" ]; then
    while IFS=' ' read -r protocol port service || [ -n "$protocol" ]; do
        # Skip comments and empty lines
        [[ "$protocol" =~ ^#.*$ ]] && continue
        [[ -z "$protocol" ]] && continue
        
        add_iptables_rule "$protocol" "$port" "$service"
    done < "$SCRIPT_DIR/iptables-rules.lst"
else
    echo "ERROR: iptables-rules.lst not found in $SCRIPT_DIR"
    exit 1
fi

# Save iptables rules
sudo iptables-save | sudo tee /etc/iptables/rules.v4 > /dev/null

# 7. Start and enable Caddy
echo "Starting services..."
sudo systemctl restart caddy
sudo systemctl enable caddy

echo "=== Setup Complete ==="