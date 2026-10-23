#!/bin/bash

# Codex setup for user-scoped MCP servers, Ponytail, and Terse.
# This script configures Codex's ~/.codex/config.toml; it does not modify Claude's MCP state.

set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"

CODEX_COMMAND="$(command -v codex || true)"
if [ -z "$CODEX_COMMAND" ]; then
    echo "Codex CLI not found on PATH. Run setup-cli.sh first." >&2
    exit 1
fi

echo "=== Codex Setup Script ==="
echo "This script configures Codex MCP servers, Ponytail, and Terse."
echo ""

setup_notion() {
    echo "=== Setting up Notion MCP ==="
    echo ""

    "$CODEX_COMMAND" mcp add notion --url https://mcp.notion.com/mcp

    echo "Authenticate with Notion in the browser that Codex opens."
    "$CODEX_COMMAND" mcp login notion

    echo "✓ Notion MCP server configured successfully!"
    echo ""
}

setup_atlassian() {
    echo "=== Setting up Atlassian MCP ==="
    echo ""
    echo "This uses Atlassian Rovo MCP's OAuth flow for user-scoped access."
    echo ""

    "$CODEX_COMMAND" mcp add atlassian --url https://mcp.atlassian.com/v2/mcp

    echo "Authenticate with Atlassian in the browser that Codex opens."
    "$CODEX_COMMAND" mcp login atlassian

    echo "✓ Atlassian MCP server configured successfully!"
    echo ""
}

setup_ucsf_confluence() {
    echo "=== Setting up UCSF Confluence MCP ==="
    echo ""
    echo "Uses sooperset/mcp-atlassian via uvx against the UCSF Data Center instance."
    echo "Requires uv and network reachability to wiki.library.ucsf.edu (campus VPN)."
    echo ""

    local pat="${UCSF_CONFLUENCE_PAT:-}"
    if [ -z "$pat" ]; then
        read -r -s -p "Enter your UCSF Confluence Personal Access Token: " pat
        echo ""
    fi

    if [ -z "$pat" ]; then
        echo "No PAT provided. Skipping UCSF Confluence setup."
        echo ""
        return 0
    fi

    "$CODEX_COMMAND" mcp add ucsf-confluence \
        --env "CONFLUENCE_URL=https://wiki.library.ucsf.edu" \
        --env "CONFLUENCE_PERSONAL_TOKEN=$pat" \
        -- uvx mcp-atlassian

    echo "✓ UCSF Confluence MCP server configured successfully!"
    echo ""
}

setup_plugins() {
    echo "=== Setting up Ponytail and Terse Codex plugins ==="
    echo ""

    "$CODEX_COMMAND" plugin marketplace add DietrichGebert/ponytail
    "$CODEX_COMMAND" plugin add ponytail@ponytail
    "$CODEX_COMMAND" plugin marketplace add lowenbjer/claude-terse
    "$CODEX_COMMAND" plugin add terse@terse

    if command -v node >/dev/null 2>&1; then
        echo "Node: available; plugin lifecycle hooks can run."
    else
        echo "Warning: node is not on PATH; plugin lifecycle hooks stay inactive."
    fi
    echo "Review and trust plugin hooks in Codex with /hooks, then start a new session."
    echo "✓ Ponytail and Terse plugins configured successfully!"
    echo ""
}

# Non-interactive path used by setup-common.sh.
if [ "${1:-}" = "plugins" ]; then
    setup_plugins
    exit 0
fi

echo "Which Codex components would you like to configure?"
echo "1) Notion only"
echo "2) Atlassian only (OAuth)"
echo "3) UCSF Confluence only (self-hosted, PAT)"
echo "4) Plugins only: Ponytail and Terse"
echo "5) All: Notion, Atlassian, UCSF Confluence, Ponytail, and Terse"
echo ""
read -r -p "Enter your choice (1-5): " choice

case "$choice" in
    1)
        setup_notion
        ;;
    2)
        setup_atlassian
        ;;
    3)
        setup_ucsf_confluence
        ;;
    4)
        setup_plugins
        ;;
    5)
        setup_notion
        setup_atlassian
        setup_ucsf_confluence
        setup_plugins
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

echo "=== Codex Setup Complete ==="
echo ""
echo "Verify MCP servers with: codex mcp list"
echo "Verify plugins with: codex plugin list"
echo "Codex MCP configuration is stored in ~/.codex/config.toml."
