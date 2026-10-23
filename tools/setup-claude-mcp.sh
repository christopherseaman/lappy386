#!/bin/bash

# Combined MCP setup script for Claude - Notion, Atlassian (Cloud), and UCSF Confluence (self-hosted)
# This script sets up MCP servers at user scope for portability

set -e  # Exit on error

echo "=== Claude MCP Setup Script ==="
echo "This script will configure MCP servers for Notion, Atlassian, and UCSF Confluence"
echo ""

server_exists() {
    if claude mcp get "$1" >/dev/null 2>&1; then
        echo "Keeping existing $1 MCP server. Remove it explicitly before replacing it."
        return 0
    fi
    return 1
}

# Function to setup Notion MCP
setup_notion() {
    server_exists notion && return 0
    echo "=== Setting up Notion MCP ==="
    echo ""

    # Add Notion MCP server with the API key at user scope
    claude mcp add notion -t http -s user https://mcp.notion.com/mcp

    echo "✓ Notion MCP server configured successfully!"
    echo ""
}

# Function to setup Atlassian MCP (Cloud, OAuth)
setup_atlassian() {
    server_exists atlassian && return 0
    echo "=== Setting up Atlassian MCP ==="
    echo ""
    echo "This will use OAuth authentication for user-scoped access."
    echo ""

    # First, run mcp-remote to complete OAuth authentication
    echo "Step 1: Authenticating with Atlassian..."
    echo "A browser window will open for OAuth authentication."
    echo ""

    npx -y mcp-remote https://mcp.atlassian.com/v1/sse &
    MCP_PID=$!

    echo "Please complete the following in your browser:"
    echo "1. Log in with your Atlassian credentials"
    echo "2. Select the Atlassian instance you want to connect to"
    echo "3. Approve the required permissions"
    echo ""
    read -p "Once authenticated, press Enter here to continue..."

    # Kill the mcp-remote process
    kill $MCP_PID 2>/dev/null || wait $MCP_PID 2>/dev/null

    echo ""
    echo "Step 2: Adding MCP server to Claude configuration..."

    # Add the official Atlassian MCP server configuration at user scope
    claude mcp add atlassian -s user "npx -y mcp-remote https://mcp.atlassian.com/v1/sse"

    echo "✓ Atlassian MCP server configured successfully!"
    echo ""
}

# Function to setup UCSF Confluence MCP (self-hosted Data Center/Server, PAT/Bearer auth)
setup_ucsf_confluence() {
    server_exists ucsf-confluence && return 0
    echo "=== Setting up UCSF Confluence MCP (self-hosted, PAT auth) ==="
    echo ""
    echo "Uses sooperset/mcp-atlassian via uvx against the UCSF Data Center instance."
    echo "Requires 'uv' installed and network reachability to wiki.library.ucsf.edu (campus VPN)."
    echo ""

    # PAT: use env var if present, otherwise prompt with hidden input (never hardcode secrets)
    if [ -z "${UCSF_CONFLUENCE_PAT}" ]; then
        read -s -p "Enter your UCSF Confluence Personal Access Token: " UCSF_CONFLUENCE_PAT
        echo ""
    fi

    if [ -z "${UCSF_CONFLUENCE_PAT}" ]; then
        echo "No PAT provided. Skipping UCSF Confluence setup."
        return 1
    fi

    # Add self-hosted Confluence (DC/Server) via mcp-atlassian.
    # DC-specific: base URL has NO /wiki suffix; PAT uses CONFLUENCE_PERSONAL_TOKEN (Bearer),
    # NOT CONFLUENCE_API_TOKEN (which is Cloud basic-auth and will 401 here).
    # Optional: add -e CONFLUENCE_SPACES_FILTER=HealthDataScience to scope to one space.
    claude mcp add ucsf-confluence -s user \
        -e CONFLUENCE_URL=https://wiki.library.ucsf.edu \
        -e CONFLUENCE_PERSONAL_TOKEN="${UCSF_CONFLUENCE_PAT}" \
        -- uvx mcp-atlassian

    echo "✓ UCSF Confluence MCP server configured successfully!"
    echo ""
}

# Main menu
echo "Which MCP servers would you like to configure?"
echo "1) Notion, Atlassian, and UCSF Confluence"
echo "2) Notion only"
echo "3) Atlassian only (Cloud, OAuth)"
echo "4) UCSF Confluence only (self-hosted, PAT)"
echo ""
read -p "Enter your choice (1-4): " choice

case $choice in
    1)
        setup_notion
        setup_atlassian
        setup_ucsf_confluence
        ;;
    2)
        setup_notion
        ;;
    3)
        setup_atlassian
        ;;
    4)
        setup_ucsf_confluence
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

echo ""
echo "=== Setup Complete ==="
echo ""
echo "To verify your MCP servers: claude mcp list"
echo ""
echo "Important notes:"
echo "- Configurations are stored at user scope (~/.claude.json)"
echo "- Notion: Uses API token authentication"
echo "- Atlassian (Cloud): Uses OAuth authentication (tokens managed by mcp-remote)"
echo "- UCSF Confluence (self-hosted): Uses a Personal Access Token (Bearer)"
echo ""
echo "Existing registrations are preserved. Remove the intended entry explicitly before replacing it."
echo "For a user entry: claude mcp remove <name> -s user; then re-run setup with the new account or PAT."
