#!/bin/bash

# Combined MCP setup script for Claude - Notion and Atlassian
# This script sets up both MCP servers at user scope for portability

set -e  # Exit on error

echo "=== Claude MCP Setup Script ==="
echo "This script will configure MCP servers for Notion and Atlassian"
echo ""

# Function to setup Notion MCP
setup_notion() {
    echo "=== Setting up Notion MCP ==="
    echo ""
    
    # Check if NOTION_API_KEY is set
    if [ -z "$NOTION_API_KEY" ]; then
        echo "NOTION_API_KEY environment variable not set."
        echo "To get your Notion API key:"
        echo "1. Go to https://www.notion.so/my-integrations"
        echo "2. Create a new integration or use an existing one"
        echo "3. Copy the Internal Integration Token"
        echo ""
        read -p "Enter your Notion API key (or press Enter to skip): " NOTION_API_KEY
        
        if [ -z "$NOTION_API_KEY" ]; then
            echo "Skipping Notion setup."
            return
        fi
    fi
    
    # Remove existing notion MCP server if it exists
    claude mcp remove notion 2>/dev/null || true
    
    # Add Notion MCP server with the API key at user scope
    claude mcp add notion -s user \
      -e "OPENAPI_MCP_HEADERS={\"Authorization\": \"Bearer ${NOTION_API_KEY}\", \"Notion-Version\": \"2022-06-28\"}" \
      -- npx -y @notionhq/notion-mcp-server
    
    echo "✓ Notion MCP server configured successfully!"
    echo ""
}

# Function to setup Atlassian MCP
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

# Main menu
echo "Which MCP servers would you like to configure?"
echo "1) Both Notion and Atlassian"
echo "2) Notion only"
echo "3) Atlassian only"
echo ""
read -p "Enter your choice (1-3): " choice

case $choice in
    1)
        setup_notion
        setup_atlassian
        ;;
    2)
        setup_notion
        ;;
    3)
        setup_atlassian
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
echo "- Configurations are stored at user scope (~/.config/claude/)"
echo "- Notion: Uses API token authentication"
echo "- Atlassian: Uses OAuth authentication (tokens managed by mcp-remote)"
echo ""
echo "To switch Notion workspace: Set a new NOTION_API_KEY and re-run this script"
echo "To switch Atlassian instance: Re-run this script and authenticate with a different account"