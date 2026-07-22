#!/bin/bash

# Combined MCP setup script for Claude - Notion, Atlassian (Cloud), and UCSF Confluence (self-hosted)
# This script sets up MCP servers at user scope for portability

## TODO
## Context7
# claude mcp add context7 -s user -t http https://mcp.context7.com/mcp --header "CONTEXT7_API_KEY: ${CONTEXT7_API_KEY}"
## MorphLLM
# claude mcp add filesystem-with-morph -s user -e MORPH_API_KEY=${MORPH_API_KEY} -e ALL_TOOLS=false -- npx @morph-llm/morph-fast-apply
## Sequential Thinking
# claude mcp add sequential-thinking -s user "npx -y @modelcontextprotocol/server-sequential-thinking"
## Zilliz "Claude Context"
# claude mcp add claude-context -s user \
#    -e OPENAI_API_KEY=${OPENAI_API_KEY} \
#    -e MILVUS_TOKEN=${ZILLIZ_API_KEY} \
#    -- npx @zilliz/claude-context-mcp@latest

set -e  # Exit on error

echo "=== Claude MCP Setup Script ==="
echo "This script will configure MCP servers for Notion, Atlassian, and UCSF Confluence"
echo ""

# Function to setup Notion MCP
setup_notion() {
    echo "=== Setting up Notion MCP ==="
    echo ""

    # Remove existing notion MCP server if it exists
    claude mcp remove notion -s project 2>/dev/null || true
    claude mcp remove notion -s local 2>/dev/null || true
    claude mcp remove notion -s user 2>/dev/null || true

    # Add Notion MCP server with the API key at user scope
    claude mcp add notion -t http -s user https://mcp.notion.com/mcp

    echo "✓ Notion MCP server configured successfully!"
    echo ""
}

# Function to setup Atlassian MCP (Cloud, OAuth)
setup_atlassian() {
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

    # Remove existing atlassian MCP server if it exists
    claude mcp remove atlassian 2>/dev/null || true

    # Add the official Atlassian MCP server configuration at user scope
    claude mcp add atlassian -s user "npx -y mcp-remote https://mcp.atlassian.com/v1/sse"

    echo "✓ Atlassian MCP server configured successfully!"
    echo ""
}

# Function to setup UCSF Confluence MCP (self-hosted Data Center/Server, PAT/Bearer auth)
setup_ucsf_confluence() {
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

    # Remove existing server at all scopes
    claude mcp remove ucsf-confluence -s project 2>/dev/null || true
    claude mcp remove ucsf-confluence -s local 2>/dev/null || true
    claude mcp remove ucsf-confluence -s user 2>/dev/null || true

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
echo "To switch Atlassian instance: Re-run this script and authenticate with a different account"
echo "To rotate the UCSF PAT: export UCSF_CONFLUENCE_PAT=... (or let the prompt handle it) and re-run"
